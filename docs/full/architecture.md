# Architecture and compatibility

## Distinct position records and estimates

| Record | Purpose | Allowed to estimate? | Trusted for damage automatically? |
|---|---|---|---|
| Original-compatible display snapshots | Smooth remote models | Yes: original stop inference, selected curve, optional limited prediction | No |
| Very experimental prediction service (off by default) | Separate bounded server/client estimates and optional remote drawing | Yes: explicit estimates only; real packet sources train it | No |
| Competitive Core 3.1 records | Existing action/contact service | Covered interpolation under its checks | Only as good as the declared server provider and game rules |
| Preview `Competitive.History` | Immutable records with provenance and discontinuities | Covered linear interpolation; no endpoint substitution or invented stops | Observed sources are refused by default |

`SourceRecorder` samples a supplied game capture hook independently of transport
send frequency. It records at real capture times and does not invent catch-up
poses after a stalled frame. It defaults to `observed`. A `serverSimulated` source
that becomes client-owned is refused unless the game explicitly supplies an
independent server source. This is a declaration/connection contract, not a generic
proof of an arbitrary game's movement code.

`EvidenceWorld` can use separate source and target times. Both must fall in policy
and have covered trusted records. Unavailable data, incompatible geometry/state,
large gaps and game callback failures cause refusals. Game callbacks cannot mutate
the actor roster while a query is evaluating it.

## Original APIs

The active `replication/` contains all 36 runtime modules from upstream commit
`90be58b09fe420977afa691396238c7817c1766f`, plus new helpers. The exact unmodified
baseline, licence and hashes are in `vendor/chrono`.

The top-level package forwards the original `Start`, `Entity`, `Holder`, `Config`,
`Stats`, `ReplicationRules`, `Events`, `Snapshots`, `ServerClock`, `Player`,
`ServerReceiver` and `EntityGrid` APIs. It also keeps `new`, `Shapes`, `Explain` and
`Core` for the competitive branch. Original module require paths under `Shared`,
`Client` and `Server` have forwarding modules, including exported type aliases.
Actual transport instances are under `Replication.Shared.Remotes`; reaching into
private remote/model storage is not a portable public API.

Original construction, destruction, native/custom/locked models, interpolation
modes, player lifecycle, mounting, ownership, data-only objects, filtering and
statistics remain present. Presence and successful smoke tests are not a claim
that every combination has already passed regression testing.

`Entity.Destroy(entity, true)` is an added keep-model removal option. The default
call keeps the original destruction behavior. Keep-model removal includes the
lifetime and native anchor state, and clients refuse removals for another lifetime.

Startup is explicit and guarded against concurrent/repeated failed initialization.
A successful second `Start` retains the original ignore-and-warn behavior. Failed
or partially started sessions require Stop before retrying.

## Wire version 2

All clients and the server must use the same build. Public API compatibility does
not mean compatibility with original Chrono's wire format.

- Packet header: magic, wire version and record count.
- Each record: object ID, flags, lifetime, ownership/state revision, update sequence,
  full 64-bit source clock, float32 position and encoded rotation.
- Full rotation record: 41 bytes. Yaw-only record: 37 bytes. Packet header: 5 bytes.
- Packets are split below 900 buffer bytes. Mixed and repeated IDs are split safely.
- Decoding validates the entire packet before returning any state. Malformed
  packets cannot partially apply. Individual valid records can still be refused by
  ownership, ordering, timing or game middleware checks.
- The update counter is compared only within one lifetime and revision. A server
  teleport and an ownership change advance the revision, so old updates do not
  become valid merely because a visual teleport timeout elapsed.
- Incoming byte allowance uses elapsed time. Debug and heartbeat messages have
  separate rate limits and type checks.

Reliable lifecycle and critical messages are separate from unreliable state.
There is no assumed ordering between those channels. State received before the
matching lifecycle/revision is dropped; a later current update resumes the stream.
This preview does not advertise an unlimited buffering/resynchronization queue.

The extra metadata has a measurable raw payload cost. See the matched live data;
no claim of reduced total network bandwidth is made.

## Engine simulation

`Competitive.Simulation.Bind` uses `BindToSimulation`, `time()` and the engine's
resimulation flag. `DeferOutcome` schedules server side effects outside simulation.
Normal Luau tables are not rollback state; shared simulation state belongs in
predicted instance attributes/properties. Use the game's input/controller and
simulation rules, rather than running a second custom transform driver.

The implementation follows Roblox's [server authority model](https://create.roblox.com/docs/projects/server-authority),
[simulation API](https://create.roblox.com/docs/reference/engine/classes/RunService#BindToSimulation)
and [techniques](https://create.roblox.com/docs/projects/server-authority/techniques).
Those documents also explain why a general-purpose adapter cannot turn an arbitrary
client controller, animation script or effect callback into a rollback-safe game.
