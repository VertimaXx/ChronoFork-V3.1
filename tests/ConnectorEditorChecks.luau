-- Real installation/Undo + plugin control callbacks. Run from Edit, outside MCP's Undo recording.
return function(package)
 local C=require(package.Editor.ConnectionConfig) local I=require(package.Editor.ConnectionInstaller)
 local Setup=require(package.Editor.Installer) local SC=require(package.Editor.Config)
 local B=require(package.Editor.HookBuilder) local A=require(package.Editor.ConnectionView)
 local rows={} local root
 local function check(name,fn) local ok,why=pcall(fn) table.insert(rows,{name=name,passed=ok,error=if ok then nil else tostring(why)}) end
 local cfg=C.Default() cfg.actors="Data" cfg.guide=false
 for key,values in {recording={"Heartbeat","Manual"},timing={"Present"},queryMode={"Once","Repeated"},actors={"Players","Data","PlayersAndData"}} do for _,v in values do
  check("mode validates "..key.." "..v,function() local c=C.Copy(cfg) c[key]=v assert(C.Validate(c,{})) end)
 end end
 for _,key in {"maxRewind","recordRate","maxGap","historySeconds","recordMaxSpeed","recordMaxRadius","queryInterval","maxObstacles"} do
  check("invalid finite/range value refused "..key,function() local c=C.Copy(cfg) c[key]=0/0 assert(not C.Validate(c,{})) end)
 end
 check("earlier timing requires Chrono candidate delivery",function() local c=C.Copy(cfg) c.timing="MeasuredPing" c.maxRewind=0.1 assert(not C.Validate(c,{})) c.candidates="Chrono" assert(C.Validate(c,{})) end)
 check("cycles and sparse settings refuse without crashing",function()
  local c=C.Copy(cfg) c.zones={C.Volume()} c.zones[3]=C.Volume("Other") assert(not C.Validate(c,{}))
  c=C.Copy(cfg) c.zones[1]=c assert(not C.Validate(c,{}))
 end)
 check("duplicate names and excessive reach refuse",function()
  local c=C.Copy(cfg) c.moveSource="Builder" c.moves={C.Move("Contact"),C.Move("Contact")} assert(not C.Validate(c,{}))
  c.moves={C.Move("Contact")} c.moves[1].maxReach=0.1 assert(not C.Validate(c,{}))
 end)
 check("setup limits are seeded into connector controls",function()
  local v=SC.Default() v.name="__ChronoExpandedEditorQA" v.maxSpeed=123 v.maxRadius=17 v.maxRewind=0.1
  local h=assert(Setup.Preview(v,{},package.Core)) root=assert(Setup.Apply(h))
  local c=I.Seed(root) assert(c.recordMaxSpeed==123 and c.recordMaxRadius==17 and c.maxRewind==0.1)
 end)
 check("nested reviewed connection values are copied",function()
  local c=C.Copy(cfg) c.zones={C.Volume("Head")} c.zones[1].y=2
  local h,why=I.Preview(root,c,{},package.Runtime) assert(h,why) c.zones[1].y=200
  assert(I.Apply(h)) assert(I.Load(root).zones[1].y==2)
 end)
 check("expanded modules and all links are supplied",function()
  for _,name in {"Configuration","Volumes","World","DefaultHooks","Movement"} do assert(root.Connector:FindFirstChild(name),name) end
  for _,name in {"Registry","Timing","Clock","World","Obstacles","Capture"} do assert(root.ConnectionLinks:FindFirstChild(name),name) end
 end)
 check("settings persist nested move edits and Undo/Redo",function()
  local c,l=I.Load(root) c.moveSource="Builder" c.moves={C.Move("Tackle")} assert(I.Save(root,c,l))
  local history=game:GetService("ChangeHistoryService") history:Undo() task.wait(0.05) assert(I.Load(root).moveSource=="Actions")
  history:Redo() task.wait(0.05) assert(I.Load(root).moves[1].name=="Tackle")
 end)
 check("explicit runtime upgrade preserves custom Hooks and Actions",function()
  root.Hooks.Source..="\n-- game hook extension" local h=root.Hooks.Source local a=root.Actions.Source
  assert(I.Upgrade(root,package.Runtime)) assert(root.Hooks.Source==h and root.Actions.Source==a)
  assert(root:GetAttribute("ConnectionBuild")==C.Build)
 end)
 check("edited Connector refuses an automatic upgrade",function()
  local before=root.Connector.Source root.Connector.Source..="\n-- custom connector"
  assert(not I.Upgrade(root,package.Runtime)) assert(root.Connector.Source:find("custom connector",1,true)) root.Connector.Source=before
 end)
 for _,custom in {false,true} do check("guide upgrade protects customization "..tostring(custom),function()
  local guide=Instance.new("LocalScript") guide.Name=root.Name.."ConnectionGuide" guide.Source="-- previous supplied guide" guide.Parent=game.StarterPlayer.StarterPlayerScripts
  local record=root.ConnectionRecord.Value local rows=game.HttpService:JSONDecode(record)
  table.insert(rows,{name=guide.Name,source=guide.Source}) root.ConnectionRecord.Value=game.HttpService:JSONEncode(rows)
  if custom then guide.Source..="\n-- developer guide changes" end local before=guide.Source
  local upgraded,why=I.Upgrade(root,package.Runtime)
  local actual=guide.Source guide:Destroy() root.ConnectionRecord.Value=record
  assert(upgraded,why)
  assert(actual==(if custom then before else package.Runtime["Guide.client"].Source))
 end) end
 check("all provider templates stay inside the supplied package",function()
  local T=require(package.Editor.ProviderTemplates)
  for _,key in {"Provider","Clock","Registry","Timing","World"} do local module=assert(T.Add(root,key)) assert(module.Parent==root and #module.Source>30) assert(not T.Add(root,key)) end
 end)
 for _,kind in {"Begin","Gate","Query","Resolve","Capture","Track","Untrack","Reset","Inspect","Destroy","Cancel","Finish","Motion","Teleport"} do
  check("generated connection call "..kind,function() local code,why=B.Generate(root,kind) assert(code,why) end)
 end
 -- Same ConnectionView and Advanced controls as the plugin, with recorded button callbacks.
 local function draw(state,width,height)
  local host=Instance.new("ScrollingFrame") host.Size=UDim2.fromOffset(width,height)
  local ui={content=host,status=Instance.new("TextLabel")} local buttons={} local callbacks={}
  function ui.place(v,p) v.Parent=p return v end
  function ui.label(p,text) local v=Instance.new("TextLabel") v.Text=tostring(text) v.Parent=p return v end
  function ui.card(p,name) local f=Instance.new("Frame") f.Name=name f.Parent=p return f end
  function ui.note(title,body) ui.label(host,title) ui.label(host,body) end
  function ui.button(p,text,fn) local v=Instance.new("TextButton") v.Text=text v.Parent=p buttons[text]=fn return v end
  function ui.connect(signal,fn) table.insert(callbacks,fn) end
  function ui.codeBox(text) ui.label(host,text) end
  function ui.rebuild() end
  A.Draw(ui,state,{root=root,runtime=package.Runtime,selection=function() return {root} end})
  return host,buttons,callbacks
 end
 for _,size in {{360,500},{500,800}} do for _,tab in {"Objects","Bodies","Moves","Timing","Recording","Events","Calls","Test & restore"} do
  check("draw plugin controls "..tab.." "..size[1],function()
   local state=A.New() state.root=root state.loadedRoot=root state.tab=tab state.c=C.Copy(cfg)
   state.c.zones={C.Volume("Body"),C.Volume("Head")} state.c.zones[2].y=3 state.c.moveSource="Builder" state.c.moves={C.Move("Contact")}
   local host=draw(state,size[1],size[2]) assert(#host:GetDescendants()>10) host:Destroy()
  end)
 end end
 check("body builder add/duplicate/remove callbacks update settings",function()
  local state=A.New() state.root=root state.loadedRoot=root state.tab="Bodies" local host,buttons=draw(state,360,500)
  buttons["Add target hitbox"]() assert(#state.c.zones==1) host:Destroy()
  host,buttons=draw(state,360,500) buttons["Duplicate selected entry"]() assert(#state.c.zones==2) host:Destroy()
  host,buttons=draw(state,360,500) buttons["Remove selected entry"]() assert(#state.c.zones==1) host:Destroy()
 end)
 check("move builder imports the saved setup Contact",function()
  local state=A.New() state.root=root state.loadedRoot=root state.tab="Moves" state.c.moveSource="Builder"
  local host,buttons=draw(state,500,800) buttons["Copy the original setup move into this builder"]()
  assert(#state.c.moves==1 and state.c.moves[1].name=="Contact") assert(state.c.moves[1].z==-SC.Default().forward) host:Destroy()
 end)
 check("legacy normalization retains old movement and timing policy",function()
  local c=C.Default() c.schema=nil c.recordMaxSpeed=nil c.recordMaxRadius=nil c.maxRewind=nil c.timing=nil
  local v=C.Normalize(c) assert(v.legacyLimits and v.recordMaxSpeed==4096 and v.maxRewind==0 and v.timing=="Present")
 end)
 if root then root:Destroy() end
 local passed=0 for _,r in rows do if r.passed then passed+=1 end end return {run=#rows,passed=passed,failed=#rows-passed,cases=rows}
end

