# Feature 0054: Inspect-only JavaScript symbol output

## Problem

JavaScript grammar source import, offline build proof, query contract, and
internal JavaScript symbol extraction proof are complete. The CLI still exposes
Tree-sitter symbols only for inspected Zig, Go, and Python files. Users
inspecting a hot JavaScript file cannot yet see current JavaScript symbols in
that file.

## Outcome

Expose a narrow, opt-in JavaScript symbol provider through the existing
inspect-only symbol flow:

```sh
git-hotspots --inspect path.js --symbols
```

The feature must reuse the existing `symbols` output envelope and preserve
file-level Git evidence as product truth. JavaScript symbols are current
working-tree symbols only. They must not affect file score, file rank, file
confidence, rename lineage, co-change evidence, scope filtering, default
analysis, package analysis, or Node/module behaviour.

## Requirements

### Runtime and build safety

- Add a reusable runtime JavaScript extraction module, expected as
  `src/tree_sitter_javascript.zig` or equivalent.
- The runtime module must own allocated symbol data and support deinitialisation
  with ownership parity to the existing Zig, Go, and Python symbol providers.
- The runtime module must validate repo-relative paths before reading files.
- The runtime module must parse only regular bounded current working-tree
  `.js`, `.mjs`, `.cjs`, and admitted `.jsx` files.
- If JSX was deferred by earlier features, `.jsx` must remain unsupported with a
  clear provider caveat.
- Non-JavaScript inspect targets requested with `--symbols` must preserve
  existing unsupported/degraded provider behaviour.
- Product build wiring must avoid duplicate Tree-sitter core linkage when Zig,
  Go, Python, and JavaScript providers are available.
- Existing Zig, Go, and Python Tree-sitter providers must remain supported and
  stable.
- Existing proof targets must keep passing:
  - `zig build tree-sitter-build-proof`
  - `zig build tree-sitter-symbol-proof`
  - `zig build tree-sitter-go-build-proof`
  - `zig build tree-sitter-go-symbol-proof`
  - `zig build tree-sitter-python-build-proof`
  - `zig build tree-sitter-python-symbol-proof`
  - `zig build tree-sitter-javascript-build-proof`
  - `zig build tree-sitter-javascript-query-proof`
  - `zig build tree-sitter-javascript-symbol-proof`

### CLI surface

- `--symbols` remains valid only with `--inspect PATH`.
- `git-hotspots --inspect path.js --symbols` must dispatch by the resolved
  inspected matched path extension.
- `.mjs` and `.cjs` paths must follow the same JavaScript provider contract.
- `.jsx` paths are supported only when earlier proof features admitted JSX.
- Provider execution must stay inspect-only and must parse only the matched
  inspected file.
- No provider execution may happen for default reports or non-symbol inspect
  reports.
- No new flags are added in this feature.
- `--symbol-line-history` for JavaScript is out of scope. If combined with a
  JavaScript inspect target, behaviour must not claim JavaScript symbol history
  or lineage. It may reject the combination clearly or degrade with explicit
  current-line evidence caveats only if fully validated.

### JavaScript supported subset

The initial runtime subset follows Feature 0053:

- module or file evidence maps to an existing module/file kind when
  deterministic;
- top-level functions map to `function`;
- function expressions and arrow functions assigned to stable names map to
  `function` or the approved existing kind;
- classes map to `type`;
- methods and supported class fields map to `method` or the approved existing
  kind;
- constants and variables map to the chosen existing provider kind with
  caveats;
- ESM exports and CommonJS exports follow the query/extraction contract;
- JSX component definitions are included only when JSX was admitted and proved.

The provider must not evaluate JavaScript packages, imports, Node runtime,
`package.json`, workspaces, bundlers, module resolution, dependency graphs,
TypeScript, TSX, custom queries, or LSP data.

### Ranges and ordering

- Symbol ranges must use deterministic one-based inclusive line ranges from the
  selected declaration node.
- Export, CommonJS, JSX, anonymous, generated/minified, and class-member handling
  must match the Feature 0052 query contract and Feature 0053 extraction proof.
