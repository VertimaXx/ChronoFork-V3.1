# Reproduce the preview checks

## Build and static checks

Run from the repository root with Python 3.10+:

```
python tools/full_build.py
python tools/full_check.py --compiler /path/to/luau-compile
```

The preview builder writes only `dist-preview`. It does not rewrite the existing
V3.2 release assets, documentation website or historical benchmark labels. Static
checks verify the pinned upstream hashes, original module/function presence,
packaged require paths, duplicate instance paths and Luau syntax in all models.

## Studio mathematical/robustness tests

Use a disposable copy of the place. Import `ChronoForkTests.rbxmx` under
ServerStorage. Disable unrelated test scripts temporarily and retain their original
enabled states. In Play's server context:

```lua
local fixture = game.ServerStorage.ChronoForkValidation
local results = require(fixture.Tests.Suite).Run(fixture)
local replay = require(fixture.Tests.TransportReplay).Run(fixture)
print(game.HttpService:JSONEncode({suite=results,replay=replay}))
```

The suite yields during its campaigns. It uses real Roblox `CFrame`, `Vector3`,
`buffer` and module behavior. The transport replay is explicitly synthetic; it
does not stand in for Studio network simulation or real cross-region clients.

## Installer checks

Run `Tests.EditorSuite` in Edit mode using fresh cloned Editor modules. It checks
configuration types/ranges, missing engine confirmation, conflicts, private
backups, added/edited object protection and removal. The automated suite injects a
history/source writer for deterministic failure testing. The real source writer
and supplied startup scripts were also exercised separately in Studio.

Studio MCP wraps edits in its own Undo recording, so attempting a nested production
`TryBeginRecording` correctly returns no recording. For that tool path, the outer
recording is used. Native plugin-button Undo/Redo interaction remains a separate
manual release gate; it has not been claimed proven by the injected unit test.

## Matched live original/fork fixture

Use a fresh Play session for each build/profile. Do not run both on the same objects.

```lua
local fixture = game.ServerStorage.ChronoForkValidation
-- false = full fork, true = exact pinned original
local test = require(fixture.Tests.ReplicationSmoke).Start(fixture, false)
```

The eight-second server schedule uses the same six objects, configured send rate,
movement, model modes, data, mount/unmount, owner handoff and teleport for each
build. The client records receipt metrics and reports. Run with these Studio
network settings (values are per direction):

| Profile | In/out delay ms | In/out jitter ms | In/out loss % |
|---|---|---|---|
| Zero added impairment | 0 / 0 | 0 / 0 | 0 / 0 |
| Nominal 150 ms total delay | 75 / 75 | 0 / 0 | 0 / 0 |
| Asymmetric/jittery | 150 / 180 | 70 / 90 | 0.5 / 0.5 |
| Severe | 400 / 500 | 120 / 150 | 2 / 2 |

The fixture's fork uses Segment drawing; the original uses its native Hermite.
Both use the same requested movement send rate. Actual scheduling and arrival
counts are recorded, not assumed equal. These are single-client functional smoke
runs, not a statistically powered rendering or fairness benchmark.

`Metrics` counts received state **buffer payloads**. It excludes lifecycle tables,
engine/native physics traffic, remote framing and compression. Never label this
measurement total network bandwidth. Server counters are last reporting intervals,
not the whole run.

Restore the original network settings after testing, restore every saved script
state, stop Play and remove only the disposable fixtures. The development session
followed that cleanup procedure; it did not save/publish the place or replace the
user's installed plugin.

## Experimental prediction integration

Use the rebuilt preview fixture in a fresh Play session. Run
`require(fixture.Tests.PredictionIntegrationSuite).Run(fixture)` for packaged
configuration, opt-in defaults, lifecycle resets and history separation. The
existing `EditorSuite` also checks all 46 setup controls and rejects experimental
drawing without the main switch or in Engine mode.

Run `ReplicationSmoke.Start(fixture, false, true)` to explicitly enable the
experimental service and drawing in the same six-object functional fixture;
leave out the third argument for the default-off check. Use a new Play session
for each. Client reports count experimental/predicted drawing samples; the server
reports accepted source clocks and model states. These checks are not additional
fairness/accuracy benchmarks. See `validation/prediction-integration.json`.
