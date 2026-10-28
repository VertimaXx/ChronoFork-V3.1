--!native
const RunService = game:GetService("RunService")
const Players = game:GetService("Players")
const Shared = script.Parent.Parent.Shared

const Warn = require(Shared.Warn)
const Entity = require(Shared.Entity)
const Events = require(Shared.Events)
const Holder = require(Shared.Holder)
const ModelHelper = require(Shared.ModelHelper)
const Types = require(Shared.Types)
const ClockUnwrap = require(Shared.ClockUnwrap)
const Stats = require(Shared.Stats).CLIENT
const ClientClock = require(script.Parent.ClientClock)
const Protocol = require(Shared.Protocol)
const StateGate = require(Shared.StateGate)
const ExperimentalPrediction = require(Shared.ExperimentalPrediction)

local BytesReceived = 0
local NewPerSec = 0
local RemovedPerSec = 0
local ChangesPerSec = 0

const SetTickMode = Entity._SetTickMode

const UnreliableEvent = Shared.Remotes.Replicate
const ReliableEvent = Shared.Remotes.ReplicateFull
const HeartbeatRemote = Shared.Remotes.Heartbeat
const ClientClockRelayRemote = Shared.Remotes.ClientClockRelay

const ServerWrap = ClockUnwrap.new()
const ClientOwnedWrap: ClockUnwrap.Store = {}

const function HandleRemoved(id: number, generation: number?, preserveModel: boolean?, anchored: boolean?)
	const entity = Holder.GetEntityFromId(id)
	if entity then
		if generation and entity.generation~=generation then return end
		Entity.Destroy(entity,preserveModel,anchored)
		return
	end
	Warn.high("Tried to remove non existent entity with id", id)
end

const function SetMountId(entity: Types.Entity, mountParentId: number?)
	entity.mountParentId = mountParentId
	Events._Signals.EntityMountChanged:Fire(entity, mountParentId)
end

const function SetMountOffset(entity: Types.Entity, mountOffset: CFrame?)
	entity.mountOffset = mountOffset or CFrame.identity
end

-- This maps SetValue keys to their functions
const ChangedLookUp = {
	networkOwner = Entity._SetEntityNetworkOwner,
	ownershipRevision = function(entity, revision)
		entity.ownershipRevision = revision entity._receivedSequence = nil entity._sendSequence = 0
	end,
	isHalfTicked = SetTickMode,
	_data = Entity.SetData,
	entityConfig = Entity.SetConfig,
	autoUpdatePosition = Entity.SetAutoUpdatePos,
	mountParentId = SetMountId,
	mountOffset = SetMountOffset,
	broadPhase = Entity.SetBroadPhase,
	_interpolationMode = Entity.SetInterpolationMode,
	_humanoidDisabledStates = Entity._SetHumanoidDisabledStates,
	_humanoidState = Entity._SetHumanoidState,
}

const function HandleChanges(changes: { id: number, data: { { any } } })
	const entity = Holder.GetEntityFromId(changes.id)
	if not entity then
		return
	end
	local modelData
	local modelChanged = false
	for _, pair in changes.data do
		const key = pair[1]
		const value = pair[2]

		const handler = ChangedLookUp[key]
		if handler then
			handler(entity, value)
		elseif key == "latestCFrame" then
			Entity.SetCFrame(entity, value)
		elseif key == "model" then
			modelData = value
			modelChanged = true -- value is nil when the model was cleared
		elseif key == "_player" then
			if value then
				Holder.SetAsCharacter(value, entity)
			else
				Holder.RemovePlayerCharacter(entity)
			end
		elseif key == "paused" then
			if value then
				Entity.PauseReplication(entity)
			else
				Entity.ResumeReplication(entity)
			end
		elseif key == "_lockedCFReplication" then
			entity._lockedCFReplication = value
			if not value then
				const part = Entity._GetPart(entity)
				if part then
					Entity._UnlockPartPhysicsReplication(part)
				end
			else
				Entity.SyncOwnerShip(entity)
			end
		else
			Warn.high("Unhandled entity change key:", key)
		end
	end

	if modelChanged then
		const model, modelType, handle = ModelHelper.CreateModelFromData(modelData)
		Entity.SetModel(entity, model, modelType :: any)
		entity._modelHandle = handle
	end
