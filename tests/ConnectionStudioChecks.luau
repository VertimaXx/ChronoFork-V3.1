-- Run in Studio Edit mode against the shipped setup package. Real editor writes and Undo records.
return function(package)
	assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
	local E=package.Editor local Config=require(E.Config) local Install=require(E.Installer)
	local CC=require(E.ConnectionConfig) local CI=require(E.ConnectionInstaller) local B=require(E.HookBuilder)
	local rows={} local root local folder=Instance.new("Folder") folder.Name="__ChronoEditQA" folder.Parent=workspace
	local dummy=Instance.new("Script") dummy.Name="Dummy" dummy.Enabled=false dummy.Source="local value = 1\nreturn value\n" dummy.Parent=game.ServerScriptService
	local remote=Instance.new("RemoteEvent") remote.Parent=folder
	local event=Instance.new("BindableEvent") event.Parent=folder
	local c=CC.Default() c.actors="Folder" c.guide=false
	local links={Actors=folder}
	local function check(name,fn) local ok,why=pcall(fn) table.insert(rows,{name=name,passed=ok,error=if ok then nil else tostring(why)}) end
	local ok,why=pcall(function()
		for _,mode in {"ServerPhysics","Humanoid"} do check("position option "..mode,function() local v=table.clone(c) v.positions=mode assert(CC.Validate(v,links)) end) end
		for _,key in {"walk","jump","ground","burst","slack","radius","height"} do check("invalid number "..key,function() local v=table.clone(c) v[key]=0/0 assert(not CC.Validate(v,links)) end) end
		check("client event refused",function() assert(not CC.Validate(c,{Actors=folder,Begin=remote})) end)
		check("existing server event accepted",function() assert(CC.Validate(c,{Actors=folder,Begin=event})) end)
		check("missing independent provider refused",function() local v=table.clone(c) v.positions="Provider" assert(not CC.Validate(v,links)) end)
		check("automatic check needs outcome",function() local v=table.clone(c) v.autoQuery=true assert(not CC.Validate(v,links)) end)
		check("missing actor folder refused",function() assert(not CC.Validate(c,{})) end)
		check("core installs through real plugin installer",function()
			local settings=Config.Default() settings.name="__ChronoConnectionEditQA"
			local plan,err=Install.Preview(settings,{},package.Core) assert(plan,err) root=assert(Install.Apply(plan))
		end)
		assert(root,"Core installation failed")
		check("reviewed connection settings are frozen",function()
			local proposed=table.clone(c) local handle,err=CI.Preview(root,proposed,links,package.Runtime) assert(handle,err)
			proposed.walk=199 assert(CI.Apply(handle))
			local saved=CI.Load(root) assert(saved.walk==c.walk)
		end)
		check("automatic startup supplied",function() assert(root.StartConnection.Enabled and root.Connector.Movement and root.Hooks) end)
		check("no gameplay remote installed",function() for _,v in root:GetDescendants() do assert(not v:IsA("RemoteEvent")) end end)
		check("configure adds formerly empty event link",function() local v,l=CI.Load(root) l.Begin=event assert(CI.Save(root,v,l)) assert(root.ConnectionLinks.Begin.Value==event) end)
		check("configure clears event link",function() local v,l=CI.Load(root) l.Begin=nil assert(CI.Save(root,v,l)) assert(root.ConnectionLinks.Begin.Value==nil) end)
		check("wizard settings support actual object Undo and Redo",function()
			local before,links=CI.Load(root) local changed=table.clone(before) changed.walk=before.walk+1 assert(CI.Save(root,changed,links))
			local history=game:GetService("ChangeHistoryService") history:Undo() task.wait(0.05) assert(CI.Load(root).walk==before.walk)
			history:Redo() task.wait(0.05) assert(CI.Load(root).walk==changed.walk)
		end)
		check("customized hook kept on settings save",function()
			local before=root.Hooks.Source root.Hooks.Source=before.."\n-- developer extension\n"
			local v,l=CI.Load(root) v.walk=21 assert(CI.Save(root,v,l)) assert(root.Hooks.Source:find("developer extension",1,true)) root.Hooks.Source=before
		end)
		check("manual settings source is not overwritten",function()
			local before=root.Connections.Source root.Connections.Source=before.."\n-- manual settings edit\n"
			local v,l=CI.Load(root) assert(not CI.Save(root,v,l)) assert(root.Connections.Source:find("manual settings edit",1,true)) root.Connections.Source=before
		end)
		for _,kind in {"Begin","Gate","Cancel","Finish","Motion","Teleport"} do check("generate "..kind,function() local code,err=B.Generate(root,kind) assert(code,err) assert(code:find("require(",1,true)) end) end
		check("unsafe variable syntax refused",function() assert(not B.Generate(root,"Gate",{actor="evil()"})) end)
		check("client hook refused",function() local client=Instance.new("LocalScript") client.Parent=folder assert(not B.Preview(root,client,1,"return")) client:Destroy() end)
		check("source changed after preview kept",function()
			local handle=assert(B.Preview(root,dummy,1,"-- example")) dummy.Source..="-- newer edit\n"
			assert(not B.Apply(handle)) assert(dummy.Source:find("newer edit",1,true))
		end)
		check("actual editor insertion and exact restore",function()
			local before=dummy.Source local handle=assert(B.Preview(root,dummy,1,"-- real insertion"))
			local record=assert(B.Apply(handle)) assert(dummy.Source~=before) assert(B.Restore(record)) assert(dummy.Source==before)
		end)
		check("explicit source Restore works after object Undo and Redo",function()
			local before=dummy.Source local handle=assert(B.Preview(root,dummy,1,"-- undo redo check")) local record=assert(B.Apply(handle))
			local name,after=record.Name,dummy.Source local history=game:GetService("ChangeHistoryService")
			assert(history:GetCanUndo(),"No Undo action was recorded")
			history:Undo() task.wait(0.05) history:Redo() task.wait(0.05)
			assert(game.ScriptEditorService:GetEditorSource(dummy)==after,"Script text changed unexpectedly")
			assert(B.Restore(root.ConnectionPatches:FindFirstChild(name))) assert(dummy.Source==before)
		end)
		check("newer edits prevent destructive restore",function()
			local before=dummy.Source local handle=assert(B.Preview(root,dummy,1,"-- insertion")) local record=assert(B.Apply(handle))
			dummy.Source..="-- subsequent work\n" assert(not B.Restore(record)) assert(dummy.Source:find("subsequent work",1,true))
			dummy.Source=record.After.Value assert(B.Restore(record)) assert(dummy.Source==before)
		end)
		check("teleport line replacement restores exactly",function()
			local before=dummy.Source local handle=assert(B.Preview(root,dummy,1,"local replacement = 2",nil,true))
			local record=assert(B.Apply(handle)) assert(not dummy.Source:find("local value = 1",1,true)) assert(B.Restore(record)) assert(dummy.Source==before)
		end)
		check("modified supplied source prevents removal",function()
			local before=root.Hooks.Source root.Hooks.Source..="\n-- keep me\n" assert(not CI.Remove(root)) assert(root.Connector) root.Hooks.Source=before
		end)
		check("nested developer extensions are kept",function()
			local extension=Instance.new("ModuleScript") extension.Name="MyExtension" extension.Source="return {}" extension.Parent=root.Connector
			assert(not CI.Remove(root)) assert(extension.Parent==root.Connector) extension:Destroy()
		end)
		check("connection rollback keeps original core",function()
			local before=root.Core.Source assert(CI.Remove(root)) assert(root.Core.Source==before and root.Actions and not root:FindFirstChild("Connector"))
		end)
	end)
	if not ok then table.insert(rows,{name="suite",passed=false,error=tostring(why)}) end
	if root then root:Destroy() end dummy:Destroy() folder:Destroy()
	local passed=0 for _,r in rows do if r.passed then passed+=1 end end
	return {run=#rows,passed=passed,failed=#rows-passed,cases=rows}
end
