-- Exact for linear translating spheres. Other shapes use explicit bounded refinement.
local C={}
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function vec(v) return typeof(v)=="Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z) and v.Magnitude<=2e7 end
function C.Spheres(a0,a1,ra,b0,b1,rb)
	assert(vec(a0) and vec(a1) and vec(b0) and vec(b1) and finite(ra) and finite(rb) and ra>=0 and rb>=0 and ra+rb<=1024,"Invalid sphere path")
	-- Vector3 arithmetic and :Dot round to float32. Subtracting two large
	-- quadratic terms there can move a grazing contact by several millistuds.
	-- Read components once and solve in Luau doubles, using closest approach.
	local rx,ry,rz=a0.X-b0.X,a0.Y-b0.Y,a0.Z-b0.Z
	local dx,dy,dz=(a1.X-a0.X)-(b1.X-b0.X),(a1.Y-a0.Y)-(b1.Y-b0.Y),(a1.Z-a0.Z)-(b1.Z-b0.Z)
	local radius=ra+rb
	local cc=rx*rx+ry*ry+rz*rz-radius*radius
	if cc<=0 then return 0 end
	local aa=dx*dx+dy*dy+dz*dz if aa<1e-20 then return nil end
	local closest=-(rx*dx+ry*dy+rz*dz)/aa
	local x,y,z=rx+dx*closest,ry+dy*closest,rz+dz*closest
	local squared=(radius*radius-(x*x+y*y+z*z))/aa
	if squared<0 then return nil end
	local first=closest-math.sqrt(squared)
	return if first>=0 and first<=1 then first else nil
end
function C.ErrorBound(speed,timeUncertainty,acceleration,sampleGap,codecError,radius,angleError)
	for _,v in {speed,timeUncertainty,acceleration,sampleGap,codecError,radius,angleError} do assert(type(v)=="number" and v==v and v>=0 and v<math.huge) end
	return speed*timeUncertainty+acceleration*sampleGap*sampleGap/8+codecError+2*radius*math.sin(math.min(angleError,math.pi)/2)
end
function C.RequiredSteps(linearDistance,angularDistance,radius,tolerance,maximum)
	assert(finite(linearDistance) and linearDistance>=0 and finite(angularDistance) and angularDistance>=0 and finite(radius) and radius>=0
		and finite(tolerance) and tolerance>0 and finite(maximum) and maximum>=1 and maximum<=4096 and maximum%1==0)
	local steps=math.max(1,math.ceil((linearDistance+angularDistance*radius)/tolerance))
	if steps>maximum then return nil,"refinement_budget" end
	return steps
end
return table.freeze(C)
