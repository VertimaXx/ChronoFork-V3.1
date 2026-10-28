--!native
const RunService = game:GetService("RunService")

const Ticker = require(script.Parent.Parent.Shared.Ticker)
const Entity = require(script.Parent.Parent.Shared.Entity)
const EntityGrid = require(script.Parent.EntityGrid)
const Types = require(script.Parent.Parent.Shared.Types)
const Shared = script.Parent.Parent.Shared
const ModelHelper = require(Shared.ModelHelper)
const Stats = require(Shared.Stats).SERVER
const Protocol = require(Shared.Protocol)

local BytesSentPerSec = 0
local PacketsSentPerSec = 0


type BufferHolder = { [Types.Ticker]: { buffer } }
const UnreliableEvent = Shared.Remotes.Replicate
const ReliableEvent = Shared.Remotes.ReplicateFull
const SafeReplicateEvent = Shared.Remotes.SafeReplicate

const function SendRecords(player, rows, kind, event)
	for _, packet in Protocol.Pack(rows) do
		(event or UnreliableEvent):FireClient(player, kind, packet)
		BytesSentPerSec += buffer.len(packet)
		PacketsSentPerSec += 1
	end
end
const function FlushClientOwned(player, groups, event)
	local rows = {}
	for _, records in groups do for _, record in records do table.insert(rows, record) end end
	SendRecords(player, rows, "O", event)
end
const function FlushEntities(player, groups, isHalf, event)
	local rows = {}
	for _, records in groups do for _, record in records do table.insert(rows, Protocol.WithHalf(record, isHalf == true)) end end
	SendRecords(player, rows, "X", event)
end

const function AddBuffer(holder: BufferHolder, ticker: Types.Ticker, b: buffer)
	local bufferTable = holder[ticker]
	if not bufferTable then
		bufferTable = {}
		holder[ticker] = bufferTable
	end
	table.insert(bufferTable, b)
end

--//honestly tables should beeeee fine for nowww, could buffer it later if reallllly needed
const function GetEntityFullData(player: Player, entity: Types.Entity): Types.EntityReceivePacket?
	if entity.destroyed then
		return nil
	end
	const modelData = ModelHelper.ReadyModelFromRep(entity, player)

	local configName: string? = entity.entityConfig.NAME
	if configName == "DEFAULT" then
		configName = nil
	end

	local cframe = entity.latestCFrame or CFrame.identity
	local time = entity.lastClientClock or 0

	if entity.isContextOwner then
		const primaryPart = Entity.GetPrimaryPart(entity)
		if primaryPart then
			cframe = primaryPart.CFrame
		end

		time = os.clock()
	end

	return {
		id = entity.id,
		generation = entity.generation, ownershipRevision = entity.ownershipRevision or 0,
		sequence = entity._receivedSequence or entity._sendSequence or 0,
		_player = entity._player,
		networkOwner = entity.networkOwner,
		cframe = cframe,
		time = time,
		config = configName,

		model = modelData,

		paused = entity.paused,
		autoUpdatePosition = entity.autoUpdatePosition,
		isHalfTicked = entity.isHalfTicked,
		_data = entity._data,
		_lockedCFReplication = entity._lockedCFReplication,
		_interpolationMode = entity._interpolationMode,
		_humanoidState = entity._humanoidState,
		_humanoidDisabledStates = entity._humanoidDisabledStates,

		mountParentId = entity.mountParentId,
		mountOffset = entity.mountOffset,
		broadPhase = entity.broadPhase :: any,
	}
end

