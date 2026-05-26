# Tree-sitter Rust source import evidence

This is the Feature 0071 execution evidence for a non-runtime Rust grammar
source import. It records public upstream source identity, a narrow bill of
materials, license and notice handling, generated parser and scanner
provenance, core compatibility, `.rs` path admission evidence, source-size
measurements, offline validation, and no-provider byte stability.

This feature adds no Rust build proof, Rust runtime provider, query contract,
provider registry entry, CLI flag, report schema field, scoring change, cache
change, CI/release/package change, network runtime, telemetry, upload, remote
enrichment, Cargo analysis, crate graph analysis, LSP integration, or
background analysis.

## Imported source identity

- tree-sitter-rust is imported under
  `third_party/tree-sitter-rust/v0.24.2` from public upstream tag `v0.24.2`, a
  lightweight tag resolving directly to commit
  `77a3747266f4d621d0757825e6b11edcbf991ca5`.
- Source identity is a pinned Git checkout of the selected commit.
- Imported file BOM and any copy notes are recorded in
  `third_party/tree-sitter-rust/v0.24.2/IMPORTED_FILES.tsv`.
- Per-component provenance is recorded in
  `third_party/tree-sitter-rust/v0.24.2/PROVENANCE.md`.
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
Make, build, release, CI, editor, playground, benchmark, example, test,
corpus, README, query, grammar metadata with binding, query, and contact
metadata, Cargo or crate graph artefacts, wasm or prebuilt artefacts, and
repository administration files.

The upstream `tree-sitter.json` file is not imported in this feature because it
contains binding references, query references, and contact metadata that are out
of scope for this source-import proof. The selected upstream metadata was
inspected only to confirm the public candidate's `.rs` file-type claim. Rust
query support remains explicitly deferred until a separate query-contract
feature.

The vendored `grammar.js` file redacts only upstream contact comment lines to
satisfy the repository privacy constraint. Its grammar body is otherwise kept
from the selected upstream revision, and the original upstream Git blob remains
recorded in the manifest.

## Generated parser and scanner basis

`third_party/tree-sitter-rust/v0.24.2/src/parser.c` is accepted as a pinned
upstream generated artefact. It is copied byte-for-byte from the selected Git
commit, with Git blob `266a09eaf8d9bf7ed6813635a852776fdf4a03e7`, SHA-256
`9602518f9e57919910bf0e777e52f6bfc9325d4c182e998bdb4efd5682b76e4a`, and byte
size `6505510`.

Parser generation was not run locally. Upstream package metadata at the
selected commit declares `tree-sitter-cli` development dependency `^0.26.7`;
this import does not use a global generator, package-manager fetch, or build
input from outside the repository.

`third_party/tree-sitter-rust/v0.24.2/src/scanner.c` is accepted as a pinned
upstream scanner artefact. It is copied byte-for-byte from the selected Git
commit, with Git blob `b36fc2092e1f89543373f2b60afa77468ec4d5d5`, SHA-256
`9609a2f92dbb7c32bc056fd8fb94e5478428f04496696aa08b048a9b66caf283`, and byte
size `12588`.

The scanner source is required by the selected generated parser: `parser.c`
declares external scanner entry points and `EXTERNAL_TOKEN_COUNT 11`. The
scanner's local helper chain is included narrowly: `scanner.c` needs
`tree_sitter/alloc.h` and `tree_sitter/parser.h`. No other helper headers are
imported.

Rust parser compilation was not run locally. Future Rust runtime work must
shape a separate compile proof before linking or executing these sources.

## Core compatibility

The imported Rust parser defines language version `15`. The existing vendored
Tree-sitter core under `third_party/tree-sitter-core/v0.26.9` declares
`TREE_SITTER_LANGUAGE_VERSION` `15` and minimum compatible version `13`.
Therefore the imported Rust parser is compatible with the existing core ABI
range. No Tree-sitter core update is included or required by this feature.

## Rust path admission evidence

The selected upstream `tree-sitter.json` declares grammar name `rust` and file
type `rs`. That upstream metadata supports the previously admitted narrow path
rule: future Rust provider work must remain inspect-path-only and
extension-based, and a requested inspect path ending in `.rs` may be considered
a Rust candidate only after a separate Rust runtime feature exists.

This source import does not implement that path rule. It does not add Cargo
parsing, workspace discovery, crate graph analysis, dependency graph inference,
macro expansion, type checking, module resolution, LSP integration, repo-wide
scanning, provider registry wiring, CLI behavior, or report schema behavior.
Unsupported or ambiguous future Rust paths should fail closed with a visible
provider caveat while preserving file-level Git evidence.

## Source-size measurements

Commands used repo-relative paths only:

```sh
find third_party/tree-sitter-rust/v0.24.2 -type f -printf '%s %p\n' | sort -nr
find third_party/tree-sitter-rust/v0.24.2 -type f -print0 | xargs -0 wc -c
du -sk --exclude=.git --exclude=.zig-cache --exclude=zig-out .
```

Observed source-size evidence:

- Imported source bytes, excluding provenance and manifest files:
  `6889901` bytes.
