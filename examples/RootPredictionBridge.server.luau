-- Studio-only diagnostic extension of RootVisualComparison. Not damage validation.
local RunService=game:GetService("RunService")
if not RunService:IsStudio() then return end
local Players=game:GetService("Players")
local Motion=require(script:WaitForChild("MotionPredictor"))
local remotes=game.ReplicatedStorage:WaitForChild("ChronoRootComparisonRemotes")
local input=Instance.new("UnreliableRemoteEvent") input.Name="MotionSamples" input.Parent=remotes
local output=Instance.new("UnreliableRemoteEvent") output.Name="Prediction" output.Parent=remotes
local states={}
local markers=Instance.new("Folder") markers.Name="ChronoServerPredictionEstimates" markers.Parent=workspace
local function destroy(player)
	local s=states[player] if s and s.marker then s.marker:Destroy() end states[player]=nil
end
Players.PlayerRemoving:Connect(destroy)
local function create(player,character)
	destroy(player)
	local marker=Instance.new("Part") marker.Name=tostring(player.UserId)
	marker.Anchored=true marker.CanCollide=false marker.CanTouch=false marker.CanQuery=false
	marker.Transparency=1 marker.Size=Vector3.new(2,2,1) marker.Parent=markers
	marker:SetAttribute("Trust","untrusted-source estimate; no damage")
	local s={character=character,model=Motion.New(),sequence=-1,tokens=6,clock=os.clock(),pending={},errors={},marker=marker}
	states[player]=s return s
end
input.OnServerEvent:Connect(function(player,character,sequence,t,frame,velocity)
	if character~=player.Character or not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local s=states[player] if not s or s.character~=character then s=create(player,character) end
	local clock=os.clock() s.tokens=math.min(6,s.tokens+math.max(0,clock-s.clock)*40) s.clock=clock
	if s.tokens<1 then return end s.tokens-=1
	local now=workspace:GetServerTimeNow()
	if not Motion.IsFinite(sequence) or sequence%1~=0 or sequence<=s.sequence or sequence>2147483647 then return end
	if not Motion.IsFinite(t) or t>now+0.03 or now-t>0.75 then return end
	if not Motion.IsFrame(frame) or not Motion.IsVector(velocity) then return end
	local old=s.last
	local ok,why=s.model:Observe(t,frame,velocity)
	if not ok then return end
	s.sequence=sequence
	if why=="reset" then table.clear(s.pending) old=nil end
	-- Grade previous server forecasts only when later source data brackets them.
	-- These client reports are a diagnostic reference, not verified ground truth.
	if old and t-old.t<=0.12 then
		local remain={}
		for _,q in s.pending do
			if q.t>t then table.insert(remain,q)
			elseif q.t>=old.t then
				local truth=old.frame.Position:Lerp(frame.Position,(q.t-old.t)/(t-old.t))
				table.insert(s.errors,{adaptive=(q.estimate-truth).Magnitude,native=(q.native-truth).Magnitude,old=(q.old-truth).Magnitude})
				if #s.errors>300 then table.remove(s.errors,1) end
			end
		end
		s.pending=remain
	else table.clear(s.pending) end
	s.last={t=t,frame=frame,velocity=velocity,sequence=sequence}
end)
local nextSend=0
RunService.Heartbeat:Connect(function()
	local now=workspace:GetServerTimeNow() if now<nextSend then return end nextSend=now+1/30
	for player,s in states do
		local part=s.character and s.character:FindFirstChild("HumanoidRootPart")
		if s.character~=player.Character or not part then destroy(player) continue end
		local last=s.last if not last or now-last.t>0.75 then s.marker:SetAttribute("Fresh",false) continue end
		local frame,info=s.model:Predict(now) if not frame then continue end
		s.marker.CFrame=frame s.marker.Size=part.Size
		s.marker:SetAttribute("Fresh",true) s.marker:SetAttribute("SourceTime",last.t)
		s.marker:SetAttribute("PredictedTime",info.predictedTime) s.marker:SetAttribute("ComputedAt",now)
		s.marker:SetAttribute("Model",info.model) s.marker:SetAttribute("Status",info.status)
		local oldTravel=last.velocity*math.min(0.1,math.max(0,now-last.t))
		if oldTravel.Magnitude>3 then oldTravel=Vector3.zero end
		table.insert(s.pending,{t=now,estimate=frame.Position,native=part.Position,old=last.frame.Position+oldTravel})
		if #s.pending>60 then table.remove(s.pending,1) end
		local n,a,b=0,0,0
		for _,e in s.errors do n+=e.native a+=e.adaptive b+=e.old end
		-- Positional args keep each unreliable message well below the 1,000-byte limit.
		output:FireClient(player,s.character,last.sequence,last.t,last.frame,last.velocity,
			now,frame,info.model,info.status,info.uncertainty,#s.errors,
			if #s.errors>0 then n/#s.errors else -1,
			if #s.errors>0 then a/#s.errors else -1,
			if #s.errors>0 then b/#s.errors else -1)
	end
end)
script:SetAttribute("Scope","server prediction diagnostic; does not change combat")
