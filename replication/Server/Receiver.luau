--!native
const RunService = game:GetService("RunService")
const Players = game:GetService("Players")
const Receiver = {}

const Shared = script.Parent.Parent.Shared
const Types = require(Shared.Types)

type MiddleMan = {
	priority: number,
	func: (player: Player, entity: Types.Entity, cframe: CFrame, arriveTime: number) -> boolean,
}
const MiddleMans: { [string]: MiddleMan } = {}
local SortedMiddleMans: { MiddleMan } = {}
const Ticker = require(Shared.Ticker)
const InterpolationMath = require(Shared.InterpolationMath)
const Warn = require(Shared.Warn)
const ServerClock = require(script.Parent.ServerClock)
const Holder = require(Shared.Holder)
const Entity = require(Shared.Entity)
const Config = require(Shared.Config)
const ClockUnwrap = require(Shared.ClockUnwrap)
const Stats = require(Shared.Stats).SERVER
const Protocol = require(Shared.Protocol)
const StateGate = require(Shared.StateGate)
const RateBudget = require(Shared.RateBudget)
const ExperimentalPrediction = require(Shared.ExperimentalPrediction)
local budgets, heartbeats = {}, {}
local function refused(reason) Stats.REJECTED_PACKETS = (Stats.REJECTED_PACKETS or 0) + 1 Stats.LAST_PACKET_REJECTION = reason end

const ClientClockWrap: ClockUnwrap.Store = {}
local BASE_MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER = 300

Config._WaitForLock(function()
	BASE_MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER = Config._GetConfig("MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER")
end)

local BytesReceived = 0

const UnreliableEvent = Shared.Remotes.Replicate
const SafeReplicateEvent = Shared.Remotes.SafeReplicate

const BASE_TELEPORT_TIME_THRESHOLD = 0.5

const function FireMiddleMans(player: Player, entity: Types.Entity, cframe: CFrame, arriveTime: number): boolean
	if #SortedMiddleMans == 0 then
		return false
	end
	debug.profilebegin("FireMiddleMans")
	for _, mmData in SortedMiddleMans do
		const block = mmData.func(player, entity, cframe, arriveTime)
		if block then
			debug.profileend()
			return true
		end
	end
	debug.profileend()
	return false
end
const function CalculateMaxThroughputForPlayer(player: Player): number
	local numberOfEntities = 0
	for _ in (Holder._clientOwned[player] or {}) :: any do
		numberOfEntities += 1
	end
	return BASE_MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER + numberOfEntities * Protocol.FullBytes
end

const function HandleEntity(
	player: Player,
	id: number,
	serverClock: number,
	clientClock: number,
	cframe: CFrame,
	copyB: buffer,
	isTeleport: boolean,
	isStop: boolean,
	generation: number, ownershipRevision: number, sequence: number
)
	const entity = Holder.GetEntityFromId(id)
	if not StateGate.Check(entity,{generation=generation,ownershipRevision=ownershipRevision,sequence=sequence},player) then
		return
	end

	const position = cframe.Position
	const sum = position.X + position.Y + position.Z
	if sum ~= sum or math.abs(sum) == math.huge then -- NaN or inf
		return
	end

	const teleportTime = entity._teleport
	const ping = math.max(player:GetNetworkPing(), 0) + 0.05

	const withinTeleportThreshold = teleportTime and os.clock() - teleportTime < (BASE_TELEPORT_TIME_THRESHOLD + ping)
	if isTeleport then
		if withinTeleportThreshold then
			entity._teleport = nil
		else
			const packed = buffer.readu8(copyB, 2)
			buffer.writeu8(copyB, 2, bit32.band(packed, bit32.bnot(4)))
		end
	elseif withinTeleportThreshold then
		return
	end

	if entity.lastClientClock and clientClock < entity.lastClientClock then
		return
	end

	if isStop and entity.snapshot and entity.snapshot.stoppedAt then
		isStop = false
		const packed = buffer.readu8(copyB, 2)
		buffer.writeu8(copyB, 2, bit32.band(packed, bit32.bnot(8)))
	end

	debug.profilebegin("HandleEntity.FireMiddleMans")
	if FireMiddleMans(player, entity, cframe, serverClock) then
		debug.profileend()
		return
	end
	debug.profileend()
	local velocity = nil
	if Config.FLAGS.SERVER_VELOCITY_FIX and entity.snapshot and entity.lastClientClock then
		const latest = entity.snapshot:GetLatest()
		const lastClientClock = entity.lastClientClock
		const baseTickRate = entity.entityConfig.TICK_RATE
		const tickrate = if entity.isHalfTicked then baseTickRate * 2 else baseTickRate
		if latest then
			velocity = InterpolationMath.CalculateVelocity(
				latest.value.Position,
				lastClientClock,
				cframe.Position,
				clientClock,
				tickrate
			)
		end
	end
	entity._receivedSequence = sequence
	entity.sourceTime = clientClock
	entity.receivedAt = serverClock
	entity.sourceGrade = "observed"
	const pushed = if isStop
		then Entity._PushStopped(entity, serverClock, cframe)
		else Entity._Push(entity, serverClock, cframe, velocity)
	if pushed then
		ExperimentalPrediction.Observe(entity,clientClock,cframe,if isStop then Vector3.zero else nil,"owner-clock",isTeleport)
		entity.arriveFrame = Ticker.GetGlobalTick()

		entity.lastClientClock = clientClock
		entity.cframeBuffer = copyB
		-- If we update the model on native this will cause the client to also update the model
		if entity.modelReplicationMode == "NATIVE" and not entity._lockedCFReplication then
			return true
		end
		Entity._SetPartCFrame(entity, cframe)
	end
	return pushed
