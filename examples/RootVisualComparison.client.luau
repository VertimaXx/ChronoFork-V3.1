-- Studio diagnostic: 3.3 visual sampling of server-observed frames, not hit validation.
local Visual=require(script:WaitForChild("VisualSampling"))
local Motion=require(script:WaitForChild("MotionPredictor"))
local predictor=Motion.New()
local forecastPacket,forecastCharacter
local echoedSequence=-1
local viewMode="Adaptive"
local visualStatus="waiting"
local visualFrame
local samples={cache={},head=1,count=0,lockedTime=0}
function samples:GetLatest() return self.cache[self.count] end
local sampleCharacter
local function record(message)
 if sampleCharacter~=message.character then table.clear(samples.cache) samples.count=0 sampleCharacter=message.character end
 local last=samples:GetLatest()
 local dt=if last then message.capturedAt-last.t else 0
 if last and (dt<=0 or dt>0.5 or (message.native.Position-last.value.Position).Magnitude>math.max(20,(last.velocity.Magnitude*dt*4+4))) then
  table.clear(samples.cache) samples.count=0 last=nil
 end
 local velocity=if last then (message.native.Position-last.value.Position)/dt else Vector3.zero
 table.insert(samples.cache,{t=message.capturedAt,value=message.native,velocity=velocity})
 if #samples.cache>60 then table.remove(samples.cache,1) end
 samples.count=#samples.cache
end
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("ChronoRootComparisonRemotes")

-- The estimator never reads the local root to correct its forecast. The local
-- root is used only to SEND source samples and to MEASURE the displayed error.
local sourceSequence,nextSource=0,0
RunService.Heartbeat:Connect(function()
 local now=workspace:GetServerTimeNow()
 if now<nextSource then return end nextSource=now+1/30
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if root then
  sourceSequence+=1
  remotes.MotionSamples:FireServer(character,sourceSequence,now,root.CFrame,root.AssemblyLinearVelocity)
 end
end)
remotes:WaitForChild("Prediction").OnClientEvent:Connect(function(character,sequence,t,frame,velocity,computedAt,estimate,model,status,uncertainty,count,nativeMean,adaptiveMean,oldMean)
 if character~=player.Character then return end
 if forecastPacket and forecastPacket.character==character and computedAt<=forecastPacket.computedAt then return end
 if forecastCharacter~=character then predictor:Reset() echoedSequence=-1 forecastCharacter=character end
 if sequence>echoedSequence then
  predictor:Observe(t,frame,velocity) echoedSequence=sequence
 end
 forecastPacket={character=character,sourceTime=t,computedAt=computedAt,estimate=estimate,model=model,status=status,
  uncertainty=uncertainty,count=count,nativeMean=nativeMean,adaptiveMean=adaptiveMean,oldMean=oldMean,received=os.clock()}
end)

local folder = Instance.new("Folder")
folder.Name = "RootComparisonMarkers"
folder.Parent = workspace
local red = Color3.fromRGB(255, 104, 112)
local green = Color3.fromRGB(67, 235, 161)
local white = Color3.fromRGB(235, 241, 249)
local function marker(name, color, height)
	local part = Instance.new("Part")
	part.Name, part.Anchored = name, true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow, part.Transparency = false, 1
	part.Color, part.Material = color, Enum.Material.Neon
	part.Parent = folder
	local border = Instance.new("SelectionBox")
	border.Name, border.Adornee, border.Color3 = "Outline", part, color
	border.LineThickness, border.SurfaceTransparency = 0.035, 1
	border.Visible, border.Parent = false, part
	local fill = Instance.new("BoxHandleAdornment")
	fill.Name, fill.Adornee, fill.Color3 = "VisibleThroughCharacter", part, color
	fill.AlwaysOnTop, fill.ZIndex, fill.Transparency = true, 5, 0.78
	fill.Visible, fill.Parent = false, part
	local tag = Instance.new("BillboardGui")
	tag.Name, tag.Adornee = "Label", part
	tag.Size, tag.StudsOffsetWorldSpace = UDim2.fromOffset(250, 22), Vector3.new(0, height, 0)
	tag.AlwaysOnTop, tag.Enabled, tag.ResetOnSpawn = true, false, false
	tag.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Font, label.TextSize, label.TextColor3 = Enum.Font.GothamBold, 13, color
	label.TextStrokeTransparency, label.Text = 0.35, name
	label.Parent = tag
	return {part = part, border = border, fill = fill, tag = tag, label = label}
