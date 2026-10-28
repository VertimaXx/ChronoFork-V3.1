# Predicting movement without pretending to know the future

This is a **VERY EXPERIMENTAL, opt-in feature in the 3.3 development preview**,
not a published replacement for hit validation. It is off by default. The
packaged `Experimental.Prediction` service uses `MotionPredictor` on either side;
the existing root comparison is a separate diagnostic example.

## Enable through the setup plugin

Open **ChronoSetup → Experimental**. Turn on **Very experimental movement
prediction** to collect separate estimates. Turn on **Use experimental estimates
for drawing** only if you also want remote-object drawing to use them. Review the
settings and install the reviewed package. For an existing installation, change
the supplied `Settings` module while Play is stopped. The setup does not overwrite
an existing package or silently update a running session.

The page provides 13 explained controls: the two switches, time, distance, speed,
acceleration, horizontal turning, orientation change, gap reset, teleport reset,
learning time, assumed source delay and drawing timeline lead. **F4** displays
whether the experiment is off/on, the bounds and per-object status. The additional
lead defaults to zero, preserving the existing drawing timeline. Prediction may
only be needed during gaps if the drawing buffer already covers received data.

This integration uses Chrono's existing packets and source clocks. It adds **no
extra movement remote or packet fields**. It automatically feeds actual server
captures, accepted client updates and explicit public `Entity.Push` samples into
a separate model. Received stop flags can supply a reported zero velocity; stops
invented by the display snapshot filler do not train the predictor. Client-owned
sources remain unverified. Velocities are derived from successive real capture
positions unless a game explicitly supplies them to `Entity.Push` / `Observe`.

Use Chrono replication / Legacy mode. The setup refuses to enable this feature
alongside the Engine adapter; Roblox engine rollback remains a separate system.

## Optional in-package scripting

No external glue is needed for the automatic feeds and drawing choice. Games can
inspect estimates inside the supplied hooks:

```lua
local prediction = chrono.Experimental.Prediction
local frame, info = prediction.EstimateCurrent(entity)
-- info.trust is "estimate". Do not insert frame into trusted hit records.
```

`chrono.ExperimentalPrediction` is an equivalent original-style API alias.

| Function | Meaning |
|---|---|
| `Estimate(entity, targetSourceTime)` | Forecast to a time in that object's source clock. Never pass a different computer's clock without a mapping. |
| `EstimateCurrent(entity, optionalSourceDelay)` | Use time elapsed since receipt plus an explicit assumed source delay. The delay defaults to zero and is not measured uplink latency. |
| `Inspect(entity)` | Read enablement, sample counts, last acceptance/refusal reason, clock domain and bounds. |
| `Reset(entity)` | Discard the estimate when your game needs an additional boundary. |
| `Observe(entity, time, frame, optionalVelocity, optionalClockDomain, optionalDiscontinuity)` | Feed a custom real source, for advanced controllers. Do not mix it with the automatic source clock for the same entity. |

Ownership revision, lifetime, model replacement, teleports, clear, pause and
destruction invalidate/reset estimates. Queries refuse inactive or mounted objects.
No API changes `Entity.GetCFrame`, stored snapshots, network ownership, server
physics, damage decisions or the competitive recorder. Explicitly enabling
experimental drawing can change remote CFRAME/ALIGN presentation and corrections.

`EstimateCurrent` deliberately does **not** subtract `os.clock()` values from
different computers or pretend a receipt-based clock offset removes transport
delay. Its result includes the source-clock label and timing assumption. An
accurate game-supplied clock mapping is still needed to claim a particular
cross-computer time. The return metadata always marks the result experimental
and an estimate, even if its source was supplied by a server simulation.

A server-created hitbox can stay attached to the server's character. Its client
copy can stay attached to the client's character. Those character positions can
still differ while movement crosses the network. Predicting reduces some of that
difference; it cannot reveal an input that has not arrived.

## What the model does

Call `Observe(captureTime, cframe, velocity, discontinuity)` with strictly newer
samples. Capture time means when the source position was measured. Using packet
arrival time would mix movement with network jitter. Call `Predict(targetTime)`
to obtain a CFrame and an explanation of the estimate.

Five candidate motions are evaluated: holding still, continuing at the measured
velocity, continuing the measured acceleration, continuing a horizontal turn, and
slowing down. Straight motion is preferred during startup. Holding requires a
measured stop; the slowing candidate requires measured deceleration. A reversal
does not become an invented orbit or a continued acceleration through zero speed.

