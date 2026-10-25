-- Supplied connection runtime, 3.2.0. One ordinary-server singleton per package.
-- Core math is unchanged. All timing/recording/query policies are explicit settings.
local Root=script.Parent
local Core=require(Root.Core)
local Contract=require(Root.Core.Contract)
local Config=require(script.Configuration)
local Volumes=require(script.Volumes)
local World=require(script.World)
local Messages=require(script.Messages)
local Movement=require(script.Movement)
local R={}
local live
local hookDepth=0
local capture,query,resolve,automatic,publish
local function invoke(fn,...)
 hookDepth+=1 local ok,a,b,c=Contract.Call(fn,...) hookDepth-=1
 if not ok then error(a,0) end return a,b,c
end
local function link(s,name) local v=s.links:FindFirstChild(name) return v and v.Value end
local function module(s,name)
 local object=link(s,name) if not object then return nil end
 local value=require(object) assert(type(value)=="table" or type(value)=="function",name.." module must return a table/function") return value
end
local function now(s)
 local value=if s.clockProvider then invoke(s.hooks.Clock,s.clockProvider) else workspace:GetServerTimeNow()
 assert(Config.Number(value,-1e12,1e12),"clock_fault") return value
end
local function fail(s,reason) s.stats.refused+=1 s.stats.reason=tostring(reason) return nil,tostring(reason) end
local function reset(s,id,reason) s.generation+=1 s.needsCapture=true s.chrono:Discontinuity(id,reason) end
local function finish(s,token)
 local move=token and s.moves[token] if not move then return false end
 s.chrono:EndAction(move.handle) s.moves[token]=nil
 if move.key~=nil and s.keys[move.actor] then s.keys[move.actor][move.key]=nil end return true
end
local function rootOf(object,c)
 if object:IsA("BasePart") then return object end
 local root=object:FindFirstChild(c.root) or object.PrimaryPart
 return if root and root:IsA("BasePart") then root else nil
end
local function owner(root) if root.Anchored then return true,nil end return pcall(root.GetNetworkOwner,root) end
local function physical(s)
 local list={} local mode=s.c.actors
 if table.find({"Players","PlayersAndFolder","PlayersAndData"},mode) then for _,p in game.Players:GetPlayers() do if p.Character then table.insert(list,p.Character) end end end
 if mode=="Tag" then list=game:GetService("CollectionService"):GetTagged(s.c.tag)
 elseif table.find({"Folder","References","PlayersAndFolder"},mode) then
  local f=link(s,"Actors")
  if f and f:IsDescendantOf(workspace) then
   if mode~="Folder" and (f:IsA("BasePart") or (f:IsA("Model") and rootOf(f,s.c))) then table.insert(list,f)
   else for _,o in f:GetChildren() do table.insert(list,o) end end
  end
 end
 local out={} local seen={}
 for _,o in list do if not seen[o] and (o:IsA("Model") or o:IsA("BasePart")) and o:IsDescendantOf(workspace) and rootOf(o,s.c) then seen[o]=true table.insert(out,o) end end
 table.sort(out,function(a,b) return a:GetFullName()<b:GetFullName() end) return out
end
local function limits(s,key,kind,overrides)
 local speed,radius=s.c.recordMaxSpeed,s.c.recordMaxRadius
 if s.c.legacyLimits and typeof(key)=="Instance" then
  local c=s.c local root=rootOf(key,c)
  speed=4096 radius=if c.positions=="Provider" then 512 else math.min(512,math.max(c.radius,c.height/2,Vector3.new(c.width,c.height,c.depth).Magnitude/2,if c.partBodies and root then root.Size.Magnitude/2 else 0)+0.001)
 end
 for _,row in s.c.kindLimits do if row.kind==kind then speed,radius=row.maxSpeed,row.maxRadius break end end
 if s.c.objectLimits and typeof(key)=="Instance" then speed=key:GetAttribute("ChronoMaxSpeed") or speed radius=key:GetAttribute("ChronoMaxRadius") or radius end
 if overrides then speed=overrides.maxSpeed or speed radius=overrides.maxRadius or radius end
 if s.hooks.RecordingLimits then speed,radius=invoke(s.hooks.RecordingLimits,key,speed,radius,s.c) end
 assert(Config.Number(speed,0,4096) and Config.Number(radius,0.001,512),"recording_limits_invalid") return speed,radius
