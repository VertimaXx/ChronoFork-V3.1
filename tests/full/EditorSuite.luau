-- Edit only. Uses disposable owned names; exact-source checks protect edits.
local M={}
function M.Run(fixture)
	local Schema=require(fixture.Editor.Schema) local Installer=require(fixture.Editor.Installer)
	local assertions=0 local function check(v,message) assertions+=1 assert(v,message or "editor check failed") end
	local settings=Schema.Defaults() check(Schema.Validate(settings))
	check(not settings.experimentalPrediction and not settings.experimentalDraw,"prediction must be opt-in")
	local experimental=table.clone(settings) experimental.experimentalDraw=true check(not Schema.Validate(experimental))
	experimental.experimentalPrediction=true check(Schema.Validate(experimental))
	experimental.mode="Engine" experimental.engineConfirmed=true check(not Schema.Validate(experimental),"experiment must not drive engine mode")
	for _,field in Schema.Fields do
		local invalid=table.clone(settings) invalid[field.key]=if field.kind=="boolean" then "false" elseif field.kind=="number" then 0/0 else {}
		check(not Schema.Validate(invalid),"invalid setting accepted: "..field.key)
	end
	local invalid=table.clone(settings) invalid.mode="Engine" check(not Schema.Validate(invalid)) invalid.engineConfirmed=true check(Schema.Validate(invalid))
	local deps={history={TryBeginRecording=function()return "test-record"end,FinishRecording=function()end},editor={UpdateSourceAsync=function(_,object,callback)object.Source=callback(object.Source)end}}
	settings.name="ChronoForkInstallerValidation"
	local plan,summary=Installer.Preview(settings,{},fixture.ChronoFork) check(plan~=nil,tostring(summary)) check(summary.settings:find("predictionSeconds = 0",1,true)~=nil)
	check(summary.settings:find("experimentalPrediction = false",1,true)~=nil)
	local added,why=Installer.Apply(plan,deps) check(added~=nil,tostring(why))
	check(added.Replication.Shared.Remotes.Replicate:IsA("UnreliableRemoteEvent"))
	check(added.Core:IsA("ModuleScript") and added.Competitive.History:IsA("ModuleScript"))
	check(added.InstallManifest:IsA("ObjectValue") and added.InstallManifest.Value.Parent==game.ServerStorage,"source backups replicated to clients")
	check(Installer.Preview(settings,{},fixture.ChronoFork)==nil,"existing name replaced")
	local extra=Instance.new("Folder") extra.Name="DeveloperAddedData" extra.Parent=added
	check(Installer.PreviewRemove(added)==nil,"developer-added object removed") extra:Destroy()
	local original=added.Hooks.Source added.Hooks.Source..="\n-- test edit"
	check(Installer.PreviewRemove(added)==nil,"edited hooks removed") added.Hooks.Source=original
	check(Installer.Remove(added,deps)) check(not game.ReplicatedStorage:FindFirstChild(settings.name))
	check(not game.ServerScriptService:FindFirstChild(settings.name.."Server"))
	check(not game.StarterPlayer.StarterPlayerScripts:FindFirstChild(settings.name.."Client"))
	check(not game.ServerStorage:FindFirstChild(settings.name.."InstallManifest"))
	return {ok=true,assertions=assertions,fields=#Schema.Fields}
end
return M
