# Connect your game through the plugin

**Current package: Connector/plugin 3.2.0, using unchanged Core 3.1.0.** The plugin supplies tracking, recording, move references, contact checks, cancellation and outcome delivery. Your game supplies its real data and rules. Customize unusual mappings inside the delivered Hooks, Actions or provider files.

For every control and limit, use [Full plugin controls](connector-controls.md). For an earlier real-game example, see the [dated combat walkthrough](combat-walkthrough.md). That example used the 24 October 3.1 build and present-time gating; it is not evidence that the new timing policies were tested in that combat game.

## First success without scripting

Open **Plugins → Chrono V3 → ChronoSetup → Try a complete supplied learning scene**. Press Play. Two anchored objects use supplied server events to start a move, check contact and increase a practice counter. Open the **Chrono connections | Studio** guide for real counters.

Stop Play and remove the scene using **ChronoConnect → Test & restore → Remove the supplied learning scene**. The scene does not certify your game. The separate RunPractice test also uses made-up data; it does not exercise your network or existing combat.

## Connect an existing game

1. In ChronoSetup, describe an initial attack and recording limits. Review and add the named code group. Match the real game's timing and dimensions.
2. Open ChronoConnect and choose the installed group. On **Objects**, choose players, extra objects, folder, tag, references or pure server data. Set kind names such as fighter and ball.
3. Choose a position source. Server physics requires genuinely server-owned/anchored roots. The supplied humanoid checker covers bounded ordinary static-ground movement. Use a position provider for other independently checked/calculated movement.
4. On **Bodies**, optionally create named target areas. On **Moves**, keep Actions or configure several moves with dimensions, offsets, rotations, target rules and check modes.
5. Review **Timing** and **Recording**. Present/Heartbeat/Once is the simplest starting policy. Earlier-position, repeated and custom-simulation paths are explicit options.
6. Return to Objects, check the proposed changes and add the reviewed connections. Enabled server startup is supplied. No client gameplay RemoteEvent is installed.
7. Connect accepted moves, hit moments, cancellations and outcomes through **Events** or **Calls**. Press Play and inspect actual game results as well as the report.

Save settings after later changes and restart Play. Changing settings keeps customized Hooks and Actions. Opening the UI does not silently replace an installed runtime.

## Existing server events

Use BindableEvents only after your game authenticates requests and checks cooldown, stamina, ownership and other move rules. Raw RemoteEvents are refused by setup.

| Link | Default arguments |
|---|---|
| Begin | source object or data id, action name, move key, checked server context |
| Query | source object or data id, same move key |
| Cancel | source object or data id, same move key |
| Outcome | source, target, action name, server context, contact |
| Capture | Optional simulation timestamp; used by Event recording |

Action defaults to Contact. Reusing an active key refuses another start. Adapt unusual event arguments inside Hooks.ReadBegin / ReadQuery / ReadCancel / ApplyOutcome. Keep existing block, parry, damage, possession and effects in the outcome handler.

Automatic checking is optional. Once checks at the first eligible recorded update; Repeated checks again at later updates during the active window. Whole-move duplicate prevention and target limits still apply. Automatic delivery requires an Outcome event and correct cancellation.

## Existing functions and generated calls

Calls generates reviewed insertions at the variable names and script line you choose. The plugin preserves an exact Restore record and refuses an outdated preview. It does not guess which private game function authorizes a move.

| Call | Purpose |
|---|---|
| Begin | Start after the game accepts a move; keep its returned reference |
| Gate / Allows | Approve an already-found target immediately before its existing outcome |
| Query | Return Chrono contacts for your existing outcome loop |
| Resolve | Deliver Chrono contacts through Outcome / OnContact |
| Cancel / Finish | Stop the reference on every relevant exit |
| Capture | Save a completed common simulation step in Manual mode |
| Track / Untrack | Register/remove a stable pure-data id |
| Reset / Discontinuity | Separate records across an approved data reset or repaired provider |
| Motion | Allow the supplied humanoid checker to account for an existing approved velocity/duration |
| Teleport | Perform an approved physical teleport and reset history; replaces the selected old teleport statement |
| Inspect / Destroy | Read server diagnostics / deliberately stop this connection instance |

**Earlier timing needs Chrono candidates.** A Gate after an existing present-time overlap cannot discover a target that overlap missed. Choose Resolve or Query contacts when enabling compensation. The UI records this integration requirement; it cannot prove an arbitrary script followed it.

Once allows one successful query. Repeated allows later captures for the same active move, without returning any target twice. The target cap applies to the entire move. A pending fresh Query result can be delivered through Allows or Resolve; do not apply the same outcome through multiple paths.

## Customize inside the package

- **ConnectionData / Connections:** saved settings and their reader. Prefer saving values through the plugin.
- **Actions or Moves builder:** named attack profiles, shape, targets, active window, reach and rules.
- **Hooks.State / CanStart / CanApply:** your existing game-state and eligibility rules.
- **Hooks.MovementLimits / RecordingLimits:** permitted movement and per-object recording bounds.
- **Hooks.ProviderSnapshot / TimingPlayer:** map your position checker and data-object ownership.
- **Hooks.ReadBegin / ReadQuery / ReadCancel / ApplyOutcome / OnContact:** existing event arguments and outcome delivery.
- **Provider templates:** position approval, data registry, clock, timing and obstacle providers. Add/open these through Test & restore.
- **Connector:** supplied machinery. Routine integration should not require replacing it.

Do not start the low-level constructor as a second service when Connector is active. Use one connection group for interacting actors. Multiple independent humanoid checkers do not share impulse/teleport permissions.

## Upgrade, inspect and restore

Use **Test & restore → Upgrade supplied Connector** for an existing group. Upgrade preserves custom Hooks/Actions and refuses an edited Connector or added runtime extension. An unchanged supplied guide updates to show current policies; a customized guide is kept. Legacy Present/Once and recording-limit behavior remain until deliberately reviewed.

The report and Studio guide show effective timing, lookback, recording, check mode, obstacle status, counters and explanations. Counters distinguish permitted outcomes from actual successful damage. Read reports instead of starting another runtime through debugging tools with separate module caches.

Studio Undo/Redo covers owned objects and settings. Generated script edits also have explicit exact-text Restore; restore later edits first. A newer custom edit is protected. Removing supplied connections refuses customized source and leaves Core/Actions.

## What the validation establishes

The 25 October 3.2 campaign passed **550 checks**: 222 expanded runtime (including 160 randomized comparisons against unchanged Core), 165 existing connection checks, 63 Core tests, 61 expanded editor checks and 39 existing editor checks.

The actual View was reviewed in a Play client at narrow/wider widths, with real timing-mode and Add move clicks. Native toolbar clicking was not claimed. Tests used one Studio workstation/client and deterministic scenarios, not a new native-network or original-Chrono performance benchmark.

Inspect [raw cases, hashes and scope](../benchmarks/data/v3.2-connector-2026-10-25.json), [reproduction](benchmarks.md), [all controls](connector-controls.md) and [remaining limits](math-and-limits.md).

