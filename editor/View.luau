-- Plain-language setup. The code names remain available beside their explanations.
local Config=require(script.Parent.Config)
local Fields=require(script.Parent.Fields)
local Installer=require(script.Parent.Installer)
local Preview=require(script.Parent.Preview)
local View={}
local colors={background=Color3.fromRGB(17,23,32),card=Color3.fromRGB(28,37,49),text=Color3.fromRGB(237,242,249),muted=Color3.fromRGB(183,199,215),accent=Color3.fromRGB(94,225,183),error=Color3.fromRGB(255,181,163)}
function View.Mount(parent,options)
	local o=options or {}
	local config=Config.Default()
	local Help=require(assert(o.core,"Pass the Core ModuleScript to the setup view").Help)
	local page,mode=1,"setup"
	local helpTab="words"
	local pages={"Choose an example","Choose objects","Build a hitbox","Choose game rules","Check and add code","Connect and test"}
	local refs,advanced={},{}
	local plan,summary,installed,lastProblem=nil,nil,nil,nil
	local query,reason="","capture_required"
	local codeVisible,codeTab=false,"Actions"
	local connections,pageConnections={},{}
	local fieldsByKey={} local order=0 local destroyed=false
	local root=Instance.new("Frame") root.Name="ChronoSetup" root.Size=UDim2.fromScale(1,1) root.BackgroundColor3=colors.background root.BorderSizePixel=0 root.Parent=parent
	local function connect(signal,fn,permanent)
		local c=signal:Connect(fn) table.insert(if permanent then connections else pageConnections,c) return c
	end
	local function place(v,target)
		order+=1 v.LayoutOrder=order v.Parent=target return v
	end
	local function padding(target,amount)
		local p=Instance.new("UIPadding") p.PaddingTop=UDim.new(0,amount) p.PaddingBottom=UDim.new(0,amount) p.PaddingLeft=UDim.new(0,amount) p.PaddingRight=UDim.new(0,amount) p.Parent=target
	end
	local function stack(target)
		local list=Instance.new("UIListLayout") list.SortOrder=Enum.SortOrder.LayoutOrder list.Padding=UDim.new(0,8) list.Parent=target return list
	end
	local function label(target,text,size,color)
		local v=Instance.new("TextLabel") v.Name="Text" v.Size=UDim2.new(1,0,0,20) v.AutomaticSize=Enum.AutomaticSize.Y
		v.BackgroundTransparency=1 v.Text=tostring(text) v.TextWrapped=true v.TextXAlignment=Enum.TextXAlignment.Left v.TextYAlignment=Enum.TextYAlignment.Top
		v.Font=Enum.Font.Gotham v.TextSize=size or 16 v.TextColor3=color or colors.text return place(v,target)
	end
	local function card(target,name)
		local f=Instance.new("Frame") f.Name=name or "Card" f.Size=UDim2.new(1,0,0,0) f.AutomaticSize=Enum.AutomaticSize.Y f.BackgroundColor3=colors.card f.BorderSizePixel=0
		place(f,target) padding(f,12) stack(f) local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,8) corner.Parent=f return f
	end
	local function button(target,text,callback,selected,permanent)
		local b=Instance.new("TextButton") b.Name=text:gsub("[^%w]","") b.Size=UDim2.new(1,0,0,42) b.BackgroundColor3=if selected then Color3.fromRGB(32,84,74) else colors.card
		b.BorderSizePixel=0 b.Text=text b.TextSize=14 b.TextWrapped=true b.Font=Enum.Font.GothamMedium b.TextColor3=colors.text
		place(b,target) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,6) c.Parent=b connect(b.Activated,callback,permanent) return b
	end
	local header=Instance.new("Frame") header.Name="Header" header.Position=UDim2.fromOffset(16,14) header.Size=UDim2.new(1,-32,0,96) header.BackgroundTransparency=1 header.Parent=root
	local brand=label(header,"CHRONO V3  /  3.1",14,colors.accent) brand.Size=UDim2.new(0.48,0,0,28) brand.AutomaticSize=Enum.AutomaticSize.None
	local title=label(header,"",22) title.Position=UDim2.fromOffset(0,42) title.Size=UDim2.new(1,0,0,54) title.AutomaticSize=Enum.AutomaticSize.None
	local content=Instance.new("ScrollingFrame") content.Name="Content" content.Position=UDim2.fromOffset(16,116) content.Size=UDim2.new(1,-32,1,-238)
	content.BackgroundTransparency=1 content.BorderSizePixel=0 content.ScrollBarThickness=5 content.AutomaticCanvasSize=Enum.AutomaticSize.Y content.CanvasSize=UDim2.new() content.Parent=root
	local contentLayout=stack(content)
	local footer=Instance.new("Frame") footer.Name="Footer" footer.Position=UDim2.new(0,16,1,-112) footer.Size=UDim2.new(1,-32,0,102) footer.BackgroundTransparency=1 footer.Parent=root
	local status=label(footer,"Your game is not connected yet.",14,colors.muted) status.Size=UDim2.new(1,0,0,48) status.AutomaticSize=Enum.AutomaticSize.None
	local rebuild,go
	local back,nextButton
	local function invalidate()
		plan=nil summary=nil lastProblem=nil status.Text="Settings changed. Check them before adding code.\nYour game's connections are not checked."
	end
	local function field(key)
		local info=Fields.Items[key] local f=card(content,"Field_"..key) fieldsByKey[key]=f
		label(f,info.label..(if info.unit then " ("..info.unit..")" else ""),15)
		local input=Instance.new("TextBox") input.Name="Input" input.Size=UDim2.new(1,0,0,38) input.Text=tostring(config[key]) input.ClearTextOnFocus=false input.Font=Enum.Font.Code input.TextSize=17
		input.BackgroundColor3=colors.background input.BorderSizePixel=0 input.TextColor3=colors.text place(input,f)
		label(f,info.hint,14,colors.muted)
		local problemText=label(f,"",14,colors.error) problemText.Visible=false
		local function showProblems()
			local lines={} for _,problem in Config.Check(config) do if problem.field==key then table.insert(lines,problem.message) end end
			problemText.Text=table.concat(lines,"\n") problemText.Visible=#lines>0
		end
		showProblems()
		connect(input.FocusLost,function()
			if info.min~=nil then config[key]=Config.ParseNumber(input.Text) or input.Text else config[key]=input.Text:match("^%s*(.-)%s*$") end
			invalidate() showProblems()
		end)
	end
	local function note(heading,text)
		local f=card(content) label(f,heading,17,colors.accent) label(f,text,14,colors.muted) return f
	end
	local function openObject(object)
		if not object then lastProblem="The requested file is not available. Add the reviewed code first." rebuild() return end
		local ok,err=pcall(function()
			if o.openScript then o.openScript(object) else game:GetService("Selection"):Set({object}) end
		end)
		status.Text=if ok then "Selected "..object.Name.." in Explorer. Read its comments for the next step." else "Select the file in Explorer to open it. Studio reported: "..tostring(err)
	end
	local function currentInstall()
		if installed and installed.Parent then return installed end
		local target=o.target or game:GetService("ServerScriptService")
		local candidate=target:FindFirstChild(tostring(config.name))
		if candidate and candidate:IsA("ModuleScript") and type(candidate:GetAttribute("ChronoV3Owner"))=="string" then return candidate end
		return nil
	end
	local function preview()
		local errors=Config.Check(config)
		if #errors>0 then plan=nil summary=nil status.Text=string.format("Fix %d setting(s). Use the buttons on the review page.",#errors) return false,errors end
		local handle,detail=Installer.Preview(config,refs,o.core,o.target)
		if not handle then plan=nil summary=nil lastProblem=tostring(detail) status.Text="Code was not added. Read the message above." return false,detail end
		plan,summary=handle,detail lastProblem=nil
		status.Text="Settings checked. No code added yet.\nYour game's connections are not checked."
		return true,detail
	end
	local function install()
		if game:GetService("RunService"):IsRunning() then lastProblem="Stop Play, then return here to add the code." rebuild() return nil end
		if not plan then lastProblem="Choose Check settings first. Then add the reviewed code." rebuild() return nil end
		local ok,object,err=pcall(Installer.Apply,plan,o.dependencies)
		plan=nil
		if not ok or not object then lastProblem=if ok then tostring(err) else tostring(object) status.Text="Code was not added. Read the message above." rebuild() return nil end
		installed=object lastProblem=nil page=6
		status.Text="Code added. Next: run the practice test.\nYour game's connections are not checked."
		if o.onInstalled then o.onInstalled(object) end rebuild()
		return object
	end
	go=function(newPage,key)
		page=math.clamp(newPage,1,#pages) mode="setup"
		if key then advanced[page]=true end rebuild()
		if key then task.defer(function()
			local f=fieldsByKey[key]
			if f and f.Parent then content.CanvasPosition=Vector2.new(0,math.max(0,f.AbsolutePosition.Y-content.AbsolutePosition.Y+content.CanvasPosition.Y-8)) local input=f:FindFirstChild("Input") if input then input:CaptureFocus() end end
		end) end
	end
	local function more(text)
		button(content,(if advanced[page] then "Hide: " else "More settings: ")..text,function() advanced[page]=not advanced[page] rebuild() end)
		return advanced[page]
	end
	local function codeBox(text)
		local f=card(content,"CodeCard")
		label(f,"Select and copy this code if you want to edit it elsewhere.",14,colors.muted)
		local scroll=Instance.new("ScrollingFrame") scroll.Name="CodeScroll" scroll.Size=UDim2.new(1,0,0,240) scroll.BackgroundColor3=colors.background scroll.BorderSizePixel=0 scroll.ScrollBarThickness=4 scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y scroll.CanvasSize=UDim2.new() place(scroll,f)
		local box=Instance.new("TextBox") box.Name="Code" box.Size=UDim2.new(1,-12,0,240) box.AutomaticSize=Enum.AutomaticSize.Y box.Text=text box.TextWrapped=true box.MultiLine=true box.ClearTextOnFocus=false box.TextEditable=false box.Font=Enum.Font.Code box.TextSize=13 box.TextColor3=colors.text box.BackgroundTransparency=1 box.TextXAlignment=Enum.TextXAlignment.Left box.TextYAlignment=Enum.TextYAlignment.Top box.Parent=scroll
		button(f,"Select all code",function() box:CaptureFocus() box.CursorPosition=#text+1 box.SelectionStart=1 end)
	end
	local function learn()
		note("Help in plain language","Look up a word, or explain a result message. The real code name stays visible so you can find it in a script.")
		local tabs=Instance.new("Frame") tabs.Name="HelpTabs" tabs.Size=UDim2.new(1,0,0,40) tabs.BackgroundTransparency=1 place(tabs,content)
		local words=button(tabs,"Word meanings",function() helpTab="words" rebuild() end,helpTab=="words") words.Size=UDim2.new(0.48,0,0,40)
		local messages=button(tabs,"Result messages",function() helpTab="messages" rebuild() end,helpTab=="messages") messages.Size=UDim2.new(0.48,0,0,40) messages.Position=UDim2.new(0.52,0,0,0)
		if helpTab=="messages" then
		local errors=card(content,"MessageHelp") label(errors,"Understand a result message",18,colors.accent)
		label(errors,"Paste a reason code from your result or Output. Example: target_state_boundary.",14,colors.muted)
		local input=Instance.new("TextBox") input.Name="ReasonCode" input.Size=UDim2.new(1,0,0,38) input.Text=reason input.ClearTextOnFocus=false input.Font=Enum.Font.Code input.TextSize=14 input.TextColor3=colors.text input.BackgroundColor3=colors.background place(input,errors)
		connect(input.FocusLost,function() reason=input.Text:match("^%s*(.-)%s*$") rebuild() end)
		local h=Help.Explain(reason) label(errors,h.title,17) if h.subject then label(errors,h.subject,14,colors.muted) end
		label(errors,"What happened: "..h.meaning,14) label(errors,"What to do: "..h.fix,14,colors.accent)
		return end
		local search=Instance.new("TextBox") search.Name="WordSearch" search.Size=UDim2.new(1,0,0,40) search.PlaceholderText="Type a word, then press Enter" search.Text=query search.ClearTextOnFocus=false search.Font=Enum.Font.Gotham search.TextSize=15 search.TextColor3=colors.text search.PlaceholderColor3=colors.muted search.BackgroundColor3=colors.card place(search,content)
		connect(search.FocusLost,function() local y=content.CanvasPosition query=search.Text rebuild() content.CanvasPosition=y end)
		local entries=Help.FindTerms(query)
		label(content,tostring(#entries).." explanation(s)",14,colors.muted)
		if #entries==0 then label(content,"No matching word. Try a shorter word or clear the search.",14) end
		for _,entry in entries do local f=card(content) label(f,entry[2],17,colors.accent) label(f,"Code / technical word: "..entry[1],13,colors.muted) label(f,entry[3],14) label(f,"Example: "..entry[4],14,colors.muted) end
	end
	rebuild=function()
		for _,c in pageConnections do c:Disconnect() end table.clear(pageConnections) table.clear(fieldsByKey)
		for _,v in content:GetChildren() do if v~=contentLayout then v:Destroy() end end
		content.CanvasPosition=Vector2.zero
		title.Text=if mode=="learn" then "Words and result messages" else string.format("%d of %d  |  %s",page,#pages,pages[page])
		if back then
			back.Text=if mode=="learn" then "Return to setup" else "Back"
			back.Visible=mode=="learn" or page>1
			back.Size=UDim2.new(if mode=="learn" then 1 else 0.48,0,0,40)
		end
		if nextButton then
			nextButton.Visible=mode~="learn"
			nextButton.Text=if page==#pages then "Start page" else "Next"
			nextButton.Size=UDim2.new(if page==1 then 1 else 0.48,0,0,40)
			nextButton.Position=UDim2.new(if page==1 then 0 else 0.52,0,0,58)
		end
		if lastProblem then note("What needs attention",lastProblem) end
		if mode=="learn" then learn() return end
		if page==1 then
			note("What Chrono V3 does","Your game supplies positions and hitboxes. Chrono saves them and checks whether a move touches an allowed object. Your game decides what happens next: possession, damage, stun or another result.")
			label(content,"Start with an example. You can change every setting.",16)
			for _,entry in {{"Sports","Sports: tackle, kick or ball"},{"Melee","Melee: a close-range attack"},{"Hitscan","Instant line check: a straight shot"}} do
				button(content,entry[2],function() config=Config.Preset(entry[1],config) invalidate() go(2) end)
			end
			note("Your existing game stays in charge","Keep your movement, camera, animations, visual effects and cutscenes. You will write a small connection to your server scripts. The setup creates starting code and a safe practice test; it does not understand your game's moves automatically.")
			button(content,"I already know my settings: continue",function() go(2) end)
		elseif page==2 then
			field("name") field("kind")
			note("Which position can decide a hit?","Use positions your server calculates or checks. This is often called authoritative data. A player sending a position, or a server reading that position, does not prove that movement was allowed.")
			button(content,"Keep links to selected objects (optional)",function()
				refs=if o.selection then o.selection() else game:GetService("Selection"):Get() invalidate() status.Text=tostring(#refs).." object link(s) selected. Their positions are not approved automatically." rebuild()
			end)
			if #refs>0 then local names={} for i=1,math.min(6,#refs) do table.insert(names,refs[i].Name) end label(content,"Links: "..table.concat(names,", "),14,colors.muted) end
			note("What you will connect","In Bindings, return {root, zones, state}. Root is the main position and direction. Zones are named hitbox shapes in the map. State holds simple values such as team=2 or active=true. The next pages explain the hitbox and move.")
			if more("movement limits") then field("maxSpeed") field("maxRadius") end
		elseif page==3 then
			field("targets")
			for _,shape in Fields.Shapes do button(content,(if config.shape==shape.code then "Selected: " else "Use: ")..shape.label,function() config.shape=shape.code invalidate() rebuild() end,config.shape==shape.code) if config.shape==shape.code then label(content,shape.help,14,colors.muted) end end
			local picture=Preview.Draw(content,config) order+=1 picture.LayoutOrder=order
			label(content,"Orange: main object position. Blue: chosen hitbox or path. Picture scaled to fit; a thin line is drawn wider so you can see it.",13,colors.muted)
			if config.shape=="Ray" or config.shape=="SweptSphere" then field("length") else field("forward") end
			if config.shape=="Box" then field("width") field("height") field("depth")
			elseif config.shape~="Ray" then field("radius") if config.shape=="Capsule" then field("height") end end
			field("opens") field("closes") field("maxTargets")
			note("Very fast moves need extra care","A check uses saved positions at one time. It does not calculate every movement between updates. Use enough updates, or an appropriate straight-line sweep for your move. A sweep still holds the other objects at one chosen time.")
		elseif page==4 then
			note("Start with the present time","By default, Chrono checks the latest saved game update. Earlier-position checks are optional. Keep that default while connecting your first move.")
			button(content,"Rule example: allow all matching types",function() config.rules="all" invalidate() rebuild() end,config.rules=="all")
			button(content,"Rule example: active and on different teams",function() config.rules="team" invalidate() rebuild() end,config.rules=="team")
			label(content,if config.rules=="team" then "This example expects state.active and state.team for both objects. The practice test supplies them. Your real position functions must supply your real values." else "Allow all is only a starting example. Add your own immunity, possession, round and other rules before using real moves.",14,colors.muted)
			if more("saved positions and delay") then field("seconds") field("maxGap") field("maxRewind") end
			note("Should a wall stop this move?","Your game must choose that rule. An optional obstacle function can check earlier map data for line or moving-ball checks. Overlap moves such as tackles need your game's own wall rule. This setup does not silently decide that walls are clear.")
		elseif page==5 then
			local errors=Config.Check(config)
			if #errors>0 then
				note("Fix these settings first",tostring(#errors).." setting(s) need attention. Select one to go to its field.")
				for _,e in errors do button(content,e.message,function() go(e.page,e.field) end) end
			else
				note("Your settings",string.format("Added code: %s\nObject type: %s\nTarget types: %s\nHitbox: %s\nHits allowed from %s to %s seconds\nTotal target limit: %s",config.name,config.kind,config.targets,config.shape,config.opens,config.closes,config.maxTargets))
			end
			button(content,"Check settings and show changes",function() preview() rebuild() end)
			if summary then
				note("Where the code goes",summary.destination.."\n\n"..summary.changes)
				button(content,"Add this reviewed code",install,true)
				button(content,if codeVisible then "Hide generated code" else "Read generated code (optional)",function() codeVisible=not codeVisible rebuild() end)
				if codeVisible then
					for _,key in {"Actions","Bindings","Practice"} do button(content,"Read "..key,function() codeTab=key rebuild() end,codeTab==key) end
					codeBox(if codeTab=="Bindings" then summary.bindings elseif codeTab=="Practice" then summary.practice else summary.action)
				end
			end
			note("What this check proves","Settings checked means these values are usable. It does not prove a player's position is safe, your game is connected, or a real move works. After adding code, run the practice example, then test your own connections.")
		elseif page==6 then
			local target=currentInstall()
			if not target then note("Add the code first","Return to page 5, check the settings and add the reviewed code. You can then open the files from here.") end
			note("1. Try the safe practice example","Open RunPractice below. In Properties, turn Enabled on. Press Play and read Output for 'Chrono V3 practice'. Stop Play, then turn that test off again. It uses made-up positions and an immediate hit period, changes no map objects, and never runs in a published game.")
			button(content,"Open RunPractice test script",function() openObject(target and target:FindFirstChild("RunPractice")) end)
			note("2. Connect your real game","Open Bindings. Add a function that supplies positions and hitboxes your server calculates or checks. Call Capture after each shared update. After your move script accepts a request, use BeginAction, Query during the hit period, and EndAction when the move ends or is cancelled.")
			button(content,"Open Bindings: connections to your game",function() openObject(target and target:FindFirstChild("Bindings")) end)
			button(content,"Open Actions: hitbox and move rules",function() openObject(target and target:FindFirstChild("Actions")) end)
			button(content,"Open Practice: a complete small example",function() openObject(target and target:FindFirstChild("Practice")) end)
			note("3. Apply your game's result once","A successful Query returns contacts. Your game rechecks its current rules and applies possession, damage or stun. An empty contact list is a checked miss. A failed check has no partial result. Do not apply the same returned contacts twice.")
			note("4. Test changes and bad connections","Try joining/leaving, respawn, teleport, immunity, cancelled moves and repeated requests. Use Discontinuity after a game-approved tracking reset; Untrack removes an object. Test actual messages with Studio's Network Simulator. The practice example alone does not test your game or network.")
			if o.inspect then button(content,"Read connected game report",function()
				local ok,r=pcall(o.inspect)
				if ok and type(r)=="table" and type(r.stats)=="table" then status.Text=string.format("Recorded updates: %s. Completed checks: %s. Refused checks: %s.",r.stats.captures,r.stats.accepted,r.stats.rejected)
				else status.Text="No usable report from your game. The setup cannot confirm the connections." end
			end) end
			note("If a result is confusing","Use Core.Explain(reason) in code, or open Words & errors above and paste the reason code. It explains the message and the next step. Use the V3.1 setup and guide for this package.")
		end
	end
	local helpButton=button(header,"Words & errors",function() mode=if mode=="learn" then "setup" else "learn" rebuild() end,false,true)
	helpButton.Size=UDim2.new(0.48,0,0,30) helpButton.Position=UDim2.new(0.52,0,0,0)
	back=button(footer,"Back",function() if mode=="learn" then mode="setup" rebuild() else go(page-1) end end,false,true)
	back.Name="Back" back.Size=UDim2.new(0.48,0,0,40) back.Position=UDim2.fromOffset(0,58)
	nextButton=button(footer,"Next",function()
		if mode=="learn" then mode="setup" rebuild() else go(if page==#pages then 1 else page+1) end
	end,false,true) nextButton.Name="Next" nextButton.Size=UDim2.new(0.48,0,0,40) nextButton.Position=UDim2.new(0.52,0,0,58)
	rebuild()
	local controller={Root=root}
	function controller.Go(p) assert(p>=1 and p<=#pages) go(p) end
	function controller.Set(key,value) assert(config[key]~=nil) config[key]=value invalidate() rebuild() end
	function controller.Preview() return preview() end
	function controller.Install() return install() end
	function controller.Config() return table.clone(config) end
	function controller.Learn(text) mode="learn" helpTab="words" query=text or "" rebuild() end
	function controller.Explain(code) mode="learn" helpTab="messages" reason=code rebuild() end
	function controller.Destroy()
		if destroyed then return end destroyed=true
		for _,c in pageConnections do c:Disconnect() end for _,c in connections do c:Disconnect() end root:Destroy()
	end
	return controller
end
return View
