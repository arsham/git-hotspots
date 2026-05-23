# Provenance for Tree-sitter core

## Component

- Component name: Tree-sitter core
- Vendored path: `third_party/tree-sitter-core/v0.26.9`
- Import decision state: `ready`
- Import feature: Feature 0025
- Import date: 2026-05-23

## Upstream identity

- Upstream repository: `https://github.com/tree-sitter/tree-sitter`
- Selected tag: `v0.26.9`
- Selected commit: `7f534862c3ec939c3a6ee147f7600ef5c1bf900f`
- Source identity: pinned Git checkout of the selected commit.
- Source archive review checksum: GitHub tag archive `v0.26.9.tar.gz`, observed during import as `914808` bytes with SHA-256 `8e14780500933f43d86662fcaa1b0ce99ebe9c220f4680bc929dce09a0e0cfc6`. This archive checksum is review evidence only; the immutable commit is the canonical source identity.
- Imported file list: `third_party/tree-sitter-core/v0.26.9/IMPORTED_FILES.tsv`
- Excluded file classes: CLI sources, release binaries, Rust and web bindings, package-manager metadata, package wrappers, tests, CI files, lldb helper scripts, upstream docs outside the selected source support files, and repository administration files. These are excluded because this feature imports auditable local source for a future provider proof and stops before build, runtime, provider, package, or release behavior.

## Generated-source provenance

- Generated files imported: none.
- Grammar/source inputs: not applicable for Tree-sitter core.
- Generator identity: not applicable.
- Reproduction or verification evidence: not applicable.
- Known limitations: selected sources are not compiled or linked by this feature.

## License and notice

- Upstream license: MIT.
- License file copied to: `third_party/tree-sitter-core/v0.26.9/LICENSE`
- Notice file copied to: `third_party/tree-sitter-core/v0.26.9/LICENSE`
- Notice obligations reviewed by: Feature 0025 execution review.
- Changes from upstream license or notice text: none.

## Measurement

- Imported source byte size, excluding this provenance file and the manifest: `770942` bytes.
- Largest imported source file: `third_party/tree-sitter-core/v0.26.9/lib/src/query.c` at `161520` bytes.
- Build-time delta: recorded in `docs/tree-sitter-source-import-evidence.md`.
- No-provider output proof: recorded in `docs/tree-sitter-source-import-evidence.md`.
- Offline validation proof: recorded in `docs/tree-sitter-source-import-evidence.md`.

## Update policy

- Update owner role: implementer for a separately dispatched update feature.
- Required review before update: provenance, license, generated-source status, source-size, build-impact, no-provider stability, and protected runtime surfaces.
- Floating branches or remote build inputs allowed: no.
