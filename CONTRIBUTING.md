# Contributing

Start with [integration](docs/integration.md), [math and limits](docs/math-and-limits.md) and [benchmark provenance](docs/benchmarks.md). Keep explanations usable by self-taught developers: define a term, show an example and preserve the exact API/reason name for searching.

For a bug, include the Connector/plugin version and Core version, a small reproducible setup, expected/actual results, reason codes, shape sizes, timing policy, recording/check mode and relevant delays. Use invented actor ids and remove private player data. Do not attach a whole private game. Current versions are Connector/plugin 3.2.0 and unchanged Core 3.1.0.

Keep uncertainty checks explicit. Do not make a refusal disappear by silently clamping time, approving an unverified actor or replacing missing history with an endpoint. Changes to acceptance policy need a documented tradeoff and meaningful adversarial cases.

After edits, run `python tools/build.py` and `python tools/check.py`. If you have the Luau CLI, use `python tools/check.py --luau-compile /path/to/luau-compile`. Runtime changes also need the relevant Studio tests from the benchmark guide; packaging CI alone is insufficient. Record new results separately with version, source hashes, seed, workload and environment. Do not rewrite earlier measurements to look current.

Preserve upstream attribution and disclose material AI assistance in contributions. AI-generated code still needs human review and meaningful validation. Screenshots and documents must not imply upstream endorsement or production certification.
