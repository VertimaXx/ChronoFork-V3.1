-- Run by an ordinary server Script, never from the MCP require cache.
-- Tests the real Connector against unchanged Core using deterministic server data.
return function(template)
 local Config=require(template.Connector.Configuration)
 local rows={} local serial=0 local clean={}
 local function check(name,fn)
  local ok,why=pcall(fn) table.insert(rows,{name=name,passed=ok,error=if ok then nil else tostring(why)})
 end
 local function make(changes,hookChange)
  serial+=1 local g=template:Clone() g.Name="__ChronoExpansion"..serial g.Parent=game.ServerScriptService table.insert(clean,g)
  local c=require(g.Connections) for k,v in changes or {} do c[k]=Config.Copy(v) end
  local clock=require(g.ClockProvider) clock.time=10
  if hookChange then hookChange(require(g.Hooks),g) end
  local R=require(g.Connector) R.Start()
  return R,clock,g,c
 end
 local function pair(R,clock,a,b,trust)
  local data={a=a or CFrame.new(),b=b or CFrame.new(0,0,-4),activeA=true,activeB=true}
  for _,id in {"a","b"} do
   R.Track(id,{kind="actor",trust=trust or "serverSimulated",capture=function()
    local f=data[id] return {ok=true,root=f,zones={Body=require(template.Core).Shapes.Sphere(f,1)},state={active=if id=="a" then data.activeA else data.activeB,team=if id=="a" then 1 else 2}}
   end})
  end
  if R.Inspect().core.time==clock.time then clock.time+=0.02 end
  assert(R.Capture(clock.time)) return data
 end
 local function step(R,clock,dt) clock.time+=dt or 0.02 local ok,why=R.Capture(clock.time) assert(ok,why) end
 local function contact(R,move,n) local result,why=R.Query(move) assert(result,why) assert(#result.contacts==n,"expected "..n.." contacts, got "..#result.contacts) return result end
 local function move(changes) local v=Config.Move("Contact") v.opens=0 v.closes=1 v.maxTargets=8 for k,x in changes or {} do v[k]=x end return {v} end
 check("manual recording does not happen at startup or Begin",function()
  local R=make() assert(R.Inspect().stats.captures==0) local token,why=R.Begin("a") assert(not token and why=="capture_required") R.Destroy()
 end)
 check("data-only objects need no Parts",function()
  local R,t=make() pair(R,t) assert(R.Inspect().actors==2) contact(R,assert(R.Begin("a")),1) R.Destroy()
 end)
 check("unverified data refuses decisions",function()
  local R,t=make() pair(R,t,nil,nil,"unverified") local token,why=R.Begin("a") assert(not token and why=="unverified_source") R.Destroy()
 end)
 check("Once is still default and duplicate query refuses",function()
  local R,t=make() pair(R,t) local m=assert(R.Begin("a")) contact(R,m,1) step(R,t) local result,why=R.Query(m) assert(not result and why=="move_already_checked") R.Destroy()
 end)
 check("Query then Resolve delivers the cached contacts once",function()
  local applied=0 local R,t=make(nil,function(H) H.OnContact=function() applied+=1 end end)
  pair(R,t) local m=assert(R.Begin("a")) contact(R,m,1) step(R,t) assert(R.Resolve(m)) assert(applied==1) assert(not R.Resolve(m)) R.Destroy()
 end)
 check("repeated miss becomes a later hit, never duplicated",function()
  local R,t=make({queryMode="Repeated"}) local d=pair(R,t,nil,CFrame.new(20,0,-4))
  local m=assert(R.Begin("a")) contact(R,m,0) d.b=CFrame.new(0,0,-4) step(R,t,0.05) contact(R,m,1)
  assert(R.Allows(m,"b")) assert(not R.Allows(m,"b")) step(R,t) contact(R,m,0) R.Destroy()
 end)
 check("Repeated Allows refreshes after a missed update",function()
  local R,t=make({queryMode="Repeated"}) local d=pair(R,t,nil,CFrame.new(20,0,-4))
  local m=assert(R.Begin("a")) assert(not R.Allows(m,"b")) d.b=CFrame.new(0,0,-4) step(R,t,0.05) assert(R.Allows(m,"b")) R.Destroy()
 end)
 check("repeated Query contacts remain deliverable after a newer capture",function()
  local R,t=make({queryMode="Repeated"}) pair(R,t) local m=assert(R.Begin("a")) contact(R,m,1) step(R,t) assert(R.Allows(m,"b")) R.Destroy()
 end)
 check("same recorded instant refuses duplicate, keeps repeated move",function()
  local R,t=make({queryMode="Repeated"}) pair(R,t,nil,CFrame.new(20,0,-4)) local m=assert(R.Begin("a"))
  contact(R,m,0) local result,why=R.Query(m) assert(not result and why=="duplicate_query") step(R,t) contact(R,m,0) R.Destroy()
 end)
 check("total target cap is shared across repeated checks",function()
  local R,t=make({queryMode="Repeated",moves=move({maxTargets=1})}) local d=pair(R,t)
  R.Track("c",{kind="actor",trust="serverSimulated",capture=function() local f=CFrame.new(0,0,-4) return {ok=true,root=f,zones={Body=require(template.Core).Shapes.Sphere(f,1)},state={active=true}} end})
  step(R,t) local m=assert(R.Begin("a")) contact(R,m,1) step(R,t) local result,why=R.Query(m) assert(not result and why=="action_spent") R.Destroy()
 end)
 for _,kind in {"Cancel","Finish","Discontinuity"} do check(kind.." ends or invalidates a move",function()
  local R,t=make({queryMode="Repeated"}) pair(R,t) local m=assert(R.Begin("a"))
  if kind=="Discontinuity" then R.Discontinuity("a","approved_test") else R[kind](m) end
  assert(not R.Query(m)) R.Destroy()
 end) end
 check("target discontinuity invalidates saved outcome",function()
  local R,t=make() pair(R,t) local m=assert(R.Begin("a")) contact(R,m,1) R.Discontinuity("b","teleport") assert(not R.Allows(m,"b")) R.Destroy()
 end)
 check("current inactive state blocks a historical contact outcome",function()
  local R,t=make() local d=pair(R,t) local m=assert(R.Begin("a")) contact(R,m,1) d.activeB=false step(R,t)
  assert(not R.Allows(m,"b")) R.Destroy()
 end)
 for _,case in {{"future",1},{"backward",-0.1},{"same",0}} do check("capture timestamp rejects "..case[1],function()
  local R,t=make() pair(R,t) assert(not R.Capture(t.time+case[2])) R.Destroy()
 end) end
 check("manual recording refuses stale evidence",function()
  local R,t=make() pair(R,t) t.time+=0.3 local m,why=R.Begin("a") assert(not m and why=="capture_stale") R.Destroy()
 end)
 for _,fault in {"nonfinite","yield"} do check("shared clock "..fault.." refuses safely",function()
  local R,t=make() pair(R,t)
  if fault=="nonfinite" then t.Now=function() return 0/0 end else t.Now=function() task.wait() return 10 end end
  local ok,why=R.Capture() assert(not ok and why=="clock_fault")
  local token,reason=R.Begin("a") assert(not token and reason=="clock_fault") R.Destroy()
 end) end
 check("record timestamps may follow a fixed-step server clock",function()
  local R,t=make() pair(R,t) t.time=10.1 assert(R.Capture(10.08)) assert(R.Inspect().core.time==10.08) R.Destroy()
 end)
 check("begin and query do not add manual captures",function()
  local R,t=make() pair(R,t) local count=R.Inspect().stats.captures contact(R,assert(R.Begin("a")),1) assert(R.Inspect().stats.captures==count) R.Destroy()
 end)
 for _,delay in {0,0.025,0.05,0.075,0.1} do check("provider lookback "..delay.." uses earlier positions",function()
  local R,t,g=make({timing="Provider",maxRewind=0.15,candidates="Chrono"})
  local d=pair(R,t,nil,CFrame.new(0,0,-4)) d.b=CFrame.new(20,0,-4) step(R,t,0.1)
  require(g.TimingProvider).delay=delay local m=assert(R.Begin("a"))
  local result=contact(R,m,if delay>=0.1 then 1 else 0)
  assert(math.abs(result.rewind-delay)<1e-8 and math.abs(result.time-(t.time-delay))<1e-8) R.Destroy()
 end) end
 for _,delay in {-0.01,0/0,0.3,math.huge} do check("invalid approved lookback refuses "..tostring(delay),function()
  local R,t,g=make({timing="Provider",maxRewind=0.15,candidates="Chrono"}) pair(R,t) require(g.TimingProvider).delay=delay
  local m,why=R.Begin("a") assert(not m and why=="rewind_rejected") R.Destroy()
 end) end
 check("larger maximum alone keeps present checks",function()
  local R,t=make({maxRewind=0.15}) pair(R,t) local r=contact(R,assert(R.Begin("a")),1) assert(r.rewind==0) R.Destroy()
 end)
 check("missing history refuses rather than substituting present",function()
  local R,t,g=make({timing="Provider",maxRewind=0.15,candidates="Chrono"}) pair(R,t) require(g.TimingProvider).delay=0.1
  local m,why=R.Begin("a") assert(not m and why:find("source_",1,true)) R.Destroy()
 end)
 check("lookback stays fixed for the move",function()
  local R,t,g=make({timing="Provider",maxRewind=0.15,candidates="Chrono",queryMode="Repeated"})
  pair(R,t) step(R,t,0.1) require(g.TimingProvider).delay=0.05 local m=assert(R.Begin("a")) require(g.TimingProvider).delay=0
  local r=contact(R,m,1) assert(r.rewind==0.05) R.Destroy()
 end)
 check("per-kind recording bounds are applied",function()
  local R,t=make({kindLimits={{kind="actor",maxSpeed=2,maxRadius=4}}}) local d=pair(R,t)
  local bounds=R.Inspect().limits assert(bounds[1].maxSpeed==2 and bounds[1].maxRadius==4)
  d.b=CFrame.new(10,0,-4) t.time+=0.02 assert(not R.Capture()) local token=R.Begin("a") if token then assert(not R.Query(token)) end R.Destroy()
 end)
 check("manual binding overrides recording limits",function()
  local R,t=make() local S=require(template.Core).Shapes
  R.Track("a",{kind="actor",trust="serverSimulated",maxSpeed=3,maxRadius=2,capture=function() return {ok=true,root=CFrame.new(),zones={Body=S.Sphere(CFrame.new(),1)},state={active=true}} end})
  assert(R.Capture()) assert(R.Inspect().limits[1].maxSpeed==3) R.Destroy()
 end)
 check("untrack updates roster and old actions refuse",function()
  local R,t=make() pair(R,t) local m=assert(R.Begin("a")) assert(R.Untrack("b")) assert(not R.Query(m)) R.Destroy()
 end)
 check("custom rule and outcome errors refuse or contain failures",function()
  local R,t=make(nil,function(H) H.CanApply=function() error("deliberate") end end)
  pair(R,t) local m=assert(R.Begin("a")) contact(R,m,1) local ok,why=R.Allows(m,"b") assert(not ok and why=="outcome_rule_error") R.Destroy()
 end)
 check("yielding position callback is quarantined",function()
  local R=make() R.Track("a",{kind="actor",trust="serverSimulated",capture=function() task.wait() return {} end})
  assert(not R.Capture()) assert(R.Inspect().stats.errors>0) R.Destroy()
 end)
 check("callback cannot destroy or reenter Connector",function()
  local RR local R,t=make(nil,function(H) H.CanStart=function() RR.Destroy() return true end end) RR=R pair(R,t)
  local m,why=R.Begin("a") assert(not m and why=="move_not_allowed") assert(R.Inspect().actors==2) R.Destroy()
 end)
 check("automatic repeated timing delivers a later entering target",function()
  local applied=0 local R,t,g=make({autoQuery=true,queryMode="Repeated"},function(H) H.OnContact=function() applied+=1 end end)
  local d=pair(R,t,nil,CFrame.new(20,0,-4)) local m=assert(R.Begin("a"))
  step(R,t) assert(applied==0) d.b=CFrame.new(0,0,-4) step(R,t,0.05) assert(applied==1) step(R,t) assert(applied==1) R.Cancel(m) R.Destroy()
 end)
 check("recording event uses the supplied exact simulation timestamp",function()
  local R,t,g=make({recording="Event"}) pair(R,t) t.time+=0.02
  g.ConnectionLinks.Capture.Value:Fire(t.time) task.wait() assert(R.Inspect().core.time==t.time) R.Destroy()
 end)
 check("registry adds, updates and removes pure-data objects",function()
  local R,t,g=make({actors="Data"})
  -- The template registry is linked only when requested; its data is server-owned.
  R.Destroy() local cfg=require(g.Connections) g.ConnectionLinks.Registry.Value=g.RegistryProvider
  local reg=require(g.RegistryProvider) local S=require(g.Core).Shapes
  local function snap(f) return {ok=true,kind="actor",root=f,zones={Body=S.Sphere(f,1)},state={active=true}} end
  reg.objects={a=snap(CFrame.new()),b=snap(CFrame.new(0,0,-4))}
  R.Start() assert(R.Capture()) assert(R.Inspect().actors==2) contact(R,assert(R.Begin("a")),1)
  reg.objects.b=nil step(R,t) assert(R.Inspect().actors==1) R.Destroy()
 end)
 check("measured player ping policy runs through the server API",function()
  local player=game.Players:GetPlayers()[1] assert(player,"Run with one Studio player")
  local R,t=make({timing="MeasuredPing",maxRewind=0.15,candidates="Chrono"},function(H) H.TimingPlayer=function() return player end end)
  pair(R,t) step(R,t,0.1) local m,why=R.Begin("a") assert(m,why)
  local r=R.Query(m) assert(r and r.rewind>=0 and r.rewind<=0.15) R.Destroy()
 end)

 check("per-move Repeated overrides the default Once mode",function()
  local R,t=make({moves=move({queryMode="Repeated"})}) pair(R,t,nil,CFrame.new(20,0,-4))
  local m=assert(R.Begin("a")) contact(R,m,0) step(R,t) contact(R,m,0) R.Destroy()
 end)
 check("Heartbeat refreshes provider evidence on accepted-move calls",function()
  local R,t=make({recording="Heartbeat"}) pair(R,t) local before=R.Inspect().stats.captures
  t.time+=0.01 local m=assert(R.Begin("a")) t.time+=0.01 contact(R,m,1) assert(R.Inspect().stats.captures>before) R.Destroy()
 end)
 local function folder(g,name)
  local f=Instance.new("Folder") f.Name=g.Name..name f.Parent=workspace table.insert(clean,f) return f
 end
 local function wall(g,frame,size)
  local f=folder(g,"Obstacles") local p=Instance.new("Part") p.Name="Block" p.Size=size or Vector3.new(20,20,1)
  p.CFrame=frame or CFrame.new(0,0,-3) p.Anchored=true p.Parent=f g.ConnectionLinks.Obstacles.Value=f return p
 end
 for _,mode in {"clear","blocked","initial overlap","exact cover tie","changed past","unanchored","oversized","removed past"} do
 check("static obstacle policy: "..mode,function()
  local p local profile=move({shape="Ray",z=0,length=10,world=true})
  local R,t,g=make({worldMode="StaticBoxes",moves=profile,timing=if mode:find("past") then "Provider" else "Present",maxRewind=0.15,candidates="Chrono"},function(H,g)
   p=wall(g,if mode=="initial overlap" then CFrame.new() elseif mode=="exact cover tie" then CFrame.new(0,0,-5.5) else CFrame.new(0,0,-3))
   if mode=="clear" then p.CFrame=CFrame.new(50,0,0) end
   if mode=="unanchored" then p.Anchored=false end
   if mode=="oversized" then p.Size=Vector3.new(600,1,1) end
  end)
  pair(R,t,nil,CFrame.new(0,0,-6))
  if mode:find("past") then step(R,t,0.1) require(g.TimingProvider).delay=0.05
   if mode=="changed past" then p.CFrame=CFrame.new(50,0,0) else p:Destroy() end step(R,t,0.02)
  end
  local m=assert(R.Begin("a")) local result,why=R.Query(m)
  if mode:find("past") or mode=="unanchored" or mode=="oversized" then assert(not result and why=="world_unknown",tostring(why))
  else assert(result and #result.contacts==(if mode=="clear" then 1 else 0)) end
  R.Destroy()
 end) end
 for _,cover in {{covered=false},{covered=true,blocked=false,fraction=2},{covered=true,blocked=true,fraction=0.2},{covered=true,blocked=false,fraction=1}} do
 check("custom obstacle provider "..game.HttpService:JSONEncode(cover),function()
  local R,t,g=make({worldMode="Provider",moves=move({shape="Ray",z=0,length=10,world=true})})
  pair(R,t,nil,CFrame.new(0,0,-6)) require(g.WorldProvider).value=cover
  local m=assert(R.Begin("a")) local result,why=R.Query(m)
  if cover.covered~=true or cover.fraction>1 then assert(not result and why=="world_unknown")
  else assert(result and #result.contacts==(if cover.blocked then 0 else 1)) end R.Destroy()
 end) end
 check("several target areas return the correct named area",function()
  local head=Config.Volume("Head") head.shape="Sphere" head.radius=1 head.y=3
  local body=Config.Volume("Body") body.width=1 body.height=1 body.depth=1
  local source,target
  local R,t=make({actors="Folder",zones={body,head},moves=move({shape="Ray",z=0,y=3,length=10})},function(H,g)
   local f=folder(g,"Actors") g.ConnectionLinks.Actors.Value=f
   for _,id in {"Source","Target"} do local m=Instance.new("Model") m.Name=id local p=Instance.new("Part") p.Name="HumanoidRootPart" p.Anchored=true
    p.Size=Vector3.one p.CFrame=CFrame.new(1000,20,if id=="Target" then -4 else 0) p.Parent=m m.PrimaryPart=p m.Parent=f
    if id=="Source" then source=m else target=m end
   end
  end)
  assert(R.Capture()) local result=contact(R,assert(R.Begin(source)),1) assert(result.contacts[1].target==target and result.contacts[1].zone=="Head") R.Destroy()
 end)
 check("physical per-object attribute bounds override defaults",function()
  local object local R=make({actors="Folder"},function(H,g)
   local f=folder(g,"Actors") local p=Instance.new("Part") p.Name="ServerObject" p.Anchored=true p.CFrame=CFrame.new(2000,20,0) p.Size=Vector3.one
   p:SetAttribute("ChronoMaxSpeed",12) p:SetAttribute("ChronoMaxRadius",8) p.Parent=f object=p g.ConnectionLinks.Actors.Value=f
  end)
  assert(R.Capture()) local row=R.Inspect().limits[1] assert(row.maxSpeed==12 and row.maxRadius==8) R.Destroy()
 end)
 check("manual recording makes a known capture gap refuse rewind",function()
  local R,t,g=make({timing="Provider",maxRewind=0.3,candidates="Chrono",maxGap=0.05})
  pair(R,t) step(R,t,0.1) require(g.TimingProvider).delay=0.05
  local m,why=R.Begin("a") assert(not m and why=="source_sample_gap",tostring(why)) R.Destroy()
 end)

 -- Differential wiring campaign. Same snapshots, timestamps, policy and profiles in both paths.
 local random=Random.new(32025) local S=require(template.Core).Shapes local Native=require(template.Core)
 for i=1,160 do check("Core parity randomized scenario "..i,function()
  local shape=({"Box","Sphere","Capsule","Ray","SweptSphere"})[(i-1)%5+1]
  local v=Config.Move("Contact") v.shape=shape v.opens=0 v.closes=1 v.maxTargets=8 v.z=if shape=="Ray" or shape=="SweptSphere" then 0 else -3
  v.length=8 v.radius=1 v.height=4 v.width=5 v.depth=5 v.yaw=random:NextNumber(-90,90) v.x=random:NextNumber(-2,2)
  local rewind=({0,0.025,0.05,0.075})[(i-1)%4+1]
  local R,t,g=make({moves={v},timing="Provider",maxRewind=0.15,candidates="Chrono"})
  local a=CFrame.Angles(0,random:NextNumber(-math.pi,math.pi),0)
  local b=CFrame.new(random:NextNumber(-6,6),random:NextNumber(-2,2),random:NextNumber(-8,2))
  local d=pair(R,t,a,b)
  local native=Native.new({clock=function() return t.time end,seconds=0.6,rate=60,maxGap=0.2,maxRewind=0.15,resolveRewind=function() return rewind end})
  for _,id in {"a","b"} do native:Track(id,{kind="actor",trust="serverSimulated",maxSpeed=1000,maxRadius=16,capture=function() local f=d[id] return {root=f,zones={Body=S.Sphere(f,1)},state={active=true,team=if id=="a" then 1 else 2}} end}) end
  assert(native:Capture(t.time).ok)
  d.b=b+Vector3.new(random:NextNumber(-5,5),0,random:NextNumber(-5,5)) step(R,t,0.1) assert(native:Capture(t.time).ok)
  require(g.TimingProvider).delay=rewind local m=assert(R.Begin("a"))
  local profile=require(g.Connector.Volumes).Actions(S,{v},require(g.Hooks)).Contact
  local n=assert(native:BeginAction("a",profile)) local actual=assert(R.Query(m)) local expected=native:Query(n)
  assert(expected.ok and #actual.contacts==#expected.contacts)
  assert(math.abs(actual.time-expected.time)<1e-8)
  for j,x in actual.contacts do local y=expected.contacts[j] assert(x.target==y.id and x.zone==y.zone and math.abs(x.fraction-y.fraction)<1e-7) end
  R.Destroy() native:Destroy()
 end) end
 for _,g in clean do pcall(function() require(g.Connector).Destroy() end) g:Destroy() end
 local passed=0 for _,r in rows do if r.passed then passed+=1 end end
 return {version=Config.Version,run=#rows,passed=passed,failed=#rows-passed,cases=rows,scope="Server Connector integration and 160 Core differential wiring cases; not a network or movement-security certification."}
end