end
local nativeMarker = marker("ROBLOX / SERVER", red, 2.7)
local chronoMarker = marker("CHRONO 3.3 / SMOOTH", green, 3.5)
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "ChronoRootComparisonHUD", false, 80
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Name, panel.Size = "Panel", UDim2.fromOffset(430, 478)
panel.Position, panel.BackgroundColor3 = UDim2.fromOffset(18, 58), Color3.fromRGB(15, 23, 33)
panel.BackgroundTransparency, panel.BorderSizePixel = 0.05, 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local function text(name, value, y, height, color, size)
	local label = Instance.new("TextLabel")
	label.Name, label.Text = name, value
	label.Position, label.Size = UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, height)
	label.BackgroundTransparency, label.TextColor3 = 1, color or white
	label.Font, label.TextSize = Enum.Font.Gotham, size or 13
	label.TextWrapped, label.TextXAlignment, label.TextYAlignment = true, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
	label.Parent = panel
	return label
end
text("Title", "ROOT POSITION / CHRONO 3.3", 15, 24, white, 17)
text("Subtitle", "Server forecast + separate return-trip display estimate", 42, 20, Color3.fromRGB(146, 167, 188), 12)
text("NativeLegend", "RED   Roblox position observed on the server", 72, 20, red)
text("ChronoLegend", "GREEN   Selected estimate; never damage evidence", 96, 20, green)
local buttons = {}
local requestedMode = "Present"
local lastPacket, lastSequence, receivedAt = nil, -1, 0
local shown, separated = true, false
local function button(name, label, x, y, width, callback)
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Position = name, label, UDim2.fromOffset(x, y)
	b.Size, b.BackgroundColor3 = UDim2.fromOffset(width, 31), Color3.fromRGB(36, 49, 63)
	b.TextColor3, b.TextSize, b.Font = white, 12, Enum.Font.GothamMedium
	b.AutoButtonColor, b.BorderSizePixel, b.Parent = true, 0, panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.Activated:Connect(callback)
	return b
end
local function choose(mode)
	requestedMode = mode
	viewMode=if mode=="Present" then "Smooth" else "Historical"
	remotes.Mode:FireServer(mode)
end
buttons.Present = button("Present", "3.3 smooth", 16, 126, 100, function() choose("Present") end)
buttons.EarlierPing = button("EarlierPing", "Earlier: ping / 2", 122, 126, 124, function() choose("EarlierPing") end)
buttons.Earlier150 = button("Earlier150", "Earlier: 150 ms", 252, 126, 122, function() choose("Earlier150") end)
button("Prediction","Old estimate: 100 ms",16,170,184,function() choose("Present") viewMode="Predict" end)
button("Raw","Raw recorded frame",206,170,168,function() choose("Present") viewMode="Raw" end)
button("Adaptive","Adaptive estimate",16,211,184,function() choose("Present") viewMode="Adaptive" end)
button("ServerEstimate","Server's sent estimate",206,211,208,function() choose("Present") viewMode="ServerEstimate" end)
local explanation = text("Explanation", "Present: both use the same recorded server position. Overlap is expected.", 252, 44, Color3.fromRGB(181, 201, 219), 12)
local metrics = text("Metrics", "Waiting for server samples...", 303, 88, white, 12)
local status = text("Status", "Both markers have the same network return delay.", 395, 28, Color3.fromRGB(146, 167, 188), 11)
local separateButton
separateButton = button("Separate", "Separate for visibility", 16, 438, 184, function()
	separated = not separated
	separateButton.Text = if separated then "Use exact overlapping centers" else "Separate for visibility"
end)
local visibleButton
visibleButton = button("Visibility", "Hide markers [F6]", 206, 438, 168, function()
	shown = not shown
	visibleButton.Text = if shown then "Hide markers [F6]" else "Show markers [F6]"
end)
local function setVisible(m, value)
	m.part.Transparency = 1
	m.fill.Visible = value
	m.border.Visible, m.tag.Enabled = value, value
