-- An optional working scene shipped INSIDE the plugin. Never presented as your own game's validation.
local X={}
local function note(object)
	local record=Instance.new("StringValue") record.Name="LearningExampleSource" record.Value=object.Source record.Parent=object
end
function X.Create(package,d)
	if game:GetService("RunService"):IsRunning() then return nil,"Stop Play before adding the learning scene." end
	local name="ChronoConnectionExample"
	if workspace:FindFirstChild(name) or game.ServerScriptService:FindFirstChild(name) then return nil,"The learning scene already exists. Open its code group, or remove that example before adding another." end
	local folder=Instance.new("Folder") folder.Name=name folder.Parent=workspace
	local group
	local ok,why=pcall(function()
		for _,row in {{"Mover",Vector3.new(35,4,0)},{"Target",Vector3.new(35,4,-3)}} do
			local model=Instance.new("Model") model.Name=row[1]
			local root=Instance.new("Part") root.Name="HumanoidRootPart" root.Size=Vector3.new(2,4,2) root.Anchored=true root.CanCollide=false root.Position=row[2]
			root.Color=if row[1]=="Mover" then Color3.fromRGB(255,179,93) else Color3.fromRGB(94,225,183)
			root.Parent=model model.PrimaryPart=root model:SetAttribute("PracticeContacts",0) model.Parent=folder
		end
		local events=Instance.new("Folder") events.Name="Events" events.Parent=folder
		local links={Actors=folder}
		for _,key in {"Begin","Query","Cancel","Outcome"} do local event=Instance.new("BindableEvent") event.Name=key event.Parent=events links[key]=event end
		local C=require(package.Editor.Config) local I=require(package.Editor.Installer)
		local c=C.Default() c.name=name c.kind="actor" c.targets="actor" c.shape="Box" c.width=4 c.height=5 c.depth=5 c.forward=3 c.opens=0.12 c.closes=0.5 c.rules="all"
		local handle,err=I.Preview(c,{},package.Core) assert(handle,err) group=assert(I.Apply(handle,d))
		local CC=require(package.Editor.ConnectionConfig) local CI=require(package.Editor.ConnectionInstaller)
		local settings=CC.Default() settings.actors="Folder" settings.width=2 settings.height=4 settings.depth=2
		local plan,reason=CI.Preview(group,settings,links,package.Runtime) assert(plan,reason) assert(CI.Apply(plan,d))
		local runner=Instance.new("Script") runner.Name="RunLearningScene"
		local source=[[-- Supplied learning example. Does not alter combat, health or your game's rules.
if not game:GetService("RunService"):IsStudio() then return end
local actors=workspace.ChronoConnectionExample local events=actors.Events
events.Outcome.Event:Connect(function(source,target,action,context,contact)
 target:SetAttribute("PracticeContacts",(target:GetAttribute("PracticeContacts") or 0)+1)
 print("Chrono learning scene: checked contact with "..target.Name)
end)
task.wait(1)
while script.Parent.Parent do
 events.Begin:Fire(actors.Mover,"Contact","practice")
 task.wait(0.2) events.Query:Fire(actors.Mover,"practice")
 task.wait(2)
end
]]
		(d and d.editor or game:GetService("ScriptEditorService")):UpdateSourceAsync(runner,function() return source end)
		runner.Parent=group
		note(runner)
		group:SetAttribute("ConnectionLearningScene",true)
	end)
	if not ok then if group then
		local guide=game.StarterPlayer.StarterPlayerScripts:FindFirstChild(name.."ConnectionGuide") if guide then guide:Destroy() end group:Destroy()
	end folder:Destroy() return nil,"Learning scene was not added: "..tostring(why) end
	return group
end
function X.Remove(group,d)
	if game:GetService("RunService"):IsRunning() then return nil,"Stop Play before removing the learning scene." end
	if not group or not group:GetAttribute("ConnectionLearningScene") then return nil,"Select the supplied learning scene's code group." end
	local runner=group:FindFirstChild("RunLearningScene")
	if not runner or not runner:FindFirstChild("LearningExampleSource") or runner.Source~=runner.LearningExampleSource.Value then return nil,"The learning script was customized. Keep those edits before removing the example." end
	local CI=require(script.Parent.ConnectionInstaller)
	local ok,why=CI.Remove(group,d) if not ok then return nil,why end
	local history=d and d.history or game:GetService("ChangeHistoryService") local rec=history:TryBeginRecording("ChronoRemoveLearningScene","Remove supplied Chrono learning scene")
	if not rec then return nil,"Connections removed. Studio could not start the final scene-removal Undo step." end
	local scene=workspace:FindFirstChild("ChronoConnectionExample") if scene then scene:Destroy() end group:Destroy()
	history:FinishRecording(rec,Enum.FinishRecordingOperation.Commit) return true
end
return X
