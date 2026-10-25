local Config=require(script.Parent.ConnectionConfig)
local I={}
local OWNER="ChronoV3Connections-20261025"
local linkNames={"Actors","Provider","Registry","Clock","Timing","World","Obstacles","Begin","Query","Cancel","Outcome","Capture"}
local function connectorClone(runtime)
	local connector=runtime:Clone() connector.Name="Connector"
	if connector:FindFirstChild("Guide.client") then connector["Guide.client"]:Destroy() end
	if connector:FindFirstChild("Hooks") then connector.Hooks.Name="DefaultHooks" end
	return connector
end
local function sourceObject(root,name,guide)
	if guide and name==guide.Name then return guide end
	local object=root for segment in name:gmatch("[^.]+") do object=object and object:FindFirstChild(segment) end return object
end
local plans=setmetatable({}, {__mode="k"})
local startup=[[-- Supplied by the Chrono connection wizard. Your game owns accepted inputs and outcomes.
local ok,why=pcall(function() require(script.Parent.Connector).Start() end)
if not ok then warn("Chrono connection could not start: "..tostring(why)) end
]]
local connectionSource=[[-- Wizard values live in ConnectionData so Studio object Undo restores them reliably.
-- Customize Hooks for code changes. Do not run a second connection instance.
return game:GetService("HttpService"):JSONDecode(script.Parent.ConnectionData.Value)
]]
local function validRoot(root)
	return typeof(root)=="Instance" and root:IsA("ModuleScript") and type(root:GetAttribute("ChronoV3Owner"))=="string" and root:FindFirstChild("Core") and root:FindFirstChild("Actions") and root:FindFirstChild("Settings")
end
function I.Preview(root,c,links,runtime)
	if not validRoot(root) then return nil,"Choose an installed Chrono V3 code group first (page 5)." end
	local ok,why=Config.Validate(c,links) if not ok then return nil,why end
	if not runtime or not runtime:FindFirstChild("Movement") or not runtime:FindFirstChild("Hooks") then return nil,"This plugin is missing its connection package. Install the complete new setup file." end
	if root:FindFirstChild("Connector") then return nil,"Connections already exist here. Use Save connection settings; your customized Hooks and runtime will be kept." end
	for _,name in {"Connections","ConnectionData","Hooks","ConnectionLinks","StartConnection","ConnectionRecord","ConnectionPatches"} do if root:FindFirstChild(name) then return nil,"A file named "..name.." already exists. Choose a fresh code group; no existing file was replaced." end end
	local copy=Config.Normalize(c) local refs=table.clone(links or {})
	local handle=table.freeze({})
	plans[handle]={root=root,c=copy,links=refs,runtime=runtime}
	return handle,{destination=root:GetFullName(),positions=c.positions,
		changes="Add the supplied Connector, movement option, Hooks, settings, object/event links and server startup. Tracking and recording start automatically. Existing combat scripts change only when you explicitly insert a generated hook. No RemoteEvent is added.",
		dependency=if c.positions=="ServerPhysics" then "Player-owned positions refuse checks. Use the humanoid checker or an existing position provider for those objects."
		elseif c.positions=="Humanoid" then "Bounded humanoid root checks: ordinary static ground only. Configure allowed movement; connect legitimate knockback/teleports. This is not complete movement security."
		else "Your selected provider must independently check or calculate positions and implement Snapshot(object,time).",
		wiring=if refs.Begin and refs.Outcome and (refs.Query or c.autoQuery) then "Existing server events selected. Verify their argument order and cancellation behavior in Play."
		else "Some attack/outcome connections remain. Use the built-in hook builder for ordinary script functions, or choose matching server events."}
end
local function dependencies(d)
	d=d or {} return d.history or game:GetService("ChangeHistoryService"),d.editor or game:GetService("ScriptEditorService")
