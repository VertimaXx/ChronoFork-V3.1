# ChronoFork full-runtime preview

**Development version 3.3.0-dev. Not a published release or a production certification.**

This branch restores original Chrono's movement replication alongside ChronoFork's
competitive contact library. It is an unofficial fork of Parihsz/Chrono, developed
with OpenAI Codex / AI under VertimaXx's direction. The original MIT notice and the
exact upstream source are included.

## What the two parts do

**Movement replication** shares positions between the server and players and draws
other objects smoothly. This restores `Start`, `Entity`, ownership, model modes,
mounting, player registration, filtering, clocks and statistics from original
Chrono. A smooth displayed position can still be delayed or estimated.

**Competitive checks** answer whether supplied hitbox shapes touched, using covered
server records. Your game still approves a move and decides possession, damage,
stun or another outcome. The existing Core 3.1 and Connector 3.2 remain unchanged.
The preview also includes separate records with source grades, authored pose zones,
continuous-motion helpers, historical obstacles and outcome/conflict helpers.

These are separate jobs. Receiving a player's position does not prove that their
movement was allowed. Drawing an object closer to its apparent current position
does not make that drawing a trustworthy server position.

## Install through the supplied plugin

1. Back up the place. Import `dist-preview/ChronoForkSetup.rbxmx` and save its full
   `ChronoForkSetup` Script, including its children, as a local Studio plugin.
2. Open **Plugins → ChronoFork → ChronoSetup**. Choose the movement mode, players
   and other objects, drawing settings and network settings. Each control explains
   its term and its effect. Decimal comma and decimal point inputs are accepted.
3. Open **Review → Check settings and show changes**. Read the generated settings,
   then install that reviewed package. Existing game scripts are not rewritten.
4. Press Play. Check Output and **F4**. Server statistics and test controls are
   restricted to Studio testers and the developer IDs you explicitly listed.
5. For gameplay contact checks, open **ChronoConnect**. The supplied contact wizard
   creates the recording, events, generated calls, timing and outcome connections.
   Its existing V3.2 controls remain available.

The movement installer adds a package in ReplicatedStorage, one server startup
Script, one client startup LocalScript and a private server installation record.
The private record stores exact sources for safe removal; those backups are not
sent to every player.

**ChronoSetup → Experimental** contains the very experimental prediction controls.
The main switch and the separate remote-drawing switch both default to Off.
The 13 controls explain limits and timing assumptions. See the
[prediction guide](prediction.md) before enabling it. This feature does not
provide trusted movement, move the server character or decide damage.

**Simple movement replication needs no separately invented helper code.** Ordinary
settings use the plugin. Game-specific behavior belongs in the supplied `Hooks`,
contact `Actions`, `Hooks` and provider modules. If the game has no suitable server
movement checker or shared controller, installation does not invent one or silently
declare client movement safe.

## Choosing a mode

| Choice | Meaning | Work your game may still need |
|---|---|---|
| Chrono replication / Legacy | Original-compatible transform replication and drawing | Your existing move approval, movement validation and outcomes |
| Roblox server simulation / Engine | Runs your shared simulation hook using `BindToSimulation` | A suitable shared controller and Roblox's Workspace server-authority settings |

Engine mode is an adapter, not an automatic conversion of an arbitrary game's
controller. Roblox restricts reading `Workspace.AuthorityMode` from ordinary scripts,
so the plugin requires an explicit settings confirmation. This branch has not yet
passed a real rollback/prediction campaign in an engine-authority place.

Do not run two position drivers on the same objects. The installer blocks a second
managed automatic-player package; it cannot identify every custom movement script
you might already have.

## What is kept inside the package

- `Settings`: generated movement/network options.
- `Hooks.Configure`: register additional object types and model templates.
- `Hooks.Connected` / `Disconnected`: game-specific ownership and hand-back rules.
- `Hooks.Simulate`: the shared controller hook for Engine mode.
- `Models`: your optional model templates.
- `Replication`: the complete active fork of the original runtime.
- `Competitive`: additional evidence, pose, motion, obstacle and outcome helpers.
- `Core`: unchanged competitive Core 3.1.

The contact wizard remains the existing Core/Connector workflow. The additional
`Competitive` helpers are advanced in-package APIs; they are not all automatically
wired into the existing contact wizard. In particular, a game's authored pose
timeline and continuous-motion policy need explicit connections and validation.

## Remove or change an installation

Stop Play first. Studio Undo can undo installation. The plugin's **Remove selected
unchanged installation** checks exact installed sources, moved/renamed objects and
newly added objects. It refuses removal when doing so would discard those edits.
Back up and review edited packages instead of forcing deletion.

Removing a replication tag uses a keep-model removal message, so clients do not
hide a surviving native model as if it had despawned. Custom originals return to
their previous parent. Use `Hooks.Disconnected` for your game's ownership hand-back
rules. Full runtime shutdown/reconfiguration requires stopping the Play session.

## Read next

- [Architecture and compatibility](architecture.md)
- [Math, assumptions and remaining limits](math-and-limits.md)
- [Validation and original comparison](validation.md)
- [Reproduce the tests](reproduce.md)
- [Current release gates](../../IMPLEMENTATION.md)
