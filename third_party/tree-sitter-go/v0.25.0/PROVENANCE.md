# Provenance for tree-sitter-go

## Component

- Component name: tree-sitter-go
- Vendored path: `third_party/tree-sitter-go/v0.25.0`
- Import decision state: `ready`
- Import feature: Feature 0036
- Import date: 2026-05-24

## Upstream identity

- Upstream repository: `https://github.com/tree-sitter/tree-sitter-go`
- Selected tag: `v0.25.0`
- Selected tag object: `6048bfc6e5238eaf062c2221bd934489c39fbb61`
- Selected commit: `1547678a9da59885853f5f5cc8a99cc203fa2e2c`
- Source identity: pinned Git checkout of the selected commit.
- Source archive SHA-256: not used; this import uses a pinned checkout basis and
  per-file manifest evidence instead of archive identity.
- Import note: `grammar.js` redacts upstream author comment lines to satisfy the
  repository privacy constraint; the grammar body and MIT license notice are
  otherwise unchanged.
- Imported file list: `third_party/tree-sitter-go/v0.25.0/IMPORTED_FILES.tsv`
- Excluded file classes: bindings for C package metadata, Go, Node, Rust,
  Python, and Swift ecosystems; package-manager manifests and lockfiles;
  CMake, Make, build, release, CI, editor, funding, benchmark, example, test,
  corpus, README, query, and repository administration files. These are
  excluded because this feature imports only reviewable grammar and generated
  parser source, and stops before Go build, runtime, provider, query, fixture,
  package, or release behavior.

## Generated-source provenance

- Generated files imported: `third_party/tree-sitter-go/v0.25.0/src/parser.c`.
- Scanner files imported: none; the selected upstream revision has no
  `src/scanner.c` or `src/scanner.cc`, and the generated parser does not include
  an external scanner source.
- Grammar/source inputs: `grammar.js`, `src/grammar.json`, and
  `src/node-types.json` listed in
  `third_party/tree-sitter-go/v0.25.0/IMPORTED_FILES.tsv`. The vendored
  `grammar.js` copy redacts only upstream author comment lines; the selected
  upstream blob remains recorded in the manifest.
- Generator identity: not run locally in this feature. Upstream package metadata
  at the selected commit declares `tree-sitter-cli` development dependency
  `^0.25.8`; this import deliberately does not use a global generator or
  package-manager fetch.
- Reproduction or verification evidence: accepted as a pinned upstream generated
  artefact because `src/parser.c` is copied byte-for-byte from the selected Git
  commit, with Git blob `e3567a9519739c92ae776060dc8d3b4968bc465f`, SHA-256
  `3dbf6ed1238b5dfcf2be4d2f2d4cb27a14d34f34d7784eccccbfd532fd4a6d85`, and
  byte size `1572685`.
- Known limitations: parser generation was not reproduced locally. Future Go
  runtime work must either keep this pinned artefact basis or shape a separate
  local reproduction proof before changing parser sources.

## Tree-sitter core compatibility

- Go parser language version: `15`, from `#define LANGUAGE_VERSION 15` in
  `src/parser.c`.
- Existing vendored core range: `13..15`, from
  `third_party/tree-sitter-core/v0.26.9/lib/include/tree_sitter/api.h`.
- Compatibility decision: compatible with the existing vendored Tree-sitter core
  ABI range; no Tree-sitter core update is required or included.

## License and notice

- Upstream license: MIT.
- License file copied to: `third_party/tree-sitter-go/v0.25.0/LICENSE`.
- Notice file copied to: `third_party/tree-sitter-go/v0.25.0/LICENSE`.
- Notice obligations reviewed by: Feature 0036 execution review.
- Changes from upstream license or notice text: none.
- Other source redactions: upstream author comment lines are removed from
  `grammar.js`; no license or grammar-body text is changed.

## Measurement

- Imported source byte size, excluding this provenance file and the manifest:
  `1855688` bytes.
- Parser size: `1572685` bytes.
- Scanner size: not applicable; no scanner source is imported.
- Largest imported source file:
  `third_party/tree-sitter-go/v0.25.0/src/parser.c` at `1572685` bytes.
- Build-time delta: recorded in
  `docs/tree-sitter-go-source-import-evidence.md`.
- No-provider output proof: recorded in
  `docs/tree-sitter-go-source-import-evidence.md`.
- Offline validation proof: recorded in
  `docs/tree-sitter-go-source-import-evidence.md`.

## Update policy

- Update owner role: implementer for a separately dispatched update feature.
- Required review before update: provenance, license, generated-source status,
  source-size, build-impact, no-provider stability, and protected runtime
  surfaces.
- Floating branches or remote build inputs allowed: no.
