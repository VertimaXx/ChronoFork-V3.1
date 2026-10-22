# Your first Chrono V3 connection

You can use ordinary Luau functions and tables. You do not need to learn another programming language. Keep the real code names beside the plain meanings below so you can find them in Studio.

## First understand the three jobs

**Your game supplies the data.** A function returns the main position, hitboxes and small rule values for a player, ball or other object. The server must calculate or check data used to decide competitive hits.

**Chrono checks contacts.** It saves a short list of earlier values. That list is called **history**. One entry at one time is a **snapshot**. It checks a move against suitable saved data and returns contacts or a reason for refusing the check.

**Your game applies the result.** It checks current rules and decides who gets the ball, who takes damage or whether a stun happens. The library does not know your football, combat or ability rules automatically.

## Install from scratch

1. Download the ZIP and extract it.
2. Open your game in Studio.
3. Open Explorer and Properties using the Window menu if they are hidden.
4. Right-click ServerStorage in Explorer → Insert from File → choose ChronoV3Setup.rbxmx.
5. Right-click the inserted ChronoV3Setup Script → Save as Local Plugin. Remove the imported Script after saving the plugin.
6. Open Plugins → Chrono V3 → ChronoSetup.
7. Complete the six setup pages and your game-specific connections. The next sections explain that work.
8. Playtest normal cases and failures, including real network delays.
9. Save and publish the game when your own checks pass. Players receive the game code; they do not install the plugin.

If you prefer code, import ChronoV3.rbxmx into ServerStorage and require that ModuleScript directly. The plugin is an optional helper.

## Follow the six pages

**1 — Choose an example.** Sports starts with a body-shaped tackle volume; melee with a box; instant line check with a ray. A ray is a straight line with no thickness. These are starting settings, not finished moves for your game.

**2 — Choose objects.** Name the added code and choose a **kind**, the short type name your scripts use. For example, each player can have kind `player` and the football kind `ball`. Different objects still need different ids such as `player-12` and `match-ball`.

Selected Studio references are only links. They do not make an object trusted. **Authoritative** means your server makes or checks the values used to decide a hit. If a client's movement is unvalidated, giving it the label `serverValidated` does not fix that problem.

The movement limits are under More settings. Speed is in studs per second. A stud is Roblox's distance unit. The farthest hitbox edge limit includes both the hitbox's size and its offset from the main position.

**3 — Build a hitbox.** Choose an invisible shape. A sphere is a ball. A capsule is a cylinder with round ends; its total height includes those ends. A sweep checks a ball all along a straight path. The picture is scaled to fit and does not change the map.

Enter when the move can hit. `opens=0.12` means wait 0.12 seconds after your server starts it. `closes=0.35` means stop at 0.35 seconds from the same start. The hit period is 0.23 seconds. Milliseconds are thousandths of a second: 0.12 seconds = 120 ms. Decimal points and decimal commas are accepted in number fields: 1.5 and 1,5 both mean one and a half. Do not use thousands separators.

**4 — Choose game rules.** The supplied team rule needs `state.active` and `state.team`. Add your real immunity, possession and round rules. Earlier-position checks are optional; start with the present time. **Rewind** means asking for an earlier saved position. It needs a timing rule supplied by your server, not just a larger number in Settings.

**5 — Check and add code.** Fix any listed fields. Each problem button takes you to its field. Review the destination and what will be added. Existing code is kept. The optional generated-code viewer lets you copy the exact text. Add the reviewed code only after checking it.

**6 — Connect and test.** Open RunPractice, then Bindings and Actions. The plugin can select and open these files. The following section explains the practice test.

## Run a complete example before connecting your game

1. In Explorer, expand ServerScriptService → the name you chose (default ChronoV3Integration).
2. Select RunPractice. In Properties, turn Enabled on.
3. Press Play. Read Output for **Chrono V3 practice: Practice passed**.
4. Stop Play. Turn RunPractice off again, or remove it when finished learning.

RunPractice calls the Practice module using made-up server values. It uses your selected shape and rule with an immediate hit period. It expects one contact and then checks that repeating the same move check is refused. It creates no map objects and does not run in a published game.

**Practice passing does not mean your real game is connected.** It also does not check your real move timing, movement validation or network traffic. It gives you a small working example to read and change.

## The four real connections

