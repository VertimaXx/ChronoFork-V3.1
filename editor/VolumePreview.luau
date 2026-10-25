-- Preview geometry stays inside a ViewportFrame; never changes Workspace.
local C=require(script.Parent.ConnectionConfig)
local P={}
function P.Draw(parent,rows,attack)
 local view=Instance.new("ViewportFrame") view.Name="VolumesPicture" view.Size=UDim2.new(1,0,0,210)
 view.BackgroundColor3=Color3.fromRGB(12,25,36) view.BorderSizePixel=0 view.Ambient=Color3.fromRGB(180,195,210) view.Parent=parent
 local good=true local span=6
 for _,v in rows do if not C.CheckVolume(v,attack) then good=false break end
  span=math.max(span,Vector3.new(v.x,v.y,v.z).Magnitude+math.max(v.width,v.height,v.depth,v.radius*2,if v.shape=="Ray" or v.shape=="SweptSphere" then v.length else 0))
 end
 if not good then local l=Instance.new("TextLabel") l.Size=UDim2.fromScale(1,1) l.Text="Fix the shape values, then update the picture." l.TextWrapped=true l.BackgroundTransparency=1 l.TextColor3=Color3.new(1,1,1) l.Parent=view return view end
 local scale=math.min(1,50/span) local model=Instance.new("WorldModel") model.Parent=view
 local function part(cf,size,shape,color,alpha)
  local p=Instance.new("Part") p.Anchored=true p.CanCollide=false p.Shape=shape
  p.Size=size*scale p.CFrame=CFrame.new(cf.Position*scale)*cf.Rotation p.Color=color p.Transparency=alpha or 0.2 p.Parent=model
 end
 part(CFrame.new(),Vector3.one*math.max(0.25,span/40),Enum.PartType.Ball,Color3.fromRGB(255,181,80),0)
 for i,v in rows do
  local f=CFrame.new(v.x,v.y,v.z)*CFrame.Angles(math.rad(v.pitch),math.rad(v.yaw),math.rad(v.roll))
  local color=Color3.fromHSV((0.53+(i-1)*0.13)%1,0.65,1)
  if v.shape=="Box" then part(f,Vector3.new(v.width,v.height,v.depth),Enum.PartType.Block,color)
  elseif v.shape=="Sphere" then part(f,Vector3.one*v.radius*2,Enum.PartType.Ball,color)
  elseif v.shape=="Capsule" then local h=v.height-v.radius*2
   if h>0 then part(f*CFrame.Angles(0,0,math.pi/2),Vector3.new(h,v.radius*2,v.radius*2),Enum.PartType.Cylinder,color) end
   for _,sign in {-1,1} do part(f*CFrame.new(0,sign*h/2,0),Vector3.one*v.radius*2,Enum.PartType.Ball,color) end
  else
   local width=if v.shape=="Ray" then math.max(0.06,span/180) else v.radius*2
   part(f*CFrame.new(0,0,-v.length/2)*CFrame.Angles(0,math.pi/2,0),Vector3.new(v.length,width,width),Enum.PartType.Cylinder,color)
   if v.shape=="SweptSphere" then for _,z in {0,-v.length} do part(f*CFrame.new(0,0,z),Vector3.one*v.radius*2,Enum.PartType.Ball,color) end end
  end
 end
 local camera=Instance.new("Camera") camera.FieldOfView=45
 camera.CFrame=CFrame.lookAt(Vector3.new(0.85,0.6,1.1)*span*scale,Vector3.zero) camera.Parent=view view.CurrentCamera=camera return view
end
return P

