# TypeScript and JavaScript relationship provider proof

## Problem

The public `--symbol-relationships` report currently exposes bounded Python
Tree-sitter relationship evidence. TypeScript and JavaScript already have local
Tree-sitter parser and current-symbol proof surfaces, and they are high-value
languages for relationship evidence, but they need their own caveated provider
proof before public claims can expand safely.

## Outcome

Add bounded local TypeScript, TSX, and JavaScript relationship provider support
using the existing provider-neutral relation model and aggregation/report
surfaces. The output remains opt-in behind `--symbols --symbol-relationships`,
additive, deterministic, caveated, local-first, and evidence-only.

## Requirements

R1: Reuse the existing relation provider model and aggregation pipeline. Do not
create a language-specific report schema, scorer, cache truth, or separate
relationship output path.

R2: Add TypeScript and JavaScript relation extraction over current local source
bytes for retained ranked-file candidates only. TSX support may share the
TypeScript implementation when the grammar surface is already available.

R3: Emit `contains`, `reference`, `call`, `import_include`, `unresolved`, and
`unknown` candidates where the selected grammars support them cheaply and
honestly. Unsupported constructs must lower confidence or become unresolved or
unknown; they must not fabricate targets.

R4: Preserve deterministic sorting, caps, omitted counts, provider failure
caveats, unsupported-language behaviour, privacy-safe provider inputs, and no
scoring or ranking effect.

R5: Add or update unit and integration fixtures that prove TypeScript,
JavaScript, and TSX relationship extraction for supported relation kinds,
unresolved targets, dynamic/member access caveats, unsupported or invalid input,
cap behaviour, and deterministic ordering.

R6: Update public docs, man page, provider capability matrix text, explain/help
claims, and validation checks only to the extent needed to state the newly
supported relationship languages accurately.

R7: Update golden JSON, Markdown, and table fixtures if public
`--symbol-relationships` output changes. Fixture updates must remain
deterministic and privacy-safe.

R8: Validate that default output without `--symbol-relationships` is unchanged
and that `--symbol-relationships` still requires `--symbols`.

R9: Run `zig build tree-sitter-javascript-build-proof`,
`zig build tree-sitter-javascript-symbol-proof`,
`zig build tree-sitter-typescript-build-proof`,
`zig build tree-sitter-typescript-symbol-proof`, `zig build test`, and
`zig build validate` or justify any replaced command through the dispatch
contract.

R10: Include privacy-safe real-repo smoke evidence for at least one repository
with tracked TypeScript or JavaScript files, or record a durable skip reason.

## Non-goals

- No type-aware resolution, package graph, bundler graph, React component graph,
  JSX runtime semantics, dynamic dispatch proof, or cross-file semantic call
  graph.
- No network, telemetry, runtime LLM, remote index, mandatory cache, npm/yarn
  invocation, or global language server dependency.
- No relationship-based scoring or ranking changes.
- No support claim for languages not implemented in this feature.

## Edge cases

E1: A call or reference is syntactically visible but the target cannot be mapped
safely. Preserve an unresolved endpoint and caveat.

E2: Member access, optional chaining, computed properties, dynamic imports,
JSX/TSX expressions, decorators, generics, and type-only constructs may need
separate caveats or unknown candidates.

E3: A file exceeds caps or parse limits. Keep the file hotspot result and expose
relationship caveats and omitted counts.

E4: TypeScript and JavaScript grammars may produce different node shapes for
similar constructs. Shared code is allowed only when tests prove deterministic
behaviour for each admitted extension.

## Verification notes

Close-out evidence should include:

- `git diff --check`.
- `zig fmt --check build.zig src tests`.
- Targeted tree-sitter proof commands for JavaScript, TypeScript, and TSX when
  available.
- `zig build test`.
- `zig build validate`.
- Updated fixture and validation proof for JSON, Markdown, and table outputs
  when public output changes.
- `flow validate --target feature:0088`.
- `flow validate --target brief:B002`.
- Independent reviewer verification of public claim accuracy and deterministic
  evidence.
