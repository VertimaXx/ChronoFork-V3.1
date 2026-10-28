-- VERY EXPERIMENTAL. Estimates are separate from entity/history CFrames.
-- No predicted frame is inserted into snapshots, serialized, or trusted for hits.
local Config=require(script.Parent.Config)
local Motion=require(script.Parent.MotionPredictor)
local P={}
local states=setmetatable({}, {__mode="k"})
local function enabled() return Config._GetConfig("EXPERIMENTAL_PREDICTION") end
local function options()
	local out={}
	for key,suffix in {maxHorizon="SECONDS",maxDistance="DISTANCE",maxSpeed="SPEED",maxAcceleration="ACCELERATION",
		maxTurnRate="TURN",maxAngularSpeed="ANGULAR",maxGap="GAP",teleportDistance="TELEPORT",learningSeconds="LEARNING"} do
		out[key]=Config._GetConfig("EXPERIMENTAL_PREDICTION_"..suffix)
	end
	return out
end
local function current(entity)
	local state=states[entity]
	if state and (state.generation~=entity.generation or state.revision~=entity.ownershipRevision
		or state.owner~=entity.networkOwner or state.modelObject~=entity.model) then
		states[entity]=nil state=nil
	end
	return state
end
function P.Reset(entity) states[entity]=nil end
function P.Observe(entity,time,frame,velocity,domain,discontinuity)
	if not enabled() then return false,"experimental_disabled" end
	if type(entity)~="table" or entity.destroyed or entity.paused then return false,"inactive_entity" end
	if not Motion.IsFinite(time) or not Motion.IsFrame(frame) or (velocity~=nil and not Motion.IsVector(velocity)) then return false,"invalid_sample" end
	domain=domain or "entity-time"
	if type(domain)~="string" or #domain>64 then return false,"invalid_clock_domain" end
	local state=current(entity)
	if state and state.domain~=domain then P.Reset(entity) state=nil end
	if not state then
		state={model=Motion.New(options()),domain=domain,generation=entity.generation,
			revision=entity.ownershipRevision,owner=entity.networkOwner,modelObject=entity.model,
			accepted=0,rejected=0}
		states[entity]=state
	end
	local ok,reason=state.model:Observe(time,frame,velocity,discontinuity)
	state.lastReason=reason
	if ok then state.sourceTime=time state.receivedAt=os.clock() state.accepted+=1 else state.rejected+=1 end
	return ok,reason
end
function P.Estimate(entity,targetSourceTime)
	if not enabled() then return nil,{status="experimental_disabled",experimental=true,trust="estimate"} end
	if type(entity)~="table" or entity.destroyed or entity.paused or entity.mountParentId then return nil,{status="inactive_entity",experimental=true,trust="estimate"} end
	local state=current(entity)
	if not state then return nil,{status="empty",experimental=true,trust="estimate"} end
	local frame,info=state.model:Predict(targetSourceTime)
	info.experimental=true info.trust="estimate" info.clockDomain=state.domain
	info.sourceGrade="observed-or-game-supplied; not upgraded by prediction"
	return frame,info
end
function P.EstimateCurrent(entity,sourceDelaySeconds)
	if not enabled() then return P.Estimate(entity,0) end
	if type(entity)~="table" then return nil,{status="inactive_entity",experimental=true,trust="estimate"} end
	local state=current(entity)
	if not state or not state.sourceTime then return P.Estimate(entity,0) end
	local delay=if sourceDelaySeconds==nil then Config._GetConfig("EXPERIMENTAL_PREDICTION_DELAY") else sourceDelaySeconds
	if not Motion.IsFinite(delay) or delay<0 or delay>0.5 then return nil,{status="invalid_delay",experimental=true,trust="estimate"} end
	local elapsed=math.max(0,os.clock()-state.receivedAt)
	local frame,info=P.Estimate(entity,state.sourceTime+elapsed+delay)
	info.timing="elapsed since receipt + explicit source-delay assumption"
	info.assumedSourceDelay=delay info.elapsedSinceReceipt=elapsed
	return frame,info
end
function P.Inspect(entity)
	local state=if type(entity)=="table" then current(entity) else nil
	return {experimental=true,enabled=enabled(),drawing=Config._GetConfig("EXPERIMENTAL_PREDICTION_DRAW"),
		active=state~=nil,accepted=if state then state.accepted else 0,rejected=if state then state.rejected else 0,
		lastReason=if state then state.lastReason else nil,
		clockDomain=if state then state.domain else nil,sourceTime=if state then state.sourceTime else nil,
		limits=options(),assumedSourceDelay=Config._GetConfig("EXPERIMENTAL_PREDICTION_DELAY"),trust="estimate"}
end
return table.freeze(P)
