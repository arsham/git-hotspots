# Feature 0027: Tree-sitter Zig symbol extraction proof

## Summary

Add an internal, test-only Tree-sitter Zig current-symbol extraction proof. This
feature proves symbol extraction semantics against vendored Tree-sitter sources
before exposing provider evidence in CLI output.

This is deliberately not the user-facing `--symbols` feature. The next feature
may add inspect-only symbol output once the extractor's supported symbol kinds,
ranges, deterministic ordering, failure states, and privacy posture are proven.

## Problem

Feature 0026 proved that the vendored Tree-sitter core and Zig grammar compile,
link, and parse a tiny Zig source in an isolated non-product build step. It did
not prove that the project can extract useful, deterministic current symbol
evidence for Zig files.

Jumping directly to CLI/report symbol output would force public schema and UX
choices before the extractor's behaviour is known. We need a small internal
proof first.

## Outcome

A future runner can extract deterministic `provider.CurrentSymbolEvidence` from
in-memory Zig source for a repo-relative `.zig` path using vendored Tree-sitter
sources, with tests covering supported symbols, ranges, ordering, and failure
or unsupported states.

Normal CLI behaviour remains unchanged. No user-visible symbol output exists in
this feature.

## Requirements

### R1 - Internal extractor only

Add a small internal Tree-sitter Zig symbol extraction module, for example
`src/tree_sitter_zig.zig` or an equivalently narrow name.

The module must:

- use only repo-local vendored Tree-sitter core and tree-sitter-zig sources;
- accept in-memory source bytes and a repo-relative path;
- return current-only symbol evidence shaped by `src/provider.zig`;
- keep source text, raw parser diagnostics, absolute paths, remotes, author
  identities, and private machine details out of returned evidence;
- clean up parser/tree resources with explicit `defer` or `errdefer` paths;
- use deterministic ordering.

### R2 - Supported symbol contract

The proof must define the exact supported symbol subset in code comments or
docs. The minimum supported subset is named Zig function declarations.

The runner may add named container/type declarations only if it can prove them
with deterministic tests and clear semantics. Unsupported constructs must be
ignored or represented with an explicit caveat in tests; they must not produce
unstable or misleading symbols.

The proof must not claim complete Zig semantic understanding.

### R3 - Range semantics

The proof must choose and document one range representation for extracted
symbols, preferably current line ranges using the existing `provider.CurrentRange`
shape.

Range semantics must be deterministic and tested. If lines are used, define
whether they are 1-based inclusive or another explicit convention.

### R4 - Failure and unsupported behaviour

The extractor must handle unsupported file types, empty files, partial/invalid
Zig, and parser failure without crashing the CLI build/test process.

Failure state must be testable through provider failure/caveat semantics or a
small internal result type that maps cleanly to the provider contract. Raw
parser stderr and source snippets must not be exposed.

### R5 - No product wiring

This feature must not add user-visible provider behaviour.

Forbidden in this feature:

- CLI flags such as `--symbols`;
- changes to `--inspect` semantics;
- table, JSON, or Markdown report schema changes;
- default provider execution;
- provider registry or plugin loading;
- file hotspot scoring, ranking, confidence, or caveat changes;
- historical symbol lineage, symbol moves, symbol renames, dependency
  propagation, cache, telemetry, network, package manager fetches, parser
  generation, or global/system Tree-sitter dependencies.

### R6 - Build isolation

The proof may add a dedicated non-product build/test step if needed, for example
`zig build tree-sitter-symbol-proof`.

Normal `zig build` must still build the existing CLI. No-provider table, JSON,
Markdown, and inspect outputs must remain byte-stable unless the dispatch
contract explicitly approves a docs-only wording change, which this feature does
not.

### R7 - Documentation

Update the provider/tree-sitter evidence docs only as needed to record the new
internal proof boundary, supported subset, limitations, validation command, and
next-step handoff.

Docs must keep public claims careful: provider evidence is current-only
enrichment, not bug prediction, code-quality scoring, developer ranking,
semantic ownership, or historical symbol lineage.

## Acceptance criteria

- A dedicated internal extractor/proof exists for Zig current-symbol extraction.
- The extractor uses only vendored local Tree-sitter sources.
- Synthetic tests prove at least named Zig function extraction.
- Tests prove deterministic ordering and deterministic range semantics.
- Tests cover empty/invalid or partial Zig input and unsupported non-Zig input.
- Tests cover privacy-safe handling of weird names where supported, including
  unicode and Markdown-sensitive characters if those are accepted symbols.
- Normal CLI output remains unchanged when no future provider flag exists.
- No `--symbols` or other provider-facing CLI/report surface is added.
- `zig build validate` passes.
- The Tree-sitter build proof still passes.
- The new symbol proof command, if added, passes.
- Close-out validation includes this repo and `sibling-local-repo` using only the
  privacy-safe label.

## Edge cases

- Empty `.zig` file returns no symbols or an explicit partial/failed state.
- Invalid or partial Zig source does not crash and does not expose raw parser
  diagnostics or source snippets.
- Unsupported non-`.zig` path does not parse and reports unsupported state in the
  internal proof.
- Symbol names requiring Markdown or JSON escaping remain deterministic and safe
  in provider evidence values, even though they are not rendered publicly yet.
- Nested function declarations are either deterministically supported or
  explicitly excluded by the supported-symbol contract.
- Container/type declarations are either deterministically supported with tests
  or explicitly deferred.

## Verification

Required validation evidence:

- `zig fmt --check build.zig src tests`
- `zig build test`
- `zig build`
- `zig build validate`
- `zig build tree-sitter-build-proof`
- new symbol proof step if added, for example `zig build tree-sitter-symbol-proof`
- `git diff --check`
- no-provider byte-stability or golden parity evidence for table, JSON, Markdown,
  and inspect outputs
- local-only/offline scan proving no network, package manager, parser generation,
  submodule, system Tree-sitter, telemetry, upload, or background analysis
- close-out validation with `sibling-local-repo` label only

## Non-goals

- No user-facing `--symbols` output.
- No JSON/Markdown/table provider schema.
- No symbol ranking or scoring.
- No historical symbol lineage.
- No multi-language support.
- No provider registry.
- No cache.
- No CI/release/package manager work.
