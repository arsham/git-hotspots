# Tree-sitter Rust query contract and fixtures

This is the Rust Tree-sitter query contract for current-only Rust symbol
evidence. It backs the product `--inspect PATH --symbols` runtime lane for
repo-relative `.rs` files, the product query asset, fixture corpus, and proof
targets without changing scoring, cache, report schemas, or runtime defaults.

## Scope and protected surfaces

Changed implementation surfaces are limited to:

- `src/queries/rust-symbols.scm`: the product Rust symbol candidate query.
- `src/tree_sitter_rust.zig`: the inspect-only current-symbol extractor.
- `src/provider_selection.zig`: extension-based runtime provider selection.
- `tests/fixtures/tree_sitter_rust_query/rust-symbols.scm`: the project-owned
  query proof fixture copy.
- `tests/fixtures/tree_sitter_rust_query/*.rs` and
  `tests/fixtures/tree_sitter_rust_query/unsupported.md`: local proof fixtures.
- `tests/tree_sitter_rust_query_proof.zig`: test-only query contract proof.
- `tests/tree_sitter_rust_symbol_proof.zig`: product extractor proof.
- `build.zig`: the explicit Rust build, query, and symbol proof steps.
- `docs/tree-sitter-rust-query-contract.md`: this evidence record.

The contract does not add new CLI flags, report schemas, scoring, cache
behavior, CI/release/package behavior, Cargo or crate/module resolution, macro
expansion, cfg or feature evaluation, type checking, LSP behavior, true symbol
history, network access, telemetry, uploads, remote enrichment, parser
generation, system package use, or custom user query execution.

## Query identity

| Field | Value |
| --- | --- |
| Query version | `rust-symbol-query-v1` |
| Provider proof name | `tree-sitter-rust-query-proof` |
| Grammar input | vendored `third_party/tree-sitter-rust/v0.24.2` |
| Product query asset | `src/queries/rust-symbols.scm` |
| Proof query asset | `tests/fixtures/tree_sitter_rust_query/rust-symbols.scm` |
| Proof commands | `zig build tree-sitter-rust-query-proof`; `zig build tree-sitter-rust-symbol-proof` |

The query is project-owned. It is not an upstream highlight, tags, or user query
import.

## Capture contract

The supported capture names are:

| Capture | Meaning |
| --- | --- |
| `@rust.file` | Rust source-file root candidate. |
| `@rust.function.definition` | Function item candidate after proof-side scope filtering. |
| `@rust.trait.method.definition` | Trait method signature candidate. |
| `@rust.trait.definition` | Trait item candidate. |
| `@rust.impl.block` | Impl block counted for method-context coverage only. |
| `@rust.module.definition` | Inline or external `mod` item candidate. |
| `@rust.struct.definition` | Struct, tuple-struct, or unit-struct item candidate. |
| `@rust.enum.definition` | Enum item candidate. |
| `@rust.enum.variant.definition` | Enum variant candidate. |
| `@rust.const.definition` | Const item candidate. |
| `@rust.static.definition` | Static item candidate. |
| `@rust.macro.definition` | Macro definition counted for caveat proof only. |
| `@rust.macro.invocation` | Macro invocation counted for caveat proof only. |
| `@rust.macro.name` | Macro name paired with macro invocation coverage. |
| `@rust.definition.name` | Identifier paired with symbol-definition candidates. |
| `@rust.attribute` | Attribute counted for caveat proof only. |
| `@rust.comment` | Comment node counted for proof coverage only. |

Future expansion work must stop for planning if it needs new capture names,
custom user queries, Cargo or crate graph analysis, module path resolution,
macro expansion, conditional compilation evaluation, type checking, LSP, true
symbol history, or non-local provider inputs.

## Symbol-kind and range mapping

The product extractor and proof map query candidates into the existing
`provider.CurrentSymbolEvidence` shape:

| Query candidate | Proof mapping |
| --- | --- |
| Source-file root | `SymbolKind.module`; symbol name is the repo-relative `.rs` path. |
| Inline or external module | `SymbolKind.module`; symbol name is the bare syntactic identifier. |
| Freestanding function | `SymbolKind.function`; symbol name is the captured identifier. |
| Impl or trait method | `SymbolKind.method`; method names are bare identifiers. |
| Struct, tuple struct, unit struct, enum, or trait | `SymbolKind.type`; no schema expansion is made. |
| Const or static item | `SymbolKind.other`, because there is no constant/static kind. |
| Enum variant | `SymbolKind.other`; tuple or field payloads are not interpreted. |