end
function I.Apply(handle,d)
	if game:GetService("RunService"):IsRunning() then return nil,"Stop Play before changing connections." end
	local p=plans[handle] if not p then return nil,"Check connections first, then add the reviewed version." end
	local c,root=p.c,p.root
	local checked,why=Config.Validate(c,p.links) if not checked then return nil,why end
	if not root.Parent or root:FindFirstChild("Connector") then return nil,"The destination changed after review. Check connections again." end
	for _,name in {"Connections","ConnectionData","Hooks","ConnectionLinks","StartConnection","ConnectionRecord","ConnectionPatches"} do if root:FindFirstChild(name) then return nil,"The destination changed after review: "..name end end
	local history,editor=dependencies(d) local recording=history:TryBeginRecording("ChronoConnections","Connect Chrono to game")
	if not recording then return nil,"Studio could not start an Undo step. Nothing changed." end
	local created={} local sources={} local guide
	local function write(object,source) editor:UpdateSourceAsync(object,function() return source end) end
	local function remember(object) table.insert(created,object) object:SetAttribute("ChronoConnectionOwner",OWNER) return object end
	local ok,err=pcall(function()
		local connector=remember(connectorClone(p.runtime))
		connector.Parent=root
		local hooks=remember(p.runtime.Hooks:Clone()) hooks.Name="Hooks" hooks.Parent=root
		local config=remember(Instance.new("ModuleScript")) config.Name="Connections" write(config,connectionSource) config.Parent=root
		local data=remember(Instance.new("StringValue")) data.Name="ConnectionData" data.Value=game.HttpService:JSONEncode(c) data.Parent=root
		local links=remember(Instance.new("Folder")) links.Name="ConnectionLinks"
		for _,key in linkNames do local v=Instance.new("ObjectValue") v.Name=key v.Value=p.links[key] v.Parent=links end
		links.Parent=root
		local boot=remember(Instance.new("Script")) boot.Name="StartConnection" write(boot,startup) boot.Parent=root
		local patches=remember(Instance.new("Folder")) patches.Name="ConnectionPatches" patches.Parent=root
		if c.guide then
			local target=game:GetService("StarterPlayer").StarterPlayerScripts local name=root.Name.."ConnectionGuide"
			assert(not target:FindFirstChild(name),"A guide with that name already exists")
			guide=remember(Instance.new("LocalScript")) guide.Name=name
			write(guide,p.runtime["Guide.client"].Source) guide:SetAttribute("ConnectionName",root.Name) guide.Parent=target
		end
		for _,obj in created do
			if obj:IsA("LuaSourceContainer") then table.insert(sources,{name=obj.Name,source=obj.Source}) end
		end
		for _,obj in connector:GetDescendants() do if obj:IsA("LuaSourceContainer") then table.insert(sources,{name="Connector."..obj.Name,source=obj.Source}) end end
		local record=remember(Instance.new("StringValue")) record.Name="ConnectionRecord"
		record.Value=game:GetService("HttpService"):JSONEncode(sources) record.Parent=root
		root:SetAttribute("ConnectionSettings",game:GetService("HttpService"):JSONEncode(c))
		root:SetAttribute("ConnectionBuild",Config.Build) root:SetAttribute("GameAdapterExercised",false)
	end)
	if not ok then for i=#created,1,-1 do created[i]:Destroy() end history:FinishRecording(recording,Enum.FinishRecordingOperation.Cancel) return nil,"Connection installation was undone: "..tostring(err) end
	history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) plans[handle]=nil
	return root
end
function I.Load(root)
	if not validRoot(root) or not root:FindFirstChild("ConnectionLinks") then return nil,"Choose a code group with connections." end
	for _,name in {"Connector","Connections","ConnectionData","Hooks","ConnectionRecord","ConnectionPatches"} do if not root:FindFirstChild(name) then return nil,"A connection file is missing: "..name..". Your remaining code was kept." end end
	local ok,c=pcall(game.HttpService.JSONDecode,game.HttpService,root.ConnectionData.Value)
	if not ok then return nil,"Stored settings are unavailable. Your existing code was kept." end
	local links={} for _,v in root.ConnectionLinks:GetChildren() do if v:IsA("ObjectValue") then links[v.Name]=v.Value end end
	return Config.Normalize(c),links
