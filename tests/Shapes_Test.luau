-- Contract tests and independent scalar-distance oracles, deterministic seed 31021.
return function(t)
	local S=require(game.ServerStorage.ChronoV3Validation.Core).Shapes
	local E=t.expect
	local function box(x,y,z) return S.Box(CFrame.new(x or 0,y or 0,z or 0),Vector3.new(2,2,2)) end
	local function sphere(x,y,z,r) return S.Sphere(CFrame.new(x or 0,y or 0,z or 0),r or 1) end
	local function capsule(x,y,z) return S.Capsule(CFrame.new(x or 0,y or 0,z or 0),1,6) end
	-- Tangency belongs to the closed hitbox volume.
	t.test("box face tangency",function() E.equal(S.Intersect(box(),box(2)),0) E.equal(S.Intersect(box(),box(2.01)),nil) end)
	-- Sphere corners use Euclidean distance, not a padded axis-aligned box.
	t.test("rounded sphere box corner",function() E.equal(S.Intersect(box(),sphere(1.9,1.9,0)),nil) E.equal(S.Intersect(box(),sphere(1.7,1.7,0)),0) end)
	-- A capsule includes its hemisphere tips but excludes the rectangular corner.
	t.test("capsule tip and corner",function() E.equal(S.Intersect(capsule(),sphere(0,4,0)),0) E.equal(S.Intersect(capsule(),sphere(1.9,3.9,0)),nil) end)
	-- Zero-length capsule is a sphere.
	t.test("degenerate capsule",function() local a=S.Capsule(CFrame.new(),1,2) E.equal(S.Intersect(a,sphere(2)),0) end)
	-- Sweeps report the earliest travel fraction including an initial overlap.
	t.test("sweep earliest and initial overlap",function()
		E.near(S.Intersect(S.Ray(Vector3.new(-5,0,0),Vector3.new(5,0,0)),sphere()),0.4,1e-6)
		E.near(S.Intersect(S.Sweep(Vector3.new(-5,0,0),Vector3.new(5,0,0),1),capsule()),0.3,1e-6)
		E.equal(S.Intersect(S.Ray(Vector3.zero,Vector3.zero),capsule()),0)
		E.equal(S.Intersect(S.Ray(Vector3.new(10,0,0),Vector3.new(10,0,0)),capsule()),nil)
	end)
	-- Capsule axis and cap paths must both be included.
	t.test("parallel capsule ray and tangent",function()
		E.near(S.Intersect(S.Ray(Vector3.new(0,-5,0),Vector3.new(0,5,0)),capsule()),0.2,1e-6)
		E.near(S.Intersect(S.Ray(Vector3.new(-5,0,1),Vector3.new(5,0,1)),capsule()),0.5,1e-5)
		E.equal(S.Intersect(S.Ray(Vector3.new(-5,0,1.01),Vector3.new(5,0,1.01)),capsule()),nil)
	end)
	-- Validation rejects malformed matrices and nonfinite primitive dimensions.
	t.test("invalid primitive inputs",function()
		E.throws(function() S.Sphere(CFrame.new(),0/0) end)
		E.throws(function() S.Capsule(CFrame.new(),2,3) end)
		E.throws(function() S.Box(CFrame.new(),Vector3.new(-1,1,1)) end)
		E.throws(function() S.Box(CFrame.new(0,0,0,2,0,0,0,1,0,0,0,1),Vector3.one) end)
	end)
	-- Against axis-aligned boxes, independent interval overlap is the exact oracle.
	t.test("4000 independent interval box cases",function()
		local rng=Random.new(31021)
		for i=1,4000 do
			local p=Vector3.new(rng:NextNumber(-5,5),rng:NextNumber(-5,5),rng:NextNumber(-5,5))
			local size=Vector3.new(rng:NextNumber(0.1,5),rng:NextNumber(0.1,5),rng:NextNumber(0.1,5))
			local expected=math.abs(p.X)<=1+size.X/2 and math.abs(p.Y)<=1+size.Y/2 and math.abs(p.Z)<=1+size.Z/2
			E.equal(S.Intersect(box(),S.Box(CFrame.new(p),size))~=nil,expected)
		end
	end)
	-- Rigidly transforming both shapes preserves every primitive pairing.
	t.test("3600 rotated pairing symmetry and invariance cases",function()
		local rng=Random.new(931021)
		for i=1,1200 do
			local p=Vector3.new(rng:NextNumber(-5,5),rng:NextNumber(-5,5),rng:NextNumber(-5,5))
			local transform=CFrame.new(30,-15,7)*CFrame.Angles(0.9,2.1,-0.4)
			local a={box(),sphere(),capsule()}
			local b={box(p.X,p.Y,p.Z),sphere(p.X,p.Y,p.Z),capsule(p.X,p.Y,p.Z)}
			for j=1,3 do local k=i%3+1
				local hit=S.Intersect(a[j],b[k])~=nil
				E.equal(S.Intersect(b[k],a[j])~=nil,hit)
				E.equal(S.Intersect(S.At(a[j],transform),S.At(b[k],transform))~=nil,hit)
			end
		end
	end)
	-- Independent convex minimization and bisection of point/segment distance.
	t.test("2500 swept capsule distance oracle cases",function()
		local rng=Random.new(1231021)
		local function distance(p)
			local y=math.clamp(p.Y,-2,2)
			return math.sqrt(p.X*p.X+(p.Y-y)^2+p.Z*p.Z)
		end
		for i=1,2500 do
			local p=Vector3.new(rng:NextNumber(-8,8),rng:NextNumber(-8,8),rng:NextNumber(-8,8))
			local q=Vector3.new(rng:NextNumber(-8,8),rng:NextNumber(-8,8),rng:NextNumber(-8,8))
			local radius=rng:NextNumber(0,2) local r=1+radius
			local lo,hi=0,1
			for _=1,55 do local a=lo+(hi-lo)/3 local b=hi-(hi-lo)/3 if distance(p:Lerp(q,a))<distance(p:Lerp(q,b)) then hi=b else lo=a end end
			local minimum=(lo+hi)/2
			local expected=nil
			if distance(p)<=r then expected=0
			elseif distance(p:Lerp(q,minimum))<=r then
				lo,hi=0,minimum
				for _=1,55 do local mid=(lo+hi)/2 if distance(p:Lerp(q,mid))<=r then hi=mid else lo=mid end end
				expected=hi
			end
			local actual=S.Intersect(S.Sweep(p,q,radius),capsule())
			E.equal(actual~=nil,expected~=nil)
			if expected then E.near(actual,expected,2e-5) end
		end
	end)
end
