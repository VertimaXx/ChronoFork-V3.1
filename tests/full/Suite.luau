-- Run in a disposable Play session. Counts distinguish cases from assertions.
local Suite={}
function Suite.Run(fixture)
	local root=fixture.ChronoFork local RS=root.Replication.Shared
	local F=require(root) local S=F.Shapes local C=F.Competitive
	local Protocol=require(RS.Protocol) local Sequence=require(RS.Sequence)
	local Gate=require(RS.StateGate) local Budget=require(RS.RateBudget)
	local Visual=require(RS.VisualSampling) local Ticker=require(RS.Ticker)
	local Config=require(RS.Config) Config.SetConfig("PLAYER_REPLICATION","CUSTOM") Config.SetConfig("WARNING_SEVERITY","NONE") Config._Lock()
	local Snapshot=require(RS.Snapshots) local Hermite=require(RS.InterpolationMath).Hermite
	local OldHermite=require(fixture.Original.Shared.InterpolationMath).Hermite
	local ViewerIndex=require(RS.ViewerIndex)
	local result={cases=0,assertions=0,passed=0,failures={},seed=20261027,findings={}}
	local random=Random.new(result.seed)
	local function check(v,message) result.assertions+=1 assert(v,message or "check failed") end
	local function near(a,b,e) check(math.abs(a-b)<=(e or 1e-6),`{a} differs from {b}`) end
	local function case(name,callback)
		result.cases+=1 local ok,why=pcall(callback)
		if ok then result.passed+=1 else table.insert(result.failures,{name=name,error=tostring(why)}) end
		if result.cases%100==0 then task.wait() end
	end
	local function vec(scale) return Vector3.new(random:NextNumber(-scale,scale),random:NextNumber(-scale,scale),random:NextNumber(-scale,scale)) end
	local function entity(id,seq) return {id=id or 1,generation=7,ownershipRevision=3,_sendSequence=seq or 0} end
	local function clone(b,size) local out=buffer.create(size or buffer.len(b)) buffer.copy(out,0,b,0,math.min(buffer.len(b),buffer.len(out))) return out end
	case("modular sequence boundaries",function()
		check(Sequence.Newer(0,4294967295)) check(not Sequence.Newer(4294967295,0))
		check(not Sequence.Newer(4,4)) check(not Sequence.Newer(2147483648,0))
		check(not Sequence.Newer(0/0,3)) check(Sequence.Next(4294967295)==0)
	end)
	case("lifetime, owner and teleport revisions",function()
		local owner={} local e={generation=8,ownershipRevision=4,_receivedSequence=10,networkOwner=owner}
		local row={generation=8,ownershipRevision=4,sequence=11}
		check(Gate.Check(e,row,owner)) check(not Gate.Check(e,row,{}))
		row.generation=7 check(not Gate.Check(e,row,owner)) row.generation=8
		row.ownershipRevision=3 check(not Gate.Check(e,row,owner)) row.ownershipRevision=4
		row.sequence=10 check(not Gate.Check(e,row,owner))
	end)
	case("elapsed budgets",function()
		local b=Budget.New(100,20,1) check(Budget.Allow(b,20,1)) check(not Budget.Allow(b,1,1))
		check(Budget.Allow(b,10,1.1)) check(not Budget.Allow(b,1,1.09)) check(not Budget.Allow(b,0/0,1.1))
		check(not pcall(Budget.New,1,1,0/0))
	end)
	for i=1,1200 do case("packet roundtrip "..i,function()
		local e=entity(i,i*17) local full=i%2==0
		local frame=CFrame.new(vec(10000))*CFrame.fromOrientation(random:NextNumber(-math.pi/2,math.pi/2),random:NextNumber(-math.pi,math.pi),random:NextNumber(-math.pi,math.pi))
		local time=if i%3==0 then 429496.7296+i/60 else i/60
		local row=Protocol.Record(e,time,frame,full,false,i%5==0,i%7==0)
		local packets=Protocol.Pack({row}) check(#packets==1 and buffer.len(packets[1])<=900)
		local rows=assert(Protocol.Decode(packets[1])) local r=rows[1]
		check(r.id==e.id and r.generation==7 and r.ownershipRevision==3 and r.sequence==e._sendSequence)
		near(r.time,time,0) check((r.frame.Position-frame.Position).Magnitude<0.0015)
		if full then local _,angle=(frame.Rotation:Inverse()*r.frame.Rotation):ToAxisAngle() check(math.abs(angle)<0.001) end
		check(r.teleport==(i%5==0) and r.stop==(i%7==0))
	end) end
	case("payload split, duplicate ids and truncations",function()
		local records={} for i=1,150 do table.insert(records,Protocol.Record(entity(i,i),500000,CFrame.new(i,0,0),true)) end
		local packets=Protocol.Pack(records) local count=0
		for _,b in packets do check(buffer.len(b)<=900) local rows=assert(Protocol.Decode(b)) count+=#rows end check(count==150)
		local duplicated=Protocol.Pack({records[1],records[1]}) check(#duplicated==2)
		local first=packets[1]
		for length=0,buffer.len(first)-1 do local ok,rows=pcall(Protocol.Decode,clone(first,length)) check(ok and rows==nil,"truncated packet accepted or threw") end
		local trailing=clone(first,buffer.len(first)+1) check(Protocol.Decode(trailing)==nil)
	end)
	for i=1,3000 do case("hostile packet "..i,function()
		local b=buffer.create(random:NextInteger(0,940))
		for offset=0,buffer.len(b)-1 do buffer.writeu8(b,offset,random:NextInteger(0,255)) end
		if i%2==0 and buffer.len(b)>=5 then buffer.writeu16(b,0,0xCF32) buffer.writeu8(b,2,2) buffer.writeu16(b,3,random:NextInteger(0,40)) end
		local ok,rows=pcall(Protocol.Decode,b) check(ok,"decoder threw on hostile bytes")
		if rows then check(#rows>=1 and #rows<=32) end
	end) end
	case("invalid matrices cannot be sent",function()
		check(not pcall(Protocol.Record,entity(),1,CFrame.new(0,0,0,2,0,0,0,1,0,0,0,1),true))
	end)
	case("original Hermite counterexample",function()
		local old=OldHermite(Vector3.zero,Vector3.xAxis,-Vector3.xAxis*3,-Vector3.xAxis*3,0.1,1)
		near(old.X,-0.188,1e-5) result.findings.originalHermiteCounterexample=old.X
		local new=Visual.SegmentHermite(Vector3.zero,Vector3.xAxis,-Vector3.xAxis*3,-Vector3.xAxis*3,0.1,1)
		check(new.X>=0 and new.X<=1)
	end)
	for i=1,700 do case("segment constraint "..i,function()
		local p0,p1=vec(50),vec(50) local direction=p1-p0 local length=direction.Magnitude
		local previous=-1e-5 local a,b=vec(5000),vec(5000)
		for step=0,50 do
			local p=Visual.SegmentHermite(p0,p1,a,b,step/50,random:NextNumber(0.001,0.5))
			-- Each curve needs fixed dt; monotonicity is tested separately below.
			local projection=(p-p0):Dot(direction)/length^2
			check(projection>=-1e-5 and projection<=1+1e-5) check(((p-p0)-direction*projection).Magnitude<2e-4)
		end
		local dt=random:NextNumber(0.001,0.5)
		for step=0,50 do
			local p=Visual.SegmentHermite(p0,p1,a,b,step/50,dt) local projection=(p-p0):Dot(direction)/length^2
			check(projection>=previous-1e-5) previous=projection
		end
	end) end
	case("coverage, lock and prediction labels",function()
		local snapshots=Snapshot(Hermite) snapshots:Push(1,CFrame.identity,Vector3.xAxis)
		snapshots:Push(2,CFrame.new(1,0,0),Vector3.xAxis)
		local _,before=Visual.Sample(snapshots,0.5,"LINEAR",0,1,100) check(before.status=="before_coverage")
		local frame,estimated=Visual.Sample(snapshots,2.05,"LINEAR",0.1,1,100) check(estimated.status=="predicted") near(frame.X,1.05,1e-5)
		local _,held=Visual.Sample(snapshots,2.3,"LINEAR",0.1,1,100) check(held.status=="held")
		snapshots.lockedTime=2
		for _,mode in {"HERMITE","LINEAR","SEGMENT"} do local f,info=Visual.Sample(snapshots,1.1,mode,0,1,100) near(f.X,1) check(info.status=="discontinuity") end
	end)
	case("ticker phase and no catch-up poses",function()
		local t=Ticker.new({TICK_RATE=0.05}) local calls=0 Ticker.AddCallback(t,function()calls+=1 end)
		for frame=1,600 do Ticker.CheckUpdate(t,frame/60) end near(calls,200,0)
		local last=calls check(Ticker.CheckUpdate(t,11)) check(calls==last+1) check(t.skippedDeadlines>=18) near(t.lastTicked,11)
	end)
	case("four-clock asymmetric bounds",function()
		-- Client offset +5; uplink 120 ms and downlink 40 ms.
		local bounds=assert(C.ClockBounds.Exchange(105,100.12,100.13,105.17))
		check(bounds.lower<=-5 and bounds.upper>=-5) near(bounds.rtt,0.16)
		local mapped=assert(C.ClockBounds.Map(bounds,105.2,0.5,100.5)) check(mapped.lower<=100.2 and mapped.upper>=100.2)
		check(C.ClockBounds.Map({lower=0/0,upper=1},1,1,2)==nil)
		check(C.ClockBounds.Map(bounds,200,0.5,100.5)==nil)
	end)
	for i=1,600 do case("asymmetric clock bounds "..i,function()
		local t,offset=random:NextNumber(0,1e6),random:NextNumber(-500,500)
		local up,down,work=random:NextNumber(0,0.75),random:NextNumber(0,0.75),random:NextNumber(0,0.02)
		local b=assert(C.ClockBounds.Exchange(t+offset,t+up,t+up+work,t+offset+up+work+down))
		check(b.lower<=-offset+1e-8 and b.upper>=-offset-1e-8) near(b.rtt,up+down,1e-8)
		check(C.ClockBounds.Exchange(nil,t,t,t)==nil)
	end) end
	for i=1,400 do case("viewer bucket conservative "..i,function()
		local points={} for id=1,60 do points[id]=vec(2000) end points[61]=vector.create(0,0,0)
		local index=ViewerIndex.new(64) index:Rebuild(points)
		local center=vec(1000) local radius=random:NextNumber(0,3000) local found=index:Query(center,radius)
		for id,p in points do if (Vector3.new(p.x,p.y,p.z)-center).Magnitude<=radius then check(found[id]~=nil,"viewer inside radius omitted") end end
		local all=index:Query(center,math.huge) check(all[61]~=nil)
	end) end
	local function row(t,x,grade) local root=CFrame.new(x or 0,0,0) return {time=t,receivedAt=t,root=root,zones={Body=S.Sphere(root,1)},state={active=true},grade=grade or "serverSimulated"} end
	case("immutable covered game records",function()
		local h=C.History.new({seconds=0.6,maxGap=0.075})
		check(h:Push(row(1,0))) check(h:Push(row(1.05,1))) local r=assert(h:Sample(1.025,1.06)) near(r.root.X,0.5,1e-5)
		check(table.isfrozen(r) and table.isfrozen(r.state) and table.isfrozen(r.zones))
		local _,reason=h:Sample(0.99,1.06) check(reason=="too_old") check(h:Sample(1.055,1.06)==nil)
		check(not h:Push(row(1.05,2))) h:Break(1.06,"teleport") check(h:Sample(1.025,1.06)==nil)
		check(h:Push(row(1.07,1000))) check(h:Push(row(1.1,1000))) check(h:Sample(1.08,1.1)~=nil)
	end)
	case("trust, gap, invalid data and retention",function()
		local h=C.History.new({seconds=0.6,maxGap=0.075,capacity=3})
		check(h:Push(row(1,0,"observed"))) check(h:Sample(1,1)==nil) check(h:Sample(1,1,true)~=nil)
		check(h:Push(row(1.2,0,"observed"))) check(h:Sample(1.1,1.2,true)==nil)
		local bad=row(1.3,0) bad.zones=false check(not h:Push(bad))
		check(h:Push(row(1.3,0))) check(h:Push(row(1.4,0))) check(h:Sample(1,1.4,true)==nil)
		check(h:Sample(1.4,2.1)==nil)
	end)
	for i=1,1200 do case("relative sphere crossing "..i,function()
		local direction=vec(1).Unit local origin=vec(1000) local travel=random:NextNumber(5,100)
		local ra,rb=random:NextNumber(0.1,2),random:NextNumber(0.1,2) local drift=vec(20)
		local a0,a1=origin-direction*travel+drift,origin+direction*travel+drift
		local b0,b1=origin,origin+drift*2
		local hit=C.Continuous.Spheres(a0,a1,ra,b0,b1,rb)
		local hitSwap=C.Continuous.Spheres(b0,b1,rb,a0,a1,ra)
		check(hit==hitSwap,`sphere swap: {hit} / {hitSwap}`)
		local relative=(a1-a0)-(b1-b0) local start=a0-b0
		if hit then local d=start+relative*hit check(math.abs(d.Magnitude-ra-rb)<0.003 or hit==0,`sphere boundary: {d.Magnitude}, radius {ra+rb}`) end
		local velocity=vec(50) local boosted=C.Continuous.Spheres(a0,a1+velocity,ra,b0,b1+velocity,rb)
		check((hit==nil and boosted==nil) or (hit~=nil and boosted~=nil and math.abs(hit-boosted)<1e-4),`sphere velocity invariance: {hit} / {boosted}; {a0} -> {a1}; {b0} -> {b1}; radii {ra},{rb}; boost {velocity}`)
	end) end
	case("pose exact keys and interpolation",function()
		local timeline=C.PoseTimeline.new({{time=0,zones={Foot=S.Sphere(CFrame.new(0,-2,0),0.5)}},{time=0.2,zones={Foot=S.Sphere(CFrame.new(0,-2,-4),0.5)}}})
		local pose=assert(timeline:Sample(0.1,CFrame.new(3,0,0))) near(pose.Foot.frame.X,3) near(pose.Foot.frame.Z,-2)
		check(timeline:Sample(0.3,CFrame.identity)==nil)
		local changed=C.PoseTimeline.new({{time=0,zones={A=S.Sphere(CFrame.identity,1)}},{time=1,zones={A=S.Sphere(CFrame.identity,2)}}})
		check(changed:Sample(0.5,CFrame.identity)==nil) check(changed:Sample(1,CFrame.identity)~=nil)
	end)
	case("outcome deduplication and partial faults",function()
		local store=C.Outcomes.new(4) local amount=0
		check(store:Apply("a",2,1,function()amount+=1 return true end))
		check(not store:Apply("a",2,1,function()amount+=1 return true end)) check(amount==1)
		check(not store:Apply("fault",2,1,function()amount+=1 error("partial effect") end))
		check(not store:Apply("fault",2,1,function()amount+=1 return true end)) check(amount==2)
		check(not store:Apply("yield",2,1,function()coroutine.yield() return true end))
	end)
	case("separate source and target evidence times",function()
		local world=C.EvidenceWorld.new({clock=function()return 1.06 end})
		world:Track("attacker",{kind="actor",grade="serverSimulated"}) world:Track("target",{kind="actor",grade="serverSimulated"})
		for _,t in {1,1.05} do check(world:Record("attacker",row(t,0))) check(world:Record("target",row(t,3))) end
		local r=world:Query({source="attacker",sourceTime=1.05,targetTime=1.025,targets={"actor"},shape=S.Sphere(CFrame.new(2,0,0),1)})
		check(r.ok and #r.contacts==1) check(r.sourceTime~=r.targetTime)
		local invalid=world:Query({source="attacker",sourceTime=0.1,targetTime=1.025,targets={"actor"},shape=S.Sphere(CFrame.identity,1)}) check(not invalid.ok)
	end)
	case("bounded continuous volumes",function()
		local a0,a1=S.Box(CFrame.new(-10,0,0),Vector3.one),S.Box(CFrame.new(10,0,0),Vector3.one)
		local b=S.Box(CFrame.new(0,10,0),Vector3.one)
		check(C.Motion.Between(a0,a1,b,b).status=="clear")
		local sphere0,sphere1=S.Sphere(CFrame.new(-10,0,0),0.5),S.Sphere(CFrame.new(10,0,0),0.5)
		local target=S.Sphere(CFrame.identity,0.5) local result=C.Motion.Between(sphere0,sphere1,target,target)
		check(result.status=="hit" and result.exact) near(result.fraction,0.45)
		local center=S.Box(CFrame.identity,Vector3.one) check(C.Motion.Between(center,center,center,center).status=="hit")
		check(C.Motion.Between(a0,a1,center,center,{budget=1}).status=="unknown")
	end)
	case("historical moving obstacles and existence",function()
		local world=C.WorldHistory.new({maxGap=0.1}) world:Track("door",1,{grade="serverSimulated"})
		for _,t in {1,1.05} do local frame=CFrame.new(5+(t-1)*100,0,0) check(world:Record("door",{time=t,receivedAt=t,root=frame,zones={Wall=S.Box(frame,Vector3.one)},state={}})) end
		local query=S.Ray(Vector3.zero,Vector3.new(20,0,0)) local blocked=world:Query(1.025,1.06,query)
		check(blocked.covered and blocked.blocked) near(blocked.fraction,0.35,1e-5)
		check(not world:Query(1.055,1.06,query).covered) world:Remove("door",1.05)
		local removed=world:Query(1.055,1.06,query) check(removed.covered and not removed.blocked)
	end)
	case("possession/round conflict tokens",function()
		local version=C.Versions.new() local calls=0
		check(version:Apply(0,function()calls+=1 return true end)) check(not version:Apply(0,function()calls+=1 return true end)) check(calls==1)
		check(not version:Apply(1,function()error("partial")end)) check(not version:Apply(version:Get(),function()calls+=1 return true end))
		version:Reconcile() check(version:Apply(version:Get(),function()calls+=1 return true end)) check(calls==2)
	end)
	case("capture trust changes with ownership",function()
		local now=1 local world=C.EvidenceWorld.new({clock=function()return now end})
		local signal=require(RS.Signal).new()
		local e={id=1,generation=1,ownershipRevision=0}
		local mock={Entity={GetPrimaryPart=function()return nil end,GetEvent=function()return signal.Event end}}
		local handle=C.SourceRecorder.Attach(mock,world,e,{id="recorder",grade="serverSimulated",manual=true,clock=function()return now end,capture=function()return row(now,0)end})
		check(handle.accepted==1) now=1.03 e.networkOwner={} e.ownershipRevision=1
		local accepted,why=handle.Capture() check(not accepted and why=="source_became_client_owned")
		check(world.actors.recorder.history:Sample(1,now)==nil)
		e.networkOwner=nil e.ownershipRevision=2 now=1.06 check(handle.Capture())
		signal:Fire(e) check(world.actors.recorder==nil)
	end)
	case("callbacks cannot change a query's roster",function()
		local world=C.EvidenceWorld.new({clock=function()return 1.06 end})
		for _,id in {"a","b"} do world:Track(id,{kind="actor",grade="serverSimulated"}) for _,t in {1,1.05} do check(world:Record(id,row(t,0))) end end
		local result=world:Query({source="a",sourceTime=1.05,targetTime=1.05,targets={"actor"},shape=S.Sphere(CFrame.identity,1),rule=function()world:Untrack("b")return true end})
		check(not result.ok and result.reason=="rules_fault") check(world.actors.b~=nil)
	end)
	case("unregister without deleting the game model",function()
		local E=require(RS.Entity) local holder=require(RS.Holder)
		local part=Instance.new("Part") part.Name="ChronoDetachUnit" part.Anchored=true part.Parent=workspace
		local e=E.new("DEFAULT",part,"NATIVE") local id=e.id
		check(holder.GetEntityFromModel(part)==e) E.Destroy(e,true)
		check(part.Parent==workspace) check(holder.GetEntityFromId(id)==nil and holder.GetEntityFromModel(part)==nil)
		check(e._preserveModelOnRemoval==true) part:Destroy()
	end)
	case("conservative camera/box intersection",function()
		local frustum=require(root.Replication.Client.Frustum) local camera=workspace.CurrentCamera local previous=camera.CFrame local fov=camera.FieldOfView
		camera.CFrame=CFrame.identity camera.FieldOfView=70 frustum.Prepare()
		check(frustum.CheckBroadPhase(Vector3.new(0,0,-10),Vector3.new(100,100,1),CFrame.identity))
		check(not frustum.CheckBroadPhase(Vector3.new(0,0,10),Vector3.one,CFrame.identity))
		check(frustum.CheckBroadPhase(Vector3.zero,Vector3.one*100,CFrame.Angles(0.4,0.3,0.2)))
		camera.CFrame=previous camera.FieldOfView=fov
	end)
	result.ok=#result.failures==0
	return result
end
return Suite
