# Tree-sitter Go source import evidence

This is the Feature 0036 execution evidence for a non-runtime Go grammar source
import. It records public upstream source identity, a narrow bill of materials,
license and notice handling, generated parser provenance, core compatibility,
source-size measurements, offline validation, and no-provider byte stability.

This feature adds no Go build proof, Go runtime provider, query contract,
provider registry entry, CLI flag, report schema field, scoring change, cache
change, CI/release/package change, network runtime, telemetry, upload, remote
enrichment, or background analysis.

## Imported source identity

- tree-sitter-go is imported under
  `third_party/tree-sitter-go/v0.25.0` from public upstream tag `v0.25.0`, tag
  object `6048bfc6e5238eaf062c2221bd934489c39fbb61`, commit
  `1547678a9da59885853f5f5cc8a99cc203fa2e2c`.
- Source identity is a pinned Git checkout of the selected commit.
- Imported file BOM and any copy notes are recorded in
  `third_party/tree-sitter-go/v0.25.0/IMPORTED_FILES.tsv`.
- Per-component provenance is recorded in
  `third_party/tree-sitter-go/v0.25.0/PROVENANCE.md`.
- Repo-level notice text is recorded in `THIRD_PARTY_NOTICES.md`.

## Bill of materials

Imported files:

- `LICENSE`
- `grammar.js`
- `src/grammar.json`
- `src/node-types.json`
- `src/parser.c`
- `src/tree_sitter/parser.h`

Excluded file classes are bindings for C package metadata, Go, Node, Rust,
Python, and Swift ecosystems; package-manager manifests and lockfiles; CMake,
Make, build, release, CI, editor, funding, benchmark, example, test, corpus,
README, query, and repository administration files.

The upstream `tree-sitter.json` file is not imported in this feature because it
references language bindings and upstream query files that are out of scope for
this source-import proof. Go query support remains explicitly deferred until a
separate query-contract feature.

The vendored `grammar.js` file redacts only upstream author comment lines to
satisfy the repository privacy constraint. Its grammar body is otherwise kept
from the selected upstream revision, and the original upstream Git blob remains
recorded in the manifest.

## Generated parser and scanner basis

`third_party/tree-sitter-go/v0.25.0/src/parser.c` is accepted as a pinned
upstream generated artefact. It is copied byte-for-byte from the selected Git
commit, with Git blob `e3567a9519739c92ae776060dc8d3b4968bc465f`, SHA-256
`3dbf6ed1238b5dfcf2be4d2f2d4cb27a14d34f34d7784eccccbfd532fd4a6d85`, and byte
size `1572685`.

Parser generation was not run locally. Upstream package metadata at the
selected commit declares `tree-sitter-cli` development dependency `^0.25.8`;
this import does not use a global generator, package-manager fetch, or build
input from outside the repository.

No scanner source is imported. The selected upstream revision has no
`src/scanner.c` or `src/scanner.cc`, and the generated parser does not include
an external scanner source.

## Core compatibility

The imported Go parser defines language version `15`. The existing vendored
Tree-sitter core under `third_party/tree-sitter-core/v0.26.9` declares
`TREE_SITTER_LANGUAGE_VERSION` `15` and minimum compatible version `13`.
Therefore the imported Go parser is compatible with the existing core ABI range.
No Tree-sitter core update is included or required by this feature.

## Source-size measurements

Commands used repo-relative paths only:

```sh
find third_party/tree-sitter-go/v0.25.0 -type f -printf '%s %p\n' | sort -nr
find third_party/tree-sitter-go/v0.25.0 -type f -print0 | xargs -0 wc -c
du -sk --exclude=.git --exclude=.zig-cache --exclude=zig-out .
```

Observed source-size evidence:

- Imported source bytes, excluding provenance and manifest files:
  `1855688` bytes.
- Bytes under `third_party/tree-sitter-go/v0.25.0`, including manifest and
  provenance files: `1861477` bytes.
- Go parser size: `1572685` bytes.
- Go scanner size: not applicable; no scanner source is imported.
- Largest imported files:
  1. `third_party/tree-sitter-go/v0.25.0/src/parser.c` - `1572685` bytes.
  2. `third_party/tree-sitter-go/v0.25.0/src/grammar.json` - `198042` bytes.
  3. `third_party/tree-sitter-go/v0.25.0/src/node-types.json` - `52032`
     bytes.
  4. `third_party/tree-sitter-go/v0.25.0/grammar.js` - `24225` bytes.
  5. `third_party/tree-sitter-go/v0.25.0/src/tree_sitter/parser.h` - `7624`
     bytes.
  6. `third_party/tree-sitter-go/v0.25.0/LICENSE` - `1080` bytes.
