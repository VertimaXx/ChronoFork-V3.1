# Development validation and original comparison

The later very experimental prediction integration has a separate
[comparison report](prediction-results.md) and [math/limits guide](prediction.md).
Its synthetic 2,160-profile result is not added to the original/fork native smoke
benchmarks below and does not certify server movement or damage decisions.
Packaged service/configuration, lifecycle, default-off/on native smoke and setup
checks are recorded separately in `validation/prediction-integration.json`.

The machine-readable records in [validation](validation) distinguish unit/property
checks, synthetic transport schedules and real Studio smoke runs. They are not
combined into a claim of thousands of real multiplayer matches.

The current upstream baseline is pinned at
`90be58b09fe420977afa691396238c7817c1766f`. Earlier published ChronoFork benchmark
data used a different upstream revision and remain historical results for their
original versions.

## Established in this implementation

- All 36 original runtime modules and original public functions remain present.
- Packaged models compile and their literal module paths resolve.
- Whole-packet decoding rejects malformed/truncated/numerically invalid payloads.
- Lifetime/revision/sequence checks refuse stale or wrong-owner updates.
- Segment rendering passes containment and monotonicity property tests, including
  a reproduced original-Hermite overshoot counterexample.
- Separate immutable history refuses missing/out-of-range/gapped/untrusted data.
- Relative sphere motion, authored pose interpolation, obstacle coverage and
  outcome/conflict helpers pass their included regression checks.
- The supplied installer protects edited/added data, and the actual startup scripts
  and F4 view run in Studio.
- Original and fork complete the included single-client functional fixture under
  matched zero, moderate and severe impairment profiles. See raw data for the
  exact tested source fingerprints and any subsequent verification run.

## Costs and practical limits

The final Studio campaign completed **8/8 matched runs** and all four extra
keep-model removal checks. Unit/property checks passed **7,121/7,121 cases** with
130,703 assertions. The separate synthetic replay covered **864 profiles** with
139,792 assertions. Installer checks passed 50 assertions over 33 controls.

| Profile | Original payload bytes/s | Fork payload bytes/s | Fork / original |
|---|---:|---:|---:|
| zero | 2817 | 5807 | 2.06× |
| rtt150 | 2749 | 5654 | 2.06× |
| asymmetric330 | 2583 | 5291 | 2.05× |
| severe900 | 2086 | 4704 | 2.26× |

These rates count received state buffers only. The severe-profile client windows
were about 6.77 seconds for the fork and 7.53 seconds for the original because
startup and completion notifications arrived at different times. The values are
normalized by each measured window; they are not a controlled total-wire benchmark
or a direct latency/accuracy ranking. See [raw live results](validation/live-original-fork.json)
and [CSV](validation/live-payloads.csv).

The fork adds per-record metadata and sends more raw state-buffer bytes in this
small fixture. It is **not currently established as a bandwidth improvement**.
Actual Roblox wire usage and compression require separate measurement.

The small CPU counters from one eight-second run are diagnostic observations, not
evidence of a statistically significant speed advantage. Startup timing and arrival
windows differ, particularly under severe impairment. Use normalized receipt rates
only within the stated scope.

Neither the original nor the fork can make transport delay disappear. No claim is
made that every player sees a root-position rectangle glued to their current local
character, or that attacker/defender fairness is automatically solved.

## Required before a production release

1. Real multiple-client observer/attacker/defender tests with documented time policies.
2. Engine-authority prediction/rollback tests with an actual shared game controller.
3. Historical animation/pose and moving-obstacle integration tests in representative games.
4. Long sessions, respawns, streaming churn, object/owner reuse and callback-failure campaigns.
5. Controlled CPU/memory/total-network measurements, including high object counts.
6. Native plugin interaction/Undo/Redo tests and novice-developer integration trials.
7. Wiring the advanced preview helpers into additional guided contact workflows,
   with examples and tests, rather than treating helper availability as completed integration.

The package is a concrete development preview with verified components, not a
claim that the full successor's release gates have all been met.
