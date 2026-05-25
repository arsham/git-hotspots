# Provenance for tree-sitter-javascript

## Component

- Component name: tree-sitter-javascript
- Vendored path: `third_party/tree-sitter-javascript/v0.25.0`
- Import decision state: `source-import-ready`
- Import feature: Feature 0050
- Import date: 2026-05-25
- Runtime support state: JavaScript runtime support is not implemented by this
  import.

## Upstream identity

- Upstream repository: `https://github.com/tree-sitter/tree-sitter-javascript`
- Selected tag: `v0.25.0`
- Selected tag object: `f76aea6aa47322ea5c208c9c2e67f4a350d554f3`
- Selected commit: `44c892e0be055ac465d5eeddae6d3e194424e7de`
- Source identity: pinned Git checkout of the selected commit.
- Source archive SHA-256: not used; this import uses a pinned checkout basis and
  per-file manifest evidence instead of archive identity.
- Import note: `grammar.js` redacts the upstream author comment lines to satisfy
  the repository privacy constraint; the grammar body and MIT license notice are
  otherwise unchanged.
- Imported file list:
  `third_party/tree-sitter-javascript/v0.25.0/IMPORTED_FILES.tsv`
- Excluded file classes: binding metadata for C package, Go, Node, Python,
  Rust, and Swift ecosystems; package-manager manifests and lockfiles; CMake,
  Make, build, release, CI, editor, funding, benchmark, example, test, corpus,
  README, upstream query, grammar metadata with binding/query/person metadata,
  and repository administration files. These are excluded because this feature
  imports only reviewable grammar and generated parser/scanner source, and stops
  before JavaScript build, runtime, provider, query, fixture, package, or
  release behavior.

## Generated-source provenance

- Generated files imported:
  `third_party/tree-sitter-javascript/v0.25.0/src/parser.c`.
- Scanner files imported:
  `third_party/tree-sitter-javascript/v0.25.0/src/scanner.c`.
- Scanner requirement: the generated parser declares `EXTERNAL_TOKEN_COUNT 8`
  and references `tree_sitter_javascript_external_scanner_*` entry points, so
  the scanner source is required for any future parser compile proof.
- Scanner helper headers: `src/scanner.c` includes only the local
  `tree_sitter/parser.h` helper header plus system headers. The imported
  `src/tree_sitter/parser.h` is therefore the only required scanner helper
  header; no `alloc.h`, `array.h`, or other helper header is imported.
- Grammar/source inputs: `grammar.js`, `src/grammar.json`, and
  `src/node-types.json` listed in
  `third_party/tree-sitter-javascript/v0.25.0/IMPORTED_FILES.tsv`. The vendored
  `grammar.js` copy redacts only the upstream author comment lines; the selected
  upstream blob remains recorded in the manifest.
- Generator identity: not run locally in this feature. Upstream package metadata
  at the selected commit declares `tree-sitter-cli` development dependency
  `^0.25.8`; this import deliberately does not use a global generator or
  package-manager fetch.
- Reproduction or verification evidence: accepted as pinned upstream generated
  artefacts because `src/parser.c` and `src/scanner.c` are copied byte-for-byte
  from the selected Git commit, with Git blobs recorded in the manifest. Parser
  generation and scanner compilation are not reproduced locally in this source
  import feature.
- Known limitations: parser generation and JavaScript parser compilation were
  not reproduced locally. Future JavaScript runtime work must either keep this
  pinned artefact basis or shape a separate local reproduction and compile proof
  before changing parser or scanner sources.

## Tree-sitter core compatibility

- JavaScript parser language version: `15`, from `#define LANGUAGE_VERSION 15`
  in `src/parser.c`.
- Existing vendored core range: `13..15`, from
  `third_party/tree-sitter-core/v0.26.9/lib/include/tree_sitter/api.h`.
- Compatibility decision: compatible with the existing vendored Tree-sitter core
  ABI range; no Tree-sitter core update is required or included.

## JSX admission state

- JSX source-import state: admitted for a later JavaScript runtime feature, not
  implemented at runtime by this source import.
- Repository-local proof basis: the imported `grammar.js` contains JSX grammar
  rules, the imported `src/node-types.json` contains JSX node types, and the
  imported generated/scanner sources define JSX-related tokens including
  `JSX_TEXT`.
- Future fixture expectation: the next JavaScript runtime or query-contract
  feature should include `.jsx` fixtures for components, fragments, and
  expression-heavy JSX before claiming runtime JSX support.
- TypeScript and TSX state: not imported and not claimed.

## License and notice

- Upstream license: MIT.
- License file copied to:
  `third_party/tree-sitter-javascript/v0.25.0/LICENSE`.
- Notice file copied to:
  `third_party/tree-sitter-javascript/v0.25.0/LICENSE`.
- Notice obligations reviewed by: Feature 0050 execution review.
- Changes from upstream license or notice text: none.
- Other source redactions: upstream author comment lines are removed from
  `grammar.js`; no license or grammar-body text is changed.

## Measurement

- Imported source byte size, excluding this provenance file and the manifest:
  `3147086` bytes.
- Parser size: `2855934` bytes.
- Scanner size: `10576` bytes.
- Largest imported source file:
  `third_party/tree-sitter-javascript/v0.25.0/src/parser.c` at `2855934`
  bytes.
- Build-time delta: recorded in
  `docs/tree-sitter-javascript-source-import-evidence.md`.
- No-provider output proof: recorded in
  `docs/tree-sitter-javascript-source-import-evidence.md`.
- Offline validation proof: recorded in
  `docs/tree-sitter-javascript-source-import-evidence.md`.

## Update policy

- Update owner role: implementer for a separately dispatched update feature.
- Required review before update: provenance, license, generated-source status,
  source-size, build-impact, no-provider stability, JSX admission, and protected
  runtime surfaces.
- Floating branches or remote build inputs allowed: no.
