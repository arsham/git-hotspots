# Relationship output noise audit

Audit date: 2026-05-31

This audit samples the current public `--symbols --symbol-relationships`
outputs and records relationship-output noise as investigation prompts. It does
not change runtime behaviour, CLI flags, report keys, scoring, ranking, provider
admission, cache behaviour, network behaviour, telemetry, release state, tags,
remotes, or package artefacts.

Relationship evidence remains syntax-provider evidence only. The observations
below are not call-graph truth, dependency proof, ownership evidence,
code-quality judgement, developer metrics, maintainer judgement, or bug
prediction.

## Scope and privacy boundaries

The sampled outputs were produced from deterministic repository fixtures and one
this-repository dogfood command. The audit records only project-relative command
shapes, provider lanes, bounded counts, caveat state, and categorical
observations. It does not include raw reports, source snippets, absolute local
paths, remotes, author identities, emails, parser diagnostics, or commit
messages.

No admitted provider lane or public surface was skipped. JSON, Markdown, and
table surfaces were sampled for Python, JavaScript, TSX, Rust, Go, Lua, and Zig.
The Zig lane used this repository because the fixture Zig paths available in the
sample set intentionally returned no current symbols or no Git-history match.
An unsupported Markdown file was sampled separately to check unsupported-lane
presentation.

## Command shapes sampled

Each command used `./zig-out/bin/git-hotspots` from this repository after a
local build. For each admitted lane below, the same command shape was run with
`--format json`, `--format markdown`, and `--format table`.

| Lane | Command shape |
| --- | --- |
| Python | `--repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-relationships --symbol-limit 4 --format <surface>` |
| JavaScript | `--repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-relationships --symbol-limit 4 --format <surface>` |
| TSX | `--repo fixtures/typescript-symbols --inspect src/component.tsx --symbols --symbol-relationships --symbol-limit 4 --format <surface>` |
| Rust | `--repo fixtures/rust-symbols --inspect src/example.rs --symbols --symbol-relationships --symbol-limit 4 --format <surface>` |
| Go | `--repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-relationships --symbol-limit 4 --format <surface>` |
| Lua | `--repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-relationships --symbol-limit 4 --format <surface>` |
| Zig dogfood | `--repo . --inspect src/main.zig --symbols --symbol-relationships --symbol-limit 4 --format <surface>` |
| Unsupported fallback | `--repo fixtures/rust-symbols --inspect src/unsupported.md --symbols --symbol-relationships --symbol-limit 4 --format <surface>` |

Repeated-order spot checks also compared two Python JSON runs and two Zig table
runs with identical command inputs. Both comparisons were byte-identical.

## Surface and lane evidence

The counts below come from JSON output unless a column names a human surface.
`Shown` and `omitted display` are human-display counts for the explicit
`--symbol-limit 4`. `Exact duplicates` means duplicate relation records with the
same source endpoint, target endpoint, relation kind, direction, provider, and
evidence basis.

| Lane | Provider lane | Records | Kind counts | Unresolved targets | Exact duplicates | Endpoint repeats | Caveats | Human display |
| --- | --- | ---: | --- | ---: | ---: | ---: | --- | --- |
| Python | `tree-sitter-python-relations` | 20 | contains 10, unresolved 7, call 1, reference 2 | 8 | 0 | 2 | 88 instances, 5 unique | 4 shown, 16 omitted |
| JavaScript | `tree-sitter-javascript-relations` | 17 | import_include 1, contains 12, reference 1, unresolved 1, call 2 | 1 | 0 | 3 | 70 instances, 6 unique | 4 shown, 13 omitted |
| TSX | `tree-sitter-tsx-relations` | 17 | contains 7, unknown 7, unresolved 2, reference 1 | 9 | 0 | 0 | 77 instances, 6 unique | 4 shown, 13 omitted |
| Rust | `tree-sitter-rust-relations` | 26 | contains 20, unresolved 2, import_include 1, reference 2, unknown 1 | 3 | 0 | 1 | 108 instances, 7 unique | 4 shown, 22 omitted |
| Go | `tree-sitter-go-relations` | 15 | import_include 1, contains 8, reference 2, call 1, unresolved 1, unknown 2 | 3 | 0 | 0 | 64 instances, 7 unique | 4 shown, 11 omitted |
| Lua | `tree-sitter-lua-relations` | 16 | contains 9, reference 1, unresolved 2, call 2, unknown 2 | 5 | 0 | 1 | 69 instances, 6 unique | 4 shown, 12 omitted |
| Zig dogfood | `tree-sitter-zig-relations` | 53 | contains 17, unknown 28, import_include 2, reference 5, unresolved 1 | 29 | 0 | 0 | 243 instances, 7 unique | 4 shown, 49 omitted |
| Unsupported fallback | unsupported | 0 | none | 0 | 0 | 0 | none on records | 0 shown, 0 omitted |

