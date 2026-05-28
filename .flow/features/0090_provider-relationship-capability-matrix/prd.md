# Provider relationship capability matrix

## Problem

As relationship support expands beyond Python, project documentation and
validation need a durable capability matrix that distinguishes symbol support,
historical symbol support, and relationship support per language. Without this,
help text, README claims, user guide claims, man page wording, inspect output,
and validation assertions can drift or overclaim.

## Outcome

Update the provider capability matrix and validation harness so relationship
support is explicit per language and kept in sync across public documentation,
help/explain/inspect surfaces, fixtures, and validation. The feature is a
claim-safety and drift-prevention slice after the TypeScript/JavaScript and Rust
provider proofs close.

## Requirements

R1: Update README, docs/user-guide.md, docs/developer-guide.md,
man/git-hotspots.1, and any provider capability text so each supported language
states symbol, current-line history, historical-symbol, and relationship support
accurately.

R2: Distinguish unsupported, internal-only, and public opt-in relationship
support. Public wording must not imply full call graph, type-aware resolution,
dependency proof, ownership, code quality, developer metrics, or bug prediction.

R3: Update help, explain, inspect, and provider capability validation checks so
new relationship-language support cannot drift silently.

R4: Add validation assertions that `--symbol-relationships` still requires
`--symbols`, remains opt-in, remains local-only, and has no scoring effect.

R5: Ensure JSON, Markdown, and table fixture checks cover the relationship
provider list, caveats, deterministic ordering, omitted counts, and privacy
constraints after language expansion.

R6: Preserve default output compatibility. Running without
`--symbol-relationships` must not add relationship fields or relationship
sections.

R7: Run `zig build validate` and any targeted fixture validation needed for the
updated public surfaces.

R8: Update B002 with a durable decision that the first provider-expansion batch
closed and that future languages must update the capability matrix through the
same validation-owned surface.

## Non-goals

- No new relationship provider implementation beyond what prior batch features
  already delivered.
- No new CLI flag or report schema beyond existing `--symbol-relationships`.
- No scoring or ranking changes.
- No network, telemetry, runtime LLM, remote index, mandatory cache, or browser
  UI work.

## Edge cases

E1: A language has current-symbol support but no relationship support. The
matrix must say so explicitly without making the language look broken.

E2: A language has internal relation proof but no public report support. The
matrix must not expose it as public support until a public feature closes.

E3: If validation fixtures use a project-local synthetic repo, outputs must not
contain absolute private paths, remotes, authors, emails, commit messages, or raw
private report dumps.

E4: If later languages are added, validation should fail until matrix/docs/help
surfaces are deliberately updated.

## Verification notes

Close-out evidence should include:

- `git diff --check`.
- `zig fmt --check build.zig src tests`.
- `zig build test`.
- `zig build validate`.
- Fixture determinism/privacy checks for JSON, Markdown, and table outputs.
- `flow validate --target feature:0090`.
- `flow validate --target brief:B002`.
- Independent reviewer verification that public claims match implemented
  provider capabilities.
