# Relationship fixture realism matrix

This matrix is durable validation metadata for the admitted relationship goldens.
It records what each checked-in lane covers without changing runtime behaviour,
provider algorithms, CLI flags, JSON schema, report fields, scoring, ranking,
cache behaviour, network behaviour, telemetry, release state, tags, remotes,
packages, or publishing behaviour.

Relationship records remain bounded local syntax evidence and investigation
prompts. The matrix is not call-graph truth, dependency truth, package
resolution, type checking, ownership evidence, a code-quality judgement,
developer-performance evidence, or bug prediction.

`zig build validate` recomputes the generated summary below from the checked-in
`fixtures/expected/symbol-relationships*.json` files and fails if the rows drift.
Reviewers should then update this matrix or intentionally update the goldens.

## Generated lane summary

| Lane | Golden | Provider | Records | Relation kinds | Unresolved targets | Human display | Provider cap or rationale | Caveats | Duplicate-looking guard |
| --- | --- | --- | ---: | --- | ---: | --- | --- | --- | --- |
| Python | `fixtures/expected/symbol-relationships.json` | `tree-sitter-python-relations` | 20 | contains 10, unresolved 7, call 1, reference 2 | 8 | 4/20, omitted 16 | 0 omitted, 0 caps; repeat endpoint pairs exercise duplicate-looking guard; provider-cap coverage remains in synthetic integration fixture, not this lane golden | 88 instances, 5 unique | exact duplicates 0; repeated endpoint pairs 2 |
| JavaScript | `fixtures/expected/symbol-relationships-javascript.json` | `tree-sitter-javascript-relations` | 17 | import_include 1, contains 12, reference 1, unresolved 1, call 2 | 1 | 6/17, omitted 11 | 0 omitted, 0 caps; repeat endpoint pairs exercise duplicate-looking guard; provider-cap coverage remains in synthetic integration fixture, not this lane golden | 70 instances, 6 unique | exact duplicates 0; repeated endpoint pairs 3 |
| Go | `fixtures/expected/symbol-relationships-go.json` | `tree-sitter-go-relations` | 15 | import_include 1, contains 8, reference 2, call 1, unresolved 1, unknown 2 | 3 | 6/15, omitted 9 | 0 omitted, 0 caps; stable Go fixture covers provider wording categories; provider-cap coverage remains in synthetic integration fixture | 64 instances, 7 unique | exact duplicates 0; repeated endpoint pairs 0 |
| Lua | `fixtures/expected/symbol-relationships-lua.json` | `tree-sitter-lua-relations` | 16 | contains 9, reference 1, unresolved 2, call 2, unknown 2 | 5 | 6/16, omitted 10 | 0 omitted, 0 caps; repeat endpoint pairs exercise duplicate-looking guard; provider-cap coverage remains in synthetic integration fixture, not this lane golden | 69 instances, 6 unique | exact duplicates 0; repeated endpoint pairs 1 |
| Rust | `fixtures/expected/symbol-relationships-rust.json` | `tree-sitter-rust-relations` | 23 | import_include 2, contains 8, unresolved 3, unknown 6, call 2, reference 2 | 10 | 6/23, omitted 17 | 0 omitted, 0 caps; repeat endpoint pairs exercise duplicate-looking guard; provider-cap coverage remains in synthetic integration fixture, not this lane golden | 104 instances, 7 unique | exact duplicates 0; repeated endpoint pairs 2 |
| TSX | `fixtures/expected/symbol-relationships-tsx.json` | `tree-sitter-tsx-relations` | 17 | contains 7, unknown 7, unresolved 2, reference 1 | 9 | 6/17, omitted 11 | 0 omitted, 0 caps; no repeated endpoint-pair guard in this lane; cross-lane duplicate-looking guards cover the category; provider-cap coverage remains in synthetic integration fixture | 77 instances, 6 unique | exact duplicates 0; repeated endpoint pairs 0 |
| TypeScript | `fixtures/expected/symbol-relationships-typescript.json` | `tree-sitter-typescript-relations` | 25 | contains 13, unknown 7, call 2, unresolved 3 | 10 | 6/25, omitted 19 | 0 omitted, 0 caps; repeat endpoint pairs exercise duplicate-looking guard; provider-cap coverage remains in synthetic integration fixture, not this lane golden | 110 instances, 6 unique | exact duplicates 0; repeated endpoint pairs 2 |
| Zig | `fixtures/expected/symbol-relationships-zig.json` | `tree-sitter-zig-relations` | 14 | contains 5, reference 1, unknown 3, unresolved 1, import_include 2, call 2 | 5 | 6/14, omitted 8 | 0 omitted, 0 caps; no repeated endpoint-pair guard in this lane; stable Zig cap coverage would be oversized and cap-coupled, so cap coverage remains synthetic | 63 instances, 7 unique | exact duplicates 0; repeated endpoint pairs 0 |

## Category observations

- Relation-kind diversity: every admitted lane now covers more than one
  relation kind, including Go's stable import, reference, call, unresolved, and
  selector-like syntax examples.
- Unknown and unresolved coverage: every admitted lane now includes unresolved
  or unknown bounded syntax evidence.
- Human display omissions: every admitted lane records display-limit behaviour;
  this includes small omissions in Go and larger omissions in the other lanes.
- Provider-cap coverage: admitted lane goldens do not force provider caps. Cap
  reporting is covered by the synthetic provider-cap integration fixture so the
  lane goldens do not become oversized or coupled to implementation caps.
- Caveat diversity: every admitted lane records record-level caveats, with the
  generated summary preserving instance and unique-caveat counts.
- Duplicate-looking guards: Python, JavaScript, Lua, Rust, and TypeScript have
  repeated source/target endpoint pairs where kind or evidence basis keeps the
  records distinct. TSX, Go, and Zig do not currently need lane-local repeated
  endpoint pairs; cross-lane coverage keeps this category reviewed.

## Privacy and protected-surface review

The matrix uses only project-relative fixture paths, provider names, bounded
counts, and categorical observations. It must not contain private paths,
remotes, identities, parser diagnostics, raw private reports, or commit
messages. Updating this matrix must not require runtime, provider, CLI, JSON,
scoring, cache, network, telemetry, release, tag, remote, package, or publish
changes.
