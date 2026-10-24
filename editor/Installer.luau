-- Edit-time only. New owned namespace, explicit preview, one undo record, no game script rewriting.
local Config=require(script.Parent.Config)
local Installer={}
local OWNER="ChronoV3-3.1.0"
local plans=setmetatable({}, {__mode="k"})
function Installer.Preview(config,references,core,service)
	local ok,why=Config.Validate(config) if not ok then return nil,why end
	if not core or not core:IsA("ModuleScript") then return nil,"The Chrono code package is missing. Import the complete setup plugin, including its Core child." end
	local target=service or game:GetService("ServerScriptService")
	if target:FindFirstChild(config.name) then return nil,"Code with this name already exists under "..target.Name..". Choose a different name, or open the existing code to edit it. Nothing has been replaced." end
	local refs={} for _,object in references or {} do
		if typeof(object)~="Instance" or not object:IsDescendantOf(game) or #refs>=64 then return nil,"Select at most 64 objects that still exist in this place. Selecting none is also allowed." end
		table.insert(refs,object)
	end
	local generated=Config.Generate(config)
	local handle=table.freeze({})
	plans[handle]={config=table.clone(config),references=refs,core=core,target=target,sources=generated}
	return handle,table.freeze({destination=target:GetFullName().."."..config.name,
		objects=#refs,declaredTrust="unverified",status="Settings checked. Your game's connections have not been tested.",
		action=generated.Actions,bindings=generated.Bindings,settings=generated.Settings,practice=generated.Practice,
		changes="Add one named code group under ServerScriptService. Includes Core (the library), Bindings (your connections), Actions (move settings), Settings, Practice, an OFF practice test Script, StartHere notes and optional object references. Your game scripts will not be edited. Nothing starts running."})
end
function Installer.Apply(handle,dependencies)
	assert(not game:GetService("RunService"):IsRunning(),"Stop Play before installing")
	local plan=plans[handle] if not plan then return nil,"First choose Check settings on the review page, then install that reviewed version." end
	local d=dependencies or {}
	local history=d.history or game:GetService("ChangeHistoryService")
	local editor=d.editor or game:GetService("ScriptEditorService")
	if plan.target:FindFirstChild(plan.config.name) then return nil,"Someone added code with this name after you checked. Choose a new name and check again. Existing code was kept." end
	for _,ref in plan.references do if not ref:IsDescendantOf(game) then return nil,"A selected object was removed. Choose the references again, then check settings." end end
	local recording=history:TryBeginRecording("ChronoV3Install","Install Chrono V3 integration")
	if not recording then return nil,"Studio could not start an Undo step. Finish any other plugin edit, then try again. No code was installed." end
	local container
	local ok,err=pcall(function()
		container=Instance.new("ModuleScript") container.Name=plan.config.name container:SetAttribute("ChronoV3Owner",OWNER)
		local function write(object,source) editor:UpdateSourceAsync(object,function() return source end) end
		write(container,plan.sources.Integration)
		local clone=plan.core:Clone() clone.Name="Core" clone.Parent=container
		for _,key in {"Actions","Bindings","Settings","Practice"} do local module=Instance.new("ModuleScript") module.Name=key write(module,plan.sources[key]) module.Parent=container end
		local runner=Instance.new("Script") runner.Name="RunPractice" runner.Enabled=false write(runner,plan.sources.RunPractice) runner.Parent=container
		local notes=Instance.new("StringValue") notes.Name="StartHere"
		notes.Value="1. Return to Plugins > Chrono V3 > ChronoConnect (page 6). Choose objects and a position source, then add the supplied connection package. It handles tracking and recording.\n\n2. Use Events for existing server BindableEvents or Calls to generate and insert reviewed calls at accepted moves, hit outcomes and cancellations. Customize Actions and Hooks inside the package.\n\n3. The supplied humanoid checker is limited to ordinary static-ground movement. Choose an existing independent provider for unsupported movement. Existing input/cooldown/stamina and outcome rules remain the game's responsibility.\n\n4. Press Play and inspect the connection report. Setup completion is not certification. Test real clients, cancellation, respawns and network impairment.\n\n5. For a small made-up API test, enable RunPractice, Play, then stop and disable it. For a working scene, use the supplied learning scene on page 1. Neither certifies your game.\n\n6. Bindings and this main constructor remain an advanced manual option. Do not start them as a second instance when Connector is running. Core.Explain(reason) explains core refusals."
		notes.Parent=container
		local references=Instance.new("Folder") references.Name="References" references.Parent=container
		for i,ref in plan.references do local value=Instance.new("ObjectValue") value.Name=string.format("Reference%02d",i) value.Value=ref value.Parent=references end
		container:SetAttribute("Configured",true) container:SetAttribute("GameAdapterExercised",false)
		container.Parent=plan.target
	end)
	if not ok then if container then container:Destroy() end history:FinishRecording(recording,Enum.FinishRecordingOperation.Cancel) return nil,"Studio could not finish writing the added code. This installation was undone. Studio reported: "..tostring(err) end
	history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit)
	plans[handle]=nil
	return container
end
return table.freeze(Installer)
