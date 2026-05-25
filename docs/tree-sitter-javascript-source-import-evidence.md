# Tree-sitter JavaScript source import evidence

This is the Feature 0050 execution evidence for a non-runtime JavaScript grammar
source import. It records public upstream source identity, a narrow bill of
materials, license and notice handling, generated parser and scanner
provenance, core compatibility, JSX admission state, source-size measurements,
offline validation, and no-provider byte stability.

This feature adds no JavaScript build proof, JavaScript runtime provider, query
contract, provider registry entry, CLI flag, report schema field, scoring
change, cache change, CI/release/package change, network runtime, telemetry,
upload, remote enrichment, or background analysis. It does not add TypeScript or
TSX support.

Next likely follow-up: JavaScript offline build proof. That future feature
should prove local parser compile/link behavior for the pinned source before any
runtime provider or symbol output work is claimed.

## Imported source identity

- tree-sitter-javascript is imported under
  `third_party/tree-sitter-javascript/v0.25.0` from public upstream tag
  `v0.25.0`, tag object `f76aea6aa47322ea5c208c9c2e67f4a350d554f3`, commit
  `44c892e0be055ac465d5eeddae6d3e194424e7de`.
- Source identity is a pinned Git checkout of the selected commit.
- Imported file BOM and any copy notes are recorded in
  `third_party/tree-sitter-javascript/v0.25.0/IMPORTED_FILES.tsv`.
- Per-component provenance is recorded in
  `third_party/tree-sitter-javascript/v0.25.0/PROVENANCE.md`.
- Repo-level notice text is recorded in `THIRD_PARTY_NOTICES.md`.

## Bill of materials

Imported files:

- `LICENSE`
- `grammar.js`
- `src/grammar.json`
- `src/node-types.json`
- `src/parser.c`
- `src/scanner.c`
- `src/tree_sitter/parser.h`

Excluded file classes are binding metadata for C package, Go, Node, Python,
Rust, and Swift ecosystems; package-manager manifests and lockfiles; CMake,
Make, build, release, CI, editor, funding, benchmark, example, test, corpus,
README, upstream query, grammar metadata with binding/query/person metadata, and
repository administration files.

The upstream `tree-sitter.json` file is not imported in this feature because it
contains binding, upstream query, and person-level metadata that is not needed
for this source-import proof. JavaScript and JSX query support remains
explicitly deferred until a separate query-contract feature.

The vendored `grammar.js` file redacts only the upstream author comment lines to
satisfy the repository privacy constraint. Its grammar body is otherwise kept
from the selected upstream revision, and the original upstream Git blob remains
recorded in the manifest.

## Generated parser and scanner basis

`third_party/tree-sitter-javascript/v0.25.0/src/parser.c` is accepted as a
pinned upstream generated artefact. It is copied byte-for-byte from the selected
Git commit, with Git blob `94f8c346cda32ef7b22af38bb7ff8c4128af2b61`, SHA-256
`67209ca7ef6e1a4f74e29e48b5928455f892fe1821a3960fbcd62f4e972f7384`, and byte
size `2855934`.

Parser generation was not run locally. Upstream package metadata at the selected
commit declares `tree-sitter-cli` development dependency `^0.25.8`; this import
does not use a global generator, package-manager fetch, or build input from
outside the repository.

`third_party/tree-sitter-javascript/v0.25.0/src/scanner.c` is accepted as a
pinned upstream scanner artefact. It is copied byte-for-byte from the selected
Git commit, with Git blob `795916dd3203674b50d491b198bd01e70b91031b`, SHA-256
`b3d3f64284d97bf80749c026862427782cf7ecc0b7dc094e6698ab311c9a42c7`, and byte
size `10576`.

The scanner source is required by the selected generated parser: `parser.c`
declares external scanner entry points and `EXTERNAL_TOKEN_COUNT 8`. The
scanner's local helper chain is narrow: `scanner.c` includes only
`tree_sitter/parser.h` from the Tree-sitter helper headers, plus system headers.
No `alloc.h`, `array.h`, or other helper header is imported.

JavaScript parser compilation was not run locally. Future JavaScript runtime
work must shape a separate compile proof before linking or executing these
sources.

## Core compatibility

The imported JavaScript parser defines language version `15`. The existing
vendored Tree-sitter core under `third_party/tree-sitter-core/v0.26.9` declares
`TREE_SITTER_LANGUAGE_VERSION` `15` and minimum compatible version `13`.
Therefore the imported JavaScript parser is compatible with the existing core
ABI range. No Tree-sitter core update is included or required by this feature.

