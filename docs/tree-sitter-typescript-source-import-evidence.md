# Tree-sitter TypeScript source import evidence

This is the Feature 0056 execution evidence for a non-runtime TypeScript and
TSX grammar source import. It records public upstream source identity, a narrow
bill of materials, license and notice handling, generated parser and scanner
provenance, Tree-sitter core compatibility, extension admission state,
source-size measurements, offline validation, and no-provider byte stability.

This feature adds no TypeScript/TSX build proof, TypeScript/TSX runtime
provider, query contract, provider registry entry, CLI flag, report schema
field, scoring change, cache change, fixture, CI/release/package change,
package/workspace/module or `tsconfig` analysis, Node provider identity, LSP
integration, network runtime, telemetry, upload, remote enrichment, or
background analysis.

Next likely follow-up: TypeScript/TSX offline build proof. That future feature
should prove local parser compile/link behavior for the pinned TypeScript and
TSX sources before any runtime provider or symbol output work is claimed.

## Imported source identity

- tree-sitter-typescript is imported under
  `third_party/tree-sitter-typescript/v0.23.2` from public upstream tag
  `v0.23.2`, a lightweight tag whose ref equals commit
  `f975a621f4e7f532fe322e13c4f79495e0a7b2e7`.
- Source identity is a pinned Git checkout of the selected commit.
- Imported file BOM and copy notes are recorded in
  `third_party/tree-sitter-typescript/v0.23.2/IMPORTED_FILES.tsv`.
- Per-component provenance is recorded in
  `third_party/tree-sitter-typescript/v0.23.2/PROVENANCE.md`.
- Repo-level notice text is recorded in `THIRD_PARTY_NOTICES.md`.
- No source archive checksum is used; per-file SHA-256 and upstream Git blob
  evidence in `IMPORTED_FILES.tsv` is the checksum basis for this checkout
  import.

## Bill of materials

Imported files:

- `LICENSE`
- `common/define-grammar.js`
- `common/scanner.h`
- `typescript/grammar.js`
- `typescript/src/grammar.json`
- `typescript/src/node-types.json`
- `typescript/src/parser.c`
- `typescript/src/scanner.c`
- `typescript/src/tree_sitter/parser.h`
- `tsx/grammar.js`
- `tsx/src/grammar.json`
- `tsx/src/node-types.json`
- `tsx/src/parser.c`
- `tsx/src/scanner.c`
- `tsx/src/tree_sitter/parser.h`

Excluded file classes are binding metadata and wrappers for C package, Go, Node,
Python, Rust, and Swift ecosystems; package-manager manifests and lockfiles;
CMake, Make, build, release, CI, editor, benchmark, example, test, corpus,
README, upstream query, grammar metadata with binding/query/person metadata,
wasm or prebuilt artefacts, and repository administration files.

The upstream `tree-sitter.json` file is not imported in this feature because it
contains binding metadata, upstream query references, Flow grammar metadata, and
person-level metadata that are not needed for this source-import proof.
TypeScript/TSX query support remains explicitly deferred until a separate
query-contract feature.

## Generated parser and scanner basis

`third_party/tree-sitter-typescript/v0.23.2/typescript/src/parser.c` is accepted
as a pinned upstream generated artefact. It is copied byte-for-byte from the
selected Git commit, with Git blob `a88f8e155319a834b11fa96f13821de99f7d64f2`,
SHA-256 `74fe453edd70f4eae9af0a1050cbd7943d8971d59165b6aaebbaa0a0b716d1aa`,
and byte size `8745894`.

`third_party/tree-sitter-typescript/v0.23.2/tsx/src/parser.c` is accepted as a
pinned upstream generated artefact. It is copied byte-for-byte from the
selected Git commit, with Git blob `faa8aa40839fe3c48974c474c3209abfb3f5b7b5`,
SHA-256 `1902cb53fa7ff5179df89b2eea863165e84c8cc866226419dc26921d8c055885`,
and byte size `8769870`.

Parser generation was not run locally. Upstream package metadata at the selected
commit declares `tree-sitter-cli` development dependency `^0.24.4`; this import
does not use a global generator, package-manager fetch, or build input from
outside the repository.

The TypeScript scanner wrapper
`third_party/tree-sitter-typescript/v0.23.2/typescript/src/scanner.c` is copied
byte-for-byte from the selected Git commit, with Git blob
`ebdb193eaf11c48d7e9d1e75c796f43fdb989278`, SHA-256
`9125013b42cb888379d9be909f1d73dfb75a37626c2cdbf4122718a2b431a6d3`, and byte
size `573`.

The TSX scanner wrapper
`third_party/tree-sitter-typescript/v0.23.2/tsx/src/scanner.c` is copied
byte-for-byte from the selected Git commit, with Git blob
`ac3f57ce5a3b21fc1b9d7ca2358b4b5a2c7dfc2d`, SHA-256
`d563cd30b2f39718c9ae4292795c5ce03a2ad01954ba3a86ef84c2781a736673`, and byte
size `538`.