Markdown and table surfaces rendered bounded relationship sections for every
admitted lane. With the explicit display limit, they exposed the same public
shape: relation rows are sampled for human output, omitted counts are present,
and repeated caveat text is visible. The unsupported fallback rendered no
relationship records and preserved file-level output with an unsupported
provider state.

## Findings by noise bucket

### Duplicate-looking records

No exact duplicate relation record was observed in the sampled JSON outputs.
Some records repeated the same source and target endpoints with different
relation kinds or evidence bases. Those are not duplicates under the public
contract because the differentiator changes the meaning of the syntax evidence.
Examples by category:

- Python nested functions had both `contains` and `reference` records for the
  same endpoint pair.
- JavaScript nested functions had both `call` and `contains` records for the
  same endpoint pair.
- Rust nested type syntax had both `contains` and `reference` records for one
  endpoint pair.
- Lua module table syntax had both `contains` and `reference` evidence for one
  endpoint pair.

Classification: acceptable caveat, not a correctness bug. Do not merge these
records unless a successor keeps relation kind, direction, provider, and
evidence basis visible or proves a provider-neutral deduplication rule.

### Over-broad reference records

The largest noise pattern is broad syntax capture that remains honest but can
be visually heavy. TSX emitted 7 `unknown` records and 9 unresolved targets in a
17-record sample. Zig dogfood emitted 28 `unknown` records and 29 unresolved
targets in a 53-record sample. Lua emitted table/member unknown records for
member-like syntax. These records correctly avoid fabricating package, type,
namespace, table, metatable, build-graph, JSX, DOM, or runtime truth.

Classification: actionable presentation target. Keep the records and caveats in
JSON, but consider a human-output summary that groups unknown and unresolved
records by provider lane and evidence basis before showing individual examples.

### Ambiguous call and member records

Python reported one direct call to an unresolved local name. Go reported one
locally resolved direct call plus unresolved and selector-like syntax. Lua
reported two call records, one unresolved and one locally resolved. JavaScript
reported two local direct-call records. TSX and Zig primarily expressed
ambiguous syntax as `unknown` rather than `call`, which is safer than
overclaiming semantic callee resolution.

Classification: acceptable caveat with a small display opportunity. The current
provider behaviour is conservative. A successor should not relabel unknown or
unresolved call-like syntax as true calls without a separate implementation
contract and tests.

### Unresolved target volume

Unresolved target volume is material in TSX, Lua, and Zig. The records are
useful because they show where the syntax proof stopped, but a long run of
unresolved endpoints in table or Markdown can read like repeated failures rather
than bounded evidence.

Classification: actionable presentation target. Add a provider-neutral human
summary such as `unresolved targets: N of M` and, when practical, group by
`unknown`, `unresolved`, `reference`, and `call` before row samples. Preserve
JSON record-level evidence and caveats.

### Repeated caveats

Caveats repeat at record level across all admitted lanes. The repeated text is
valuable in JSON because every record remains self-caveated, but it is noisy in
human output. The largest sample, Zig dogfood, had 243 caveat instances across
7 unique caveat strings. Rust had 108 instances across 7 unique caveat strings.

