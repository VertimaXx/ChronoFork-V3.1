# Full-runtime successor work

Development branch, not a published release. Original source is pinned at
`90be58b09fe420977afa691396238c7817c1766f`; exact files and hashes are retained in
`vendor/chrono`. `replication/` is the active full-feature fork. Existing Core 3.1
and Connector 3.2 files remain available unchanged.

Implemented and checked in this development branch:

- Complete pinned original runtime, API forwarding and typed module aliases.
- Wire-v2 bounded decoding, full clocks, lifecycle/revision/sequence guards,
  elapsed-time byte budgets, protected diagnostic events and teleport boundaries.
- Optional segment/linear/original curves, bounded labeled display prediction,
  conservative frustum tests, time-based buffer statistics and phased scheduling.
- Immutable graded evidence, separate query times, source recording, authored pose
  zones, relative sphere CCD, bounded volume refinement, historical obstacles,
  outcome reservations and possession/round conflict tokens.
- Full-runtime setup with 46 explained controls, generated in-package hooks,
  server-private backups, safe removal, child-arrival readiness and F4 diagnostics.
- Existing competitive connector bundled alongside it without changing Core 3.1.
- VERY EXPERIMENTAL prediction service integrated into existing packet/capture
  paths, off by default, with a separate drawing switch and 13 setup controls.
  No extra runtime motion channel and no predicted hit records. Two seeded
  algorithm replays cover 2,160 profiles and 682,560 evaluated positions; see
  docs/full/prediction-results.md and prediction.md for integration limits.
- 7,121 seeded/property/regression cases; 864 synthetic delivery profiles; 50
  installer assertions; matched single-client original/fork smoke fixtures.

These checks have practical scope limits. See docs/full/validation.md and raw JSON.
Additional release gates remain:

- Full original runtime and public API coverage, including all model/render modes,
  ownership, mounting, data-only objects, clocks, filters and debugging.
- Atomic bounded packet decoding, lifecycle/ownership generations, state sequences,
  elapsed-time rate limits and resynchronization.
- Rendering fixes, adaptive buffering, explicitly marked optional estimates,
  trustworthy covered history, source provenance and bounded timing.
- Relative-motion contact tests, authored pose/zone timelines, historical world
  providers and conflict-aware/idempotent outcome integration.
- Compatible legacy and engine-server-authority paths; replay-safe effects.
- Plugin installation and setup controls, editable in-package hooks, reversible
  changes and plain-language guidance.
- Feature parity and regression tests, multiple-client native network testing,
  fairness/error/performance/bandwidth comparisons and updated documentation.

Wire protocol changes require the same fork build on clients and server. Public
API compatibility does not imply mixed-version wire compatibility. No performance,
accuracy, zero-delay or complete-security improvement is claimed before testing.
