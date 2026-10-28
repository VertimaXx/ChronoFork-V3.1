-- Disposable Play fixture: three model modes, data, mounting, ownership and teleports.
local M={}
function M.Start(fixture,useOriginal,experiment)
	local root=(if useOriginal then fixture.Original else fixture.ChronoFork):Clone() root.Name="ChronoForkSmoke"
	root:SetAttribute("TestExperimentalPrediction",experiment==true)
	assert(not game.ReplicatedStorage:FindFirstChild(root.Name)) root.Parent=game.ReplicatedStorage
	local settings=fixture.Tests.SmokeSettings:Clone() settings.Name="Settings" settings.Parent=root
	local F=require(root) F.Start(settings)
	local E=F.Entity local all={} local owned
	local function part(name,x,anchored)
		local p=Instance.new("Part") p.Name="ChronoSmoke"..name p.Anchored=anchored p.CanCollide=false p.CFrame=CFrame.new(x,18,0) p.Parent=workspace return p
	end
	for i,name in {"Native","Locked","Custom","Data","Mounted","Owned"} do
		local e
		if name=="Data" then e=E.new("SMOKE",nil,"NATIVE",CFrame.new(i*3,18,0))
		elseif name=="Custom" then e=E.new("SMOKE","SmokeTemplate","CUSTOM",CFrame.new(i*3,18,0))
		else e=E.new("SMOKE",part(name,i*3,name~="Locked" and name~="Owned"),if name=="Locked" then "NATIVE_WITH_LOCK" else "NATIVE") end
		E.SetData(e,{label=name,build="wire-v2"}) all[name]=e root:SetAttribute(name.."Id",e.id)
	end
	E.SetMount(all.Mounted,all.Native,CFrame.new(0,3,0))
	local player=assert(game.Players:GetPlayers()[1],"Run with a client")
	E.SetNetworkOwner(all.Owned,player)
	local client=fixture.Tests.ReplicationClient:Clone() client.Name="ChronoForkSmokeClient" client.Parent=assert(player:WaitForChild("PlayerGui",10),"PlayerGui missing") client.Enabled=true
	local start=os.clock() local stage=0 local received=false
	local connection
	connection=game:GetService("RunService").Heartbeat:Connect(function()
		local age=os.clock()-start
		for _,name in {"Native","Locked","Custom"} do local e=all[name] local p=E._GetRootPart(e) or E.GetPrimaryPart(e) if p then p.CFrame=CFrame.new((if stage>=1 then 40 else 3)+math.sin(age)*5,18,if name=="Custom" then 8 else 0)*CFrame.Angles(0.1*math.sin(age),age,0) end end
		E.Push(all.Data,os.clock(),CFrame.new(5+math.sin(age),18,0))
		if all.Owned.networkOwner==player and all.Owned.lastClientClock then
			received=true root:SetAttribute("OwnedUpdateReceived",true)
			if F.Experimental then
				local detail=F.Experimental.Prediction.Inspect(all.Owned)
				root:SetAttribute("OwnerPredictionAccepted",detail.active and detail.accepted>0 and detail.clockDomain=="owner-clock")
			end
		end
		if age>2 and stage==0 then E.SetCFrame(all.Native,CFrame.new(40,18,0)) stage=1 root:SetAttribute("Teleported",true)
		elseif age>4 and stage==1 then E.SetNetworkOwner(all.Owned,nil) local p=E.GetPrimaryPart(all.Owned) if p then p.Anchored=true end stage=2 root:SetAttribute("OwnerReturned",true)
		elseif age>5 and stage==2 then E.PauseReplication(all.Custom) E.SetInterpolationMode(all.Locked,"NONE") stage=3
		elseif age>6 and stage==3 then E.ResumeReplication(all.Custom) E.SetInterpolationMode(all.Locked,"CFRAME") E.ClearMount(all.Mounted) stage=4
		elseif age>8 then
			if F.Experimental then
				local prediction={}
				for name,e in all do local _,info=F.Experimental.Prediction.EstimateCurrent(e) prediction[name]={inspect=F.Experimental.Prediction.Inspect(e),status=info.status,model=info.model} end
				root:SetAttribute("ExperimentalReport",game.HttpService:JSONEncode(prediction))
			end
			root:SetAttribute("Complete",true) root:SetAttribute("OwnedUpdateReceived",received)
			local stats=F.Stats.SERVER root:SetAttribute("FinalMetrics",game.HttpService:JSONEncode({sentBytesPerSec=stats.BYTES_SENT_PER_SEC,receivedBytesPerSec=stats.BYTES_RECEIVED_PER_SEC,packetsPerSec=stats.PACKETS_SENT_PER_SEC,rangeMs=stats.ENTITY_GRID_UPDATE_TIME_MS,tickerMs=stats.AVG_TICKER_TIME_MS,upstream=useOriginal==true}))
			-- Keep fixture bodies still for inspection after the measured window.
			for _,e in all do local p=E._GetRootPart(e) or E.GetPrimaryPart(e) if p then p.Anchored=true end end
			connection:Disconnect()
		end
	end)
	return {root=root,runtime=F,entities=all,client=client,connection=connection}
end
return M
