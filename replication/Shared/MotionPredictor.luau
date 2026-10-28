-- Estimates only, on either peer. A forecast never upgrades a sample's trust.
-- Source times must describe capture time, not packet receipt time.
local Motion = {}
local Model = {}
Model.__index = Model
local HORIZONS = {0.033, 0.067, 0.1, 0.15, 0.25}
local NAMES = {"hold", "straight", "acceleration", "turn", "braking"}
local DEFAULTS = {maxHorizon=0.25,maxDistance=8,maxSpeed=120,maxAcceleration=250,
	maxTurnRate=8,maxAngularSpeed=12,maxGap=0.75,teleportDistance=8,learningSeconds=0.6}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function vectorOK(v)
	return typeof(v)=="Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z)
end
local function frameOK(cf)
	if typeof(cf)~="CFrame" then return false end
	for _,v in {cf:GetComponents()} do if not finite(v) then return false end end
	return true
end
local function limit(v, cap)
	local length=v.Magnitude
	return if length>cap then v*(cap/length) else v
end
local function newScores()
	local scores={}
	for i=1,#HORIZONS do scores[i]={loss={0,0,0,0,0},seen=0} end
	return scores
end
local function bin(age)
	local best=1
	for i=2,#HORIZONS do
		if math.abs(age-HORIZONS[i])<math.abs(age-HORIZONS[best]) then best=i end
	end
	return best
end
local function displacement(state, h, index, config)
	local v=state.velocity
	local d
	if index==1 then d=Vector3.zero
	elseif index==2 then d=v*h
	elseif index==3 then
		local a=state.acceleration
		local speed=v.Magnitude
		-- Measured braking must not become an invented backwards launch.
		if speed<0.1 then d=Vector3.zero else
			local along=a:Dot(v/speed)
			local stop=if along<0 then math.min(h,-speed/along) else h
			d=v*stop+a*(0.5*stop*stop)
		end
	elseif index==4 then
		local w=state.turn
		if math.abs(w)<1e-4 then d=v*h else
			local a,b=math.sin(w*h)/w,(1-math.cos(w*h))/w
			d=Vector3.new(v.X*a-v.Z*b,v.Y*h,v.X*b+v.Z*a)
		end
	else d=v*(0.08*(1-math.exp(-h/0.08))) end
	return limit(d,config.maxDistance)
end
function Motion.New(options)
	local config=table.clone(DEFAULTS)
	for key,value in options or {} do
		assert(config[key]~=nil and finite(value) and value>0,"invalid motion option: "..tostring(key))
		config[key]=value
	end
	return setmetatable({config=table.freeze(config),history={},scores=newScores(),epoch=0},Model)
end
function Model:Reset()
	table.clear(self.history) self.scores=newScores() self.epoch+=1
