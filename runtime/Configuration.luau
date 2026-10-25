-- Shared wizard/runtime schema. Plain data; editor does not execute game modules.
local C={Version="3.2.0",Build="2026-10-25"}
function C.Copy(v,seen)
 if type(v)~="table" then return v end
 seen=seen or {} assert(not seen[v],"Settings must not contain repeated/cyclic tables") seen[v]=true
 local o={} for k,x in v do o[k]=C.Copy(x,seen) end seen[v]=nil return o
end
function C.Volume(name) return {name=name or "Body",shape="Box",width=4,height=5,depth=2,radius=2,x=0,y=0,z=0,pitch=0,yaw=0,roll=0,length=20} end
function C.Move(name) local v=C.Volume(name or "Contact") v.z=-3 v.depth=5 v.targets="actor" v.opens=0.12 v.closes=0.35 v.maxTargets=1 v.maxReach=32 v.rule="all" v.world=false v.queryMode="Default" return v end
function C.Default()
 return {schema=2,actors="Players",tag="ChronoActor",root="HumanoidRootPart",kind="actor",positions="ServerPhysics",
 body="Box",width=4,height=5,depth=2,radius=2,walk=20,jump=50,ground=3,burst=0.4,slack=1.25,verticalSlack=3,wallRadius=0.7,
 correction=false,autoQuery=false,guide=true,partBodies=false,activeAttribute="",teamAttribute="",
 recording="Heartbeat",recordRate=60,historySeconds=0.6,maxGap=0.075,maxRewind=0,recordMaxSpeed=100,recordMaxRadius=16,
 timing="Present",displayDelay=0,queryMode="Once",queryInterval=1/60,candidates="Existing",worldMode="None",maxObstacles=1024,
 moveSource="Actions",moves={},zones={},kindLimits={},objectLimits=true,legacyLimits=false}
end
function C.Normalize(v,base)
 local out=C.Default() base=base or {}
 for key,value in {historySeconds=base.seconds,maxGap=base.maxGap,maxRewind=base.maxRewind,recordRate=base.rate,recordMaxSpeed=base.maxSpeed,recordMaxRadius=base.maxRadius} do if value~=nil then out[key]=value end end
 if v then for key,value in v do out[key]=C.Copy(value) end end
 if v and v.schema==nil then
  out.legacyLimits=true
  out.recordMaxSpeed=4096
  out.recordMaxRadius=if v.positions=="Provider" then 512 else math.min(512,math.max(v.radius or 2,(v.height or 5)/2,Vector3.new(v.width or 4,v.height or 5,v.depth or 2).Magnitude/2)+0.001)
 end
 out.schema=2 return out
end
local function number(n,a,b) return type(n)=="number" and n==n and n>=a and n<=b end
local function name(s) return type(s)=="string" and #s>0 and #s<=64 and not s:find("%c") end
C.Number=number C.Name=name
function C.CheckVolume(v,attack)
 if type(v)~="table" or not name(v.name) then return false,"Give every hitbox/move a short name." end
 if not table.find(if attack then {"Box","Sphere","Capsule","Ray","SweptSphere"} else {"Box","Sphere","Capsule"},v.shape) then return false,"Choose a supported shape." end
 for key,b in {width={0.01,512},height={0.02,512},depth={0.01,512},radius={0.01,32},length={0.01,4096},x={-4096,4096},y={-4096,4096},z={-4096,4096},pitch={-360,360},yaw={-360,360},roll={-360,360}} do if not number(v[key],b[1],b[2]) then return false,"Invalid hitbox value: "..key end end
 if v.shape=="Capsule" and v.height<v.radius*2 then return false,"Capsule height must include both round ends: at least twice its radius." end
 if attack then
  if not number(v.opens,0,10) or not number(v.closes,v.opens,10) or not number(v.maxTargets,1,256) or v.maxTargets%1~=0 or not number(v.maxReach,0,4096) then return false,"Review timing, reach and target count." end
  if not table.find({"all","team","Hook"},v.rule) or not table.find({"Default","Once","Repeated"},v.queryMode) or type(v.world)~="boolean" then return false,"Choose the move rule, check mode and wall option." end
  if v.world and v.shape~="Ray" and v.shape~="SweptSphere" then return false,"Core obstacle checks support rays and swept spheres; other moves need your own wall rule." end
  if type(v.targets)~="string" then return false,"Enter target kinds separated by commas." end
  local count=0 for k in v.targets:gmatch("[^,%s]+") do if not name(k) then return false,"Invalid target kind." end count+=1 end
  if count<1 or count>32 then return false,"Use 1 to 32 target kinds." end
  local position=Vector3.new(v.x,v.y,v.z) local reach
  if v.shape=="Ray" or v.shape=="SweptSphere" then
   local f=CFrame.new(position)*CFrame.Angles(math.rad(v.pitch),math.rad(v.yaw),math.rad(v.roll))
   reach=math.max(position.Magnitude,(f*CFrame.new(0,0,-v.length)).Position.Magnitude)+(if v.shape=="Ray" then 0 else v.radius)
  else reach=position.Magnitude+(if v.shape=="Box" then Vector3.new(v.width,v.height,v.depth).Magnitude/2 elseif v.shape=="Capsule" then v.height/2 else v.radius) end
  if reach>v.maxReach then return false,"Move "..v.name.." exceeds its allowed reach. Include its offset and size." end
 end return true
