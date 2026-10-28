local Schema=require(script.Parent.Schema)
local Installer=require(script.Parent.Installer)
local V={}
function V.Mount(widget,template,openContact)
	local settings=Schema.Defaults() local handle local category="Start" local connections={} local renderConnections={} local buildingBody=false
	local background=Color3.fromRGB(16,23,32) local card=Color3.fromRGB(29,40,53) local accent=Color3.fromRGB(81,226,202)
	local canvas=Instance.new("Frame") canvas.Size=UDim2.fromScale(1,1) canvas.BackgroundColor3=background canvas.Parent=widget
	local function connect(signal,callback) table.insert(if buildingBody then renderConnections else connections,signal:Connect(callback)) end
	local function text(parent,value,height,size)
		local t=Instance.new("TextLabel") t.BackgroundTransparency=1 t.Size=UDim2.new(1,-12,0,height or 0) t.AutomaticSize=if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
		t.Text=value t.TextWrapped=true t.Font=Enum.Font.Gotham t.TextSize=size or 13 t.TextColor3=Color3.fromRGB(214,225,236) t.TextXAlignment=Enum.TextXAlignment.Left t.Parent=parent return t
	end
	local function button(parent,value,callback)
		local b=Instance.new("TextButton") b.Size=UDim2.new(1,-8,0,37) b.BackgroundColor3=card b.TextColor3=Color3.new(1,1,1) b.TextWrapped=true b.Text=value b.Font=Enum.Font.GothamMedium b.TextSize=13 b.Parent=parent Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
		connect(b.Activated,callback) return b
	end
	local header=text(canvas,"CHRONOFORK / FULL RUNTIME · 3.3 preview",35,15) header.Position=UDim2.fromOffset(14,7) header.TextColor3=accent
	local tabs=Instance.new("Frame") tabs.BackgroundTransparency=1 tabs.Position=UDim2.fromOffset(12,48) tabs.Size=UDim2.new(1,-24,0,84) tabs.Parent=canvas
	local grid=Instance.new("UIGridLayout") grid.CellSize=UDim2.new(1/4,-6,0,35) grid.CellPadding=UDim2.fromOffset(6,6) grid.Parent=tabs
	local body=Instance.new("ScrollingFrame") body.Position=UDim2.fromOffset(14,140) body.Size=UDim2.new(1,-28,1,-243) body.BackgroundTransparency=1 body.BorderSizePixel=0 body.ScrollBarThickness=5 body.AutomaticCanvasSize=Enum.AutomaticSize.Y body.CanvasSize=UDim2.new() body.Parent=canvas
	local layout=Instance.new("UIListLayout") layout.Padding=UDim.new(0,10) layout.Parent=body
	local status=text(canvas,"Nothing has been installed.",65) status.Position=UDim2.new(0,14,1,-94)
	local fields={
		Start={name=true,mode=true,engineConfirmed=true}, Objects={players=true,extraSource=true,tag=true,modelMode=true,fullRotation=true},
		Drawing={interpolation=true,curve=true,minBuffer=true,maxBuffer=true,predictionSeconds=true,predictionDistance=true,predictionSpeed=true},
		Network={sendHz=true,normalDistance=true,halfDistance=true,snapshots=true,gridInterval=true,gridBudget=true,byteRate=true},
		Advanced={warning=true,debugger=true,adminIds=true,deaths=true,setters=true},Experimental={},Review={},
	}
	for _,f in Schema.Fields do if f.key:match("^[A-Z_]+$") then fields.Advanced[f.key]=true end end
	for _,f in Schema.Fields do if f.key:match("^experimental") then fields.Experimental[f.key]=true end end
	local function invalidate() if handle then Installer.Discard(handle) handle=nil end status.Text="Settings changed. Review them before installation." end
	local draw
	local function field(f)
		local box=Instance.new("Frame") box.BackgroundColor3=card box.Size=UDim2.new(1,-8,0,0) box.AutomaticSize=Enum.AutomaticSize.Y box.Parent=body Instance.new("UICorner",box).CornerRadius=UDim.new(0,7)
		local pad=Instance.new("UIPadding") pad.PaddingLeft=UDim.new(0,10) pad.PaddingRight=UDim.new(0,10) pad.PaddingTop=UDim.new(0,10) pad.PaddingBottom=UDim.new(0,10) pad.Parent=box
		local list=Instance.new("UIListLayout") list.Padding=UDim.new(0,8) list.Parent=box
		text(box,f.label,nil,14)
		if f.kind=="choice" or f.kind=="boolean" then
			local names={Legacy="Chrono replication",Engine="Roblox server simulation",NATIVE="Roblox copies models",NATIVE_WITH_LOCK="Roblox models, locked transforms",CUSTOM="Separate model copies",CFRAME="Set displayed position",ALIGN="Follow using constraints",NONE="Off",SEGMENT="Stay on the segment",LINEAR="Straight, constant progress",HERMITE="Original curved smoothing"}
			local function value() return f.label..": "..(if f.kind=="boolean" then (if settings[f.key] then "On" else "Off") else (names[settings[f.key]] or tostring(settings[f.key]))) end
			local control
			control=button(box,value(),function()
				if f.kind=="boolean" then settings[f.key]=not settings[f.key] else local i=table.find(f.values,settings[f.key]) or 1 settings[f.key]=f.values[i%#f.values+1] end
				control.Text=value() invalidate()
			end) control.BackgroundColor3=Color3.fromRGB(32,85,76)
		else
			local control=Instance.new("TextBox") control.Size=UDim2.new(1,-8,0,36) control.BackgroundColor3=background control.TextColor3=Color3.new(1,1,1) control.Font=Enum.Font.Code control.TextSize=14 control.ClearTextOnFocus=false control.Text=tostring(settings[f.key]) control.Parent=box
			connect(control.FocusLost,function()
				if f.kind=="number" then
					local number=tonumber(control.Text:gsub(",","."))
					if not number then status.Text=f.label..": enter a number, such as "..f.default.."." return end
					settings[f.key]=number
				else settings[f.key]=control.Text end invalidate()
			end)
		end
		text(box,f.help)
	end
	draw=function()
		for _,c in renderConnections do c:Disconnect() end table.clear(renderConnections) buildingBody=true
		for _,child in body:GetChildren() do if child~=layout then child:Destroy() end end
		body.CanvasPosition=Vector2.zero
		if category=="Start" then
			text(body,"Restore original Chrono's movement replication, then connect competitive contact checks when your game needs them.",nil,16)
			text(body,"This is a development preview. Installation is one Undo step. Settings and game-specific hooks live inside the supplied package.")
			button(body,"Open competitive contact setup / connections",openContact)
		end
		if category=="Experimental" then
			text(body,"VERY EXPERIMENTAL · off by default",nil,17)
			text(body,"Guesses can overshoot at stops, turns, walls and teleports. Enable estimates first; drawing is a separate choice. This never makes a reported position trustworthy, changes damage decisions or supplies Roblox rollback.")
		end
		for _,f in Schema.Fields do if fields[category][f.key] then field(f) end end
		if category=="Objects" then text(body,"Selected objects must already exist in Workspace. For custom model templates, use Models and Hooks.Configure inside the added package. The original model and animation APIs remain available.") end
		if category=="Review" then
			text(body,"1. Check these settings and the exact generated settings module.\n2. Install the reviewed version.\n3. Play and inspect F4 plus Output. Test your actual moves and clients.")
			button(body,"Check settings and show changes",function()
				invalidate() local preview,summary=Installer.Preview(settings,game:GetService("Selection"):Get(),template)
				if not preview then status.Text=summary return end handle=preview
				local previous=body:FindFirstChild("ReviewText") if previous then previous:Destroy() end
				local review=text(body,summary.changes.."\n\n"..summary.behavior.."\n\n"..summary.settings) review.Name="ReviewText" review.Font=Enum.Font.Code review.TextSize=12
				status.Text="Review prepared. Install adds only the listed objects."
			end)
			button(body,"Install the reviewed package",function()
				local installed,why=Installer.Apply(handle)
				if not installed then status.Text=why return end handle=nil
				game:GetService("Selection"):Set({installed}) status.Text="Installed. Stop Play before changes/removal. F4 is a developer view; competitive damage checks still require the contact connection setup."
			end)
			button(body,"Remove selected unchanged installation",function()
				local selected=game:GetService("Selection"):Get()[1] local ok,why=Installer.Remove(selected)
				status.Text=if ok then "Installation removed in one Undo step." else why
			end)
			text(body,"Removal checks the installed sources and refuses if you edited them. Studio Undo is also available. This setup never silently changes Workspace's engine-authority settings.")
		end
		buildingBody=false
	end
	for _,name in {"Start","Objects","Drawing","Network","Advanced","Experimental","Review"} do button(tabs,name,function()category=name draw()end) end
	draw()
	return {Destroy=function() if handle then Installer.Discard(handle) end for _,list in {connections,renderConnections} do for _,c in list do c:Disconnect() end end canvas:Destroy() end}
end
return V