end
local function remove(s,key)
 local rec=s.actors[key] if not rec then return false end
 for token,move in s.moves do if move.actor==key then finish(s,token) end end
 s.chrono:Untrack(rec.id) s.actors[key]=nil s.byId[rec.id]=nil s.keys[key]=nil s.generation+=1 s.needsCapture=true return true
end
local function register(s,key,kind,trust,speed,radius,extra)
 s.serial+=1
 local rec=extra or {} rec.id="actor-"..s.serial rec.key=key rec.kind=kind rec.maxSpeed=speed rec.maxRadius=radius rec.trust=trust
 s.chrono:Track(rec.id,{kind=kind,trust=trust,maxSpeed=speed,maxRadius=radius,capture=function(time) assert(rec.preparedAt==time,"No common update prepared") return rec.prepared end})
 s.actors[key]=rec s.byId[rec.id]=rec s.generation+=1 s.needsCapture=true return rec
end
local function sync(s,time)
 local objects=physical(s) local found={}
 for _,o in objects do found[o]=true end
 local data={}
 if s.registry then
  local supplied=invoke(s.hooks.DataSnapshots,s.registry,time)
  assert(type(supplied)=="table","Registry.Snapshots must return a dictionary keyed by short text ids")
  local count=0 for id,snapshot in supplied do
   count+=1 assert(count<=256 and Config.Name(id) and type(snapshot)=="table","data_registry_invalid")
   data[id]=snapshot
  end
 end
 for key,rec in s.actors do
  if (rec.source=="physical" and (not found[key] or rootOf(key,s.c)~=rec.root)) or (rec.source=="registry" and not data[key]) then remove(s,key) end
 end
 for _,o in objects do
  local root=rootOf(o,s.c) local kind=o:GetAttribute("ChronoKind") or s.c.kind
  local speed,radius=limits(s,o,kind)
  local rec=s.actors[o] local known,who=owner(root)
  if rec and (rec.kind~=kind or rec.maxSpeed~=speed or rec.maxRadius~=radius) then remove(s,o) rec=nil end
  if not rec then
   rec=register(s,o,kind,if s.c.positions=="ServerPhysics" then "serverSimulated" else "serverValidated",speed,radius,{source="physical",root=root,owner=who,ownerKnown=known})
   if s.c.positions=="Humanoid" and o:FindFirstChildOfClass("Humanoid") then rec.guard=Movement.New(o,root,time,s.c) end
  elseif known~=rec.ownerKnown or who~=rec.owner then rec.owner=who rec.ownerKnown=known reset(s,rec.id,"physics_owner_changed") end
 end
 for id,snapshot in data do
  local rec=s.actors[id] assert(not rec or rec.source=="registry","registry_id_conflicts_with_manual_track")
  local kind=snapshot.kind or s.c.kind local speed,radius=limits(s,id,kind,snapshot)
  if rec and (rec.kind~=kind or rec.maxSpeed~=speed or rec.maxRadius~=radius) then remove(s,id) rec=nil end
  if not rec then rec=register(s,id,kind,"serverValidated",speed,radius,{source="registry"}) end
  rec.nextSnapshot=snapshot
 end
 return objects
