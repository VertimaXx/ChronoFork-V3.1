const Players = game:GetService("Players")
const LocalPlayer = Players.LocalPlayer

const Shared = script.Parent.Parent.Shared
const Holder = require(Shared.Holder)
const Types = require(Shared.Types)
const Entity = require(Shared.Entity)
const Protocol = require(Shared.Protocol)
const Sequence = require(Shared.Sequence)
local records = {}
const ServerReplicate = require(script.Parent.Parent.Server.Replicate)
const UnreliableEvent = Shared.Remotes.Replicate
const SafeReplicateEvent = Shared.Remotes.SafeReplicate

const ClientOwned = Holder._clientOwned
if not ClientOwned[LocalPlayer] then
	ClientOwned[LocalPlayer] = {}
end
const PlayerEntities = ClientOwned[LocalPlayer]

local clock = 0
local hasTeleport = false
local hasStop = false

const function FireEvent(entity: Types.Entity, eventName: string, ...: any)
	const events = entity._events
	if not events then
		return
	end
	const signal = events[eventName]
	if signal then
		signal:Fire(entity, ...)
	end
end

const function Flush()
	for _, packet in Protocol.Pack(records) do
		if hasTeleport or hasStop then SafeReplicateEvent:FireServer(packet) else UnreliableEvent:FireServer(packet) end
	end
	table.clear(records)
end
const function WriteEntity(id, cf, fullCFrame, halfTicked, teleport, stop)
	local entity = Holder.GetEntityFromId(id)
	if not entity or not entity.generation then return end
	entity._sendSequence = Sequence.Next(entity._sendSequence)
	table.insert(records, Protocol.Record(entity, clock, cf, fullCFrame, halfTicked, teleport, stop))
end
--//This is to catch an edge case where the primarypart hasn't been replicated
const function CheckLocker(entity: Types.Entity)
	if entity._cfLockFailed then
		if entity._lockedCFReplication and entity.isContextOwner and not entity._player then
			const part = Entity._GetPart(entity)
			if part then
				Entity._LockPartPhysicsReplication(part)
				entity._cfLockFailed = nil
			end
		else
			entity._cfLockFailed = nil
		end
	end
end

const function CheckEntity(entity: Types.Entity)
	if entity.destroyed or entity.paused then
		return
	end

	const config = entity.entityConfig
	local tickRate = config.TICK_RATE

	if entity.isHalfTicked then
		tickRate = tickRate * 2
	elseif entity.isHalfTicked == nil then
		return
	end

	const now = clock
	const lastTime = entity.lastReplicatedTime or 0
	const difference = now - lastTime

	if difference < tickRate then
		return
	end
	CheckLocker(entity)
	FireEvent(entity, "Ticked", difference)
	const primaryPart = Entity.GetPrimaryPart(entity)

	if entity.autoUpdatePosition and primaryPart then
		Entity._Push(entity, now, primaryPart.CFrame)
	end

	const currentCFrame = entity.latestCFrame
	const lastCFrame = entity.lastCheckedCFrame
	if currentCFrame and ServerReplicate.HasCFrameChanged(lastCFrame, currentCFrame) then
		entity.lastReplicatedTime = now
		const fullCFrame = config.FULL_ROTATION
		entity.lastCheckedCFrame = currentCFrame
		const teleport = entity._teleport ~= nil
		hasTeleport = hasTeleport or teleport
		WriteEntity(entity.id, currentCFrame, fullCFrame, entity.isHalfTicked, teleport)
		entity._teleport = nil
		const step = if lastCFrame then currentCFrame.Position - lastCFrame.Position else Vector3.zero
		const paused = (entity._idleTicks or 0) > 0
		Entity._RecordMove(entity, step, if paused then math.max(math.round(difference / tickRate), 2) else 1)
	elseif currentCFrame then
		const idleTicks = difference // tickRate
		const stopAfter = entity._stopAfter or 1
		if idleTicks >= stopAfter and (entity._idleTicks or 0) < stopAfter then
			hasStop = true
			WriteEntity(entity.id, currentCFrame, config.FULL_ROTATION, entity.isHalfTicked, false, true)
		end
		entity._idleTicks = idleTicks
	end
end

const function Update()
	clock = os.clock()
	for entity in PlayerEntities do
		CheckEntity(entity)
	end

	Flush()
	hasTeleport = false
	hasStop = false
end

return {
	Update = Update,
}
