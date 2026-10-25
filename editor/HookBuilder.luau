-- Generates small calls and applies an exact reviewed edit. Never guesses what arbitrary game code means.
local H={}
local plans=setmetatable({}, {__mode="k"})
local function variable(text)
	if type(text)~="string" or #text>128 or text:find("[^%w_%.]") or text:find("%.%.") or text:sub(-1)=="." then return false end
	for word in text:gmatch("[^.]+") do if not word:match("^[%a_][%w_]*$") or table.find({"nil","true","false","return","end","local","function","then","if","else","for","while","do","continue","break","and","or","not","repeat","until","in","elseif","export","type"},word) then return false end end
	return #text>0
end
function H.Generate(root,kind,v)
	v=v or {} local actor=v.actor or "character" local token=v.token or "chronoMove"
	local target=v.target or "target" local action=v.action or "Contact"
	if not variable(actor) or not variable(target) or not variable(token) or token:find("%.") then return nil,"Use ordinary variable names, such as character, target and chronoMove." end
	if type(action)~="string" or #action==0 or #action>64 or action:find("%c") then return nil,"Choose a short move name from Actions." end
	if not root or not root:FindFirstChild("Connector") then return nil,"Add the connection package before generating calls." end
	local ref="require(game:GetService(\"ServerScriptService\")["..string.format("%q",root.Name).."].Connector)"
	local exit=if v.exit=="continue" then "continue" else "return"
	local code,explanation
	if kind=="Begin" then
		code="local "..token.." = "..ref..".Begin("..actor..", "..string.format("%q",action)..")\nif not "..token.." then return end"
		explanation="Insert INSIDE the accepted-attack function, AFTER existing request/cooldown checks and BEFORE animation/windup. The move variable must remain in scope at its hit and cancellation points."
	elseif kind=="Gate" then
		code="if not "..ref..".Allows("..token..", "..target..") then "..exit.." end"
		explanation="Insert immediately BEFORE the existing damage/possession call. Choose 'continue' inside a target loop, or 'return' inside a per-target function. It permits each target once. This cannot discover a target missed by a present-part search; use Resolve or Query contacts for earlier timing."
	elseif kind=="Query" then
		code="local chronoResult, chronoReason = "..ref..".Query("..token..")\nif not chronoResult then return end\n-- chronoResult.contacts contains .target, .zone, .time and .state.\n-- Use these targets; do not filter through a present-part overlap first."
		explanation="Insert at the hit moment. This returns covered contacts, without applying outcomes. For supplied outcome delivery use Resolve instead. A repeated move may Query again AFTER another Capture; total targets and duplicate prevention span the whole move."
	elseif kind=="Resolve" then
		code=ref..".Resolve("..token..")"
		explanation="Insert at the hit moment, or use automatic checking on Events. Sends Chrono contacts to the selected Outcome event and OnContact inside Hooks, once per target. Supports earlier timing without an external present-part candidate list. Keep current damage, block, parry and possession rules there."
	elseif kind=="Capture" then
		local stamp=v.timestamp or "" if stamp~="" and not variable(stamp) then return nil,"Use an existing simulation timestamp variable, or leave it blank." end
		code=ref..".Capture("..stamp..")"
		explanation="Manual recording: insert AFTER your server finishes updating ALL participating objects at the same simulation instant. Optional timestamp uses the chosen clock's seconds. The plugin does not create a simulation loop or movement checker."
	elseif kind=="Track" then
		local snapshot=v.snapshot or "snapshotFunction" local id=v.id or "actorId" local trust=v.trust or "unverified"
		if not variable(snapshot) or not variable(id) or not table.find({"unverified","serverValidated","serverSimulated"},trust) then return nil,"Choose existing id/function variables and a valid data trust declaration." end
		code=ref..".Track("..id..", {kind="..string.format("%q",v.objectKind or "actor")..", trust="..string.format("%q",trust)..", capture="..snapshot.."})"
		explanation="Data-only alternative to the Registry provider: insert when your server creates an object. id is stable short text; capture(time) returns {ok=true,root,zones,state}. Uses recording limits from the plugin. Choose a trusted declaration only when your server really calculates/checks the data. No Parts are required."
	elseif kind=="Untrack" or kind=="Reset" then
		code=ref..(if kind=="Reset" then ".Discontinuity(" else ".Untrack(")..actor..")"
		explanation=if kind=="Reset" then "After an approved data teleport or position-provider repair, clear interrupted records. Update your server data first; old moves cannot cross this reset." else "When a manually registered data object is removed, unregister its stable text id. Automatic registries/folders handle their own removals."
	elseif kind=="Inspect" then
		code="local chronoReport = "..ref..".Inspect()"
		explanation="Server diagnostics: configuration, per-object limits, counters and unchanged Core inspection. Avoid exposing this information as a client gameplay authority."
	elseif kind=="Destroy" then
		code=ref..".Destroy()"
		explanation="Stop this supplied connection instance and its listeners during deliberate server teardown. Disable StartConnection if it should stay stopped; later public calls start it again."
	elseif kind=="Cancel" or kind=="Finish" then
		code=ref.."."..kind.."("..token..")"
		explanation="Insert on the existing cancellation path, or after the move's hit checks finish. Every early exit after Begin needs Cancel."
	elseif kind=="Motion" then
		if not variable(v.velocity or "velocity") or not variable(v.duration or "duration") then return nil,"Use your existing velocity and duration variable names." end
		code=ref..".AllowMotion("..target..", "..(v.velocity or "velocity")..", "..(v.duration or "duration")..")"
		explanation="Humanoid checker only. Insert BEFORE the server applies its existing knockback/dash. This grants a bounded movement allowance; it does not create the force."
	elseif kind=="Teleport" then
		if not variable(v.frame or "destinationCFrame") then return nil,"Use your destination CFrame variable name." end
		code=ref..".Teleport("..actor..", "..(v.frame or "destinationCFrame")..")"
		explanation="This call PERFORMS the approved teleport and resets records. Select the line containing only your old server teleport statement. Preview replaces that line rather than executing both. Keep other logic on separate lines before reviewing the replacement."
	else return nil,"Choose Begin, Gate, Cancel, Finish, Motion or Teleport." end
	return code,explanation
