local Config=require(script.Parent.ConnectionConfig)
local I={}
local OWNER="ChronoV3Connections-20261024"
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
	local copy=table.clone(c) local refs=table.clone(links or {})
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
		local connector=remember(p.runtime:Clone()) connector.Name="Connector"
		for _,child in connector:GetChildren() do if child.Name~="Movement" then child:Destroy() end end
		connector.Parent=root
		local hooks=remember(p.runtime.Hooks:Clone()) hooks.Name="Hooks" hooks.Parent=root
		local config=remember(Instance.new("ModuleScript")) config.Name="Connections" write(config,connectionSource) config.Parent=root
		local data=remember(Instance.new("StringValue")) data.Name="ConnectionData" data.Value=game.HttpService:JSONEncode(c) data.Parent=root
		local links=remember(Instance.new("Folder")) links.Name="ConnectionLinks"
		for _,key in {"Actors","Provider","Begin","Query","Cancel","Outcome"} do local v=Instance.new("ObjectValue") v.Name=key v.Value=p.links[key] v.Parent=links end
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
		table.insert(sources,{name="Connector.Movement",source=connector.Movement.Source})
		local record=remember(Instance.new("StringValue")) record.Name="ConnectionRecord"
		record.Value=game:GetService("HttpService"):JSONEncode(sources) record.Parent=root
		root:SetAttribute("ConnectionSettings",game:GetService("HttpService"):JSONEncode(c))
		root:SetAttribute("ConnectionBuild","2026-10-24") root:SetAttribute("GameAdapterExercised",false)
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
	return c,links
end
function I.Save(root,c,links,d)
	if game:GetService("RunService"):IsRunning() then return nil,"Stop Play before saving settings." end
	local old,why=I.Load(root) if not old then return nil,why end
	local ok,reason=Config.Validate(c,links) if not ok then return nil,reason end
	if c.guide~=old.guide then return nil,"Guide installation stays as originally chosen. You can disable its LocalScript, or remove and reinstall the connection package." end
	local _,editor=dependencies(d)
	local original=editor:GetEditorSource(root.Connections)
	local rows=game.HttpService:JSONDecode(root.ConnectionRecord.Value)
	for _,row in rows do if row.name=="Connections" and row.source~=original then return nil,"Connections was edited manually. Copy those settings into the wizard before saving, or keep the manual file. Your code was kept." end end
	local history,editor=dependencies(d) local rec=history:TryBeginRecording("ChronoConnectionSettings","Update Chrono connection settings")
	if not rec then return nil,"Studio could not start an Undo step." end
	local oldAttribute=root:GetAttribute("ConnectionSettings") local oldData=root.ConnectionData.Value local oldLinks={}
	for _,v in root.ConnectionLinks:GetChildren() do table.insert(oldLinks,{object=v,value=v.Value}) end
	local changed,err=pcall(function()
		assert(editor:GetEditorSource(root.Connections)==original,"Settings reader changed during the save. Review again.")
		root.ConnectionData.Value=game.HttpService:JSONEncode(c)
		for _,row in oldLinks do row.object.Value=links[row.object.Name] end
		root:SetAttribute("ConnectionSettings",game.HttpService:JSONEncode(c))
	end)
	if not changed then
		root.ConnectionData.Value=oldData
		for _,row in oldLinks do row.object.Value=row.value end root:SetAttribute("ConnectionSettings",oldAttribute)
		history:FinishRecording(rec,Enum.FinishRecordingOperation.Cancel) return nil,tostring(err)
	end
	history:FinishRecording(rec,Enum.FinishRecordingOperation.Commit) return root
end
function I.Remove(root,d)
	if game:GetService("RunService"):IsRunning() then return nil,"Stop Play before removing connections." end
	if not root:FindFirstChild("ConnectionRecord") then return nil,"No connection installation record was found." end
	if #root.ConnectionPatches:GetChildren()>0 then return nil,"Restore generated game-script hooks first using their saved patch records." end
	local _,editor=dependencies(d)
	local guide=game.StarterPlayer.StarterPlayerScripts:FindFirstChild(root.Name.."ConnectionGuide")
	local connector=root:FindFirstChild("Connector")
	if connector then for _,child in connector:GetDescendants() do if child~=connector:FindFirstChild("Movement") then return nil,"Additional content inside Connector was kept. Move or back up your extension before removing supplied connections." end end end
	for _,name in {"Hooks","Connections","ConnectionData","StartConnection","ConnectionRecord"} do local child=root:FindFirstChild(name) if child and #child:GetChildren()>0 then return nil,"Additional content inside "..name.." was kept. Move or back up that extension first." end end
	if guide and #guide:GetChildren()>0 then return nil,"The guide contains extra content. Keep that extension before removing the guide." end
	for _,row in game.HttpService:JSONDecode(root.ConnectionRecord.Value) do
		local connector=root:FindFirstChild("Connector")
		local object=if row.name=="Connector.Movement" then connector and connector:FindFirstChild("Movement") else root:FindFirstChild(row.name)
		if row.name==root.Name.."ConnectionGuide" then object=guide end
		if not object or editor:GetEditorSource(object)~=row.source then return nil,"Customized or missing file: "..row.name..". Keep a copy of your edits before removing the package." end
	end
	local history=dependencies(d) local recording=history:TryBeginRecording("ChronoRemoveConnections","Remove supplied Chrono connections")
	if not recording then return nil,"Studio could not start an Undo step." end
	for _,child in root:GetChildren() do if child:GetAttribute("ChronoConnectionOwner")==OWNER then child:Destroy() end end
	if guide and guide:GetAttribute("ChronoConnectionOwner")==OWNER then guide:Destroy() end
	root:SetAttribute("ConnectionBuild",nil) root:SetAttribute("ConnectionSettings",nil)
	history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) return true
end
return I
