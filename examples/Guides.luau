-- Optional developer-only guide. It creates no network events or gameplay controls.
-- Mount(screenGui, optionalMetricsFunction, optionalHelpModule).
-- The packaged ChronoV3Guides.rbxmx includes a Help child; source users can pass Core.Help.
local Guide={}
function Guide.Mount(parent,getMetrics,help)
	local Help=help or (script:FindFirstChild("Help") and require(script.Help))
	local panel=Instance.new("ScrollingFrame") panel.Name="ChronoV3Guide" panel.Size=UDim2.new(0.92,0,0.85,0) panel.Position=UDim2.fromScale(0.04,0.075)
	panel.AutomaticCanvasSize=Enum.AutomaticSize.Y panel.CanvasSize=UDim2.new() panel.ScrollBarThickness=5 panel.BackgroundColor3=Color3.fromRGB(17,23,32) panel.BorderSizePixel=0 panel.Parent=parent
	local limit=Instance.new("UISizeConstraint") limit.MaxSize=Vector2.new(660,720) limit.Parent=panel
	local layout=Instance.new("UIListLayout") layout.SortOrder=Enum.SortOrder.LayoutOrder layout.Padding=UDim.new(0,12) layout.Parent=panel
	local padding=Instance.new("UIPadding") padding.PaddingLeft=UDim.new(0,18) padding.PaddingRight=UDim.new(0,18) padding.PaddingTop=UDim.new(0,18) padding.PaddingBottom=UDim.new(0,18) padding.Parent=panel
	local connections={} local localConnections={} local order=0
	local function place(v,target) order+=1 v.LayoutOrder=order v.Parent=target return v end
	local function text(target,value,size,color)
		local v=Instance.new("TextLabel") v.Size=UDim2.new(1,0,0,20) v.AutomaticSize=Enum.AutomaticSize.Y v.BackgroundTransparency=1 v.Text=value v.TextWrapped=true v.Font=Enum.Font.Gotham v.TextSize=size or 15 v.TextColor3=color or Color3.fromRGB(232,241,249) v.TextXAlignment=Enum.TextXAlignment.Left v.TextYAlignment=Enum.TextYAlignment.Top return place(v,target)
	end
	text(panel,"CHRONO V3  /  Learning guide",22,Color3.fromRGB(94,225,183))
	local body=Instance.new("Frame") body.Name="Lesson" body.Size=UDim2.new(1,0,0,0) body.AutomaticSize=Enum.AutomaticSize.Y body.BackgroundTransparency=1 place(body,panel)
	local bodyLayout=Instance.new("UIListLayout") bodyLayout.SortOrder=Enum.SortOrder.LayoutOrder bodyLayout.Padding=UDim.new(0,12) bodyLayout.Parent=body
	local pages={
		{"How it works","1. Your game supplies positions and invisible hitbox shapes.\n\n2. Chrono saves short records of earlier positions. This is called history. It stays in memory; old records are removed.\n\n3. After your server accepts a move, Chrono checks which allowed objects its shape touches.\n\n4. Your own game code decides possession, damage or another result. Your animation and effects code stays in your game."},
		{"Which positions can decide hits?","The server must calculate or check the positions used to decide a competitive hit. This is often called authoritative data.\n\nA client is one player's game copy. A player sending a position does not prove the movement was allowed. A server reading that position does not prove it either.\n\nThe trust labels describe your code's guarantee. Choosing a label does not create that guarantee."},
		{"The few calls you connect","Track: register a player, ball or other object and a function that returns its data.\n\nCapture: save one update after your server updates all participating objects. Save once before allowing moves.\n\nBeginAction: keep the move reference it returns after your server approves a move.\n\nQuery: check the move during its hit period.\n\nEndAction: stop a finished or cancelled move.\n\nUntrack removes an object. Discontinuity reports an approved reset such as a teleport or respawn."},
		{"A result is not always a hit","A successful Query means the data checks completed. If contacts is empty, nothing was touched.\n\nA refused check is different: Chrono could not safely complete it. Keep its reason code. Help explains why and what to do next.\n\nYour game still checks its CURRENT rules before applying the result once. Prevent repeated requests and repeated application in your game code."},
		{"What to test in your game","Try normal hits and misses, players joining/leaving, respawn, teleport, immunity, cancelled moves and repeated input.\n\nA bad data function pauses that object's recording. Fix the original error before resetting tracking.\n\nStudio's Network Simulator adds real message delay, variation and packet loss to a playtest. Test the real connections you wrote.\n\nThe supplied practice example uses made-up values. A passing practice example does not prove your game is connected or that its network behavior is correct."},
	}
	local index,mode,search,code=1,"lessons","","capture_required"
	local render
	local function button(target,caption,fn,temporary)
		local b=Instance.new("TextButton") b.Name=caption:gsub("[^%w]","") b.Size=UDim2.new(1,0,0,40) b.TextWrapped=true b.BackgroundColor3=Color3.fromRGB(33,53,65) b.TextColor3=Color3.fromRGB(230,245,240) b.Font=Enum.Font.GothamMedium b.TextSize=14 b.Text=caption place(b,target)
		table.insert(if temporary then localConnections else connections,b.Activated:Connect(fn))
	end
	render=function()
		for _,c in localConnections do c:Disconnect() end table.clear(localConnections)
		for _,v in body:GetChildren() do if v~=bodyLayout then v:Destroy() end end
		if mode=="lessons" then text(body,string.format("%d of %d  |  %s",index,#pages,pages[index][1]),19) text(body,pages[index][2],15)
		else
			text(body,"Understand a result message",19)
			local input=Instance.new("TextBox") input.Name="ReasonCode" input.Size=UDim2.new(1,0,0,38) input.Text=code input.ClearTextOnFocus=false input.Font=Enum.Font.Code input.TextSize=15 input.BackgroundColor3=Color3.fromRGB(30,40,52) input.TextColor3=Color3.fromRGB(237,242,249) place(input,body)
			table.insert(localConnections,input.FocusLost:Connect(function() code=input.Text:match("^%s*(.-)%s*$") render() end))
			if Help then
				local h=Help.Explain(code) text(body,h.title,17) text(body,"What happened: "..h.meaning) text(body,"What to do: "..h.fix)
			else text(body,"Copy the packaged guide with its Help child for the full message explanations. The setup plugin also contains them.") end
			text(body,"Find a word",19)
			local input2=Instance.new("TextBox") input2.Name="WordSearch" input2.Size=UDim2.new(1,0,0,38) input2.Text=search input2.PlaceholderText="history, authoritative, root..." input2.ClearTextOnFocus=false input2.Font=Enum.Font.Gotham input2.TextSize=15 input2.BackgroundColor3=Color3.fromRGB(30,40,52) input2.TextColor3=Color3.fromRGB(237,242,249) place(input2,body)
			table.insert(localConnections,input2.FocusLost:Connect(function() search=input2.Text render() end))
			if Help then
				local entries=Help.FindTerms(search)
				if #entries==0 then text(body,"No matching word. Try a shorter word or clear the search.") end
				for _,e in entries do text(body,e[2].." ("..e[1]..")",17) text(body,e[3]) text(body,"Example: "..e[4],13,Color3.fromRGB(183,199,215)) end
			end
		end
	end
	button(panel,"Previous lesson",function() mode="lessons" index=math.max(1,index-1) render() panel.CanvasPosition=Vector2.zero end)
	button(panel,"Next lesson",function() mode="lessons" index=index%#pages+1 render() panel.CanvasPosition=Vector2.zero end)
	button(panel,"Words and result messages",function() mode=if mode=="lessons" then "help" else "lessons" render() panel.CanvasPosition=Vector2.zero end)
	local status=text(panel,"This guide does not know whether your game is connected. A practice pass tests the example only.",13,Color3.fromRGB(183,199,215))
	if getMetrics then button(panel,"Read your connected game report",function()
		local ok,r=pcall(getMetrics)
		if not ok or type(r)~="table" or type(r.stats)~="table" then status.Text="No usable report from your game. Check the function supplying it." return end
		local line=string.format("Saved updates: %s. Completed checks: %s. Refused checks: %s.",tostring(r.stats.captures),tostring(r.stats.accepted),tostring(r.stats.rejected))
		if Help then local h=Help.Explain(r.stats.lastRejection) line..="\nLast refusal: "..h.title..". "..h.fix end
		status.Text=line
	end) end
	render()
	return function() for _,c in localConnections do c:Disconnect() end for _,c in connections do c:Disconnect() end panel:Destroy() end
end
return Guide
