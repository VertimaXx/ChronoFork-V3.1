-- Reproduces the connection campaign in a DISPOSABLE Studio place with a flat baseplate.
-- Call Prepare from Edit mode, outside an existing ChangeHistory recording.
local T={}
local names={"__ChronoRuntimeQA","__ChronoProviderQA","__ChronoAutoQA","__ChronoPlayerPhysicsQA","__ChronoHumanoidQA","__ChronoMixedQA"}
function T.Prepare(package,checks)
	assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
	for _,name in names do assert(not game.ServerScriptService:FindFirstChild(name),"Test namespace already exists: "..name) end
	assert(not workspace:FindFirstChild("__ChronoConnectionActors") and not workspace:FindFirstChild("__ChronoMixedActors"),"Test actors already exist")
	local actors=Instance.new("Folder") actors.Name="__ChronoConnectionActors" actors.Parent=workspace
	local extra=Instance.new("Folder") extra.Name="__ChronoMixedActors" extra.Parent=workspace
	for _,folder in {actors,extra} do
		for _,row in {{"Source",Vector3.new(60,4,0)},{"Target",Vector3.new(60,4,-4)},{"Far",Vector3.new(90,4,0)}} do
			local model=Instance.new("Model") model.Name=row[1] local part=Instance.new("Part") part.Name="HumanoidRootPart"
			part.Size=Vector3.new(4,5,2) part.Position=row[2] part.Anchored=true part.CanCollide=false part.Parent=model
			model.PrimaryPart=part model:SetAttribute("Active",true) model.Parent=folder
		end
	end
	local ball=Instance.new("Part") ball.Name="RoundBall" ball.Shape=Enum.PartType.Ball ball.Size=Vector3.one*2 ball.CFrame=CFrame.new(60,4,-4)
	ball.Anchored=true ball.CanCollide=false ball:SetAttribute("ChronoKind","ball") ball.Parent=extra
	local provider=Instance.new("ModuleScript") provider.Name="__ChronoTestProvider"
	local core=package.Core:Clone() core.Name="Core" core.Parent=provider
	provider.Source=[[local S=require(script.Core).Shapes
return {Snapshot=function(object,time)
 if object:GetAttribute("Fault") then error("deliberate provider failure") end
 if object:GetAttribute("Unapproved") then return {ok=false} end
 local f=object.HumanoidRootPart.CFrame
 return {ok=true,root=f,zones={Body=S.Box(f,Vector3.new(4,5,2))},state={active=object:GetAttribute("Active")==true}}
end}
]]
	provider.Parent=game.ServerStorage
	local C=require(package.Editor.Config) local I=require(package.Editor.Installer)
	local CC=require(package.Editor.ConnectionConfig) local CI=require(package.Editor.ConnectionInstaller)
	for _,row in {{names[1],"ServerPhysics"},{names[2],"Provider"},{names[3],"ServerPhysics","Auto"},{names[4],"ServerPhysics","Players"},{names[5],"Humanoid","Players"},{names[6],"Humanoid","Mixed"}} do
		local c=C.Default() c.name=row[1] c.kind="actor" c.targets=if row[3]=="Mixed" then "actor,ball" else "actor"
		c.shape="Box" c.width=8 c.height=8 c.depth=6 c.forward=4 c.opens=if row[3]=="Auto" then 0.12 else 0 c.closes=0.5 c.maxTargets=16 c.rules="all" c.maxGap=0.1
		local handle,why=I.Preview(c,{},package.Core) assert(handle,why) local group=assert(I.Apply(handle))
		local settings=CC.Default() settings.positions=row[2] settings.actors=if row[3]=="Players" then "Players" elseif row[3]=="Mixed" then "PlayersAndFolder" else "Folder"
		settings.guide=false settings.autoQuery=row[3]=="Auto" settings.partBodies=row[3]=="Mixed" settings.activeAttribute=if row[3]=="Players" or row[3]=="Mixed" then "" else "Active"
		local links={Actors=if row[3]=="Mixed" then extra else actors,Provider=if row[2]=="Provider" then provider else nil}
		local events=Instance.new("Folder") events.Name="TestEvents" events.Parent=group
		for _,key in {"Begin","Query","Cancel","Outcome"} do local event=Instance.new("BindableEvent") event.Name=key event.Parent=events links[key]=event end
		local plan,err=CI.Preview(group,settings,links,package.Runtime) assert(plan,err) assert(CI.Apply(plan))
	end
	local driver=Instance.new("LocalScript") driver.Name="__ChronoMovementDriver"
	driver.Source=[[local player=game.Players.LocalPlayer
player:GetAttributeChangedSignal("__ChronoQADrive"):Connect(function()
 local character=player.Character local h=character and character:FindFirstChildOfClass("Humanoid") if not h then return end
 local began=os.clock() local jumped=false
 while os.clock()-began<1.8 and character.Parent do
  h:Move(Vector3.new(1,0,0),false)
  if not jumped and os.clock()-began>0.5 then jumped=true h.Jump=true end
  game:GetService("RunService").RenderStepped:Wait()
 end
 h:Move(Vector3.zero,false)
end)
]]
	driver.Parent=game.StarterPlayer.StarterPlayerScripts
	local boot=Instance.new("Script") boot.Name="__ChronoConnectionRunner"
	local reference=Instance.new("ObjectValue") reference.Name="Checks" reference.Value=checks reference.Parent=boot
	boot.Source=[[local report=Instance.new("StringValue") report.Name="__ChronoConnectionTestResult" report.Parent=game.ReplicatedStorage
task.wait(1)
local ok,result=pcall(function() return require(script.Checks.Value)() end)
report.Value=game.HttpService:JSONEncode({ok=ok,result=result})
]]
	boot.Parent=game.ServerScriptService
	return {names=names,message="Press Play. Read ReplicatedStorage.__ChronoConnectionTestResult. Stop Play, then call Cleanup in this disposable place."}
end
function T.Cleanup()
	assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
	for _,name in names do local object=game.ServerScriptService:FindFirstChild(name) if object then object:Destroy() end end
	for _,name in {"__ChronoConnectionActors","__ChronoMixedActors"} do local object=workspace:FindFirstChild(name) if object then object:Destroy() end end
	for _,row in {{game.ServerStorage,"__ChronoTestProvider"},{game.ServerScriptService,"__ChronoConnectionRunner"},{game.StarterPlayer.StarterPlayerScripts,"__ChronoMovementDriver"}} do local object=row[1]:FindFirstChild(row[2]) if object then object:Destroy() end end
end
return T
