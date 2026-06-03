# Provider-specific caveat wording audit

Audit date: 2026-06-01

This docs-only audit reviews provider-specific relationship caveat wording in
checked-in relationship goldens. It classifies caveat issues and recommends
bounded follow-ups without changing runtime behaviour, CLI flags, JSON schema,
report fields, provider algorithms, provider admission, relation semantics,
scoring, ranking, caps, cache, network, telemetry, release state, tags, remotes,
packages, or publishing behaviour.

Relationship records remain local syntax-provider evidence and investigation
prompts. The caveats below are not call-graph truth, dependency truth, package
resolution, type checking, ownership evidence, code-quality judgement,
developer-performance evidence, maintainer judgement, or bug prediction.

## Scope and privacy boundaries

The audit covers Python, JavaScript, Go, Lua, Rust, TSX, TypeScript, and Zig
relationship lanes using project-relative checked-in goldens under
`fixtures/expected/symbol-relationships*.json`. It also compares the generated
lane summary in `docs/relationship-fixture-realism-matrix.md` and the prior
relationship output audit documents.

Only project-relative paths, provider names, bounded counts, caveat text classes,
and categorical observations are recorded. This document does not include raw
private reports, absolute local paths, remotes, identities, emails, parser
diagnostics, commit messages, or source snippets.

## Evidence sources

| Lane | Golden | Provider | Records | Unique caveats |
| --- | --- | --- | ---: | ---: |
| Python | `fixtures/expected/symbol-relationships.json` | `tree-sitter-python-relations` | 20 | 5 |
| JavaScript | `fixtures/expected/symbol-relationships-javascript.json` | `tree-sitter-javascript-relations` | 17 | 6 |
| Go | `fixtures/expected/symbol-relationships-go.json` | `tree-sitter-go-relations` | 15 | 7 |
| Lua | `fixtures/expected/symbol-relationships-lua.json` | `tree-sitter-lua-relations` | 16 | 6 |
| Rust | `fixtures/expected/symbol-relationships-rust.json` | `tree-sitter-rust-relations` | 23 | 7 |
| TSX | `fixtures/expected/symbol-relationships-tsx.json` | `tree-sitter-tsx-relations` | 17 | 6 |
| TypeScript | `fixtures/expected/symbol-relationships-typescript.json` | `tree-sitter-typescript-relations` | 25 | 6 |
| Zig | `fixtures/expected/symbol-relationships-zig.json` | `tree-sitter-zig-relations` | 14 | 7 |

The lane counts match the generated fixture realism matrix. The audit did not
modify the goldens or regenerate expected CLI output.

## Classification key

- **No action**: caveat wording is coherent for the current public surface.
- **Docs candidate**: follow-up documentation could make existing wording easier
  to interpret without changing runtime output.
- **Fixture candidate**: follow-up fixture work could represent caveat categories
  more clearly without changing provider semantics.
- **Validation candidate**: follow-up validation could protect wording classes or
  documentation summaries from drift.
- **Runtime/provider candidate**: implementation work would be needed. No such
  candidate is recommended by this audit.

## Cross-lane caveat classes

| Caveat class | Lanes | Classification | Finding |
| --- | --- | --- | --- |
| Product-truth boundary | all lanes | No action | The repeated statement that file-level Git evidence remains product truth is clear and consistent. |
| Optional provider evidence boundary | all lanes | No action | The scoring, ranking, ownership, developer-metrics, and bug-prediction disclaimer is consistent and necessary. |
| Bounded syntax proof summary | all lanes | Docs candidate | Each lane names supported syntax categories, but the phrasing differs enough that a docs summary would help readers compare lanes. |
| Unresolved or external endpoint disclaimer | all lanes | No action | The disclaimers avoid fabricated local, package, module, type, or build-graph truth. |
| Unresolved target record caveat | Python, JavaScript, Lua, Rust, TSX, TypeScript, Zig | No action | Record-level unresolved caveats are honest and lane-specific where needed. |
| Unknown relation-like syntax caveat | Lua, Rust, TSX, TypeScript, Zig | Docs candidate | The wording is conservative, but a docs glossary could explain why unknown syntax is evidence rather than failure. |
| Import or include external-string caveat | JavaScript, Rust, Zig | No action | Each caveat correctly avoids package, crate, module, build graph, and file-system resolution claims. |
| Go broad capability caveat | Go | No action | Go caveat wording mentions imports, calls, selectors, unresolved, and unknown syntax, and the current lane golden now emits stable examples for those categories. |
| TSX and TypeScript shared caveat wording | TSX, TypeScript | No action | Shared wording is acceptable because both lanes use TypeScript-family syntax evidence and differ through record counts. |
| Zig package/build/comptime caveat | Zig | No action | Zig-specific wording is appropriately bounded and avoids build graph, namespace, type, method, comptime, and generated-code truth. |

## Lane findings

