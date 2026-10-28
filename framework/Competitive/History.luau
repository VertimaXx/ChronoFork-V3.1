-- Immutable evidence; no synthetic stop samples and no endpoint fallback.
local Core=script.Parent.Parent.Core
local Guard=require(Core.Guard)
local Shapes=require(Core.Shapes)
local Contract=require(Core.Contract)
local H={} H.__index=H
local grades={observed=true,serverValidated=true,serverSimulated=true}
function H.new(options)
	local o=options or {}
	local seconds,capacity,gap=o.seconds or 0.6,o.capacity or 128,o.maxGap or 0.075
	assert(Guard.Number(seconds) and seconds>0 and seconds<=10 and Guard.Integer(capacity,2,4096) and Guard.Number(gap) and gap>0 and gap<=1)
	assert(Guard.Number(o.maxSpeed or 4096) and (o.maxSpeed or 4096)>=0 and (o.maxSpeed or 4096)<=4096)
	assert(Guard.Number(o.maxRadius or 512) and (o.maxRadius or 512)>0 and (o.maxRadius or 512)<=512)
	return setmetatable({rows={},head=1,count=0,capacity=capacity,seconds=seconds,maxGap=gap,generation=1,
		maxSpeed=o.maxSpeed or 4096,maxRadius=o.maxRadius or 512,boundary=-math.huge},H)
end
function H:At(index) return self.rows[(self.head+index-2)%self.capacity+1] end
function H:Latest() return if self.count>0 then self:At(self.count) else nil end
function H:Break(time,reason)
	assert(Guard.Number(time))
	self.generation+=1 self.boundary=math.max(time,self.boundary) self.reason=reason or "reset"
end
function H:Push(row)
	if type(row)~="table" or not Guard.Number(row.time) or not Guard.Number(row.receivedAt) or row.receivedAt<row.time
		or not Guard.Frame(row.root) or not grades[row.grade] then return false,"invalid_record" end
	if row.sourceId~=nil and not ((type(row.sourceId)=="string" and #row.sourceId<=128) or Guard.Number(row.sourceId)) then return false,"invalid_source_id" end
	local last=self:Latest()
	if row.time<self.boundary or (last and row.time<=last.time) then return false,"non_monotonic" end
	if last and last.generation==self.generation and (row.root.Position-last.root.Position).Magnitude>self.maxSpeed*(row.time-last.time)+1e-4 then return false,"speed_bound" end
	local state=Contract.State(row.state or {}) if not state then return false,"invalid_state" end
	if type(row.zones)~="table" then return false,"invalid_zones" end
	local zones={} local count=0
	for key,zone in row.zones or {} do
		count+=1 local copy=Shapes.Copy(zone,true)
		if type(key)~="string" or #key>64 or count>32 or not copy then return false,"invalid_zone" end
		if (copy.frame.Position-row.root.Position).Magnitude+Shapes.Radius(copy)>self.maxRadius+1e-5 then return false,"zone_out_of_bounds" end
		zones[key]=copy
	end
	if count==0 then return false,"empty_zones" end
	local uncertainty=row.uncertainty or 0
	if not Guard.Number(uncertainty) or uncertainty<0 or uncertainty>1 then return false,"invalid_uncertainty" end
	local copy=table.freeze({time=row.time,receivedAt=row.receivedAt,root=row.root,zones=table.freeze(zones),state=state,
		grade=row.grade,generation=self.generation,sourceId=row.sourceId,uncertainty=uncertainty})
	if self.count<self.capacity then self.count+=1 self.rows[(self.head+self.count-2)%self.capacity+1]=copy
	else self.rows[self.head]=copy self.head=self.head%self.capacity+1 end
	return true
end
function H:Sample(time,now,allowObserved)
	if not Guard.Number(time) or not Guard.Number(now) then return nil,"invalid_time" end
	if time>now+1e-6 then return nil,"future" end
	if now-time>self.seconds then return nil,"expired" end
	if self.count==0 then return nil,"empty" end
	if time<self:At(1).time then return nil,"too_old" end
	if time>self:Latest().time then return nil,"not_recorded" end
	local lo,hi=1,self.count
	while lo<=hi do local mid=(lo+hi)//2 if self:At(mid).time<time then lo=mid+1 else hi=mid-1 end end
	local after=self:At(lo)
	if after.generation~=self.generation then return nil,"generation_changed" end
	if not allowObserved and after.grade=="observed" then return nil,"unverified_source" end
	if after.time==time then return after end
	local before=self:At(lo-1)
	if before.generation~=after.generation then return nil,"discontinuity" end
	if before.grade~=after.grade or (not allowObserved and before.grade=="observed") then return nil,"trust_boundary" end
	if after.time-before.time>self.maxGap then return nil,"sample_gap" end
	if not Contract.SameState(before.state,after.state) then return nil,"state_boundary" end
	local alpha=(time-before.time)/(after.time-before.time) local zones={}
	for name,zone in before.zones do
		local nextZone=after.zones[name]
		if not nextZone or not Shapes.SameDimensions(zone,nextZone) then return nil,"geometry_boundary" end
		zones[name]=Shapes.Lerp(zone,nextZone,alpha)
	end
	for name in after.zones do if not before.zones[name] then return nil,"geometry_boundary" end end
	return table.freeze({time=time,receivedAt=math.max(before.receivedAt,after.receivedAt),root=before.root:Lerp(after.root,alpha),
		zones=table.freeze(zones),state=before.state,grade=before.grade,generation=before.generation,
		uncertainty=math.max(before.uncertainty,after.uncertainty),before=before.sourceId,after=after.sourceId})
end
return H
