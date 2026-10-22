-- Integration oracle, deliberately separate from isolated unit tests.
-- Roblox engine narrow-phase overlap/casts vs supplied primitive math; deterministic seed.
return function(Core,count)
	local S=require(Core).Shapes
	local model=Instance.new("WorldModel") model.Name="ChronoV3TemporaryOracle" model.Parent=game.ServerStorage
	local a=Instance.new("Part") a.Name="Query" a.Anchored=true a.CanCollide=false a.Parent=model
	local b=Instance.new("Part") b.Name="Target" b.Anchored=true b.CanCollide=false b.Parent=model
	local overlap=OverlapParams.new() overlap.FilterType=Enum.RaycastFilterType.Include overlap.FilterDescendantsInstances={b}
	local cast=RaycastParams.new() cast.FilterType=Enum.RaycastFilterType.Include cast.FilterDescendantsInstances={b}
	local rng=Random.new(471021)
	local r={cases=count or 6000,passed=0,failures={},kinds={}}
	local ok,err=pcall(function()
		for i=1,r.cases do
			local kind=({"box-box","sphere-box","sweep-box"})[(i-1)%3+1]
			local pos=Vector3.new(rng:NextNumber(-5,5),rng:NextNumber(-5,5),rng:NextNumber(-5,5))
			b.CFrame=CFrame.new(pos)*CFrame.Angles(rng:NextNumber(-3,3),rng:NextNumber(-3,3),rng:NextNumber(-3,3))
			b.Size=Vector3.new(rng:NextNumber(0.5,5),rng:NextNumber(0.5,5),rng:NextNumber(0.5,5))
			local target=S.Box(b.CFrame,b.Size) local actual,expected,mathDistance,engineDistance
			if kind=="box-box" then
				a.Shape=Enum.PartType.Block a.Size=Vector3.new(3,4,2) a.CFrame=CFrame.Angles(rng:NextNumber(-3,3),rng:NextNumber(-3,3),rng:NextNumber(-3,3))
				actual=S.Intersect(S.Box(a.CFrame,a.Size),target)~=nil expected=#model:GetPartsInPart(a,overlap)>0
			elseif kind=="sphere-box" then
				a.Shape=Enum.PartType.Ball a.Size=Vector3.one*2 a.CFrame=CFrame.new()
				actual=S.Intersect(S.Sphere(a.CFrame,1),target)~=nil expected=#model:GetPartsInPart(a,overlap)>0
			else
				local from,to=Vector3.new(-10,0,0),Vector3.new(10,0,0)
				local hit=model:Spherecast(from,0.75,to-from,cast)
				local fraction=S.Intersect(S.Sweep(from,to,0.75),target)
				actual=fraction~=nil expected=hit~=nil
				if hit and fraction then mathDistance=fraction*20 engineDistance=hit.Distance end
			end
			local pass=actual==expected and (not mathDistance or math.abs(mathDistance-engineDistance)<0.025)
			r.kinds[kind]=(r.kinds[kind] or 0)+1
			if pass then r.passed+=1 elseif #r.failures<30 then table.insert(r.failures,{i=i,kind=kind,actual=actual,expected=expected,mathDistance=mathDistance,engineDistance=engineDistance}) end
			if i%256==0 then task.wait() end
		end
	end)
	model:Destroy() if not ok then error(err) end return r
end