- Bytes under `third_party/tree-sitter-rust/v0.24.2`, including manifest and
  provenance files: `6896687` bytes.
- Rust parser size: `6505510` bytes.
- Rust scanner size: `12588` bytes.
- Largest upstream imported source/license files, excluding provenance and
  manifest files (eight files total):
  1. `third_party/tree-sitter-rust/v0.24.2/src/parser.c` - `6505510` bytes.
  2. `third_party/tree-sitter-rust/v0.24.2/src/grammar.json` - `224430` bytes.
  3. `third_party/tree-sitter-rust/v0.24.2/src/node-types.json` - `99023`
     bytes.
  4. `third_party/tree-sitter-rust/v0.24.2/grammar.js` - `38661` bytes.
  5. `third_party/tree-sitter-rust/v0.24.2/src/scanner.c` - `12588` bytes.
  6. `third_party/tree-sitter-rust/v0.24.2/src/tree_sitter/parser.h` - `7624`
     bytes.
  7. `third_party/tree-sitter-rust/v0.24.2/LICENSE` - `1080` bytes.
  8. `third_party/tree-sitter-rust/v0.24.2/src/tree_sitter/alloc.h` - `985`
     bytes.
- Repo-owned evidence files under the same directory are excluded from the list
  above but included in the full directory total: `PROVENANCE.md` is `5129`
  bytes and `IMPORTED_FILES.tsv` is `1657` bytes.
- Repository working-tree size excluding `.git`, `.zig-cache`, and `zig-out`:
  - Before import: `59100` KiB.
  - After import and evidence files: `65876` KiB.

Source-size review note: the generated Rust parser is large, but the import is
limited to source/provenance files and changes no normal build graph, compile
path, runtime provider behavior, package behavior, or release behavior. Future
Rust offline build proof should review source-install and compile-time impact
before adding these sources to any compile path.

## Validation and build-impact evidence

Validation command shapes:

```sh
time -p zig build validate
git diff --check
git status --short -- src tests fixtures build.zig build.zig.zon .github tools/validate.sh
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
| `time -p zig build validate` before import | `0` | Default validation passed in `real 29.85`, `user 28.22`, `sys 10.01`. |
| `time -p zig build validate` after import | `0` | Default validation passed in `real 29.71`, `user 27.82`, `sys 9.83`. |
| `git diff --check` | `0` | No whitespace errors were reported. |
| Changed-path scan for source-import-only scope | `0` | Protected runtime, build, test, fixture, provider, CLI, report, scoring, cache, package, and CI paths had no changes. |
| Provenance/license/BOM scan | `0` | Manifest paths, byte counts, SHA-256 digests, license notice, parser language version, scanner requirement, and imported file count matched the committed Rust source-import evidence. |
| No-provider output stability check | `0` | Basic table, JSON, Markdown, and inspect JSON outputs matched their before-import captures byte-for-byte. |
| `zig build validate -Dcloseout=true ... -Dsmoke-label=sibling-local-repo` | `0` | Close-out validation passed with `this-repo` and `sibling-local-repo` smoke labels only. |

The close-out validation summary reported `PASS` for every rung, including real
repo smoke `this-repo` and real repo smoke `sibling-local-repo`. Its emitted
privacy statement said summaries use labels and bounded counts only, with raw
reports and absolute private paths omitted.

Validation reported local-only behavior: no fetch, pull, push, upload,
telemetry, remote enrichment, CI service, default provider runtime, cache
requirement, packaging, or release automation. Existing opt-in Tree-sitter Zig,
Go, Python, JavaScript, Lua, TypeScript, or TSX symbol proof remains local
current-file enrichment and is not expanded by this feature.

## No-provider byte-stability evidence

Representative table, JSON, Markdown, and inspect outputs were captured before
and after the Rust source import using existing fixture commands. Each
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

## Feature 0071 evidence set

- Source identity: public upstream tag `v0.24.2`, lightweight tag commit
  `77a3747266f4d621d0757825e6b11edcbf991ca5`.
- BOM: eight imported source, header, or license files, plus repo-owned manifest
  and provenance files. The `grammar.js` copy removes only upstream contact
  comment lines under the explicit privacy constraint.
- License and notice: upstream MIT license copied unchanged to the vendored
  component path and repo notice updated.
- Generated parser provenance: Rust `src/parser.c` accepted as a pinned
  upstream generated artefact from the selected commit; no local generator or
  package manager is used.
- Scanner provenance: `src/scanner.c` and required local helper headers are
  imported because the selected generated parser declares external scanner
  entry points.
- Core compatibility: Rust parser language version `15` fits the existing core
  compatible range `13..15`.
- `.rs` path evidence: selected upstream metadata declares file-type `rs`, but
  runtime path handling remains deferred to a separate feature.
- Validation: default validation, source-import gate checks, whitespace checks,
  no-provider output comparison, protected-surface scan, and close-out smoke all
  passed.
- Boundary proof: no Rust build/runtime/provider/query/CLI/report/schema/
  scoring/cache/CI/release/package behavior is added.

This document is source-import evidence only. It is not evidence that Rust
runtime support exists.