end
local function prepare(s,rec,time,objects)
 if rec.fault then return nil,rec.fault end
 if rec.source~="physical" then
  local snapshot=if rec.source=="registry" then rec.nextSnapshot else invoke(rec.capture,time)
  if type(snapshot)~="table" or snapshot.ok~=true then return nil,"provider_has_not_approved_position" end
  return {root=snapshot.root,zones=snapshot.zones,state=snapshot.state or {active=true}}
 end
 local o,root=rec.key,rec.root
 local frame=root.CFrame local state=invoke(s.hooks.State,o,root,s.c)
 local zones
 if s.c.positions=="ServerPhysics" then local known,who=owner(root) if not known or who~=nil then return nil,"client_owned_position_needs_checker" end
 elseif s.c.positions=="Humanoid" then
  if rec.guard then local reason,corrected frame,reason,corrected=Movement.Check(rec.guard,time,s.c,s.hooks,objects)
   if not frame then if corrected then s.stats.corrections+=1 invoke(s.hooks.AfterCorrection,o,reason) end return nil,reason end
  else local known,who=owner(root) if not known or who~=nil then return nil,"non_humanoid_needs_server_physics_or_provider" end end
 else
  local snapshot=invoke(s.hooks.ProviderSnapshot,s.provider,o,time)
  if type(snapshot)~="table" or snapshot.ok~=true then return nil,"provider_has_not_approved_position" end
  frame,zones,state=snapshot.root,snapshot.zones,snapshot.state or state
 end
 if not zones then
  if #s.c.zones>0 then zones=Volumes.Zones(Core.Shapes,s.c.zones,frame)
  elseif s.c.partBodies and not o:FindFirstChildOfClass("Humanoid") then
   local size=root.Size local sphere=root:IsA("Part") and root.Shape==Enum.PartType.Ball and math.abs(size.X-size.Y)<1e-5 and math.abs(size.X-size.Z)<1e-5
   zones={Body=if sphere then Core.Shapes.Sphere(frame,size.X/2) else Core.Shapes.Box(frame,size)}
  else zones={Body=if s.c.body=="Sphere" then Core.Shapes.Sphere(frame,s.c.radius) elseif s.c.body=="Capsule" then Core.Shapes.Capsule(frame,s.c.radius,s.c.height) else Core.Shapes.Box(frame,Vector3.new(s.c.width,s.c.height,s.c.depth))} end
 end
 return {root=frame,zones=zones,state=state}
end
capture=function(s,time,runAutomatic)
 if s.busy then return fail(s,"connection_reentry") end
 local read,clock=Contract.Call(now,s) if not read then return fail(s,"clock_fault") end time=time or clock
 if not Config.Number(time,-1e12,clock+1e-6) or clock-time>s.maxGap then return fail(s,"invalid_capture_time") end
 if s.time and time<=s.time then return fail(s,"non_monotonic") end
 s.busy=true s.phaseTime=time
 local ok,accepted,reason=pcall(function()
  local objects=sync(s,time) local blocked
  if s.c.worldMode=="StaticBoxes" then
   local record,why=World.Capture(s.worldRecord,link(s,"Obstacles"),time,s.c.maxObstacles,Core.Shapes)
   s.worldRecord=record s.worldFault=why
  end
  for _,rec in s.actors do
   local worked,snapshot,why=Contract.Call(prepare,s,rec,time,objects)
   if not worked then rec.fault="position_function_error" snapshot=nil why=rec.fault s.stats.errors+=1 end
   if not snapshot then if not rec.blocked then reset(s,rec.id,why) end rec.blocked=why blocked=blocked or why
   else if rec.blocked then reset(s,rec.id,"position_available_again") end rec.blocked=nil rec.prepared=snapshot rec.preparedAt=time end
  end
  if blocked then return nil,blocked end
  local result=s.chrono:Capture(time) s.time=time s.stats.captures+=1
  for token,move in s.moves do if time>move.expires then finish(s,token) end end
  if not result.ok then for _,fault in result.faults or {} do local r=s.byId[fault.id] if r then r.fault=fault.reason end end return nil,result.reason end
  s.needsCapture=false return true
 end)
 s.busy=false s.phaseTime=nil
 if not ok then s.stats.errors+=1 return fail(s,"capture_error: "..tostring(accepted)) end
 if not accepted then return fail(s,reason) end
 if runAutomatic then automatic(s) end
 if publish then publish(s) end return true
end
local function refresh(s)
 if s.busy then return nil,"connection_reentry" end
 if s.c.recording=="Heartbeat" then return capture(s,nil,false) end
 local read,t=Contract.Call(now,s) if not read then return nil,"clock_fault" end
 if not s.time then return nil,"capture_required" end
 if t<s.time-1e-6 then return nil,"clock_reversed" end
 if t-s.time>s.maxGap then return nil,"capture_stale" end return true
