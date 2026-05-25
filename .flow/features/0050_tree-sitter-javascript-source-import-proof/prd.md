# PRD: JavaScript Tree-sitter source import proof

## Summary

Import a pinned, narrow `tree-sitter-javascript` source set into the repository
as a source-import and provenance proof only. The feature resolves the admission
blockers from Feature 0048 that can be proven at source-import time: immutable
revision, checkout or archive identity, license and notice handling, generated
parser and scanner provenance, bill of materials, Tree-sitter core
compatibility, source-size impact, offline validation, JSX admission evidence,
and no-provider output stability.

This feature must not add JavaScript parser build integration, JavaScript
runtime provider behaviour, provider registry entries, CLI flags, report schema
fields, scoring changes, cache changes, query fixtures, symbol extraction, CI
changes, release work, package publishing, network access, telemetry, upload,
remote enrichment, Node provider identity, package/workspace/module analysis,
or background provider execution.

## Problem

Feature 0048 recorded `tree-sitter-javascript` as a plausible future grammar but
left it in `conditionaljavascript` state. The remaining blockers include exact
immutable source identity, license and notice verification, generated parser and
scanner provenance, BOM selection, JSX source admission proof, source-size
evidence, core compatibility, offline validation, and no-provider output
stability. JavaScript runtime support should not proceed until the source import
itself is reviewable and local-first.

## Outcome

A pinned `tree-sitter-javascript` source set is vendored under
`third_party/tree-sitter-javascript/<revision>/` with provenance, imported-file
manifest, license/notice handling, JSX admission evidence, and source-import
evidence. The repository still has no JavaScript runtime support after this
feature; it only has reviewed local source inputs for later build, query, and
extraction proofs.

## Requirements

### R1 Source import scope

- Select an immutable `tree-sitter-javascript` revision: tag plus full commit,
  or full commit when no suitable tag exists.
- Import a narrow source set under
  `third_party/tree-sitter-javascript/<revision>/`.
- Add or update only source-import artefacts, provenance/evidence docs,
  notices, and Flow state.
- Do not change `src/`, `tests/`, `fixtures/`, `build.zig`, `build.zig.zon`,
  `.github/`, `tools/validate.sh`, CLI flags, report schemas, scoring, cache,
  provider runtime, provider registry, CI, release, or package behaviour.

### R2 Exact source identity

The import must record:

- upstream URL;
- selected immutable tag and full commit, or selected full commit with reason;
- canonical source basis, such as pinned checkout or named archive;
- SHA-256 checksum for any archive used;
- per-file imported manifest;
- vendored path;
- imported feature id; and
- import date.

If an archive checksum is not used because a pinned checkout is the source
basis, record that reason explicitly and include enough per-file identity for
review.

### R3 License and notice

The import must:

- verify the upstream license at the selected revision;
- copy upstream license text unchanged into the vendored component path;
- preserve required copyright and notice text;
- update `THIRD_PARTY_NOTICES.md` with public upstream attribution; and
- stop as blocked for missing, ambiguous, changed, or incompatible license or
  notice terms.

### R4 Generated parser and scanner provenance

The import must identify generated parser and scanner files, expected to include
`src/parser.c` and any `src/scanner.c`, `src/scanner.cc`, or equivalent scanner
files if present. It must do one of:

1. reproduce generated files from pinned grammar inputs and an exact
   Tree-sitter generator using local inputs only; or
2. verify generated files against pinned upstream artefacts with hashes, Git
   blob ids, or equivalent immutable evidence, and record why accepting the
   upstream generated artefact is deterministic and reviewable.

The import must explicitly prove scanner presence or absence for the selected
revision. If a scanner is present, it must be included in the BOM only when its
license/provenance gates are satisfied.

The feature must not add a global Tree-sitter CLI dependency, package-manager
fetch, build-time generation dependency, or network generation step. The feature
must not close with unresolved generated parser or scanner provenance.

### R5 Narrow bill of materials

The import should include only files needed for future local parser build and
symbol-query review:

- upstream license and notice files;
- grammar metadata such as `tree-sitter.json` when present;
- grammar source files needed to review parser generation;
- generated C parser files and required scanner files;
- required parser headers or binding metadata when needed by generated C
  sources;
- helper headers required by the scanner when the selected revision requires
  them;
- node type metadata required for query design;
- provenance and imported-file manifest files.

The import must exclude package-manager lockfiles and install metadata, CI and
release files, prebuilt binaries, wasm artefacts, playgrounds, examples,
benchmarks, editor integrations, language bindings, runtime registry wiring,
custom user queries, TypeScript grammar files, TSX support files, Node wrappers,
package/workspace metadata, and provider implementation unless a file is
explicitly justified in the BOM.

### R6 Tree-sitter core compatibility

The import must prove that the selected JavaScript grammar language version is
compatible with the existing vendored Tree-sitter core ABI and language-version
range from `third_party/tree-sitter-core/v0.26.9`.

If the selected JavaScript grammar requires a newer Tree-sitter core, this
feature must stop or record a blocker. A Tree-sitter core update is out of
scope.

