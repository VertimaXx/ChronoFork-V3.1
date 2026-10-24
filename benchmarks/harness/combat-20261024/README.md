# Existing-game QA drivers: 24 October 2026

These four scripts produced the [recorded combat integration cases](../../data/v3.1-combat-integration-2026-10-24.json). They are **fixture-dependent inspection/reproduction material**, not a generic test installer. They are not included as enabled scripts in any shipped Studio model. They deliberately move characters, fire the game's real combat remotes and apply test damage. Use a disposable local copy only.

The original third-party game and original HitDetection baseline are not redistributed. Its existing R6 rigs, character/remotes hierarchy, damage handler, assets, animations, movement tags and ragdoll system must already be present. The [combat walkthrough](../../../docs/combat-walkthrough.md) describes the tested connection.

## Fixture arrangement

Before Play, the recorded run used these temporary objects:

- `ServerScriptService.__ChronoWorkflowQA`: Folder containing an untouched original `Baseline` HitDetection ModuleScript and a server Script with `Workflow.server.luau`.
- `ReplicatedStorage.__ChronoWorkflowQA`: Folder used for server-authored Phase, Case, Done and client acknowledgement attributes, with a `Result` StringValue.
- `ReplicatedStorage.__ChronoWorkflowAck`: RemoteEvent for the disposable input driver's acknowledgement.
- `StarterPlayer.StarterPlayerScripts.__ChronoWorkflowInput`: LocalScript with `Workflow.client.luau`.
- `ServerScriptService.__ChronoFlowRun`: server Script with `MovementFlow.server.luau`.
- `ReplicatedStorage.__ChronoFlowQA`: Folder with a `Finish` RemoteEvent and `Result` StringValue; server-authored Walk, Jump and Done attributes coordinate the movement driver.
- `StarterPlayer.StarterPlayerScripts.__ChronoFlowInput`: LocalScript with `MovementFlow.client.luau`.

Use the existing original baseline saved **before** applying the generated calls. The installed connection group is `ServerScriptService.CombatChrono`. It must use the tested settings and customized Hooks, with practice disabled. The game must contain `Workspace.Characters.Rig`, the normal playable character pipeline and `ServerStorage.Requests.DamageHumanoid`. Inspect every referenced asset/property in the drivers before running against a different game.

Start one local Studio client. The movement phase waits for the workflow phase's Done attribute. Read the two Result StringValues, the supplied connection report and actual game outcomes. An error or different count is new evidence; do not rewrite the archived passing JSON. The parity generator uses seed **241031** and 48 randomized geometry cases in addition to its 11 named cases.

Stop Play, remove all temporary objects above and any test leftovers, and leave the editor in Edit mode. The recorded completed place contained no temporary `__Chrono` objects. The final installed 27-source compilation was a separate source-snapshot check. It is not reproduced merely by running these four drivers.

## Interpretation

The workflow driver compares original and connected behavior, then exercises the game's actual input channel and Chrono's rejection paths. The movement drivers check that selected legitimate existing movement remains accepted. They measure minimum health reached to avoid confusing passive health regeneration with damage. A fresh present-time query after a reset may use the new state; the reset refusal case concerns reusing an already-cached contact.

These drivers are specific to the tested game. They do not prove universal movement security, trusted animation, multiplayer correctness or network-delay performance. All six native network impairment settings were zero. The earlier original-Chrono benchmark remains a separate, explicitly labeled experiment.