end
local function currentState(s,rec)
 if rec.source=="physical" then
  if not rec.key:IsDescendantOf(workspace) then return nil end
  return invoke(s.hooks.State,rec.key,rec.root,s.c)
 end
 return if rec.prepared then rec.prepared.state else nil
end
local function targetAllowed(s,move,target)
 local contact=move.allowed and move.allowed[target]
 if not contact or move.delivered[target] then return nil end
 local a,b=s.actors[move.actor],s.actors[target] if not a or not b then return nil end
 local x,y=currentState(s,a),currentState(s,b)
 if not x or not y or x.active~=true or y.active~=true then return nil end
 if invoke(s.hooks.CanApply,move.actor,target,move.name,move.context,contact)~=true then return nil end return contact
end
query=function(s,token,doRefresh)
 local move=token and s.moves[token] if not move then return fail(s,"move_missing_or_finished") end
 if move.checked and move.mode=="Once" then return fail(s,"move_already_checked") end
 if doRefresh then local ok,why=refresh(s) if not ok then finish(s,token) return fail(s,why) end end
 if s.moves[token]~=move then return fail(s,"move_expired") end
 local result=s.chrono:Query(move.handle) s.stats.queries+=1
 if not result.ok then
  if not table.find({"not_active","duplicate_query"},result.reason) then finish(s,token) end
  return fail(s,result.reason)
 end
 local out=table.clone(result) local contacts={}
 move.allowed={} move.checked=true move.generation=s.generation move.lastQuery=s.time
 for _,contact in result.contacts do
  local rec=s.byId[contact.id]
  if rec then local copy=table.clone(contact) copy.target=rec.key copy=table.freeze(copy) move.allowed[rec.key]=copy table.insert(contacts,copy) s.stats.contacts+=1 end
 end
 out.contacts=table.freeze(contacts) move.result=table.freeze(out) move.pendingCount=#contacts move.pending=#contacts>0
 s.stats.reason="contact_check_completed" return move.result
end
local function allows(s,token,target,doRefresh)
 local move=token and s.moves[token] if not move then return false,"move_missing_or_finished" end
 local fresh,why=true,nil
 if doRefresh then fresh,why=refresh(s) end
 if fresh and (not move.checked or (move.mode=="Repeated" and move.lastQuery~=s.time and not move.pending)) then local result,reason=query(s,token,false) if not result then return false,reason end end
 if not fresh or s.moves[token]~=move or move.generation~=s.generation then finish(s,token) return false,why or "contact_records_changed" end
 local read,t=Contract.Call(now,s) if not read then finish(s,token) return false,"clock_fault" end
 if t>move.result.capturedAt+s.maxGap then finish(s,token) return false,"contact_result_stale" end
 local ok,contact=Contract.Call(targetAllowed,s,move,target)
 if not ok then finish(s,token) return false,"outcome_rule_error" end
 if not contact then return false,"target_not_allowed_or_already_used" end
 move.delivered[target]=true move.pendingCount-=1 if move.pendingCount<=0 then move.pending=false end s.stats.applied+=1 return true,contact
end
resolve=function(s,token,doRefresh)
 local move=token and s.moves[token] if not move then return fail(s,"move_missing_or_finished") end
 local outcome=link(s,"Outcome")
 if not outcome and s.hooks.OnContact==nil then return fail(s,"choose_outcome_event_or_hook") end
 if move.resolved and move.mode=="Once" then return fail(s,"outcomes_already_resolved") end
 if doRefresh then local fresh,reason=refresh(s) if not fresh then finish(s,token) return fail(s,reason) end end
 local result,why
 if move.pending or (move.checked and move.mode=="Once" and not move.resolved) then result=move.result else result,why=query(s,token,false) end
 if not result then return nil,why end
 move.resolved=true
 -- Deterministic contact order is preserved; target keys may be Instances or data ids.
 for _,contact in result.contacts do
  local target=contact.target local allowed=allows(s,token,target,false)
  if allowed then
   local ok,err=Contract.Call(function()
    if outcome then invoke(s.hooks.ApplyOutcome,outcome,move.actor,target,move.name,move.context,contact) end
    if s.hooks.OnContact then invoke(s.hooks.OnContact,move.actor,target,move.name,move.context,contact) end
   end)
   if not ok then s.stats.errors+=1 s.stats.reason="outcome_mapping_error: "..tostring(err) end
  end
 end
 move.pending=false
 return result
