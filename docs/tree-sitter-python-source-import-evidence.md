# Tree-sitter Python source import evidence

This is the Feature 0042 execution evidence for a non-runtime Python grammar
source import. It records public upstream source identity, a narrow bill of
materials, license and notice handling, generated parser and scanner
provenance, core compatibility, source-size measurements, offline validation,
and no-provider byte stability.

This feature adds no Python build proof, Python runtime provider, query
contract, provider registry entry, CLI flag, report schema field, scoring
change, cache change, CI/release/package change, network runtime, telemetry,
upload, remote enrichment, or background analysis.

## Imported source identity

- tree-sitter-python is imported under
  `third_party/tree-sitter-python/v0.25.0` from public upstream tag `v0.25.0`,
  tag object `d326e4cad262cf681656e130960e49dfc04c03ea`, commit
  `293fdc02038ee2bf0e2e206711b69c90ac0d413f`.
- Source identity is a pinned Git checkout of the selected commit.
- Imported file BOM and any copy notes are recorded in
  `third_party/tree-sitter-python/v0.25.0/IMPORTED_FILES.tsv`.
- Per-component provenance is recorded in
  `third_party/tree-sitter-python/v0.25.0/PROVENANCE.md`.
- Repo-level notice text is recorded in `THIRD_PARTY_NOTICES.md`.

## Bill of materials

Imported files:

- `LICENSE`
- `grammar.js`
- `src/grammar.json`
- `src/node-types.json`
- `src/parser.c`
- `src/scanner.c`
- `src/tree_sitter/alloc.h`
- `src/tree_sitter/array.h`
- `src/tree_sitter/parser.h`

Excluded file classes are binding metadata for C package, Go, Node, Python,
Rust, and Swift ecosystems; package-manager manifests and lockfiles; CMake,
Make, build, release, CI, editor, funding, example, test, corpus, README,
query, grammar metadata with binding references, and repository administration
files.

The upstream `tree-sitter.json` file is not imported in this feature because it
references language bindings and upstream query files that are out of scope for
this source-import proof. Python query support remains explicitly deferred
until a separate query-contract feature.

The vendored `grammar.js` file redacts only the upstream author comment line to
satisfy the repository privacy constraint. Its grammar body is otherwise kept
from the selected upstream revision, and the original upstream Git blob remains
recorded in the manifest.

## Generated parser and scanner basis

`third_party/tree-sitter-python/v0.25.0/src/parser.c` is accepted as a pinned
upstream generated artefact. It is copied byte-for-byte from the selected Git
commit, with Git blob `c7ca6bf7cb920fc90c1de0234ba5d5b9433ba317`, SHA-256
`a895f10b3cf7b2608f3283b43cd5cfed70971c7ee4a0136abbaaccbc4a7a25e0`, and byte
size `3439646`.

Parser generation was not run locally. Upstream package metadata at the
selected commit declares `tree-sitter-cli` development dependency `^0.25.9`;
this import does not use a global generator, package-manager fetch, or build
input from outside the repository.

`third_party/tree-sitter-python/v0.25.0/src/scanner.c` is accepted as a pinned
upstream scanner artefact. It is copied byte-for-byte from the selected Git
commit, with Git blob `1fc77cdbdee6c7d33c183dc8c2bc3b64c9b0a410`, SHA-256
`6db82134ac2d4c90a1a1475487a625cface02662ebda9b7478cad9c7147e9afe`, and byte
size `15470`.

The scanner source is required by the selected generated parser: `parser.c`
declares external scanner entry points and `EXTERNAL_TOKEN_COUNT 12`. The
scanner's local helper chain is included narrowly: `scanner.c` needs
`tree_sitter/array.h` and `tree_sitter/parser.h`, and `array.h` needs
`tree_sitter/alloc.h`. No other helper headers are imported.

Python parser compilation was not run locally. Future Python runtime work must
shape a separate compile proof before linking or executing these sources.

## Core compatibility

The imported Python parser defines language version `15`. The existing vendored
Tree-sitter core under `third_party/tree-sitter-core/v0.26.9` declares
`TREE_SITTER_LANGUAGE_VERSION` `15` and minimum compatible version `13`.
Therefore the imported Python parser is compatible with the existing core ABI
range. No Tree-sitter core update is included or required by this feature.

## Source-size measurements

Commands used repo-relative paths only:

```sh
find third_party/tree-sitter-python/v0.25.0 -type f -printf '%s %p\n' | sort -nr
find third_party/tree-sitter-python/v0.25.0 -type f -print0 | xargs -0 wc -c
du -sk --exclude=.git --exclude=.zig-cache --exclude=zig-out .
```

