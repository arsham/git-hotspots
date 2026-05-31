# Relationship output sample realism audit

Audit date: 2026-05-31

This docs-only audit compares current real-repository relationship output with
existing fixture and golden coverage. It treats relationship records as local,
deterministic syntax evidence and investigation prompts only. It does not change
runtime behaviour, CLI flags, JSON schema, report fields, provider algorithms,
relationship semantics, scoring, ranking, cache behaviour, network behaviour,
telemetry, release state, tags, remotes, packages, or publishing behaviour.

The findings below are not call-graph truth, dependency truth, package
resolution, type checking, ownership evidence, code-quality judgement,
maintainer responsibility, developer-performance evidence, or bug prediction.

## Scope and privacy boundaries

Evidence was collected from this repository and compared with the checked-in
`fixtures/expected/symbol-relationships*.json` goldens. A sibling/local
repository sample was not run in this pass: no sibling repository was selected
as privacy-safe for naming, path handling, and raw output handling inside this
public repository. This-repo dogfood evidence is sufficient for this docs-only
pass because it exercises the admitted Zig relationship lane on a real source
file, produces provider-cap and display-limit omissions, and exposes a larger
unknown/unresolved mix than the small Zig golden. A future external sample
should use an explicitly approved public or throw-away repository label and
check the same categories without recording raw reports, absolute paths,
remotes, author identities, emails, parser diagnostics, or commit messages.

Only command shapes, labels, bounded counts, categorical observations, and
project-relative paths are recorded here.

## Command shapes sampled

The executable anchor was `./zig-out/bin/git-hotspots` after a local build.

| Label | Command shape | Purpose |
| --- | --- | --- |
| This-repo dogfood JSON | `--repo . --inspect src/main.zig --symbols --symbol-relationships --symbol-limit 4 --format json` | Bounded real-repository counts. |
| This-repo dogfood Markdown | `--repo . --inspect src/main.zig --symbols --symbol-relationships --symbol-limit 4 --format markdown` | Human Markdown shape and omission/caveat presentation. |
| This-repo dogfood table | `--repo . --inspect src/main.zig --symbols --symbol-relationships --symbol-limit 4 --format table` | Human table shape and omission/caveat presentation. |
| Fixture/golden comparison | `fixtures/expected/symbol-relationships*.json` | Existing checked-in coverage baseline. |

## This-repo dogfood evidence

The real-repository sample used the Zig provider lane and emitted relationship
records for `src/main.zig`.

| Category | Observation |
| --- | --- |
| Provider lane | `tree-sitter-zig-relations` |
| Relationship records | 53 emitted records from 64 provider candidates |
| Relation kind distribution | contains 17, unknown 28, import_include 2, reference 5, unresolved 1 |
| Unknown/unresolved volume | 29 records had unresolved targets; most uncertainty is represented as `unknown` records rather than stronger semantic claims |
| Human display omission | 4 records shown and 49 omitted with the explicit display limit |
| Provider omission/cap | 27 provider candidates omitted; provider cap reached |
| Caveats | 243 record-level caveat instances across 7 unique caveat strings |
| Duplicate-looking records | 0 exact duplicate records under source endpoint, target endpoint, kind, direction, provider, and evidence basis |

The Markdown and table surfaces completed with bounded relationship sections.
They preserved the distinction between emitted records and human display
omissions, but they still make repeated caveats and uncertainty-heavy rows
visually prominent.

## Fixture/golden coverage comparison

