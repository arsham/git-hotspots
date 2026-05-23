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

## Generated-source note

`third_party/tree-sitter-zig/v1.1.2/src/parser.c` is accepted in this feature as
a pinned upstream generated artefact. The selected Git commit and release asset
contain identical parser content, Git blob
`cb09604e5dac45c2bd599e3bdc509411ea6ed2a1`, with byte size `5843608`. No local
parser generator, package-manager fetch, build path, link path, parser runtime,
or provider behavior is added by this import.
