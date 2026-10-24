-- Delivered connection runtime. Use one singleton from ordinary SERVER scripts.
-- All game-specific customization belongs in Connections, Actions and Hooks.
local Root=script.Parent
local Core=require(Root.Core)
local Movement=require(script.Movement)
local R={}
local live
local function reset(s,id,reason) s.generation+=1 s.chrono:Discontinuity(id,reason) end
local function rootOf(object,c)
	if object:IsA("BasePart") then return object end
	local root=object:FindFirstChild(c.root) or object.PrimaryPart
	return if root and root:IsA("BasePart") then root else nil
end
local function owner(root)
	if root.Anchored then return true,nil end
	return pcall(root.GetNetworkOwner,root)
end
local function link(s,name)
	local value=s.links:FindFirstChild(name) return value and value.Value
end
local function fail(s,reason)
	s.stats.refused+=1 s.stats.reason=tostring(reason)
	return nil,tostring(reason)
end
local function finish(s,token)
	local move=token and s.moves[token]
	if not move then return false end
	s.chrono:EndAction(move.handle) s.moves[token]=nil
	if move.key~=nil and s.keys[move.actor] then s.keys[move.actor][move.key]=nil end
	return true
end
local function objects(s)
	local values={}
	if s.c.actors=="Players" or s.c.actors=="PlayersAndFolder" then
		for _,player in game:GetService("Players"):GetPlayers() do if player.Character then table.insert(values,player.Character) end end
	end
	if s.c.actors=="Tag" then values=game:GetService("CollectionService"):GetTagged(s.c.tag)
	elseif s.c.actors~="Players" then
		local source=link(s,"Actors")
		if source and source:IsDescendantOf(workspace) then
			local extra=if (s.c.actors=="References" or s.c.actors=="PlayersAndFolder") and (source:IsA("BasePart") or (source:IsA("Model") and rootOf(source,s.c))) then {source} else source:GetChildren()
			for _,object in extra do table.insert(values,object) end
		end
	end
	local result={} local seen={}
	for _,object in values do
		if not seen[object] and (object:IsA("Model") or object:IsA("BasePart")) and object:IsDescendantOf(workspace) and rootOf(object,s.c) then seen[object]=true table.insert(result,object) end
	end
	table.sort(result,function(a,b) return a:GetFullName()<b:GetFullName() end)
	return result
end
local function sync(s,now)
	local found={} local values=objects(s)
	if #values>256 then return nil,"actor_limit_256" end
	for _,object in values do found[object]=true end
	for object,record in s.actors do
		if not found[object] or rootOf(object,s.c)~=record.root then
			for token,move in s.moves do if move.actor==object then finish(s,token) end end
			s.chrono:Untrack(record.id) s.generation+=1 s.byId[record.id]=nil s.actors[object]=nil s.keys[object]=nil
		end
	end
	for _,object in values do
		local root=rootOf(object,s.c) local record=s.actors[object]
		local known,who=owner(root)
		if not record then
			s.serial+=1 s.generation+=1
			record={id="actor-"..s.serial,object=object,root=root,owner=who,ownerKnown=known}
			if s.c.positions=="Humanoid" and object:FindFirstChildOfClass("Humanoid") then record.guard=Movement.New(object,root,now,s.c) end
			s.actors[object]=record s.byId[record.id]=record
			local radius=math.min(512,math.max(s.c.radius,s.c.height/2,Vector3.new(s.c.width,s.c.height,s.c.depth).Magnitude/2,if s.c.partBodies then root.Size.Magnitude/2 else 0)+0.001)
			s.chrono:Track(record.id,{kind=object:GetAttribute("ChronoKind") or s.c.kind,
				trust=if s.c.positions=="ServerPhysics" then "serverSimulated" else "serverValidated",
				maxSpeed=4096,maxRadius=if s.c.positions=="Provider" then 512 else radius,
				capture=function(time) assert(record.preparedAt==time,"No common update prepared") return record.prepared end})
		elseif known~=record.ownerKnown or who~=record.owner then
			record.owner=who record.ownerKnown=known reset(s,record.id,"physics_owner_changed")
		end
	end
	return values
