# Provenance for tree-sitter-python

## Component

- Component name: tree-sitter-python
- Vendored path: `third_party/tree-sitter-python/v0.25.0`
- Import decision state: `ready`
- Import feature: Feature 0042
- Import date: 2026-05-24

## Upstream identity

- Upstream repository: `https://github.com/tree-sitter/tree-sitter-python`
- Selected tag: `v0.25.0`
- Selected tag object: `d326e4cad262cf681656e130960e49dfc04c03ea`
- Selected commit: `293fdc02038ee2bf0e2e206711b69c90ac0d413f`
- Source identity: pinned Git checkout of the selected commit.
- Source archive SHA-256: not used; this import uses a pinned checkout basis and
  per-file manifest evidence instead of archive identity.
- Import note: `grammar.js` redacts the upstream author comment line to satisfy
  the repository privacy constraint; the grammar body and MIT license notice are
  otherwise unchanged.
- Imported file list:
  `third_party/tree-sitter-python/v0.25.0/IMPORTED_FILES.tsv`
- Excluded file classes: binding metadata for C package, Go, Node, Python,
  Rust, and Swift ecosystems; package-manager manifests and lockfiles; CMake,
  Make, build, release, CI, editor, funding, example, test, corpus, README,
  query, grammar metadata with binding references, and repository
  administration files. These are excluded because this feature imports only
  reviewable grammar and generated parser/scanner source, and stops before
  Python build, runtime, provider, query, fixture, package, or release behavior.

## Generated-source provenance

- Generated files imported: `third_party/tree-sitter-python/v0.25.0/src/parser.c`.
- Scanner files imported: `third_party/tree-sitter-python/v0.25.0/src/scanner.c`.
- Scanner requirement: the generated parser declares `EXTERNAL_TOKEN_COUNT 12`
  and references `tree_sitter_python_external_scanner_*` entry points, so the
  scanner source is required for any future parser compile proof.
- Scanner helper headers: `src/scanner.c` includes `tree_sitter/array.h` and
  `tree_sitter/parser.h`; `array.h` includes `tree_sitter/alloc.h`. Those three
  local helper headers are imported because they are required by the selected
  scanner and parser source. No other helper headers are imported.
- Grammar/source inputs: `grammar.js`, `src/grammar.json`, and
  `src/node-types.json` listed in
  `third_party/tree-sitter-python/v0.25.0/IMPORTED_FILES.tsv`. The vendored
  `grammar.js` copy redacts only the upstream author comment line; the selected
  upstream blob remains recorded in the manifest.
- Generator identity: not run locally in this feature. Upstream package metadata
  at the selected commit declares `tree-sitter-cli` development dependency
  `^0.25.9`; this import deliberately does not use a global generator or
  package-manager fetch.
- Reproduction or verification evidence: accepted as pinned upstream generated
  artefacts because `src/parser.c` and `src/scanner.c` are copied byte-for-byte
  from the selected Git commit, with Git blobs recorded in the manifest. Parser
  generation and scanner compilation are not reproduced locally in this source
  import feature.
- Known limitations: parser generation and Python parser compilation were not
  reproduced locally. Future Python runtime work must either keep this pinned
  artefact basis or shape a separate local reproduction and compile proof before
  changing parser or scanner sources.

## Tree-sitter core compatibility

- Python parser language version: `15`, from `#define LANGUAGE_VERSION 15` in
  `src/parser.c`.
- Existing vendored core range: `13..15`, from
  `third_party/tree-sitter-core/v0.26.9/lib/include/tree_sitter/api.h`.
- Compatibility decision: compatible with the existing vendored Tree-sitter core
  ABI range; no Tree-sitter core update is required or included.

## License and notice

- Upstream license: MIT.
- License file copied to: `third_party/tree-sitter-python/v0.25.0/LICENSE`.
- Notice file copied to: `third_party/tree-sitter-python/v0.25.0/LICENSE`.
- Notice obligations reviewed by: Feature 0042 execution review.
- Changes from upstream license or notice text: none.
- Other source redactions: the upstream author comment line is removed from
  `grammar.js`; no license or grammar-body text is changed.

## Measurement

- Imported source byte size, excluding this provenance file and the manifest:
  `3712005` bytes.
- Parser size: `3439646` bytes.
- Scanner size: `15470` bytes.
- Largest imported source file:
  `third_party/tree-sitter-python/v0.25.0/src/parser.c` at `3439646` bytes.
- Build-time delta: recorded in
  `docs/tree-sitter-python-source-import-evidence.md`.
- No-provider output proof: recorded in
  `docs/tree-sitter-python-source-import-evidence.md`.
- Offline validation proof: recorded in
  `docs/tree-sitter-python-source-import-evidence.md`.

## Update policy

- Update owner role: implementer for a separately dispatched update feature.
- Required review before update: provenance, license, generated-source status,
  source-size, build-impact, no-provider stability, and protected runtime
  surfaces.
- Floating branches or remote build inputs allowed: no.
