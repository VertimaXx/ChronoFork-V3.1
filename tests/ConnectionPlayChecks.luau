-- Run from an ordinary SERVER Script after the plugin installed the test namespaces.
return function()
	local rows={} local SSS=game.ServerScriptService local actors=workspace.__ChronoConnectionActors
	local A,B,F=actors.Source,actors.Target,actors.Far
	local R=require(SSS.__ChronoRuntimeQA.Connector)
	local P=require(SSS.__ChronoProviderQA.Connector)
	local Auto=require(SSS.__ChronoAutoQA.Connector)
	local sourceFrame=CFrame.new(60,4,0) local targetFrame=CFrame.new(60,4,-4)
	local function check(name,fn) local ok,why=pcall(fn) table.insert(rows,{name=name,passed=ok,error=if ok then nil else tostring(why)}) end
	local function reset(runtime)
		for _,object in {A,B,F} do object:SetAttribute("Unapproved",nil) object:SetAttribute("Fault",nil) object:SetAttribute("Active",true) end
		runtime.Teleport(A,sourceFrame) runtime.Teleport(B,targetFrame) runtime.Teleport(F,CFrame.new(90,4,0))
	end
	task.wait(0.5) reset(R)
	check("automatic tracking and recording",function() local r=R.Inspect() assert(r.actors==3 and r.stats.captures>0) end)
	check("missing move refuses",function() assert(not R.Allows({},B)) end)
	check("approved target allowed once",function() local move=assert(R.Begin(A)) assert(R.Allows(move,B)) assert(not R.Allows(move,B)) R.Finish(move) end)
	check("existing outcome stays game owned",function() local count=0 local move=assert(R.Begin(A)) if R.Allows(move,B) then count+=7 end assert(count==7) R.Finish(move) end)
	check("distant target refused",function() local move=assert(R.Begin(A)) assert(not R.Allows(move,F)) R.Finish(move) end)
	check("cancelled move refuses",function() local move=assert(R.Begin(A)) assert(R.Cancel(move)) assert(not R.Allows(move,B)) end)
	check("finished move refuses",function() local move=assert(R.Begin(A)) R.Finish(move) assert(not R.Allows(move,B)) end)
	check("missing profile refuses",function() assert(not R.Begin(A,"Missing")) end)
	check("repeated server key refuses",function() local move=assert(R.Begin(A,"Contact",nil,"same")) assert(not R.Begin(A,"Contact",nil,"same")) R.Cancel(move) end)
	check("query only once",function() local move=assert(R.Begin(A)) assert(R.Query(move)) assert(not R.Query(move)) R.Finish(move) end)
	check("source teleport invalidates move",function() local move=assert(R.Begin(A)) R.Teleport(A,sourceFrame) assert(not R.Allows(move,B)) end)
	check("target teleport invalidates cached contacts",function() local move=assert(R.Begin(A)) assert(R.Query(move)) R.Teleport(B,CFrame.new(80,4,0)) assert(not R.Allows(move,B)) reset(R) end)
	check("roster change invalidates move",function()
		local move=assert(R.Begin(A)) local extra=F:Clone() extra.Name="Extra" extra.Parent=actors
		assert(not R.Allows(move,B)) extra:Destroy() reset(R)
	end)
	check("inactive source refuses",function() A:SetAttribute("Active",false) assert(not R.Begin(A)) A:SetAttribute("Active",true) end)
	check("inactive target cannot receive outcome",function() local move=assert(R.Begin(A)) B:SetAttribute("Active",false) assert(not R.Allows(move,B)) B:SetAttribute("Active",true) R.Finish(move) end)
	check("stale cached contacts refuse",function() local move=assert(R.Begin(A)) assert(R.Query(move)) task.wait(0.13) assert(not R.Allows(move,B)) end)
	check("expired move refuses",function() local move=assert(R.Begin(A)) task.wait(0.55) assert(not R.Allows(move,B)) end)
	-- Randomized same-shape comparisons use the actual Roblox spatial query as an independent oracle.
	local rng=Random.new(31024) local overlap=OverlapParams.new() overlap.FilterType=Enum.RaycastFilterType.Include overlap.FilterDescendantsInstances={B.HumanoidRootPart}
	for i=1,128 do check("native geometry comparison "..i,function()
		local a=CFrame.new(60,4,0)*CFrame.Angles(rng:NextNumber(-0.5,0.5),rng:NextNumber(-math.pi,math.pi),rng:NextNumber(-0.5,0.5))
		local b=CFrame.new(60+rng:NextNumber(-10,10),4+rng:NextNumber(-5,5),rng:NextNumber(-12,5))*CFrame.Angles(rng:NextNumber(-1,1),rng:NextNumber(-math.pi,math.pi),rng:NextNumber(-1,1))
		R.Teleport(A,a) R.Teleport(B,b)
		local native=#workspace:GetPartBoundsInBox(a*CFrame.new(0,0,-4),Vector3.new(8,8,6),overlap)>0
		local move=assert(R.Begin(A)) local result,why=R.Allows(move,B)
		assert(result==native,"engine="..tostring(native)..", connection="..tostring(result)..", reason="..tostring(why)) R.Finish(move)
	end) if i%16==0 then task.wait() end end
	reset(R) reset(P)
	check("existing checker connects without runtime redesign",function() local move=assert(P.Begin(A)) assert(P.Allows(move,B)) P.Finish(move) end)
	check("provider must actually approve",function() A:SetAttribute("Unapproved",true) assert(not P.Begin(A)) A:SetAttribute("Unapproved",nil) end)
	check("provider error pauses evidence",function() A:SetAttribute("Fault",true) assert(not P.Begin(A)) A:SetAttribute("Fault",nil) assert(not P.Begin(A)) end)
	check("explicit resume after provider fix",function() P.Resume(A) local move=assert(P.Begin(A)) assert(P.Allows(move,B)) P.Finish(move) end)
	local events=SSS.__ChronoRuntimeQA.TestEvents local delivered=0
	local connection=events.Outcome.Event:Connect(function(source,target,action,context,contact) assert(source==A and action=="Contact" and contact.id) if target==B then delivered+=1 end end)
	check("existing server event path applies once",function()
		events.Begin:Fire(A,"Contact","event-1",{existing=true}) task.wait(0.03) events.Query:Fire(A,"event-1") task.wait(0.03)
		events.Query:Fire(A,"event-1") task.wait(0.03) assert(delivered==1,"received "..delivered)
	end)
	check("existing cancel event stops outcome",function()
		local before=delivered events.Begin:Fire(A,"Contact","event-2") task.wait(0.03) events.Cancel:Fire(A,"event-2") task.wait(0.03) events.Query:Fire(A,"event-2") task.wait(0.03) assert(delivered==before)
	end)
	check("different existing event arguments adapt inside Hooks",function()
		local hooks=require(SSS.__ChronoRuntimeQA.Hooks) local begin,query=hooks.ReadBegin,hooks.ReadQuery
		hooks.ReadBegin=function(key,actor) return actor,"Contact",key end hooks.ReadQuery=function(key,actor) return actor,key end
		local before=delivered events.Begin:Fire("mapped",A) task.wait(0.03) events.Query:Fire("mapped",A) task.wait(0.03)
		hooks.ReadBegin=begin hooks.ReadQuery=query assert(delivered==before+1)
	end)
	check("existing outcome arguments adapt inside Hooks",function()
		local hooks=require(SSS.__ChronoRuntimeQA.Hooks) local apply=hooks.ApplyOutcome local calls=0
		hooks.ApplyOutcome=function(event,source,target,name,context,contact) calls+=1 return apply(event,source,target,name,context,contact) end
		local move=assert(R.Begin(A)) assert(R.Resolve(move)) R.Finish(move) task.wait(0.03) hooks.ApplyOutcome=apply assert(calls==1)
	end)
	connection:Disconnect()
	local autoEvents=SSS.__ChronoAutoQA.TestEvents local automatic=0 local ac=autoEvents.Outcome.Event:Connect(function() automatic+=1 end)
	reset(Auto)
	check("optional automatic hit timing",function() autoEvents.Begin:Fire(A,"Contact","auto-1") task.wait(0.3) assert(automatic==1,"received "..automatic) end)
	check("automatic timing respects cancellation",function() local before=automatic autoEvents.Begin:Fire(A,"Contact","auto-2") task.wait(0.02) autoEvents.Cancel:Fire(A,"auto-2") task.wait(0.25) assert(automatic==before) end)
	ac:Disconnect()
	-- Test actual player-owned data against both physics-only and supplied humanoid modes.
	local player=game.Players:GetPlayers()[1]
	local character=player and player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local Physics=require(SSS.__ChronoPlayerPhysicsQA.Connector)
		local Humanoid=require(SSS.__ChronoHumanoidQA.Connector)
		local root=character.HumanoidRootPart local original=root.CFrame local anchored=root.Anchored
		check("client-owned physics cannot claim server simulation",function()
			root.Anchored=false root:SetNetworkOwner(player) task.wait(0.1) assert(not Physics.Begin(character))
		end)
		check("supplied checker accepts approved player teleport",function()
			Humanoid.Teleport(character,CFrame.new(0,3,0)) task.wait(0.4) local move=assert(Humanoid.Begin(character)) Humanoid.Cancel(move)
		end)
		check("supplied checker refuses excessive horizontal movement",function()
			character:PivotTo(character:GetPivot()+Vector3.new(200,0,0)) assert(not Humanoid.Begin(character))
		end)
		check("approved teleport recovers movement evidence",function() Humanoid.Teleport(character,CFrame.new(0,3,0)) task.wait(0.4) local move=assert(Humanoid.Begin(character)) Humanoid.Cancel(move) end)
		check("server motion allowance uses existing force values",function() Humanoid.AllowMotion(character,Vector3.new(30,0,0),0.5) end)
		check("ordinary client walking and jumping remain usable",function()
			Humanoid.Teleport(character,CFrame.new(0,3,0)) task.wait(0.4)
			local before=root.Position player:SetAttribute("__ChronoQADrive",(player:GetAttribute("__ChronoQADrive") or 0)+1)
			task.wait(2.2) assert((root.Position-before).Magnitude>15,"Client movement driver did not move")
			local move=assert(Humanoid.Begin(character)) Humanoid.Cancel(move)
			assert(Humanoid.Inspect().core.stats.providerFaults==0)
		end)
		Humanoid.Teleport(character,original) root.Anchored=anchored
	else table.insert(rows,{name="real player available",passed=false,error="Player did not spawn"}) end
	local mixed=require(SSS.__ChronoMixedQA.Connector) local extra=workspace.__ChronoMixedActors local ball=extra.RoundBall local source=extra.Source
	-- The earlier cases deliberately moved this player through a DIFFERENT checker's teleport API.
	-- Synchronize this independent test checker with that approved server reset before testing its balls.
	if character and character:FindFirstChild("HumanoidRootPart") then mixed.Teleport(character,character.HumanoidRootPart.CFrame) task.wait(0.4) end
	check("players and extra objects discovered together",function() assert(mixed.Inspect().actors>=5) end)
	check("supplied checker also handles server-controlled balls",function() local move=assert(mixed.Begin(source)) assert(mixed.Allows(move,ball)) mixed.Finish(move) end)
	check("client-controlled ball still needs a genuine checker",function()
		ball.Anchored=false ball:SetNetworkOwner(player) assert(not mixed.Begin(source)) ball.Anchored=true mixed.Teleport(ball,CFrame.new(60,4,-4))
	end)
	check("server-owned ball recovers with an approved reset",function() local move=assert(mixed.Begin(source)) assert(mixed.Allows(move,ball)) mixed.Finish(move) end)
	local passed=0 for _,r in rows do if r.passed then passed+=1 end end
	return {run=#rows,passed=passed,failed=#rows-passed,cases=rows,runtime=R.Inspect(),provider=P.Inspect(),automatic=Auto.Inspect()}
end