end
local function prepare(s,record,now,excluded)
	if record.fault then return nil,record.fault end
	local frame=record.root.CFrame local state=s.hooks.State(record.object,record.root,s.c)
	local zones
	if s.c.positions=="ServerPhysics" then
		local known,who=owner(record.root)
		if not known or who~=nil then return nil,"client_owned_position_needs_checker" end
	elseif s.c.positions=="Humanoid" then
		if not record.guard then
			local known,who=owner(record.root)
			if not known or who~=nil then return nil,"non_humanoid_needs_server_physics_or_provider" end
		else
			local reason,corrected
			frame,reason,corrected=Movement.Check(record.guard,now,s.c,s.hooks,excluded)
			if not frame then
				if corrected then s.stats.corrections+=1 s.hooks.AfterCorrection(record.object,reason) end
				return nil,reason
			end
		end
	else
		if not s.provider then return nil,"position_provider_required" end
		local snapshot=s.hooks.ProviderSnapshot(s.provider,record.object,now)
		if type(snapshot)~="table" or snapshot.ok~=true then return nil,"provider_has_not_approved_position" end
		frame=snapshot.root zones=snapshot.zones state=snapshot.state or state
	end
	if not zones then
		local S=Core.Shapes
		if s.c.partBodies and not record.object:FindFirstChildOfClass("Humanoid") then
			local part=record.root local size=part.Size
			local sphere=part:IsA("Part") and part.Shape==Enum.PartType.Ball and math.abs(size.X-size.Y)<1e-5 and math.abs(size.X-size.Z)<1e-5
			zones={Body=if sphere then S.Sphere(frame,size.X/2) else S.Box(frame,size)}
		else zones={Body=if s.c.body=="Sphere" then S.Sphere(frame,s.c.radius)
			elseif s.c.body=="Capsule" then S.Capsule(frame,s.c.radius,s.c.height)
			else S.Box(frame,Vector3.new(s.c.width,s.c.height,s.c.depth))}
		end
	end
	return {root=frame,zones=zones,state=state}
end
local function capture(s)
	local now=workspace:GetServerTimeNow()
	local values,why=sync(s,now) if not values then return nil,why end
	local reason
	for _,record in s.actors do
		local ok,snapshot,err=pcall(prepare,s,record,now,values)
		if not ok then record.fault="position_function_error" snapshot=nil err=record.fault s.stats.errors+=1 end
		if not snapshot then
			if not record.blocked then reset(s,record.id,err) end
			record.blocked=err reason=reason or err
		else
			if record.blocked then reset(s,record.id,"position_available_again") end
			record.blocked=nil record.prepared=snapshot
		end
	end
	-- Never timestamp a snapshot before a reset, which reads the clock internally.
	if reason then return nil,reason end
	local time=workspace:GetServerTimeNow()
	for _,record in s.actors do record.preparedAt=time end
	local result=s.chrono:Capture(time) s.time=time s.stats.captures+=1
	for token,move in s.moves do if time>move.expires then finish(s,token) end end
	if not result.ok then
		for _,fault in result.faults or {} do local r=s.byId[fault.id] if r then r.fault=fault.reason end end
		return nil,result.reason
	end
	return true
end
local function publish(s)
	if not s.report or os.clock()-s.published<0.5 then return end
	s.published=os.clock()
	local count=0 local paused={}
	for object,record in s.actors do count+=1 if record.blocked or record.fault then table.insert(paused,{object=object.Name,reason=record.fault or record.blocked}) end end
	local report={version="3.1.0",connectionBuild="2026-10-24",actors=count,positions=s.c.positions,
		stats=s.stats,paused=paused,core=s.chrono:Inspect().stats,rewind=0,
		outcomeLinked=link(s,"Outcome")~=nil,attackEventLinked=link(s,"Begin")~=nil}
	s.report.Value=game:GetService("HttpService"):JSONEncode(report)
	Root:SetAttribute("ConnectionActors",count) Root:SetAttribute("ConnectionReason",s.stats.reason)
	Root:SetAttribute("ConnectionBegun",s.stats.begun) Root:SetAttribute("ConnectionQueries",s.stats.queries)
