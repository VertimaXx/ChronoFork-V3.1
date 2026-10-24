-- Disposable ordinary server test; removed after Play.
local Players=game:GetService("Players")
local H=game:GetService("HttpService")
local RS=game:GetService("ReplicatedStorage")
local folder=RS.__ChronoWorkflowQA
local ackConnection=RS.__ChronoWorkflowAck.OnServerEvent:Connect(function(player,phase)
	if player==Players:GetPlayers()[1] and type(phase)=="number" and phase==folder:GetAttribute("Phase") then folder:SetAttribute("Ack",phase) end
end)
local root=game.ServerScriptService.CombatChrono
local chrono=require(root.Connector)
local native=require(script.Parent.Baseline)
local connected=require(game.ServerScriptService.HitDetection)
local parity,inputRows,refusals={},{},{}
local models={}
local sourcePlayer,originalFrame,originalAnchored
local requestConnection
local passes=0
local function check(name,ok,detail)
	table.insert(refusals,{name=name,passed=ok,detail=detail})
	assert(ok,name..": "..tostring(detail))
end
local function clean(model)
	for _,v in model:GetDescendants() do
		if v:IsA("ForceField") or v:IsA("BodyVelocity") or (v:IsA("Accessory") and table.find({"Blocking","Knocked","Stun","Action","LightAttack"},v.Name)) then v:Destroy() end
	end
	model.Humanoid.Health=model.Humanoid.MaxHealth
end
local function tag(model,name,class)
	local v=Instance.new(class or "Accessory") v.Name=name v.Parent=model return v
end
local function make(name)
	local model=workspace.Characters.Rig:Clone() model.Name="__ChronoQA_"..name
	for _,v in model:GetDescendants() do
		if v:IsA("LuaSourceContainer") then v:Destroy()
		elseif v:IsA("BasePart") then v.Anchored=true v.CanCollide=false v.CanQuery=true end
	end
	for _,asset in game.ServerStorage.Assets.HumanoidRootPart:GetChildren() do
		if not model.HumanoidRootPart:FindFirstChild(asset.Name) then asset:Clone().Parent=model.HumanoidRootPart end
	end
	model.Humanoid.MaxHealth=1000 model.Humanoid.Health=1000
	model.Parent=workspace.Characters table.insert(models,model) return model
end
local function teleport(model,frame) chrono.Teleport(model,frame) end
local function waitFor(predicate,seconds)
	local deadline=os.clock()+seconds
	repeat if predicate() then return true end task.wait(0.01) until os.clock()>deadline
	return predicate()
