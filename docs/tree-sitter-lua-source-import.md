# Tree-sitter Lua source import evidence

This is the Feature 0065 execution evidence for a non-runtime Lua grammar
source import. It records public upstream source identity, a narrow bill of
materials, license and notice handling, generated parser and scanner
provenance, core compatibility, `.lua` path admission evidence, source-size
measurements, offline validation, and no-provider byte stability.

This feature adds no Lua build proof, Lua runtime provider, query contract,
provider registry entry, CLI flag, report schema field, scoring change, cache
change, CI/release/package change, network runtime, telemetry, upload, remote
enrichment, package-path analysis, module resolution, LuaRocks support, or
background analysis.

## Imported source identity

- tree-sitter-lua is imported under
  `third_party/tree-sitter-lua/v0.5.0` from public upstream tag `v0.5.0`, a
  lightweight tag resolving directly to commit
  `10fe0054734eec83049514ea2e718b2a56acd0c9`.
- Source identity is a pinned Git checkout of the selected commit.
- Imported file BOM and any copy notes are recorded in
  `third_party/tree-sitter-lua/v0.5.0/IMPORTED_FILES.tsv`.
- Per-component provenance is recorded in
  `third_party/tree-sitter-lua/v0.5.0/PROVENANCE.md`.
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
- `src/tree_sitter/parser.h`

Excluded file classes are binding metadata for C package, Go, Node, Python,
Rust, and Swift ecosystems; package-manager manifests and lockfiles; CMake,
Make, build, release, CI, editor, playground, benchmark, example, test, corpus,
README, query, grammar metadata with binding and query references, LuaRocks or
package-path metadata, wasm or prebuilt artefacts, and repository
administration files.

The upstream `tree-sitter.json` file is not imported in this feature because it
references language bindings and upstream query files that are out of scope for
this source-import proof. The selected upstream metadata was inspected only to
confirm the public candidate's `.lua` file-type claim. Lua query support remains
explicitly deferred until a separate query-contract feature.

The vendored `grammar.js` file redacts only the upstream author comment line to
satisfy the repository privacy constraint. Its grammar body is otherwise kept
from the selected upstream revision, and the original upstream Git blob remains
recorded in the manifest.

## Generated parser and scanner basis

`third_party/tree-sitter-lua/v0.5.0/src/parser.c` is accepted as a pinned
upstream generated artefact. It is copied byte-for-byte from the selected Git
commit, with Git blob `b9a46a7bf11538f30582a49008ba5bb12de975ce`, SHA-256
`933206d96a78f7785c13b2600182f1527dcd755c200b1271bb5bc4d8da4b17b3`, and byte
size `356379`.

Parser generation was not run locally. Upstream package metadata at the
selected commit declares `tree-sitter-cli` development dependency `^0.25.3`;
this import does not use a global generator, package-manager fetch, or build
input from outside the repository.

`third_party/tree-sitter-lua/v0.5.0/src/scanner.c` is accepted as a pinned
upstream scanner artefact. It is copied byte-for-byte from the selected Git
commit, with Git blob `e257c2dc0ba1712938339850488aa6026f91a7f1`, SHA-256
`35bbd630b5a7421d46d2e91185eeea09bf78565d44cb676b63ca20d0f1b54bbd`, and byte
size `4559`.

The scanner source is required by the selected generated parser: `parser.c`
declares external scanner entry points and `EXTERNAL_TOKEN_COUNT 6`. The
scanner's local helper chain is included narrowly: `scanner.c` needs
`tree_sitter/alloc.h` and `tree_sitter/parser.h`. No other helper headers are
imported.

Lua parser compilation was not run locally. Future Lua runtime work must shape
a separate compile proof before linking or executing these sources.

## Core compatibility

The imported Lua parser defines language version `15`. The existing vendored
Tree-sitter core under `third_party/tree-sitter-core/v0.26.9` declares
`TREE_SITTER_LANGUAGE_VERSION` `15` and minimum compatible version `13`.
Therefore the imported Lua parser is compatible with the existing core ABI
range. No Tree-sitter core update is included or required by this feature.

## Lua path admission evidence

The selected upstream `tree-sitter.json` declares grammar name `lua` and file
type `lua`. That upstream metadata supports the previously admitted narrow path
rule: future Lua provider work must remain inspect-path-only and
extension-based, and a requested inspect path ending in `.lua` may be considered
a Lua candidate only after a separate Lua runtime feature exists.

This source import does not implement that path rule. It does not add `require`
resolution, module resolution, LuaRocks package discovery, package-path
analysis, dependency graph inference, runtime execution, LSP integration,
repo-wide scanning, provider registry wiring, CLI behavior, or report schema
behavior. Unsupported or ambiguous future Lua paths should fail closed with a
visible provider caveat while preserving file-level Git evidence.

## Source-size measurements

Commands used repo-relative paths only:

```sh
find third_party/tree-sitter-lua/v0.5.0 -type f -printf '%s %p\n' | sort -nr
find third_party/tree-sitter-lua/v0.5.0 -type f -print0 | xargs -0 wc -c
du -sk --exclude=.git --exclude=.zig-cache --exclude=zig-out .
```

Observed source-size evidence:

- Imported source bytes, excluding provenance and manifest files:
  `498099` bytes.
