-- Historical obstacle provider compatible with Core's world(time,now,shape) hook.
-- Object existence is time bounded; missing geometry is never reported clear.
local History=require(script.Parent.History)
local Guard=require(script.Parent.Parent.Core.Guard)
local Shapes=require(script.Parent.Parent.Core.Shapes)
local W={} W.__index=W
function W.new(options)
	local o=options or {} local seconds=o.seconds or 0.6
	assert(Guard.Number(seconds) and seconds>=0.05 and seconds<=10)
	return setmetatable({rows={},seconds=seconds,maxGap=o.maxGap or 0.075,serial=0,lastTime=-math.huge},W)
end
function W:Track(id,time,options)
	assert(type(id)=="string" and #id>0 and #id<=64 and Guard.Number(time) and not self.rows[id])
	local count=0 for _ in self.rows do count+=1 end assert(count<256,"Obstacle history capacity")
	local o=options or {} assert(o.grade=="serverSimulated" or o.grade=="serverValidated","Obstacle position needs an explicit checked server source")
	self.serial+=1 self.rows[id]={born=time,lifetime=self.serial,grade=o.grade,history=History.new({seconds=self.seconds,maxGap=self.maxGap,capacity=o.capacity or 128,maxSpeed=o.maxSpeed or 4096,maxRadius=o.maxRadius or 512})}
end
function W:Record(id,row)
	local object=assert(self.rows[id],"Unknown obstacle")
	if object.removed or type(row)~="table" or not Guard.Number(row.time) or row.time<object.born then return false,"obstacle_not_active" end
	local copy=table.clone(row) copy.grade=object.grade return object.history:Push(copy)
end
function W:Remove(id,time)
	local object=assert(self.rows[id],"Unknown obstacle") local latest=object.history:Latest()
	assert(not object.removed and Guard.Number(time) and time>=object.born and (not latest or time>=latest.time)) object.removed=time
end
function W:Discontinuity(id,time,reason) assert(self.rows[id],"Unknown obstacle").history:Break(time,reason) end
function W:Prune(now)
	assert(Guard.Number(now) and now>=self.lastTime) self.lastTime=now
	for id,object in self.rows do if object.removed and now-object.removed>self.seconds then self.rows[id]=nil end end
end
function W:Query(at,now,shape)
	if not Guard.Number(at) or not Guard.Number(now) or now<self.lastTime or at>now or now-at>self.seconds or type(shape)~="table" or shape.kind~="sweep" then return {covered=false,reason="world_time_or_shape"} end
	local copy=Shapes.Copy(shape) if not copy then return {covered=false,reason="world_shape"} end
	local fraction,id,zone=1,nil,nil
	for name,object in self.rows do
		if at<object.born or (object.removed and at>=object.removed) then continue end
		local pose,reason=object.history:Sample(at,now)
		if not pose then return table.freeze({covered=false,reason=reason,id=name}) end
		for key,volume in pose.zones do
			local hit=Shapes.Intersect(copy,volume)
			if hit and (not id or hit<fraction or (hit==fraction and name<id) or (hit==fraction and name==id and key<zone)) then fraction,id,zone=hit,name,key end
		end
	end
	return table.freeze({covered=true,blocked=id~=nil,fraction=fraction,id=id,zone=zone})
end
function W:Provider() return function(at,now,shape)return self:Query(at,now,shape)end end
return W
