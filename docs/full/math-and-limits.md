# Math, assumptions and remaining limits

## Segment-constrained drawing

Let `d = p1-p0`, `L = |d|`, `u = d/L`, and `dt` be the actual sample interval.
The new Segment option projects endpoint velocities onto that segment:

```
a = clamp(dot(v0,u) * dt/L, 0, 3)
b = clamp(dot(v1,u) * dt/L, 0, 3)
if a+b > 3: scale both so a+b = 3
p(t) = p0 + d * (h10(t)*a + h01(t) + h11(t)*b)
```

The equivalent scalar Bezier control points are `0, a/3, 1-b/3, 1`.
They are ordered and inside `[0,1]`, so progress is monotonic along the endpoint
segment, apart from numerical tolerance. Perpendicular velocity is deliberately
discarded. Coincident endpoints return that endpoint.

This does **not** prove collision-free movement, the true curved trajectory, correct
timing or lower visual error for every motion. A straight segment can cut through a
wall or cut a real curve. Linear and original Hermite remain selectable.

The preserved original Hermite counterexample is `p0=0, p1=1, dt=1, v0=v1=-3`:
at `t=0.1` its x coordinate is approximately `-0.188`. The new constrained option
stays inside the segment. This is a specific demonstrated improvement, not a
universal accuracy benchmark.

## Optional visual prediction

After the newest sample, the renderer may use `latest + velocity*age` only within
configured time, distance and speed limits. Zero prediction time disables it.
The returned display metadata distinguishes `predicted`, `held`, `interpolated`,
`before_coverage` and `discontinuity`. Every curve respects teleport locks.

The predictor does not know the next input or solve collisions. It is never copied
into competitive evidence and cannot make the true server position instantly
follow a high-ping client's present input.

## Covered game records and error budgets

Evidence refuses requests outside retained data or beyond the maximum sample gap.
It never silently substitutes an endpoint. Ownership, teleport and other explicit
discontinuities separate record generations. State, geometry and trust changes
cannot be interpolated across.

Under independently justified bounds, a useful positional error budget is:

```
recording/codec error
  + maximumSpeed * timeUncertainty
  + maximumAcceleration * sampleGap^2 / 8
  + 2 * zoneRadius * sin(rotationError/2)
```

The acceleration term assumes a bounded-acceleration path interpolated linearly
between true endpoints. An endpoint speed check alone does not establish that
bound, continuous legal movement or obstacle clearance.

## Relative motion

For two linearly moving sphere centers, use relative start `r=a0-b0`, relative
displacement `d=(a1-a0)-(b1-b0)` and combined radius `R=ra+rb`. Contact solves
`|r+t*d|^2=R^2`, including initial overlap and zero relative velocity.

The implementation reads Vector3 components and solves using Luau numbers. It uses
closest approach to avoid subtracting large float32 quadratic terms. A seeded
Studio case caught a several-millistud error in the initial Vector3 calculation;
that regression now passes.

For boxes/capsules, `Motion.Between` evaluates the declared linear-center,
shortest-rotation interpolation and bounds interval movement with translation plus
`2R*sin(angle/2)`. Separating support projections can prove an interval clear.
Refinement has explicit work/tolerance limits. Unresolved intervals return
`unknown`, not an invented hit or clear. Endpoint interpolation is not arbitrary
curved motion, skeletal forward kinematics or every animation blend.

`PoseTimeline` supplies server-authored local hitbox zones. It rejects uncovered
times and incompatible geometry. It does not recover arbitrary client Animator,
IK or cutscene poses. Roblox's [Motor6D documentation](https://create.roblox.com/docs/reference/engine/classes/Motor6D)
and [animation documentation](https://create.roblox.com/docs/animation) remain relevant
when deciding what a game's pose source actually proves.

## Clock bounds

For honest client/server timestamps `c0,s1,s2,c3`, nonnegative travel delay bounds
the server-minus-client clock offset by `[s2-c3, s1-c0]`. The midpoint is an estimate;
half the interval width is uncertainty. Asymmetric routing need not be RTT/2.
Mapping refuses when the entire resulting interval is outside the age policy.

These helpers do not authenticate a dishonest client's timestamps. The retained
original render clocks still use receipt-based estimates. They are not silently
promoted into calibrated damage evidence.

## Codec and counters

State timestamps use float64, removing the original state packet's approximately
4.97-day uint32 clock wrap. Sequences use modular uint32 comparison inside a lifetime
and revision. More than half the sequence range without a valid reference requires
resynchronization; lifetime/revision exhaustion fails explicitly.

Float32 positions and Euler rotation encoding remain. Euler steps are approximately
`360/65535 = 0.005493` degrees for individual encoded angles; yaw-only mode omits
pitch and roll. This is not a universal complete-orientation error guarantee.
Large world coordinates need separate precision assessment.

## Outcomes and historical obstacles

`WorldHistory` keeps obstacle existence intervals and covered historical geometry.
An unknown obstacle record is not reported clear. Its supplied provider checks rays
and swept spheres at a chosen historical time; general moving-world continuous
occlusion still needs an appropriate game policy/provider.

`Outcomes` reserves a server key before invoking game code. Duplicate calls within
the reservation window are refused. A partial failure stays ambiguous and is not
automatically retried. `Versions` rejects stale possession/round tokens and requires
explicit reconciliation after an ambiguous callback. These helpers are not database
transactions or proof that arbitrary game callbacks are correct.
