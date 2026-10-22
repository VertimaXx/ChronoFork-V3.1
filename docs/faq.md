# Frequently asked questions

## Is this official Chrono 3.1?

No. **ChronoFork V3.1** names this unofficial competitive branch. [Parihsz/Chrono](https://github.com/Parihsz/Chrono) is the original project. Upstream credit and the MIT notice are preserved. AI assistance is credited in [CREDITS.md](../CREDITS.md).

## Will it make every competitive game accurate after one click?

The setup plugin creates connecting code and explains it. Your server must still supply checked positions, accept valid moves and apply game-specific results. No tool can safely infer all of another game's rules from selected parts.

## Do I need guns or a Humanoid?

No. Actors are string ids with root frames, named gameplay shapes and simple state. A tackle, ball, sword move or custom character can use the same API. Obstacles and outcomes depend on your game's rules.

## Do I have to replace my movement, animation or VFX?

The package does not replace them. Connect your existing server events. Exact animated limb checks need checked pose data, while a deliberate root-relative gameplay box can represent a move without matching every visible vertex.

## Does setting trust to serverValidated check movement?

No. The label describes validation your code already performs. Reading a client-owned part from a server Script is not a movement validator.

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

Existing toolbar, object and method names remain compatible. The module's `Version` value is `3.1.0`; the public project name is ChronoFork V3.1.

## Where are V1 and V2?

Not in this source release. The comparison page has a labeled historical appendix and selected archived data. Those results are never counted as V3.1 tests.
