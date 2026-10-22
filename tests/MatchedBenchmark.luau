-- Shared input history interpolation comparison only. No end-to-end gameplay equivalence claim.
return function(Core,Baseline)
	local H=require(Core.History)
	local S=require(Core).Shapes
	local config=require(Baseline.Shared.Config)
	local locked=false config._WaitForLock(function() locked=true end) if not locked then config._Lock() end
	local Old=require(Baseline.Shared.Snapshots)
	local M=require(Baseline.Shared.InterpolationMath)
	local rng=Random.new(8841021)
	local metrics={cases=2000,queries=0,covered=0,originalReturnedOutside=0,v3RejectedOutside=0,originalOvershoot=0,v3Overshoot=0,
		originalMeanError=0,v3MeanError=0,originalSeconds=0,v3Seconds=0,scope="same two endpoint snapshots and 17 covered queries; random velocities; linear trajectory oracle"}
	local osum,vsum=0,0
	for i=1,metrics.cases do
		local old=Old(M.Hermite)
		local history=H.new({capacity=40,seconds=0.6,maxGap=0.075,maxSpeed=4096,maxRadius=4})
		local p=Vector3.new(rng:NextNumber(-20,20),0,0)
		local q=p+Vector3.new(rng:NextNumber(-10,10),0,0)
		local v0=Vector3.new(rng:NextNumber(-150,150),rng:NextNumber(-80,80),0)
		local v1=Vector3.new(rng:NextNumber(-150,150),rng:NextNumber(-80,80),0)
		for _,row in {{time=10,p=p,v=v0},{time=10.05,p=q,v=v1}} do
			old:Push(row.time,CFrame.new(row.p),row.v)
			history:Push(row.time,{root=CFrame.new(row.p),zones={body=S.Sphere(CFrame.new(row.p),1)},state={active=true}})
		end
		for j=0,16 do
			local alpha=j/16 local time=10+0.05*alpha local expected=p:Lerp(q,alpha)
			local begin=os.clock() local a=old:GetAt(time) metrics.originalSeconds+=os.clock()-begin
			begin=os.clock() local b=history:Sample(time,10.05) metrics.v3Seconds+=os.clock()-begin
			assert(a and b,"covered shared case rejected")
			metrics.covered+=1 metrics.queries+=1
			osum+=(a.Position-expected).Magnitude vsum+=(b.root.Position-expected).Magnitude
			local low,high=math.min(p.X,q.X)-1e-5,math.max(p.X,q.X)+1e-5
			if a.X<low or a.X>high then metrics.originalOvershoot+=1 end
			if b.root.X<low or b.root.X>high then metrics.v3Overshoot+=1 end
		end
		for _,time in {9.99,10.06} do
			if old:GetAt(time) then metrics.originalReturnedOutside+=1 end
			if not history:Sample(time,10.1) then metrics.v3RejectedOutside+=1 end
		end
		if i%128==0 then task.wait() end
	end
	metrics.originalMeanError=osum/metrics.covered metrics.v3MeanError=vsum/metrics.covered
	metrics.originalMeanQueryUs=metrics.originalSeconds/metrics.covered*1e6
	metrics.v3MeanQueryUs=metrics.v3Seconds/metrics.covered*1e6
	return metrics
end
