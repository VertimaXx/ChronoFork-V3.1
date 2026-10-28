-- Explicit SERVER capture bridge. Receipt is never upgraded to trusted motion.
-- Sparse transport/display samples are not reused as historical game records.
local Contract=require(script.Parent.Parent.Core.Contract)
local Guard=require(script.Parent.Parent.Core.Guard)
local S={}
function S.Attach(chrono,world,entity,options)
	assert(game:GetService("RunService"):IsServer(),"Record game positions on the server")
	local o=options or {} local id=o.id or ("entity-"..entity.id.."-"..entity.generation)
	local grade=o.grade or "observed"
	assert(type(o.capture)=="function","Supply a capture hook for this game's positions, zones and state")
	local frequency=o.frequency or 60
	assert(Guard.Number(frequency) and frequency>=1 and frequency<=120)
	world:Track(id,{kind=o.kind or "actor",grade=grade,maxSpeed=o.maxSpeed or 4096,maxRadius=o.maxRadius or 16})
	local alive=true local revision=entity.ownershipRevision or 0
	local lastCapture=-math.huge local clock=o.clock or function() return workspace:GetServerTimeNow() end
	local handle={id=id,lastReason="waiting",accepted=0,rejected=0}
	local connection,destroyed
	local function record()
		if not alive then return false,"closed" end
		local called,now=Contract.Call(clock)
		if not called or not Guard.Number(now) then handle.lastReason="clock_fault" return false,handle.lastReason end
		if now<lastCapture then handle.lastReason="clock_reversed" handle.rejected+=1 return false,handle.lastReason end
		if now-lastCapture<1/frequency-1e-6 then return false,"not_due" end
		lastCapture=now
		if (entity.ownershipRevision or 0)~=revision then
			revision=entity.ownershipRevision or 0 world:Discontinuity(id,now,"stream_changed")
		end
		if grade=="serverSimulated" and o.independent~=true then
			local part=chrono.Entity.GetPrimaryPart(entity)
			if entity.networkOwner or (part and not part.Anchored and part:GetNetworkOwner()~=nil) then
				handle.lastReason="source_became_client_owned" handle.rejected+=1 return false,handle.lastReason
			end
		end
		local ok,snapshot=Contract.Call(o.capture,entity,now)
		if not ok or type(snapshot)~="table" then
			handle.lastReason="capture_fault" handle.rejected+=1 return false,handle.lastReason
		end
		local copy=table.clone(snapshot) copy.time=now copy.receivedAt=now copy.sourceId=revision
		local accepted,reason=world:Record(id,copy)
		handle.lastReason=reason or "recorded"
		if accepted then handle.accepted+=1 else handle.rejected+=1 end
		return accepted,reason
	end
	local function close()
		if not alive then return end
		alive=false if connection then connection:Disconnect() end if destroyed then destroyed:Disconnect() end
		world:Untrack(id)
	end
	handle.Capture=record handle.Disconnect=close
	destroyed=chrono.Entity.GetEvent(entity,"Destroying"):Connect(close)
	if o.manual~=true then connection=game:GetService("RunService").PostSimulation:Connect(record) end
	record()
	return handle
end
return table.freeze(S)