### 1. Supply an object's data

Your server startup requires the added main module and calls the returned function once:

```luau
local start = require(game.ServerScriptService.ChronoV3Integration)
local kit = start()
local chrono = kit.Chrono
-- Keep kit for the life of this game session. Do not create a new kit every frame.
```

If you used a name with spaces, use brackets, for example `game.ServerScriptService["Football contact"]`.

Your registration function supplies a table with three parts:

```luau
{
    root = mainPositionAndDirection, -- a CFrame value
    zones = {Body = bodyShape},      -- named shapes at their positions in the map
    state = {active=true, team=2},   -- simple values needed by your rules
}
```

`root` is the main position and facing direction. It need not be a Part named HumanoidRootPart. `zones` holds gameplay hitboxes. `state` holds true/false, numbers and short text. Do not put Instances or nested tables in state. All values must describe the same moment.

Read the comments in Bindings. Choose `serverSimulated` only for values your server actually calculates, or `serverValidated` only after it checks them against your real rules. The default `unverified` prevents these positions from deciding gameplay hits.

### 2. Save each shared update

Call `chrono:Capture()` after all participating server objects finish the same update. Call it once before accepting moves and then after each update your hit system needs. Capture asks each registered object's data function for a record. It does not run your movement code for you.

If your game uses a fixed simulation clock, see the exact API before passing explicit times. Keep all times in the same server clock system.

### 3. Connect a move's start, checks and end

Your existing server code first checks the player's request: cooldown, stamina, possession, round state and repeated requests. Only after that should it call:

```luau
local move, reason = chrono:BeginAction(playerId, kit.Actions.Contact)
```

Keep `move`, the returned **handle** or move reference. During the hit period, use `chrono:Query(move)`. When the move ends or is cancelled, use `chrono:EndAction(move)`. A new table is not a substitute for a move reference. A new move reference is not a substitute for validating a repeated client request.

### 4. Apply your game result

```luau
local result = chrono:Query(move)
if not result.ok then
    local help = kit.Explain(result)
    warn(help.title .. ": " .. help.fix)
    return
end

for _,contact in result.contacts do
    -- Recheck your CURRENT game rules.
    -- Apply possession, damage or another result once, using contact.id.
end
```

The comments above are the part your own game implements. Chrono does not include a universal possession or damage function. Your existing move events can keep driving animations, effects and cutscenes.

An empty contact list after a successful check is a checked miss. A refused check is not a miss: Chrono could not safely complete it. It returns no partial contacts. One move returns each target at most once, but your code must still avoid applying one result twice.

## Teleports, respawns and errors

When your game approves a teleport, respawn or change in who calculates an object's physics, call `Discontinuity(id, reason)`. This resets the position-record version, called an **epoch**. Earlier records cannot silently join later ones across that reset.

Use `Untrack(id)` when an object is removed. Adding or removing any tracked object currently invalidates older move references globally. Your game chooses whether a new move may start.

If a position function fails, Chrono pauses that object's recording. This is called **quarantine**. Fix the cause, report the approved reset and record again. Do not reset every frame to hide an error. Use `Core.Explain(reason)` or Words & errors for an explanation and next step.

## Test the actual game

Try hits, misses, moving targets, teammates, immunity, cancelled moves, repeated input, joins/leaves, respawn and teleports. Make sure your game applies results once. Check refusal reasons rather than treating every refusal as a miss.

Use Studio's Network Simulator for the actual messages between your client and server. Start with all six values set to zero. Then add inbound and outbound delay, jitter (changing delay) and loss. Check the values after changing a preset; presets can add delay. The included synthetic timeline tests do not replace these game-specific playtests.

If a wall should stop a tackle, you must supply that game rule. Optional historical-obstacle checks support rays and moving-ball sweeps; they do not automatically solve overlap obstruction. Exact animated limb hitboxes also need a server-calculated or server-checked pose function.

## Need more detail?

- [the searchable handbook](../site/start-here.html) has searchable words and result messages.
- [integration.md](integration.md) lists exact API values and limits.
- [math-and-limits.md](math-and-limits.md) explains the calculations and remaining limits.
- SportsAdapter.luau shows where existing server services can connect. Its ActorService, MoveService and BallService names are examples of **your game code**, not Roblox services created by the plugin.
