-- Continuous checks for the declared endpoint interpolation, not arbitrary paths.
-- Unresolved intervals return UNKNOWN, never an invented clear or damage result.
local Shapes=require(script.Parent.Parent.Core.Shapes)
local Guard=require(script.Parent.Parent.Core.Guard)
local Continuous=require(script.Parent.Continuous)
local M={}
local function axes(shape)
	if shape.kind=="box" then return {shape.frame.RightVector,shape.frame.UpVector,shape.frame.ZVector} end
	if shape.kind=="capsule" then return {shape.frame.UpVector} end return {}
end
local function extent(shape,axis)
	if shape.kind=="box" then local h=shape.size/2 return math.abs(axis:Dot(shape.frame.RightVector))*h.X+math.abs(axis:Dot(shape.frame.UpVector))*h.Y+math.abs(axis:Dot(shape.frame.ZVector))*h.Z end
	if shape.kind=="capsule" then return shape.radius+(shape.height/2-shape.radius)*math.abs(axis:Dot(shape.frame.UpVector)) end
	return shape.radius
end
local function separation(a,b)
	local delta=b.frame.Position-a.frame.Position local aa,bb=axes(a),axes(b) local candidates={delta}
	for _,axis in aa do table.insert(candidates,axis) end for _,axis in bb do table.insert(candidates,axis) end
	for _,u in aa do for _,v in bb do table.insert(candidates,u:Cross(v)) end end
	-- Include sphere-to-closest-box direction, often much tighter than face axes.
	for _,pair in {{a,b},{b,a}} do
		local box,other=pair[1],pair[2]
		if box.kind=="box" then
			local p=box.frame:PointToObjectSpace(other.frame.Position) local half=box.size/2
			local closest=Vector3.new(math.clamp(p.X,-half.X,half.X),math.clamp(p.Y,-half.Y,half.Y),math.clamp(p.Z,-half.Z,half.Z))
			table.insert(candidates,other.frame.Position-box.frame:PointToWorldSpace(closest))
		end
	end
	local lower=0
	for _,axis in candidates do if axis.Magnitude>1e-7 then axis=axis.Unit lower=math.max(lower,math.abs(delta:Dot(axis))-extent(a,axis)-extent(b,axis)) end end
	return lower
end
local function rotation(a,b) local _,angle=(a.frame.Rotation:Inverse()*b.frame.Rotation):ToAxisAngle() return math.abs(angle) end
function M.Between(a0,a1,b0,b1,options)
	local o=options or {}
	a0,a1,b0,b1=Shapes.Copy(a0,true),Shapes.Copy(a1,true),Shapes.Copy(b0,true),Shapes.Copy(b1,true)
	if not a0 or not a1 or not b0 or not b1 or not Shapes.SameDimensions(a0,a1) or not Shapes.SameDimensions(b0,b1) then return table.freeze({status="unknown",reason="geometry_boundary"}) end
	local budget,tolerance,fractionTolerance=o.budget or 256,o.tolerance or 0.005,o.fractionTolerance or 0.001
	assert(Guard.Integer(budget,1,4096) and Guard.Number(tolerance) and tolerance>0 and tolerance<=1 and Guard.Number(fractionTolerance) and fractionTolerance>0 and fractionTolerance<=1)
	if a0.kind=="sphere" and b0.kind=="sphere" then
		local fraction=Continuous.Spheres(a0.frame.Position,a1.frame.Position,a0.radius,b0.frame.Position,b1.frame.Position,b0.radius)
		return table.freeze({status=if fraction then "hit" else "clear",fraction=fraction,lower=fraction,upper=fraction,exact=true,evaluations=1})
	end
	local linearA=(a1.frame.Position-a0.frame.Position).Magnitude local linearB=(b1.frame.Position-b0.frame.Position).Magnitude
	local angleA,angleB=rotation(a0,a1),rotation(b0,b1) local radiusA,radiusB=Shapes.Radius(a0),Shapes.Radius(b0)
	local scale=math.max(a0.frame.Position.Magnitude,a1.frame.Position.Magnitude,b0.frame.Position.Magnitude,b1.frame.Position.Magnitude,1)
	local numericMargin=math.max(1e-5,scale*1e-6)
	if Shapes.Intersect(a0,b0) then return table.freeze({status="hit",fraction=0,lower=0,upper=0,exact=true,evaluations=1}) end
	local stack={{0,1}} local evaluations=0
	while #stack>0 do
		if evaluations>=budget then return table.freeze({status="unknown",reason="refinement_budget",evaluations=evaluations}) end
		local interval=table.remove(stack) local lo,hi=interval[1],interval[2] local mid=(lo+hi)/2 local span=hi-lo
		local a,b=Shapes.Lerp(a0,a1,mid),Shapes.Lerp(b0,b1,mid) evaluations+=1
		-- Every point can move this far from its midpoint pose over the interval.
		local travel=(linearA+linearB)*span/2+2*radiusA*math.sin(math.min(math.pi,angleA*span)/4)+2*radiusB*math.sin(math.min(math.pi,angleB*span)/4)
		if separation(a,b)>travel+numericMargin then continue end
		if span<=fractionTolerance or travel<=tolerance then
			for _,fraction in {lo,mid,hi} do
				if Shapes.Intersect(Shapes.Lerp(a0,a1,fraction),Shapes.Lerp(b0,b1,fraction)) then
					return table.freeze({status="hit",fraction=fraction,lower=lo,upper=hi,exact=false,evaluations=evaluations})
				end
			end
			return table.freeze({status="unknown",reason="interval_unresolved",lower=lo,upper=hi,evaluations=evaluations})
		end
		-- Left interval is visited first so any returned contact includes a bound
		-- on earliest contact. A preceding unknown interval prevents a later hit.
		table.insert(stack,{mid,hi}) table.insert(stack,{lo,mid})
	end
	return table.freeze({status="clear",exact=false,evaluations=evaluations})
end
return table.freeze(M)
