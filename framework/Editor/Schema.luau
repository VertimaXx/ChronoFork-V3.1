-- One schema drives validation, source generation, controls and help text.
local S={Version="3.3.0-dev"}
S.Fields={
	{key="experimentalPrediction",label="Very experimental movement prediction",kind="boolean",default=false,help="Off by default. Saves separate estimates on server and client. Estimates can be wrong and are never added to hit-validation history."},
	{key="experimentalDraw",label="Use experimental estimates for drawing",kind="boolean",default=false,help="Also enable the main experiment. Only remote-object drawing changes; your own character and server physics stay under the existing controller."},
	{key="experimentalSeconds",label="Maximum time to guess ahead (seconds)",kind="number",default=0.25,min=0.001,max=0.25,help="0.25 means 250 milliseconds. A larger delay still leaves a gap after this cap."},
	{key="experimentalDistance",label="Maximum guessed travel (studs)",kind="number",default=8,min=0.01,max=32,help="Limits displacement from the newest real sample. Does not enlarge a damage hitbox."},
	{key="experimentalSpeed",label="Fastest source movement to accept (studs/second)",kind="number",default=120,min=1,max=4096,help="Faster samples are refused by the experiment. This is a prediction limit, not an anti-cheat verdict."},
	{key="experimentalAcceleration",label="Maximum guessed acceleration (studs/second squared)",kind="number",default=250,min=1,max=10000,help="How quickly speed is allowed to change in a guess. Game-specific dashes and knockback need their own testing."},
	{key="experimentalTurn",label="Maximum horizontal turn rate (radians/second)",kind="number",default=8,min=0.01,max=50,help="One full turn is about 6.28 radians. Limits the turning candidate."},
	{key="experimentalAngular",label="Maximum orientation change (radians/second)",kind="number",default=12,min=0.01,max=50,help="Limits how far the box may rotate during a forecast. Rotation is not separately optimized by the error learner."},
	{key="experimentalGap",label="Reset after this sample gap (seconds)",kind="number",default=0.75,min=0.05,max=5,help="A gap this long starts a new estimate instead of learning motion across missing updates."},
	{key="experimentalTeleport",label="Minimum jump treated as a reset (studs)",kind="number",default=8,min=1,max=1000,help="A jump larger than this or the speed allowance starts fresh. Deliberate Chrono teleports always clear prediction."},
	{key="experimentalLearning",label="How long errors influence model choice (seconds)",kind="number",default=0.6,min=0.05,max=10,help="Smaller values react faster but may switch guesses more often. Only later received positions are used to score past predictions."},
	{key="experimentalDelay",label="Assumed source delay for EstimateCurrent (seconds)",kind="number",default=0,min=0,max=0.5,help="Advanced server estimate only. Zero makes no uplink-delay assumption. A positive value is your explicit timing assumption, not a measured fact."},
	{key="experimentalLead",label="Move the drawing timeline forward (seconds)",kind="number",default=0,min=0,max=0.25,help="Optional display-only lead. Zero keeps the existing drawing delay. Reducing that delay may add freezes, guesses and corrections."},

	{key="name",label="Added package name",kind="name",default="ChronoFork",help="The code group added to ReplicatedStorage. Existing objects are never replaced."},
	{key="mode",label="Who moves the game objects?",kind="choice",values={"Legacy","Engine"},default="Legacy",help="Legacy uses Chrono movement replication. Engine uses Roblox server authority and your shared simulation hook. Confirm the Workspace settings yourself; scripts cannot read AuthorityMode."},
	{key="players",label="Connect player characters",kind="boolean",default=true,help="Legacy mode follows joins, respawns and character removal automatically."},
	{key="extraSource",label="Other objects to replicate",kind="choice",values={"None","Selection","Tag"},default="None",help="Selection keeps links to selected Parts/Models. Tag follows objects marked with the tag below. No game script rewrite is needed."},
	{key="tag",label="Object tag",kind="name",default="ChronoReplicated",help="A CollectionService tag. Add this tag to the Parts or Models you want Chrono to follow."},
	{key="modelMode",label="Model copying",kind="choice",values={"NATIVE","NATIVE_WITH_LOCK","CUSTOM"},default="NATIVE",help="NATIVE keeps Roblox model copying. WITH_LOCK stops native server transform copying and changes physics behavior. CUSTOM makes separate model copies; use the package hooks for game-specific appearance and animations."},
	{key="interpolation",label="How other objects are drawn",kind="choice",values={"CFRAME","ALIGN","NONE"},default="CFRAME",help="CFRAME sets the displayed pose. ALIGN uses physics constraints and costs more. NONE leaves drawing to your game."},
	{key="curve",label="Curve between received positions",kind="choice",values={"SEGMENT","LINEAR","HERMITE"},default="SEGMENT",help="SEGMENT stays on the straight segment and moves forward along it. LINEAR uses constant progress. HERMITE keeps original Chrono's curved smoothing and may overshoot. None proves that movement avoided walls."},
	{key="sendHz",label="Movement updates each second",kind="number",min=1,max=120,default=20,help="Higher values send more real samples and use more network traffic. This is separate from the competitive recorder."},
	{key="fullRotation",label="Keep pitch and roll",kind="boolean",default=true,help="On sends all three rotation angles. Off sends yaw only, which intentionally loses tilting."},
	{key="minBuffer",label="Minimum drawing delay (seconds)",kind="number",min=0,max=1,default=0.09,help="Extra time to collect packets before drawing. Lower can feel faster but may freeze more during packet gaps."},
	{key="maxBuffer",label="Maximum drawing delay (seconds)",kind="number",min=0,max=2,default=0.5,help="Limits the automatic delay chosen from recent arrivals. It does not remove transport delay."},
	{key="predictionSeconds",label="Optional visual guess (seconds)",kind="number",min=0,max=0.25,default=0,help="Zero is off. A short velocity estimate can hide a missing update, but can be wrong at turns and walls. Never used as hit evidence."},
	{key="predictionDistance",label="Maximum guessed distance (studs)",kind="number",min=0,max=32,default=1,help="The guess stops when it would exceed this distance."},
	{key="predictionSpeed",label="Maximum speed for a visual guess",kind="number",min=0,max=4096,default=100,help="Studs each second. Faster samples are held instead of extrapolated."},
	{key="normalDistance",label="Full update range (studs)",kind="number",min=0,max=100000,default=50,help="Other selected objects nearby receive the normal update frequency. Players keep full reach by default."},
	{key="halfDistance",label="Reduced update range (studs)",kind="number",min=0,max=100000,default=100,help="Between the two ranges, update less often. Far native models still receive reduced updates to preserve original behavior."},
	{key="snapshots",label="Saved drawing samples",kind="number",min=2,max=1024,integer=true,default=60,help="Samples kept by the renderer. Competitive records have their own time and coverage checks."},
	{key="gridInterval",label="Refresh viewer ranges (seconds)",kind="number",min=0.01,max=1,default=0.1,help="How often the server refreshes which players receive each object."},
	{key="gridBudget",label="Range-check work before yielding (ms)",kind="number",min=0.05,max=10,default=0.5,help="Spread a large range refresh over frames. This is a work budget, not a guarantee about total frame time."},
	{key="byteRate",label="Base incoming movement budget (bytes/frame equivalent)",kind="number",min=50,max=10000,integer=true,default=300,help="Converted to an elapsed-time byte budget at 60 frames per second. Extra owned objects add allowance. Invalid packets still consume budget."},
	{key="warning",label="Diagnostic detail",kind="choice",values={"MEDIUM","HIGH","LOW","NONE"},default="MEDIUM",help="Controls messages written to Studio Output."},
	{key="deaths",label="Copy death notifications for",kind="choice",values={"PLAYER_CHARACTERS","PLAYER_ENTITIES","NONE"},default="PLAYER_CHARACTERS",help="Which automatic player objects forward the original death notification. This does not decide damage."},
	{key="setters",label="Copy explicit position changes for",kind="choice",values={"PLAYER_ENTITIES","PLAYER_CHARACTERS","NONE"},default="PLAYER_ENTITIES",help="Which automatic player objects copy deliberate CFrame assignments, such as a server teleport."},
	{key="debugger",label="Developer F4 panel",kind="boolean",default=true,help="Shows movement counts, network bytes, rendering status and entity details. Only Studio testers and explicitly listed developers receive server statistics."},
	{key="adminIds",label="Developer user IDs",kind="text",default="",help="Comma-separated numeric Roblox user IDs. Empty grants nobody outside Studio. These users can use the original diagnostic APIs."},
	{key="engineConfirmed",label="I checked Roblox server-authority settings",kind="boolean",default=false,help="Engine mode requires Workspace AuthorityMode=Server and the related fixed simulation/input settings. The plugin does not silently alter these place settings."},
}
for _,definition in {
	{"CHARACTER_WAIT_DELAY","Wait for character appearance","Wait for Roblox to finish loading the character before registration."},
	{"SERVER_VELOCITY_FIX","Account for bunched arrivals","Estimate velocity using source times when several updates arrive together. This does not verify movement."},
	{"VELOCITY_CALC_FIX","Limit tiny-time velocity spikes","Use at least one update period when estimating display velocity."},
	{"SNAPSHOT_INTERPOLATION_FIX","Original pause/resume smoothing","Allows inferred stop samples in display storage. Competitive records never use these inferred samples."},
	{"SET_CFRAME_FIX","Mark explicit teleports","Copy the teleport flag in addition to the new stream revision."},
	{"FIX_TELEPORT_JITTER","Lock drawing after teleports","Keep earlier display samples from pulling an object back across a teleport."},
} do table.insert(S.Fields,{key=definition[1],label=definition[2],kind="boolean",default=true,help=definition[3]}) end
function S.Defaults() local out={} for _,field in S.Fields do out[field.key]=field.default end return out end
function S.Validate(config)
	if type(config)~="table" then return false,"Choose settings first." end
	for _,f in S.Fields do
		local value=config[f.key]
		if f.kind=="number" then
			if type(value)~="number" or value~=value or value<f.min or value>f.max or (f.integer and value%1~=0) then return false,f.label..": use "..f.min.." to "..f.max..(if f.integer then " (whole numbers)." else ".") end
		elseif f.kind=="choice" then if not table.find(f.values,value) then return false,"Choose "..f.label.."." end
		elseif f.kind=="boolean" then if type(value)~="boolean" then return false,f.label..": choose On or Off." end
		elseif type(value)~="string" or #value>256 then return false,f.label..": use at most 256 characters."
		elseif f.kind=="name" and (#value>64 or not value:match("^[%a_][%w_%-]*$")) then return false,f.label..": use up to 64 letters/numbers; start with a letter. _ and - are allowed." end
	end
	if config.experimentalDraw and not config.experimentalPrediction then return false,"Turn on the main experimental prediction switch before enabling experimental drawing." end
	if config.mode=="Engine" and (config.experimentalPrediction or config.experimentalDraw) then return false,"Experimental prediction currently supports Chrono replication mode only. Leave it off for Roblox server simulation." end
	if config.minBuffer>config.maxBuffer then return false,"Minimum drawing delay must be no greater than the maximum." end
	if config.normalDistance>config.halfDistance then return false,"Full update range must be no greater than reduced update range." end
	if config.mode=="Engine" and not config.engineConfirmed then return false,"Confirm the server-authority Workspace settings before installing Engine mode." end
	for id in config.adminIds:gmatch("[^,%s]+") do local n=tonumber(id) if not n or n%1~=0 or n<1 or n>9007199254740991 then return false,"Developer IDs must be positive whole numbers separated by commas." end end
	return true
end
function S.Generate(config)
	local ok,why=S.Validate(config) assert(ok,why)
	local lines={"-- Generated by ChronoFork full-runtime setup. Edit or use the plugin controls.","return {"}
	for _,f in S.Fields do local v=config[f.key] table.insert(lines,"    "..f.key.." = "..(if type(v)=="string" then string.format("%q",v) else tostring(v))..",") end
	table.insert(lines,"}") return table.concat(lines,"\n").."\n"
end
return table.freeze(S)
