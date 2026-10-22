-- A picture in the plugin only. These Parts never enter Workspace or affect gameplay.
local Config=require(script.Parent.Config)
local Preview={}
function Preview.Draw(parent,config)
	local frame=Instance.new("ViewportFrame") frame.Name="ShapePicture" frame.Size=UDim2.new(1,0,0,190)
	frame.BackgroundColor3=Color3.fromRGB(12,25,36) frame.BorderSizePixel=0 frame.Ambient=Color3.fromRGB(175,190,210)
	frame.LightColor=Color3.fromRGB(245,248,255) frame.LightDirection=Vector3.new(-1,-1,-1) frame.Parent=parent
	for _,problem in Config.Check(config) do if problem.page==3 then
		local label=Instance.new("TextLabel") label.Size=UDim2.fromScale(1,1) label.BackgroundTransparency=1 label.TextWrapped=true
		label.Text="Fix the hitbox settings to see the picture." label.TextColor3=Color3.fromRGB(231,236,244) label.Parent=frame return frame
	end end
	local model=Instance.new("WorldModel") model.Parent=frame
	local blue=Color3.fromRGB(64,178,238) local orange=Color3.fromRGB(255,178,78)
	local parts={}
	local function part(name,shape,size,cf,color,transparency)
		table.insert(parts,{name=name,shape=shape,size=size,frame=cf,color=color,transparency=transparency or 0})
	end
	local radius=Config.ParseNumber(config.radius) or 1.5 local forward=Config.ParseNumber(config.forward) or 0
	local center=Vector3.new(0,0,-forward) local span=math.max(6,forward+6)
	if config.shape=="Box" then
		part("Hitbox",Enum.PartType.Block,Vector3.new(config.width,config.height,config.depth),CFrame.new(center),blue)
		span=math.max(span,forward+config.width,forward+config.height,forward+config.depth)
	elseif config.shape=="Sphere" then part("Hitbox",Enum.PartType.Ball,Vector3.one*radius*2,CFrame.new(center),blue) span=math.max(span,forward+radius*2)
	elseif config.shape=="Capsule" then
		local middle=config.height-radius*2
		if middle>0 then part("Middle",Enum.PartType.Cylinder,Vector3.new(middle,radius*2,radius*2),CFrame.new(center)*CFrame.Angles(0,0,math.pi/2),blue) end
		for _,sign in {-1,1} do part("RoundEnd",Enum.PartType.Ball,Vector3.one*radius*2,CFrame.new(center+Vector3.new(0,sign*middle/2,0)),blue) end
		span=math.max(span,forward+config.height)
	else
		local length=config.length center=Vector3.new(0,0,-length/2) span=math.max(6,length)
		local width=if config.shape=="Ray" then math.max(0.06,length/180) else radius*2
		part("Line",Enum.PartType.Cylinder,Vector3.new(length,width,width),CFrame.new(center)*CFrame.Angles(0,math.pi/2,0),blue,0.3)
		if config.shape=="SweptSphere" then for _,z in {0,-length} do part("RoundEnd",Enum.PartType.Ball,Vector3.one*radius*2,CFrame.new(0,0,z),blue,0.2) end span=math.max(span,length+radius*2) end
	end
	part("ReferencePosition",Enum.PartType.Ball,Vector3.one*math.max(0.35,span/35),CFrame.new(),orange)
	-- Normalize before creating Parts, so very long previews avoid Part-size and camera limits.
	local scale=math.min(1,60/span)
	for _,data in parts do
		local p=Instance.new("Part") p.Name=data.name p.Shape=data.shape p.Size=data.size*scale
		p.CFrame=CFrame.new(data.frame.Position*scale)*data.frame.Rotation p.Color=data.color p.Transparency=data.transparency
		p.Anchored=true p.CanCollide=false p.Material=Enum.Material.SmoothPlastic p.Parent=model
	end
	local focus=center*(0.5*scale) local viewSpan=span*scale
	local camera=Instance.new("Camera") camera.FieldOfView=40 camera.CFrame=CFrame.lookAt(focus+Vector3.new(viewSpan*0.9,viewSpan*0.65,viewSpan*1.15),focus) camera.Parent=frame frame.CurrentCamera=camera
	return frame
end
return Preview
