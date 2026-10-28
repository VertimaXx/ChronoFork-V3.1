-- Read-only historical contact evidence with separate source and target times.
-- Move authorization/outcomes can use the existing Core action service.
local Core=script.Parent.Parent.Core
local Guard=require(Core.Guard)
local Shapes=require(Core.Shapes)
local Contract=require(Core.Contract)
local History=require(script.Parent.History)
local W={} W.__index=W
local function name(id) return type(id)=="string" and #id>0 and #id<=64 end
local function failure(reason,actor) return table.freeze({ok=false,reason=reason,actor=actor,contacts=table.freeze({})}) end
local function call(self,callback,...)
	self.inCallback=true local values=table.pack(Contract.Call(callback,...)) self.inCallback=false
	return table.unpack(values,1,values.n)
end
function W.new(options)
	local o=options or {}
	assert(game:GetService("RunService"):IsServer(),"EvidenceWorld runs on the server")
	local seconds,rewind=o.seconds or 0.6,o.maxRewind or 0.3
	assert(Guard.Number(seconds) and seconds>=0.05 and seconds<=10 and Guard.Number(rewind) and rewind>=0 and rewind<=seconds)
	return setmetatable({actors={},seconds=seconds,maxRewind=rewind,maxGap=o.maxGap or 0.075,
		clock=o.clock or function() return workspace:GetServerTimeNow() end,serial=0},W)
end
function W:Track(id,binding)
	assert(not self.inCallback,"Return from the game callback before changing tracked objects")
	assert(name(id) and not self.actors[id] and type(binding)=="table" and name(binding.kind))
	assert(binding.grade=="observed" or binding.grade=="serverValidated" or binding.grade=="serverSimulated")
	local count=0 for _ in self.actors do count+=1 end assert(count<256,"EvidenceWorld actor capacity")
	self.serial+=1
	self.actors[id]={id=id,kind=binding.kind,grade=binding.grade,lifetime=self.serial,
		history=History.new({seconds=self.seconds,maxGap=self.maxGap,capacity=binding.capacity or 128,maxSpeed=binding.maxSpeed or 4096,maxRadius=binding.maxRadius or 512})}
end
function W:Untrack(id) assert(not self.inCallback,"Return from the game callback before untracking") self.actors[id]=nil end
function W:Discontinuity(id,time,reason)
	assert(not self.inCallback,"Return from the game callback before resetting records")
	local actor=assert(self.actors[id],"Unknown actor") actor.history:Break(time,reason)
end
function W:Record(id,row)
	assert(not self.inCallback,"Return from the game callback before recording")
	local actor=assert(self.actors[id],"Unknown actor")
	if type(row)~="table" then return false,"invalid_record" end
	local copy=table.clone(row) copy.grade=actor.grade
	return actor.history:Push(copy)
end
function W:Query(request)
	if self.inCallback then return failure("reentrant_query") end
	if type(request)~="table" or not name(request.source) then return failure("invalid_request") end
	local source=self.actors[request.source] if not source then return failure("source_missing") end
	local ok,now=call(self,self.clock) if not ok or not Guard.Number(now) then return failure("clock_fault") end
	local sourceTime,targetTime=request.sourceTime,request.targetTime
	for _,time in {sourceTime,targetTime} do
		if not Guard.Number(time) or time>now+1e-6 or now-time>self.maxRewind then return failure("time_out_of_policy") end
	end
	-- nil fields do not appear in an array constructor's iteration.
	if not Guard.Number(sourceTime) or not Guard.Number(targetTime) then return failure("invalid_time") end
	local pose,why=source.history:Sample(sourceTime,now)
	if not pose then return failure("source_"..why,source.id) end
	local shape=Shapes.Copy(request.shape)
	if not shape then return failure("invalid_shape") end
	local reach=request.maxReach or 32
	if not Guard.Number(reach) or reach<0 or reach>4096 or Shapes.Reach(shape)>reach then return failure("reach_limit") end
	local transformed,worldShape=Contract.Call(Shapes.At,shape,pose.root)
	if not transformed then return failure("invalid_shape") end
	local kinds={} local n=0
	if type(request.targets)~="table" then return failure("target_kinds_required") end
	for _,kind in request.targets do if not name(kind) then return failure("invalid_target_kind") end kinds[kind]=true n+=1 end
	if n<1 or n>32 then return failure("invalid_target_kind") end
	local limit=request.maxTargets or 1
	if not Guard.Integer(limit,1,256) then return failure("invalid_target_limit") end
	if request.rule~=nil and type(request.rule)~="function" then return failure("invalid_rule") end
	local contacts={} local blocker=1 local blocked=false
	if request.world then
		if worldShape.kind~="sweep" or type(request.world)~="function" then return failure("world_provider_or_shape") end
		local called,cover=call(self,request.world,targetTime,now,worldShape)
		if not called or type(cover)~="table" or cover.covered~=true or type(cover.blocked)~="boolean"
			or not Guard.Number(cover.fraction) or cover.fraction<0 or cover.fraction>1 then return failure("world_unknown") end
		blocked=cover.blocked blocker=if blocked then cover.fraction else 1
	end
	for id,actor in self.actors do
		if id==request.source or not kinds[actor.kind] then continue end
		local target,reason=actor.history:Sample(targetTime,now)
		if not target then return failure("target_"..reason,id) end
		if request.rule then
			local called,allowed=call(self,request.rule,pose.state,target.state,id,actor.kind)
			if not called or type(allowed)~="boolean" then return failure("rules_fault",id) end
			if not allowed then continue end
		end
		local fraction,zone
		for key,volume in target.zones do
			local hit=Shapes.Intersect(worldShape,volume)
			if hit and (hit<blocker or (not blocked and hit<=blocker)) and (fraction==nil or hit<fraction or (hit==fraction and key<zone)) then fraction,zone=hit,key end
		end
		if fraction then table.insert(contacts,table.freeze({id=id,kind=actor.kind,zone=zone,fraction=fraction,root=target.root,
			state=target.state,lifetime=actor.lifetime,generation=target.generation,time=targetTime,uncertainty=target.uncertainty})) end
	end
	table.sort(contacts,function(a,b) return if a.fraction==b.fraction then a.id<b.id else a.fraction<b.fraction end)
	while #contacts>limit do table.remove(contacts) end
	return table.freeze({ok=true,reason="covered",source=pose,sourceTime=sourceTime,targetTime=targetTime,shape=worldShape,contacts=table.freeze(contacts)})
end
return W
