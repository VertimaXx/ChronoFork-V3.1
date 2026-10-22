# Mathematics and remaining limits

## Ranked limitations

| Severity | Limitation | Practical consequence / integration responsibility |
|---|---|---|
| 1 — fundamental | Supplied evidence must already be authoritative or validated | V3 checks coverage, structure and declared bounds; it cannot prove an arbitrary game's movement, animation, timing or ownership claims. A dishonest `serverValidated` declaration defeats the trust boundary. |
| 2 — fundamental | Game authorization and outcomes remain game-owned | Authenticate input, replay, cooldowns, stamina, possession, round state, cancellations and current eligibility. Deduplication is per handle; it is not global request authentication or an exactly-once outcome transaction. |
| 3 — accuracy | A snapshot query is not continuous simulation | Linear/spherical interpolation estimates intermediate poses. Fast opposing actors, curved limb paths, acceleration, rotating long shapes or a skipped active window can still miss or invent contacts between captures. Increase authoritative sampling or supply deliberately swept gameplay volumes; V3 does not solve relative-motion CCD. |
| 4 — accuracy | Timing and animation uncertainty are external | No universal one-way delay estimator, render buffer reconciliation or automatic animation reconstruction. Rewind is off by default. A bounded resolver still needs a defensible server timing policy. |
| 5 — game policy | Historical obstacles are optional and adapter-owned | With world off, contact checks deliberately ignore obstacles. With it on, only sweeps are supported and the provider must prove cover/initial-overlap history. Sports overlap obstruction needs a game rule. A game-specific provider must establish what geometry existed at the checked time. |
| 6 — availability | Strict uncertainty can reject otherwise harmless actions | All matching actors need trusted covered data. Provider faults quarantine until reset. Joins/removals invalidate active handles globally. These choices favor refusing uncertain evidence and may feel strict in large or unstable games. |
| 7 — representation | Finite primitive gameplay volumes | Boxes, spheres and capsules, not arbitrary meshes or exact animated skin. Root-relative shapes may intentionally differ from visual limbs. Maximum radius, dimension, reach, actor, state and action capacities apply. |
| 8 — performance | Full evidence checks cost CPU and allocations | Matching actors/zones are scanned and copied/interpolated. No spatial tree or speculative relevance exclusion. Benchmark this against your real roster and zone count; the 256-actor measurement is a one-zone synthetic workload. |
| 9 — numerical | Floating-point tolerances and coordinate scale | No codec quantization is added, but Roblox Vector3/CFrame precision remains. Tests use ordinary map scales. Very small radii, nearly parallel axes and very large coordinates need game-specific precision assessment. |
| 10 — tooling | Integration remains explicit development work | The wizard writes reviewable modules and guides bindings; it does not infer arbitrary moves or retrofit another game's code. No automatic migration/update of existing integrations; namespaces are preserved. |

## Interpolation

For covered adjacent snapshots at t0 and t1, alpha = (t − t0)/(t1 − t0). Positions use p(alpha) = (1 − alpha)p0 + alpha p1. Thus each interpolated position stays in its endpoint segment. Orientation uses CFrame.Lerp's shortest-arc slerp. This avoids velocity-induced Hermite position overshoot but does **not** establish collision-free, physically feasible movement, or the true nonlinear path between samples. Rotating corners need not remain inside the segment of their endpoint corner positions.

Interpolation requires a covered time, retention age, maximum sample gap, current epoch, identical zone dimensions/names and equal discrete scalar state. Exact snapshots may have changed state/dimensions; interior points across that change reject. There is no endpoint fallback, extrapolation or synthetic stop insertion. Root travel is bounded by maxSpeed·deltaTime; that is an admission check, not a complete movement validator. Each zone must fit its declared root-relative extent bound.

## Intersection mathematics

- **OBB/OBB:** separating-axis theorem on the six face normals and nine edge cross products. Nearly zero cross products are skipped; remaining axes are normalized. Separation on any axis means a miss.
- **Sphere/OBB:** Euclidean distance to the box, including rounded corner/edge geometry. Padding each box axis by radius would admit false corner contacts and is not used.
- **Swept sphere/OBB:** transform the segment into box coordinates. Split travel at its six face-plane crossings. On each interval, the set of outside coordinates is fixed, so squared point-to-box distance minus radius squared is quadratic. Solve its earliest valid root; include initial overlap.
- **Sphere/sphere:** center distance at most sum of radii.
- **Sphere/capsule:** point-to-clamped-segment distance at most sum of radii.
- **Capsule/capsule:** closest distance between two closed centerline segments at most sum of radii, including degenerate segments.
- **Swept sphere/capsule:** expand capsule radius by query radius. Split where projection onto the centerline clamps to either endpoint. Solve squared affine distance on each piece, including initial overlap. A capsule with total height = 2·radius degenerates to a sphere.
- **Sweep/sphere:** quadratic ray intersection against the expanded sphere. Return the earliest parameter in [0,1]. A ray is a zero-radius sweep.

Overlap contacts return zero travel fraction. Sweeps return first travel fraction relative to the original full query segment. Target volumes stay fixed at the sampled historical instant during that spatial sweep. This is a deliberate gameplay sweep, not both actors' physical motion integrated through time.

Absolute numerical tolerances are small but nonzero: SAT separation tolerance 1e-7 studs, squared-distance/root tolerance in the corresponding routines, CFrame orthonormality tolerance 1e-4, root-speed slack 1e-4 studs and zone-extent slack 1e-5 studs. They are implementation tolerances, not a universal bound on total hit-registration error. The independent Roblox engine sweep oracle allows 0.025 studs distance disagreement because engine collision tolerances differ from mathematical primitives.

## What the comparison proves

The 34,000 shared covered history queries use two endpoint snapshots, randomized endpoint velocities, and a deliberately **linear** position oracle. Original Chrono Hermite averaged 0.5683 studs from that imposed line and had 5,958 scalar endpoint-range overshoots; V3 linear history had zero in both measures. This is an adversarial interpolation test. The velocities are not guaranteed consistent with the imposed path, so it does not establish a general accuracy advantage over original Chrono on real nonlinear motion.

For 4,000 out-of-range requests, original Chrono returned an endpoint; V3 rejected all. That is a stronger evidence contract, not proof that a rejected attack was illegitimate. Checked history query mean CPU time was 1.5405 microseconds versus 0.5769 for original Chrono on this workstation. These are different validation contracts and include one V3 zone/state interpolation. They are not whole-game FPS, network bandwidth or player win-rate measurements.

