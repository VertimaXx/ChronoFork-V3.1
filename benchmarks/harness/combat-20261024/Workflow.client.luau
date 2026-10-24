-- Fixture-dependent real-client QA driver; not installed by the plugin.
local Players=game:GetService("Players")
local folder=game.ReplicatedStorage:WaitForChild("__ChronoWorkflowQA")
local player=Players.LocalPlayer
local character=player.Character or player.CharacterAdded:Wait()
local remotes=character:WaitForChild("CharacterHandler"):WaitForChild("Remotes")
local previous=0
while folder.Parent and folder:GetAttribute("Done")~=true do
	local phase=folder:GetAttribute("Phase") or 0
	if phase>0 and phase~=previous then
		previous=phase
		local name=folder:GetAttribute("Case")
		if name=="player holds block" then
			remotes.Block:FireServer(true) task.wait(0.3)
			remotes.LeftClick:FireServer() task.wait(0.5) remotes.Block:FireServer(false)
		elseif name=="four hit combo" then
			for _=1,4 do remotes.LeftClick:FireServer() task.wait(0.75) end
		else
			remotes.LeftClick:FireServer()
			if name=="click during cooldown" then task.wait(0.05) remotes.LeftClick:FireServer() end
		end
		folder:SetAttribute("ClientAck",phase)
		game.ReplicatedStorage.__ChronoWorkflowAck:FireServer(phase)
	end
	task.wait(0.02)
end