For a prediction interval `h`, the straight candidate travels `v*h`. Acceleration
travels `v*h + a*h*h/2`, stopping the integration when braking would reverse the
velocity. The turn candidate integrates horizontal velocity at constant angular
rate `w` using `sin(w*h)/w` and `(1-cos(w*h))/w`, with a straight-motion limit as
`w` approaches zero. The slowing candidate integrates an exponentially decaying
velocity with an 80 ms time constant. Orientation uses bounded angular velocity
from the previous two orientations. Model selection is trained on **position**
error; orientation is not independently optimized.

When a new position arrives, old saved states are forecast to that capture time
and compared with the newly available position. No later sample is available to
those saved states when they are created. Squared errors are updated separately
near 33, 67, 100, 150 and 250 ms, using elapsed-time exponential averaging with a
0.6-second time constant and a squared-loss cap of 400. Selection uses the lowest
eligible recent loss with a small preference for straight motion. This is a
causal heuristic, not a proof of minimum possible error or a learned input oracle.

Default bounds are 250 ms ahead, 8 studs of displacement, 120 studs/second of
source speed, 250 studs/second squared acceleration, 8 radians/second horizontal
turning, and 12 radians/second orientation change. After the time cap the forecast
holds at the capped prediction, with status `capped`. It does not silently keep
projecting. Options can be supplied to `New`; game-specific choices need testing.

Explicit discontinuities, large position jumps and long gaps reset the model.
Invalid samples and backwards or duplicate capture times are refused. Recent
history has at most 64 states. The returned `uncertainty` is a disagreement/error
warning, **not** a statistical confidence interval, a safe hitbox size, or proof
that an obstacle-free path exists.

## Reading the separate Studio comparison

- **Red** is the Roblox root observed by the server and sent back to the client.
- **Server's sent estimate** is the forecast actually computed on the server.
  A transparent, non-colliding server Part records that exact forecast under
  `Workspace.ChronoServerPredictionEstimates`. It also takes time to reach you.
- **Adaptive estimate** forecasts on the display using only source samples that
  have travelled to the server and back. It does not read your current local root
  to adjust the result. Your local root is used to send observations and measure
  the displayed gap, never to secretly attach the green box to it.
- The old 100 ms estimate, raw query, smoothing and historical modes remain for
  comparison. Historical queries and predictions answer different questions.

The **comparison example's** extra motion channel sends source CFrames, velocities and capture times at
up to 30 Hz. The server checks character identity, ordering, finite values, age,
speed and a receive budget. These are input bounds, **not movement validation**:
the client can still lie about valid-looking positions and times. No predicted
Part collides, fires contact damage, replaces the character or supplies trusted
competitive history. Existing combat and the released Core/Connector are unchanged.
This extra channel is not installed by the packaged experimental feature.

The live mean errors compare earlier server forecasts with subsequently received
client reports, interpolated only across short gaps. They are diagnostic and
exclude long gaps and reset boundaries. Native replication and the new motion
channel have different transports. Use synthetic same-input comparisons to
separate algorithm improvements from the extra channel or changed time bounds.

## Tests and remaining limits

`tests/full/PredictionSuite.luau` includes finite/order/reset/bound checks and
source-time replay of 18 motion families, five one-way delays (0–350 ms), two
jitter ranges, three loss levels and two source rates. Random source decisions
include irregular direction and speed changes. Packets are reordered by arrival
time; predictions receive only delivered samples. Teleports remain in aggregate
error, including the period before the teleport packet arrives.

See `validation/prediction-replay.json` and `prediction-results.md` for results.
See `validation/prediction-integration.json` for packaged service, setup and
native single-client integration checks. The synthetic replay uses accurately
supplied velocities; production source-derived velocities may perform differently.
These are synthetic trajectories, not native Roblox latency benchmarks or proof
that every player, device, map, movement controller or contact outcome improves.
Long outages, unknown collisions, knockback, new inputs and teleport destinations
remain unpredictable. No multiple-client fairness or production-load result is
claimed. A game that needs trusted movement must supply its own simulation or
validated state; attaching this estimator does not provide that missing layer.

Roblox documents the same fundamental need to correct mistaken predictions in
its [server authority model](https://create.roblox.com/docs/projects/server-authority).
It also explains why a client's control of physics is not proof of safe movement
in [network ownership and movement validation](https://create.roblox.com/docs/scripting/security/network-ownership).
