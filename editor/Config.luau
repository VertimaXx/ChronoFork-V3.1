-- Game-neutral data schema. Presets are editable examples, not game adapters.
local C={}
local Fields=require(script.Parent.Fields)
function C.Default()
	return {name="ChronoV3Integration",kind="actor",targets="actor,ball",shape="Capsule",radius=1.5,height=5,
		width=4,depth=5,forward=3,length=100,opens=0.12,closes=0.35,maxTargets=1,
		seconds=0.6,maxGap=0.075,maxRewind=0,maxSpeed=100,maxRadius=16,rules="all"}
end
function C.Preset(preset,previous)
	local c=C.Default() c.name=previous.name
	if preset=="Sports" then c.kind="player" c.targets="player,ball"
	elseif preset=="Melee" then c.shape="Box" c.kind="fighter" c.targets="fighter" c.forward=2 c.rules="team"
	elseif preset=="Hitscan" then c.shape="Ray" c.kind="player" c.targets="player" c.opens=0 c.closes=0.1 c.rules="team" end
	return c
end
local function number(v,lo,hi) return type(v)=="number" and v==v and v>=lo and v<=hi end
function C.ParseNumber(value)
	if type(value)=="number" then return value end
	if type(value)~="string" then return nil end
	local text=value:match("^%s*(.-)%s*$")
	if not text:find("%.") then text=text:gsub(",",".") end
	local result=tonumber(text)
	return if result and result==result and math.abs(result)<math.huge then result else nil
end
function C.Check(c)
	local errors={}
	local function add(field,message) table.insert(errors,{field=field,page=Fields.Items[field].page,message=message}) end
	if type(c)~="table" then add("name","No settings were supplied. Start with an example on page 1.") return errors end
	if type(c.name)~="string" or #c.name==0 or #c.name>48 or c.name:match("^%s*$") or c.name:find('[%c/\\\"]') then add("name","Use a short name without quotation marks, slash or backslash. Spaces are allowed. Example: Football contact.") end
	if type(c.kind)~="string" or #c.kind==0 or #c.kind>48 or c.kind:find("[%s,%c]") then add("kind","Use one short object type name without spaces or commas. Example: player or ball.") end
	local count=0
	if type(c.targets)~="string" or #c.targets>256 then add("targets","Enter target type names, separated by commas. Example: player, ball.")
	else
		for kind in c.targets:gmatch("[^,]+") do
			kind=kind:match("^%s*(.-)%s*$")
			if #kind==0 or #kind>48 or kind:find("[%s%c]") then add("targets","Each target type needs one short name. Use commas between names, not spaces.") break end
			count+=1
		end
		if count==0 or count>16 then add("targets","Enter 1 to 16 target type names. Example: player, ball.") end
	end
	if not table.find({"Box","Sphere","Capsule","Ray","SweptSphere"},c.shape) then add("shape","Choose one of the five hitbox shapes.") end
	local used={opens=true,closes=true,maxTargets=true,seconds=true,maxGap=true,maxRewind=true,maxSpeed=true,maxRadius=true}
	if c.shape=="Box" then used.width=true used.height=true used.depth=true used.forward=true
	elseif c.shape=="Sphere" then used.radius=true used.forward=true
	elseif c.shape=="Capsule" then used.radius=true used.height=true used.forward=true
	elseif c.shape=="Ray" then used.length=true
	elseif c.shape=="SweptSphere" then used.length=true used.radius=true end
	for _,key in Fields.Order do
		local field=Fields.Items[key]
		if used[key] and not number(c[key],field.min,field.max) then add(key,string.format("%s: enter a number from %s to %s %s.",field.label,field.min,field.max,field.unit)) end
	end
	if number(c.maxTargets,1,256) and c.maxTargets%1~=0 then add("maxTargets","The object count must be a whole number, such as 1 or 3.") end
	if number(c.opens,0,10) and number(c.closes,0,10) and c.closes<c.opens then add("closes","Stop time must be the same as, or later than, the time hits start.") end
	if number(c.seconds,0.05,10) and number(c.maxRewind,0,10) and c.maxRewind>c.seconds then add("maxRewind","The allowed past time cannot be longer than the time you keep past positions.") end
	if c.shape=="Capsule" and number(c.height,0.02,64) and number(c.radius,0.01,32) and c.height<c.radius*2 then add("height","A capsule needs height at least twice its radius. Radius 1.5 needs total height 3 or more.") end
	if c.rules~="all" and c.rules~="team" then add("rules","Choose a target rule example.") end
	return errors