Observed source-size evidence:

- Imported source bytes, excluding provenance and manifest files:
  `3712005` bytes.
- Bytes under `third_party/tree-sitter-python/v0.25.0`, including manifest and
  provenance files: `3718998` bytes.
- Python parser size: `3439646` bytes.
- Python scanner size: `15470` bytes.
- Largest upstream imported source/license files, excluding provenance and
  manifest files (nine files total):
  1. `third_party/tree-sitter-python/v0.25.0/src/parser.c` - `3439646` bytes.
  2. `third_party/tree-sitter-python/v0.25.0/src/grammar.json` - `145051`
     bytes.
  3. `third_party/tree-sitter-python/v0.25.0/src/node-types.json` - `64995`
     bytes.
  4. `third_party/tree-sitter-python/v0.25.0/grammar.js` - `26723` bytes.
  5. `third_party/tree-sitter-python/v0.25.0/src/scanner.c` - `15470` bytes.
  6. `third_party/tree-sitter-python/v0.25.0/src/tree_sitter/array.h` -
     `10431` bytes.
  7. `third_party/tree-sitter-python/v0.25.0/src/tree_sitter/parser.h` -
     `7624` bytes.
  8. `third_party/tree-sitter-python/v0.25.0/LICENSE` - `1080` bytes.
  9. `third_party/tree-sitter-python/v0.25.0/src/tree_sitter/alloc.h` - `985`
     bytes.
- Repo-owned evidence files under the same directory are excluded from the list
  above but included in the full directory total: `PROVENANCE.md` is `5108`
  bytes and `IMPORTED_FILES.tsv` is `1885` bytes.
- Repository working-tree size excluding `.git`, `.zig-cache`, and `zig-out`:
  - Before import: `17536` KiB.
  - After import and evidence files: `21192` KiB.

No planner-review size threshold is triggered: no single imported Python file
exceeds `6000000` bytes, and the Python source import is below `8000000` bytes.

## Validation and build-impact evidence

Validation command shapes:

```sh
time -p zig build validate
git diff --check
git diff --cached --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

Observed validation evidence:

| Command summary | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `time -p zig build validate` before import | `0` | Default validation passed in `real 15.54`, `user 13.35`, `sys 5.92`. |
| `time -p zig build validate` after import | `0` | Default validation passed in `real 15.73`, `user 13.31`, `sys 5.89`. |
| `zig build validate -Dcloseout=true ... -Dsmoke-label=sibling-local-repo` | `0` | Close-out validation passed with `this-repo` and `sibling-local-repo` smoke labels only. |

The close-out validation summary reported `PASS` for every rung, including real
repo smoke `this-repo` and real repo smoke `sibling-local-repo`. Its emitted
privacy statement said summaries use labels and bounded counts only, with raw
reports and absolute private paths omitted.

Validation reported local-only behavior: no fetch, pull, push, upload,
telemetry, remote enrichment, CI service, default provider runtime, cache
requirement, packaging, or release automation. Existing opt-in Tree-sitter Zig
or Go symbol proof remains local current-file enrichment and is not expanded by
this feature.

## No-provider byte-stability evidence

Representative table, JSON, Markdown, and inspect outputs were captured before
and after the Python source import using existing fixture commands. Each
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

## Feature 0042 evidence set

- Source identity: public upstream tag `v0.25.0`, tag object
  `d326e4cad262cf681656e130960e49dfc04c03ea`, commit
  `293fdc02038ee2bf0e2e206711b69c90ac0d413f`.
- BOM: nine imported source, header, or license files, plus repo-owned manifest
  and provenance files. The `grammar.js` copy removes only the upstream author
  comment line under the explicit privacy constraint.
- License and notice: upstream MIT license copied unchanged to the vendored
  component path and repo notice updated.
- Generated parser provenance: Python `src/parser.c` accepted as a pinned
  upstream generated artefact from the selected commit; no local generator or
  package manager is used.
- Scanner provenance: `src/scanner.c` and required local helper headers are
  imported because the selected generated parser declares external scanner entry
  points.
- Core compatibility: Python parser language version `15` fits the existing
  core compatible range `13..15`.
- Validation: default validation, source-import gate checks, whitespace checks,
  no-provider output comparison, and close-out smoke all passed.
- Boundary proof: no Python build/runtime/provider/query/CLI/report/schema/
  scoring/cache/CI/release/package behavior is added.
- Privacy proof: committed evidence uses repo-relative paths and public
  upstream component identifiers only; it omits private paths, private repo
  names, raw sibling output, raw parser stderr, author identities, commercial
  strategy, bug-prediction claims, quality scoring, developer ranking, and
  maintainer judgement.
