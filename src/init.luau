--!strict
-- Chrono V3: server historical contact evidence. No automatic gameplay/network side effects.
local Guard=require(script.Guard)
local Contract=require(script.Contract)
local History=require(script.History)
local Shapes=require(script.Shapes)
local Types=require(script.Types)
local API={Shapes=Shapes,Version="3.1.0"}
-- Optional explanation helper. It never changes the result or runs a hit check.
function API.Explain(reason: (string | {reason: string})?): Types.Explanation return require(script.Help).Explain(reason) end
local Methods={} Methods.__index=Methods
local private=setmetatable({}, {__mode="k"})
local function session(self)
	local s=assert(private[self],"This Chrono instance was destroyed, or the call used the wrong object.")
	assert(not s.inCallback,"Do not call Chrono again from inside a position or rule function. Return its data first.")
	return s
end
local function call(s,callback,...)
	s.inCallback=true
	local out=table.pack(Contract.Call(callback,...))
	s.inCallback=false
	return table.unpack(out,1,out.n)
end
local function bounded(n,lo,hi) return Guard.Number(n) and n>=lo and n<=hi end
local function name(n) return type(n)=="string" and #n>0 and #n<=64 end
local function frozenResult(ok,reason,fields)
	local out=fields or {} out.ok=ok out.reason=reason
	if not out.contacts then out.contacts=table.freeze({}) end
	return table.freeze(out)
end
local function failure(s,reason,fields)
	s.stats.rejected+=1 s.stats.lastRejection=reason
	return frozenResult(false,reason,fields)
end
local function fresh(s)
	local ok,now=call(s,s.clock)
	if not ok or not Guard.Number(now) then return nil,"clock_fault" end
	if not s.time then return nil,"capture_required" end
	if now<s.time-1e-6 then return nil,"clock_reversed" end
	if now-s.time>s.maxGap then return nil,"capture_stale" end
	return now
end
function API.new(options: Types.Options?): Types.Service
	assert(game:GetService("RunService"):IsServer(),"Chrono V3 runs on the server")
	local o=options or {}
	local seconds,rate,gap=o.seconds or 0.6,o.rate or 60,o.maxGap or 0.075
	assert(bounded(seconds,0.05,10) and bounded(rate,1,240) and bounded(gap,0.001,1),"Use seconds=0.05 to 10, rate=1 to 240, and maxGap=0.001 to 1. These control saved-position storage.")
	assert(bounded(o.maxRewind or 0,0,seconds),"maxRewind must be zero or a positive number no greater than seconds (the time you keep past positions).")
	assert(o.clock==nil or type(o.clock)=="function","clock must be a function that returns server time in seconds, or leave it unset.")
	assert(o.resolveRewind==nil or type(o.resolveRewind)=="function","resolveRewind must be a function that returns an approved earlier-time delay, or leave it unset.")
	assert(o.world==nil or type(o.world)=="function","world must be an obstacle-check function, or leave it unset.")
	local self=setmetatable({},Methods)
	private[self]={clock=o.clock or function() return workspace:GetServerTimeNow() end,
		seconds=seconds,capacity=math.ceil(rate*seconds)+2,maxGap=gap,maxRewind=o.maxRewind or 0,
		resolveRewind=o.resolveRewind,world=o.world,actors={},actions={},actionCount=0,roster=0,
		stats={captures=0,queries=0,accepted=0,rejected=0,contacts=0,providerFaults=0,lastRejection="none"}}
	return self :: any -- Public method types help Studio autocomplete; checks above still run.
end
function Methods:Track(id,binding)
	local s=session(self)
	assert(name(id) and type(binding)=="table" and name(binding.kind),"Track needs short text id and kind names. Example: id='player-12', kind='player'.")
	assert(not s.actors[id],"This id is already tracked. Call Untrack before deliberately registering a replacement.")
	assert(type(binding.capture)=="function","Track needs capture=function(time) ... end to supply the object's position, hitboxes and game values.")
	assert(bounded(binding.maxSpeed,0,4096) and bounded(binding.maxRadius,0.001,512),"Set maxSpeed from 0 to 4096 studs/second and maxRadius from 0.001 to 512 studs. They must describe your allowed movement and hitbox extent.")
	local trust=binding.trust or "unverified"
	assert(trust=="unverified" or trust=="serverValidated" or trust=="serverSimulated","Use trust='unverified', 'serverValidated' or 'serverSimulated'. Choose a trusted label only after your server actually checks or calculates the data.")
	local count=0 for _ in s.actors do count+=1 end assert(count<256,"This instance already tracks 256 objects. Remove objects no longer needed before adding another.")
	s.actors[id]={id=id,kind=binding.kind,capture=binding.capture,trust=trust,status="awaiting_capture",faults=0,
		history=History.new({seconds=s.seconds,capacity=s.capacity,maxGap=s.maxGap,maxSpeed=binding.maxSpeed,maxRadius=binding.maxRadius})}
	s.roster+=1