end
function R.Start()
	if live then return true end
	assert(game:GetService("RunService"):IsServer(),"Use Chrono connections from server scripts")
	local c=require(Root.Connections) local hooks=require(Root.Hooks)
	local s={c=c,hooks=hooks,links=Root.ConnectionLinks,chrono=nil,actors={},byId={},moves={},keys={},serial=0,
		connections={},generation=0,published=-math.huge,stats={captures=0,begun=0,queries=0,contacts=0,applied=0,refused=0,cancelled=0,corrections=0,errors=0,reason="starting"}}
	local options=table.clone(require(Root.Settings)) options.maxRewind=0
	s.chrono=Core.new(options) s.maxGap=options.maxGap or 0.075 s.actions=require(Root.Actions)
	local provider=link(s,"Provider")
	if provider then local ok,p=pcall(require,provider) if not ok or (type(p)~="table" and type(p)~="function") then s.chrono:Destroy() error("Selected position provider did not return a table or function") end s.provider=p end
	live=s
	if game:GetService("RunService"):IsStudio() then
		local reports=game.ReplicatedStorage:FindFirstChild("_ChronoConnectionReports")
		if not reports then reports=Instance.new("Folder") reports.Name="_ChronoConnectionReports" reports.Parent=game.ReplicatedStorage end
		assert(not reports:FindFirstChild(Root.Name),"A second Chrono connection instance was started. Require the same Connector from ordinary server scripts.")
		s.report=Instance.new("StringValue") s.report.Name=Root.Name s.report.Parent=reports
	end
	local function safe(fn,...)
		local ok,why=pcall(fn,...)
		if not ok then s.stats.errors+=1 s.stats.reason="connection_error" warn("Chrono connection: "..tostring(why)) end
	end
	for name,callback in {
		Begin=function(...) local actor,action,key,context=s.hooks.ReadBegin(...) R.Begin(actor,action,context,key or action or "Contact") end,
		Query=function(...) local actor,key=s.hooks.ReadQuery(...) local token=s.keys[actor] and s.keys[actor][key or "Contact"] if token then R.Resolve(token) R.Finish(token) else fail(s,"move_missing") end end,
		Cancel=function(...) local actor,key=s.hooks.ReadCancel(...) local token=s.keys[actor] and s.keys[actor][key or "Contact"] if token then R.Cancel(token) end end,
	} do
		local event=link(s,name)
		if event then assert(event:IsA("BindableEvent"),"Only server BindableEvents can connect accepted moves") table.insert(s.connections,event.Event:Connect(function(...) safe(callback,...) end)) end
	end
	table.insert(s.connections,game:GetService("RunService").Heartbeat:Connect(function()
		safe(function()
			local ok,reason=capture(s) if not ok then s.stats.reason=reason end
			if s.c.autoQuery and ok then
				local ready={} for token,move in s.moves do if not move.checked and s.time>=move.opens then table.insert(ready,token) end end
				for _,token in ready do R.Resolve(token) R.Finish(token) end
			end
			publish(s)
		end)
	end))
	local ok,reason=capture(s) s.stats.reason=if ok then "ready_for_moves" else reason publish(s)
	return true