- Repository working-tree size excluding `.git`, `.zig-cache`, and `zig-out`:
  - Before import: `11756` KiB.
  - After import and evidence files: `13616` KiB.

No planner-review size threshold is triggered: no single imported Go file
exceeds `6000000` bytes, and the Go source import is below `8000000` bytes.

## Validation and build-impact evidence

Validation command shapes:

```sh
time -p zig build validate
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

Observed validation evidence:

| Command summary | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `time -p zig build validate` before import | `0` | Default validation passed in `real 13.60`, `user 12.09`, `sys 4.97`. |
| `time -p zig build validate` after import | `0` | Default validation passed in `real 12.31`, `user 10.98`, `sys 4.53`. |
| `zig build tree-sitter-build-proof` | `0` | Existing Zig proof target passed; no Go build proof is added. |
| `zig build tree-sitter-symbol-proof` | `0` | Existing Zig symbol proof target passed; no Go symbol proof is added. |
| `git diff --check` | `0` | No whitespace errors were reported. |
| `zig build validate -Dcloseout=true ... -Dsmoke-label=sibling-local-repo` | `0` | Close-out validation passed with `this-repo` and `sibling-local-repo` smoke labels only. |

The close-out validation summary reported `PASS` for every rung, including real
repo smoke `this-repo` and real repo smoke `sibling-local-repo`. Its emitted
privacy statement said summaries use labels and bounded counts only, with raw
reports and absolute private paths omitted.

Validation reported local-only behavior: no fetch, pull, push, upload,
telemetry, remote enrichment, CI service, default provider runtime, cache
requirement, packaging, or release automation. Existing opt-in Tree-sitter Zig
symbol proof remains local current-file enrichment and is not expanded by this
feature.

## No-provider byte-stability evidence

Representative table, JSON, Markdown, and inspect outputs were captured before
and after the Go source import using existing fixture commands. Each
before/after pair matched byte-for-byte with `cmp`.

Stable output digests were:

- Table: `a5e76af80689af6cd365c22bf37aa5a04f6173c6147ba2de076f9005cbf3c02a`.
- JSON: `3437fc55042e9725d97e76652d97397a0f0fb724a6510b5d670003c632018fb3`.
- Markdown: `987dffcbf88e2bc081c4cd0b593b1724dde1041e29da0f5a0329cc8c62b12f75`.
- Inspect JSON:
  `96495ca536a5c6019192eeb27f4b2abd9ac67a8f36b6483f7ac745382a73d292`.

## Protected-surface evidence

Protected runtime, test, fixture, expected-output, package-manifest, validation
script, provider, scoring, report, and CLI paths were not changed by this
feature. The expected protected scan command is:

```sh
git diff --name-only -- src tests fixtures build.zig build.zig.zon .github tools/validate.sh
```

The expected result is no output. The feature also keeps `.gitmodules` and
`build.zig.zon` absent, and uses ordinary tracked files rather than submodules.

## Close-out smoke privacy

The close-out smoke command uses a local operator-supplied repository and the
privacy-safe label `sibling-local-repo`. Committed evidence intentionally omits
the absolute sibling path, private repository name, raw private report output,
author identities, source snippets, remotes, and commit messages.

## Feature 0036 evidence set

- Source identity: public upstream tag `v0.25.0`, tag object
  `6048bfc6e5238eaf062c2221bd934489c39fbb61`, commit
  `1547678a9da59885853f5f5cc8a99cc203fa2e2c`.
- BOM: six imported source or license files, plus repo-owned manifest and
  provenance files. The `grammar.js` copy removes only upstream author comment
  lines under the explicit privacy constraint.
- License and notice: upstream MIT license copied unchanged to the vendored
  component path and repo notice updated.
- Generated parser provenance: Go `src/parser.c` accepted as a pinned upstream
  generated artefact from the selected commit; no local generator or package
  manager is used.
- Scanner provenance: no scanner source exists or is imported for the selected
  revision.
- Core compatibility: Go parser language version `15` fits the existing core
  compatible range `13..15`.
- Validation: default validation, existing Tree-sitter Zig proof targets,
  whitespace check, no-provider output comparison, and close-out smoke all
  passed.
- Boundary proof: no Go build/runtime/provider/query/CLI/report/schema/scoring/
  cache/CI/release/package behavior is added.
- Privacy proof: committed evidence uses repo-relative paths and public upstream
  component identifiers only; it omits private paths, private repo names, raw
  sibling output, raw parser stderr, source snippets, remotes, author
  identities, commercial strategy, bug-prediction claims, quality scoring,
  developer ranking, and maintainer judgement.
