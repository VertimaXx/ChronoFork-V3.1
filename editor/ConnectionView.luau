local Config=require(script.Parent.ConnectionConfig)
local Installer=require(script.Parent.ConnectionInstaller)
local Builder=require(script.Parent.HookBuilder)
local V={}
function V.New() return {c=Config.Default(),links={},tab="Objects",hook="Begin",vars={actor="character",target="target",token="chronoMove",action="Contact",velocity="velocity",duration="duration",frame="destinationCFrame",exit="return"},line=1} end
function V.Draw(ui,state,o)
	local root=state.root or o.root local c=state.c local links=state.links
	if root and root:FindFirstChild("Connector") and state.loadedRoot~=root then
		local saved,refs=Installer.Load(root)
		if saved then state.c=saved state.links=refs c=saved links=refs state.loadedRoot=root end
	end
	local function message(text)
		text=tostring(text) state.notice=if #text>110 then text else nil
		ui.status.Text=if state.notice then "Read the connection message above." else text
	end
	local function selected() return (if o.selection then o.selection() else game:GetService("Selection"):Get())[1] end
	local function refresh() local position=ui.content.CanvasPosition state.plan=nil state.patch=nil ui.rebuild() ui.content.CanvasPosition=position end
	local function input(label,key,values,numeric,hint)
		local f=ui.card(ui.content,"Connection_"..key) ui.label(f,label,15)
		local box=Instance.new("TextBox") box.Name="Input" box.Size=UDim2.new(1,0,0,38) box.Text=tostring(values[key]) box.ClearTextOnFocus=false
		box.Font=Enum.Font.Code box.TextSize=15 box.TextColor3=Color3.fromRGB(237,242,249) box.BackgroundColor3=Color3.fromRGB(17,23,32) box.BorderSizePixel=0 ui.place(box,f)
		if hint then ui.label(f,hint,13) end
		ui.connect(box.FocusLost,function()
			values[key]=if numeric then require(script.Parent.Config).ParseNumber(box.Text) or box.Text else box.Text
			state.plan=nil state.patch=nil message("Value updated. Check settings or regenerate the call before applying changes.")
		end)
	end
	local function choose(key,title,help)
		ui.note(title,help.."\nSelected: "..(links[key] and links[key]:GetFullName() or "none"))
		ui.button(ui.content,"Use selected object for "..title,function() links[key]=selected() refresh() end)
		if links[key] then ui.button(ui.content,"Clear "..title,function() links[key]=nil refresh() end) end
	end
	ui.label(ui.content,"Chrono supplies tracking, recording and move handling. Customize Actions and Hooks for your game.",14)
	ui.label(ui.content,"Code group: "..(root and root.Name or "choose one"),14)
	if root and root:FindFirstChild("Connector") and not state.displayedRoot then state.displayedRoot=root message("Connection files found. Use Test & restore to verify real runtime activity.") end
	ui.button(ui.content,"Use selected installed code group",function()
		local candidate=selected()
		if not candidate or not candidate:IsA("ModuleScript") or not candidate:GetAttribute("ChronoV3Owner") then message("Select the installed Chrono group under ServerScriptService.") return end
		state.root=candidate local loaded,refs=Installer.Load(candidate)
		if loaded then state.c=loaded state.links=refs end refresh()
	end)
	local tabs=Instance.new("Frame") tabs.Name="ConnectionTabs" tabs.Size=UDim2.new(1,0,0,80) tabs.BackgroundTransparency=1 ui.place(tabs,ui.content)
	for i,name in {"Objects","Events","Calls","Test & restore"} do
		local b=ui.button(tabs,name,function() state.tab=name ui.rebuild() end,state.tab==name)
		b.Size=UDim2.new(0.49,0,0,36) b.Position=UDim2.new(if i%2==0 then 0.51 else 0,0,0,if i>2 then 42 else 0)
	end
	if state.notice then ui.note("Connection message",state.notice) end
	if state.tab=="Objects" then
		ui.note("1. Which objects participate?","Players follows player characters and respawns. Folder follows its direct child models/parts. Tag follows objects marked with the chosen CollectionService tag. References follows one selected object, or a folder of objects. Objects need a root Part, unless they are Parts themselves. Each may set a ChronoKind attribute for mixed kinds, such as player and ball.")
		for _,name in {"Players","PlayersAndFolder","Folder","Tag","References"} do ui.button(ui.content,"Objects: "..(if name=="PlayersAndFolder" then "Players + extra objects" else name),function() c.actors=name refresh() end,c.actors==name) end
		if c.actors=="Folder" or c.actors=="References" or c.actors=="PlayersAndFolder" then choose("Actors","Participating objects","Select an existing Workspace folder/model/Part in Explorer, then use the button. Players + extra objects follows characters automatically and adds these objects, such as a server-controlled ball.") end
		if c.actors=="Tag" then input("Object tag","tag",c,false) end
		input("Root Part name","root",c,false,"Usually HumanoidRootPart. A tracked Part uses itself.")
		input("Default object kind","kind",c,false,"Match the target kinds in Actions. Use ChronoKind attributes for balls or other kinds.")
		ui.note("2. Who checks the position?","Server physics accepts anchored or server-owned Parts only. Player-owned movement needs either the supplied limited humanoid checker or your existing independent position checker. Selecting a label does not verify movement.")
		for _,row in {{"ServerPhysics","Server calculates physics"},{"Humanoid","Use supplied humanoid checks"},{"Provider","Connect my existing position checker"}} do ui.button(ui.content,row[2],function() c.positions=row[1] refresh() end,c.positions==row[1]) end
		if c.positions=="Provider" then
			choose("Provider","Existing position checker","Select a server ModuleScript returning Snapshot(object,time). That function must return {ok=true,root=CFrame,zones={...},state={...}} AFTER checking movement. If its API differs, adapt the small function inside this package; the plugin cannot infer that API.")
		elseif c.positions=="Humanoid" then
			ui.note("Supported movement","Checks root travel, jump height, gravity and small wall sweeps on static ground. Configure the actual allowed speeds below. Connect server knockback and teleports using Calls. Moving platforms, vehicles, flying and root-motion moves need an existing/custom checker. This is not complete anti-cheat or exact animated-body checking.")
			input("Allowed walking speed (studs/second)","walk",c,true)
			input("Allowed upward jump speed (studs/second)","jump",c,true)
			input("Root height above ground (studs)","ground",c,true,"Measure your rig. Usually about 3 for a basic R6 rig; other rigs differ.")
			ui.button(ui.content,if c.correction then "Invalid movement: return to last checked position" else "Invalid movement: refuse contact checks",function() c.correction=not c.correction refresh() end,c.correction)
			ui.button(ui.content,if state.advanced then "Hide movement tolerances" else "Show movement tolerances",function() state.advanced=not state.advanced ui.rebuild() end)
			if state.advanced then for _,row in {{"burst","Packet burst allowance (seconds)"},{"slack","Horizontal position slack (studs)"},{"verticalSlack","Vertical position slack (studs)"},{"wallRadius","Wall sweep radius (studs)"}} do input(row[2],row[1],c,true) end end
		end
		ui.note("3. Target gameplay hitbox","This is the deliberate contact shape around each object's root. It is separate from the attacking shape in Actions. It does not reconstruct animated limbs. When keeping an existing overlap test, Allows can add approval before its original outcome.")
		ui.button(ui.content,if c.partBodies then "Non-character objects: use root Part size" else "Non-character objects: use configured body shape",function() c.partBodies=not c.partBodies refresh() end,c.partBodies)
		ui.label(ui.content,"The humanoid option also accepts non-character objects whose physics the server controls. Root Part size uses a sphere for a round Ball Part, otherwise a bounding box; meshes are not exact geometry.",13)
		for _,shape in {"Box","Sphere","Capsule"} do ui.button(ui.content,"Target body: "..shape,function() c.body=shape refresh() end,c.body==shape) end
		if c.body=="Box" then input("Body width (studs)","width",c,true) input("Body height (studs)","height",c,true) input("Body depth (studs)","depth",c,true)
		else input("Body radius (studs)","radius",c,true) if c.body=="Capsule" then input("Total body height (studs)","height",c,true) end end
		input("Optional active attribute","activeAttribute",c,false,"Blank uses living Humanoid / active object. Otherwise the named server attribute must be true.")
		input("Optional team attribute","teamAttribute",c,false,"Blank uses the player's Team name when available. A team rule needs meaningful teams on both objects.")
		if root and root:FindFirstChild("Connector") then
			ui.label(ui.content,if c.guide then "Studio guide was installed. Enable/disable its LocalScript under StarterPlayerScripts." else "Studio guide was not installed. Its installation choice is kept when saving settings.",13)
		else ui.button(ui.content,if c.guide then "Studio guide: included" else "Studio guide: off",function() c.guide=not c.guide refresh() end,c.guide) end
		if root and root:FindFirstChild("Connector") then
			ui.button(ui.content,"Load saved connection settings",function() local loaded,refs=Installer.Load(root) if loaded then state.c=loaded state.links=refs refresh() else message(refs) end end)
			ui.button(ui.content,"Save connection settings (keeps customized code)",function() local obj,why=Installer.Save(root,c,links,o.dependencies) message(if obj then "Settings saved. Restart Play to load them. Hooks were kept." else why) end)
		else
			ui.button(ui.content,"Check connections and show changes",function()
				local handle,summary=Installer.Preview(root,c,links,o.runtime)
				state.plan=handle state.summary=if handle then summary else nil message(if handle then "Review the connection changes below." else summary) ui.rebuild()
			end)
			if state.summary and state.plan then
				ui.note("Changes",state.summary.changes.."\n\n"..state.summary.dependency.."\n\n"..state.summary.wiring.."\nEarlier-time compensation remains off.")
				ui.button(ui.content,"Add these reviewed connections",function()
					local obj,why=Installer.Apply(state.plan,o.dependencies) state.plan=nil state.summary=nil
					if obj then state.root=obj message("Connection package added. Select Events or Calls to connect real attacks; Play tests the actual wiring.") else message(why) end ui.rebuild()
				end,true)
			end
		end
	elseif state.tab=="Events" then
		ui.note("Existing server events","Use this page if your game already has BindableEvents for accepted moves and their results. Never connect a raw RemoteEvent. First authenticate the player and check cooldown, stamina and other move rules in the original server code. Select Calls for ordinary functions instead. If argument order differs, customize ReadBegin/ReadQuery/ReadCancel/ApplyOutcome in the supplied Hooks. Links take effect after Add connections / Save connection settings on Objects.")
		choose("Begin","Accepted move event","Arguments: sourceModel, actionName, moveKey, context. actionName defaults to Contact. moveKey identifies this active move; repeated keys refuse.")
		choose("Query","Hit moment event","Arguments: sourceModel, moveKey. Use the same key as Begin. At this moment Chrono checks contacts and sends approved targets to Outcome.")
		choose("Cancel","Cancelled move event","Arguments: sourceModel, moveKey. Fire from every existing cancellation path before it can apply an outcome.")
		choose("Outcome","Existing outcome event","Receives sourceModel, targetModel, actionName, context, contact. Keep existing damage/possession/block/parry rules in its server handler. Use Hooks to adapt unusual data; no universal damage amount is invented.")
		ui.button(ui.content,if c.autoQuery then "Hit timing: automatically once when window opens" else "Hit timing: existing Query event or generated Allows call",function() c.autoQuery=not c.autoQuery refresh() end,c.autoQuery)
		ui.note("Automatic timing is optional","Use only when one check at the opening of the hit period matches your move. It requires an Outcome event and proper cancellation links. For animation markers, existing precise timing or target loops, keep it off and use Query / Calls.")
		if root and root:FindFirstChild("Connector") then ui.button(ui.content,"Save event links and timing",function() local obj,why=Installer.Save(root,c,links,o.dependencies) message(if obj then "Event links saved. Restart Play and verify the argument order." else why) end) end
	elseif state.tab=="Calls" then
		ui.note("Generate the calls your existing scripts need","Choose the event's meaning, enter the variable names already used by your game, and preview an insertion at a selected server-script line. The plugin supplies the surrounding tracking and recording. You choose the correct location; it does not guess the meaning of arbitrary code.")
		for _,kind in {"Begin","Gate","Cancel","Finish","Motion","Teleport"} do ui.button(ui.content,"Call: "..kind,function() state.hook=kind state.patch=nil ui.rebuild() end,state.hook==kind) end
		input("Existing source character/object variable","actor",state.vars,false)
		input("Move reference variable (same scope at start and hit)","token",state.vars,false)
		input("Action name in Actions","action",state.vars,false)
		if state.hook=="Gate" or state.hook=="Motion" then input("Existing target variable","target",state.vars,false) end
		if state.hook=="Gate" then ui.button(ui.content,"When refused: "..state.vars.exit,function() state.vars.exit=if state.vars.exit=="return" then "continue" else "return" state.patch=nil ui.rebuild() end) end
		if state.hook=="Motion" then input("Existing velocity variable","velocity",state.vars,false) input("Existing duration variable","duration",state.vars,false) end
		if state.hook=="Teleport" then input("Existing destination CFrame variable","frame",state.vars,false) end
		ui.button(ui.content,"Generate call with these variable names",function() state.patch=nil ui.rebuild() end)
		local code,explanation=Builder.Generate(root,state.hook,state.vars)
		if code then
			ui.note("Where this belongs",explanation) ui.codeBox(code)
			ui.button(ui.content,"Use selected existing server script",function() state.script=selected() state.patch=nil ui.rebuild() end)
			ui.label(ui.content,"Script: "..(state.script and state.script:GetFullName() or "not selected"),14)
			input("Insert before line number","line",state,true,"Open the selected script, place its cursor on the intended line, then use Read cursor line. Always inspect the resulting edit.")
			ui.button(ui.content,"Read cursor line from selected script",function()
				local editor=game:GetService("ScriptEditorService") local doc=state.script and editor:FindScriptDocument(state.script)
				if doc then state.line=doc:GetSelectionStart() state.patch=nil ui.rebuild() else message("Open the selected script in Studio's editor first.") end
			end)
			ui.button(ui.content,if state.hook=="Teleport" then "Preview replacing the selected teleport line" else "Preview the generated insertion",function()
				local current,why=Builder.Generate(root,state.hook,state.vars)
				if not current then message(why) return end
				local handle,detail=Builder.Preview(root,state.script,state.line,current,nil,state.hook=="Teleport")
				state.patch=handle state.patchDetail=if handle then detail else nil message(if handle then "Review the full resulting script below. Your source is unchanged until Apply." else detail) ui.rebuild()
			end)
			if state.patch and state.patchDetail then
				ui.note("Reviewed edit",state.patchDetail.path.." at line "..state.patchDetail.line..". An exact copy is saved for Restore. If the source changes, this preview refuses to apply.")
				ui.codeBox(state.patchDetail.after)
				ui.button(ui.content,"Apply this reviewed game-script edit",function() local record,why=Builder.Apply(state.patch,o.dependencies) state.patch=nil message(if record then "Call inserted. A restore record is available in Test & restore." else why) ui.rebuild() end,true)
			end
		else ui.note("Call needs attention",explanation) end
	else
		ui.note("What counts as connected?","Setup completion is not proof of working combat. In Play, verify objects, position updates, accepted moves, contact checks and actual outcomes. A miss has zero contacts. A refusal has insufficient evidence. Test cancellations, respawns, teleports, joins/leaves and Studio network delay/loss with real clients.")
		ui.button(ui.content,"Read the running connection report",function()
			local reports=game.ReplicatedStorage:FindFirstChild("_ChronoConnectionReports") local report=reports and root and reports:FindFirstChild(root.Name)
			if not report then message("No running report. Install connections and press Play. Do not require another runtime instance from debugging tools.") return end
			local ok,r=pcall(game.HttpService.JSONDecode,game.HttpService,report.Value)
			if ok then state.report=r ui.rebuild() else message("Report is not ready yet.") end
		end)
		if state.report then local r=state.report local s=r.stats ui.note("Measured runtime",string.format("Objects: %d\nUpdates: %d\nMoves: %d\nChecks: %d\nContacts: %d\nOutcomes permitted: %d\nRefusals: %d\nCorrections: %d\nErrors: %d\nLast status: %s",r.actors,s.captures,s.begun,s.queries,s.contacts,s.applied,s.refused,s.corrections,s.errors,s.reason)) end
		if root then
			if root:GetAttribute("ConnectionLearningScene") then ui.button(ui.content,"Remove the supplied learning scene",function() local ok,why=require(script.Parent.ConnectionExample).Remove(root,o.dependencies) if ok then state.root=nil end message(if ok then "Learning scene removed." else why) ui.rebuild() end) end
			for _,name in {"Hooks","Connections","Actions","Connector","RunPractice"} do ui.button(ui.content,"Open "..name.." inside the package",function() local object=root:FindFirstChild(name) if object and o.openScript then o.openScript(object) else message("Add connections first, then open the supplied file.") end end) end
			local patches=root:FindFirstChild("ConnectionPatches")
			if patches then local records=patches:GetChildren() for i=#records,1,-1 do local record=records[i] ui.button(ui.content,"Restore call in "..(record:FindFirstChild("Target") and record.Target.Value and record.Target.Value.Name or record.Name),function() local ok,why=Builder.Restore(record,o.dependencies) message(if ok then "Original script restored. Other edits were kept." else why) ui.rebuild() end) end end
			ui.button(ui.content,"Remove supplied connections (keep the Core and Actions)",function() local ok,why=Installer.Remove(root,o.dependencies) message(if ok then "Supplied connection files removed. Core and Actions remain." else why) ui.rebuild() end)
		end
	end
end
return V
