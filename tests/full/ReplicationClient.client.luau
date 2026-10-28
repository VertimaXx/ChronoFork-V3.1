local root=game:GetService("ReplicatedStorage"):WaitForChild("ChronoForkSmoke")
local F=require(root) F.Start(root:WaitForChild("Settings",30))
if F.Experimental then require(root.DebugUI).Mount(F,root) end
local reports={}
local shared=if root:FindFirstChild("Replication") then root.Replication.Shared else root.Shared
local payloadBytes,packetCount,startedAt=0,0,os.clock()
local function count(_,data) if typeof(data)=="buffer" then payloadBytes+=buffer.len(data) packetCount+=1 end end
shared.Remotes.Replicate.OnClientEvent:Connect(count) shared.Remotes.SafeReplicate.OnClientEvent:Connect(count)
local function fail(message) script:SetAttribute("Error",message) end
local function inspect()
	for _,name in {"Native","Locked","Custom","Data","Mounted","Owned"} do
		local id=root:GetAttribute(name.."Id")
		local e=id and F.Holder.GetEntityFromId(id)
		if e then
			local r=reports[name] or {samples=0,modes={}}
			r.samples+=1 r.generation=e.generation r.revision=e.ownershipRevision r.owner=if e.networkOwner then e.networkOwner.UserId else 0
			r.modes[F.Entity.GetModelReplicationType(e)]=true
			r.position=if e.latestCFrame then {e.latestCFrame.X,e.latestCFrame.Y,e.latestCFrame.Z} else nil
			r.render=if e.renderInfo then e.renderInfo.status else "local"
			if e.renderInfo and e.renderInfo.experimental then
				r.experimentalSamples=(r.experimentalSamples or 0)+1
				if e.renderInfo.trust=="estimate" then r.predictedSamples=(r.predictedSamples or 0)+1 end
			end
			r.model=e.model~=nil r.data=e._data r.mounted=e.mountParentId~=nil
			reports[name]=r
			if name=="Owned" and e.isContextOwner and e.model then
				local part=F.Entity.GetPrimaryPart(e) if part then part.CFrame=CFrame.new(12+math.sin(os.clock()*3)*3,18,0) end
			end
		end
	end
	script:SetAttribute("Reports",game.HttpService:JSONEncode(reports))
	script:SetAttribute("Started",if F.IsStarted then F.IsStarted() else true)
end
game:GetService("RunService").Heartbeat:Connect(function()
	if script:GetAttribute("Complete") then return end
	local ok,why=pcall(inspect) if not ok then fail(tostring(why)) end
	if root:GetAttribute("Complete") then script:SetAttribute("Complete",true) script:SetAttribute("Metrics",game.HttpService:JSONEncode({seconds=os.clock()-startedAt,statePayloadBytes=payloadBytes,statePackets=packetCount,scope="received state buffers; excludes reliable lifecycle, Roblox physics and headers"})) end
end)
script:SetAttribute("Ready",true)
