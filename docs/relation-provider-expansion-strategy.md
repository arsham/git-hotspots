# Relation provider expansion strategy

This planning-only strategy ranks the next relationship-provider expansion work
for `git-hotspots`. It turns the relation architecture into a serial admission
rubric for future implementation features. It does not add runtime providers,
CLI flags, report fields, scoring changes, cache truth, network access,
telemetry, package publication, or browser-visible UI work.

Relationship providers remain optional local evidence. They help explain what a
bounded source provider observed near retained hotspot candidates, but they are
not call-graph truth, dependency proof, ownership evidence, code-quality
judgement, developer metrics, bug prediction, or a scoring input.

## Shared rubric

Every candidate language is compared with the same dimensions:

- existing parser support: whether the repository already carries a local
  Tree-sitter grammar or an equivalent local source that can run without
  network access;
- current-symbol coverage: whether `--symbols` already has current working-tree
  coverage that can provide file and symbol endpoints;
- likely relation kinds: which of `contains`, `reference`, `call`,
  `import_include`, `unresolved`, and `unknown` can be produced honestly from a
  syntax-only provider;
- fixture complexity: how much synthetic fixture coverage is needed for common
  syntax, unresolved targets, unsupported cases, failures, caps, and stable
  ordering;
- runtime risk: expected parser cost, query complexity, ambiguous syntax,
  dynamic constructs, generated-code exposure, and failure behaviour;
- public value: how much the lane helps common local repository investigations
  once caveats are explicit;
- real-repo smoke availability: whether this repository or another
  privacy-safe local repository can exercise the provider without committing
  private paths or raw private report output;
- caveat burden: how much language-specific wording is needed to avoid
  overclaiming semantic dependency, type resolution, package resolution,
  ownership, scoring, or bug prediction.

A language can have current-symbol support and still remain unsupported for
relationship evidence when syntax-only relation coverage would be weak,
misleading, too expensive, or hard to validate with deterministic fixtures.

## Comparison

| Language lane | Parser and symbol basis | Likely first relation kinds | Value and risk | Decision |
| --- | --- | --- | --- | --- |
| TypeScript | Existing `tree-sitter-typescript` symbol lane for `.ts`, `.mts`, and `.cts`. | `contains`, local syntactic `reference`, call-like syntax, import strings, `unresolved`, and `unknown`. | High public value because many projects use TypeScript, but caveats must reject tsconfig, type checking, workspace, package, and module-resolution claims. Fixture complexity is moderate because imports, calls, property access, and type-only syntax need separate cases. | First implementation lane, shipped with TSX/JavaScript only when the shared grammar surfaces can stay bounded. |
| JavaScript | Existing `tree-sitter-javascript` symbol lane for `.js`, `.mjs`, `.cjs`, and admitted `.jsx`. | `contains`, local syntactic `reference`, call-like syntax, require/import strings, `unresolved`, and `unknown`. | High value and similar query shape to TypeScript, but dynamic property access, CommonJS patterns, JSX, bundler behaviour, packages, and workspaces need visible caveats. Fixture complexity is moderate. | First implementation lane paired with TypeScript/TSX so shared syntax assumptions are reviewed together. |
| Rust | Existing `tree-sitter-rust` symbol lane for `.rs`. | `contains`, use/import-like paths, syntactic calls where the callee token is local, `unresolved`, and `unknown`. | High value for systems projects, but macro expansion, crates, modules, cfg features, trait dispatch, type checking, and Cargo resolution make semantic claims risky. Fixture complexity is higher than TypeScript/JavaScript. | Second implementation lane after TypeScript/JavaScript proves the shared provider seam. |
| Go | Existing `tree-sitter-go` symbol lane for `.go`. | `contains`, syntactic calls, selector references, import strings, `unresolved`, and `unknown`. | Useful and comparatively regular syntax, but honest package, module, build-tag, method-set, interface, cgo, and dependency caveats are required. Real-repo smoke is likely available. | Defer until after the first batch hardens the matrix and validation harness. |
| Lua | Existing `tree-sitter-lua` symbol lane for `.lua`. | `contains`, call-like syntax, require strings, table/member references where syntax-only evidence is safe, `unresolved`, and `unknown`. | Useful for plugin-heavy repositories, but dynamic tables, metatables, module loaders, runtime mutation, and package conventions create a high caveat burden. | Defer until JavaScript-style dynamic caveats and cap behaviour are proven. |
| Zig | Existing `tree-sitter-zig` symbol lane for `.zig`. | `contains`, import strings, call-like syntax, simple references, `unresolved`, and `unknown`. | Valuable for this repository and dogfood validation, but broader public value is lower than TypeScript/JavaScript, Rust, and Go. Compile-time constructs and build graph meaning must remain out of scope. | Defer as a later dogfood and matrix-hardening lane. |
| Python | Existing `tree-sitter-python` relationship proof and public opt-in relationship output. | Already proves bounded `contains`, syntactic references, calls, imports, unresolved targets, and unknown fallbacks for the first lane. | It is the baseline, not the next expansion. Future work should use it for regression comparisons and report-drift protection rather than reselect it as the next lane. | Keep as the reference lane and validation baseline. |