end
function C.Validate(values,links)
 if type(values)~="table" then return false,"Choose connection settings first." end
 local copied,c=pcall(C.Normalize,values) if not copied then return false,"Settings must be plain data without cycles." end links=links or {}
 local defaults=C.Default() for key in c do if defaults[key]==nil then return false,"Unknown setting: "..tostring(key) end end
 for key,choices in {actors={"Players","PlayersAndFolder","Folder","Tag","References","Data","PlayersAndData"},positions={"ServerPhysics","Humanoid","Provider"},body={"Box","Sphere","Capsule"},recording={"Heartbeat","Manual","Event"},timing={"Present","MeasuredPing","Provider"},queryMode={"Once","Repeated"},candidates={"Existing","Chrono"},worldMode={"None","StaticBoxes","Provider"},moveSource={"Actions","Builder"}} do if not table.find(choices,c[key]) then return false,"Choose a valid option: "..key end end
 for _,key in {"root","kind","tag","activeAttribute","teamAttribute"} do if type(c[key])~="string" or #c[key]>64 or c[key]:find("%c") then return false,"Use short names: "..key end end
 if c.root=="" or c.kind=="" or c.kind:find("[%s,]") or (c.actors=="Tag" and c.tag=="") then return false,"Root/kind/tag names are incomplete." end
 for key,b in {width={0.02,512},height={0.02,512},depth={0.02,512},radius={0.01,32},walk={0,200},jump={0,250},ground={0.5,20},burst={0.05,1},slack={0,10},verticalSlack={0,15},wallRadius={0.1,3},recordRate={1,240},historySeconds={0.05,10},maxGap={0.001,1},maxRewind={0,10},displayDelay={0,10},recordMaxSpeed={0,4096},recordMaxRadius={0.001,512},queryInterval={1/240,1},maxObstacles={1,4096}} do if not number(c[key],b[1],b[2]) then return false,"Choose a valid number for "..key end end
 if c.maxObstacles%1~=0 then return false,"Obstacle count must be a whole number." end
 if c.maxRewind>c.historySeconds or c.displayDelay>c.maxRewind then return false,"Lookback must fit saved history; view delay must fit lookback." end
 if c.timing~="Present" and (c.maxRewind<=0 or c.candidates~="Chrono") then return false,"Earlier checks need a positive lookback and targets from Chrono contacts, not a present-part target list." end
 if c.body=="Capsule" and c.height<c.radius*2 then return false,"Target capsule height must be at least twice its radius." end
 for _,key in {"correction","autoQuery","guide","partBodies","objectLimits","legacyLimits"} do if type(c[key])~="boolean" then return false,"Choose on/off: "..key end end
 for key,required in {Provider=c.positions=="Provider" and c.actors~="Data",Registry=false,Clock=false,Timing=c.timing=="Provider",World=c.worldMode=="Provider"} do
  local v=links[key] if required and not v then return false,"Select the "..key.." server ModuleScript." end
  if v and (typeof(v)~="Instance" or not v:IsA("ModuleScript") or not v:IsDescendantOf(game)) then return false,key.." must be a ModuleScript in this place." end
 end
 if table.find({"Folder","References","PlayersAndFolder"},c.actors) then
  local v=links.Actors if typeof(v)~="Instance" or not (v:IsA("Folder") or v:IsA("Model") or (c.actors~="Folder" and v:IsA("BasePart"))) or not v:IsDescendantOf(workspace) then return false,"Select participating Workspace objects." end
 end
 if c.worldMode=="StaticBoxes" then local v=links.Obstacles if typeof(v)~="Instance" or not (v:IsA("Folder") or v:IsA("Model")) or not v:IsDescendantOf(workspace) then return false,"Select the folder/model of anchored obstacles." end end
 for _,key in {"Begin","Query","Cancel","Outcome","Capture"} do local v=links[key] if v and (typeof(v)~="Instance" or not v:IsA("BindableEvent") or not v:IsDescendantOf(game)) then return false,key..": choose a server BindableEvent, never a RemoteEvent." end end
 if c.recording=="Event" and not links.Capture then return false,"Select the completed-simulation recording event." end
 if c.autoQuery and not links.Outcome then return false,"Automatic checks need your Outcome event." end
 for _,key in {"zones","moves","kindLimits"} do
  if type(c[key])~="table" or #c[key]>32 then return false,"Use at most 32 entries: "..key end
  local n=0 for index in c[key] do if type(index)~="number" or index%1~=0 or index<1 or index>#c[key] then return false,"Use a continuous list: "..key end n+=1 end
  if n~=#c[key] then return false,"Use a continuous list: "..key end
 end
 for _,key in {"zones","moves"} do local seen={} for _,v in c[key] do local ok,why=C.CheckVolume(v,key=="moves") if not ok then return false,why end if seen[v.name] then return false,"Duplicate name: "..v.name end seen[v.name]=true end end
 if c.moveSource=="Builder" and #c.moves==0 then return false,"Add a move on the Moves page." end
 if c.moveSource=="Builder" and c.worldMode=="None" then for _,v in c.moves do if v.world then return false,"Choose an obstacle provider on Timing for move "..v.name end end end
 local kinds={} for _,v in c.kindLimits do if type(v)~="table" or not name(v.kind) or kinds[v.kind] or not number(v.maxSpeed,0,4096) or not number(v.maxRadius,0.001,512) then return false,"Review each kind's unique name and recording limits." end kinds[v.kind]=true end
 return true
end
function C.Source() return 'return game:GetService("HttpService"):JSONDecode(script.Parent.ConnectionData.Value)\n' end
return table.freeze(C)
