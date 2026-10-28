-- Lightweight native developer panel; server statistics remain permission gated.
local D={}
function D.Mount(F,root)
	local players=game:GetService("Players") local input=game:GetService("UserInputService") local run=game:GetService("RunService")
	local gui=Instance.new("ScreenGui") gui.Name="ChronoForkDeveloper" gui.ResetOnSpawn=false gui.Enabled=false gui.DisplayOrder=1000
	local panel=Instance.new("Frame") panel.Size=UDim2.fromOffset(470,540) panel.Position=UDim2.new(1,-490,0,60) panel.BackgroundColor3=Color3.fromRGB(16,23,32) panel.Parent=gui
	Instance.new("UICorner",panel).CornerRadius=UDim.new(0,10)
	local title=Instance.new("TextLabel") title.Size=UDim2.new(1,-28,0,45) title.Position=UDim2.fromOffset(14,0) title.BackgroundTransparency=1 title.Text="ChronoFork · developer view (F4)" title.Font=Enum.Font.GothamMedium title.TextSize=17 title.TextColor3=Color3.fromRGB(87,228,203) title.TextXAlignment=Enum.TextXAlignment.Left title.Parent=panel
	local close=Instance.new("TextButton") close.Size=UDim2.fromOffset(32,30) close.Position=UDim2.new(1,-39,0,7) close.Text="×" close.TextSize=24 close.BackgroundTransparency=1 close.TextColor3=Color3.new(1,1,1) close.Parent=panel
	local scroll=Instance.new("ScrollingFrame") scroll.Position=UDim2.fromOffset(14,48) scroll.Size=UDim2.new(1,-28,1,-64) scroll.BackgroundTransparency=1 scroll.BorderSizePixel=0 scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y scroll.CanvasSize=UDim2.new() scroll.ScrollBarThickness=5 scroll.Parent=panel
	local layout=Instance.new("UIListLayout") layout.Padding=UDim.new(0,9) layout.Parent=scroll
	local function label(text,color)
		local t=Instance.new("TextLabel") t.Size=UDim2.new(1,-8,0,0) t.AutomaticSize=Enum.AutomaticSize.Y t.BackgroundTransparency=1 t.Text=text t.TextWrapped=true t.Font=Enum.Font.Gotham t.TextSize=13 t.TextColor3=color or Color3.fromRGB(216,226,237) t.TextXAlignment=Enum.TextXAlignment.Left t.TextYAlignment=Enum.TextYAlignment.Top t.Parent=scroll return t
	end
	label("Displayed positions can be delayed or estimated. A smooth rectangle is not proof that the server accepted a hit.",Color3.fromRGB(255,207,125))
	local metrics=label("") local experiment=label("",Color3.fromRGB(255,207,125)) local objects=label("")
	label("TEST CONTROLS · developer permission required",Color3.fromRGB(87,228,203))
	label("These change the selected object's replication settings. Use them in a test session. Changes last for this session.")
	local selected=Instance.new("TextBox") selected.Size=UDim2.new(1,-8,0,32) selected.BackgroundColor3=Color3.fromRGB(29,40,53) selected.TextColor3=Color3.new(1,1,1) selected.Text="1" selected.PlaceholderText="Object ID shown above" selected.Font=Enum.Font.Code selected.TextSize=14 selected.ClearTextOnFocus=false selected.Parent=scroll
	local notice=label("")
	local function action(title,callback)
		local button=Instance.new("TextButton") button.Size=UDim2.new(1,-8,0,34) button.BackgroundColor3=Color3.fromRGB(29,40,53) button.TextColor3=Color3.new(1,1,1) button.Text=title button.Font=Enum.Font.Gotham button.TextSize=13 button.Parent=scroll
		button.Activated:Connect(function()
			if not F.Stats.HasPermissionToReplicate(players.LocalPlayer) then notice.Text="This account has no server diagnostic permission." return end
			local id=tonumber(selected.Text) local entity=id and F.Holder.GetEntityFromId(id)
			if not entity then notice.Text="Choose an existing object ID." return end
			callback(entity,id,button) notice.Text="Requested a server diagnostic change."
		end)
		return button
	end
	action("Pause / resume selected object",function(_,id)F.Stats._fireClientStatsEvent("TOGGLE_PAUSE",id)end)
	action("Toggle native transform lock",function(_,id)F.Stats._fireClientStatsEvent("CHANGE_NATIVE",id)end)
	action("Cycle drawing: set position / constraints / off",function(e,id)
		local modes={"CFRAME","ALIGN","NONE"} local current=e._interpolationMode or e.entityConfig.INTERPOLATION_MODE local index=table.find(modes,current) or 1
		F.Stats._fireClientStatsEvent("SET_INTERPOLATION_MODE",id,modes[index%#modes+1])
	end)
	action("Cycle selected object's registered type",function(e,id)
		local names={} for name in F.Config._EntityConfigs do table.insert(names,name) end table.sort(names)
		local index=table.find(names,e.entityConfig.NAME) or 1 F.Stats._fireClientStatsEvent("CHANGE_CONFIG",id,names[index%#names+1])
	end)
	local warningIndex=1
	action("Cycle message detail",function()
		local levels={"MEDIUM","HIGH","LOW","NONE"} warningIndex=warningIndex%#levels+1 F.Stats._updateStat("CONFIG","WARNING_SEVERITY",levels[warningIndex])
	end)
	local flags={CHARACTER_WAIT_DELAY="Wait for complete character appearance",SERVER_VELOCITY_FIX="Use source times for velocity",VELOCITY_CALC_FIX="Limit tiny-time velocity spikes",SNAPSHOT_INTERPOLATION_FIX="Pause / resume smoothing",SET_CFRAME_FIX="Teleport flags",FIX_TELEPORT_JITTER="Teleport display lock"}
	for _,name in {"CHARACTER_WAIT_DELAY","SERVER_VELOCITY_FIX","VELOCITY_CALC_FIX","SNAPSHOT_INTERPOLATION_FIX","SET_CFRAME_FIX","FIX_TELEPORT_JITTER"} do
		action("Toggle: "..flags[name],function()F.Stats._updateStat("FFLAG",name,not F.Config.FLAGS[name])end)
	end
	local remote=root.Replication.Shared.Stats:WaitForChild("Stats",10)
	local function setOpen(open) gui.Enabled=open gui:SetAttribute("Open",open) if remote then remote:FireServer("DEBUGGER_OPENED",open) end end
	close.Activated:Connect(function()setOpen(false)end)
	local keys=input.InputBegan:Connect(function(key,processed)
		if not processed and key.KeyCode==Enum.KeyCode.F4 and (run:IsStudio() or F.Stats.HasPermissionToReplicate(players.LocalPlayer)) then setOpen(not gui.Enabled) end
	end)
	gui.Parent=players.LocalPlayer:WaitForChild("PlayerGui")
	local accumulator=0
	local update=run.Heartbeat:Connect(function(dt)
		accumulator+=dt if accumulator<0.25 or not gui.Enabled then return end accumulator=0
		local client,server=F.Stats.CLIENT,F.Stats.SERVER
		local prediction=F.Experimental.Prediction
		local configured=prediction.Inspect(nil)
		experiment.Text=if not configured.enabled then "VERY EXPERIMENTAL PREDICTION: OFF (default). Setup → Experimental to opt in."
			else string.format("VERY EXPERIMENTAL PREDICTION: ON\nDrawing: %s | Limits: %.0f ms / %.2f studs\nAssumed source delay: %.0f ms (not a measurement). Estimates are not hit evidence. Change settings after stopping Play.",
				if configured.drawing then "ON" else "OFF",configured.limits.maxHorizon*1000,configured.limits.maxDistance,configured.assumedSourceDelay*1000)
		metrics.Text=string.format("CLIENT\nObjects: %s   moved: %s   culled: %s\nDrawing work: %.3f ms   incoming payload: %s bytes/s\nRejected packets: %s\n\nSERVER (requires permission)\nObjects: %s   incoming: %s bytes/s   outgoing: %s bytes/s\nPackets: %s/s   range refresh: %.3f ms\nRejected packets: %s   last reason: %s",
			tostring(client.TOTAL_CLIENT_ENTITIES),tostring(client.ENTITIES_MOVED_THIS_FRAME),tostring(client.TOTAL_ENTITIES_CULLED),client.AVG_INTERPOLATION_TIME_MS or 0,tostring(client.BYTES_RECEIVED_PER_SEC),tostring(client.REJECTED_PACKETS or 0),
			tostring(server.NUMBER_OF_ENTITIES),tostring(server.BYTES_RECEIVED_PER_SEC),tostring(server.BYTES_SENT_PER_SEC),tostring(server.PACKETS_SENT_PER_SEC),server.ENTITY_GRID_UPDATE_TIME_MS or 0,tostring(server.REJECTED_PACKETS or 0),tostring(server.LAST_PACKET_REJECTION or "none"))
		local rows={"OBJECT DETAILS · first 30 by ID"} local ids={} for id in F.Holder.idMap do table.insert(ids,id) end table.sort(ids)
		for i=1,math.min(30,#ids) do
			local e=F.Holder.idMap[ids[i]] local info=e.renderInfo or {} local clock=F.Entity.GetClock(e)
			table.insert(rows,string.format("#%s · lifetime %s · revision %s · %s\nOwner: %s   display: %s\nSaved display samples: %s   render time: %.4f",tostring(e.id),tostring(e.generation),tostring(e.ownershipRevision),F.Entity.GetModelReplicationType(e),if e.networkOwner then e.networkOwner.Name else "server",tostring(info.status or (if e.isContextOwner then "local owner" else "waiting")),tostring(if e.snapshot then e.snapshot.count else 0),if clock then clock:GetTargetRenderTime() else -1))
			if configured.enabled then
				local detail=prediction.Inspect(e) local _,estimate=prediction.EstimateCurrent(e)
				table.insert(rows,string.format("  EXPERIMENT: %s / %s | source clock: %s | accepted samples: %s",
					tostring(estimate.status),tostring(estimate.model or "waiting"),tostring(detail.clockDomain or "none"),tostring(detail.accepted)))
			end
		end
		objects.Text=table.concat(rows,"\n\n")
	end)
	return {Disconnect=function()keys:Disconnect() update:Disconnect() if remote then remote:FireServer("DEBUGGER_OPENED",false) end gui:Destroy()end}
end
return D