Classification: highest-priority actionable repair target for human surfaces.
Keep per-record caveats in JSON unless a later schema feature approves a
change. For table and Markdown, add or improve a lane-level caveat summary and
show compact caveat markers on rows.

### Cap and omission presentation

The explicit `--symbol-limit 4` produced visible human-display omissions for all
admitted lanes. JSON preserved full arrays within provider bounds. Zig dogfood
also reported a provider cap state: 64 relation candidates, 27 provider-omitted
candidates, 53 emitted relation records, and `cap_reached: true`. That cap state
is correctly caveated as partial evidence.

Classification: actionable presentation target. Human outputs should make cap
state and display-limit omission distinct. Display-limit omission is a sampling
choice; provider cap omission means the emitted evidence is partial.

### Ordering stability

Two repeated Python JSON runs and two repeated Zig table runs with identical
inputs were byte-identical. No ordering instability was observed. Different
outputs from different lanes or different command inputs were not classified as
nondeterminism.

Classification: no repair target from this audit. Keep deterministic sort keys
and add regression coverage if a future deduplication or grouping change touches
relation ordering.

### Unsupported-lane presentation

The unsupported Markdown-file sample produced zero relationship records and an
unsupported provider state while retaining file-level report behaviour. That is
appropriate for a non-admitted relationship lane and avoids parser diagnostics
or fabricated relationship support.

Classification: acceptable caveat. No implementation repair is recommended from
this sample.

## Prioritized successor slices

1. **Human caveat compaction for relationship output.** Add provider-neutral
   table and Markdown caveat grouping for relationship evidence while preserving
   JSON record caveats and all runtime semantics. This is the recommended next
   implementation feature because repeated caveat text is the broadest observed
   user-facing noise.
2. **Relationship uncertainty summary for human output.** Add lane-level counts
   for unresolved, unknown, call, reference, import/include, contains, display
   omissions, and provider cap omissions. Keep the summary explicitly framed as
   syntax evidence.
3. **Provider cap wording hardening.** Make display-limit omissions and provider
   cap omissions visually distinct in table and Markdown output. Preserve JSON
   fields unless a separate schema feature is approved.
4. **Deduplication guardrail tests.** Add tests that endpoint repeats with
   different relation kind or evidence basis are not collapsed accidentally.
   This is lower priority because no exact duplicate records were observed.

## Non-goals for successors

- Do not change file scoring, ranking, confidence, lineage, co-change evidence,
  cache behaviour, network behaviour, telemetry, release state, tags, remotes,
  or package artefacts.
- Do not claim call-graph truth, dependency truth, package resolution, type
  checking, ownership, code quality, maintainer responsibility, developer
  performance, or bug prediction.
- Do not remove unresolved, unknown, unsupported, or cap caveats; make them
  easier to scan.
- Do not merge duplicate-looking records unless the differentiator and public
  meaning are preserved.

## Validation evidence

Validation was run after producing this audit document.

| Check | Evidence |
| --- | --- |
| Relationship output sampling | Commands listed above completed for JSON, Markdown, and table surfaces across Python, JavaScript, TSX, Rust, Go, Lua, Zig dogfood, and unsupported fallback. |
| Ordering smoke | Repeated Python JSON and repeated Zig table command outputs were byte-identical for identical inputs. |
| Local real-repository smoke | `--repo . --inspect src/main.zig --symbols --symbol-relationships --symbol-limit 4` completed for JSON, Markdown, and table surfaces; bounded counts are recorded above. |
| Sibling smoke | Not run. The local dogfood command provided privacy-safe real-repository evidence, and no public sibling repository was selected to avoid private path or repository-name leakage. |
| `git diff --check` | Passed with no output after staging this new audit file for whitespace checking. |
| `zig build test` | Passed with no output. |
| `zig build validate` | Passed all validation rungs, including the built-in `git diff` whitespace check and real-repo smoke labelled `this-repo`. |
