-- Display estimates only. Competitive evidence never calls this module.
local V = {}
function V.SegmentHermite(p0, p1, v0, v1, alpha, dt)
	local delta = p1 - p0
	local length = delta.Magnitude
	if length < 1e-8 then return p0 end
	local direction = delta / length
	local a = math.clamp((v0 or Vector3.zero):Dot(direction) * dt / length, 0, 3)
	local b = math.clamp((v1 or Vector3.zero):Dot(direction) * dt / length, 0, 3)
	-- Ordered Bezier control points give a sufficient monotonic segment constraint.
	if a + b > 3 then local scale = 3 / (a + b) a *= scale b *= scale end
	local t2, t3 = alpha * alpha, alpha * alpha * alpha
	local u = (t3 - 2*t2 + alpha)*a + (-2*t3 + 3*t2) + (t3-t2)*b
	return p0 + delta * math.clamp(u, 0, 1)
end
function V.Sample(snapshot, time, mode, predictionSeconds, predictionDistance, predictionSpeed)
	local requestedTime=time
	-- Respect explicit teleports for EVERY display curve, including linear sampling.
	if snapshot.lockedTime and time<snapshot.lockedTime then time=snapshot.lockedTime end
	local latest = snapshot:GetLatest()
	if not latest then return nil, {status="empty", requestedTime=time} end
	local first = snapshot.cache[snapshot.head]
	if time > latest.t then
		local age = time - latest.t
		local velocity = latest.velocity or Vector3.zero
		if predictionSeconds > 0 and age <= predictionSeconds and velocity.Magnitude <= predictionSpeed then
			local travel = velocity * age
			if travel.Magnitude <= predictionDistance then
				return latest.value + travel, {status="predicted",requestedTime=time,sourceTime=latest.t,age=age}
			end
		end
		return latest.value, {status="held",requestedTime=time,sourceTime=latest.t,age=age}
	end
	if requestedTime<time then
		local frame=V.Sample(snapshot,time,mode,predictionSeconds,predictionDistance,predictionSpeed)
		return frame,{status="discontinuity",requestedTime=requestedTime,sourceTime=time}
	end
	if time < first.t then return first.value, {status="before_coverage",requestedTime=time,sourceTime=first.t} end
	if mode == "HERMITE" then return snapshot:GetAt(time), {status="interpolated",requestedTime=time} end
	local previous = first
	for index=2,snapshot.count do
		local after = snapshot.cache[(snapshot.head+index-2)%#snapshot.cache+1]
		if after.t >= time then
			local span = after.t - previous.t
			if span <= 0 then return after.value, {status="recorded",requestedTime=time,sourceTime=after.t} end
			local alpha = math.clamp((time-previous.t)/span,0,1)
			local rotation = previous.value:Lerp(after.value,alpha).Rotation
			local position = if mode=="LINEAR" then previous.value.Position:Lerp(after.value.Position,alpha)
				else V.SegmentHermite(previous.value.Position,after.value.Position,previous.velocity,after.velocity,alpha,span)
			return CFrame.new(position)*rotation,{status="interpolated",requestedTime=time,before=previous.t,after=after.t}
		end
		previous=after
	end
	return latest.value,{status="recorded",requestedTime=time,sourceTime=latest.t}
end
return table.freeze(V)
