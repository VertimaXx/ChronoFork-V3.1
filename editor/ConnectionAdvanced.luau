-- Advanced controls are part of the same plugin and save the same reviewed settings.
local C=require(script.Parent.ConnectionConfig)
local Picture=require(script.Parent.VolumePreview)
local A={}
function A.Draw(tab,ui,state,root,c,links,h)
 if not table.find({"Bodies","Moves","Timing","Recording"},tab) then return false end
 local input,choose,refresh,message=h.input,h.choose,h.refresh,h.message
 local function options(key,rows,title,values)
  values=values or c if title then ui.label(ui.content,title,16) end
  for _,row in rows do
   local value=if type(row)=="table" then row[1] else row local text=if type(row)=="table" then row[2] else row
   ui.button(ui.content,text,function() values[key]=value refresh() end,values[key]==value)
  end
 end
 local function toggle(key,text)
  ui.button(ui.content,text..(if c[key] then ": on" else ": off"),function() c[key]=not c[key] refresh() end,c[key])
 end
 local function volumes(key,attack)
  local list=c[key] local indexKey=key.."Index" state[indexKey]=math.clamp(state[indexKey] or 1,1,math.max(1,#list))
  ui.note(if attack then "Named moves" else "Named target hitboxes",if attack then "Choose a move below. Names are used by Begin and the accepted-move event. Your Actions file is kept when the builder is selected." else "A returned contact names the area touched, such as Head or Body. Shapes turn and move with the recorded root. They do not follow animated limbs. A position provider can supply animated zones instead.")
  for i,v in list do ui.button(ui.content,tostring(i)..". "..v.name,function() state[indexKey]=i refresh() end,i==state[indexKey]) end
  ui.button(ui.content,if attack then "Add move" else "Add target hitbox",function()
   if #list>=32 then message("Maximum 32 entries.") return end
   local used={} for _,v in list do used[v.name]=true end local n=#list+1 local prefix=if attack then "Move" else "Zone"
   while used[prefix..n] do n+=1 end
   table.insert(list,if attack then C.Move(prefix..n) else C.Volume(prefix..n)) state[indexKey]=#list refresh()
  end)
  local v=list[state[indexKey]] if not v then return end
  input(if attack then "Move name" else "Hitbox name","name",v,false)
  options("shape",if attack then {"Box","Sphere","Capsule","Ray","SweptSphere"} else {"Box","Sphere","Capsule"},"Shape",v)
  if v.shape=="Box" then
   for _,row in {{"width","Width (studs)"},{"height","Height (studs)"},{"depth","Depth (studs)"}} do input(row[2],row[1],v,true) end
  elseif v.shape=="Sphere" or v.shape=="Capsule" or v.shape=="SweptSphere" then
   input("Radius: center to edge (studs)","radius",v,true)
   if v.shape=="Capsule" then input("Total height, including round ends (studs)","height",v,true) end
  end
  if v.shape=="Ray" or v.shape=="SweptSphere" then input("Line length (studs)","length",v,true) end
  ui.note("Position and rotation","Offsets use the saved root: X right, Y up, Z backward (negative Z is forward). Rotations are degrees in pitch, yaw, roll order. Orange marks the root; colored shapes are hitboxes.")
  for _,row in {{"x","X offset (studs)"},{"y","Y offset (studs)"},{"z","Z offset (studs)"},{"pitch","Pitch: X rotation (degrees)"},{"yaw","Yaw: Y rotation (degrees)"},{"roll","Roll: Z rotation (degrees)"}} do input(row[2],row[1],v,true) end
  ui.place(Picture.Draw(nil,if attack then {v} else list,attack),ui.content)
  ui.button(ui.content,"Update shape picture",refresh)
  if attack then
   for _,row in {{"targets","Target kinds, separated by commas"},{"opens","Wait before checking (seconds)"},{"closes","Stop checking, from move start (seconds)"},{"maxTargets","Different targets for the WHOLE move"},{"maxReach","Farthest allowed attack edge (studs)"}} do input(row[2],row[1],v,row[1]~="targets") end
   options("rule",{{"all","Allow matching types"},{"team","Active objects on different teams"},{"Hook","Use Eligible inside Hooks"}},"Target rule",v)
   options("queryMode",{{"Default","Use connection check mode"},{"Once","Check once"},{"Repeated","Check again at later recorded updates"}},"Hit checking",v)
   ui.button(ui.content,"Check obstacles: "..tostring(v.world),function() v.world=not v.world refresh() end,v.world)
   ui.label(ui.content,"Obstacle checks require a ray or swept sphere and a provider on Timing. Other shapes need the game's wall rule inside Hooks.",13)
  end
  ui.button(ui.content,"Duplicate selected entry",function()
   if #list>=32 then message("Maximum 32 entries.") return end
   local used={} for _,row in list do used[row.name]=true end local n=1 while used[v.name.."Copy"..n] do n+=1 end
   local copy=C.Copy(v) copy.name=v.name.."Copy"..n table.insert(list,copy) state[indexKey]=#list refresh()
  end)
  ui.button(ui.content,"Remove selected entry",function() table.remove(list,state[indexKey]) refresh() end)
 end
 if tab=="Bodies" then
  ui.note("One object, several target areas","Up to 32 named Box, Sphere or Capsule shapes. Empty list uses the simple body on Objects. Provider-supplied zones take priority; these controls do not override that provider. Data-only objects supply their zones in their snapshot.")
  volumes("zones",false)
 elseif tab=="Moves" then
  options("moveSource",{{"Actions","Use the Actions module inside the package"},{"Builder","Use moves configured in this plugin"}},"Where move settings come from")
  if c.moveSource=="Builder" then
   ui.button(ui.content,"Copy the original setup move into this builder",function()
    local data=root and root:FindFirstChild("SetupData")
    if not data then message("This older code group has no saved setup values. Add a move below, or keep using its Actions file.") return end
    local ok,v=pcall(game.HttpService.JSONDecode,game.HttpService,data.Value) if not ok then message("Saved setup values are unreadable.") return end
    for _,row in c.moves do if row.name=="Contact" then message("Contact already exists. Your move was kept.") return end end
    if #c.moves>=32 then message("Maximum 32 entries.") return end
    local m=C.Move("Contact")
    for _,k in {"shape","width","height","depth","radius","length","targets","opens","closes","maxTargets"} do m[k]=v[k] end
    m.z=if v.shape=="Ray" or v.shape=="SweptSphere" then 0 else -v.forward m.rule=v.rules
    m.maxReach=4096 table.insert(c.moves,m) state.movesIndex=#c.moves refresh()
   end)
   volumes("moves",true)
  else ui.note("Custom move logic stays inside Actions","Open Actions in Test & restore. Each named profile uses the same Core shape, targets, opens/closes, maxTargets, maxReach, world and eligible fields. Optional queryMode chooses Once or Repeated for that move. The plugin keeps that file when switching modes.") end
 elseif tab=="Timing" then
  ui.note("Which positions decide a contact?","Present checks the latest recorded update. Earlier checks look back by one server-approved delay, fixed when the move starts. Missing, old or interrupted records refuse the check. A larger maximum alone does not enable compensation.")
  options("timing",{{"Present","Latest saved positions (default)"},{"MeasuredPing","Earlier positions: measured player ping"},{"Provider","Earlier positions: my server timing rule"}},"Timing policy")
  input("Maximum approved lookback (seconds)","maxRewind",c,true,"Must fit saved history. Over-limit requests refuse; no silent clamp.")
  if c.timing=="MeasuredPing" then
   input("Additional known display delay (seconds)","displayDelay",c,true,"Only use a delay your own display pipeline actually adds. Default zero.")
   ui.note("Measured ping is an estimate","Uses half the server's GetNetworkPing round-trip value, plus the configured display delay. It does not know exact packet arrival asymmetry or the exact screen frame seen by the player. Data-only actors need TimingPlayer inside Hooks to identify their player.")
  elseif c.timing=="Provider" then choose("Timing","Timing provider","ModuleScript with Resolve(actor,serverContext,captureTime,maximum). Context must already be checked by your server. A template is available in Test & restore.") end
  options("candidates",{{"Existing","Keep an existing present-part target list"},{"Chrono","Use targets returned by Chrono contacts"}},"Where hit candidates come from")
  ui.note("A gate cannot discover missing targets","Allows only checks a target your code already found. A present-time overlap can miss someone who was inside an earlier hitbox. Earlier timing therefore requires Chrono candidates: use Resolve with Outcome, or Query contacts. This choice records your integration intent; Play tests must verify the actual code path.")
  ui.note("Obstacle checks","Choose only objects that should stop these moves. The built-in option saves anchored Part bounding boxes, including conservative boxes around meshes. Terrain and moving historical cover need your own provider.")
  options("worldMode",{{"None","No Core obstacle provider"},{"StaticBoxes","Anchored obstacles: saved bounding boxes"},{"Provider","My obstacle provider"}},"Obstacle policy")
  if c.worldMode=="StaticBoxes" then
   choose("Obstacles","Obstacle folder","Select a Workspace Folder/Model containing anchored blocking Parts. CanCollide and CanQuery must both be true. A changed obstacle list/box starts a new coverage period; earlier checks across that change refuse.")
   input("Maximum obstacle Parts","maxObstacles",c,true)
  elseif c.worldMode=="Provider" then choose("World","Obstacle provider","ModuleScript with Check(queryTime,currentTime,shape). It must return covered, blocked and fraction; unknown historical cover must refuse. Template in Test & restore.") end
 elseif tab=="Recording" then
  ui.note("When positions are saved","All participating objects must describe the same instant. Heartbeat suits ordinary server physics. A game with its own simulation should save after completing each simulation step; selecting a mode does not create that simulation.")
  options("recording",{{"Heartbeat","Automatic: after physics"},{"Manual","My server calls Connector.Capture(time)"},{"Event","My completed-step BindableEvent"}},"Recording mode")
  if c.recording=="Event" then choose("Capture","Completed-step recording event","Server BindableEvent argument: optional timestamp in the selected clock's seconds. Fire AFTER updating all participating objects.") end
  choose("Clock","Optional shared clock","No link uses Workspace.GetServerTimeNow. A selected module returns Now() in seconds. Every Capture timestamp and position provider must use that same clock. See template in Test & restore.")
  for _,row in {{"recordRate","Expected / automatic update rate (per second)"},{"historySeconds","How long to keep positions (seconds)"},{"maxGap","Largest allowed record gap (seconds)"},{"recordMaxSpeed","Maximum root travel speed (studs/second)"},{"recordMaxRadius","Farthest target hitbox edge from root (studs)"}} do input(row[2],row[1],c,true) end
  ui.note("Storage and evidence limits","Storage holds ceil(rate × seconds) + 2 updates per object. Heartbeat also refreshes on move/query/approval calls, preserving immediate provider checks. Include those updates in the expected rate. Recording faster than that rate shortens usable history. Manual/Event gives your simulation sole recording control. Speed/extent limits do not prove movement was permitted.")
  if c.legacyLimits then
   ui.note("Older installation limits retained","This installation still uses its old 4096 speed / derived extent policy. Switch deliberately to the configured limits below after reviewing your game.")
   ui.button(ui.content,"Use reviewed recording limits instead of legacy limits",function() c.legacyLimits=false refresh() end)
  end
  toggle("objectLimits","Allow server object attributes ChronoMaxSpeed / ChronoMaxRadius")
  ui.note("Limits by object kind","Override defaults for named kinds, such as fighter or ball. Server object attributes override these; data bindings and RecordingLimits in Hooks may override them again.")
  for i,v in c.kindLimits do
   input("Kind name","kind",v,false) input("Maximum speed","maxSpeed",v,true) input("Farthest hitbox edge","maxRadius",v,true)
   ui.button(ui.content,"Remove kind limit "..i,function() table.remove(c.kindLimits,i) refresh() end)
  end
  ui.button(ui.content,"Add limits for another kind",function()
   if #c.kindLimits>=32 then message("Maximum 32 kinds.") return end
   table.insert(c.kindLimits,{kind="kind"..(#c.kindLimits+1),maxSpeed=c.recordMaxSpeed,maxRadius=c.recordMaxRadius}) refresh()
  end)
 end
 return true
end
return A