Ranges are one-based inclusive line ranges from the symbol definition node. The
file range is the Tree-sitter `source_file` node range. Ordering is
deterministic source order by symbol node start byte, with the file symbol
first. Comments, attributes, impl blocks, macro definitions, and macro
invocations are counted to prove coverage but are not emitted as symbols.

## Supported and caveated subset

The provider-covered subset includes `.rs` files, empty files, source-file roots,
freestanding functions, raw identifiers, inline modules, external module
declarations, consts, statics, structs, tuple structs, unit structs, enums, enum
variants, traits, trait method signatures, trait methods with default bodies,
impl methods, comments, attributes, generated-file markers, conditional
compilation attributes, macro definitions, macro invocations, invalid/partial
files, unsupported paths, unsafe paths, monorepo-style paths, and
Markdown-sensitive fixture text.

The contract intentionally excludes custom user queries, Cargo/package/workspace
discovery, crate graphs, module path resolution, imports or `use` resolution,
qualified name construction, macro expansion output, generated-source policy
enforcement, cfg/feature evaluation, type checking, parser diagnostics, source
snippets in failures, LSP data, lineage, true symbol history, ownership,
people metrics, scoring, and bug prediction.

Unsupported non-`.rs` paths return `unsupported` without parsing. Unsafe paths
are rejected before parsing. Invalid or partial Rust source returns `failed`
with caveats only; raw parser diagnostics and source snippets are not exposed.
Generated-file markers are caveated only and do not change scoring or runtime
behavior. Macro definitions and invocations are counted only; expansion output
is not inferred. Conditional compilation attributes are caveated only; features
and target cfgs are not evaluated. External module declarations are emitted by
syntactic name only; no file-system or crate module resolution is performed.

## Fixture corpus

| Fixture | Coverage |
| --- | --- |
| `tests/fixtures/tree_sitter_rust_query/supported_subset.rs` | Source-file root, module doc comment, const, static, inline module, unit struct, tuple struct, record struct, enum, enum variants, trait, trait methods, impl methods, module function, top-level function, external module declaration, raw identifier, monorepo-style path proof, and Markdown-sensitive text. |
| `tests/fixtures/tree_sitter_rust_query/macro_cfg.rs` | Conditional compilation attribute caveat, macro definition count, macro invocation count, skipped macro-expanded symbol, trait method signature, and proof that cfg and macro expansion are not evaluated. |
| `tests/fixtures/tree_sitter_rust_query/generated.rs` | Generated marker comment, struct, and function with generated caveat. |
| `tests/fixtures/tree_sitter_rust_query/invalid_partial.rs` | Invalid/partial Rust failure without diagnostics or snippets. |
| `tests/fixtures/tree_sitter_rust_query/empty.rs` | Empty source-file root symbol only. |
| `tests/fixtures/tree_sitter_rust_query/unsupported.md` | Unsupported path containing Rust-looking Markdown that is not parsed. |

All fixture paths are project-relative. No private paths, raw private reports,
remote URLs, authors, email addresses, commit messages, or source from sibling
repositories are recorded.

## Validation evidence

Fresh local validation on 2026-05-27:

| Command | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `zig build tree-sitter-rust-query-proof` | `0` | Query compiled, expected capture names were present, and all local fixtures passed. |
| `zig build tree-sitter-rust-symbol-proof` | `0` | Product Rust extractor proof emitted current-only symbols and caveats from local fixtures. |
| `zig build tree-sitter-rust-build-proof` | `0` | Existing Rust parser/scanner build proof still compiled, linked, and ran. |
| `zig build validate` | `0` | Product validation passed with Rust runtime provider output, docs, privacy scans, and matrix checks. |
| `zig build validate-all` | `0` | Validate-all included Rust build, query, and product symbol proof steps. |
| `zig build run -- --help` | `0` | CLI help lists Rust `.rs` support and no Cargo/crate/module/macro/cfg/type/dependency boundary. |
| `zig build run -- --explain` | `0` | Explain output lists Rust capability and no semantic Rust boundary. |
| `git diff --check` | `0` | No whitespace errors were reported. |

The proof uses only repository-local vendored Tree-sitter core and Rust parser
sources plus local fixtures. It performs no network access, package-manager
resolution, parser generation, telemetry, upload, remote enrichment, background
analysis, Cargo discovery, crate graph analysis, module-path analysis, macro
expansion, cfg evaluation, type checking, LSP analysis, or true symbol-history
analysis. Runtime `--symbol-line-history` remains current-line Git evidence for
HEAD line ranges only.