end
local function session() R.Start() return live end
function R.Begin(actor,actionName,context,key)
	local s=session() actionName=actionName or "Contact"
	local profile=s.actions[actionName] if not profile then return fail(s,"move_settings_missing") end
	if key~=nil and (type(key)~="string" or #key>64) then return fail(s,"move_key_invalid") end
	if key~=nil and s.keys[actor] and s.keys[actor][key] then return fail(s,"move_key_already_active") end
	local ok,reason=capture(s) if not ok then return fail(s,reason) end
	local record=s.actors[actor] if not record then return fail(s,"actor_not_connected") end
	local permitted,allowed=pcall(s.hooks.CanStart,actor,actionName,context,record.prepared.state)
	if not permitted or allowed~=true then return fail(s,"move_not_allowed") end
	local handle,why=s.chrono:BeginAction(record.id,profile,context)
	if not handle then return fail(s,why) end
	local token=table.freeze({})
	s.moves[token]={actor=actor,name=actionName,context=context,handle=handle,key=key,
		opens=s.time+(profile.opens or 0),expires=s.time+(profile.closes or 0.25),delivered={}}
	if key~=nil then s.keys[actor]=s.keys[actor] or {} s.keys[actor][key]=token end
	s.stats.begun+=1 s.stats.reason="move_started" return token
end
function R.Query(token)
	local s=session() local move=token and s.moves[token]
	if not move then return fail(s,"move_missing_or_finished") end
	if move.checked then return fail(s,"move_already_checked") end
	local ok,reason=capture(s) if not ok then finish(s,token) return fail(s,reason) end
	if s.moves[token]~=move then return fail(s,"move_expired") end
	local result=s.chrono:Query(move.handle) s.stats.queries+=1
	if not result.ok then finish(s,token) return fail(s,result.reason) end
	move.checked=true move.result=result move.generation=s.generation move.allowed={}
	for _,contact in result.contacts do
		local record=s.byId[contact.id]
		if record then move.allowed[record.object]=contact s.stats.contacts+=1 end
	end
	s.stats.reason="contact_check_completed" return result
end
local function allowedNow(s,move,target)
	local contact=move.allowed and move.allowed[target]
	if not contact or move.delivered[target] then return nil end
	local sourceRecord,targetRecord=s.actors[move.actor],s.actors[target]
	if not sourceRecord or not targetRecord or not target:IsDescendantOf(workspace) or not move.actor:IsDescendantOf(workspace) then return nil end
	local a=s.hooks.State(move.actor,sourceRecord.root,s.c) local b=s.hooks.State(target,targetRecord.root,s.c)
	if a.active~=true or b.active~=true then return nil end
	if s.hooks.CanApply(move.actor,target,move.name,move.context,contact)~=true then return nil end
	return contact
end
-- Put this generated call before an EXISTING damage/possession call. It never applies an outcome.
function R.Allows(token,target)
	local s=session() local move=token and s.moves[token]
	if not move then return false,"move_missing_or_finished" end
	if not move.checked then local result,why=R.Query(token) if not result then return false,why end end
	local fresh,why=capture(s)
	if not fresh or s.moves[token]~=move or move.generation~=s.generation then finish(s,token) return false,why or "contact_records_changed" end
	if workspace:GetServerTimeNow()>(move.result.capturedAt+s.maxGap) then finish(s,token) return false,"contact_result_stale" end
	local ok,contact=pcall(allowedNow,s,move,target)
	if not ok then finish(s,token) return false,"outcome_rule_error" end
	if not contact then return false,"target_not_allowed_or_already_used" end
	move.delivered[target]=true s.stats.applied+=1 return true,contact
end
-- Event mode: emit approved contacts to an EXISTING server event, then optional Hooks.OnContact.
function R.Resolve(token)
	local s=session() local move=token and s.moves[token]
	if not move then return nil,"move_missing_or_finished" end
	if move.resolved then return fail(s,"outcomes_already_resolved") end
	local outcome=link(s,"Outcome")
	if not outcome then return fail(s,"choose_outcome_event_or_use_allows_hook") end
	local result,reason=R.Query(token) if not result then return nil,reason end
	move.resolved=true
	for target in move.allowed do
		local ok,contact=R.Allows(token,target)
		if ok then
			local emitted=pcall(s.hooks.ApplyOutcome,outcome,move.actor,target,move.name,move.context,contact)
			if not emitted then s.stats.errors+=1 s.stats.reason="outcome_mapping_error" end
			local done=pcall(s.hooks.OnContact,move.actor,target,move.name,move.context,contact)
			if not done then s.stats.errors+=1 s.stats.reason="outcome_hook_error" end
		end
	end
	return result
end
function R.Cancel(token) local s=session() if finish(s,token) then s.stats.cancelled+=1 return true end return false end
function R.Finish(token) return finish(session(),token) end
function R.AllowMotion(actor,velocity,seconds)
	local s=session() local values,why=sync(s,workspace:GetServerTimeNow()) assert(values,why)
	local record=assert(s.actors[actor],"Object is not connected")
	assert(record.guard,"Motion permissions belong to the optional humanoid checker; use your existing checker otherwise")
	Movement.Allow(record.guard,velocity,seconds,workspace:GetServerTimeNow())
end
function R.Teleport(actor,frame)
	local s=session() local values,why=sync(s,workspace:GetServerTimeNow()) assert(values,why)
	local record=assert(s.actors[actor],"Object is not connected")
	assert(typeof(frame)=="CFrame","Teleport expects a CFrame")
	if record.guard then Movement.Reset(record.guard,frame,workspace:GetServerTimeNow(),s.c)
	elseif actor:IsA("Model") then actor:PivotTo(frame*record.root.CFrame:Inverse()*actor:GetPivot()) else record.root.CFrame=frame end
	reset(s,record.id,"approved_teleport") record.fault=nil record.blocked=nil
	for token,move in s.moves do if move.actor==actor then finish(s,token) end end
end
function R.Resume(actor)
	local s=session() local record=assert(s.actors[actor],"Object is not connected")
	record.fault=nil record.blocked=nil reset(s,record.id,"provider_fixed_by_server")
end
function R.Inspect()
	local s=session() local count=0 for _ in s.actors do count+=1 end
	return {stats=table.clone(s.stats),actors=count,core=s.chrono:Inspect(),positions=s.c.positions}
end
function R.Destroy()
	local s=live if not s then return end
	for _,c in s.connections do c:Disconnect() end
	s.chrono:Destroy() if s.report then s.report:Destroy() end live=nil
end
return R