end
function H.Preview(root,object,line,code,editor,replaceLine)
	if game:GetService("RunService"):IsRunning() then return nil,"Stop Play before editing scripts." end
	if not root or not root:FindFirstChild("ConnectionPatches") then return nil,"Add connections first." end
	if not object or not object:IsA("LuaSourceContainer") or not object:IsDescendantOf(game) then return nil,"Select the existing SERVER Script/ModuleScript to connect." end
	if object:IsA("LocalScript") or (object:IsA("Script") and object.RunContext==Enum.RunContext.Client) or object:IsDescendantOf(game.StarterPlayer) or object:IsDescendantOf(game.StarterGui) then return nil,"Choose server code. Never put a contact approval call in a client script." end
	if object:IsDescendantOf(root) then return nil,"Generated game hooks belong at existing game events. Customize package files with Open Hooks instead." end
	editor=editor or game:GetService("ScriptEditorService")
	local before=editor:GetEditorSource(object)
	local lines=string.split(before,"\n")
	if type(line)~="number" or line%1~=0 or line<1 or line>#lines+1 then return nil,"Choose a line in the selected server script." end
	local marker="-- Chrono connection "..game.HttpService:GenerateGUID(false)
	local chunk=marker.."\n"..code.."\n-- End Chrono connection"
	if replaceLine then if line>#lines then return nil,"Select the existing teleport statement's line." end table.remove(lines,line) end
	table.insert(lines,line,chunk) local after=table.concat(lines,"\n")
	local handle=table.freeze({}) plans[handle]={root=root,object=object,before=before,after=after,marker=marker}
	return handle,{before=before,after=after,line=line,path=object:GetFullName(),inserted=chunk}
end
function H.Apply(handle,d)
	local p=plans[handle] if not p then return nil,"Preview the generated edit first." end
	if game:GetService("RunService"):IsRunning() then return nil,"Stop Play before applying the edit." end
	if not p.object.Parent or not p.root:FindFirstChild("ConnectionPatches") then return nil,"The selected script/package was removed. Preview again." end
	d=d or {} local editor=d.editor or game:GetService("ScriptEditorService") local history=d.history or game:GetService("ChangeHistoryService")
	if editor:GetEditorSource(p.object)~=p.before then return nil,"That script changed since the preview. Preview again; your edits were kept." end
	local recording=history:TryBeginRecording("ChronoInsertHook","Insert reviewed Chrono connection call")
	if not recording then return nil,"Studio could not start an Undo step." end
	local record local changed=false
	local ok,err=pcall(function()
		editor:UpdateSourceAsync(p.object,function(current) if current~=p.before then return nil end changed=true return p.after end)
		assert(changed and editor:GetEditorSource(p.object)==p.after,"Script changed during the edit. Preview again.")
		record=Instance.new("Folder") record.Name="Patch"..game.HttpService:GenerateGUID(false)
		for key,value in {Before=p.before,After=p.after} do local t=Instance.new("StringValue") t.Name=key t.Value=value t.Parent=record end
		local target=Instance.new("ObjectValue") target.Name="Target" target.Value=p.object target.Parent=record
		record.Parent=p.root.ConnectionPatches
	end)
	if not ok then
		if changed and editor:GetEditorSource(p.object)==p.after then editor:UpdateSourceAsync(p.object,function() return p.before end) end
		if record then record:Destroy() end history:FinishRecording(recording,Enum.FinishRecordingOperation.Cancel) return nil,tostring(err)
	end
	history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) plans[handle]=nil return record
end
function H.Restore(record,d)
	if game:GetService("RunService"):IsRunning() then return nil,"Stop Play before restoring code." end
	if not record or not record:FindFirstChild("Target") or not record.Target.Value or not record:FindFirstChild("Before") or not record:FindFirstChild("After") then return nil,"Select a saved patch record." end
	d=d or {} local editor=d.editor or game:GetService("ScriptEditorService") local history=d.history or game:GetService("ChangeHistoryService")
	local object=record.Target.Value
	if editor:GetEditorSource(object)~=record.After.Value then return nil,"This script has newer edits. Restore later patches first, or keep your changes and remove the marked call manually." end
	local rec=history:TryBeginRecording("ChronoRestoreHook","Restore script before Chrono hook")
	if not rec then return nil,"Studio could not start an Undo step." end
	local changed=false
	local ok,err=pcall(function()
		editor:UpdateSourceAsync(object,function(current) if current~=record.After.Value then return nil end changed=true return record.Before.Value end)
		assert(changed,"Script changed during restore") record:Destroy()
	end)
	history:FinishRecording(rec,if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	return if ok then true else nil,err
end
return H
