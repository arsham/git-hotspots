# Provenance for tree-sitter-rust

## Component

- Component name: tree-sitter-rust
- Vendored path: `third_party/tree-sitter-rust/v0.24.2`
- Import decision state: `ready`
- Import feature: Feature 0071
- Import date: 2026-05-26

## Upstream identity

- Upstream repository: `https://github.com/tree-sitter/tree-sitter-rust`
- Selected tag: `v0.24.2`
- Selected tag object: not applicable; `v0.24.2` is a lightweight tag that
  resolves directly to the selected commit.
- Selected commit: `77a3747266f4d621d0757825e6b11edcbf991ca5`
- Source identity: pinned Git checkout of the selected commit.
- Source archive SHA-256: not used; this import uses a pinned checkout basis and
  per-file manifest evidence instead of archive identity.
- Import note: `grammar.js` redacts upstream contact comment lines to satisfy
  the repository privacy constraint; the grammar body and MIT license notice are
  otherwise unchanged.
- Imported file list:
  `third_party/tree-sitter-rust/v0.24.2/IMPORTED_FILES.tsv`
- Excluded file classes: binding metadata for C package, Go, Node, Python,
  Rust, and Swift ecosystems; package-manager manifests and lockfiles; CMake,
  Make, build, release, CI, editor, playground, benchmark, example, test,
  corpus, README, query, grammar metadata with binding, query, and contact
  metadata, Cargo or crate graph artefacts, wasm or prebuilt artefacts, and
  repository administration files. These are excluded because this feature
  imports only reviewable grammar and generated parser/scanner source, and stops
  before Rust build, runtime, provider, query, fixture, package, or release
  behavior.

## Generated-source provenance

- Generated files imported: `third_party/tree-sitter-rust/v0.24.2/src/parser.c`.
- Scanner files imported: `third_party/tree-sitter-rust/v0.24.2/src/scanner.c`.
- Scanner requirement: the generated parser declares `EXTERNAL_TOKEN_COUNT 11`
  and references `tree_sitter_rust_external_scanner_*` entry points, so the
  scanner source is required for any future parser compile proof.
- Scanner helper headers: `src/scanner.c` includes `tree_sitter/alloc.h` and
  `tree_sitter/parser.h`. Those two local helper headers are imported because
  they are required by the selected scanner and parser source. No other helper
  headers are imported.
- Grammar/source inputs: `grammar.js`, `src/grammar.json`, and
  `src/node-types.json` listed in
  `third_party/tree-sitter-rust/v0.24.2/IMPORTED_FILES.tsv`. The vendored
  `grammar.js` copy redacts only upstream contact comment lines; the selected
  upstream blob remains recorded in the manifest.
- Generator identity: not run locally in this feature. Upstream package
  metadata at the selected commit declares `tree-sitter-cli` development
  dependency `^0.26.7`; this import deliberately does not use a global generator
  or package-manager fetch.
- Reproduction or verification evidence: accepted as pinned upstream generated
  artefacts because `src/parser.c` and `src/scanner.c` are copied from the
  selected Git commit, with Git blobs recorded in the manifest. Parser
  generation and scanner compilation are not reproduced locally in this source
  import feature.
- Known limitations: parser generation and Rust parser compilation were not
  reproduced locally. Future Rust runtime work must either keep this pinned
  artefact basis or shape a separate local reproduction and compile proof before
  changing parser or scanner sources.

## Tree-sitter core compatibility

- Rust parser language version: `15`, from `#define LANGUAGE_VERSION 15` in
  `src/parser.c`.
- Existing vendored core range: `13..15`, from
  `third_party/tree-sitter-core/v0.26.9/lib/include/tree_sitter/api.h`.
- Compatibility decision: compatible with the existing vendored Tree-sitter core
  ABI range; no Tree-sitter core update is required or included.

## License and notice

- Upstream license: MIT.
- License file copied to: `third_party/tree-sitter-rust/v0.24.2/LICENSE`.
- Notice file copied to: `third_party/tree-sitter-rust/v0.24.2/LICENSE`.
- Notice obligations reviewed by: Feature 0071 execution review.
- Changes from upstream license or notice text: none.
- Other source redactions: upstream contact comment lines are removed from
  `grammar.js`; no license or grammar-body text is changed.

## Measurement

- Imported source byte size, excluding this provenance file and the manifest:
  `6889901` bytes.
- Parser size: `6505510` bytes.
- Scanner size: `12588` bytes.
- Largest imported source file:
  `third_party/tree-sitter-rust/v0.24.2/src/parser.c` at `6505510` bytes.
- Build-time delta: recorded in
  `docs/tree-sitter-rust-source-import.md`.
- No-provider output proof: recorded in
  `docs/tree-sitter-rust-source-import.md`.
- Offline validation proof: recorded in
  `docs/tree-sitter-rust-source-import.md`.

## Update policy

- Update owner role: implementer for a separately dispatched update feature.
- Required review before update: provenance, license, generated-source status,
  source-size, build-impact, no-provider stability, and protected runtime
  surfaces.
- Floating branches or remote build inputs allowed: no.