end
function Model:Observe(t, frame, velocity, discontinuity)
	if not finite(t) or not frameOK(frame) or (velocity~=nil and not vectorOK(velocity)) then return false,"invalid_sample" end
	local previous=self.history[#self.history]
	if previous and t<=previous.t then return false,"out_of_order" end
	local dt=if previous then t-previous.t else 0
	local reset=discontinuity==true or (previous and (dt>self.config.maxGap or
		(frame.Position-previous.frame.Position).Magnitude>math.max(self.config.teleportDistance,self.config.maxSpeed*dt*1.5)))
	velocity=velocity or (if previous and not reset then (frame.Position-previous.frame.Position)/dt else Vector3.zero)
	if velocity.Magnitude>self.config.maxSpeed then return false,"speed_limit" end
	if reset then self:Reset() previous=nil end
	local acceleration,turn,angular=Vector3.zero,0,Vector3.zero
	if previous and dt<=0.25 then
		acceleration=limit((velocity-previous.velocity)/dt,self.config.maxAcceleration)
		local p,v=previous.velocity,velocity
		if Vector3.new(p.X,0,p.Z).Magnitude>1 and Vector3.new(v.X,0,v.Z).Magnitude>1 then
			turn=math.clamp(math.atan2(p.X*v.Z-p.Z*v.X,p.X*v.X+p.Z*v.Z)/dt,-self.config.maxTurnRate,self.config.maxTurnRate)
		end
		-- A reversal is a new movement choice, not evidence of a continuing orbit.
		if p.Magnitude>1 and v.Magnitude>1 and p:Dot(v)/(p.Magnitude*v.Magnitude)<0.5 then
			acceleration,turn=Vector3.zero,0
		end
		if v.Magnitude<0.1 then acceleration=Vector3.zero end
		local axis,angle=previous.frame.Rotation:ToObjectSpace(frame.Rotation):ToAxisAngle()
		angular=limit(previous.frame:VectorToWorldSpace(axis)*(angle/dt),self.config.maxAngularSpeed)
	end
	-- Retrospective scoring: each old state was built with information available THEN.
	-- Never use the newly calculated acceleration to score an earlier forecast.
	if previous then
		local alpha=1-math.exp(-dt/self.config.learningSeconds)
		for b,horizon in HORIZONS do
			local old,nearest
			for i=#self.history,1,-1 do
				local s=self.history[i] local distance=math.abs(t-s.t-horizon)
				if not nearest or distance<nearest then old,nearest=s,distance end
			end
			if old and nearest<=math.max(0.025,horizon*0.4) and t-old.t>0 then
				local bucket=self.scores[b]
				for k=1,#NAMES do
					local error=(old.frame.Position+displacement(old,math.min(t-old.t,self.config.maxHorizon),k,self.config)-frame.Position).Magnitude
					bucket.loss[k]+=alpha*(math.min(error*error,400)-bucket.loss[k])
				end
				bucket.seen+=dt
			end
		end
	end
	local state={t=t,frame=frame,velocity=velocity,acceleration=acceleration,turn=turn,angular=angular}
	table.insert(self.history,state)
	while #self.history>64 or (#self.history>1 and t-self.history[1].t>0.6) do table.remove(self.history,1) end
	return true,if reset then "reset" else "accepted"
end
function Model:Predict(t)
	if not finite(t) then return nil,{status="invalid_time"} end
	local state=self.history[#self.history]
	if not state then return nil,{status="empty"} end
	local age=t-state.t
	if age<0 then return nil,{status="before_source"} end
	local h=math.min(age,self.config.maxHorizon)
	local bucket=self.scores[bin(h)]
	local best=2
	-- Prefer straight motion until evidence distinguishes another model.
	-- A small cost prevents switching because of float noise alone.
	if bucket.seen>=0.15 then
		for k=1,#NAMES do
			-- History can suggest a stop is likely, but stable current velocity is
			-- not evidence that a player has chosen to stop. Require measured braking.
			local eligible=(k~=1 or state.velocity.Magnitude<0.1)
				and (k~=5 or state.acceleration:Dot(state.velocity)<-2*state.velocity.Magnitude)
			if eligible and bucket.loss[k]+0.0025<bucket.loss[best] then best=k end
		end
	end
	local travel=displacement(state,h,best,self.config)
	local angular=state.angular local speed=angular.Magnitude
	local rotation=state.frame.Rotation
	if speed>1e-5 then rotation=CFrame.fromAxisAngle(angular/speed,speed*h)*rotation end
	local candidates={}
	for k=1,#NAMES do candidates[k]=displacement(state,h,k,self.config) end
	local spread=0
	for _,d in candidates do spread=math.max(spread,(d-travel).Magnitude) end
	return CFrame.new(state.frame.Position+travel)*rotation,{
		status=if age>h+1e-6 then "capped" else "predicted",model=NAMES[best],
		sourceTime=state.t,targetTime=t,predictedTime=state.t+h,age=age,horizon=h,
		-- A heuristic warning, NOT a confidence interval or collision volume.
		uncertainty=math.sqrt(bucket.loss[best])+spread+math.max(0,age-h)*self.config.maxSpeed,
		epoch=self.epoch,trust="estimate",
	}
end
Motion.IsFinite=finite Motion.IsVector=vectorOK Motion.IsFrame=frameOK
return table.freeze(Motion)
