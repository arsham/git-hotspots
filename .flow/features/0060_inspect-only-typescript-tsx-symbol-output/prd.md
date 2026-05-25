# Feature 0060: Inspect-only TypeScript/TSX symbol output

## Problem

TypeScript/TSX source import, offline build proof, query contract, and internal
symbol extraction proof are complete. The CLI still exposes Tree-sitter symbols
only for inspected Zig, Go, Python, and JavaScript files. Users inspecting a hot
TypeScript or TSX file cannot yet see current symbols for that one file.

## Outcome

Expose a narrow, opt-in TypeScript/TSX symbol provider through the existing
inspect-only symbol flow:

```sh
git-hotspots --inspect path.ts --symbols
git-hotspots --inspect path.tsx --symbols
```

The feature must reuse the existing `symbols` output envelope and preserve
file-level Git evidence as product truth. TypeScript/TSX symbols are current
working-tree symbols only. They must not affect file score, file rank, file
confidence, rename lineage, co-change evidence, scope filtering, default
analysis, package analysis, type checking, module resolution, or Node runtime
behaviour.

## Requirements

### Runtime and build safety

- Add reusable runtime TypeScript and TSX extraction support, expected as
  `src/tree_sitter_typescript.zig` or equivalent.
- The runtime module must own allocated symbol data and support
  deinitialisation with ownership parity to the existing Zig, Go, Python, and
  JavaScript symbol providers.
- The runtime module must validate repo-relative paths before reading files.
- The runtime module must parse only regular bounded current working-tree
  `.ts`, `.tsx`, `.mts`, and `.cts` files.
- Non-TypeScript/TSX inspect targets requested with `--symbols` must preserve
  existing unsupported/degraded provider behaviour.
- Product build wiring must avoid duplicate Tree-sitter core linkage when Zig,
  Go, Python, JavaScript, TypeScript, and TSX providers are available.
- Existing Zig, Go, Python, and JavaScript Tree-sitter providers must remain
  supported and stable.
- Existing proof targets must keep passing, including TypeScript/TSX build,
  query, and symbol proof targets.

### CLI surface

- `--symbols` remains valid only with `--inspect PATH`.
- `git-hotspots --inspect path.ts --symbols` and
  `git-hotspots --inspect path.tsx --symbols` must dispatch by the resolved
  inspected matched path extension.
- `.mts` and `.cts` paths must follow the same TypeScript provider contract
  where the parser/query proof supports deterministic extraction.
- Provider execution must stay inspect-only and must parse only the matched
  inspected file.
- No provider execution may happen for default reports or non-symbol inspect
  reports.
- No new flags are added in this feature.
- `--symbol-line-history` for TypeScript/TSX is out of scope. If combined with
  a TypeScript/TSX inspect target, behaviour must not claim TypeScript/TSX
  symbol history or lineage.

### TypeScript/TSX supported subset

The initial runtime subset follows Feature 0059:

- module or file evidence maps to an existing module/file kind when
  deterministic;
- top-level functions map to `function`;
- function expressions and arrow functions assigned to stable names map to
  `function` or the approved existing kind;
- classes map to `type`;
- constructors, methods, accessors, and supported class fields map to `method`
  or the approved existing kind;
- interfaces, type aliases, enums, namespaces, and deterministic module
  declarations map to existing provider kinds with caveats;
- constants and variables map to the chosen existing provider kind with caveats;
- ESM exports, deterministic re-exports, CommonJS export patterns, anonymous
  cases, and TSX component definitions follow the query/extraction contract.

The provider must not evaluate packages, imports, Node runtime, `package.json`,
workspaces, bundlers, module resolution, dependency graphs, tsconfig, TypeScript
type checking, custom queries, or LSP data.

### Ranges and ordering

- Symbol ranges must use deterministic one-based inclusive line ranges from the
  selected declaration node.
- Export, CommonJS, anonymous, generated/minified, class-member, interface,
  type-alias, enum, namespace, JSX, and TSX component handling must match the
  Feature 0058 query contract and Feature 0059 extraction proof.
- Symbol ordering must be deterministic and pinned in tests.
- Human outputs may use the existing human symbol display limit and sorting
  semantics, but JSON `symbols.items` must remain complete and deterministic.

### Output contract

- JSON must reuse the existing `symbols` envelope.
- JSON provider metadata for TypeScript/TSX must identify the provider as
  Tree-sitter TypeScript or Tree-sitter TSX and include provider version,
  contract version, current-only state, freshness, failure, confidence, caveats,
  and local provenance for the matched path.
- Table output must not say `current Zig symbols`, `current Go symbols`,
  `current Python symbols`, or `current JavaScript symbols` for TypeScript/TSX
  files.