| Golden | Records | Kind distribution | Unresolved targets | Human omissions | Provider omissions/cap | Exact duplicates | Caveats |
| --- | ---: | --- | ---: | ---: | --- | ---: | --- |
| Python | 20 | contains 10, unresolved 7, call 1, reference 2 | 8 | 16 | 0 / no cap | 0 | 88 instances, 5 unique |
| JavaScript | 17 | import_include 1, contains 12, reference 1, unresolved 1, call 2 | 1 | 11 | 0 / no cap | 0 | 70 instances, 6 unique |
| Go | 8 | contains 8 | 0 | 2 | 0 / no cap | 0 | 32 instances, 4 unique |
| Lua | 16 | contains 9, reference 1, unresolved 2, call 2, unknown 2 | 5 | 10 | 0 / no cap | 0 | 69 instances, 6 unique |
| Rust | 23 | import_include 2, contains 8, unresolved 3, unknown 6, call 2, reference 2 | 10 | 17 | 0 / no cap | 0 | 104 instances, 7 unique |
| TSX | 17 | contains 7, unknown 7, unresolved 2, reference 1 | 9 | 11 | 0 / no cap | 0 | 77 instances, 6 unique |
| TypeScript | 25 | contains 13, unknown 7, call 2, unresolved 3 | 10 | 19 | 0 / no cap | 0 | 110 instances, 6 unique |
| Zig | 2 | contains 2 | 0 | 0 | 0 / no cap | 0 | 8 instances, 4 unique |
| Python default sample | 20 | contains 10, unresolved 7, call 1, reference 2 | 8 | 16 | 0 / no cap | 0 | 88 instances, 5 unique |

The checked-in goldens still represent the main relationship-output categories:
`contains`, `import_include`, `reference`, `call`, `unknown`, `unresolved`,
human display omissions, record-level caveats, and duplicate-sensitive endpoint
pairs. They do not currently represent a realistic high-volume Zig sample with
provider-cap omission, heavy `unknown` volume, and large display-limit omission.
That gap is fixture representativeness, not evidence of a runtime bug.

## Gap classification

| Gap or observation | Classification | Rationale |
| --- | --- | --- |
| No exact duplicates in this-repo dogfood or fixture/golden samples | No action | Current samples do not show duplicate records under the public differentiators. |
| Endpoint pairs may look repeated when kind or evidence basis differs | No action | The differentiator changes the meaning of the syntax evidence; collapsing these records would need separate proof and tests. |
| Zig golden has only 2 `contains` records while this-repo dogfood has 53 mixed records | Fixture-update candidate | Existing Zig golden is intentionally small and does not represent realistic uncertainty, cap, or omission volume. |
| Unknown/unresolved-heavy output appears in this-repo dogfood and several goldens | Presentation candidate | The records are conservative, but human output would be easier to scan with provider-neutral uncertainty summaries. |
| Repeated record caveats are numerous in real and golden samples | Presentation candidate | Per-record caveats remain useful in JSON; human Markdown/table output could group caveats without changing runtime semantics. |
| Provider cap omission appears in this-repo dogfood but not in goldens | Fixture-update candidate | Coverage should include at least one cap-reached sample if a future fixture can do so without unstable counts. |
| Real sample contradicts public output contract | No action | No contradiction was observed; output remained caveated syntax evidence. |
| Provider algorithms or relationship semantics need changes | No action | The audit found presentation and representativeness gaps, not provider correctness proof. |
| Runtime bug exposed by sampling | No action | No runtime bug was observed. |

## Successor recommendation

Evidence supports two bounded successor slices:

1. **Add a realistic Zig relationship golden.** Create or adjust a fixture that
   covers mixed Zig relation kinds, unresolved targets, human display omission,
   and provider-cap state if stable enough for deterministic tests. This is a
   fixture-update candidate, not a runtime behaviour change.
2. **Compact human relationship uncertainty and caveats.** Add Markdown/table
   summaries for unknown/unresolved counts, display omissions, provider-cap
   omissions, and repeated caveat groups while preserving JSON record-level
   evidence and all relationship semantics. This is a presentation candidate.

No provider, scoring, CLI, schema, cache, network, telemetry, release, package,
remote, tag, or publishing slice is indicated by this audit.

## Validation evidence

| Check | Evidence |
| --- | --- |
| This-repo dogfood sampling | JSON, Markdown, and table command shapes listed above completed for `src/main.zig`; bounded counts are recorded in this document. |
| Fixture/golden comparison | `fixtures/expected/symbol-relationships*.json` was compared for relation kinds, unresolved targets, omissions, caveats, and duplicate-looking records. |
| Sibling/local sample | Skipped with the privacy-safe reason recorded above; future sample guidance is included. |
| `git diff --check` | Passed with no output. |
| `zig build test` | Passed with no output. |
| `zig build validate` | Passed all validation rungs, including docs/man surface checks, prohibited-claim scan, git diff whitespace check, deterministic fixture JSON/Markdown, and real repo smoke labelled `this-repo`. |