end
local ok,problem=xpcall(function()
	assert(waitFor(function() local p=Players:GetPlayers()[1] return p and p.Character and p.Character.Parent==workspace.Characters and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("CharacterHandler") end,15),"test player not ready")
	local player=Players:GetPlayers()[1]
	sourcePlayer=player.Character
	originalFrame=sourcePlayer.HumanoidRootPart.CFrame originalAnchored=sourcePlayer.HumanoidRootPart.Anchored
	sourcePlayer.HumanoidRootPart.Anchored=true
	teleport(sourcePlayer,CFrame.new(0,3,0))
	clean(sourcePlayer)
	local floor=Instance.new("Part") floor.Name="__ChronoQAFloor" floor.Anchored=true floor.Size=Vector3.new(1200,1,600) floor.Position=Vector3.new(400,-0.5,0) floor.Parent=workspace
	local source,target,extra=make("Source"),make("Target"),make("Extra")
	local requests=0 local observedSource
	requestConnection=game.ServerStorage.Requests.DamageHumanoid.Event:Connect(function(actor) if actor==observedSource then requests+=1 end end)
	local cases={
		{name="front hit",offset=Vector3.new(0,0,-4),expected=7},
		{name="distant miss",offset=Vector3.new(25,0,-4),expected=0},
		{name="behind miss",offset=Vector3.new(0,0,5),expected=0},
		{name="above miss",offset=Vector3.new(0,15,-4),expected=0},
		{name="front block",offset=Vector3.new(0,0,-4),yaw=math.pi,block=true,expected=0},
		{name="rear block removed",offset=Vector3.new(0,0,-4),block=true,expected=7},
		{name="forcefield",offset=Vector3.new(0,0,-4),forcefield=true,expected=0},
		{name="knocked immunity",offset=Vector3.new(0,0,-4),knocked=true,expected=0},
		{name="fourth hit knockback",offset=Vector3.new(0,0,-4),finisher=true,expected=7},
		{name="multiple targets",offset=Vector3.new(-1,0,-4),multi=true,expected=7},
		{name="CanQuery flags",offset=Vector3.new(0,0,-4),noQuery=true},
	}
	local rng=Random.new(241031)
	for i=1,48 do table.insert(cases,{name="seeded geometry "..i,offset=Vector3.new(rng:NextNumber(-9,9),rng:NextNumber(-7,7),rng:NextNumber(-11,5)),yaw=rng:NextNumber(-math.pi,math.pi),roll=rng:NextNumber(-0.6,0.6),sourceYaw=rng:NextNumber(-math.pi,math.pi)}) end
	for _,case in cases do
		local results={}
		for index,module in {native,connected} do
			for _,model in {source,target,extra} do clean(model) end
			for _,p in target:GetDescendants() do if p:IsA("BasePart") then p.CanQuery=true end end
			local frame=CFrame.new(400,3,0)*CFrame.Angles(0,case.sourceYaw or 0,0)
			teleport(source,frame)
			teleport(target,frame*CFrame.new(case.offset)*CFrame.Angles(0,case.yaw or 0,case.roll or 0))
			teleport(extra,frame*CFrame.new(if case.multi then Vector3.new(1,0,-4) else Vector3.new(35,0,0)))
			if case.block then tag(target,"Blocking") end
			if case.forcefield then tag(target,"ForceField","ForceField") end
			if case.knocked then tag(target,"Knocked") end
			if case.noQuery then for _,p in target:GetDescendants() do if p:IsA("BasePart") then p.CanQuery=false end end end
			local attack={damage=7,punch=true,block=true,combo=if case.finisher then 4 else 1}
			if case.finisher then attack.knockback=true attack.ragdoll=true end
			requests=0 observedSource=source
			module.hitboxCheck(source,Vector3.new(8,8,6),attack)
			task.wait(0.04)
			local velocity=target.HumanoidRootPart:FindFirstChildWhichIsA("BodyVelocity")
			results[index]={requests=requests,damage=1000-target.Humanoid.Health,extraDamage=1000-extra.Humanoid.Health,blocked=target:FindFirstChild("Blocking")~=nil,knocked=target:FindFirstChild("Knocked")~=nil,knockback=velocity and math.round(velocity.Velocity.Magnitude) or 0}
		end
		local same=true for key,value in results[1] do if results[2][key]~=value then same=false end end
		if case.expected~=nil and results[1].damage~=case.expected then same=false end
		table.insert(parity,{name=case.name,passed=same,original=results[1],connected=results[2]})
		folder:SetAttribute("Parity",#parity)
	end
	for _,row in parity do assert(row.passed,"parity mismatch: "..row.name) end
	clean(source) clean(target) clean(extra)
	local frame=CFrame.new(400,3,0)
	teleport(source,frame) teleport(target,frame*CFrame.new(0,0,-4)) teleport(extra,frame*CFrame.new(40,0,0))
	local token,why=chrono.Begin(source,"Contact") check("real move starts",token~=nil,why)
	local allowed=chrono.Allows(token,target) check("covered target allowed",allowed)
	check("target cannot be allowed twice",not chrono.Allows(token,target))
	chrono.Finish(token)
	check("finished move refuses",chrono.Query(token)==nil)
	token=assert(chrono.Begin(source,"Contact")) chrono.Cancel(token)
	check("cancelled move refuses",chrono.Query(token)==nil)
	token=assert(chrono.Begin(source,"Contact")) task.wait(0.16)
	check("expired move refuses",chrono.Query(token)==nil)
	token=assert(chrono.Begin(source,"Contact")) assert(chrono.Query(token)) teleport(target,target.HumanoidRootPart.CFrame)
	check("cached contact refuses after target reset",not chrono.Allows(token,target))
	check("unknown move refuses",chrono.Begin(source,"UnknownAction")==nil)
	-- Both a real damage path and a false source-position claim are exercised.
	clean(target)
	local approved=source.HumanoidRootPart.CFrame
	teleport(target,approved*CFrame.new(200,0,-4))
	source:PivotTo(approved*CFrame.new(200,0,0))
	observedSource=source requests=0
	connected.hitboxCheck(source,Vector3.new(8,8,6),{damage=7,punch=true,block=true,combo=1})
	task.wait(0.04)
	check("invalid movement produces no damage",target.Humanoid.Health==1000 and requests==0,requests)
	teleport(source,approved)
	for _,model in {source,target,extra} do model:Destroy() end
	models={}
	-- Fresh real-client remote tests; the original CharacterHandler is unchanged.
	target=make("InputTarget")
	local inputCases={
		{name="single punch",damage=7,requests=1},
		{name="miss",damage=0,requests=0,miss=true},
		{name="target blocks",damage=0,requests=1,blocking=true},
		{name="forcefield",damage=0,requests=1,forcefield=true},
		{name="cancelled by stun",damage=0,requests=0,cancel=true},
		{name="click during cooldown",damage=7,requests=1},
		{name="player holds block",damage=0,requests=0},
		{name="four hit combo",damage=28,requests=4},
	}
	for index,case in inputCases do
		clean(sourcePlayer) clean(target)
		sourcePlayer.Combo.Value=0 sourcePlayer.ComboTimer.Value=tick()
		teleport(sourcePlayer,CFrame.new(0,3,0))
		local targetFrame=sourcePlayer.HumanoidRootPart.CFrame*CFrame.new(if case.miss then Vector3.new(25,0,-4) else Vector3.new(0,0,-4))
		if case.blocking then targetFrame*=CFrame.Angles(0,math.pi,0) end
		teleport(target,targetFrame)
		if case.blocking then tag(target,"Blocking") end
		if case.forcefield then tag(target,"ForceField","ForceField") end
		task.wait(0.25)
		observedSource=sourcePlayer requests=0
		local before=chrono.Inspect().stats
		folder:SetAttribute("Case",case.name) folder:SetAttribute("Phase",index)
		if case.cancel then
			assert(waitFor(function() return sourcePlayer:FindFirstChild("LightAttack")~=nil end,3),"cancel input did not arrive")
			tag(sourcePlayer,"Stun") 
		end
		assert(waitFor(function() return folder:GetAttribute("Ack")==index end,6),"client acknowledgement missing")
		task.wait(if case.name=="four hit combo" then 1.1 else 1.35)
		local after=chrono.Inspect().stats
		local row={name=case.name,damage=1000-target.Humanoid.Health,requests=requests,expectedDamage=case.damage,expectedRequests=case.requests,chronoMoves=after.begun-before.begun,chronoQueries=after.queries-before.queries}
		row.passed=row.damage==case.damage and row.requests==case.requests
		if case.cancel then row.noMoveCreated=after.begun==before.begun row.passed=row.passed and row.noMoveCreated end
		if case.name=="four hit combo" then row.comboReset=sourcePlayer.Combo.Value==0 row.passed=row.passed and row.comboReset end
		table.insert(inputRows,row)
	end
	for _,row in inputRows do assert(row.passed,"client input mismatch: "..row.name) end
	floor:Destroy()
end,debug.traceback)
folder:SetAttribute("Phase",0)
if requestConnection then requestConnection:Disconnect() end
for _,model in models do if model.Parent then model:Destroy() end end
local floor=workspace:FindFirstChild("__ChronoQAFloor") if floor then floor:Destroy() end
if sourcePlayer and sourcePlayer.Parent then
	clean(sourcePlayer)
	if originalFrame then chrono.Teleport(sourcePlayer,originalFrame) end
	sourcePlayer.HumanoidRootPart.Anchored=originalAnchored or false
end
folder.Result.Value=H:JSONEncode({passed=ok,error=if ok then nil else tostring(problem),parity=parity,input=inputRows,refusals=refusals,report=chrono.Inspect(),scope="One real client, original game remotes, disposable server fixtures; no new latency claim"})
ackConnection:Disconnect()
folder:SetAttribute("Done",true)