### Python

Python caveats are coherent for the current public surface. The lane states that
its proof is bounded to containment, local direct identifier references, direct
calls, imports, unresolved identifiers, and ambiguous attribute syntax. The
record-level unresolved caveat appears only on unresolved targets.

Classification: no action.

### JavaScript

JavaScript caveats are coherent and appropriately separate import/include strings
from local module, Node, package, workspace, and bundler resolution. The bounded
syntax summary covers member and computed syntax caveats without claiming type or
runtime resolution.

Classification: no action.

### Go

Go caveats are coherent. The lane now includes stable import/include, direct
identifier call, local identifier reference, unresolved identifier, and
selector-like syntax examples alongside declaration containment, so the bounded
syntax summary is represented directly by the checked-in golden.

Classification: no action.

### Lua

Lua caveats are coherent and necessary for dynamic table, metatable, callable,
package path, and runtime mutation boundaries. The unknown syntax caveat is
appropriately record-level and does not overclaim relation meaning.

Classification: docs candidate. A future glossary entry could explain
`unknown relation-like syntax` for Lua table/member records in human terms.

### Rust

Rust caveats are coherent. They distinguish external `mod` and `use` strings
from Cargo, crate, module, and file-system resolution, and they caveat ambiguous
path/member syntax without claiming semantic dependency truth.

Classification: no action.

### TSX

TSX caveats are coherent and intentionally conservative for JSX, type-only,
member, and computed syntax. The lane has material unknown and unresolved
volume, but the wording correctly avoids DOM, runtime, type, or package truth.

Classification: docs candidate. The wording is safe, but readers would benefit
from a glossary or matrix note explaining why JSX-heavy syntax often becomes
`unknown` evidence.

### TypeScript

TypeScript shares TypeScript/TSX caveat wording with TSX. That shared wording is
acceptable because the caveat names the family evidence surface while records and
provider names distinguish the lanes.

Classification: no action.

### Zig

Zig caveats are coherent and appropriately specific. They separate `@import`
strings from package lookup, build graph meaning, and file-system resolution, and
they avoid namespace, type, method, comptime, and generated-code truth.

Classification: no action.

## Successor recommendations

1. **Document a relationship caveat glossary.** Completed in
   `docs/user-guide.md`, with README and man page pointers plus validation
   anchors. It remains presentation documentation, not runtime wording or JSON
   schema work.
2. **Keep Go fixture representativeness stable.** Completed as a validation
   contract: the fixture realism matrix and validation guards preserve Go
   import/include, call, reference, unresolved, and selector-like coverage.
3. **Add drift validation for caveat classes.** Completed in
   `tools/validate.sh` as the relationship caveat class drift check. It guards
   caveat classes without prescribing exact prose.
4. **Do not start runtime/provider work from this audit.** Still current. No
   provider algorithm, admission, relation semantic, scoring, ranking, CLI,
   schema, cap, cache, network, telemetry, release, tag, remote, package, or
   publish change is indicated by this audit.

## Remaining watch points

- **Keep Go fixture representativeness stable.** Preserve the current Go
   import/include, call, reference, unresolved, and selector-like examples when
   regenerating fixture outputs unless a future provider contract intentionally
   changes them.
- **Keep caveat-class validation class-based.** Do not tighten it into exact
  prose matching unless a separate wording contract explicitly approves that
  constraint.
- **Avoid runtime/provider follow-up by momentum.** Future provider work should
  come from concrete fixture or real-repo evidence, not from this caveat audit
  alone.

## Requirement coverage

| Requirement | Coverage |
| --- | --- |
| Audit Python, JavaScript, Go, Lua, Rust, TSX, TypeScript, and Zig caveats | Covered in the evidence table and lane findings. |
| Compare repeated, confusing, broad, missing, or lane-inconsistent wording | Covered in cross-lane caveat classes and Go lane finding. |
| Classify findings | Every cross-lane and lane finding uses the required classification set. |
| Preserve runtime behaviour and protected surfaces | Only this documentation file is added; no fixtures, runtime code, schema, or generated report files are changed. |
| Record privacy-safe bounded counts and project-relative paths only | Counts and paths are bounded and project-relative. |
| Avoid provider wording changes except typo-only docs | No provider wording or expected output is changed. |
| Produce durable audit with successor recommendations | This document is the durable audit and includes bounded follow-ups. |

## Validation evidence

Validation was run after producing this audit document.

| Check | Evidence |
| --- | --- |
| Caveat extraction | A local script read checked-in `fixtures/expected/symbol-relationships*.json` goldens and counted record-level caveat classes for all admitted lanes. |
| `git diff --check` | Passed with no output. |
| `zig build test` | Passed. |
| `zig build validate` | Passed all validation rungs, including docs/man surface checks, prohibited-claim scan, git diff whitespace check, deterministic fixture checks, and real repo smoke labelled `this-repo`. |