## Selected serial batch order

The next provider-expansion batch should remain serial:

1. Feature 0088: TypeScript, TSX, and JavaScript relationship provider proof.
2. Feature 0089: Rust relationship provider proof.
3. Feature 0090: provider relationship capability matrix and validation
   hardening.

TypeScript/TSX and JavaScript should ship together in the first implementation
feature because their provider surfaces and user caveats overlap. Keeping them
in one feature lets the shared parser/query assumptions, import/call fixtures,
JSX and TSX boundaries, and public wording be reviewed as one contract. They
should still report language-specific caveats where TypeScript type syntax,
TSX, JSX, CommonJS, or ESM constructs differ.

Rust should follow rather than lead. It has high public value and existing
symbol support, but a syntax-only proof must be narrower: `contains`,
import/include-like `use` paths, simple call-like syntax, unresolved targets,
and `unknown` are acceptable. Macro expansion, trait dispatch, crates, module
resolution, cfg feature selection, type checking, Cargo metadata, and semantic
callee proof must remain caveated or unsupported.

Go, Lua, and Zig should wait until the first two expansion features prove that
the common provider seam, caps, validation harness, matrix wording, and public
claim controls prevent overclaim drift. Python remains the reference lane and
should supply regression expectations for shared aggregation and reporting.

## Admission bar for future providers

A future relationship provider is admissible only when it satisfies all of the
following conditions:

- The evidence source is local Tree-sitter or an equivalent local source named
  by the implementation feature. It must not require network access,
  telemetry, remote enrichment, runtime LLM judgement, a hosted service, or
  mandatory cache truth.
- The provider emits provider-neutral relation candidates through the shared
  relation contract, not language-specific public truth.
- It supports `contains` and at least one useful syntax evidence kind such as
  `reference`, `call`, or `import_include`, where the language can do so
  honestly.
- It preserves `unresolved` targets instead of fabricating endpoint identity.
- It emits `unknown` when relation-like syntax is present but safe
  classification is not possible.
- Unsupported files, unavailable providers, parse failures, stale input,
  oversized files, generated-policy skips, cap hits, and time or memory limits
  degrade with visible caveats and failure states instead of breaking file-level
  hotspot analysis.
- Deterministic sorting is owned by shared aggregation. Provider output must not
  depend on hash-map, filesystem, provider, process, or parser iteration order
  for public sample order.
- Candidate, file, symbol, relation, runtime, and sample caps are explicit, and
  omitted counts are reported where public output samples relation evidence.
- Caveats are attached where users see the evidence, including unresolved
  targets, syntax-only support, dynamic dispatch, package or module resolution
  gaps, macro or generated-code limits, unsupported language, parser failure,
  stale input, and cap hits.
- Relation evidence remains additive. It must not change file score, symbol
  score, rank, confidence, co-change evidence, Git rename lineage, scope,
  inclusion/exclusion decisions, cache truth, or public hotspot semantics.

A provider expansion must remain internal when the implementation only proves a
query, provider seam, or aggregation behaviour. Public report claims may change
only when a separate feature updates the provider capability matrix, report
fixtures, CLI/user documentation, manual page, and validation harness together.

## Common validation bar

Each provider-expansion feature must record fresh evidence for the shared bar:

1. Grammar proof when the language needs a new vendored grammar, parser update,
   query addition, or admission policy change.
2. Targeted provider unit proof for supported relation kinds, unresolved
   targets, unknown fallbacks, unsupported files, provider failures, cap hits,
   caveats, and deterministic ordering.
