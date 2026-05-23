# Provenance for tree-sitter-zig

## Component

- Component name: tree-sitter-zig
- Vendored path: `third_party/tree-sitter-zig/v1.1.2`
- Import decision state: `ready`
- Import feature: Feature 0025
- Import date: 2026-05-23

## Upstream identity

- Upstream repository: `https://github.com/tree-sitter-grammars/tree-sitter-zig`
- Selected tag: `v1.1.2`
- Selected commit: `b670c8df85a1568f498aa5c8cae42f51a90473c0`
- Source identity: pinned Git checkout of the selected commit.
- Source archive review checksum: release asset `tree-sitter-zig.tar.xz`, observed during import as `114816` bytes with SHA-256 `80cbc2cae284b539930f9958003f8f28d4c056ddc3bed912f61bf64e7d6fd680`.
- Secondary archive review checksum: GitHub tag archive `v1.1.2.tar.gz`, observed during import as `264645` bytes with SHA-256 `612d67059faa90ec7691e5d786d70d8f7c2c8b15b83de901b9b801122ad4cf25`. The immutable commit and release asset above are the import evidence used for this feature.
- Imported file list: `third_party/tree-sitter-zig/v1.1.2/IMPORTED_FILES.tsv`
- Excluded file classes: Node, Go, Rust, Python, Swift, CMake, Make, package-manager wrappers, lockfiles, prebuild and package metadata, tests, CI files, release automation, and repository administration files. These are excluded because this feature imports grammar and query source for a future provider proof and stops before build, runtime, provider, package, or release behavior.

## Generated-source provenance

- Generated files imported: `third_party/tree-sitter-zig/v1.1.2/src/parser.c`
- Grammar/source inputs: `grammar.js`, `src/grammar.json`, `src/node-types.json`, and query files listed in `third_party/tree-sitter-zig/v1.1.2/IMPORTED_FILES.tsv`.
- Generator identity: not run locally in this feature. Prior readiness evidence recorded upstream package metadata declaring `tree-sitter-cli` development dependency `^0.24.5`; this import deliberately does not use a global generator or package-manager fetch.
- Reproduction or verification evidence: accepted as a pinned upstream generated artefact because the selected Git commit and the `tree-sitter-zig.tar.xz` release asset contain identical `src/parser.c` content, Git blob `cb09604e5dac45c2bd599e3bdc509411ea6ed2a1`, with byte size `5843608`.
- Known limitations: parser generation was not reproduced locally. Future runtime work must either keep this pinned artefact basis or shape a separate local reproduction proof before changing parser sources.

## License and notice

- Upstream license: MIT.
- License file copied to: `third_party/tree-sitter-zig/v1.1.2/LICENSE`
- Notice file copied to: `third_party/tree-sitter-zig/v1.1.2/LICENSE`
- Notice obligations reviewed by: Feature 0025 execution review.
- Changes from upstream license or notice text: none.

## Measurement

- Imported source byte size, excluding this provenance file and the manifest: `6091875` bytes.
- Largest imported source file: `third_party/tree-sitter-zig/v1.1.2/src/parser.c` at `5843608` bytes.
- Build-time delta: recorded in `docs/tree-sitter-source-import-evidence.md`.
- No-provider output proof: recorded in `docs/tree-sitter-source-import-evidence.md`.
- Offline validation proof: recorded in `docs/tree-sitter-source-import-evidence.md`.

## Update policy

- Update owner role: implementer for a separately dispatched update feature.
- Required review before update: provenance, license, generated-source status, source-size, build-impact, no-provider stability, and protected runtime surfaces.
- Floating branches or remote build inputs allowed: no.
