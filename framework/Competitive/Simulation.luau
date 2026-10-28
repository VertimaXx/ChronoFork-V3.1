-- Cooperates with Roblox's replayable simulation; effects run only on confirmed work.
local S={}
local run=game:GetService("RunService")
local isServer=run:IsServer()
function S.Bind(step,options)
	assert(type(step)=="function")
	local RunService=game:GetService("RunService")
	local o=options or {}
	-- AuthorityMode is RobloxScript-only. Ordinary scripts cannot inspect it.
	-- Installation records the developer's explicit choice; the engine enforces
	-- fixed-simulation availability when BindToSimulation is called.
	assert(o.engineAuthority==true,"Confirm Workspace server authority in Studio and pass engineAuthority=true")
	return RunService:BindToSimulation(function(dt)
		step(dt,time(),RunService:IsResimulating())
	end,o.frequency or Enum.StepFrequency.Hz60,o.priority or 2000)
end
-- Commit keys should include lifetime + approved action sequence + target lifetime.
function S.ConfirmOnce(store,key,expires,callback)
	assert(isServer,"Only the server commits gameplay outcomes")
	if run:IsResimulating() then return false,"resimulation" end
	return store:Apply(key,expires,time(),callback)
end
-- Call from simulation; run non-simulation side effects after it has finished.
-- Only the server queues a commit. Normal Luau tables are NOT rollback state.
function S.DeferOutcome(store,key,expires,callback,onComplete)
	if not isServer then return false,"server_only" end
	if run:IsResimulating() then return false,"resimulation" end
	task.defer(function()
		local ok,reason=store:Apply(key,expires,time(),callback)
		if onComplete then onComplete(ok,reason) end
	end)
	return true,"queued"
end
return table.freeze(S)