- Symbol ordering must be deterministic and pinned in tests.
- Human outputs may use the existing human symbol display limit and sorting
  semantics, but JSON `symbols.items` must remain complete and deterministic.

### Output contract

- JSON must reuse the existing `symbols` envelope.
- JSON provider metadata for JavaScript must identify the provider as
  Tree-sitter JavaScript and include provider version, contract version,
  current-only state, freshness, failure, confidence, caveats, and local
  provenance for the matched path.
- Table output must not say `current Zig symbols`, `current Go symbols`, or
  `current Python symbols` for JavaScript files.
- Table output must print the actual symbol kind instead of hardcoding a kind.
- Markdown output must identify the JavaScript provider state, caveats, counts,
  kinds, and line ranges.
- Human outputs must state that symbols do not change score, rank, lineage,
  confidence, scope, co-change evidence, or file-level Git truth.
- Existing no-provider outputs must remain byte-stable.
- Existing Zig, Go, and Python `--symbols` outputs must remain byte-stable
  except for explicitly planned language-neutral wording that does not alter
  schema or semantics.

### Documentation

- README, `--help`, and `--explain` must acknowledge that inspect-only
  Tree-sitter symbols support Zig, Go, Python, and JavaScript.
- Docs must state that JavaScript support is current working-tree symbol
  enrichment only.
- Docs must not claim JavaScript symbol history, package analysis, dependency
  analysis, import/module resolution, Node provider identity, TypeScript/TSX,
  custom query execution, type-checking, or repo-wide provider scanning.

## Edge cases

- Unsupported extension with `--symbols` returns visible provider unsupported or
  existing clear behaviour without raw diagnostics.
- Empty JavaScript file returns provider `ok` with zero symbols or a
  deterministic module-only result according to the approved contract.
- Invalid or partial JavaScript returns deterministic failure or caveated partial
  output without raw parser diagnostics or source snippets.
- Missing current file, symlink/non-regular file, and too-large file degrade as
  unavailable.
- JavaScript files with generated/minified markers, JSX, exports, CommonJS,
  anonymous functions, dynamic constructs, Unicode identifiers, and
  Markdown-sensitive names/paths are handled deterministically and escaped in
  human outputs.
- Rename-alias inspect must parse the resolved matched path, not the requested
  alias.
- A fixture with two JavaScript files must prove inspect-only behaviour: the
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
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-repo> -Dsmoke-label=sibling-local-repo
```

Additional validation expectations:

- JavaScript symbol success goldens for JSON, Markdown, and table output.
- `.js`, `.mjs`, `.cjs`, and admitted `.jsx` coverage.
- Explicit `--symbol-limit` human-output coverage for JavaScript when
  applicable.
- Semantic JSON checks proving `symbols.items` remains complete under human
  limits.
- Unsupported, empty, invalid, unavailable, symlink/non-regular, too-large,
  generated/minified, JSX, exports, CommonJS, anonymous, rename-alias, and
  two-JavaScript-file cases.
- Repeated-output determinism for JavaScript symbol JSON, Markdown, and table
  outputs.
- Existing no-provider, Zig symbol, Go symbol, and Python symbol goldens remain
  stable.
- Privacy and prohibited-claim scans include new JavaScript symbol outputs,
  fixtures, docs, and validation summaries.
- Runtime/dependency scans prove no network, telemetry, upload, fetch, parser
  generation, package-manager commands, global Tree-sitter CLI, submodules,
  repo-wide provider execution, cache, LSP, Node/package/workspace analysis,
  module resolution, TypeScript, or TSX support.
- Real-repo close-out smoke may use the approved sibling repo only under the
  durable label `sibling-local-repo`; no raw private output or absolute private
  paths may be committed.

## Non-goals

- No default provider execution.
- No scoring or ranking changes.
- No symbol line-history for JavaScript.
- No TypeScript or TSX support.
- No Node provider identity or package/workspace/module analysis.
- No custom query execution, LSP, cache, package, release, network, telemetry,
  upload, or remote enrichment.
