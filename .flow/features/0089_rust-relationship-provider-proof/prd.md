# Rust relationship provider proof

## Problem

Rust has existing local Tree-sitter parser and current-symbol proof surfaces,
and it is valuable for real-repo relationship evidence. Rust relationship
extraction is also easy to overclaim because modules, traits, macros, generics,
and method resolution require semantic knowledge that a syntax-only provider
cannot prove.

## Outcome

Add bounded local Rust relationship provider support using the existing
provider-neutral relation model and aggregation/report surfaces. The output
remains opt-in behind `--symbols --symbol-relationships`, additive,
deterministic, caveated, local-first, and evidence-only.

## Requirements

R1: Reuse the existing relation provider model and aggregation pipeline. Do not
create Rust-specific report schemas, scoring changes, cache truth, or a separate
relationship output path.

R2: Add Rust relation extraction over current local source bytes for retained
ranked-file candidates only.

R3: Emit syntax-only `contains`, `reference`, `call`, `import_include`,
`unresolved`, and `unknown` candidates where Rust Tree-sitter evidence supports
that honestly. Macro expansion, trait resolution, module resolution, method
receiver type, and dynamic dispatch must remain caveated or unresolved.

R4: Preserve deterministic sorting, caps, omitted counts, provider failure
caveats, unsupported-language behaviour, privacy-safe provider inputs, and no
scoring or ranking effect.

R5: Add or update fixtures that prove Rust relationship extraction for nested
items, function or method-like calls, `use`/module-like import evidence,
unresolved targets, macro or generated-like caveats, invalid input, cap
behaviour, and deterministic ordering.

R6: Update public docs, man page, provider capability matrix text, explain/help
claims, and validation checks only to state Rust relationship support accurately
and with caveats.

R7: Update golden JSON, Markdown, and table fixtures if public
`--symbol-relationships` output changes. Fixture updates must remain
deterministic and privacy-safe.

R8: Validate that default output without `--symbol-relationships` is unchanged
and that `--symbol-relationships` still requires `--symbols`.

R9: Run `zig build tree-sitter-rust-build-proof`,
`zig build tree-sitter-rust-query-proof`,
`zig build tree-sitter-rust-symbol-proof`, `zig build test`, and
`zig build validate` or justify any replaced command through the dispatch
contract.

R10: Include privacy-safe real-repo smoke evidence for at least one repository
with tracked Rust files, or record a durable skip reason.

## Non-goals

- No Cargo metadata graph, crate dependency resolver, rust-analyzer dependency,
  macro expansion, trait solving, type inference, borrow checking, dynamic
  dispatch proof, or cross-crate call graph.
- No network, telemetry, runtime LLM, remote index, mandatory cache, cargo
  invocation, or global language server dependency.
- No relationship-based scoring or ranking changes.
- No support claim for languages not implemented in this feature.

## Edge cases

E1: A macro invocation looks call-like but cannot be resolved. Preserve syntax
evidence as caveated call, unknown, or unresolved, not semantic certainty.

E2: A method call has a receiver but no type resolution. Do not claim the target
impl or trait method unless local syntax evidence can identify it safely.

E3: `use`, `mod`, and path expressions may name modules or external crates.
Represent them as local strings or unresolved/external endpoints with caveats.

E4: Lifetimes, generics, attributes, and generated code patterns must not break
file-level hotspot output.

## Verification notes

Close-out evidence should include:

- `git diff --check`.
- `zig fmt --check build.zig src tests`.
- Rust tree-sitter proof commands.
- `zig build test`.
- `zig build validate`.
- Updated fixture and validation proof for JSON, Markdown, and table outputs
  when public output changes.
- `flow validate --target feature:0089`.
- `flow validate --target brief:B002`.
- Independent reviewer verification of Rust caveats and public claim accuracy.