end
function I.Save(root,c,links,d)
	if game:GetService("RunService"):IsRunning() then return nil,"Stop Play before saving settings." end
	local old,why=I.Load(root) if not old then return nil,why end
	if not root.Connector:FindFirstChild("Configuration") then return nil,"Upgrade the supplied Connector in Test & restore before saving new settings. Existing code was kept." end
	local ok,reason=Config.Validate(c,links) if not ok then return nil,reason end
	c=Config.Normalize(c)
	if c.guide~=old.guide then return nil,"Guide installation stays as originally chosen. You can disable its LocalScript, or remove and reinstall the connection package." end
	local _,editor=dependencies(d)
	local original=editor:GetEditorSource(root.Connections)
	local rows=game.HttpService:JSONDecode(root.ConnectionRecord.Value)
	for _,row in rows do if row.name=="Connections" and row.source~=original then return nil,"Connections was edited manually. Copy those settings into the wizard before saving, or keep the manual file. Your code was kept." end end
	local history,editor=dependencies(d) local rec=history:TryBeginRecording("ChronoConnectionSettings","Update Chrono connection settings")
	if not rec then return nil,"Studio could not start an Undo step." end
	local oldAttribute=root:GetAttribute("ConnectionSettings") local oldData=root.ConnectionData.Value local oldLinks={} local added={}
	for _,v in root.ConnectionLinks:GetChildren() do table.insert(oldLinks,{object=v,value=v.Value}) end
	local changed,err=pcall(function()
		assert(editor:GetEditorSource(root.Connections)==original,"Settings reader changed during the save. Review again.")
		root.ConnectionData.Value=game.HttpService:JSONEncode(c)
		for _,name in linkNames do if not root.ConnectionLinks:FindFirstChild(name) then local v=Instance.new("ObjectValue") v.Name=name v.Parent=root.ConnectionLinks table.insert(added,v) end end
		for _,v in root.ConnectionLinks:GetChildren() do v.Value=links[v.Name] end
		root:SetAttribute("ConnectionSettings",game.HttpService:JSONEncode(c))
	end)
	if not changed then
		root.ConnectionData.Value=oldData
		for _,v in added do v:Destroy() end
		for _,row in oldLinks do row.object.Value=row.value end root:SetAttribute("ConnectionSettings",oldAttribute)
		history:FinishRecording(rec,Enum.FinishRecordingOperation.Cancel) return nil,tostring(err)
	end
	history:FinishRecording(rec,Enum.FinishRecordingOperation.Commit) return root
end
function I.Seed(root)
	local c=Config.Default()
	local data=root and root:FindFirstChild("SetupData")
	if data then local ok,v=pcall(game.HttpService.JSONDecode,game.HttpService,data.Value) if ok then
		c.kind=v.kind c.historySeconds=v.seconds c.maxGap=v.maxGap c.maxRewind=v.maxRewind c.recordMaxSpeed=v.maxSpeed c.recordMaxRadius=v.maxRadius
	end end
	return c
