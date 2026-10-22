return function(t)
	local API=require(game.ServerStorage.ChronoV3Validation.Core)
	local S,E=API.Shapes,t.expect
	local function fixture(options)
		local now=10
		local o=options or {} o.clock=function() return now end
		local service=API.new(o)
		local state={a={team=1,active=true},b={team=2,active=true}}
		local positions={a=Vector3.zero,b=Vector3.new(0,0,-3)}
		for _,id in {"a","b"} do service:Track(id,{kind=if id=="a" then "player" else "ball",trust="serverSimulated",maxSpeed=100,maxRadius=4,
			capture=function() return {root=CFrame.new(positions[id]),zones={body=S.Sphere(CFrame.new(positions[id]),1)},state=state[id]} end}) end
		service:Capture()
		local function step(delta) now+=delta or 1/60 return service:Capture() end
		local profile={shape=S.Box(CFrame.new(0,0,-2),Vector3.new(4,4,4)),targets={"ball"},maxTargets=1,closes=1}
		return service,profile,step,state,positions,function(n) now=n end
	end
	-- A football contact works without a Humanoid, damage API, network protocol, or obstacle map.
	t.test("minimal football contact",function() local s,p=fixture() local a=assert(s:BeginAction("a",p)) local r=s:Query(a) E.truthy(r.ok) E.equal(r.contacts[1].id,"b") E.equal(r.time,10) s:Destroy() end)
	-- Returning evidence never edits game-owned state.
	t.test("outcomes remain game owned",function() local s,p,_,state=fixture() local a=s:BeginAction("a",p) s:Query(a) E.equal(state.b.active,true) E.equal(state.b.team,2) end)
	-- Handles from another service or a copied table cannot authorize a query.
	t.test("forged and foreign handles",function() local s,p=fixture() local other=fixture() E.equal(s:Query({}).reason,"invalid_action") E.equal(other:Query(s:BeginAction("a",p)).reason,"invalid_action") end)
	-- Re-querying an action cannot yield a second contact against the same target.
	t.test("duplicate and spent contacts",function() local s,p,step=fixture() local a=s:BeginAction("a",p) E.equal(#s:Query(a).contacts,1) E.equal(s:Query(a).reason,"duplicate_query") step() E.equal(s:Query(a).reason,"action_spent") end)
	-- Recovery is explicit after any provider fault; no speed violation becomes an accepted teleport.
	t.test("speed fault quarantines until lifecycle reset",function() local s,p,step,_,pos=fixture() pos.b=Vector3.new(0,0,-100) E.falsy(step().ok) step() E.equal(s:Inspect().actors[2].status,"speed_bound") s:Discontinuity("b","authorized teleport") E.truthy(step().ok) end)
	-- Legitimate teleports invalidate old source handles.
	t.test("source teleport invalidates action",function() local s,p,step=fixture() local a=s:BeginAction("a",p) s:Discontinuity("a","teleport") step() E.equal(s:Query(a).reason,"source_epoch_changed") end)
	-- Entity removal or id reuse cannot silently change an action's target roster.
	t.test("roster change invalidates action",function() local s,p=fixture() local a=s:BeginAction("a",p) s:Untrack("b") E.equal(s:Query(a).reason,"roster_changed") end)
	-- Scalar state and geometry are copied; later game-table edits cannot rewrite evidence.
	t.test("historical state is immutable",function() local s,p,_,state=fixture() state.b.team=99 local a=s:BeginAction("a",p) local r=s:Query(a) E.equal(r.contacts[1].state.team,2) E.throws(function() r.contacts[1].state.team=9 end) end)
	-- A supplied predicate can exclude teammates or invulnerability using the sampled state.
	t.test("eligibility predicates",function() local s,p=fixture() p.eligible=function(a,b) return a.team==b.team end local a=s:BeginAction("a",p) E.equal(#s:Query(a).contacts,0) end)
	-- Predicates must synchronously return a boolean.
	t.test("rules yield fails closed",function() local s,p=fixture() p.eligible=function() coroutine.yield() return true end E.equal(s:Query(s:BeginAction("a",p)).reason,"rules_fault") end)
	-- Reentrant provider operations are caught as provider faults.
	t.test("reentrant rules fail closed",function() local s,p=fixture() p.eligible=function() s:Capture() return true end E.equal(s:Query(s:BeginAction("a",p)).reason,"rules_fault") end)
	-- An inactive move cannot query early; its open endpoint is included.
	t.test("active window boundaries",function() local s,p,step=fixture() p.opens=0.125 p.closes=0.25 local a=s:BeginAction("a",p) E.equal(s:Query(a).reason,"not_active") step(0.125) E.truthy(s:Query(a).ok) end)
	-- The expired handle is reclaimed on capture.
	t.test("expired action reclaimed",function() local s,p,step=fixture() local a=s:BeginAction("a",p) step(1.01) E.equal(s:Query(a).reason,"invalid_action") E.equal(s:Inspect().activeActions,0) end)
	-- Stale captures do not become evidence for the present frame.
	t.test("capture age checked",function() local s,p,_,_,_,set=fixture() local a=s:BeginAction("a",p) set(10.1) E.equal(s:Query(a).reason,"capture_stale") end)
	-- Rewind is off unless the game deliberately supplies a server resolver.
	t.test("client time ignored by default",function() local s,p=fixture() local a=s:BeginAction("a",p,{time=-100,rewind=99}) E.equal(s:Query(a).rewind,0) end)
	-- Resolver over-budget values are rejected rather than clamped into success.
	t.test("rewind bounds",function() local s,p=fixture({maxRewind=0.1,resolveRewind=function() return 0.101 end}) local a,why=s:BeginAction("a",p) E.equal(a,nil) E.equal(why,"rewind_rejected") end)
	-- Callback failure may not silently opt into current time.
	t.test("rewind callback fault",function() local s,p=fixture({resolveRewind=function() error("bad resolver") end}) local a,why=s:BeginAction("a",p) E.equal(a,nil) E.equal(why,"rewind_rejected") end)
	-- An exact covered historical frame can support an opted-in bounded rewind.
	t.test("explicit covered rewind",function() local s,p,step=fixture({maxRewind=0.1,resolveRewind=function() return 0.0625 end}) step(0.0625) local a=assert(s:BeginAction("a",p)) local r=s:Query(a) E.truthy(r.ok) E.equal(r.time,10) end)
	-- State transitions are not interpolated into invented invulnerability times.
	t.test("uncertain discrete state boundary rejects",function() local s,p,step,state=fixture({maxRewind=0.1,resolveRewind=function() return 0.03125 end}) state.b.active=false step(0.0625) local a=assert(s:BeginAction("a",p)) E.equal(s:Query(a).reason,"target_state_boundary") end)
	-- No interpolation across a sampling gap larger than the configured limit.
	t.test("packet or capture gap rejects",function() local s,p,step=fixture({maxRewind=0.25,resolveRewind=function() return 0.125 end}) step(0.25) local a,why=s:BeginAction("a",p) E.equal(a,nil) E.equal(why,"source_sample_gap") end)
	-- Merely reading a replicated part on the server does not confer trust.
	t.test("unverified targets block partial success",function() local s,p=fixture() s:Track("c",{kind="ball",maxSpeed=1,maxRadius=1,capture=function() return {root=CFrame.new(999,0,0),zones={x=S.Sphere(CFrame.new(999,0,0),1)}} end}) local a=s:BeginAction("a",p) E.equal(s:Query(a).reason,"unverified_target") end)
	-- Cover is optional, and enabled sweeps require covered evidence from the game adapter.
	t.test("world cover fraction and uncertainty",function()
		local known=true
		local s,p=fixture({world=function() return {covered=known,blocked=true,fraction=0.1} end})
		p.shape=S.Ray(Vector3.zero,Vector3.new(0,0,-10)) p.world=true
		E.equal(#s:Query(s:BeginAction("a",p)).contacts,0)
		known=false E.equal(s:Query(s:BeginAction("a",p)).reason,"world_unknown")
	end)
	-- Unsupported overlap/cover semantics are rejected explicitly, never silently skipped.
	t.test("overlap cover requires game policy",function() local s,p=fixture({world=function() return {covered=true,blocked=false,fraction=1} end}) p.world=true local a,why=s:BeginAction("a",p) E.equal(a,nil) E.equal(why,"world_provider_or_shape") end)
	-- A clear world and a blocker exactly at the endpoint have different meanings.
	t.test("clear world includes tangent endpoint",function()
		local blocked=false
		local s,p=fixture({world=function() return {covered=true,blocked=blocked,fraction=1} end})
		p.shape=S.Ray(Vector3.zero,Vector3.new(0,0,-2)) p.world=true
		E.equal(#s:Query(s:BeginAction("a",p)).contacts,1)
		blocked=true E.equal(#s:Query(s:BeginAction("a",p)).contacts,0)
	end)
	-- Geometry reach and shape values are server-owned and bounded.
	t.test("invalid reach profile",function() local s,p=fixture() p.maxReach=1 local a,why=s:BeginAction("a",p) E.equal(a,nil) E.equal(why,"invalid_profile") end)
	-- Profile mutation after authorization cannot alter this action.
	t.test("action profile copied",function() local s,p=fixture() local a=s:BeginAction("a",p) p.shape=S.Sphere(CFrame.new(500,0,0),1) p.targets[1]="noone" E.equal(#s:Query(a).contacts,1) end)
	-- Snapshot provider yielding quarantines its actor and rejects old evidence.
	t.test("provider yield contained",function() local s,p,step=fixture() s:Track("c",{kind="ball",trust="serverSimulated",maxSpeed=1,maxRadius=1,capture=function() coroutine.yield() end}) E.falsy(step().ok) local a=s:BeginAction("a",p) E.equal(s:Query(a).reason,"target_empty") end)
	-- Erroneous adapter payload metamethods cannot escape the capture boundary.
	t.test("snapshot validation errors contained",function()
		local s,_,step=fixture()
		s:Track("c",{kind="ball",trust="serverSimulated",maxSpeed=1,maxRadius=1,capture=function()
			return {root=CFrame.new(),zones={body=setmetatable({},{__index=function() error("bad shape accessor") end})}}
		end})
		local result=step() E.falsy(result.ok) E.equal(result.faults[1].reason,"invalid_snapshot")
		E.equal(s:Inspect().actors[3].status,"invalid_snapshot")
	end)
	-- Clock reversal cannot create a later authoritative sample.
	t.test("clock reversal rejected",function() local s,_,_,_,_,set=fixture() set(9) E.equal(s:Capture().reason,"non_monotonic") end)
	-- Maximum outstanding actions is finite and EndAction releases capacity.
	t.test("action capacity and release",function() local s,p=fixture() local a=s:BeginAction("a",p) for _=1,3 do E.truthy(s:BeginAction("a",p)) end local x,why=s:BeginAction("a",p) E.equal(x,nil) E.equal(why,"action_capacity") E.truthy(s:EndAction(a)) E.truthy(s:BeginAction("a",p)) end)
	-- Destroy ends the instance without leaving connections or running loops.
	t.test("destroy lifecycle",function() local s=fixture() s:Destroy() E.throws(function() s:Capture() end) end)
end