local playerReplicateTotal = 0
local playerReplicateCount = 0
const function ReplicatePlayer(player: Player)
	const holder = EntityGrid.GetEntityHolder(player)
	if not holder then
		return
	end
	debug.profilebegin("ReplicatePlayer")
	const replicatedOLD = holder.REPLICATED -- Leftovers will be removed
	const replicated = table.clone(replicatedOLD)
	holder.REPLICATED = replicated

	const holderEntityAdded = holder.EntityAdded
	const holderEntityRemoving = holder.EntityRemoving
	const normal = holder.NORMAL
	const half = holder.HALF

	const toSendFull = {}
	const toRemove = {}
	const clientOwned = {}
	const clientReliable = {}
	const entityChanges = {}

	const normalBuffers: BufferHolder = {}
	const halfBuffers: BufferHolder = {}
	const normalStops: BufferHolder = {}
	const halfStops: BufferHolder = {}
	const frameTimeNow = Ticker.GetGlobalTick()

	const function HandleClientEntities(entity: Types.Entity)
		if entity.arriveFrame ~= frameTimeNow then -- (time will be the same during the same frame)
			return
		end
		if entity.networkOwner == player then
			return
		end
		const clientTime = entity.lastClientClock or 0
		const cframeBuffer = entity.cframeBuffer :: buffer
		const reliable = bit32.band(buffer.readu8(cframeBuffer, 2), 12) ~= 0 -- teleport or stop
		const target = if reliable then clientReliable else clientOwned
		if not target[clientTime] then
			target[clientTime] = {}
		end

		table.insert(target[clientTime], cframeBuffer)
	end

	const function Handle(entity: Types.Entity, isNormal: boolean)
		if entity.destroyed then
			return
		end
		replicated[entity] = true
		if not replicatedOLD[entity] then
			holderEntityAdded:Fire(entity)
			table.insert(toSendFull, GetEntityFullData(player, entity))
			return
		end
		if entity._changes then
			table.insert(entityChanges, entity._changes)
		end
		replicatedOLD[entity] = nil
		if entity.paused then
			return
		end

		const isServerOwned = entity.isContextOwner
		if not isServerOwned then
			HandleClientEntities(entity)
			return
		end

		const ticker = entity._ticker
		if not (ticker and ticker.tickedFrame == frameTimeNow) then
			return
		end

		const isHalf = entity.isHalfTicked or not isNormal
		const cframeBuffer = entity.cframeBuffer

		if cframeBuffer and (entity._idleTicks or 0) > 0 then
			AddBuffer(isHalf and halfStops or normalStops, ticker, cframeBuffer)
			return
		end

		if isHalf and not ticker.tickedHalf then
			return
		end

		const toSend = if isHalf then cframeBuffer or entity._halfBuffer else cframeBuffer
		if toSend then
			AddBuffer(isHalf and halfBuffers or normalBuffers, ticker, toSend)
		end
	end
	const startTime = os.clock()
	for _, entity in normal do
		Handle(entity, true)
	end
	for _, entity in half do
		Handle(entity, false)
	end

	for entity, _ in replicatedOLD do
		replicated[entity] = nil
		holderEntityRemoving:Fire(entity)
		table.insert(toRemove,{id=entity._lastId or entity.id,generation=entity.generation,
			preserveModel=entity._preserveModelOnRemoval==true,anchored=entity._removalAnchor})
	end

	FlushClientOwned(player, clientOwned)
	FlushEntities(player, normalBuffers)
	FlushEntities(player, halfBuffers, true)

	FlushClientOwned(player, clientReliable, SafeReplicateEvent)
	FlushEntities(player, normalStops, false, SafeReplicateEvent)
	FlushEntities(player, halfStops, true, SafeReplicateEvent)

	if #toRemove > 0 or #toSendFull > 0 or #entityChanges > 0 then
		ReliableEvent:FireClient(player, toSendFull, toRemove, entityChanges)
	end
	debug.profileend()
	const endTime = os.clock()
	playerReplicateTotal += endTime - startTime
	playerReplicateCount += 1
end

local lastStatTime = os.clock()

if RunService:IsServer() then
	RunService.Heartbeat:Connect(function()
		Stats.REPLICATE_PLAYER_TIME_MS = playerReplicateTotal / math.max(playerReplicateCount, 1) * 1000
		if os.clock() - lastStatTime > 1 then
			Stats.BYTES_SENT_PER_SEC = BytesSentPerSec
			Stats.PACKETS_SENT_PER_SEC = PacketsSentPerSec
			BytesSentPerSec = 0
			PacketsSentPerSec = 0
			lastStatTime = os.clock()
			playerReplicateTotal = 0
			playerReplicateCount = 0
		end
	end)
end

return {
	ReplicatePlayer = ReplicatePlayer,
}