end
-- Explicit upgrade, separate from Save. Never replaces an edited Connector.
-- Hooks/Actions stay intact; newly supplied defaults fill only missing hook functions.
function I.Upgrade(root,runtime,d)
	if game:GetService("RunService"):IsRunning() then return nil,"Stop Play before upgrading." end
	local c,links=I.Load(root) if not c then return nil,links end
	if not runtime or not runtime:FindFirstChild("Configuration") then return nil,"Complete new plugin required." end
	local history,editor=dependencies(d)
	local oldRecord=root.ConnectionRecord.Value local rows=game.HttpService:JSONDecode(oldRecord) local kept={}
 local expected={}
 local guide=game.StarterPlayer.StarterPlayerScripts:FindFirstChild(root.Name.."ConnectionGuide")
 local guideBefore local guideAfter=runtime["Guide.client"].Source
	for _,row in rows do
		if row.name=="Connector" or row.name:sub(1,10)=="Connector." then
			local object=sourceObject(root,row.name) if not object or editor:GetEditorSource(object)~=row.source then return nil,"Connector was customized: "..row.name..". Keep your changes; install a fresh code group to compare." end
			expected[row.name]=true
		else
			if guide and row.name==guide.Name and editor:GetEditorSource(guide)==row.source then
				guideBefore=row.source row=table.clone(row) row.source=guideAfter
			end
			table.insert(kept,row)
		end
	end
	for _,object in root.Connector:GetDescendants() do if not expected["Connector."..object.Name] then return nil,"Connector contains an extension. Keep it before choosing an upgrade." end end
	local rec=history:TryBeginRecording("ChronoUpgradeConnections","Upgrade supplied Chrono connector") if not rec then return nil,"Studio could not start an Undo step." end
	local old=root.Connector local fresh local oldBuild=root:GetAttribute("ConnectionBuild") local oldData=root.ConnectionData.Value local oldAttribute=root:GetAttribute("ConnectionSettings") local added={}
	local ok,err=pcall(function()
		fresh=connectorClone(runtime) fresh:SetAttribute("ChronoConnectionOwner",OWNER)
		old.Parent=nil fresh.Parent=root
		if guideBefore then
			assert(editor:GetEditorSource(guide)==guideBefore,"Guide changed during upgrade")
			editor:UpdateSourceAsync(guide,function(current) return if current==guideBefore then guideAfter else nil end)
			assert(editor:GetEditorSource(guide)==guideAfter,"Guide changed during upgrade")
		end
		table.insert(kept,{name="Connector",source=fresh.Source})
		for _,object in fresh:GetDescendants() do if object:IsA("LuaSourceContainer") then table.insert(kept,{name="Connector."..object.Name,source=object.Source}) end end
		for _,name in linkNames do if not root.ConnectionLinks:FindFirstChild(name) then local v=Instance.new("ObjectValue") v.Name=name v.Parent=root.ConnectionLinks table.insert(added,v) end end
		root.ConnectionData.Value=game.HttpService:JSONEncode(c) root:SetAttribute("ConnectionSettings",root.ConnectionData.Value)
		root.ConnectionRecord.Value=game.HttpService:JSONEncode(kept) root:SetAttribute("ConnectionBuild",Config.Build)
	end)
	if not ok then
		if fresh then fresh:Destroy() end old.Parent=root for _,v in added do v:Destroy() end
		if guideBefore and editor:GetEditorSource(guide)==guideAfter then editor:UpdateSourceAsync(guide,function() return guideBefore end) end
		root.ConnectionRecord.Value=oldRecord root.ConnectionData.Value=oldData root:SetAttribute("ConnectionSettings",oldAttribute) root:SetAttribute("ConnectionBuild",oldBuild)
		history:FinishRecording(rec,Enum.FinishRecordingOperation.Cancel) return nil,tostring(err)
	end
	old:Destroy() history:FinishRecording(rec,Enum.FinishRecordingOperation.Commit) return root
end
function I.Remove(root,d)
	if game:GetService("RunService"):IsRunning() then return nil,"Stop Play before removing connections." end
	if not root:FindFirstChild("ConnectionRecord") then return nil,"No connection installation record was found." end
	if #root.ConnectionPatches:GetChildren()>0 then return nil,"Restore generated game-script hooks first using their saved patch records." end
	local _,editor=dependencies(d)
	local guide=game.StarterPlayer.StarterPlayerScripts:FindFirstChild(root.Name.."ConnectionGuide")
	local connector=root:FindFirstChild("Connector")
	local supplied={} for _,row in game.HttpService:JSONDecode(root.ConnectionRecord.Value) do supplied[row.name]=true end
	if connector then for _,child in connector:GetDescendants() do if not supplied["Connector."..child.Name] then return nil,"Additional content inside Connector was kept. Move or back up your extension before removing supplied connections." end end end
	for _,name in {"Hooks","Connections","ConnectionData","StartConnection","ConnectionRecord"} do local child=root:FindFirstChild(name) if child and #child:GetChildren()>0 then return nil,"Additional content inside "..name.." was kept. Move or back up that extension first." end end
	if guide and #guide:GetChildren()>0 then return nil,"The guide contains extra content. Keep that extension before removing the guide." end
	for _,row in game.HttpService:JSONDecode(root.ConnectionRecord.Value) do
		local connector=root:FindFirstChild("Connector")
		local object=sourceObject(root,row.name,guide)
		if not object or editor:GetEditorSource(object)~=row.source then return nil,"Customized or missing file: "..row.name..". Keep a copy of your edits before removing the package." end
	end
	local history=dependencies(d) local recording=history:TryBeginRecording("ChronoRemoveConnections","Remove supplied Chrono connections")
	if not recording then return nil,"Studio could not start an Undo step." end
	for _,child in root:GetChildren() do if tostring(child:GetAttribute("ChronoConnectionOwner")):match("^ChronoV3Connections%-%d+$") then child:Destroy() end end
	if guide and tostring(guide:GetAttribute("ChronoConnectionOwner")):match("^ChronoV3Connections%-%d+$") then guide:Destroy() end
	root:SetAttribute("ConnectionBuild",nil) root:SetAttribute("ConnectionSettings",nil)
	history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) return true
end
return I