end

const function HandleNewEntity(data: Types.EntityReceivePacket)
	const model, modelType, handle = ModelHelper.CreateModelFromData(data.model)
	local cframe = data.cframe
	const localPlayer = Players.LocalPlayer
	-- initializes cframe for local character just in case client loads in a different spot
	if data.networkOwner == localPlayer and model and model == localPlayer.Character then
		const root = (model :: Model).PrimaryPart
		if root then
			cframe = root.CFrame
		end
	end
	const entity = Entity._new(data.config, model, modelType :: any, cframe)

	entity.id = data.id
	entity.generation = data.generation
	entity.ownershipRevision = data.ownershipRevision or 0
	entity._sendSequence = 0
	entity._receivedSequence = data.sequence
	entity._player = data._player
	entity._modelHandle = handle
	entity.paused = data.paused or false
	entity.autoUpdatePosition = data.autoUpdatePosition or false
	entity.isHalfTicked = data.isHalfTicked
	entity._data = data._data
	entity.mountParentId = data.mountParentId
	entity.mountOffset = data.mountOffset or CFrame.identity
	entity.broadPhase = data.broadPhase or entity.broadPhase
	entity._lockedCFReplication = data._lockedCFReplication or false
	entity._interpolationMode = data._interpolationMode

	Entity._Push(entity, data.time, cframe)

	Entity._SetEntityNetworkOwner(entity, data.networkOwner)
	entity._receivedSequence=data.sequence -- ownership setup may reset the stream

	Entity._SetHumanoidDisabledStates(entity, data._humanoidDisabledStates)
	Entity._SetHumanoidState(entity, data._humanoidState)
	SetTickMode(entity, data.isHalfTicked)
	Holder.RegisterEntity(entity)
end

const function PushCFrameFor(
	id: number,
	clientOwned: boolean,
	cframe: CFrame,
	time: number,
	isHalfTick: boolean,
	teleport: boolean?,
	isStop: boolean?,
	generation: number, ownershipRevision: number, sequence: number
): boolean
	const entity = Holder.GetEntityFromId(id)
	if not entity then
		Warn.high("Received update for non existent entity with id", id)
		return false
	end
	
	if entity.isContextOwner or clientOwned ~= (entity.networkOwner ~= nil)
		or not StateGate.Check(entity,{generation=generation,ownershipRevision=ownershipRevision,sequence=sequence}) then
		return false
	end

	const withinTeleportThreshold = entity._teleport and os.clock() - entity._teleport < 0.5
	if withinTeleportThreshold then
		if teleport then
			entity._teleport = nil
		else
			return false
		end
	end
	if teleport then
		entity._ownerChangedAt = nil
		entity._ownerSmoothing = nil
	end

	if clientOwned then
		const renderCache = entity._clientClock
		if renderCache then
			if isHalfTick then
				renderCache:SetTickRate(renderCache._baseTickRate * 2)
			else
				renderCache:SetTickRate(renderCache._baseTickRate)
			end
			if isStop then
				renderCache:OnStop(time)
			else
				renderCache:OnSnapShot(time)
			end
		end
	else
		const renderCaches = entity.entityConfig.CLIENT_CLOCK
		if renderCaches then
			const renderCache = isHalfTick and renderCaches.HALF or renderCaches.NORMAL
			if renderCache and isStop then
				renderCache:OnStop(time)
			elseif renderCache then
				renderCache:OnSnapShot(time)
			end
		end
	end

	if entity.isHalfTicked ~= isHalfTick then
		SetTickMode(entity, isHalfTick)
	end
	entity.isHalfTicked = isHalfTick

	entity._receivedSequence = sequence
	if isStop then
		Entity._PushStopped(entity, time, cframe)
	else
		Entity._Push(entity, time, cframe)
	end
	ExperimentalPrediction.Observe(entity,time,cframe,if isStop then Vector3.zero else nil,
		if clientOwned then "owner-clock" else "server-clock",teleport)
	return true