## JSX admission state

JSX is admitted only as source evidence for later JavaScript runtime work. This
feature does not implement `.jsx` runtime support, JavaScript symbol output,
queries, fixtures, provider registration, CLI behavior, report schema behavior,
scoring behavior, or cache behavior.

Repository-local proof basis:

- the imported `grammar.js` contains JSX grammar rules;
- the imported `src/node-types.json` contains JSX node types;
- the imported `src/parser.c` declares external scanner tokens; and
- the imported `src/scanner.c` includes the `JSX_TEXT` token path required by
  that scanner.

Future JavaScript query-contract or runtime work should include `.jsx` fixture
coverage for components, fragments, and expression-heavy JSX before claiming
runtime JSX support. TypeScript and TSX are not imported and remain
unsupported.

## Explicit deferrals and future sequencing

JavaScript runtime support remains unimplemented. The next likely follow-up is
JavaScript offline build proof, not runtime provider wiring.

This source-import feature explicitly defers all of the following:

- JavaScript parser compile/link proof and offline build proof beyond the source
  import evidence recorded here;
- JavaScript extraction proof;
- JavaScript symbol query fixtures;
- inspect-only JavaScript symbol output;
- provider registry changes;
- CLI, report schema, scoring, and cache changes;
- TypeScript and TSX grammar work;
- LSP integration;
- custom user query execution; and
- `package.json`, workspace, bundler, dependency graph, module resolution, Node
  provider identity, and repo-wide scanning behavior.

Any future JavaScript extraction, query, inspect-output, LSP, custom-query,
Node, package/workspace, bundler, dependency-graph, module-resolution, or
repo-wide scanning behavior needs a separately shaped feature and validation
contract. This import does not make those behaviors available.

## Source-size measurements

Commands used repo-relative paths only:

```sh
find third_party/tree-sitter-javascript/v0.25.0 -type f -printf '%s %p\n' | sort -nr
find third_party/tree-sitter-javascript/v0.25.0 -type f -print0 | xargs -0 wc -c
du -sk --exclude=.git --exclude=.zig-cache --exclude=zig-out .
```

Observed source-size evidence:

- Imported source bytes, excluding provenance and manifest files: `3147086`
  bytes.
- Bytes under `third_party/tree-sitter-javascript/v0.25.0`, including manifest
  and provenance files: `3154565` bytes.
- JavaScript parser size: `2855934` bytes.
- JavaScript scanner size: `10576` bytes.
- Largest upstream imported source/license files, excluding provenance and
  manifest files (seven files total):
  1. `third_party/tree-sitter-javascript/v0.25.0/src/parser.c` - `2855934`
     bytes.
  2. `third_party/tree-sitter-javascript/v0.25.0/src/grammar.json` - `174998`
     bytes.
  3. `third_party/tree-sitter-javascript/v0.25.0/src/node-types.json` - `64022`
     bytes.
  4. `third_party/tree-sitter-javascript/v0.25.0/grammar.js` - `32852` bytes.
  5. `third_party/tree-sitter-javascript/v0.25.0/src/scanner.c` - `10576`
     bytes.
  6. `third_party/tree-sitter-javascript/v0.25.0/src/tree_sitter/parser.h` -
     `7624` bytes.
  7. `third_party/tree-sitter-javascript/v0.25.0/LICENSE` - `1080` bytes.
- Repo-owned evidence files under the same directory are excluded from the list
  above but included in the full directory total: `PROVENANCE.md` is `5989`
  bytes and `IMPORTED_FILES.tsv` is `1490` bytes.
- Repository working-tree size excluding `.git`, `.zig-cache`, and `zig-out`:
  - Before import: `25540` KiB.
  - After import and evidence files: `28556` KiB.

No planner-review size threshold is triggered: no single imported JavaScript
file exceeds `6000000` bytes, and the JavaScript source import is below
`8000000` bytes.

## Validation and build-impact evidence

Validation command shapes:

```sh
git diff --check
time -p zig build validate
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build tree-sitter-go-build-proof
zig build tree-sitter-go-symbol-proof
zig build tree-sitter-python-build-proof
zig build tree-sitter-python-symbol-proof
git diff --name-only -- src tests fixtures build.zig build.zig.zon .github tools/validate.sh
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
| `git diff --check` | `0` | No whitespace errors were reported. |
| `time -p zig build validate` before import | `0` | Default validation passed in `real 24.85`, `user 19.52`, `sys 8.25`. |
| `time -p zig build validate` after import | `0` | Default validation passed in `real 29.30`, `user 24.46`, `sys 8.05`. |
| `zig build tree-sitter-build-proof` | `0` | Existing Zig parser build proof passed; no JavaScript parser build proof is added. |
| `zig build tree-sitter-symbol-proof` | `0` | Existing Zig symbol proof passed; no JavaScript symbol output is added. |
| `zig build tree-sitter-go-build-proof` | `0` | Existing Go parser build proof passed; no JavaScript parser build proof is added. |
| `zig build tree-sitter-go-symbol-proof` | `0` | Existing Go symbol proof passed; no JavaScript symbol output is added. |
| `zig build tree-sitter-python-build-proof` | `0` | Existing Python parser build proof passed; no JavaScript parser build proof is added. |
| `zig build tree-sitter-python-symbol-proof` | `0` | Existing Python symbol proof passed; no JavaScript symbol output is added. |
| Changed-path scan for source-import-only scope | `0` | Protected runtime, build, test, fixture, provider, CLI, report, scoring, cache, package, and CI paths had no changes. |
| Provenance/license/BOM scan | `0` | Manifest paths, byte counts, SHA-256 digests, license notice, and imported file count matched the committed JavaScript source-import evidence. |
| Generated parser/scanner provenance check | `0` | Parser language version, external scanner requirement, scanner helper narrowness, and JSX scanner token evidence matched the committed manifest and provenance notes. |
| No-provider output stability check | `0` | Table, JSON, Markdown, and inspect JSON fixture outputs matched the recorded stable digests. |
| `zig build validate -Dcloseout=true ... -Dsmoke-label=sibling-local-repo` | `0` | Close-out validation passed with `this-repo` and `sibling-local-repo` smoke labels only. |

The close-out validation summary reported `PASS` for every rung, including real
repo smoke `this-repo` and real repo smoke `sibling-local-repo`. Its emitted
privacy statement said summaries use labels and bounded counts only, with raw
reports and absolute private paths omitted.

Validation reported local-only behavior: no fetch, pull, push, upload,
telemetry, remote enrichment, CI service, default provider runtime, cache
requirement, packaging, or release automation. Existing opt-in Tree-sitter Zig,
Go, or Python symbol proof remains local current-file enrichment and is not
expanded by this feature.

## No-provider byte-stability evidence

Representative table, JSON, Markdown, and inspect outputs were captured before
and after the JavaScript source import using existing fixture commands. Each
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

## Feature 0050 evidence set

- Source identity: public upstream tag `v0.25.0`, tag object
  `f76aea6aa47322ea5c208c9c2e67f4a350d554f3`, commit
  `44c892e0be055ac465d5eeddae6d3e194424e7de`.
- BOM: seven imported source, header, or license files, plus repo-owned manifest
  and provenance files. The `grammar.js` copy removes only upstream author
  comment lines under the explicit privacy constraint.
- License and notice: upstream MIT license copied unchanged to the vendored
  component path and repo notice updated.
- Generated parser provenance: JavaScript `src/parser.c` accepted as a pinned
  upstream generated artefact from the selected commit; no local generator or
  package manager is used.
- Scanner provenance: `src/scanner.c` and the required local helper header are
  imported because the selected generated parser declares external scanner entry
  points.
- JSX admission: imported repository-local grammar, node-type, parser, and
  scanner sources prove JSX grammar support for future JavaScript runtime work;
  `.jsx` runtime behavior remains unimplemented.
- Core compatibility: JavaScript parser language version `15` fits the existing
  core compatible range `13..15`.
- Validation: default validation, source-import gate checks, whitespace checks,
  existing Zig/Go/Python Tree-sitter build and symbol proof rungs, no-provider
  output comparison, and close-out smoke all passed.
- Boundary proof: no JavaScript build/runtime/provider/query/CLI/report/schema/
  scoring/cache/CI/release/package behavior is added; JavaScript extraction
  proof, JavaScript symbol query fixtures, inspect-only JavaScript symbol
  output, LSP, custom user query execution, package/workspace/bundler/
  dependency graph/module resolution, Node provider identity, repo-wide scanning,
  TypeScript, and TSX remain deferred.
- Privacy proof: committed evidence uses repo-relative paths and public
  upstream component identifiers only; it omits private paths, private repo
  names, raw sibling output, raw parser stderr, author identities, commercial
  strategy, bug-prediction claims, quality scoring, developer ranking, and
  maintainer judgement.