The shared scanner source
`third_party/tree-sitter-typescript/v0.23.2/common/scanner.h` is copied
byte-for-byte from the selected Git commit, with Git blob
`23b78b5bc53dace668064eb952dff903022154aa`, SHA-256
`da66ef2bd14a3f7ea743e25ba068c6c9aae2c3509db200ff80c4a0e6116e564c`, and byte
size `10097`.

Both generated parsers declare `EXTERNAL_TOKEN_COUNT 10` and reference their
external scanner entry points, so the scanner wrappers and shared scanner source
are required for any future parser compile proof. The scanner helper chain is
narrow: imported parser sources include `tree_sitter/parser.h`; imported scanner
wrappers include `../../common/scanner.h`; and `common/scanner.h` includes
`tree_sitter/parser.h` through the grammar-specific include path. The only
Tree-sitter helper headers imported are therefore the two byte-identical
`src/tree_sitter/parser.h` copies for the TypeScript and TSX source trees. The
upstream `alloc.h` and `array.h` files are excluded because no imported parser
or scanner source includes them.

TypeScript/TSX parser compilation was not run locally. Future TypeScript/TSX
runtime work must shape a separate compile proof before linking or executing
these sources.

## Core compatibility

The imported TypeScript parser defines language version `14`. The imported TSX
parser defines language version `14`. The existing vendored Tree-sitter core
under `third_party/tree-sitter-core/v0.26.9` declares
`TREE_SITTER_LANGUAGE_VERSION` `15` and minimum compatible version `13`.
Therefore both imported parsers are compatible with the existing core ABI range.
No Tree-sitter core update is included or required by this feature.

## Extension admission state

Extension admission is source-import planning evidence only. This feature does
not implement runtime support for `.ts`, `.mts`, `.cts`, `.tsx`, or any other
TypeScript/TSX extension.

Repository-local proof basis:

- `.ts` is admitted for later TypeScript source/runtime proof by the imported
  `typescript/` grammar, generated parser, generated grammar metadata, node
  types, and scanner wrapper.
- `.mts` is admitted for later TypeScript source/runtime proof as a TypeScript
  module-extension path using the same imported TypeScript grammar sources.
  This does not admit package, workspace, module-resolution, or `tsconfig`
  semantics.
- `.cts` is admitted for later TypeScript source/runtime proof as a TypeScript
  CommonJS-extension path using the same imported TypeScript grammar sources.
  This does not admit package, workspace, module-resolution, or `tsconfig`
  semantics.
- `.tsx` is admitted for later TSX source/runtime proof by the imported `tsx/`
  grammar, generated parser, generated grammar metadata, node types, scanner
  wrapper, and shared scanner `JSX_TEXT` token path.

Future TypeScript query-contract or runtime work should include `.ts`, `.mts`,
`.cts`, and `.tsx` fixture coverage before claiming runtime support. Any future
extension handling remains inspect-path-only and extension-based unless a
separately shaped feature deliberately changes that boundary.

## Explicit deferrals and future sequencing

At the time of this source-import evidence, TypeScript and TSX runtime support
remained unimplemented and the next likely follow-up was TypeScript/TSX offline
build proof, not runtime provider wiring.

This source-import feature explicitly deferred all of the following:

- TypeScript/TSX parser compile/link proof and offline build proof beyond the
  source import evidence recorded here;
- TypeScript/TSX extraction proof;
- TypeScript/TSX symbol query fixtures;
- inspect-only TypeScript/TSX symbol output;
- provider registry changes;
- CLI, report schema, scoring, and cache changes;
- LSP integration;
- custom user query execution;
- `package.json`, workspace, bundler, dependency graph, module resolution,
  `tsconfig` analysis, Node provider identity, and repo-wide scanning behavior;
  and
- true symbol history, authorship, ownership, ranking, risk scoring, telemetry,
  network, upload, and remote enrichment.

Any future TypeScript/TSX extraction, query, inspect-output, LSP, custom-query,
Node, package/workspace, bundler, dependency-graph, module-resolution,
`tsconfig`, or repo-wide scanning behavior needs a separately shaped feature and
validation contract. This import does not make those behaviors available.

## Source-size measurements

Commands used repo-relative paths only:

```sh
find third_party/tree-sitter-typescript/v0.23.2 -type f -printf '%s %p\n' | sort -nr
find third_party/tree-sitter-typescript/v0.23.2 -type f -print0 | xargs -0 wc -c
du -sk --exclude=.git --exclude=.zig-cache --exclude=zig-out .
```

Observed source-size evidence:

- Imported source bytes, excluding provenance and manifest files: `18360892`
  bytes.
- Bytes under `third_party/tree-sitter-typescript/v0.23.2`, including manifest
  and provenance files: `18371386` bytes.
