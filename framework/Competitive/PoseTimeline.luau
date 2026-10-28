-- Server-authored move zones. This is not a claim to recover arbitrary client animation or IK.
local Core=script.Parent.Parent.Core
local Shapes=require(Core.Shapes)
local Guard=require(Core.Guard)
local P={} P.__index=P
function P.new(keys)
	assert(type(keys)=="table" and #keys>=1 and #keys<=1024,"Use 1 to 1024 pose keys")
	local copy={} local last=-math.huge
	for _,key in keys do
		assert(type(key)=="table" and Guard.Number(key.time) and key.time>=0 and key.time<=120 and key.time>last,"Pose key times must increase (0 to 120 seconds)")
		assert(type(key.zones)=="table","Pose key needs named zones")
		local zones={} local count=0
		for name,shape in key.zones do
			count+=1 assert(type(name)=="string" and #name>0 and #name<=64 and count<=32)
			zones[name]=assert(Shapes.Copy(shape,true),"Invalid pose shape")
		end
		assert(count>0,"Pose needs a zone")
		table.insert(copy,table.freeze({time=key.time,zones=table.freeze(zones)})) last=key.time
	end
	return setmetatable({keys=table.freeze(copy),duration=last},P)
end
function P:Sample(age,root)
	if not Guard.Number(age) or not Guard.Frame(root) then return nil,"invalid_pose_time" end
	if age<self.keys[1].time or age>self.duration then return nil,"pose_not_covered" end
	local before=self.keys[1] local zones={}
	for _,after in self.keys do
		if after.time==age then
			for name,shape in after.zones do zones[name]=Shapes.At(shape,root) end
			return table.freeze(zones)
		end
		if after.time>=age then
			local alpha=if after.time==before.time then 0 else (age-before.time)/(after.time-before.time)
			for name,shape in before.zones do
				local other=after.zones[name]
				if not other or not Shapes.SameDimensions(shape,other) then return nil,"pose_geometry_boundary" end
				zones[name]=Shapes.At(Shapes.Lerp(shape,other,alpha),root)
			end
			for name in after.zones do if not before.zones[name] then return nil,"pose_geometry_boundary" end end
			return table.freeze(zones)
		end
		before=after
	end
	return nil,"pose_not_covered"
end
return P
