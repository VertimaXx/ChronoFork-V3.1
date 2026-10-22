--!strict
-- Geometry uses studs, seconds, world CFrames, and closed volumes (tangency counts).
local Guard = require(script.Parent.Guard)
local G = require(script.Parent.Geometry)
local S = {}
local EPS = 1e-7
local function positive(v, maximum)
	return Guard.Number(v) and v > 0 and v <= maximum
end
function S.Copy(s, targetOnly)
	if type(s) ~= "table" then return nil end
	if s.kind == "box" and Guard.Frame(s.frame) and Guard.Size(s.size, 512) then
		return table.freeze({kind="box", frame=s.frame, size=s.size})
	elseif s.kind == "sphere" and Guard.Frame(s.frame) and positive(s.radius,32) then
		return table.freeze({kind="sphere", frame=s.frame, radius=s.radius})
	elseif s.kind == "capsule" and Guard.Frame(s.frame) and positive(s.radius,32)
		and positive(s.height,512) and s.height >= s.radius*2 then
		return table.freeze({kind="capsule", frame=s.frame, radius=s.radius, height=s.height})
	elseif not targetOnly and s.kind == "sweep" and Guard.Vector(s.start) and Guard.Vector(s.finish)
		and Guard.Number(s.radius) and s.radius >= 0 and s.radius <= 32
		and (s.finish-s.start).Magnitude <= 4096 then
		return table.freeze({kind="sweep", start=s.start, finish=s.finish, radius=s.radius})
	end
	return nil
end
local function checked(s) return assert(S.Copy(s), "invalid Chrono shape") end
function S.Box(frame, size) return checked({kind="box",frame=frame,size=size}) end
function S.Sphere(frame, radius) return checked({kind="sphere",frame=frame,radius=radius}) end
function S.Capsule(frame, radius, height) return checked({kind="capsule",frame=frame,radius=radius,height=height}) end
function S.Sweep(start, finish, radius) return checked({kind="sweep",start=start,finish=finish,radius=radius}) end
function S.Ray(start, finish) return S.Sweep(start,finish,0) end
function S.At(shape, frame)
	assert(Guard.Frame(frame), "invalid reference frame")
	local out = table.clone(shape)
	if out.kind == "sweep" then
		out.start, out.finish = frame:PointToWorldSpace(out.start), frame:PointToWorldSpace(out.finish)
	else out.frame = frame*out.frame end
	return checked(out)
end
function S.Radius(s)
	if s.kind == "box" then return s.size.Magnitude*0.5 end
	if s.kind == "capsule" then return s.height*0.5 end
	return s.radius
end
function S.Reach(s)
	if s.kind == "sweep" then return math.max(s.start.Magnitude,s.finish.Magnitude)+s.radius end
	return s.frame.Position.Magnitude+S.Radius(s)
end
function S.SameDimensions(a,b)
	return a.kind==b.kind and a.size==b.size and a.radius==b.radius and a.height==b.height
end
function S.Lerp(a,b,alpha)
	local out=table.clone(a) out.frame=a.frame:Lerp(b.frame,alpha)
	return table.freeze(out)
end
local function ends(c)
	local offset=c.frame.UpVector*(c.height*0.5-c.radius)
	return c.frame.Position-offset,c.frame.Position+offset
end
-- Closest distance between two closed segments, including zero length segments.
local function segmentPair(p1,q1,p2,q2)
	local d1,d2,r=q1-p1,q2-p2,p1-p2
	local a,e,f=d1:Dot(d1),d2:Dot(d2),d2:Dot(r)
	local s,t=0,0
	if a<=1e-12 and e<=1e-12 then return r:Dot(r) end
	if a<=1e-12 then t=math.clamp(f/e,0,1)
	else
		local c=d1:Dot(r)
		if e<=1e-12 then s=math.clamp(-c/a,0,1)
		else
			local b=d1:Dot(d2) local denominator=a*e-b*b
			if denominator>1e-12 then s=math.clamp((b*f-c*e)/denominator,0,1) end
			t=(b*s+f)/e
			if t<0 then t=0 s=math.clamp(-c/a,0,1)
			elseif t>1 then t=1 s=math.clamp((b-c)/a,0,1) end
		end
	end
	local delta=r+d1*s-d2*t
	return delta:Dot(delta)
end
local function raySphere(p,q,center,radius)
	local d,m=q-p,p-center
	local a,c=d:Dot(d),m:Dot(m)-radius*radius
	if c<=EPS then return 0 end
	if a<1e-12 then return nil end
	local b=m:Dot(d) local h=b*b-a*c
	if h<0 then return nil end
	local t=(-b-math.sqrt(h))/a
	if t>=0 and t<=1 then return t end
	return nil
