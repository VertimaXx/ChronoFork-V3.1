-- All writes are additive, reviewed and contained in one Studio Undo recording.
local Schema=require(script.Parent.Schema)
local I={} local plans=setmetatable({}, {__mode="k"})
local owner="ChronoForkFull-3.3.0-dev"
local function targets(name)
	return {game:GetService("ReplicatedStorage"),game:GetService("ServerScriptService"),game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),game:GetService("ServerStorage")}, {name,name.."Server",name.."Client",name.."InstallManifest"}
end
function I.Discard(handle) local p=plans[handle] if p then p.template:Destroy() plans[handle]=nil end end
function I.Preview(config,references,template)
	local ok,why=Schema.Validate(config) if not ok then return nil,why end
	if not template or not template:IsA("ModuleScript") or not template:FindFirstChild("Replication") or not template:FindFirstChild("Bootstrap") then return nil,"Import the complete full-runtime setup plugin." end
	local services,names=targets(config.name)
	for n,parent in services do if parent:FindFirstChild(names[n]) then return nil,parent.Name.." already contains "..names[n]..". Choose a new name or use the existing package." end end
	if config.players then
		for _,existing in services[1]:GetChildren() do
			if existing:GetAttribute("ChronoForkOwner")==owner then
				local data=existing:FindFirstChild("SetupData") local decoded,other=pcall(function()return game.HttpService:JSONDecode(data.Value)end)
				if decoded and other.players then return nil,"A ChronoFork player package already exists: "..existing.Name..". Use it, or remove it before starting a second player driver." end
			end
		end
	end
	local refs={}
	if config.extraSource=="Selection" then
		for _,o in references or {} do
			if #refs>=64 or typeof(o)~="Instance" or not o:IsDescendantOf(workspace) or not (o:IsA("BasePart") or o:IsA("Model")) then return nil,"Select up to 64 whole Models or Parts in Workspace." end
			if o:IsA("Model") and not o.PrimaryPart then return nil,"Set PrimaryPart on "..o.Name.." first. It is the part whose position represents the model." end
			table.insert(refs,o)
		end
		if #refs==0 then return nil,"Select objects in Explorer, or choose None / Tag." end
	end
	local handle=table.freeze({}) local copy=table.freeze(table.clone(config))
	plans[handle]={config=copy,refs=refs,template=template:Clone(),services=services,names=names,settings=Schema.Generate(copy)}
	local experiment=if config.experimentalPrediction then " VERY EXPERIMENTAL prediction enabled; drawing "..(if config.experimentalDraw then "ON" else "OFF")..". Estimates are separate from actual positions and hit evidence. Assumed source delay: "..config.experimentalDelay.." seconds (not measured)." else " Experimental prediction remains OFF."
	return handle,table.freeze({settings=plans[handle].settings,changes="Add ReplicatedStorage."..names[1]..", ServerScriptService."..names[2]..", and StarterPlayerScripts."..names[3]..". Includes settings, hooks, full replication, competitive library and developer panel. Existing scripts stay intact."..experiment,
		behavior=if config.mode=="Engine" then "Engine adapter: configure the supplied Hooks.Simulate with your game's shared controller. Installation does not create a complete character controller." else "Starts original-compatible replication. Drawing curve: "..config.curve..". Visual prediction: "..config.predictionSeconds.." seconds. This does not turn observed client movement into verified hit evidence."})