end
automatic=function(s)
 if not s.c.autoQuery then return end
 local ready={}
 for token,move in s.moves do
  if s.time>=move.opens and s.time<=move.expires and (not move.checked or move.mode=="Repeated") and (not move.lastQuery or s.time-move.lastQuery>=s.c.queryInterval-1e-6) then table.insert(ready,token) end
 end
 for _,token in ready do local move=s.moves[token] if move then local result=resolve(s,token,false) if result and move.mode=="Once" then finish(s,token) end end end
end
publish=function(s)
 if not s.report or os.clock()-s.published<0.5 then return end s.published=os.clock()
 local count=0 local paused={}
 for key,rec in s.actors do count+=1 if rec.blocked or rec.fault then table.insert(paused,{object=if typeof(key)=="Instance" then key.Name else key,reason=rec.fault or rec.blocked}) end end
 s.report.Value=game.HttpService:JSONEncode({version=Config.Version,connectionBuild=Config.Build,actors=count,positions=s.c.positions,stats=s.stats,paused=paused,core=s.chrono:Inspect().stats,explanation=Messages.Explain(s.stats.reason) or Core.Explain(s.stats.reason),
  timing=s.c.timing,rewind=s.lastRewind or 0,maxRewind=s.c.maxRewind,recording=s.c.recording,queryMode=s.c.queryMode,world=s.c.worldMode,worldFault=s.worldFault,
  outcomeLinked=link(s,"Outcome")~=nil,attackEventLinked=link(s,"Begin")~=nil})
 Root:SetAttribute("ConnectionActors",count) Root:SetAttribute("ConnectionReason",s.stats.reason)
 Root:SetAttribute("ConnectionBegun",s.stats.begun) Root:SetAttribute("ConnectionQueries",s.stats.queries)
