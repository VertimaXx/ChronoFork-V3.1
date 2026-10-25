-- Optional Studio-only guide. No gameplay keys, remotes or live-game debug access.
if not game:GetService("RunService"):IsStudio() then return end
local reports=game.ReplicatedStorage:WaitForChild("_ChronoConnectionReports",15)
if not reports then return end
local report=reports:WaitForChild(script:GetAttribute("ConnectionName"),15)
if not report then return end
local gui=Instance.new("ScreenGui") gui.Name="ChronoConnectionGuide" gui.ResetOnSpawn=false
gui.Parent=game.Players.LocalPlayer:WaitForChild("PlayerGui")
local toggle=Instance.new("TextButton") toggle.Name="Toggle" toggle.AnchorPoint=Vector2.new(1,0)
toggle.Position=UDim2.new(1,-18,0,20) toggle.Size=UDim2.fromOffset(260,36)
toggle.BackgroundColor3=Color3.fromRGB(27,54,61) toggle.TextColor3=Color3.fromRGB(207,255,234)
toggle.Font=Enum.Font.GothamMedium toggle.TextSize=14 toggle.Text="Chrono connections | Studio" toggle.Parent=gui
local panel=Instance.new("ScrollingFrame") panel.Name="Report" panel.AnchorPoint=Vector2.new(1,0)
panel.Position=UDim2.new(1,-18,0,62) panel.Size=UDim2.new(1,-36,0.7,0)
panel.BackgroundColor3=Color3.fromRGB(17,23,32) panel.ScrollBarThickness=4 panel.BorderSizePixel=0
panel.AutomaticCanvasSize=Enum.AutomaticSize.Y panel.CanvasSize=UDim2.new() panel.Visible=false panel.Parent=gui
local bounds=Instance.new("UISizeConstraint") bounds.MaxSize=Vector2.new(360,420) bounds.Parent=panel
local body=Instance.new("TextLabel") body.Name="Details" body.Size=UDim2.new(1,-8,0,0) body.AutomaticSize=Enum.AutomaticSize.Y
body.BackgroundTransparency=1 body.TextColor3=Color3.fromRGB(237,242,249) body.Font=Enum.Font.Gotham body.TextSize=14
body.TextWrapped=true body.TextXAlignment=Enum.TextXAlignment.Left body.TextYAlignment=Enum.TextYAlignment.Top body.Parent=panel
local padding=Instance.new("UIPadding") padding.PaddingLeft=UDim.new(0,14) padding.PaddingRight=UDim.new(0,14)
padding.PaddingTop=UDim.new(0,14) padding.PaddingBottom=UDim.new(0,14) padding.Parent=panel
local meanings={ready_for_moves="Positions are available. Waiting for an accepted attack.",
 client_owned_position_needs_checker="These parts are moved by a player. Choose a position checker in the plugin.",
 movement_speed="Movement exceeded the configured distance budget.",movement_wall="The root crossed solid geometry.",
 position_provider_required="Choose your existing position-checking module.",
 contact_check_completed="A contact check finished. An empty result is a miss.",
 move_started="An accepted move was recorded. Waiting for its hit period."}
local function update()
	local ok,r=pcall(game.HttpService.JSONDecode,game.HttpService,report.Value) if not ok then return end
	local s=r.stats
 body.Text=string.format("%s\n\nObjects connected: %d\nPosition updates: %d\nMoves started: %d\nContact checks: %d\nContacts found: %d\nOutcomes permitted: %d\nRefusals: %d   Corrections: %d\n\n%s\n\nCounters describe connections, not successful damage.",
 script:GetAttribute("ConnectionName"),r.actors,s.captures,s.begun,s.queries,s.contacts,s.applied,s.refused,s.corrections,meanings[s.reason] or s.reason)
 body.Text..=string.format("\n\nTiming: %s\nLatest approved delay: %.1f ms / %.1f ms maximum\nRecording: %s\nCheck mode: %s\nObstacles: %s",r.timing or "Present",(r.rewind or 0)*1000,(r.maxRewind or 0)*1000,r.recording or "Heartbeat",r.queryMode or "Once",r.world or "None")
 if r.explanation and r.explanation.known then body.Text..="\n\n"..r.explanation.title.."\n"..r.explanation.meaning.."\nNext: "..r.explanation.fix end
end
toggle.Activated:Connect(function() panel.Visible=not panel.Visible update() end)
report.Changed:Connect(update) update()