### R7 JSX admission evidence

The import must inspect the selected revision and record whether `.jsx` can be
supported by the selected JavaScript grammar using repository-local inputs. If
JSX support can be proven, the source-import evidence must record the proof
basis and future fixture expectation. If JSX cannot be proven locally for the
selected revision, `.jsx` must be explicitly deferred while `.js`, `.mjs`, and
`.cjs` remain eligible for later JavaScript features.

The feature must not import TypeScript or TSX grammar sources and must not claim
`.ts`, `.mts`, `.cts`, or `.tsx` support.

### R8 Local-first and offline boundary

The import must prove that validation uses only repository-local inputs. It
must not introduce:

- build-time network fetches;
- Git submodules;
- package-manager resolution;
- system Tree-sitter packages;
- global parser packages or CLI dependencies;
- remote parser services;
- telemetry;
- upload;
- remote enrichment;
- package/workspace/module analysis; or
- background provider execution.

Any source acquisition done during execution must be a runner-time import action
only; committed build/runtime paths must remain offline and local.

### R9 Source-size and build-impact evidence

The import evidence must record:

- bytes added under `third_party/tree-sitter-javascript/<revision>/`;
- largest ten imported files by byte size;
- parser and scanner sizes or explicit scanner absence;
- repository working-tree size before and after import, excluding `.git`,
  `.zig-cache`, and `zig-out`;
- `zig build validate` before and after import;
- before/after validation timing summaries where practical; and
- planner-review note if size or timing materially changes source-install
  experience.

### R10 No-provider output stability

The feature must prove that existing no-provider outputs remain stable. Required
coverage includes representative table, JSON, Markdown, and inspect outputs.

JavaScript provider output is out of scope and must not be produced by this
feature.

### R11 Public evidence and future sequencing

The evidence document must state that JavaScript runtime support is still not
implemented. Expected path:

```text
docs/tree-sitter-javascript-source-import-evidence.md
```

It must identify the next likely follow-up as JavaScript offline build proof or
record blockers if import gates failed.

It must explicitly defer:

- JavaScript parser compile/link proof;
- JavaScript extraction proof;
- JavaScript symbol query fixtures;
- inspect-only JavaScript symbol output;
- provider registry changes;
- CLI/report/schema/scoring/cache changes;
- TypeScript and TSX grammar work;
- LSP;
- custom user query execution;
- `package.json`, workspace, bundler, dependency graph, module resolution,
  Node provider identity, and repo-wide scanning behaviour.

## Acceptance criteria

- `third_party/tree-sitter-javascript/<revision>/` exists with a narrow imported
  source set.
- The vendored JavaScript component includes unchanged upstream license/notice
  text.
- The vendored JavaScript component includes `PROVENANCE.md` and
  `IMPORTED_FILES.tsv`.
- `THIRD_PARTY_NOTICES.md` is updated with public, repo-relative JavaScript
  attribution.
- A source-import evidence document records immutable source identity, generated
  parser/scanner provenance, Tree-sitter core compatibility, JSX admission
  state, source-size measurements, offline validation, and no-provider output
  stability.
- No JavaScript build, runtime provider, provider registry, CLI, report schema,
  scoring, cache, test fixture, CI, release, package, TypeScript, TSX, Node, or
  package/workspace behaviour is added.
- The feature stops as blocked rather than closing if immutable revision,
  license/notice, generated parser/scanner provenance, core compatibility, BOM
  narrowness, JSX decision, or no-provider stability cannot be proven.

## Edge cases

- If no suitable tag exists, pin a full commit and explain why no tag was used.
- If the selected source archive checksum cannot be recorded, use a pinned
  checkout basis and record per-file manifest evidence instead of guessing.
- If generated parser or scanner files cannot be reproduced or verified, stop as
  blocked.
- If the JavaScript grammar uses an external scanner, include it only if it is
  required by the generated parser and provenance/license gates are satisfied.
- If JSX cannot be proven locally for the selected revision, defer `.jsx` rather
  than blocking `.js`, `.mjs`, and `.cjs` source import.
- If the JavaScript grammar requires a newer Tree-sitter core than the current
  vendored core, stop for a separate core-update feature.
- If the BOM requires package manager, binding, TypeScript, TSX, Node, or
  workspace files to function, stop and reshape.

## Verification

Close-out must include evidence for:

```sh
git diff --check
zig build validate
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build tree-sitter-go-build-proof
zig build tree-sitter-go-symbol-proof
zig build tree-sitter-python-build-proof
zig build tree-sitter-python-symbol-proof
changed-path scan for source-import-only scope
provenance/license/BOM scan
generated parser/scanner provenance check
no-provider output stability check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

Evidence must use repo-relative paths and privacy-safe labels only. It must not
record absolute sibling paths, raw private reports, raw parser stderr dumps,
source snippets from private repos, remotes, author identities, commercial
strategy, bug prediction, quality scoring, developer ranking, or maintainer
judgement.