end
function R.Start()
 assert(hookDepth==0,"Do not start Connector from a provider or rule function")
 if live then return true end
 assert(game:GetService("RunService"):IsServer(),"Use Chrono connections from server scripts")
 local base=require(Root.Settings)
 local c=Config.Normalize(require(Root.Connections),base)
 local custom=require(Root.Hooks) local defaults=require(script:FindFirstChild("DefaultHooks") or script.Hooks)
 local hooks=setmetatable({},{__index=function(_,key) local value=custom[key] return if value~=nil then value else defaults[key] end})
 local links={} for _,v in Root.ConnectionLinks:GetChildren() do if v:IsA("ObjectValue") then links[v.Name]=v.Value end end
 local valid,why=Config.Validate(c,links) assert(valid,why)
 local s={c=c,hooks=hooks,links=Root.ConnectionLinks,actors={},byId={},moves={},keys={},serial=0,connections={},generation=0,published=-math.huge,maxGap=c.maxGap,
  stats={captures=0,begun=0,queries=0,contacts=0,applied=0,refused=0,cancelled=0,corrections=0,errors=0,reason="starting"}}
 s.provider=if c.positions=="Provider" then module(s,"Provider") else nil
 s.registry=if c.actors=="Data" or c.actors=="PlayersAndData" then module(s,"Registry") else nil
 s.clockProvider=module(s,"Clock") s.timingProvider=if c.timing=="Provider" then module(s,"Timing") else nil s.worldProvider=if c.worldMode=="Provider" then module(s,"World") else nil
 local options=table.clone(base)
 options.seconds=c.historySeconds options.rate=c.recordRate options.maxGap=c.maxGap options.maxRewind=c.maxRewind
 options.clock=function() return s.phaseTime or now(s) end
 options.resolveRewind=function(id,context,time)
  local rec=s.byId[id] local delay
  if c.timing=="Present" then delay=0
  elseif c.timing=="MeasuredPing" then
   local player=if hooks.TimingPlayer then invoke(hooks.TimingPlayer,rec.key,context) elseif typeof(rec.key)=="Instance" and rec.key:IsA("Model") then game.Players:GetPlayerFromCharacter(rec.key) else nil
   assert(typeof(player)=="Instance" and player:IsA("Player") and player.Parent==game.Players,"timing_player_required")
   -- Current Roblox API defines GetNetworkPing as RTT. Half is only an estimate of one-way delay.
   delay=player:GetNetworkPing()/2+c.displayDelay
  else delay=invoke(hooks.ResolveRewind,s.timingProvider,rec.key,context,time,c.maxRewind) end
  assert(Config.Number(delay,0,c.maxRewind),"rewind_rejected")
  s.lastRewind=delay return delay
 end
 options.world=if c.worldMode=="None" then nil else function(time,current,shape)
  if c.worldMode=="StaticBoxes" then return World.Check(s.worldRecord,time,shape,Core.Shapes) end
  return invoke(hooks.WorldCheck,s.worldProvider,time,current,shape)
 end
 s.chrono=Core.new(options)
 s.actions=if c.moveSource=="Builder" then Volumes.Actions(Core.Shapes,c.moves,hooks) else require(Root.Actions)
 local wrapped={} for name,profile in s.actions do
  local copy=table.clone(profile) if copy.eligible then local rule=copy.eligible copy.eligible=function(...) return invoke(rule,...) end end wrapped[name]=copy
 end s.actions=wrapped
 live=s
 if game:GetService("RunService"):IsStudio() then
  local reports=game.ReplicatedStorage:FindFirstChild("_ChronoConnectionReports")
  if not reports then reports=Instance.new("Folder") reports.Name="_ChronoConnectionReports" reports.Parent=game.ReplicatedStorage end
  if reports:FindFirstChild(Root.Name) then live=nil s.chrono:Destroy() error("Second connection instance: require the same Connector from ordinary server scripts") end
  s.report=Instance.new("StringValue") s.report.Name=Root.Name s.report.Parent=reports
 end
 local function safe(fn,...)
  local ok,err=pcall(fn,...) if not ok then s.stats.errors+=1 s.stats.reason="connection_error: "..tostring(err) warn(s.stats.reason) end
 end
 for name,callback in {
  Begin=function(...) local actor,action,key,context=invoke(hooks.ReadBegin,...) R.Begin(actor,action,context,key or action or "Contact") end,
  Query=function(...) local actor,key=invoke(hooks.ReadQuery,...) local token=s.keys[actor] and s.keys[actor][key or "Contact"] if token then local move=s.moves[token] R.Resolve(token) if move and move.mode=="Once" then R.Finish(token) end else fail(s,"move_missing") end end,
  Cancel=function(...) local actor,key=invoke(hooks.ReadCancel,...) local token=s.keys[actor] and s.keys[actor][key or "Contact"] if token then R.Cancel(token) end end,
 } do local event=link(s,name) if event then table.insert(s.connections,event.Event:Connect(function(...) safe(callback,...) end)) end end
 if c.recording=="Event" then table.insert(s.connections,link(s,"Capture").Event:Connect(function(time) safe(R.Capture,time) end)) end
 table.insert(s.connections,game:GetService("RunService").Heartbeat:Connect(function()
  safe(function()
   if c.recording=="Heartbeat" then local t=now(s) if not s.time or t-s.time>=1/c.recordRate-1e-6 then capture(s,nil,true) end end
   publish(s)
  end)
 end))
 if c.recording=="Heartbeat" then local ok,reason=capture(s,nil,false) s.stats.reason=if ok then "ready_for_moves" else reason else s.stats.reason="waiting_for_capture" end
 publish(s) return true
end
local function session(allowHook) assert(allowHook or hookDepth==0,"Do not call Connector again from a provider or rule function") if not live then R.Start() end return live end
function R.Capture(time) return capture(session(),time,true) end
function R.Track(id,binding)
 local s=session() assert(not s.busy,"connection_reentry")
 assert(Config.Name(id) and not s.actors[id] and type(binding)=="table" and type(binding.capture)=="function","Track needs an unused text id and capture function")
 local kind=binding.kind or s.c.kind local speed,radius=limits(s,id,kind,binding)
 register(s,id,kind,binding.trust or "unverified",speed,radius,{source="manual",capture=binding.capture})
 return id
