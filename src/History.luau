--!strict
local Guard=require(script.Parent.Guard)
local Contract=require(script.Parent.Contract)
local Shapes=require(script.Parent.Shapes)
local H={} H.__index=H
function H.new(options)
	return setmetatable({rows=table.create(options.capacity),head=1,count=0,capacity=options.capacity,
		epoch=1,maxAge=options.seconds,maxGap=options.maxGap,maxSpeed=options.maxSpeed,
		maxRadius=options.maxRadius,boundary=-math.huge},H)
end
function H:_at(i) return self.rows[(self.head+i-2)%self.capacity+1] end
function H:Latest() return if self.count>0 then self:_at(self.count) else nil end
function H:Break(time)
	self.epoch+=1 self.boundary=time
end
function H:Push(time,snapshot)
	if type(snapshot)~="table" or not Guard.Frame(snapshot.root) or type(snapshot.zones)~="table" then return false,"invalid_snapshot" end
	local state=Contract.State(snapshot.state or {})
	if not state then return false,"invalid_state" end
	local zones,count={},0
	for name,shape in snapshot.zones do
		count+=1
		if count>32 or type(name)~="string" or #name>64 then return false,"invalid_zones" end
		local zone=Shapes.Copy(shape,true)
		if not zone then return false,"invalid_zone" end
		if (zone.frame.Position-snapshot.root.Position).Magnitude+Shapes.Radius(zone)>self.maxRadius+1e-5 then return false,"zone_out_of_bounds" end
		zones[name]=zone
	end
	if count==0 then return false,"empty_zones" end
	local latest=self:Latest()
	if time<self.boundary or (latest and time<=latest.time) then return false,"non_monotonic" end
	if latest and latest.epoch==self.epoch and (snapshot.root.Position-latest.root.Position).Magnitude>self.maxSpeed*(time-latest.time)+1e-4 then return false,"speed_bound" end
	local row=table.freeze({time=time,root=snapshot.root,zones=table.freeze(zones),state=state,epoch=self.epoch})
	if self.count<self.capacity then self.count+=1 self.rows[(self.head+self.count-2)%self.capacity+1]=row
	else self.rows[self.head]=row self.head=self.head%self.capacity+1 end
	return true
end
function H:Sample(time,now)
	if not Guard.Number(time) or not Guard.Number(now) then return nil,"invalid_time" end
	if time>now+1e-6 then return nil,"future" end
	if now-time>self.maxAge then return nil,"expired" end
	if self.count==0 then return nil,"empty" end
	if time<self:_at(1).time then return nil,"too_old" end
	if time>self:Latest().time then return nil,"not_recorded" end
	local low,high=1,self.count
	while low<=high do local mid=(low+high)//2 if self:_at(mid).time<time then low=mid+1 else high=mid-1 end end
	local after=self:_at(low)
	if after.time==time then
		if after.epoch~=self.epoch then return nil,"epoch_changed" end
		return after
	end
	local before=self:_at(low-1)
	if before.epoch~=after.epoch or after.epoch~=self.epoch then return nil,"discontinuity" end
	if after.time-before.time>self.maxGap then return nil,"sample_gap" end
	if not Contract.SameState(before.state,after.state) then return nil,"state_boundary" end
	local alpha=(time-before.time)/(after.time-before.time)
	local zones={}
	for name,zone in before.zones do
		local nextZone=after.zones[name]
		if not nextZone or not Shapes.SameDimensions(zone,nextZone) then return nil,"geometry_boundary" end
		zones[name]=Shapes.Lerp(zone,nextZone,alpha)
	end
	for name in after.zones do if not before.zones[name] then return nil,"geometry_boundary" end end
	return table.freeze({time=time,root=before.root:Lerp(after.root,alpha),state=before.state,
		zones=table.freeze(zones),epoch=before.epoch})
end
return H
