# Provenance for tree-sitter-typescript

## Component

- Component name: tree-sitter-typescript
- Vendored path: `third_party/tree-sitter-typescript/v0.23.2`
- Import decision state: `source-import-ready`
- Import feature: Feature 0056
- Import date: 2026-05-25
- Runtime support state: TypeScript and TSX runtime support are not implemented
  by this import.

## Upstream identity

- Upstream repository: `https://github.com/tree-sitter/tree-sitter-typescript`
- Selected tag: `v0.23.2`
- Selected tag object: none; `v0.23.2` is a lightweight tag.
- Selected commit: `f975a621f4e7f532fe322e13c4f79495e0a7b2e7`
- Source identity: pinned Git checkout of the selected commit.
- Source archive SHA-256: not used; this import uses a pinned checkout basis and
  per-file manifest evidence instead of archive identity.
- Import note: all imported files are copied byte-for-byte from the selected
  commit.
- Imported file list:
  `third_party/tree-sitter-typescript/v0.23.2/IMPORTED_FILES.tsv`
- Excluded file classes: binding metadata and wrappers for C package, Go, Node,
  Python, Rust, and Swift ecosystems; package-manager manifests and lockfiles;
  CMake, Make, build, release, CI, editor, benchmark, example, test, corpus,
  README, upstream query, grammar metadata with binding/query/person metadata,
  wasm or prebuilt artefacts, and repository administration files. These are
  excluded because this feature imports only reviewable grammar and generated
  parser/scanner source, and stops before TypeScript or TSX build, runtime,
  provider, query, fixture, package, workspace, module-resolution, tsconfig,
  Node, LSP, CI, release, or report behavior.

## Generated-source provenance

- Generated TypeScript parser imported:
  `third_party/tree-sitter-typescript/v0.23.2/typescript/src/parser.c`.
- Generated TSX parser imported:
  `third_party/tree-sitter-typescript/v0.23.2/tsx/src/parser.c`.
- Scanner files imported:
  `third_party/tree-sitter-typescript/v0.23.2/typescript/src/scanner.c` and
  `third_party/tree-sitter-typescript/v0.23.2/tsx/src/scanner.c`.
- Shared scanner source imported:
  `third_party/tree-sitter-typescript/v0.23.2/common/scanner.h`.
- Scanner requirement: both generated parsers declare `EXTERNAL_TOKEN_COUNT 10`
  and reference dialect-specific external scanner entry points, so the scanner
  wrappers and shared scanner source are required for any future parser compile
  proof.
- Scanner helper headers: the parser sources include `tree_sitter/parser.h`; the
  scanner wrappers include `../../common/scanner.h`, which includes
  `tree_sitter/parser.h` through the grammar-specific include path. The imported
  `typescript/src/tree_sitter/parser.h` and `tsx/src/tree_sitter/parser.h` files
  are therefore the only required Tree-sitter helper headers for this source
  proof. Upstream `alloc.h` and `array.h` are excluded because no imported
  parser or scanner source includes them.
- Grammar/source inputs: `common/define-grammar.js`, `typescript/grammar.js`,
  `typescript/src/grammar.json`, `typescript/src/node-types.json`,
  `tsx/grammar.js`, `tsx/src/grammar.json`, and `tsx/src/node-types.json`, all
  listed in `third_party/tree-sitter-typescript/v0.23.2/IMPORTED_FILES.tsv`.
- Generator identity: not run locally in this feature. Upstream package metadata
  at the selected commit declares `tree-sitter-cli` development dependency
  `^0.24.4`; this import deliberately does not use a global generator or
  package-manager fetch.
- Reproduction or verification evidence: accepted as pinned upstream generated
  artefacts because the generated parsers, scanner wrappers, shared scanner,
  grammar metadata, and grammar inputs are copied byte-for-byte from the
  selected Git commit, with Git blobs recorded in the manifest. Parser
  generation and scanner compilation are not reproduced locally in this source
  import feature.
- Known limitations: parser generation and TypeScript/TSX parser compilation were
  not reproduced locally. Future TypeScript/TSX runtime work must either keep
  this pinned artefact basis or shape a separate local reproduction and compile
  proof before changing parser or scanner sources.

## Tree-sitter core compatibility

- TypeScript parser language version: `14`, from `#define LANGUAGE_VERSION 14`
  in `typescript/src/parser.c`.
- TSX parser language version: `14`, from `#define LANGUAGE_VERSION 14` in
  `tsx/src/parser.c`.
- Existing vendored core range: `13..15`, from
  `third_party/tree-sitter-core/v0.26.9/lib/include/tree_sitter/api.h`.
- Compatibility decision: both imported parsers are compatible with the existing
  vendored Tree-sitter core ABI range; no Tree-sitter core update is required or
  included.

## Extension admission state

Extension admission is a source-import planning fact only. This import does not
implement runtime TypeScript or TSX support for any extension.

- `.ts`: admitted for later TypeScript source/runtime proof using the imported
  TypeScript grammar and generated parser sources.
- `.mts`: admitted for later TypeScript source/runtime proof as a TypeScript
  module-extension path using the same imported TypeScript grammar sources;
  package, workspace, module-resolution, and `tsconfig` semantics remain
  deferred.
- `.cts`: admitted for later TypeScript source/runtime proof as a TypeScript
  CommonJS-extension path using the same imported TypeScript grammar sources;
  package, workspace, module-resolution, and `tsconfig` semantics remain
  deferred.
- `.tsx`: admitted for later TSX source/runtime proof using the imported `tsx/`
  grammar, generated parser, node types, and the shared scanner path containing
  the `JSX_TEXT` token.

Future TypeScript/TSX runtime or query-contract work should include `.ts`,
`.mts`, `.cts`, and `.tsx` fixtures before claiming runtime support.

## License and notice

- Upstream license: MIT.
- License file copied to:
  `third_party/tree-sitter-typescript/v0.23.2/LICENSE`.
- Notice file copied to:
  `third_party/tree-sitter-typescript/v0.23.2/LICENSE`.
- Notice obligations reviewed by: Feature 0056 execution review.
- Changes from upstream license or notice text: none.

## Measurement

- Imported source byte size, excluding this provenance file and the manifest:
  `18360892` bytes.
- TypeScript parser size: `8745894` bytes.
- TypeScript scanner wrapper size: `573` bytes.
- TSX parser size: `8769870` bytes.
- TSX scanner wrapper size: `538` bytes.
- Shared scanner size: `10097` bytes.
- Largest imported source file:
  `third_party/tree-sitter-typescript/v0.23.2/tsx/src/parser.c` at `8769870`
  bytes.
- Build-time delta: recorded in
  `docs/tree-sitter-typescript-source-import-evidence.md`.
- No-provider output proof: recorded in
  `docs/tree-sitter-typescript-source-import-evidence.md`.
- Offline validation proof: recorded in
  `docs/tree-sitter-typescript-source-import-evidence.md`.

## Update policy

- Update owner role: implementer for a separately dispatched update feature.
- Required review before update: provenance, license, generated-source status,
  source-size, build-impact, no-provider stability, extension admission, and
  protected runtime surfaces.
- Floating branches or remote build inputs allowed: no.
