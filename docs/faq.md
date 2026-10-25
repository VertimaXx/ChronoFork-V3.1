# Frequently asked questions

## Is this an official upstream Chrono release?

No. **ChronoFork V3.2** is this unofficial branch's current package: Connector/plugin 3.2 and unchanged Core 3.1. [Parihsz/Chrono](https://github.com/Parihsz/Chrono) is the original project. Upstream credit, AI assistance and the MIT notice are preserved in [CREDITS.md](../CREDITS.md).

## Will it make every competitive game accurate after one click?

The setup plugin creates connecting code and explains it. Your server must still supply checked positions, accept valid moves and apply game-specific results. No tool can safely infer all of another game's rules from selected parts.

## Do I need guns or a Humanoid?

No. Actors are string ids with root frames, named gameplay shapes and simple state. A tackle, ball, sword move or custom character can use the same API. Obstacles and outcomes depend on your game's rules.

## Do I have to replace my movement, animation or VFX?

The package does not replace them. Connect your existing server events. Exact animated limb checks need checked pose data, while a deliberate root-relative gameplay box can represent a move without matching every visible vertex.

## Does setting trust to serverValidated check movement?

No. The label describes validation your code already performs. Reading a client-owned part from a server Script is not a movement validator.

## Can I enable lag compensation through the plugin?

Yes. Choose measured-ping or provider timing, set a positive maximum lookback within saved history, and use targets returned by Chrono through Resolve/Query. Present is the default. maxRewind alone only sets a ceiling. A gate after a present-part target search cannot discover missing historical targets. See [Timing controls](connector-controls.md#earlier-positions).

## Can one move check more than once?

Yes. Choose Repeated globally or per move. Later captures can produce new targets during the active window. A target is returned at most once, and the target cap spans the whole move. Use separate accepted moves for deliberate repeated hits on the same target.

## Does the game need Parts or an automatic recording loop?

No. Data-only objects can use a registry or generated Track/Untrack calls. Manual/Event recording and a shared clock can follow an existing server simulation. The plugin supplies the connection path; it does not create a simulation your game lacks.

## What is history?

A short record of earlier object positions, shapes and game values. The library can check an earlier instant only when the record actually covers it and all other checks pass.

## What does authoritative mean?

The server calculates or checks the value used to decide gameplay. The plugin and handbook explain the word as “server decides.”

## Is a refusal the same as a miss?

No. `ok=true` with no contacts is a checked miss. `ok=false` means the check could not safely complete. Use `Core.Explain(result)` to get a readable reason and suggested fix; log the original reason code too.

## Why are some otherwise harmless queries refused?

The design deliberately refuses uncertainty: all matching actors need covered trusted records, state/shape transitions can block interpolation, provider errors pause evidence, and roster changes invalidate active moves. Read [limitations](math-and-limits.md) before choosing this policy.

## Is the practice test real integration or a ping test?

No. It uses made-up server data and an immediate hit period. Passing proves that the generated example works, not that your real game is connected or that network conditions were tested.

## Is it faster or universally more accurate than original Chrono?

No universal claim is supported. The earlier checked-history microbenchmark took about 2.67 times the original query CPU time and eliminated endpoint overshoot in a deliberately linear test. Their jobs and validation work differ. See [comparison](comparison.md).

## Why do the plugin and code still say Chrono V3?

Existing toolbar, object and method names remain compatible. Core's `Version` remains `3.1.0`. Connector/plugin are now `3.2.0`; the repository URL retains ChronoFork-V3.1. See [full plugin controls and upgrade steps](connector-controls.md). Historical benchmarks keep their original version labels.

## Where are V1 and V2?

Not in this source release. The comparison page has a labeled historical appendix and selected archived data. Those results are never counted as V3.1 tests.