- Bytes under `third_party/tree-sitter-lua/v0.5.0`, including manifest and
  provenance files: `504933` bytes.
- Lua parser size: `356379` bytes.
- Lua scanner size: `4559` bytes.
- Largest upstream imported source/license files, excluding provenance and
  manifest files (eight files total):
  1. `third_party/tree-sitter-lua/v0.5.0/src/parser.c` - `356379` bytes.
  2. `third_party/tree-sitter-lua/v0.5.0/src/grammar.json` - `84462` bytes.
  3. `third_party/tree-sitter-lua/v0.5.0/src/node-types.json` - `25185`
     bytes.
  4. `third_party/tree-sitter-lua/v0.5.0/grammar.js` - `17826` bytes.
  5. `third_party/tree-sitter-lua/v0.5.0/src/tree_sitter/parser.h` - `7624`
     bytes.
  6. `third_party/tree-sitter-lua/v0.5.0/src/scanner.c` - `4559` bytes.
  7. `third_party/tree-sitter-lua/v0.5.0/LICENSE` - `1079` bytes.
  8. `third_party/tree-sitter-lua/v0.5.0/src/tree_sitter/alloc.h` - `985`
     bytes.
- Repo-owned evidence files under the same directory are excluded from the list
  above but included in the full directory total: `PROVENANCE.md` is `5184`
  bytes and `IMPORTED_FILES.tsv` is `1650` bytes.
- Repository working-tree size excluding `.git`, `.zig-cache`, and `zig-out`:
  - Before import: `54732` KiB.
  - After import and evidence files: `55264` KiB.

No planner-review size threshold is triggered: no single imported Lua file
exceeds `6000000` bytes, and the Lua source import is below `8000000` bytes.

## Validation and build-impact evidence

Validation command shapes:

```sh
time -p zig build validate
git diff --check
git status --short -- src tests fixtures build.zig build.zig.zon .github tools/validate.sh
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

Observed validation evidence:

| Command summary | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `time -p zig build validate` before import | `0` | Default validation passed in `real 25.78`, `user 24.44`, `sys 8.63`. |
| `time -p zig build validate` after import | `0` | Default validation passed in `real 25.57`, `user 24.00`, `sys 8.51`. |
| `git diff --check` | `0` | No whitespace errors were reported. |
| Protected surface changed-path scan | `0` | No protected source, test, fixture, build, CI, or validation-script paths changed. |
| `zig build validate -Dcloseout=true ... -Dsmoke-label=sibling-local-repo` | `0` | Close-out validation passed with `this-repo` and `sibling-local-repo` smoke labels only. |

The close-out validation summary reported `PASS` for every rung, including real
repo smoke `this-repo` and real repo smoke `sibling-local-repo`. Its emitted
privacy statement said summaries use labels and bounded counts only, with raw
reports and absolute private paths omitted.

Validation reported local-only behavior: no fetch, pull, push, upload,
telemetry, remote enrichment, CI service, default provider runtime, cache
requirement, packaging, or release automation. Existing opt-in Tree-sitter Zig,
Go, Python, JavaScript, TypeScript, or TSX symbol proof remains local
current-file enrichment and is not expanded by this feature.

## No-provider byte-stability evidence

Representative table, JSON, Markdown, and inspect outputs were captured before
and after the Lua source import using existing fixture commands. Each
after-import output matched its before-import counterpart byte-for-byte with
`cmp`.

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
git status --short -- src tests fixtures build.zig build.zig.zon .github tools/validate.sh
```

The expected result is no output. The feature also keeps `.gitmodules` and
`build.zig.zon` absent, and uses ordinary tracked files rather than submodules.

## Close-out smoke privacy

The close-out smoke command uses a local operator-supplied repository and the
privacy-safe label `sibling-local-repo`. Committed evidence intentionally omits
the absolute sibling path, private repository name, raw private report output,
author identities, source snippets, remotes, and commit messages.

## Feature 0065 evidence set

- Source identity: public upstream tag `v0.5.0`, lightweight tag commit
  `10fe0054734eec83049514ea2e718b2a56acd0c9`.
- BOM: eight imported source, header, or license files, plus repo-owned manifest
  and provenance files. The `grammar.js` copy removes only the upstream author
  comment line under the explicit privacy constraint.
- License and notice: upstream MIT license copied unchanged to the vendored
  component path and repo notice updated.
- Generated parser provenance: Lua `src/parser.c` accepted as a pinned upstream
  generated artefact from the selected commit; no local generator or package
  manager is used.
- Scanner provenance: `src/scanner.c` and required local helper headers are
  imported because the selected generated parser declares external scanner
  entry points.
- Core compatibility: Lua parser language version `15` fits the existing core
  compatible range `13..15`.
- `.lua` path evidence: selected upstream metadata declares file-type `lua`, but
  runtime path handling remains deferred to a separate feature.
- Validation: default validation, source-import gate checks, whitespace checks,
  no-provider output comparison, protected-surface scan, and close-out smoke all
  passed.
- Boundary proof: no Lua build/runtime/provider/query/CLI/report/schema/
  scoring/cache/CI/release/package behavior is added.

This document is source-import evidence only. It is not evidence that Lua
runtime support exists.
