-- Declarative shapes use unchanged Core math.
local V={}
function V.Shape(S,v)
 local f=CFrame.new(v.x,v.y,v.z)*CFrame.Angles(math.rad(v.pitch),math.rad(v.yaw),math.rad(v.roll))
 if v.shape=="Box" then return S.Box(f,Vector3.new(v.width,v.height,v.depth))
 elseif v.shape=="Sphere" then return S.Sphere(f,v.radius)
 elseif v.shape=="Capsule" then return S.Capsule(f,v.radius,v.height)
 else return S.Sweep(f.Position,(f*CFrame.new(0,0,-v.length)).Position,if v.shape=="Ray" then 0 else v.radius) end
end
function V.Zones(S,rows,root) local out={} for _,v in rows do out[v.name]=S.At(V.Shape(S,v),root) end return out end
function V.Actions(S,rows,hooks)
 local out={}
 for _,v in rows do
  local kinds={} for k in v.targets:gmatch("[^,%s]+") do table.insert(kinds,k) end
  local shape=V.Shape(S,v) assert(S.Reach(shape)<=v.maxReach,"Move "..v.name.." exceeds allowed reach")
  out[v.name]={shape=shape,targets=kinds,opens=v.opens,closes=v.closes,maxTargets=v.maxTargets,maxReach=v.maxReach,world=v.world,queryMode=if v.queryMode~="Default" then v.queryMode else nil,
   eligible=function(a,b,id,kind)
    if v.rule=="team" then return a.active==true and b.active==true and a.team~=nil and b.team~=nil and a.team~=b.team end
    if v.rule=="Hook" then return hooks.Eligible(a,b,id,kind,v.name) end return true
   end}
 end return out
end
return V
