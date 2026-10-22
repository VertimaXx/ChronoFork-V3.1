-- Executes as an ordinary game Script, exercising the generated integration, not the MCP require context.
local Http=game:GetService("HttpService")
local output=Instance.new("StringValue") output.Name="LiveAdapterResult" output.Parent=game.ServerStorage.ChronoV3Validation
local assertions=0
local function check(value,message) assertions+=1 assert(value,message) end
local ok,err=pcall(function()
	local time=100
	local kit=require(game.ServerScriptService.ChronoV3SmokeIntegration)({clock=function() return time end})
	local c,S=kit.Chrono,require(game.ServerScriptService.ChronoV3SmokeIntegration.Core).Shapes
	local p=Vector3.new(0,0,-3)
	kit.Bindings.Track("player",function() return {root=CFrame.new(),zones={body=S.Sphere(CFrame.new(),1)},state={active=true,team=1}} end,"serverSimulated","player")
	kit.Bindings.Track("ball",function() return {root=CFrame.new(p),zones={ball=S.Sphere(CFrame.new(p),1)},state={active=true}} end,"serverSimulated","ball")
	check(c:Capture().ok,"capture")
	local action=assert(c:BeginAction("player",kit.Actions.Contact))
	check(c:Query(action).reason=="not_active","move opens too early")
	for _=1,2 do time+=0.0625 check(c:Capture().ok,"step capture") end
	local evidence=c:Query(action)
	check(evidence.ok and #evidence.contacts==1 and evidence.contacts[1].id=="ball","football contact")
	check(c:Query(action).reason=="duplicate_query","duplicate outcome")
	time+=0.0625 c:Capture() check(c:Query(action).reason=="action_spent","repeat ball contact")
	check(c:EndAction(action),"end action")
	local raw=Instance.new("Part") raw.Name="RawReference" raw.Parent=game.ServerStorage.ChronoV3Validation
	kit.Bindings.TrackReference("raw",raw,"ball")
	time+=0.0625 check(c:Capture().ok,"unverified reference capture")
	local profile=table.clone(kit.Actions.Contact) profile.opens=0
	local second=assert(c:BeginAction("player",profile))
	check(c:Query(second).reason=="unverified_target","server reference falsely trusted")
	c:Untrack("raw") raw:Destroy()
	local third=assert(c:BeginAction("player",profile))
	c:Discontinuity("player","authorized respawn") time+=0.0625 c:Capture()
	check(c:Query(third).reason=="source_epoch_changed","respawn stale move")
	check(c:Inspect().stats.contacts==1,"incorrect contact count")
	c:Destroy()
end)
output.Value=Http:JSONEncode({passed=ok,assertions=assertions,error=if ok then nil else tostring(err),context="ordinary server Script + wizard-generated integration"})
