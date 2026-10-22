-- Practical timeline simulation. Synthetic RTT is a policy input, NOT a real-network benchmark.
-- Expected coverage is derived independently from retained scalar capture times and states.
local API=require(script.Parent.Core)
local S=API.Shapes
return function(count)
	local rng=Random.new(20261021)
	local result={seed=20261021,scenarios=count or 8192,assertions=0,passed=0,failures={},reasons={},rttMs={},shapeCounts={},queries=0,mode="deterministic server-timeline simulation"}
	local groups={"clean","jitter","hitch","stateTransition","teleport","providerFault","unverified","cover","roster","duplicate","expired","clockReverse","resize","cancel"}
	local started=os.clock()
	for i=1,result.scenarios do
		local group=groups[(i-1)%#groups+1]
		local rtt=({0,16,33,50,80,100,150,200,300,500,750,1000})[rng:NextInteger(1,12)]
		local rewind=if rtt==0 then 0 else math.clamp(rtt/2000+rng:NextNumber(-0.02,0.02),0,0.5)
		local now=100 local times={} local changedAt=nil local broken=false
		local targetStart=Vector3.new(rng:NextNumber(-5,5),rng:NextNumber(-3,3),rng:NextNumber(-8,-1))
		local velocity=Vector3.new(rng:NextNumber(-12,12),0,rng:NextNumber(-6,6))
		local targetKind=({"box","sphere","capsule"})[rng:NextInteger(1,3)]
		local queryKind=({"box","sphere","capsule","sweep"})[rng:NextInteger(1,4)]
		local function targetShape(t)
			local cf=CFrame.new(targetStart+velocity*(t-100))
			if targetKind=="box" then return S.Box(cf,Vector3.new(2,2,2))
			elseif targetKind=="sphere" then return S.Sphere(cf,1)
			else return S.Capsule(cf,1,4) end
		end
		local shape
		if queryKind=="box" then shape=S.Box(CFrame.new(0,0,-3),Vector3.new(6,6,6))
		elseif queryKind=="sphere" then shape=S.Sphere(CFrame.new(0,0,-3),3)
		elseif queryKind=="capsule" then shape=S.Capsule(CFrame.new(0,0,-3),2,6)
		else shape=S.Sweep(Vector3.zero,Vector3.new(0,0,-15),0.5) end
		local s=API.new({clock=function() return now end,seconds=0.6,maxGap=0.075,maxRewind=0.5,
			resolveRewind=function() return rewind end,world=function() return {covered=true,blocked=true,fraction=0.1} end})
		s:Track("source",{kind="player",trust="serverSimulated",maxSpeed=100,maxRadius=4,capture=function()
			return {root=CFrame.new(),zones={body=S.Sphere(CFrame.new(),1)},state={active=true}} end})
		s:Track("target",{kind="target",trust=if group=="unverified" then "unverified" else "serverSimulated",maxSpeed=100,maxRadius=8,capture=function(time)
			if broken then error("simulated provider failure") end
			local z=targetShape(time)
			if group=="resize" and changedAt and time>=changedAt then z=S.Sphere(z.frame,2) end
			return {root=z.frame,zones={body=z},state={active=not (changedAt and time>=changedAt and group=="stateTransition")}}
		end})
		for j=1,30 do
			if j>1 then now+=if group=="jitter" then rng:NextNumber(0.008,0.04) elseif group=="hitch" and j==24 then 0.25 else 1/30 end
			if j==27 then
				if group=="stateTransition" or group=="resize" then changedAt=now end
				if group=="providerFault" then broken=true end
			end
			s:Capture() table.insert(times,now)
		end
		local p={shape=shape,targets={"target"},maxTargets=1,closes=0.25,maxReach=32,world=group=="cover" and queryKind=="sweep"}
		local handle,why=s:BeginAction("source",p)
		local sampleTime=now-rewind local lower,upper
		for _,time in times do if time<=sampleTime then lower=time end if time>=sampleTime then upper=time break end end
		local expected
		if not lower then expected="source_too_old"
		elseif upper~=lower and upper-lower>0.075 then expected="source_sample_gap" end
		if not expected then
			if group=="teleport" then s:Discontinuity("source","teleport") expected="source_epoch_changed"
			elseif group=="providerFault" then
				if sampleTime>times[26] then expected="target_not_recorded"
				elseif lower==upper then expected="target_epoch_changed" else expected="target_discontinuity" end
			elseif group=="unverified" then expected="unverified_target"
			elseif group=="roster" then s:Untrack("target") expected="roster_changed"
			elseif group=="cancel" then s:EndAction(handle) expected="invalid_action"
			elseif group=="expired" then now+=0.3 s:Capture() expected="invalid_action"
			elseif group=="clockReverse" then now-=0.2 expected="clock_reversed"
			elseif (group=="stateTransition" or group=="resize") and lower~=upper and lower<changedAt and upper>=changedAt then expected=if group=="resize" then "target_geometry_boundary" else "target_state_boundary"
			else expected="covered" end
		end
		local actual=if handle then s:Query(handle) else {reason=why,ok=false,contacts={}}
		result.queries+=if handle then 1 else 0 result.assertions+=1
		local pass=actual.reason==expected
		if actual.ok and group=="duplicate" then result.assertions+=1 pass=pass and s:Query(handle).reason=="duplicate_query" end
		if actual.ok then
			result.assertions+=1
			local target=targetShape(sampleTime)
			if group=="resize" and changedAt and sampleTime>=changedAt then target=S.Sphere(target.frame,2) end
			local hit=S.Intersect(shape,target)
			local expectedCount=if hit and (not p.world or hit<0.1) then 1 else 0
			pass=pass and #actual.contacts==expectedCount
		end
		result.reasons[actual.reason]=(result.reasons[actual.reason] or 0)+1
		result.rttMs[tostring(rtt)]=(result.rttMs[tostring(rtt)] or 0)+1
		result.shapeCounts[queryKind.."/"..targetKind]=(result.shapeCounts[queryKind.."/"..targetKind] or 0)+1
		if pass then result.passed+=1 elseif #result.failures<30 then table.insert(result.failures,{i=i,group=group,rttMs=rtt,expected=expected,actual=actual.reason,time=sampleTime}) end
		s:Destroy()
		if i%128==0 then task.wait() end
	end
	result.seconds=os.clock()-started
	return result
end