3. Integration fixture proof that retained hotspot candidates can receive
   provider-neutral relation candidates without changing scoring or ranking.
4. Public report fixture drift checks whenever public support, documentation,
   manual text, or capability claims change.
5. `zig build test`.
6. `zig build validate`.
7. At least one privacy-safe real-repository smoke, or a documented skip reason
   that names the missing local condition without exposing private paths or raw
   private report output.

The smoke record should keep command shapes, pass/fail status, bounded counts,
caveat counts, elapsed time, and categorical observations. It must not commit
absolute local paths, remotes, author identities, emails, source snippets,
private repository names, parser diagnostics, raw private reports, or commit
messages.

## Public-claim controls

Public documentation must not say that a language has relationship support until
its implementation and validation feature closes. When public documentation is
updated later, the provider capability matrix and report fixtures must change in
the same delivery boundary so CLI help, README, user guide, manual page, and
validation expectations cannot drift apart.

Capability wording should say what local syntax evidence was observed and what
is unsupported. It should not imply full call graphs, dependency graphs, package
graphs, type checking, semantic reference resolution, ownership, code quality,
developer performance, impact, bug prediction, cache truth, network access, or
telemetry.

## Current admission matrix

Feature 0095 admits the predecessor proofs below into the public relationship
capability matrix. This matrix records only syntax-provider evidence already
closed by the source feature; it does not widen scoring, ranking, cache truth,
network access, telemetry, ownership, dependency-proof, or bug-prediction
claims.

| Language lane | Source feature | Public relationship provider | Admitted evidence | Required caveats |
| --- | --- | --- | --- | --- |
| Python | Existing baseline before 0091 | `tree-sitter-python-relations` | Bounded local syntax relation evidence already exposed publicly. | No imports, packages, virtual environments, generated-source policy, call-graph truth, scoring, or ownership claims. |
| JavaScript | 0091 | `tree-sitter-javascript-relations` | Bounded syntax evidence for contains, references, calls, imports, unresolved targets, and unknown relation-like syntax. | No Node, packages, workspaces, module resolution, TypeScript, TSX, dependency graphs, call-graph truth, scoring, or ownership claims. |
| TypeScript | 0091 | `tree-sitter-typescript-relations` | Bounded syntax evidence for contains, calls, unresolved targets, and unknown relation-like syntax. | No packages, workspaces, tsconfig, module resolution, type checking, dependency graphs, cache, call-graph truth, scoring, or ownership claims. |
| TSX | 0091 | `tree-sitter-tsx-relations` | Bounded syntax evidence for contains, references, unresolved targets, and unknown relation-like syntax. | No React, DOM, package, type-analysis, dependency-graph, cache, call-graph, scoring, or ownership claims. |
| Rust | 0091 | `tree-sitter-rust-relations` | Bounded syntax evidence for contains, references, calls, import/include-like syntax, unresolved targets, and unknown relation-like syntax. | No Cargo, crates, module resolution, macro expansion output, cfg feature selection, type checking, dependency graphs, call-graph truth, scoring, or ownership claims. |
| Go | 0092 | `tree-sitter-go-relations` | Bounded syntax evidence for contains, import includes, direct identifier calls, selector-like syntax, unresolved identifiers, and unknown relation-like syntax. | No packages, modules, build tags, cgo, dependency graphs, method-set or interface semantics, true semantic lineage, scoring, or ownership claims. |
| Lua | 0093 | `tree-sitter-lua-relations` | Bounded syntax evidence for contains, require-like imports, direct calls, table/member reference-like syntax, unresolved identifiers, and unknown relation-like syntax. | No package, require, runtime module resolution, metatables, dynamic table keys, dependency graphs, runtime execution, scoring, or ownership claims. |
| Zig | 0094 | `tree-sitter-zig-relations` | Bounded syntax evidence for contains, `@import` strings, direct identifier calls, local identifier references, unresolved identifiers, and ambiguous member or comptime syntax. | No packages, build graph, comptime, generated-code truth, dependencies, semantic moves, true semantic lineage, scoring, or ownership claims. |
| Unsupported current files | 0095 matrix refresh | unsupported fallback | No relationship records; file evidence remains intact. | No parser diagnostics, source snippets, parsed symbols, relationship support, or scoring claims. |
