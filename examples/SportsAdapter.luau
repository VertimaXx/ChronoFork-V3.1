-- Example dependency boundary for YOUR existing server services, not a replacement framework.
-- ActorService snapshots must already be server-simulated or server-validated.
return function(Integration,ActorService,MoveService,BallService)
	local kit=Integration()
	local chrono,actions,bindings=kit.Chrono,kit.Actions,kit.Bindings
	local liveActions={}
	local connections={}
	local function register(id)
		bindings.Track(id,function(time)
			-- Must atomically return the root, gameplay zones and scalar eligibility state at time.
			return ActorService:CaptureHitboxes(id,time)
		end,"serverValidated","player")
	end
	for _,id in ActorService:GetIds() do register(id) end
	bindings.Track("match-ball",function(time) return BallService:CaptureHitbox(time) end,"serverSimulated","ball")
	table.insert(connections,ActorService.Added:Connect(register))
	table.insert(connections,ActorService.Removed:Connect(function(id) chrono:Untrack(id) end))
	table.insert(connections,ActorService.Discontinuity:Connect(function(id,reason) chrono:Discontinuity(id,reason) end))
	-- Your existing server service already checked stamina, cooldown, possession and request replay.
	table.insert(connections,MoveService.Authorized:Connect(function(actorId,moveId)
		if liveActions[actorId] then chrono:EndAction(liveActions[actorId]) end
		if moveId=="Tackle" then liveActions[actorId]=chrono:BeginAction(actorId,actions.Contact) end
	end))
	table.insert(connections,MoveService.Cancelled:Connect(function(actorId)
		if liveActions[actorId] then chrono:EndAction(liveActions[actorId]) liveActions[actorId]=nil end
	end))
	-- This event must fire after all participating server actors and the ball completed the same step.
	table.insert(connections,ActorService.AfterSimulation:Connect(function(serverTime)
		chrono:Capture(serverTime)
		for actorId,action in liveActions do
			local result=chrono:Query(action)
			if result.ok then
				for _,contact in result.contacts do
					-- The outcome is game-owned. Its current-state checks may still refuse the contact.
					MoveService:TryApplyTackle(actorId,contact.id,contact.time)
				end
			elseif result.reason=="invalid_action" or result.reason=="source_epoch_changed" or result.reason=="roster_changed" then
				chrono:EndAction(action) liveActions[actorId]=nil
			end
		end
	end))
	return function()
		for _,connection in connections do connection:Disconnect() end
		chrono:Destroy()
	end
end
