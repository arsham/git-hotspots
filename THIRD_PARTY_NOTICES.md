# Third-party vendored source notices

This repository vendors selected source files from the components below for
local, offline provider work. The copied sources remain under their upstream
licenses. This notice records public upstream attribution and repo-relative
vendored paths only.

## Tree-sitter core

- Upstream: `https://github.com/tree-sitter/tree-sitter`
- Selected revision: tag `v0.26.9`, commit
  `7f534862c3ec939c3a6ee147f7600ef5c1bf900f`
- Vendored path: `third_party/tree-sitter-core/v0.26.9`
- License: MIT
- Notice: preserve the upstream MIT license text and copyright notice copied in
  `third_party/tree-sitter-core/v0.26.9/LICENSE`.
- Provenance: `third_party/tree-sitter-core/v0.26.9/PROVENANCE.md`

## tree-sitter-zig

- Upstream: `https://github.com/tree-sitter-grammars/tree-sitter-zig`
- Selected revision: tag `v1.1.2`, commit
  `b670c8df85a1568f498aa5c8cae42f51a90473c0`
- Vendored path: `third_party/tree-sitter-zig/v1.1.2`
- License: MIT
- Notice: preserve the upstream MIT license text and copyright notice copied in
  `third_party/tree-sitter-zig/v1.1.2/LICENSE`.
- Provenance: `third_party/tree-sitter-zig/v1.1.2/PROVENANCE.md`

## tree-sitter-go

- Upstream: `https://github.com/tree-sitter/tree-sitter-go`
- Selected revision: tag `v0.25.0`, commit
  `1547678a9da59885853f5f5cc8a99cc203fa2e2c`
- Vendored path: `third_party/tree-sitter-go/v0.25.0`
- License: MIT
- Notice: preserve the upstream MIT license text and copyright notice copied in
  `third_party/tree-sitter-go/v0.25.0/LICENSE`.
- Provenance: `third_party/tree-sitter-go/v0.25.0/PROVENANCE.md`

## tree-sitter-javascript

- Upstream: `https://github.com/tree-sitter/tree-sitter-javascript`
- Selected revision: tag `v0.25.0`, commit
  `44c892e0be055ac465d5eeddae6d3e194424e7de`
- Vendored path: `third_party/tree-sitter-javascript/v0.25.0`
- License: MIT
- Notice: preserve the upstream MIT license text and copyright notice copied in
  `third_party/tree-sitter-javascript/v0.25.0/LICENSE`.
- Provenance: `third_party/tree-sitter-javascript/v0.25.0/PROVENANCE.md`

## tree-sitter-typescript

- Upstream: `https://github.com/tree-sitter/tree-sitter-typescript`
- Selected revision: tag `v0.23.2`, commit
  `f975a621f4e7f532fe322e13c4f79495e0a7b2e7`
- Vendored path: `third_party/tree-sitter-typescript/v0.23.2`
- License: MIT
- Notice: preserve the upstream MIT license text and copyright notice copied in
  `third_party/tree-sitter-typescript/v0.23.2/LICENSE`.
- Provenance: `third_party/tree-sitter-typescript/v0.23.2/PROVENANCE.md`

## tree-sitter-python

- Upstream: `https://github.com/tree-sitter/tree-sitter-python`
- Selected revision: tag `v0.25.0`, commit
  `293fdc02038ee2bf0e2e206711b69c90ac0d413f`
- Vendored path: `third_party/tree-sitter-python/v0.25.0`
- License: MIT
- Notice: preserve the upstream MIT license text and copyright notice copied in
  `third_party/tree-sitter-python/v0.25.0/LICENSE`.
- Provenance: `third_party/tree-sitter-python/v0.25.0/PROVENANCE.md`

## tree-sitter-lua

- Upstream: `https://github.com/tree-sitter-grammars/tree-sitter-lua`
- Selected revision: tag `v0.5.0`, commit
  `10fe0054734eec83049514ea2e718b2a56acd0c9`
- Vendored path: `third_party/tree-sitter-lua/v0.5.0`
- License: MIT
- Notice: preserve the upstream MIT license text and copyright notice copied in
  `third_party/tree-sitter-lua/v0.5.0/LICENSE`.
- Provenance: `third_party/tree-sitter-lua/v0.5.0/PROVENANCE.md`

## Generated-source note

`third_party/tree-sitter-zig/v1.1.2/src/parser.c` is accepted in Feature 0025
as a pinned upstream generated artefact. The selected Git commit and release
asset contain identical parser content, Git blob
`cb09604e5dac45c2bd599e3bdc509411ea6ed2a1`, with byte size `5843608`.

`third_party/tree-sitter-go/v0.25.0/src/parser.c` is accepted in Feature 0036
as a pinned upstream generated artefact copied from the selected Git commit,
Git blob `e3567a9519739c92ae776060dc8d3b4968bc465f`, with byte size
`1572685`. No local parser generator, package-manager fetch, build path, link
path, parser runtime, provider behavior, or Go query support is added by this
import.

`third_party/tree-sitter-python/v0.25.0/src/parser.c` and
`third_party/tree-sitter-python/v0.25.0/src/scanner.c` are accepted in Feature
0042 as pinned upstream generated/scanner artefacts copied from the selected
Git commit, with Git blobs recorded in
`third_party/tree-sitter-python/v0.25.0/IMPORTED_FILES.tsv`. No local parser
generator, package-manager fetch, build path, link path, parser runtime,
provider behavior, or Python query support is added by this import.

`third_party/tree-sitter-javascript/v0.25.0/src/parser.c` and
`third_party/tree-sitter-javascript/v0.25.0/src/scanner.c` are accepted in
Feature 0050 as pinned upstream generated/scanner artefacts copied from the
selected Git commit, with Git blobs recorded in
`third_party/tree-sitter-javascript/v0.25.0/IMPORTED_FILES.tsv`. No local parser
generator, package-manager fetch, build path, link path, parser runtime,
provider behavior, JavaScript query support, TypeScript support, or TSX support
is added by this import.

`third_party/tree-sitter-typescript/v0.23.2/typescript/src/parser.c` and
`third_party/tree-sitter-typescript/v0.23.2/tsx/src/parser.c` are accepted in
Feature 0056 as pinned upstream generated parser artefacts copied from the
selected Git commit. The TypeScript and TSX scanner wrappers plus shared scanner
source are accepted as pinned upstream scanner artefacts copied from the same
commit, with Git blobs recorded in
`third_party/tree-sitter-typescript/v0.23.2/IMPORTED_FILES.tsv`. No local parser
generator, package-manager fetch, build path, link path, parser runtime,
provider behavior, TypeScript or TSX query support, package/workspace/module or
`tsconfig` analysis, LSP support, network behavior, telemetry, or remote
enrichment is added by this import.

`third_party/tree-sitter-lua/v0.5.0/src/parser.c` and
`third_party/tree-sitter-lua/v0.5.0/src/scanner.c` are accepted in Feature 0065
as pinned upstream generated/scanner artefacts copied from the selected Git
commit, with Git blobs recorded in
`third_party/tree-sitter-lua/v0.5.0/IMPORTED_FILES.tsv`. No local parser
generator, package-manager fetch, build path, link path, parser runtime,
provider behavior, Lua query support, LuaRocks support, package-path or module
resolution, LSP support, network behavior, telemetry, or remote enrichment is
added by this import.
