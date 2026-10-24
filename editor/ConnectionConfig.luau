-- Settings for the supplied connection machinery. No game script analysis or trust guessing.
local C={}
function C.Default()
	return {actors="Players",tag="ChronoActor",root="HumanoidRootPart",kind="actor",
		positions="ServerPhysics",body="Box",width=4,height=5,depth=2,radius=2,
		walk=20,jump=50,ground=3,burst=0.4,slack=1.25,verticalSlack=3,wallRadius=0.7,
		correction=false,autoQuery=false,guide=true,partBodies=false,activeAttribute="",teamAttribute=""}
end
local function bounded(n,a,b) return type(n)=="number" and n==n and n>=a and n<=b end
function C.Validate(c,links)
	if type(c)~="table" then return false,"Choose connection settings first." end
	local defaults=C.Default() for key in c do if defaults[key]==nil then return false,"Unknown connection setting: "..tostring(key) end end
	if c.partBodies~=nil and type(c.partBodies)~="boolean" then return false,"Choose on/off for non-character Part sizes." end
	if not table.find({"Players","PlayersAndFolder","Folder","Tag","References"},c.actors) then return false,"Choose where participating objects come from." end
	if not table.find({"ServerPhysics","Humanoid","Provider"},c.positions) then return false,"Choose who calculates or checks positions." end
	if not table.find({"Box","Sphere","Capsule"},c.body) then return false,"Choose the target contact shape." end
	for _,key in {"root","kind","tag","activeAttribute","teamAttribute"} do
		if type(c[key])~="string" or #c[key]>64 or c[key]:find("%c") then return false,"Use short names without control characters: "..key end
	end
	if c.root=="" or c.kind=="" or c.kind:find("[%s,]") or (c.actors=="Tag" and c.tag=="") then return false,"Root and tag need names. Object kind must be one short name without spaces or commas." end
	for key,range in {width={0.02,64},height={0.02,64},depth={0.02,64},radius={0.01,32},walk={0,200},jump={0,250},ground={0.5,20},burst={0.05,1},slack={0,10},verticalSlack={0,15},wallRadius={0.1,3}} do
		if not bounded(c[key],range[1],range[2]) then return false,"Choose a valid number for "..key.." ("..range[1].." to "..range[2]..")." end
	end
	if c.body=="Capsule" and c.height<c.radius*2 then return false,"Target capsule height must be at least twice its radius." end
	for _,key in {"correction","autoQuery","guide"} do if type(c[key])~="boolean" then return false,"Choose on/off for "..key end end
	links=links or {}
	if c.actors=="Folder" and (typeof(links.Actors)~="Instance" or not (links.Actors:IsA("Folder") or links.Actors:IsA("Model")) or not links.Actors:IsDescendantOf(workspace)) then return false,"Select the Workspace folder/model containing your participating objects." end
	if c.actors=="PlayersAndFolder" and (not links.Actors or not (links.Actors:IsA("Folder") or links.Actors:IsA("Model") or links.Actors:IsA("BasePart")) or not links.Actors:IsDescendantOf(workspace)) then return false,"Select the extra Workspace object, or folder of balls/other objects. Players are followed automatically." end
	if c.actors=="References" and (not links.Actors or not (links.Actors:IsA("Model") or links.Actors:IsA("BasePart") or links.Actors:IsA("Folder")) or not links.Actors:IsDescendantOf(workspace)) then return false,"Select one Workspace model/Part, or a folder of objects to track." end
	if c.positions=="Provider" and (not links.Provider or not links.Provider:IsA("ModuleScript")) then return false,"Select the existing server position-checking ModuleScript. It must implement Snapshot(object, time)." end
	for _,key in {"Begin","Query","Cancel","Outcome"} do
		if links[key] and (not links[key]:IsA("BindableEvent") or not links[key]:IsDescendantOf(game)) then return false,key..": select an existing server BindableEvent, not a RemoteEvent." end
	end
	if c.autoQuery and not links.Outcome then return false,"Automatic hit timing needs your existing Outcome BindableEvent. Otherwise keep automatic timing off and use the generated Allows call." end
	if links.Actors and not links.Actors:IsDescendantOf(game) then return false,"The selected objects were removed. Choose them again." end
	return true
end
function C.Source(c)
	local keys={} for key in c do table.insert(keys,key) end table.sort(keys)
	local lines={"-- Edited by the Chrono connection wizard. Edit Hooks for unusual game rules.","return {"}
	for _,key in keys do local v=c[key] table.insert(lines," "..key.."="..(if type(v)=="string" then string.format("%q",v) else tostring(v))..",") end
	table.insert(lines,"}") return table.concat(lines,"\n").."\n"
end
return table.freeze(C)