end
function R.Untrack(id) local s=session() assert(not s.busy,"connection_reentry") return remove(s,id) end
function R.Discontinuity(actor,reason)
 local s=session() assert(not s.busy,"connection_reentry") local rec=assert(s.actors[actor],"Object is not connected")
 reset(s,rec.id,reason or "approved_reset") rec.fault=nil rec.blocked=nil
 for token,move in s.moves do if move.actor==actor then finish(s,token) end end return true
end
function R.Begin(actor,name,context,key)
 local s=session() name=name or "Contact"
 local profile=s.actions[name] if not profile then return fail(s,"move_settings_missing") end
 if key~=nil and (type(key)~="string" or #key>64) then return fail(s,"move_key_invalid") end
 if key~=nil and s.keys[actor] and s.keys[actor][key] then return fail(s,"move_key_already_active") end
 local ok,why=refresh(s) if not ok then return fail(s,why) end
 local rec=s.actors[actor] if not rec then return fail(s,"actor_not_connected") end
 local mode=profile.queryMode or s.c.queryMode if mode~="Once" and mode~="Repeated" then return fail(s,"invalid_query_mode") end
 local permitted,value=Contract.Call(invoke,s.hooks.CanStart,actor,name,context,rec.prepared.state)
 if not permitted or value~=true then return fail(s,"move_not_allowed") end
 local handle,reason=s.chrono:BeginAction(rec.id,profile,context) if not handle then return fail(s,reason) end
 local token=table.freeze({}) s.moves[token]={actor=actor,name=name,context=context,handle=handle,key=key,opens=s.time+(profile.opens or 0),expires=s.time+(profile.closes or 0.25),delivered={},mode=profile.queryMode or s.c.queryMode}
 if key~=nil then s.keys[actor]=s.keys[actor] or {} s.keys[actor][key]=token end
 s.stats.begun+=1 s.stats.reason="move_started" return token
end
function R.Query(token) return query(session(),token,true) end
function R.Allows(token,target) return allows(session(),token,target,true) end
function R.Resolve(token) return resolve(session(),token,true) end
function R.Cancel(token) local s=session() if finish(s,token) then s.stats.cancelled+=1 return true end return false end
function R.Finish(token) return finish(session(),token) end
function R.AllowMotion(actor,velocity,seconds)
 local s=session(true) local rec=s.actors[actor]
 if not rec then assert(not s.busy,"Object is not connected") sync(s,now(s)) rec=s.actors[actor] end
 assert(rec and rec.guard,"Motion permission needs the supplied humanoid checker") Movement.Allow(rec.guard,velocity,seconds,now(s))
end
function R.Teleport(actor,frame)
 local s=session() assert(not s.busy,"connection_reentry") local rec=s.actors[actor]
 if not rec then sync(s,now(s)) rec=s.actors[actor] end
 assert(rec and rec.source=="physical","For data-only objects, update server data then call Discontinuity") assert(typeof(frame)=="CFrame","Teleport needs a CFrame")
 if rec.guard then Movement.Reset(rec.guard,frame,now(s),s.c) elseif actor:IsA("Model") then actor:PivotTo(frame*rec.root.CFrame:Inverse()*actor:GetPivot()) else actor.CFrame=frame end
 return R.Discontinuity(actor,"approved_teleport")
end
function R.Resume(actor) return R.Discontinuity(actor,"provider_fixed_by_server") end
function R.Inspect()
 local s=session() local count=0 local limitsList={}
 for key,rec in s.actors do count+=1 table.insert(limitsList,{object=if typeof(key)=="Instance" then key:GetFullName() else key,kind=rec.kind,maxSpeed=rec.maxSpeed,maxRadius=rec.maxRadius,source=rec.source}) end
 return {version=Config.Version,stats=table.clone(s.stats),actors=count,core=s.chrono:Inspect(),positions=s.c.positions,configuration=Config.Copy(s.c),limits=limitsList}
end
function R.Explain(reason) return Messages.Explain(reason) or Core.Explain(reason) end
function R.Destroy()
 local s=live if not s then return end assert(not s.busy and hookDepth==0,"connection_reentry")
 for _,c in s.connections do c:Disconnect() end s.chrono:Destroy() if s.report then s.report:Destroy() end live=nil
end
return R