- Table output must print the actual symbol kind instead of hardcoding a kind.
- Markdown output must identify the TypeScript/TSX provider state, caveats,
  counts, kinds, and line ranges.
- Human outputs must state that symbols do not change score, rank, lineage,
  confidence, scope, co-change evidence, or file-level Git truth.
- Existing no-provider outputs must remain byte-stable.
- Existing Zig, Go, Python, and JavaScript `--symbols` outputs must remain
  byte-stable except for explicitly planned language-neutral wording that does
  not alter schema or semantics.

### Documentation

- README, `--help`, and `--explain` must acknowledge that inspect-only
  Tree-sitter symbols support Zig, Go, Python, JavaScript, TypeScript, and TSX.
- Docs must state that TypeScript/TSX support is current working-tree symbol
  enrichment only.
- Docs must not claim TypeScript/TSX symbol history, package analysis,
  dependency analysis, import/module resolution, Node provider identity,
  tsconfig analysis, type checking, custom query execution, or repo-wide
  provider scanning.

## Edge cases

- Unsupported extension with `--symbols` returns visible provider unsupported or
  existing clear behaviour without raw diagnostics.
- Empty TypeScript/TSX file returns provider `ok` with zero symbols or a
  deterministic module-only result according to the approved contract.
- Invalid or partial TypeScript/TSX returns deterministic failure or caveated
  partial output without raw parser diagnostics or source snippets.
- Missing current file, symlink/non-regular file, and too-large file degrade as
  unavailable.
- TypeScript/TSX files with generated/minified markers, JSX, exports,
  CommonJS, anonymous functions, dynamic constructs, Unicode identifiers,
  Markdown-sensitive names/paths, interfaces, type aliases, enums, namespaces,
  decorators, overloads, and declaration merging are handled deterministically
  and escaped in human outputs.
- Rename-alias inspect must parse the resolved matched path, not the requested
  alias.
- A fixture with two TypeScript/TSX files must prove inspect-only behaviour: the
  provider parses only the inspected file.
- No authors, emails, commit messages, raw source snippets, parser stderr,
  absolute paths, private repo identifiers, or remote URLs may appear in output
  or committed evidence.

## Verification

Required commands before close-out:

```sh
zig fmt --check build.zig src tests
zig build test
zig build
zig build validate
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build tree-sitter-go-build-proof
zig build tree-sitter-go-symbol-proof
zig build tree-sitter-python-build-proof
zig build tree-sitter-python-symbol-proof
zig build tree-sitter-javascript-build-proof
zig build tree-sitter-javascript-query-proof
zig build tree-sitter-javascript-symbol-proof
zig build tree-sitter-typescript-build-proof
zig build tree-sitter-tsx-build-proof
zig build tree-sitter-typescript-query-proof
zig build tree-sitter-tsx-query-proof
zig build tree-sitter-typescript-symbol-proof
zig build tree-sitter-tsx-symbol-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-repo> -Dsmoke-label=sibling-local-repo
```

Additional validation expectations:

- TypeScript and TSX symbol success goldens for JSON, Markdown, and table
  output.
- `.ts`, `.tsx`, `.mts`, and `.cts` coverage where deterministic.
- Explicit `--symbol-limit` human-output coverage for TypeScript/TSX when
  applicable.
- Semantic JSON checks proving `symbols.items` remains complete under human
  limits.
- Unsupported, empty, invalid, unavailable, symlink/non-regular, too-large,
  generated/minified, JSX, exports, CommonJS, anonymous, rename-alias,
  Unicode, Markdown-sensitive, and two-file inspect-only cases.
- Repeated-output determinism for TypeScript/TSX symbol JSON, Markdown, and
  table outputs.
- Existing no-provider, Zig, Go, Python, and JavaScript symbol goldens remain
  stable.
- Privacy and prohibited-claim scans include new TypeScript/TSX symbol outputs,
  fixtures, docs, and validation summaries.
- Runtime/dependency scans prove no network, telemetry, upload, fetch, parser
  generation, package-manager commands, global Tree-sitter CLI, submodules,
  repo-wide provider execution, cache, LSP, package/workspace analysis, module
  resolution, tsconfig analysis, type checking, or Node runtime support.
- Real-repo close-out smoke may use the approved sibling repo only under the
  durable label `sibling-local-repo`; no raw private output or absolute private
  paths may be committed.

## Non-goals

- No default provider execution.
- No scoring or ranking changes.
- No symbol line-history for TypeScript/TSX.
- No Node provider identity, package/workspace/module analysis, tsconfig
  analysis, type checking, or LSP.
- No custom query execution, cache, package, release, network, telemetry,
  upload, or remote enrichment.