end
remotes.Positions.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or type(message.sequence) ~= "number" or message.sequence <= lastSequence then return end
	if message.character ~= player.Character then return end
	record(message)
	lastPacket, lastSequence, receivedAt = message, message.sequence, os.clock()
	for key, b in buttons do b.BackgroundColor3 = if key == message.mode then Color3.fromRGB(29, 103, 79) else Color3.fromRGB(36, 49, 63) end
	gui:SetAttribute("PacketsReceived", (gui:GetAttribute("PacketsReceived") or 0) + 1)
	gui:SetAttribute("LastSequence", message.sequence)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.F6 then
		shown = not shown
		visibleButton.Text = if shown then "Hide markers [F6]" else "Show markers [F6]"
	end
end)
RunService.RenderStepped:Connect(function()
	local message = lastPacket
	local character = player.Character
	local current = character and character:FindFirstChild("HumanoidRootPart")
	local fresh = message and message.character == character and os.clock() - receivedAt < 0.75 and current ~= nil
	setVisible(nativeMarker, shown and fresh == true)
	setVisible(chronoMarker, shown and fresh == true and (viewMode~="Historical" or message.chrono~=nil))
	if not fresh then
		metrics.Text = "Waiting for fresh server samples..."
		gui:SetAttribute("Fresh", false)
		return
	end
	gui:SetAttribute("Fresh", true)
	local nOffset = if separated then Vector3.new(-1.5, 0, 0) else Vector3.zero
	local cOffset = if separated then Vector3.new(1.5, 0, 0) else Vector3.zero
	nativeMarker.part.Size = message.size + Vector3.new(0.08, 0.08, 0.08)
	chronoMarker.part.Size = message.size
	nativeMarker.fill.Size = nativeMarker.part.Size
	chronoMarker.fill.Size = chronoMarker.part.Size
	nativeMarker.part.CFrame = message.native + nOffset
	visualFrame=message.chrono
 if viewMode=="Adaptive" or viewMode=="ServerEstimate" then
  local f=forecastPacket
  if f and f.character==character and os.clock()-f.received<0.75 then
   if viewMode=="ServerEstimate" then visualFrame=f.estimate visualStatus=f.status.." / "..f.model
   else local info visualFrame,info=predictor:Predict(workspace:GetServerTimeNow()) visualStatus=info.status.." / "..(info.model or "waiting") end
  else visualFrame=nil visualStatus="waiting for server forecast" end
 elseif viewMode=="Smooth" or viewMode=="Predict" then
  local latest=samples:GetLatest()
  local target=if viewMode=="Predict" then latest.t+math.min(0.1,math.max(0,workspace:GetServerTimeNow()-latest.t)) else latest.t+(os.clock()-receivedAt)-0.06
  local info
  visualFrame,info=Visual.Sample(samples,target,"SEGMENT",if viewMode=="Predict" then 0.100001 else 0,3,100)
  visualStatus=info.status
 else visualStatus=if viewMode=="Raw" then "raw recorded" else "historical query" end
 if visualFrame then chronoMarker.part.CFrame=visualFrame+cOffset else setVisible(chronoMarker,false) end
 panel.Prediction.BackgroundColor3=if viewMode=="Predict" then Color3.fromRGB(29,103,79) else Color3.fromRGB(36,49,63)
 panel.Raw.BackgroundColor3=if viewMode=="Raw" then Color3.fromRGB(29,103,79) else Color3.fromRGB(36,49,63)
 buttons.Present.BackgroundColor3=if viewMode=="Smooth" then Color3.fromRGB(29,103,79) else Color3.fromRGB(36,49,63)
	panel.Adaptive.BackgroundColor3=if viewMode=="Adaptive" then Color3.fromRGB(29,103,79) else Color3.fromRGB(36,49,63)
 panel.ServerEstimate.BackgroundColor3=if viewMode=="ServerEstimate" then Color3.fromRGB(29,103,79) else Color3.fromRGB(36,49,63)
 local label = if message.mode == "Present" then "PRESENT" elseif message.mode == "EarlierPing" then "EARLIER / PING" else "EARLIER / 150 MS"
	chronoMarker.label.Text = "CHRONO 3.3 / "..(if viewMode=="Historical" then label elseif viewMode=="Predict" then "OLD ESTIMATE" elseif viewMode=="ServerEstimate" then "SERVER ESTIMATE" elseif viewMode=="Adaptive" then "ADAPTIVE DISPLAY" else viewMode:upper())
	local delay = (message.rewind or 0) * 1000
	local gap = if visualFrame then (message.native.Position - visualFrame.Position).Magnitude else nil
	local localGap = (current.Position - message.native.Position).Magnitude
	local age = math.max(0, workspace:GetServerTimeNow() - message.capturedAt) * 1000
	explanation.Text=if viewMode=="Adaptive" then "Forecast from server-returned source data only, up to 250 ms / 8 studs. New inputs are still unknown."
 elseif viewMode=="ServerEstimate" then "The estimate actually computed on the SERVER. Its trip back to your screen adds delay."
 elseif viewMode=="Smooth" then "3.3 Segment smoothing: 60 ms drawing buffer. Green stays on recorded segments."
 elseif viewMode=="Predict" then "Visual guess only: at most 100 ms / 3 studs. It cannot remove transport delay or prove a hit."
 elseif viewMode=="Raw" then "Raw Chrono query frame. This reproduces the previous comparison."
 else "Historical position check. This is an earlier record, not a forward prediction."
	metrics.Text = string.format("Ping: %.0f ms  |  Lookback: %.0f ms  |  Packet age: %.0f ms\nRed to green: %s studs  |  Red to your root: %.2f studs\nChrono coverage: %s", message.ping * 1000, delay, age,
		if gap then string.format("%.3f", gap) else "unavailable", localGap, message.reason)

 local greenError=if visualFrame then (current.Position-visualFrame.Position).Magnitude else -1
 gui:SetAttribute("DisplayedRootError",greenError)
 if forecastPacket and forecastPacket.character==character then
  local f=forecastPacket
  local sourceAge=math.max(0,workspace:GetServerTimeNow()-f.sourceTime)*1000
  metrics.Text=string.format("Source age: %.0f ms | Red to root: %.2f studs\nGreen to root NOW: %.2f studs | Server forecast age: %.0f ms\nPast server mean error (%d checks, client-report reference):\nNative %.2f | Old 100 ms %.2f | Adaptive %.2f studs",
   sourceAge,localGap,greenError,math.max(0,workspace:GetServerTimeNow()-f.computedAt)*1000,f.count,f.nativeMean,f.oldMean,f.adaptiveMean)
  gui:SetAttribute("PredictionSourceAgeMs",sourceAge)
  gui:SetAttribute("ServerNativeMean",f.nativeMean) gui:SetAttribute("ServerAdaptiveMean",f.adaptiveMean)
  gui:SetAttribute("ServerOldMean",f.oldMean) gui:SetAttribute("ServerChecks",f.count)
 end
 status.Text = if separated then "DISPLAY OFFSET: red -1.5 X, green +1.5 X. Distances stay real."
		else "3.3: "..visualStatus..". Red is raw; green is a display estimate."
	if requestedMode ~= message.mode then status.Text = "Waiting for the server to confirm your selected mode..." end
	gui:SetAttribute("Mode", viewMode)
	gui:SetAttribute("VisualVersion","3.3.0-dev")
	gui:SetAttribute("VisualStatus",visualStatus)
	gui:SetAttribute("Coverage", message.reason)
	gui:SetAttribute("NativeChronoDistance", gap or -1)
	gui:SetAttribute("NativeLocalDistance", localGap)
	gui:SetAttribute("RewindMs", delay)
	gui:SetAttribute("PacketAgeMs", age)
end)
choose("Present")
viewMode="Adaptive"
