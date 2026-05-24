# Feature 0039: Inspect-only Go symbol output

## Problem

Go grammar source import, offline build proof, and internal Go symbol extraction
proof are complete. The CLI still exposes Tree-sitter symbols only for inspected
Zig files. Users inspecting a hot Go file cannot yet see current Go symbols in
that file.

## Outcome

Expose a narrow, opt-in Go symbol provider through the existing inspect-only
symbol flow:

```sh
git-hotspots --inspect path.go --symbols
```

The feature must reuse the existing `symbols` output envelope and preserve
file-level Git evidence as product truth. Go symbols are current working-tree
symbols only. They must not affect file score, file rank, file confidence,
rename lineage, co-change evidence, scope filtering, or default analysis.

## Requirements

### Runtime and build safety

- Add a reusable runtime Go extraction module, expected as
  `src/tree_sitter_go.zig` or equivalent.
- The runtime module must own allocated symbol data and support deinitialisation
  with ownership parity to the existing Zig symbol provider.
- The runtime module must validate repo-relative paths before reading files.
- The runtime module must parse only regular bounded current working-tree `.go`
  files.
- Non-Go inspect targets requested with `--symbols` must preserve existing
  unsupported/degraded provider behaviour.
- Product build wiring must avoid duplicate Tree-sitter core linkage when Zig
  and Go providers are both available.
- The existing Zig Tree-sitter provider must remain supported and stable.
- Existing proof targets must keep passing:
  - `zig build tree-sitter-build-proof`
  - `zig build tree-sitter-symbol-proof`
  - `zig build tree-sitter-go-build-proof`
  - `zig build tree-sitter-go-symbol-proof`

### CLI surface

- `--symbols` remains valid only with `--inspect PATH`.
- `git-hotspots --inspect path.go --symbols` must dispatch by the resolved
  inspected matched path extension.
- Provider execution must stay inspect-only and must parse only the matched
  inspected file.
- No provider execution may happen for default reports or non-symbol inspect
  reports.
- No new flags are added in this feature.
- `--symbol-line-history` for Go is out of scope. If combined with a Go inspect
  target, behaviour must not claim Go symbol history or lineage. It may either
  reject the combination clearly or degrade with explicit current-line evidence
  caveats only if fully validated.

### Go supported subset

The initial runtime subset follows Feature 0038:

- package clauses map to `module`;
- top-level function declarations map to `function`;
- method declarations map to `method` with a bare-name caveat;
- top-level struct and interface type specs map to `type` with caveats;
- top-level variable names map to `variable`;
- top-level constant names map to the chosen existing provider kind and must
  carry a caveat. The expected choice is `other` unless implementation evidence
  justifies `variable` without weakening semantics.

The provider must not evaluate Go packages, modules, build tags, cgo, imports,
dependency graphs, generated-file markers, LSP data, or symbol history.

### Ranges and ordering

- Symbol ranges must use deterministic one-based inclusive line ranges from the
  enclosing Go declaration node.
- Grouped const/var names must share the enclosing declaration range.
- Symbol ordering must be deterministic and pinned in tests. Source-order
  traversal is acceptable if it is explicitly documented and stable.
- Human outputs may use the existing human symbol display limit and sorting
  semantics, but JSON `symbols.items` must remain complete and deterministic.

### Output contract

- JSON must reuse the existing `symbols` envelope.
- JSON provider metadata for Go must identify the provider as Tree-sitter Go and
  include provider version, contract version, current-only state, freshness,
  failure, confidence, caveats, and local provenance for the matched path.
- Table output must not say `current Zig symbols` for Go files.
- Table output must print the actual symbol kind instead of hardcoding
  `function` for every symbol row.
- Markdown output must identify the Go provider state, caveats, counts, kinds,
  and line ranges.
- Human outputs must state that symbols do not change score, rank, lineage,
  confidence, scope, co-change evidence, or file-level Git truth.
- Existing no-provider outputs must remain byte-stable.
- Existing Zig `--symbols` outputs must remain byte-stable except for explicitly
  planned language-neutral wording that does not alter schema or semantics.

### Documentation

- README, `--help`, and `--explain` must acknowledge that inspect-only
  Tree-sitter symbols support Zig and Go.
- Docs must state that Go support is current working-tree symbol enrichment only.
- Docs must not claim Go symbol history, package analysis, dependency analysis,
  build-tag evaluation, cgo analysis, or repo-wide provider scanning.

## Edge cases

- Unsupported extension with `--symbols` returns visible provider unsupported or
  existing clear behaviour without raw diagnostics.
- Empty Go file returns provider `ok` with zero symbols.
- Invalid or partial Go returns deterministic failure or caveated partial output
  without raw parser diagnostics or source snippets.
- Missing current file, symlink/non-regular file, and too-large file degrade as
  unavailable.
- Go files with generated markers, `//go:build`, and `import "C"` are parsed
  only as current source and must carry caveats that build tags/generated/cgo are
  not evaluated.
- Rename-alias inspect must parse the resolved matched path, not the requested
  alias.
- A fixture with two Go files must prove inspect-only behaviour: the provider
  parses only the inspected file.
- Unicode Go identifiers and Markdown-sensitive names/paths must be escaped in
  human outputs and valid in JSON.
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
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-repo> -Dsmoke-label=sibling-local-repo
```

Additional validation expectations:

- Go symbol success goldens for JSON, Markdown, and table output.
- Explicit `--symbol-limit` human-output coverage for Go when applicable.
- Semantic JSON checks proving `symbols.items` remains complete under human
  limits.
- Unsupported, empty, invalid, unavailable, symlink/non-regular, too-large,
  generated/build-tag/cgo caveat, rename-alias, and two-Go-file cases.
- Repeated-output determinism for Go symbol JSON, Markdown, and table outputs.
- Existing no-provider and Zig symbol goldens remain stable.
- Privacy and prohibited-claim scans include new Go symbol outputs, fixtures,
  docs, and validation summaries.
- Runtime/dependency scans prove no network, telemetry, upload, fetch, parser
  generation, package-manager Go commands, global Tree-sitter CLI, submodules,
  repo-wide provider execution, cache, LSP, or dependency graph analysis.
- Real-repo close-out smoke may use the approved sibling repo only under the
  durable label `sibling-local-repo`; no raw private output or absolute private
  paths may be committed.

## Non-goals

- No Go line-history support in this feature.
- No symbol scoring or ranking.
- No symbol lineage or historical function tracking.
- No repo-wide provider scan.
- No package/module loading, build-tag evaluation, cgo analysis, dependency
  graph, LSP, custom query execution, cache, network, telemetry, parser
  generation, release automation, or package publishing.
