# Rust provider completion batch

## Problem

Rust Tree-sitter work has reached the point where admission, source import,
offline build proof, and a test-only Rust query contract exist, but the runtime
CLI still does not expose Rust as an inspect-only symbol provider. Public help,
README, user guide, man page, explanation text, capability-matrix validation,
and provider selection currently list Zig, Go, Python, JavaScript, Lua,
TypeScript, and TSX but omit Rust.

That leaves the Rust lane in an awkward half-complete state: the repository has
vendored Rust grammar evidence and query fixtures, while users and downstream
agents cannot ask for deterministic current Rust symbol evidence through the
normal `--inspect PATH --symbols` path.

## Outcome

Complete the first runtime Rust provider lane by adding inspect-only,
current-working-tree Rust symbol evidence for repo-relative `.rs` files, backed
by the already-vendored `tree-sitter-rust` source and project-owned Rust query
contract. The feature keeps Rust provider output additive to file-level Git
history, includes current-line Git evidence when the existing
`--symbol-line-history` flag is requested, and updates docs, help, fixtures,
validation, and provider capability matrices so public claims match runtime
behaviour.

Rust support remains narrow: no Cargo, crate graph, module resolution, macro
expansion, cfg evaluation, type checking, LSP, dependency analysis, true symbol
history, scoring changes, cache requirement, repo-wide scanning, network access,
telemetry, upload, or remote enrichment.

## Requirements

R1: Add a product Rust Tree-sitter extractor for inspect-only `.rs` files using
only repository-local vendored Tree-sitter core and `tree-sitter-rust` sources.
The extractor must expose provider evidence with provider name, version,
contract version, query/config fingerprint, local input identity, freshness,
failure state, confidence, provenance, and caveats.

R2: Keep Rust provider selection extension-based and inspect-path-only. A
matched repo-relative path ending in `.rs` may use the Rust provider after normal
inspect scoring and scope selection. Unsupported non-`.rs` paths must continue
to use the existing unsupported-provider fallback while preserving inspected
file-level Git evidence.

R3: Read only the current working-tree file for the matched inspected path, with
the existing bounded-file policy. Missing, symlinked, too-large, non-regular, or
unreadable current Rust files must report provider caveats without parser
diagnostics, source snippets, absolute local paths, remotes, author identities,
commit messages, or private repository names.

R4: Map the project-owned Rust query contract into current symbol evidence with
deterministic ordering and one-based inclusive line ranges. Covered symbols are
source-file module rows, inline or external modules, freestanding functions,
impl and trait methods, structs, tuple structs, unit structs, enums, traits,
consts, statics, and enum variants where the existing query contract can name
them syntactically.

R5: Caveat or skip Rust constructs that require semantic interpretation. The
provider must not claim Cargo package or workspace understanding, crate graph
analysis, module path resolution, `use` or re-export resolution, macro
expansion, cfg or feature evaluation, type checking, trait resolution, LSP
understanding, generated-source policy enforcement, ownership, semantic moves,
or dependency analysis.

R6: Wire Rust into runtime `--inspect PATH --symbols` output without changing
file score, rank, confidence, co-change evidence, Git rename lineage, selected
scope, include/exclude decisions, report schemas, or no-provider analysis
outputs.

R7: Make existing `--symbol-line-history` behaviour work for Rust symbols when
requested through `--inspect PATH --symbols --symbol-line-history`. Evidence must
remain current-line Git evidence for the symbol's current HEAD line range, not
true symbol history, semantic lineage, ownership, `git log -L`, or bug
prediction.

R8: Update public documentation and terminal surfaces that enumerate supported
providers or examples: `--help`, `--explain`, `README.md`, `docs/user-guide.md`,
`man/git-hotspots.1`, and any relevant developer-guide validation guidance. The
wording must say Rust support is inspect-only, current-only, additive provider
evidence and must not overclaim semantic Rust understanding.

R9: Add deterministic Rust symbol fixtures and expected outputs for JSON,
Markdown, and table reporting, including at least supported symbols, empty
files, invalid or partial files, generated/caveated files, unsupported paths,
symlink/unavailable paths, too-large or missing files where the existing fixture
pattern supports them, symbol-limit behaviour, rename aliases, and current-line
history success.

R10: Extend validation coverage so capability-matrix checks, prohibited-claim
scans, privacy scans, and `validate-all` include Rust provider output. Full
close-out evidence must include this repository plus one privacy-safe
sibling/local real-repository smoke or an explicit privacy-safe unavailable-repo
reason accepted by the validation contract.

## Non-goals

- Do not add Cargo, `Cargo.toml`, `cargo metadata`, package, workspace, crate
  graph, module resolution, dependency graph, macro expansion, cfg evaluation,
  type checking, trait resolution, or LSP analysis.
- Do not add repo-wide symbol scanning, background provider execution, network
  access, telemetry, upload, remote enrichment, cache requirements, custom user
  queries, or provider plugin infrastructure.
- Do not change scoring, rank, confidence, co-change evidence, Git rename
  lineage, report schemas, include/exclude scope semantics, or default
  local-first runtime behaviour.
- Do not publish Rust support claims before runtime output, docs, tests, and
  validation all agree.
- Do not expose parser diagnostics, source snippets, absolute local paths,
  remotes, author identities, commit messages, raw private reports, or private
  repository names in provider failures, public docs, or committed evidence.

## Edge cases

E1: Unsupported non-`.rs` files still preserve inspected file evidence and emit
no parsed symbols.

E2: Invalid or partial Rust source fails closed with provider failure and caveats
only; raw parser diagnostics and source snippets are not exposed.

E3: Empty Rust files may emit the source-file module row only when the extractor
can produce a valid current source-file range.

E4: External `mod name;` declarations are emitted by bare syntactic name only;
no file-system or crate module lookup is performed.

E5: Macro definitions and macro invocations may be counted or caveated, but
macro expansion output must not be inferred as symbol evidence.

E6: Conditional compilation attributes are caveated only; features and target
cfgs are not evaluated.

E7: Generated-file markers are caveated only; generated-source policy is not
evaluated and does not change scoring.

E8: Current-line history is omitted or caveated when the inspected file is dirty,
unsupported, unavailable, invalid, has invalid ranges, or the current-line Git
command cannot produce safe evidence.

E9: Normal table, JSON, Markdown, and inspect outputs without `--symbols` must
remain byte-stable aside from intentional fixture updates caused by validation
harness setup.

## Verification notes

Close-out evidence should include:

- `git diff --check`.
- `zig fmt --check build.zig src tests` when Zig/test files change.
- `zig build tree-sitter-rust-build-proof`.
- `zig build tree-sitter-rust-query-proof`.
- A new Rust symbol extraction proof command, expected as
  `zig build tree-sitter-rust-symbol-proof` unless implementation chooses a
  clearer equivalent.
- `zig build test`.
- `zig build validate`.
- `zig build validate-all` after Rust provider wiring and proof aggregate
  updates.
- Focused runtime smokes for `--inspect <rust-file> --symbols` and
  `--inspect <rust-file> --symbols --symbol-line-history` in JSON, Markdown,
  and table formats.
- Capability-matrix validation proving Rust appears consistently in README,
  explain output, help text where applicable, and representative JSON provider
  output.
- Privacy/prohibited-claim scan covering new Rust expected outputs and public
  docs.
- Privacy-safe real-repository smoke on this repo and one suitable sibling/local
  repo when available, using labels and bounded counts only.

Review should prove that Rust provider support is useful, deterministic,
current-only, inspect-only, and additive to file-level Git evidence, without
promoting Rust syntax enrichment into product truth or semantic Rust analysis.
