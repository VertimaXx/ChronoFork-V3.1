local folder=game.ReplicatedStorage:WaitForChild("__ChronoFlowQA")
local player=game.Players.LocalPlayer
local actor=player.Character or player.CharacterAdded:Wait()
local humanoid=actor:WaitForChild("Humanoid") local root=actor:WaitForChild("HumanoidRootPart")
repeat task.wait(0.03) until folder:GetAttribute("Walk") or not folder.Parent
local start=root.Position local peak=start.Y local began=os.clock() local jumped=false
game.RunService:BindToRenderStep("__ChronoFlow",Enum.RenderPriority.Character.Value+5,function()
	humanoid:Move(Vector3.new(1,0,0),false)
	if not jumped and os.clock()-began>0.3 then humanoid.Jump=true jumped=true end
	peak=math.max(peak,root.Position.Y)
end)
task.wait(1.8)
game.RunService:UnbindFromRenderStep("__ChronoFlow") humanoid:Move(Vector3.zero,false)
folder.Finish:FireServer({distance=root.Position.X-start.X,peak=peak-start.Y})

repeat task.wait(0.02) until folder:GetAttribute("Jump")==true or folder:GetAttribute("Done")==true
if folder:GetAttribute("Jump") then
	game.RunService:BindToRenderStep("__ChronoExtraJump",Enum.RenderPriority.Character.Value+5,function() humanoid.Jump=true end)
	task.wait(0.15)
	game.RunService:UnbindFromRenderStep("__ChronoExtraJump")
end