end

const function HandlePacket(b, clientOwned, forceStop)
	local rows, reason = Protocol.Decode(b)
	if not rows then Stats.REJECTED_PACKETS = (Stats.REJECTED_PACKETS or 0)+1 Stats.LAST_PACKET_REJECTION = reason return end
	BytesReceived += buffer.len(b)
	for _, row in rows do
		PushCFrameFor(row.id, clientOwned, row.frame, row.time, row.half, row.teleport,
			forceStop or row.stop, row.generation, row.ownershipRevision, row.sequence)
	end
end
const function HandleClientOwned(b) HandlePacket(b, true, false) end
const function HandleServerOwned(b, isStop) HandlePacket(b, false, isStop) end

const function HandleUnreliable(id: string, data: buffer)
	if id == "X" then -- Server Owned
		HandleServerOwned(data)
	elseif id == "O" then -- Client Owned
		HandleClientOwned(data)
	else
		Warn.high("Unknown unreliable replicate id", id)
	end
end

const function HandleReliable(newEntities: { any }, removedEntities: { number }, entityChanges: { any })
	if removedEntities then
		for _, data in removedEntities do
			if type(data)=="table" then HandleRemoved(data.id,data.generation,data.preserveModel,data.anchored)
			else HandleRemoved(data) end
		end
		RemovedPerSec += #removedEntities
	end

	if newEntities then
		for _, data: any in newEntities do
			HandleNewEntity(data)
		end
		NewPerSec += #newEntities
	end

	if entityChanges then
		for _, changeData in entityChanges do
			HandleChanges(changeData)
		end
		ChangesPerSec += #entityChanges
	end
end

UnreliableEvent.OnClientEvent:Connect(HandleUnreliable)
ReliableEvent.OnClientEvent:Connect(HandleReliable)
Shared.Remotes.SafeReplicate.OnClientEvent:Connect(function(id: string, data: buffer)
	if id == "X" then
		HandleServerOwned(data, true)
	elseif id == "O" then
		HandleClientOwned(data)
	else
		Warn.high("Unknown replicate id", id)
	end
end)

HeartbeatRemote.OnClientEvent:Connect(function(time: number)
	const unwrapped = ClockUnwrap.seatFull(ServerWrap, time)
	for clock in ClientClock.serverOwnedClocks do
		clock:Refresh(unwrapped)
	end
end)

-- Syncs each player's clock offset from the server
ClientClockRelayRemote.OnClientEvent:Connect(function(list: { { player: Player, raw: number, offset: number } })
	if type(list) ~= "table" then
		return
	end
	for _, entry in list do
		const player = entry.player
		const raw = entry.raw
		const offset = entry.offset
		if player and player.Parent and type(raw) == "number" and type(offset) == "number" then
			local state = ClientOwnedWrap[player]
			if not state then
				state = ClockUnwrap.new()
				ClientOwnedWrap[player] = state
			end
			state.lastRaw = raw
			state.offset = math.max(state.offset, offset)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	ClientOwnedWrap[player] = nil
end)

local lastByteCheckTime = 0
RunService.Heartbeat:Connect(function()
	if os.clock() - lastByteCheckTime > 1 then
		if not Stats._PAUSE then
			Stats.BYTES_RECEIVED_PER_SEC = BytesReceived
			Stats.NEW_ENTITIES_PER_SEC = NewPerSec
			Stats.ENTITY_CHANGES_PER_SEC = ChangesPerSec
			Stats.ENTITY_REMOVALS_PER_SEC = RemovedPerSec
		end
		NewPerSec = 0
		RemovedPerSec = 0
		ChangesPerSec = 0
		BytesReceived = 0
		lastByteCheckTime = os.clock()
	end
end)

return nil