end
function Methods:Untrack(id)
	local s=session(self) if not s.actors[id] then return false end
	s.actors[id]=nil s.roster+=1 return true
end
function Methods:Discontinuity(id,reason)
	local s=session(self) local actor=assert(s.actors[id],"actor not tracked")
	local ok,now=call(s,s.clock) assert(ok and Guard.Number(now),"clock fault")
	actor.history:Break(math.max(now,s.time or now)) actor.status=reason or "discontinuity" actor.quarantined=false
end
-- Invoke after your authoritative simulation. All providers must describe the same instant.
-- An optional timestamp supports a fixed-step server simulation using this clock domain.
function Methods:Capture(time)
	local s=session(self)
	local ok,now=call(s,s.clock)
	if not ok or not Guard.Number(now) then return frozenResult(false,"clock_fault") end
	time=time or now
	if not Guard.Number(time) or time>now+1e-6 or now-time>s.maxGap then return frozenResult(false,"invalid_capture_time") end
	if s.time and time<=s.time then return frozenResult(false,"non_monotonic") end
	s.time=time s.stats.captures+=1
	local faults={}
	for id,actor in s.actors do
		if actor.quarantined then table.insert(faults,table.freeze({id=id,reason="quarantined"})) continue end
		local called,snapshot=call(s,actor.capture,time)
		local pushed,reason=false,"provider_fault"
		if called then
			-- Validation itself can encounter an erroneous table metamethod from an adapter.
			local validated,accepted,why=call(s,function() return actor.history:Push(time,snapshot) end)
			pushed=validated and accepted==true
			reason=if validated then why else "invalid_snapshot"
		end
		if not pushed then
			actor.history:Break(time) actor.faults+=1 s.stats.providerFaults+=1
			actor.status=reason actor.quarantined=true table.insert(faults,table.freeze({id=id,reason=reason}))
		else actor.status="captured" end
	end
	for token,action in s.actions do
		if time>action.started+action.close or action.roster~=s.roster then s.actions[token]=nil s.actionCount-=1 end
	end
	return frozenResult(#faults==0,if #faults==0 then "captured" else "capture_fault",{time=time,faults=table.freeze(faults)})
end
-- Call only after your existing server move/action service authorizes the action.
-- No client-facing RemoteEvent is created. Context is consumed only by YOUR timing resolver.
function Methods:BeginAction(actorId,profile,approvedContext)
	local s=session(self) local now,err=fresh(s)
	if not now then return nil,err end
	local actor=s.actors[actorId] if not actor then return nil,"actor_missing" end
	if actor.trust=="unverified" then return nil,"unverified_source" end
	if type(profile)~="table" then return nil,"invalid_profile" end
	local shape=Shapes.Copy(profile.shape)
	local opening,closing=profile.opens or 0,profile.closes or 0.25
	if not shape or not bounded(opening,0,10) or not bounded(closing,opening,10)
		or not bounded(profile.maxReach or 32,0,4096) or Shapes.Reach(shape)>(profile.maxReach or 32)
		or not Guard.Integer(profile.maxTargets or 1,1,256) then return nil,"invalid_profile" end
	if profile.eligible~=nil and type(profile.eligible)~="function" then return nil,"invalid_profile" end
	if profile.world~=nil and type(profile.world)~="boolean" then return nil,"invalid_profile" end
	if profile.world and (not s.world or shape.kind~="sweep") then return nil,"world_provider_or_shape" end
	if type(profile.targets)~="table" then return nil,"target_kinds_required" end
	local kinds,count={},0
	for _,kind in profile.targets do
		if not name(kind) then return nil,"invalid_target_kind" end kinds[kind]=true count+=1
	end
	if count==0 or count>32 then return nil,"target_kinds_required" end
	local rewind=0
	if s.resolveRewind then
		local resolved,value=call(s,s.resolveRewind,actorId,approvedContext,s.time)
		if not resolved or not bounded(value,0,s.maxRewind) then return nil,"rewind_rejected" end rewind=value
	end
	local source,reason=actor.history:Sample(s.time-rewind,now)
	if not source then return nil,"source_"..reason end
	local actorActions=0 for _,a in s.actions do if a.actor==actorId then actorActions+=1 end end
	if s.actionCount>=512 or actorActions>=4 then return nil,"action_capacity" end
	local token=table.freeze({})
	s.actions[token]={actor=actorId,epoch=actor.history.epoch,roster=s.roster,started=s.time,
		open=opening,close=closing,shape=shape,kinds=table.freeze(kinds),eligible=profile.eligible,
		world=profile.world==true,maxTargets=profile.maxTargets or 1,rewind=rewind,hit={},totalHits=0}
	s.actionCount+=1
	return token
end
function Methods:EndAction(token)
	local s=session(self) if not s.actions[token] then return false end
	s.actions[token]=nil s.actionCount-=1 return true
end
function Methods:Query(token)
	local s=session(self) s.stats.queries+=1
	local action=s.actions[token] if not action then return failure(s,"invalid_action") end
	local now,err=fresh(s) if not now then return failure(s,err) end
	if action.roster~=s.roster then return failure(s,"roster_changed") end
	local actor=s.actors[action.actor]
	if not actor or actor.history.epoch~=action.epoch then return failure(s,"source_epoch_changed") end
	local elapsed=s.time-action.started
	if elapsed<action.open then return failure(s,"not_active") end
	if elapsed>action.close then return failure(s,"action_expired") end
	if action.lastTime==s.time then return failure(s,"duplicate_query") end
	if action.totalHits>=action.maxTargets then return failure(s,"action_spent") end
	local time=s.time-action.rewind
	local source,reason=actor.history:Sample(time,now)
	if not source then return failure(s,"source_"..reason) end
	local transformed,query=Contract.Call(Shapes.At,action.shape,source.root)
	if not transformed then return failure(s,"shape_out_of_bounds") end
	local fraction=1 local blocked=false
	if action.world then
		local called,cover=call(s,s.world,time,now,query)
		if not called or type(cover)~="table" or cover.covered~=true or type(cover.blocked)~="boolean"
			or not bounded(cover.fraction,0,1) then return failure(s,"world_unknown") end
		blocked=cover.blocked fraction=if blocked then cover.fraction else 1
	end
	local contacts={}
	for id,target in s.actors do
		if id==action.actor or not action.kinds[target.kind] or action.hit[id] then continue end
		-- A missing target can hide a closer contact. Never return a partial success.
		if target.trust=="unverified" then return failure(s,"unverified_target",{actor=id}) end
		local snapshot,why=target.history:Sample(time,now)
		if not snapshot then return failure(s,"target_"..why,{actor=id}) end
		if action.eligible then
			local called,allowed=call(s,action.eligible,source.state,snapshot.state,id,target.kind)
			if not called or type(allowed)~="boolean" then return failure(s,"rules_fault",{actor=id}) end
			if not allowed then continue end
		end
		local best,zoneName=nil,nil
		for zone,volume in snapshot.zones do
			local t=Shapes.Intersect(query,volume)
			-- Cover wins exact ties. With no cover callback, include sweep endpoint tangency.
			if t and (t<fraction or (not blocked and t<=fraction)) and (not best or t<best or (t==best and zone<zoneName)) then best=t zoneName=zone end
		end
		if best then
			local distance=if query.kind=="sweep" then (query.finish-query.start).Magnitude*best else 0
			table.insert(contacts,table.freeze({id=id,kind=target.kind,zone=zoneName,distance=distance,fraction=best,
				time=time,epoch=snapshot.epoch,state=snapshot.state,root=snapshot.root}))
		end
	end
	table.sort(contacts,function(a,b) if a.fraction~=b.fraction then return a.fraction<b.fraction end return a.id<b.id end)
	while #contacts>action.maxTargets-action.totalHits do table.remove(contacts) end
	-- Commit duplicate suppression only after every relevant provider/rule/world check passed.
	for _,contact in contacts do action.hit[contact.id]=true end
	action.totalHits+=#contacts action.lastTime=s.time
	s.stats.accepted+=1 s.stats.contacts+=#contacts
	return frozenResult(true,"covered",{time=time,capturedAt=s.time,rewind=action.rewind,source=source,
		contacts=table.freeze(contacts),shape=query})
end
function Methods:Inspect()
	local s=session(self) local actors={}
	for id,a in s.actors do
		local row=a.history:Latest()
		table.insert(actors,table.freeze({id=id,kind=a.kind,declaredTrust=a.trust,status=a.status,
			captured=row~=nil,latest=if row then row.time else nil,epoch=a.history.epoch,faults=a.faults}))
	end
	table.sort(actors,function(a,b) return a.id<b.id end)
	return table.freeze({version=API.Version,time=s.time,actors=table.freeze(actors),activeActions=s.actionCount,
		stats=table.freeze(table.clone(s.stats)),worldEnabled=s.world~=nil,maxRewind=s.maxRewind})
end
function Methods:Destroy() session(self) private[self]=nil end
return table.freeze(API)
