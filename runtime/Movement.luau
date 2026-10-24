-- Optional bounded humanoid checker. No combat tags, damage values or game-specific moves.
-- Checks roots on ordinary static ground. Vehicles, moving platforms and custom physics need a provider.
local M={}
local function valid(frame)
	if typeof(frame)~="CFrame" then return false end
	for _,n in {frame:GetComponents()} do if n~=n or math.abs(n)==math.huge then return false end end
	return true
end
function M.New(object,root,now,c)
	assert(valid(root.CFrame),"Spawn position is invalid")
	return {object=object,root=root,frame=root.CFrame,time=now,credit=c.walk*c.burst+c.slack,
		vertical=c.jump*c.burst+c.verticalSlack,airStart=now,airY=root.Position.Y,
		impulse=Vector3.zero,untilTime=0,blockedUntil=0}
end
function M.Allow(r,velocity,seconds,now)
	assert(typeof(velocity)=="Vector3" and velocity.Magnitude==velocity.Magnitude and velocity.Magnitude<=2000,"Use a finite server-approved velocity up to 2000 studs/second")
	assert(type(seconds)=="number" and seconds>=0 and seconds<=5,"Motion permission lasts 0 to 5 seconds")
	r.impulse=velocity r.untilTime=now+seconds+0.35
end
function M.Reset(r,frame,now,c)
	assert(valid(frame),"Approved teleport needs a finite CFrame")
	local root=r.root
	if r.object:IsA("Model") then r.object:PivotTo(frame*root.CFrame:Inverse()*r.object:GetPivot()) else root.CFrame=frame end
	root.AssemblyLinearVelocity=Vector3.zero root.AssemblyAngularVelocity=Vector3.zero
	r.frame=frame r.time=now r.credit=c.walk*c.burst+c.slack r.vertical=c.jump*c.burst+c.verticalSlack
	r.airStart=now r.airY=frame.Position.Y r.blockedUntil=0 r.untilTime=0 r.impulse=Vector3.zero
end
function M.Check(r,now,c,hooks,excluded)
	local root=r.root local proposed=root.CFrame
	local function refuse(reason)
		r.blockedUntil=now+0.35
		if c.correction then
			if valid(proposed) then
				if r.object:IsA("Model") then r.object:PivotTo(r.frame*proposed:Inverse()*r.object:GetPivot()) else root.CFrame=r.frame end
			else root.CFrame=r.frame end
			root.AssemblyLinearVelocity=Vector3.zero root.AssemblyAngularVelocity=Vector3.zero
		end
		r.time=now r.credit=0 r.vertical=0
		return nil,reason,c.correction
	end
	if not valid(proposed) then return refuse("movement_invalid") end
	local walk,jump=hooks.MovementLimits(r.object,c)
	if type(walk)~="number" or walk~=walk or walk<0 or walk>200 or type(jump)~="number" or jump~=jump or jump<0 or jump>250 then return refuse("movement_limits_invalid") end
	local dt=math.max(0,now-r.time)
	local extra=if now<=r.untilTime then r.impulse else Vector3.zero
	local speed=walk+Vector3.new(extra.X,0,extra.Z).Magnitude
	r.credit=math.min(speed*c.burst+c.slack,r.credit+speed*dt)
	local delta=proposed.Position-r.frame.Position
	local horizontal=Vector3.new(delta.X,0,delta.Z).Magnitude
	if horizontal>r.credit+1e-4 then return refuse("movement_speed") end
	local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Exclude ray.FilterDescendantsInstances=excluded
	ray.RespectCanCollide=true ray.CollisionGroup=root.CollisionGroup
	local hit=workspace:Raycast(proposed.Position,Vector3.new(0,-c.ground-0.5,0),ray)
	local onGround=hit and hit.Normal.Y>0.5
	local gravity=workspace.Gravity
	local age=math.max(0,now-r.airStart)
	local launch=jump+math.max(0,extra.Y)
	local verticalSpeed=math.min(2000,launch+gravity*age+math.abs(extra.Y))
	r.vertical=math.min(verticalSpeed*c.burst+c.verticalSlack,r.vertical+verticalSpeed*dt)
	if math.abs(delta.Y)>r.vertical+1e-4 then return refuse("movement_vertical") end
	if not onGround and gravity>0 then
		local t=math.clamp(launch/gravity,math.max(0,age-0.3),age+0.3)
		if proposed.Position.Y>r.airY+launch*t-0.5*gravity*t*t+c.verticalSlack then return refuse("movement_air") end
	end
	if delta.Magnitude>0.01 and delta.Magnitude<1000 then
		for _,height in {-c.ground*0.4,0,c.ground*0.4} do
			local wall=workspace:Spherecast(r.frame.Position+Vector3.new(0,height,0),c.wallRadius,delta,ray)
			if wall and wall.Distance<delta.Magnitude-0.18 then return refuse("movement_wall") end
		end
	end
	if onGround then r.airStart=now r.airY=proposed.Position.Y end
	r.credit=math.max(0,r.credit-horizontal) r.vertical=math.max(0,r.vertical-math.abs(delta.Y))
	r.frame=proposed r.time=now
	if now<r.blockedUntil then return nil,"movement_settling",false end
	return proposed
end
return M
