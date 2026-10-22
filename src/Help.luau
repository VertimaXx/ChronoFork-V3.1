-- Help text only. Looking up a message never changes a hit check or trusts a position.
local Help={}
local terms={
	{"authoritative","Server decides","The server makes or checks the value used to decide a hit. A player cannot make a position valid just by sending it.","A tackle uses a position your server movement code has checked."},
	{"server","Server","The computer running the shared game rules for all players. In Studio Play, you can switch between the server and a player's client.","The server decides who gets the ball."},
	{"client","Client","One player's running copy of the game. It handles input, the camera and what that player sees.","A LocalScript reads the tackle button."},
	{"history","Saved past positions","A short list of earlier positions, hitboxes and game values, with the time of each record. Chrono keeps these in memory and later removes old records.","Keep the last 0.6 seconds so a check can use an earlier position."},
	{"snapshot","One saved record","The position, hitboxes and game values of one object at one time.","At time 10.2, the ball was here and the player was on team 2."},
	{"actor","Tracked object","Anything Chrono checks: a player, a ball, an NPC or another game object. It does not have to be a character.","Register the football as kind ball."},
	{"provider","Function that supplies data","A function you write. Chrono calls it to get an object's position, hitboxes and game values.","Read a ball position calculated by your server and return a sphere around it."},
	{"adapter","Connection to your game code","A small piece of code that connects Chrono calls to the scripts your game already uses. Bindings is the generated module for these connections.","When your move script accepts a tackle, start a Chrono action."},
	{"bindings","Connections to your game code","The functions that connect your players, moves and rules to Chrono. The setup creates a Bindings module for you to edit.","Call Bindings.Track when your game adds a player."},
	{"callback","Function given to another function","A function Chrono calls when it needs data or a rule result. The function must finish without task.wait or waiting for an event.","eligible = function(source, target) return source.team ~= target.team end"},
	{"root","Reference position","The main position and direction from which an object's hitboxes are measured. It is a CFrame value; it need not be a part named HumanoidRootPart.","For a ball, its center can be the root."},
	{"cframe","Position and direction (CFrame)","A Roblox value that stores both where something is and which way it faces.","CFrame.new(0, 0, -3) places a local hitbox 3 studs in front."},
	{"local space","Relative to an object","Measure a shape from the object's reference position and facing direction. It moves with that object.","A tackle box stays 3 studs in front of the player."},
	{"world space","Position in the map","Measure a shape in the map's coordinate system, rather than from one object.","A provider returns the ball hitbox at the ball's map position."},
	{"state","Game values saved with a position","Small values your hit rules need at that time. Use true/false, numbers or short text. Do not put Instances or nested tables here.","{active=true, team=2, invulnerable=false}"},
	{"eligible","Allowed by your game rules","A target can count only if the rules you supply allow it. Your game must also check its current rules before applying the result.","A teammate or an invulnerable player may be excluded."},
	{"hitbox","Shape used to check contact","An invisible shape your gameplay uses to decide whether a move reaches an object. It may be simpler than the visible model.","A sphere can represent a football."},
	{"capsule","Cylinder with round ends","A shape like a cylinder with a half-sphere at each end. Height includes both round ends and must be at least twice the radius.","A simple body hitbox can have radius 1.5 and total height 5 studs."},
	{"radius","Center-to-edge distance","The distance from the center of a ball or circular part to its edge. Diameter is twice this value.","Radius 1.5 means a ball is 3 studs wide."},
	{"ray","Line check","A line from a start point to an end point. It has no thickness.","A straight instant-shot check can use a ray."},
	{"sweep","Shape checked along a path","Check a ball all along a straight line, rather than only at its final position. Other objects are held at the one saved time being checked.","A thick straight attack can use a swept sphere."},
	{"interpolation","Estimate between saved positions","If the requested time lies between two records, Chrono estimates a position between them. It refuses to guess across a large gap or an uncertain change.","Records at 10.0 and 10.05 can estimate a pose at 10.025."},
	{"coverage","Enough saved data for the requested time","Chrono has suitable records around that time and its time, change and shape checks pass. This does not prove your supplied positions were honest.","A covered check with zero contacts means a checked miss."},
	{"rewind","Check an earlier position","Use saved records from before the latest update. This is off by default and needs a timing rule supplied by your server.","Your approved timing rule may allow checking 0.08 seconds earlier."},
	{"lag compensation","Use earlier data to account for delay","A game policy that can let an input use an earlier position because messages took time to travel. Chrono does not choose a fair time automatically.","Decide how much delay your game allows before rejecting an old request."},
	{"latency","Message travel delay","The time a message takes to travel. Ping usually measures a round trip, not one direction.","50 ms each way adds about 100 ms to a round trip."},
	{"epoch","Position-record version","A number that changes when tracking is reset. Older records cannot silently be used after that reset.","A respawn starts a new version of the player's position records."},
	{"discontinuity","Approved tracking reset","A real change where earlier positions must no longer connect to later ones. Your game reports it with Discontinuity after approving the change.","Teleport, respawn, or a change in who simulates an object."},
	{"quarantine","Pause one object's recording","Chrono stops using an object's records after its data function fails or returns bad data. Fix the cause, report the approved reset, then record again.","Do not reset tracking repeatedly just to hide a faulty data function."},
	{"network ownership","Who calculates Roblox physics","Roblox can let a player's client calculate an object's physics. Reading that result on the server alone does not prove it was a legal move.","Your server still needs to check player movement used to decide competitive hits."},
	{"stud","Roblox distance unit","A unit for size and distance in Roblox Studio.","A default Part is 4 studs wide along its X axis."},
	{"hz","Updates per second (Hz)","How often something is updated each second. Chrono's rate setting sizes its storage; your script still calls Capture.","60 Hz means 60 updates in one second."},
	{"handle","Move reference returned by Chrono","The value BeginAction returns after it accepts a move. Keep it and pass it to Query and EndAction. Do not create your own table as a replacement.","local move, reason = chrono:BeginAction(playerId, profile)"},
	{"capture","Save one update","Capture asks each registered object's data function for a position record. Your game calls it after all participating objects finish the same server update.","chrono:Capture()"},
	{"query","Check a move","Query checks the move reference you kept from BeginAction. It returns allowed contacts or a reason explaining why the check could not complete.","local result = chrono:Query(move)"},
	{"profile","Settings for one move","A plain Luau table describing the shape, target types, timing, target limit and rules for a move.","The generated Actions.Contact table is one profile."},
	{"contact","One returned target","A tracked object whose saved hitbox touched the move's shape and passed the supplied rules. Your game still decides whether to apply its current result.","result.contacts[1].id is the first returned object id."},
	{"active window","Time when the move may hit","The time from opens to closes, counted after your server starts the move.","opens=0.12 and closes=0.35 allow checks from 120 to 350 ms after the start."},
	{"id","One object's name in your code","A stable short text label for a particular registered object. Keep it unique while that object is tracked.","player-12 is an id; player is its kind."},
	{"kind","Group name for similar objects","A short text label for an object type. A move's targets list uses these labels to choose which groups to check.","Register a ball with kind='ball'; use targets={'ball'} to check that group."},
	{"unverified","Data not approved for hits","The default label for positions whose server-side calculation or validation has not been established. Chrono refuses gameplay checks that need them.","Selecting a Part in Studio creates only an unverified reference."},
	{"serverSimulated","Data calculated by your server","Use this trust label only when your own server code actually calculates the positions used for hit checks.","A server-owned ball simulation supplies its position."},
	{"serverValidated","Data checked by your server","Use this trust label only after your server actually verifies the supplied positions and hitboxes against the rules your game requires.","Your existing movement checks reject impossible client moves before their data reaches Chrono."},
	{"ModuleScript","A reusable code file","A Roblox code file that returns a value when another script calls require on it. Installing the generated main module does not automatically connect it to your game.","local startChrono = require(game.ServerScriptService.ChronoV3Integration)"},
	{"boolean","True or false","A value with only two choices. Useful for saved rules such as whether a player is active or invulnerable.","state = {active=true, invulnerable=false}"},
	{"hitscan","Instant line check","Check a straight line immediately. There is no simulated bullet flying along that path over later frames.","The Instant line check preset creates a ray-shaped query."},
	{"source","Object doing the move","The registered object whose saved position and facing direction place the move's hitbox.","The tackling player is the source; the player or ball being checked is a target."},
	{"target","Object the move may touch","A registered object of a kind listed in the move's targets. Its saved hitbox is checked against the move.","A kick can target the ball kind."},
	{"jitter","Changing message delay","Messages do not all take the same time to arrive. This makes updates arrive at uneven intervals.","Studio's Network Simulator can add different jitter in each direction."},
	{"packet loss","Dropped network packets","Some small pieces of network data do not arrive. Reliable messages can be resent, which adds delay; unreliable updates may stay missing.","0.5% means half of one percent, not 50%."},
}
for _,entry in terms do table.freeze(entry) end
Help.Terms=table.freeze(terms)
local messages={
	captured={"Positions saved","The supplied positions passed the recording checks.","Continue updating the game, then call Capture again after the next update."},
	covered={"Hitbox check completed","There was enough saved data for this check. Zero returned contacts means nothing was touched.","Use the returned contacts only after checking your game's current rules."},
	capture_required={"No positions saved yet","Chrono needs a recorded starting position before it can start a move.","Register your objects with Track. Call Capture once before accepting move requests, then after each game update."},
	capture_stale={"Positions are not recent enough","The game has not saved a recent enough update for this check.","Call Capture after every required server update. Check for stopped loops or functions that wait."},
	clock_fault={"The time function failed","The clock did not return a usable number.","Use the default clock, or return time in seconds from one consistent server clock."},
	clock_reversed={"Time moved backwards","The clock is earlier than the latest saved update.","Use the same server clock for saving positions and checking moves. Do not mix different clocks."},
	invalid_capture_time={"Cannot record this time","The supplied time is too far behind the clock, in the future, or not a valid number.","Use Capture() with its default time first. For a fixed-step simulation, pass a recent server time in the same clock system."},
	non_monotonic={"This update is not newer","Chrono already saved this time or a later time.","Record once per simulation step, in increasing time order. Do not record the same step twice."},
	actor_missing={"Object is not registered","The move's source id was not found.","Call Track for this id before starting the move. Keep the same id spelling in both calls."},
	unverified_source={"The move's position is not approved","The object's data is marked unverified, so it cannot be used to decide gameplay.","Connect data your server actually calculates or validates. Only then choose the matching trust label. Changing the label alone does not validate movement."},
	unverified_target={"A target's position is not approved","One object of a target kind is marked unverified. Chrono refuses a partial result.","Supply checked data for that target kind, or correct which kinds the move should check. Selected Studio references stay unverified."},
	invalid_profile={"Move settings are not usable","A shape, distance limit, active time, target count or rule function is invalid.","Check the Actions module. Times must be ordered, dimensions positive, and maxReach large enough for the full shape."},
	target_kinds_required={"Choose which object types to check","The move needs at least one target kind.","Set targets to a list such as {\"player\", \"ball\"}. Use the kind names passed to Track."},
	invalid_target_kind={"An object type name is invalid","A target kind must be a short nonempty string.","Use the same short kind names in Track and the move's targets list."},
	world_provider_or_shape={"The obstacle check is not connected","world=true needs an obstacle-data function and a ray or moving-ball query.","Connect the world function for a sweep. For an overlap move, implement your game's obstruction rule. Do not disable an obstacle rule just to make a failed check pass."},
	rewind_rejected={"The earlier check time was refused","Your server timing function failed or requested more time than allowed.","Return a delay between zero and maxRewind from your server timing rule. Check request age and never trust a client's time without validation."},
	action_capacity={"Too many moves are still open","This object or service has reached its limit for open move references.","Call EndAction when a move ends or is cancelled. Continue Capture so old moves are removed."},
	invalid_action={"The move reference is no longer valid","It was ended, removed, expired, or was not created by this Chrono instance.","Keep the value BeginAction returns. Start a new move only after your server accepts a new move request."},
	roster_changed={"The tracked object list changed","An object was added or removed after this move started. This version cancels older move references for safety.","End the old move. Let your game decide whether a new move can start after the next saved update."},
	source_epoch_changed={"The moving object was reset","A teleport, respawn or data error changed its position-record version.","End the old move. Fix data errors if present, save the new position, then let your server authorize another move."},
	not_active={"It is too early for this move to hit","The move's hit period has not started yet.","Keep saving positions. Query again during opens to closes, or correct those times in Actions."},
	action_expired={"The move's hit period has ended","This move can no longer return a contact.","Call EndAction. Start a new move only when your game authorizes one."},
	duplicate_query={"This update was already checked","This move already completed a check using the latest saved update.","Wait for your game's next update and Capture before querying this move again. Do not apply the same result twice."},
	action_spent={"The move reached its contact limit","It already returned the total number of targets allowed for this move.","End this move or wait for its normal cancellation. Change maxTargets only if your game is meant to allow more contacts."},
	shape_out_of_bounds={"The hitbox is outside the supported range","The shape could not be placed safely at the recorded root position.","Check its position, size and distance from the root. Very large map coordinates also need a precision review."},
	world_unknown={"Obstacle data is missing or uncertain","The optional obstacle function could not prove what was clear or blocked at this time.","Check your world function and its saved obstacle data. It must report covered, blocked and fraction. Include a check for starting inside an obstacle."},
	rules_fault={"The target rule function failed","eligible must finish immediately and return exactly true or false.","Check the function in Actions. Remove waiting calls and fix its errors. Save needed rule values in the snapshot state."},
	capture_fault={"Some positions were not saved","One or more object functions failed or returned unusable data. See the faults list for object ids and reasons.","Explain each item in result.faults. Fix its cause, then report an approved tracking reset for that object."},
	provider_fault={"The position function failed","The function given to Track threw an error or tried to wait.","Check that function for errors. Return root, zones and state immediately. Do not use task.wait or wait for events inside it."},
	quarantined={"Recording for this object is paused","An earlier position function failed. Chrono keeps refusing it until you deliberately reset tracking.","Find and fix the first error. Then call Discontinuity for that object and Capture again. Do not reset every frame."},
	invalid_snapshot={"The position record is not usable","The supplied table or a value it contains could not be read safely.","Return a plain table with root=CFrame, zones={...}, and optional flat state={...}. Check the data function for errors."},
	invalid_state={"Saved game values are not usable","State must contain only true/false values, finite numbers or short text, with string keys.","Save values such as team=2 and active=true. Do not save Instances, nested tables or NaN numbers in state."},
	invalid_zones={"The hitbox list is not usable","There are too many zones or a zone name is invalid.","Return 1 to 32 named shapes. Zone names must be strings up to 64 bytes."},
	invalid_zone={"One hitbox is not usable","A target zone must be a valid box, sphere or capsule.","Build it with Core.Shapes.Box, Sphere or Capsule. Check frame, size, radius and height."},
	empty_zones={"The object has no hitbox","At least one target shape is required in each saved record.","Return a named hitbox in zones, such as zones={Body=S.Sphere(frame,1)}."},
	zone_out_of_bounds={"A hitbox is too far from its object","Its root-to-shape distance plus full outside extent exceeds maxRadius.","Check the world-space hitbox position. Increase maxRadius only to match the real maximum extent your game allows."},
	speed_bound={"The object moved farther than allowed","The root travelled farther than maxSpeed allows between saved updates.","Check your movement data and speed setting. For a game-approved teleport, explicitly reset tracking. Do not raise the limit to accept unexplained movement."},
	empty={"No position records are available","There is no usable record for this object yet.","Track it, supply a valid position function and call Capture before querying it."},
	too_old={"The requested position was not kept","The requested time is before the oldest stored record.","Use a more recent approved time. Check seconds, rate, capture frequency and how long messages are delayed."},
	not_recorded={"That time has not been recorded","The requested time is later than this object's latest saved position.","Check provider faults and simulation order. Capture the shared game update before querying it."},
	expired={"The requested time is too old","The requested time exceeds the configured age limit.","Reject or retry according to your game rules. Only increase the age limit after choosing a fair delay policy."},
	future={"The requested time is in the future","The requested position is later than the server's current clock.","Use a consistent server clock and validate any client-reported times."},
	invalid_time={"The time value is not usable","A time is not a finite number.","Pass time in seconds from the same server clock used by Capture."},
	epoch_changed={"Earlier position records were reset","The requested exact record belongs to an older tracking version.","Do not use records from before a teleport, respawn or approved reset. Capture the new state before a new move."},
	discontinuity={"The requested time crosses a reset","Chrono cannot connect records across a teleport, respawn or tracking failure.","Use a time wholly within the current tracking version. Do not guess a path through the reset."},
	sample_gap={"Saved positions are too far apart","There is too much missing time between the two records needed for this check.","Check capture frequency and stalled updates. Refuse the uncertain check rather than treating it as a miss or a hit."},
	state_boundary={"A game value changed between records","For example, invulnerability changed between the two saved times. Chrono cannot prove its value at the requested time.","Record transitions at their actual server time. Expect uncertain in-between requests to be refused."},
	geometry_boundary={"A hitbox changed between records","A zone was added, removed, resized or changed shape between those times.","Record shape changes at their actual time. Do not interpolate a different shape through the change."},
}
for _,entry in messages do table.freeze(entry) end
Help.Messages=table.freeze(messages)
function Help.Explain(value)
	local code=if type(value)=="table" then value.reason else value
	if type(code)~="string" then code="unknown" end
	local key,subject=code,nil
	if code:sub(1,7)=="source_" and messages[code]==nil then key=code:sub(8) subject="Object doing the move"
	elseif code:sub(1,7)=="target_" and messages[code]==nil then key=code:sub(8) subject="Possible target" end
	local entry=messages[key]
	return table.freeze({code=code,known=entry~=nil,subject=subject,
		title=if entry then entry[1] else "More information is needed",
		meaning=if entry then entry[2] else "This message is not in the built-in help list. Keep the original code when reporting it.",
		fix=if entry then entry[3] else "Check Studio Output and the documentation. Include the original message and a small example when asking for help."})
end
function Help.FindTerms(query)
	local result={} local q=string.lower(if type(query)=="string" then query else "")
	for _,entry in terms do if q=="" or (string.lower(table.concat(entry," "))):find(q,1,true) then table.insert(result,entry) end end
	return result
end
return table.freeze(Help)