end

const function OnReceive(player: Player, data: buffer)
	if typeof(data) ~= "buffer" or player.Parent == nil then return end
	local now = os.clock()
	local budget = budgets[player]
	if not budget then budget = RateBudget.New(CalculateMaxThroughputForPlayer(player)*60, Protocol.MaxPayload*4, now) budgets[player] = budget end
	budget.rate=CalculateMaxThroughputForPlayer(player)*60
	if not RateBudget.Allow(budget, buffer.len(data), now) then refused("packet_rate") return end
	local rows, reason = Protocol.Decode(data)
	if not rows then refused(reason) return end
	BytesReceived += buffer.len(data)
	-- No clock/history/model is touched until the complete packet decoded successfully.
	local acceptedTime
	for _, row in rows do
		local thread=coroutine.create(HandleEntity)
		local ok, accepted = coroutine.resume(thread, player, row.id, now, row.time, row.frame, row.record,
			row.teleport, row.stop, row.generation, row.ownershipRevision, row.sequence)
		if not ok then refused("packet_handler")
		elseif coroutine.status(thread)~="dead" then coroutine.close(thread) refused("packet_handler_yielded")
		elseif accepted then acceptedTime=if acceptedTime then math.max(acceptedTime,row.time) else row.time end
	end
	if acceptedTime then ServerClock.Store(player, acceptedTime) end
end

const function SortMiddleMans()
	SortedMiddleMans = {}
	for _, data in MiddleMans do
		table.insert(SortedMiddleMans, data)
	end
	table.sort(SortedMiddleMans, function(a: MiddleMan, b: MiddleMan)
		return a.priority > b.priority
	end)
end

--[=[
	Registers a middle man function that can intercept incoming entity updates.

	@param name The unique name of the middle man
	@param priority The priority of the middle man ( higher priority runs first )
	@param func The function to call. Should return true to block the update, else allow it.
]=]
function Receiver.RegisterMiddleMan(
	name: string,
	priority: number,
	func: (
		player: Player,
		entity: Types.Entity,
		cframe: CFrame,
		arriveTime: number
	) -> boolean
)
	MiddleMans[name] = { priority = priority, func = func }
	SortMiddleMans()
end

--[=[
	Unregisters a middle man function.
	@param name The unique name of the middle man
]=]
function Receiver.UnregisterMiddleMan(name: string)
	MiddleMans[name] = nil
	SortMiddleMans()
end

if RunService:IsServer() then
	local lastByteCheckTime = 0
	RunService.Heartbeat:Connect(function()

		if os.clock() - lastByteCheckTime > 1 then
			Stats.BYTES_RECEIVED_PER_SEC = BytesReceived
			BytesReceived = 0
			lastByteCheckTime = os.clock()
		end
	end)
	UnreliableEvent.OnServerEvent:Connect(OnReceive)
	SafeReplicateEvent.OnServerEvent:Connect(OnReceive)

	Shared.Remotes.ClientHeartbeat.OnServerEvent:Connect(function(player: Player, seconds: number)
		if type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 or seconds > 1e12 or player.Parent == nil then
			return
		end
		local b = heartbeats[player] if not b then b = RateBudget.New(1, 4, os.clock()) heartbeats[player] = b end
		if not RateBudget.Allow(b, 1, os.clock()) then return end
		const clientClock = ClockUnwrap.seatFullFor(ClientClockWrap, player, seconds)
		ServerClock.Store(player, clientClock)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ClientClockWrap[player] = nil
		budgets[player], heartbeats[player] = nil, nil
	end)
end

function Receiver._GetClientClockRaws(): { { player: Player, raw: number, offset: number } }
	const out = {}
	for player, state in ClientClockWrap do
		if state.lastRaw then
			table.insert(out, { player = player, raw = state.lastRaw, offset = state.offset })
		end
	end
	return out
end

return Receiver
