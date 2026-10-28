# Prediction comparison — 28 October 2026

Development diagnostic; all errors below are distances in studs. These figures
compare algorithms on synthetic source trajectories. They do not establish
competitive fairness, native network performance or a production improvement.

The model is now also packaged as the **very experimental, default-off** 3.3
service. These replay figures test its mathematical model with accurately
supplied source velocities, not the entire integrated packet/timing/drawing path.
The packaged integration derives many velocities from received source positions.
Its separate functional evidence is in
[prediction-integration.json](validation/prediction-integration.json).

| Predictor | Mean error, seed 20261028 | Mean error, seed 179426549 |
|---|---:|---:|
| Last received position | 3.1115 | 3.0485 |
| Previous 100 ms / 3 stud estimate | 2.2664 | 2.2043 |
| Straight velocity, 250 ms / 8 stud limits | 1.1960 | 1.1644 |
| Adaptive, 250 ms / 8 stud limits | 1.1629 | 1.1314 |

Across these equally sized runs, adaptive mean error is
48.68% lower than the previous estimate and
2.80% lower than straight prediction with the same bounds.
Most of the improvement against the old estimate comes from the larger limits,
not sophisticated model selection. The synthetic old estimator receives the same
accurate source velocity as the other algorithms, rather than the jitter-sensitive
receipt-time finite differences used by the old visual demo.

Each seed covers 1,080 profiles, 341,280 evaluated positions and 343,307 assertions.
Together: 2,160 profiles, 682,560 position checks, 686,614 assertions, no failures.
There are 18 motion families; capture rates 15/30 Hz; one-way delay 0/50/100/200/350 ms;
uniform jitter of 0 or ±50 ms (negative delivery delay clipped to zero); independent
loss 0/10/30%, with an additional 200 ms loss burst in 30% profiles. Packets are
sorted by arrival and stale source times refused. No future packet feeds a
forecast. Each profile lasts six seconds; scoring starts at 0.75 seconds. These
are two seeded replays, not 2,160 unrelated gameplay implementations.

The second seed changes both delivery randomness and the irregular motion
decisions without changing predictor parameters after the first seed's final run.
It is still a synthetic check on the same motion generator, not an independent
real-world validation set.

| Tail metric | Straight seed 1 | Adaptive seed 1 | Straight seed 2 | Adaptive seed 2 |
|---|---:|---:|---:|---:|
| 95th percentile | 5.3333 | 5.3333 | 5.1316 | 5.1923 |
| Maximum | 64.2667 | 64.2667 | 64.5333 | 64.5333 |

Adaptive prediction does not improve every case. Against equal-bound straight
prediction, the second seed's 95th percentile is slightly worse. Some dash,
micro-jitter or irregular-speed means also regress slightly. Teleports remain in
the score, so the largest misses include an unknowable 60-stud displacement before
its packet arrives. No method knows that destination ahead of time. The 80 stud/s
sprint also deliberately exceeds the 8-stud travel budget at longer delays; the
resulting gap is retained rather than hidden by increasing the budget.

The greatest model-selection benefit is on continuous curves: seed 1 circle
mean 0.810 → 0.444;
platform mean 0.479 → 0.322.
Unannounced cuts and reversals cannot be forecast exactly.

A single-client native Studio smoke also checked movement, turning, jump,
both display controls, active server Parts and the error HUD. Its raw captures
are in [prediction-live.json](validation/prediction-live.json). This was a
functional check at the existing network settings, not a matched native-latency
benchmark; server/client views were not compared under two identical input runs.
The complete synthetic per-profile data is in
[prediction-replay.json](validation/prediction-replay.json).

The server diagnostic receives additional client-reported samples. Bounds do not
make those reports trusted. Server error measurements use later client reports
as a reference, with interpolation across short gaps, so they must not be used as
anti-cheat proof. The adaptive display independently estimates across the return
trip from echoed source packets; it is not the exact server Part at this instant.

See [prediction.md](prediction.md) for the math, defaults, integration scope and
limitations. Existing Core 3.1 and Connector 3.2 source files remain unchanged.