end
-- Point swept against a capsule. Split where projection onto its axis clamps.
-- On each piece, squared distance to the segment is a quadratic in t.
local function rayCapsule(p,q,a,b,radius)
	local axis,d,m=b-a,q-p,p-a
	local length2=axis:Dot(axis)
	if length2<1e-12 then return raySphere(p,q,a,radius) end
	local u0,du=m:Dot(axis)/length2,d:Dot(axis)/length2
	local cuts={0,1}
	if math.abs(du)>1e-12 then
		for _,u in {0,1} do local t=(u-u0)/du if t>0 and t<1 then table.insert(cuts,t) end end
	end
	table.sort(cuts)
	for i=1,#cuts-1 do
		local lower,upper=cuts[i],cuts[i+1]
		local u=u0+du*(lower+upper)*0.5
		local v,w
		if u<0 then v,w=m,d elseif u>1 then v,w=p-b,d
		else v,w=m-axis*u0,d-axis*du end
		local aa,bb,cc=w:Dot(w),2*v:Dot(w),v:Dot(v)-radius*radius
		if (aa*lower+bb)*lower+cc<=EPS then return lower end
		if aa>1e-12 then
			local discriminant=bb*bb-4*aa*cc
			if discriminant>=0 then
				local t=(-bb-math.sqrt(discriminant))/(2*aa)
				if t>=lower-EPS and t<=upper+EPS then return math.clamp(t,lower,upper) end
			end
		end
	end
	return nil
end
local function boxBox(a,b)
	local aa={a.frame.RightVector,a.frame.UpVector,a.frame.ZVector}
	local ba={b.frame.RightVector,b.frame.UpVector,b.frame.ZVector}
	local axes={aa[1],aa[2],aa[3],ba[1],ba[2],ba[3]}
	for _,u in aa do for _,v in ba do table.insert(axes,u:Cross(v)) end end
	local halfA,halfB=a.size*0.5,b.size*0.5
	local dimsA,dimsB={halfA.X,halfA.Y,halfA.Z},{halfB.X,halfB.Y,halfB.Z}
	local delta=b.frame.Position-a.frame.Position
	for _,axis in axes do
		if axis.Magnitude>1e-7 then
			axis=axis.Unit local ra,rb=0,0
			for i=1,3 do ra+=dimsA[i]*math.abs(axis:Dot(aa[i])) rb+=dimsB[i]*math.abs(axis:Dot(ba[i])) end
			if math.abs(delta:Dot(axis))>ra+rb+EPS then return false end
		end
	end
	return true
end
-- Returns the first travel fraction for a sweep, or zero for volume overlap.
-- This is exact for supplied primitives at one time; it is not continuous actor motion.
function S.Intersect(a,b)
	if a.kind=="sweep" then
		if b.kind=="box" then return G.SphereSweepOBB(a.start,a.finish,a.radius,b.frame,b.size) end
		if b.kind=="sphere" then return raySphere(a.start,a.finish,b.frame.Position,a.radius+b.radius) end
		local p,q=ends(b) return rayCapsule(a.start,a.finish,p,q,a.radius+b.radius)
	end
	local hit=false
	if a.kind=="box" and b.kind=="box" then hit=boxBox(a,b)
	elseif a.kind=="sphere" and b.kind=="sphere" then
		hit=(a.frame.Position-b.frame.Position).Magnitude<=a.radius+b.radius+EPS
	elseif a.kind=="capsule" and b.kind=="capsule" then
		local p,q=ends(a) local r,s=ends(b)
		hit=segmentPair(p,q,r,s)<=(a.radius+b.radius)^2+EPS
	elseif a.kind=="box" or b.kind=="box" then
		local box,other=if a.kind=="box" then a else b,if a.kind=="box" then b else a
		local p,q=other.frame.Position,other.frame.Position
		if other.kind=="capsule" then p,q=ends(other) end
		hit=G.SphereSweepOBB(p,q,other.radius,box.frame,box.size)~=nil
	else
		local sphere,cap=if a.kind=="sphere" then a else b,if a.kind=="sphere" then b else a
		local p,q=ends(cap)
		hit=G.SegmentDistanceSquared(p,q,sphere.frame.Position)<=(sphere.radius+cap.radius)^2+EPS
	end
	return if hit then 0 else nil
end
return table.freeze(S)
