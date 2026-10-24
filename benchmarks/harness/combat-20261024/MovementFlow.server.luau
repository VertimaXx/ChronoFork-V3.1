local Players=game.Players
local folder=game.ReplicatedStorage.__ChronoFlowQA
local chrono=require(game.ServerScriptService.CombatChrono.Connector)
repeat task.wait(0.05) until game.ReplicatedStorage.__ChronoWorkflowQA:GetAttribute("Done")==true
local player=Players:GetPlayers()[1] local actor=player.Character local root=actor.HumanoidRootPart
local original=root.CFrame local wasAnchored=root.Anchored
local clientDone
local link=folder.Finish.OnServerEvent:Connect(function(p,result) if p==player then clientDone=result end end)
local rows={} local source
local function monitor(seconds)
	local deadline=os.clock()+seconds local accepted,refused=0,0 local reasons={}
	while os.clock()<deadline do
		local token,why=chrono.Begin(actor,"Contact")
		if token then accepted+=1 chrono.Finish(token) else refused+=1 reasons[why]=(reasons[why] or 0)+1 end
		task.wait(0.08)
	end
	return {accepted=accepted,refused=refused,reasons=reasons}
end
local ok,err=xpcall(function()
	root.Anchored=false chrono.Teleport(actor,CFrame.new(100,3,30)) root:SetNetworkOwner(player)
	task.wait(1.2)
	local start=root.Position
	folder:SetAttribute("Walk",true)
	local movement=monitor(3.5)
	movement.name="real client walking and jumping"
	movement.serverDistance=root.Position.X-start.X movement.client=clientDone
	movement.passed=movement.refused==0 and movement.serverDistance>15 and clientDone and clientDone.peak>3
	table.insert(rows,movement)
	source=workspace.Characters.Rig:Clone() source.Name="__ChronoFlowSource"
	for _,v in source:GetDescendants() do if v:IsA("LuaSourceContainer") then v:Destroy() elseif v:IsA("BasePart") then v.Anchored=true v.CanCollide=false end end
	source.Parent=workspace.Characters
	for _,spec in {{name="existing slight knockback",combo=1,finisher=false,seconds=1.1},{name="existing stun during a legitimate jump",combo=1,finisher=false,seconds=1.3,preJump=true},{name="existing fourth-hit knockback and ragdoll",combo=4,finisher=true,seconds=1.4}} do
		task.wait(0.5)
		chrono.Teleport(actor,CFrame.new(100,3,30))
		chrono.Teleport(source,CFrame.lookAt(Vector3.new(95,3,30),Vector3.new(100,3,30)))
		if spec.preJump then
			folder:SetAttribute("Jump",true)
			local deadline=os.clock()+2
			repeat task.wait(0.01) until root.AssemblyLinearVelocity.Y>10 or os.clock()>deadline
			assert(root.AssemblyLinearVelocity.Y>10,"client jump did not occur")
			task.wait(0.08)
		end
		local health=actor.Humanoid.Health local minimum=health
		local healthConnection=actor.Humanoid.HealthChanged:Connect(function(value) minimum=math.min(minimum,value) end)
		game.ServerStorage.Requests.DamageHumanoid:Fire(source,actor,{damage=7,punch=true,block=true,combo=spec.combo,knockback=spec.finisher,ragdoll=spec.finisher})
		local row=monitor(spec.seconds)
		healthConnection:Disconnect()
		row.name=spec.name row.damage=health-minimum row.passed=row.refused==0 and math.abs(row.damage-7)<0.01
		table.insert(rows,row)
	end
end,debug.traceback)
if source then source:Destroy() end
link:Disconnect()
chrono.Teleport(actor,original) root.Anchored=wasAnchored
if not wasAnchored then root:SetNetworkOwnershipAuto() end
folder.Result.Value=game.HttpService:JSONEncode({passed=ok and #rows==4 and (function() for _,row in rows do if not row.passed then return false end end return true end)(),error=if ok then nil else err,rows=rows,report=chrono.Inspect()})
folder:SetAttribute("Done",true)
