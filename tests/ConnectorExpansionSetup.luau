-- Disposable Studio place only. Call Prepare from Edit after any MCP Undo recording ends.
local T={}
function T.Prepare(package)
 assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
 assert(not game.ServerScriptService:FindFirstChild("__ChronoExpandedTemplate"),"Expansion fixture already exists")
 local I=require(package.Editor.Installer) local C=require(package.Editor.Config)
 local CI=require(package.Editor.ConnectionInstaller) local CC=require(package.Editor.ConnectionConfig)
 local v=C.Default() v.name="__ChronoExpandedTemplate"
 local root=assert(I.Apply(assert(I.Preview(v,{},package.Core))))
 local c=CC.Default() c.actors="Data" c.recording="Manual" c.guide=false c.maxGap=0.2
 c.recordMaxSpeed=1000 c.moveSource="Builder" local m=CC.Move("Contact") m.opens=0 m.closes=1 m.maxTargets=8 c.moves={m}
 local function module(name,source) local v=Instance.new("ModuleScript") v.Name=name v.Source=source v.Parent=root return v end
 local clock=module("ClockProvider","local C={time=10} function C.Now() return C.time end return C")
 local timing=module("TimingProvider","local T={delay=0} function T.Resolve() return T.delay end return T")
 module("RegistryProvider","local T={objects={}} function T.Snapshots() return T.objects end return T")
 local world=module("WorldProvider","local W={value={covered=true,blocked=false,fraction=1}} function W.Check() return W.value end return W")
 local capture=Instance.new("BindableEvent") capture.Name="CaptureEvent" capture.Parent=root
 local outcome=Instance.new("BindableEvent") outcome.Name="OutcomeEvent" outcome.Parent=root
 local plan,why=CI.Preview(root,c,{Clock=clock,Timing=timing,World=world,Capture=capture,Outcome=outcome},package.Runtime)
 assert(plan,why) assert(CI.Apply(plan)) root.StartConnection.Enabled=false
 local boot=Instance.new("Script") boot.Name="__ChronoExpansionRunner"
 local reference=Instance.new("ObjectValue") reference.Name="Checks" reference.Value=package.ConnectorExpansionChecks reference.Parent=boot
 boot.Source=[[local report=Instance.new("StringValue") report.Name="__ChronoExpansionResult" report.Parent=game.ReplicatedStorage
task.wait(2)
local ok,result=pcall(function() return require(script.Checks.Value)(game.ServerScriptService.__ChronoExpandedTemplate) end)
report.Value=game.HttpService:JSONEncode({ok=ok,result=result})
]]
 boot.Parent=game.ServerScriptService return root
end
function T.Cleanup()
 assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
 for _,name in {"__ChronoExpandedTemplate","__ChronoExpansionRunner"} do local v=game.ServerScriptService:FindFirstChild(name) if v then v:Destroy() end end
end
return T
