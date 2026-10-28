-- Full-runtime development package. Contact Core 3.1 remains an independent service.
-- Requiring this module does not start movement replication.
require(script:WaitForChild("Await",30)).Ready(script)
local Core=require(script.Core)
local Types=require(script.Replication.Shared.Types)
export type Entity=Types.Entity
export type EntityConfig=Types.EntityConfig
export type EntityConfigInput=Types.EntityConfigInput
export type MODEL_REPLICATION_MODE=Types.MODEL_REPLICATION_MODE
export type SnapshotData<V,T> = Types.SnapshotData<V,T>
export type Snapshot<V,T> = Types.Snapshot<V,T>
export type Ticker=Types.Ticker
export type ClientClock=Types.ClientClock
export type InterpolationBuffer=Types.InterpolationBuffer
export type PlayerEntityHolder=Types.PlayerEntityHolder
export type Connection=Types.Connection
export type Event<F,T...> = Types.Event<F,T...>
export type Signal<F,T...> = Types.Signal<F,T...>
export type ReplicationRule=Types.ReplicationRule
export type EntityReceivePacket=Types.EntityReceivePacket
export type ClientEntitiesStats=Types.ClientEntitiesStats
export type ServerEntitiesStats=Types.ServerEntitiesStats
local F={Version="3.3.0-dev",CoreVersion=Core.Version,WireVersion=2,Shapes=Core.Shapes,new=Core.new,Explain=Core.Explain}
local replication
local function original()
	if not replication then replication=require(script.Replication) end
	return replication
end
function F.Start(config)
	assert(script:GetAttribute("ChronoForkRuntimeMode")~="Engine","This package uses the engine simulation adapter; do not start a second movement driver")
	local ok,authority=pcall(function() return workspace.AuthorityMode end)
	assert(not ok or authority~=Enum.AuthorityMode.Server,
		"This place uses Roblox server authority. Use Competitive.Simulation.Bind for its simulation; do not also start custom CFrame replication.")
	return original().Start(config)
end
function F.IsStarted() return replication~=nil and replication.IsStarted() end
function F.GetStartupState() return if replication then replication.GetStartupState() else "idle" end
F.Competitive=require(script.Competitive)
F.Experimental=table.freeze({Prediction=require(script.Replication.Shared.ExperimentalPrediction)})
-- Public original APIs and paths are retained in Replication. Existing Core calls
-- remain available through new/Shapes/Explain and the explicit Core child.
return setmetatable(F,{__index=function(_,key) return original()[key] end})