- TypeScript parser size: `8745894` bytes.
- TypeScript scanner wrapper size: `573` bytes.
- TSX parser size: `8769870` bytes.
- TSX scanner wrapper size: `538` bytes.
- Shared scanner size: `10097` bytes.
- Largest upstream imported source/license files, excluding provenance and
  manifest files:
  1. `third_party/tree-sitter-typescript/v0.23.2/tsx/src/parser.c` - `8769870`
     bytes.
  2. `third_party/tree-sitter-typescript/v0.23.2/typescript/src/parser.c` -
     `8745894` bytes.
  3. `third_party/tree-sitter-typescript/v0.23.2/tsx/src/grammar.json` -
     `281578` bytes.
  4. `third_party/tree-sitter-typescript/v0.23.2/typescript/src/grammar.json` -
     `281518` bytes.
  5. `third_party/tree-sitter-typescript/v0.23.2/tsx/src/node-types.json` -
     `113345` bytes.
  6. `third_party/tree-sitter-typescript/v0.23.2/typescript/src/node-types.json`
     - `108583` bytes.
  7. `third_party/tree-sitter-typescript/v0.23.2/common/define-grammar.js` -
     `33533` bytes.
  8. `third_party/tree-sitter-typescript/v0.23.2/common/scanner.h` - `10097`
     bytes.
  9. `third_party/tree-sitter-typescript/v0.23.2/tsx/src/tree_sitter/parser.h`
     - `7039` bytes.
  10. `third_party/tree-sitter-typescript/v0.23.2/typescript/src/tree_sitter/parser.h`
      - `7039` bytes.
- Repo-owned evidence files under the same directory are excluded from the list
  above but included in the full directory total: `PROVENANCE.md` is `7209`
  bytes and `IMPORTED_FILES.tsv` is `3285` bytes.
- Repository working-tree size excluding `.git`, `.zig-cache`, and `zig-out`:
  - Before import: `32232` KiB.
  - After import and evidence files: `50228` KiB.

Planner-review note: the source import is intentionally narrow, but the selected
TypeScript and TSX generated parser files are large and the total imported
source is above earlier single-language imports. This feature changes no normal
build graph or runtime provider behavior; future TypeScript/TSX offline build
proof should review source-install and compile-time impact before adding these
sources to any compile path.

## Validation and build-impact evidence

Validation command shapes:

```sh
git diff --check
time -p zig build validate
git status --porcelain --untracked-files=all -- src tests fixtures build.zig build.zig.zon .github tools/validate.sh
python3 - <<'PY'
# provenance/license/BOM and generated parser/scanner checks, using only
# repo-local files and manifest digests
PY
# no-provider table, JSON, Markdown, and inspect output stability check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

Observed validation evidence:

| Command summary | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `time -p zig build validate` before import | `0` | Default validation passed in `real 21.10`, `user 18.48`, `sys 7.51`. |
| `git diff --check` | `0` | No whitespace errors were reported. |
| `time -p zig build validate` after import | `0` | Default validation passed in `real 38.36`, `user 31.70`, `sys 9.93`. |
| Changed-path scan for source-import-only scope | `0` | Protected runtime, build, test, fixture, provider, CLI, report, scoring, cache, package, and CI paths had no changes. |
| Provenance/license/BOM scan | `0` | Manifest paths, byte counts, SHA-256 digests, license notice, and imported file count matched the committed TypeScript/TSX source-import evidence. |
| Generated parser/scanner provenance check | `0` | Parser language versions, external scanner requirements, scanner helper narrowness, core compatibility, and TSX scanner token evidence matched the committed manifest and provenance notes. |
| Extension admission or deferral check | `0` | `.ts`, `.mts`, `.cts`, and `.tsx` are recorded only as future source/runtime proof candidates; no runtime support is implied. |
| No-provider output stability check | `0` | Basic JSON and Markdown matched committed fixtures; table output was deterministic; inspect JSON, Markdown, and table outputs matched committed fixtures. |
| `zig build validate -Dcloseout=true ... -Dsmoke-label=sibling-local-repo` | `0` | Close-out validation passed in `real 24.19`, `user 21.47`, `sys 8.29` with `this-repo` and `sibling-local-repo` smoke labels only. |

Validation reported local-only behavior: no fetch, pull, push, upload,
telemetry, remote enrichment, CI service, default provider runtime, cache
requirement, packaging, or release automation. Existing opt-in Tree-sitter Zig,
Go, Python, or JavaScript symbol proof remains local current-file enrichment and
is not expanded by this feature.

## No-provider byte-stability evidence

Representative table, JSON, Markdown, and inspect outputs were captured after
the TypeScript/TSX source import using existing fixture commands. Each output
matched the committed no-provider fixture baseline exactly:

- `fixtures/expected/basic.json`
- `fixtures/expected/basic.md`
- deterministic repeated table output for `fixtures/basic`
- `fixtures/expected/basic-inspect.json`
- `fixtures/expected/basic-inspect.md`
- `fixtures/expected/basic-inspect.txt`

The source import does not add provider registry entries, requested TypeScript
or TSX parsing, report fields, scoring inputs, cache inputs, CLI flags, package
analysis, Node identity, LSP behavior, network calls, telemetry, upload, or
remote enrichment. No-provider output remains byte-stable.