end
local function write(editor,object,source) editor:UpdateSourceAsync(object,function()return source end) end
function I.Apply(handle,dependencies)
	assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing")
	local p=plans[handle] if not p then return nil,"Check settings and review the changes first." end
	for n,parent in p.services do if parent:FindFirstChild(p.names[n]) then return nil,"An object was added after review. Check the settings again." end end
	for _,ref in p.refs do if not ref:IsDescendantOf(workspace) then return nil,"A selected object was removed. Review the selection again." end end
	local d=dependencies or {} local history=d.history or game:GetService("ChangeHistoryService") local editor=d.editor or game:GetService("ScriptEditorService")
	local recording=history:TryBeginRecording("ChronoForkFullInstall","Install ChronoFork full runtime")
	if not recording then return nil,"Studio could not start an Undo step. No code was added." end
	local made={} local package
	local ok,why=pcall(function()
		package=p.template:Clone() package.Name=p.names[1] package:SetAttribute("ChronoForkOwner",owner) package:SetAttribute("ChronoForkRuntimeMode",p.config.mode)
		local settings=Instance.new("ModuleScript") settings.Name="Settings" write(editor,settings,p.settings) settings.Parent=package
		local data=Instance.new("StringValue") data.Name="SetupData" data.Value=game:GetService("HttpService"):JSONEncode(p.config) data.Parent=package
		local refs=Instance.new("Folder") refs.Name="References" refs.Parent=package
		local models=Instance.new("Folder") models.Name="Models" models.Parent=package
		for n,ref in p.refs do local value=Instance.new("ObjectValue") value.Name=string.format("Object%02d",n) value.Value=ref value.Parent=refs end
		-- Exact-source backups belong on the server, not in every player's download.
		local manifest=Instance.new("Folder") manifest.Name=p.names[4] table.insert(made,manifest)
		local manifestLink=Instance.new("ObjectValue") manifestLink.Name="InstallManifest" manifestLink.Value=manifest manifestLink.Parent=package
		local token=game:GetService("HttpService"):GenerateGUID(false) package:SetAttribute("ChronoForkInstallId",token)
		manifest:SetAttribute("ChronoForkInstallId",token) manifest:SetAttribute("ChronoForkOwner",owner)
		local function remember(object,parent)
			local ref=Instance.new("ObjectValue") ref.Name="OwnedObject" ref.Value=object ref.Parent=manifest
			ref:SetAttribute("InstalledName",object.Name)
			local previousParent=Instance.new("ObjectValue") previousParent.Name="InstalledParent" previousParent.Value=parent or object.Parent previousParent.Parent=ref
			if object:IsA("LuaSourceContainer") then local exact=Instance.new("StringValue") exact.Name="InstalledSource" exact.Value=object.Source exact.Parent=ref end
		end
		local scripts={}
		for n=2,3 do
			local scriptObject=Instance.new(if n==2 then "Script" else "LocalScript") scriptObject.Name=p.names[n] scriptObject.Enabled=false
			scriptObject:SetAttribute("ChronoForkInstallId",token) scriptObject:SetAttribute("ChronoForkOwner",owner)
			write(editor,scriptObject,"local package=game:GetService(\"ReplicatedStorage\"):WaitForChild("..string.format("%q",p.names[1])..",30)\nassert(package,\"ChronoFork package did not arrive\")\nlocal bootstrap=package:WaitForChild(\"Bootstrap\",30)\nassert(bootstrap,\"ChronoFork bootstrap did not arrive\")\nrequire(bootstrap).Start(package)\n")
			table.insert(scripts,scriptObject) table.insert(made,scriptObject)
		end
		for _,o in package:GetDescendants() do remember(o) end
		remember(package,p.services[1]) for n,o in scripts do remember(o,p.services[n+1]) end
		local paths={} for _,o in package:GetDescendants() do
			local pieces={} local current=o while current~=package do table.insert(pieces,1,current.Name) current=current.Parent end
			table.insert(paths,table.concat(pieces,"/"))
		end table.sort(paths) package.ReadyPaths.Value=game:GetService("HttpService"):JSONEncode(paths)
		manifest.Parent=p.services[4]
		table.insert(made,package) package.Parent=p.services[1]
		for n,o in scripts do o.Parent=p.services[n+1] o.Enabled=true end
	end)
	if not ok then for _,o in made do o:Destroy() end if package then package:Destroy() end history:FinishRecording(recording,Enum.FinishRecordingOperation.Cancel) return nil,"Installation was undone: "..tostring(why) end
	history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) I.Discard(handle)
	return package
end
function I.PreviewRemove(package)
	if not package or package:GetAttribute("ChronoForkOwner")~=owner then return nil,"Select an installed full-runtime package in ReplicatedStorage." end
	local manifest=package:FindFirstChild("InstallManifest") if manifest and manifest:IsA("ObjectValue") then manifest=manifest.Value end
	if not manifest then return nil,"The install record is missing. Use Studio Undo or review the package manually." end
	local owned={} local token=package:GetAttribute("ChronoForkInstallId")
	local remembered={}
	if manifest.Parent==game:GetService("ServerStorage") and (manifest:GetAttribute("ChronoForkInstallId")~=token or manifest:GetAttribute("ChronoForkOwner")~=owner) then return nil,"The private install record does not match this package." end
	for _,ref in manifest:GetChildren() do
		local o=ref.Value if not o then return nil,"An installed object was moved or removed. Review it manually to preserve your work." end
		remembered[o]=true
		local previousParent=ref:FindFirstChild("InstalledParent")
		if previousParent and (previousParent.Value~=o.Parent or ref:GetAttribute("InstalledName")~=o.Name) then return nil,"An installed object was moved or renamed. Review it manually to preserve your work." end
		local exact=ref:FindFirstChild("InstalledSource")
		if exact and (not o:IsA("LuaSourceContainer") or o.Source~=exact.Value) then return nil,o.Name.." was edited after installation. Removal is blocked to preserve those edits; use Undo or back up and review manually." end
		if o==package or o:IsDescendantOf(package) then continue end
		if o:GetAttribute("ChronoForkInstallId")~=token then return nil,"An install link points outside this package. Review it manually." end
		table.insert(owned,o)
	end
	if manifest.Parent==game:GetService("ServerStorage") then
		for _,o in package:GetDescendants() do if not remembered[o] then return nil,"Objects were added after installation. Removal is blocked to preserve those additions." end end
		table.insert(owned,manifest)
	end
	table.insert(owned,package) return owned
end
function I.Remove(package,dependencies)
	assert(not game:GetService("RunService"):IsRunning(),"Stop Play before removal")
	local owned,why=I.PreviewRemove(package) if not owned then return nil,why end
	local history=if dependencies then dependencies.history else game:GetService("ChangeHistoryService")
	local rec=history:TryBeginRecording("ChronoForkFullRemove","Remove unchanged ChronoFork installation") if not rec then return nil,"Studio could not start Undo." end
	for _,o in owned do o:Destroy() end history:FinishRecording(rec,Enum.FinishRecordingOperation.Commit) return true
end
return I
