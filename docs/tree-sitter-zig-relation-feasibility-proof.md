# Tree-sitter Zig relation feasibility proof

This record admits a narrow internal Zig relationship proof through the shared
relation-provider contract. It does not add public Zig relationship support,
CLI flags, report schema fields, scoring inputs, cache truth, network access,
telemetry, remote enrichment, or hosted analysis.

## Decision

Admit the Zig lane internally for proof and reviewer validation only. The lane
uses the existing vendored Tree-sitter Zig grammar and emits conservative
syntax-only candidates for `.zig` files through `RelationCandidate`.

Public README, user guide, manual page, help text, capability matrix, and report
fixtures remain unchanged in this feature. Any public support wording is deferred
to a later matrix refresh.

## Admission bar assessment

| Criterion | Result |
| --- | --- |
| Local parser basis | Pass. Uses the already vendored Tree-sitter core and Zig grammar sources. |
| Shared contract | Pass. Emits provider-neutral `RelationCandidate` rows only. |
| Useful syntax evidence | Pass. Emits `contains`, `import_include`, `call`, `reference`, `unresolved`, and `unknown`. |
| No fabricated resolution | Pass. Unknown imports, namespaces, methods, comptime constructs, and unresolved names stay caveated. |
| Additive evidence | Pass by implementation boundary. The lane is not wired into file scoring, ranking, historical symbol evidence, or public report semantics. |
| Degradation | Pass in the conformance harness for unsupported paths, parse failures, unavailable state, oversized input, and candidate caps. |

## Conservative evidence admitted

- `contains` for file, container-like declarations, functions, nested functions,
  and variable definitions observed in the same syntax tree.
- `import_include` for string targets in `@import(...)`, as external strings
  only. No package, build graph, or file-system mapping is inferred.
- `call` for direct identifier call expressions where the callee is syntactic
  identifier text.
- `reference` for simple identifier references that uniquely match a local
  syntactic definition name.
- `unresolved` for simple identifiers with no unique local syntactic definition.
- `unknown` for member access and non-import builtin calls where syntax is
  relation-like but semantic classification would overclaim.

## Caveats and non-goals

The proof deliberately does not resolve Zig packages, build graph meaning,
namespaces, container member lookup, method dispatch, type information, comptime
execution, generated code, aliases, or cross-file imports. These gaps are
represented as caveats, external-string endpoints, unresolved endpoints, or
unknown relation candidates.

The feature must not be used as evidence that `git-hotspots` publicly supports
Zig relationship reports. It is reviewer evidence for the internal provider seam
only, and it remains additive to deterministic file-history evidence.

Feature 0095 later admitted this proof into the public relationship capability
matrix as `tree-sitter-zig-relations`, with the same syntax-only caveats and no
scoring, ranking, cache-truth, ownership, dependency-proof, or bug-prediction
claim.

## Reproducible fixture evidence

The shared conformance harness exercises a Zig fixture with `@import`, a
container-like `struct`, nested functions, direct calls, local references,
unresolved identifiers, member syntax, builtin comptime-like syntax, unsupported
paths, invalid source, unavailable state, oversized input, and cap truncation.

Required fresh validation for this feature remains:

- `git diff --check`
- `zig fmt --check build.zig src tests`
- `zig build test`
- `zig build validate`
- privacy-safe this-repo dogfood smoke or an explicit skip reason