end
function C.Validate(c)
	local errors=C.Check(c)
	return #errors==0,if errors[1] then errors[1].message else nil
end
function C.Generate(c)
	local ok,why=C.Validate(c) assert(ok,why)
	local shape
	if c.shape=="Box" then shape=string.format("S.Box(CFrame.new(0,0,-%s),Vector3.new(%s,%s,%s))",c.forward,c.width,c.height,c.depth)
	elseif c.shape=="Sphere" then shape=string.format("S.Sphere(CFrame.new(0,0,-%s),%s)",c.forward,c.radius)
	elseif c.shape=="Capsule" then shape=string.format("S.Capsule(CFrame.new(0,0,-%s),%s,%s)",c.forward,c.radius,c.height)
	else shape=string.format("S.Sweep(Vector3.zero,Vector3.new(0,0,-%s),%s)",c.length,if c.shape=="Ray" then 0 else c.radius) end
	local kinds={} for kind in c.targets:gmatch("[^,%s]+") do table.insert(kinds,string.format("%q",kind)) end
	local rules=if c.rules=="team" then "return source.active == true and target.active == true and source.team ~= nil and target.team ~= nil and source.team ~= target.team" else "return true -- Example only: add the rules your game needs before using real moves."
	local reach=if c.shape=="Ray" then c.length elseif c.shape=="SweptSphere" then c.length+c.radius
		elseif c.shape=="Capsule" then c.forward+c.height/2 elseif c.shape=="Sphere" then c.forward+c.radius
		else c.forward+Vector3.new(c.width,c.height,c.depth).Magnitude/2
	return {
		Actions=string.format([[-- MOVE SETTINGS. Edit these values to match one move in your game.
-- A hitbox is an invisible shape used to check contact.
-- Its position here is measured from the moving object's main position and direction.
local S=require(script.Parent.Core).Shapes
return {
 Contact = {
  shape = %s,
  targets = {%s},
  opens = %s,
  closes = %s,
  maxTargets = %s,
  maxReach = %.9g,
 -- opens/closes: seconds after your server accepts the move.
 -- maxTargets: total different objects this move may return; not a count per frame.
 -- source/target: saved game values from your position functions, such as team and active.
  eligible = function(source, target)
  %s
  end,
 },
}
]],shape,table.concat(kinds,","),c.opens,c.closes,c.maxTargets,reach+0.0001,rules),
		Settings=string.format([[-- RECORDING SETTINGS. These do not control your camera, movement, animation or health.
-- seconds: how long to keep earlier positions and hitboxes in memory.
-- rate: expected updates per second. This sizes the storage; your script still calls Capture.
-- maxGap: largest time gap across which Chrono may estimate an in-between position.
-- maxRewind: largest earlier time your SERVER timing rule may approve. Zero is simplest.
return {seconds=%s,rate=60,maxGap=%s,maxRewind=%s}
-- A larger maxRewind alone does not enable earlier checks.
-- Add a resolveRewind function only after deciding how your server validates delayed requests.
]],c.seconds,c.maxGap,c.maxRewind),
		Bindings=string.format([[-- CONNECT YOUR GAME HERE. This file does not replace your player or move scripts.
-- capture is a function YOU supply. It returns a position, hitboxes and rule values at one time.
-- "unverified": data is not approved for gameplay checks.
-- "serverSimulated": your server calculates the data itself.
-- "serverValidated": your server already checks that the supplied data is allowed.
-- Changing the label does not make a player's movement safe. That check belongs in your game.
return function(chrono)
 local B={}
 function B.Track(id,capture,declaredTrust,kind)
  chrono:Track(id,{kind=kind or %q,capture=capture,trust=declaredTrust or "unverified",maxSpeed=%s,maxRadius=%s})
 end
 -- Optional reference for inspecting a selected Part. It stays unverified.
 -- A server reading a client-controlled Part is not the same as a server checking its movement.
 function B.TrackReference(id,part,kind)
  B.Track(id,function(time)
   return {root=part.CFrame,zones={Body=require(script.Parent.Core).Shapes.Box(part.CFrame,part.Size)},state={}}
  end,"unverified",kind)
 end
 -- CONNECTION 1: when your game adds an object, call B.Track with its data function.
 -- Return {root=mainCFrame,zones={Body=shape},state={active=true,team=1}}.
 -- root is the object's reference position AND direction. Zones use map positions.
 -- state contains simple game values: booleans, numbers and short text, not Instances/tables.
 -- CONNECTION 2: after your server updates all participating objects, call chrono:Capture().
 -- Save once before allowing moves, then after every needed game update.
 -- CONNECTION 3: AFTER your server accepts a move (cooldown, stamina, etc.), call BeginAction.
 -- Keep its returned move reference. During the hit period, call Query with that reference.
 -- CONNECTION 4: if result.ok is true, recheck CURRENT rules and apply your own result once.
 -- Your game decides possession, damage or stun. Keep your existing animations and effects.
 -- On an approved teleport/respawn/change of physics owner: chrono:Discontinuity(id,reason).
 -- When cancelled/finished: chrono:EndAction(move). When removed: chrono:Untrack(id).
 -- If something fails: local help=require(script.Parent.Core).Explain(reason)
 -- Print help.title, help.meaning and help.fix. The original reason code stays available.
 return B
end
]],c.kind,c.maxSpeed,c.maxRadius),
		Integration=[[-- START HERE: require this module from your existing SERVER startup script.
-- Requiring this file returns a function. Call that function once to make a Chrono instance.
-- The instance does not move objects or start recording on its own.
return function(overrides)
 local Core=require(script.Core)
 local options=table.clone(require(script.Settings))
 for key,value in overrides or {} do options[key]=value end
 local chrono=Core.new(options)
 return {Chrono=chrono,Actions=require(script.Actions),Bindings=require(script.Bindings)(chrono),Explain=Core.Explain}
end
]],
		Practice=string.format([[-- SAFE PRACTICE: uses made-up server values, no live players or map changes.
-- Uses your shape and target rule with an immediate hit period for this example.
-- This does NOT test your game's connections or real move timing.
return function(Integration)
 local time=10
 local kit=Integration({clock=function() return time end})
 local chrono=kit.Chrono
 local S=require(script.Parent.Core).Shapes
 local targetFrame=CFrame.new(0,0,-%s)
 chrono:Track("practice-source",{kind="practice",trust="serverSimulated",maxSpeed=1,maxRadius=2,
  capture=function() return {root=CFrame.new(),zones={Body=S.Sphere(CFrame.new(),1)},state={active=true,team=1}} end})
 chrono:Track("practice-target",{kind=kit.Actions.Contact.targets[1],trust="serverSimulated",maxSpeed=1,maxRadius=2,
  capture=function() return {root=targetFrame,zones={Body=S.Sphere(targetFrame,1)},state={active=true,team=2}} end})
 assert(chrono:Capture().ok,"Practice could not save its first position")
 local practiceProfile=table.clone(kit.Actions.Contact)
 practiceProfile.opens=0 practiceProfile.closes=1
 local move,reason=chrono:BeginAction("practice-source",practiceProfile)
 assert(move,reason)
 local result=chrono:Query(move)
 local contacts=#result.contacts
 local replay=chrono:Query(move)
 local passed=result.ok and contacts==1 and replay.reason=="duplicate_query"
 local report={passed=passed,contacts=contacts,reason=result.reason,
  duplicateStopped=replay.reason=="duplicate_query",message=if passed then "Practice passed: one contact; repeated check refused. Your game connections are not tested yet." else "Practice failed. Read the reason and use Core.Explain(reason)."}
 chrono:EndAction(move) chrono:Destroy()
 return report
end
]],if c.shape=="Ray" or c.shape=="SweptSphere" then c.length*0.5 else c.forward),
		RunPractice=[[-- PRACTICE ONLY. Starts turned OFF. It never runs in a published game.
-- 1. In Explorer, select this Script and set Enabled=true in Properties.
-- 2. Press Play. Read Output for "Chrono V3 practice".
-- 3. Stop Play. Turn this Script off again or remove it when you finish learning.
if not game:GetService("RunService"):IsStudio() then return end
local report=require(script.Parent.Practice)(require(script.Parent))
print("Chrono V3 practice: "..report.message)
script.Parent:SetAttribute("PracticePassed",report.passed)
script.Parent:SetAttribute("PracticeMessage",report.message)
]],
	}
end
return table.freeze(C)
