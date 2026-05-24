# Feature 0046: Inspect-only Python symbol output

## Problem

Python grammar source import, offline build proof, query contract, and internal
Python symbol extraction proof are complete. The CLI still exposes Tree-sitter
symbols only for inspected Zig and Go files. Users inspecting a hot Python file
cannot yet see current Python symbols in that file.

## Outcome

Expose a narrow, opt-in Python symbol provider through the existing inspect-only
symbol flow:

```sh
git-hotspots --inspect path.py --symbols
```

The feature must reuse the existing `symbols` output envelope and preserve
file-level Git evidence as product truth. Python symbols are current
working-tree symbols only. They must not affect file score, file rank, file
confidence, rename lineage, co-change evidence, scope filtering, or default
analysis.

## Requirements

### Runtime and build safety

- Add a reusable runtime Python extraction module, expected as
  `src/tree_sitter_python.zig` or equivalent.
- The runtime module must own allocated symbol data and support
  deinitialisation with ownership parity to the existing Zig and Go symbol
  providers.
- The runtime module must validate repo-relative paths before reading files.
- The runtime module must parse only regular bounded current working-tree `.py`
  files.
- Non-Python inspect targets requested with `--symbols` must preserve existing
  unsupported/degraded provider behaviour.
- Product build wiring must avoid duplicate Tree-sitter core linkage when Zig,
  Go, and Python providers are available.
- Existing Zig and Go Tree-sitter providers must remain supported and stable.
- Existing proof targets must keep passing:
  - `zig build tree-sitter-build-proof`
  - `zig build tree-sitter-symbol-proof`
  - `zig build tree-sitter-go-build-proof`
  - `zig build tree-sitter-go-symbol-proof`
  - `zig build tree-sitter-python-build-proof`
  - `zig build tree-sitter-python-symbol-proof`

### CLI surface

- `--symbols` remains valid only with `--inspect PATH`.
- `git-hotspots --inspect path.py --symbols` must dispatch by the resolved
  inspected matched path extension.
- Provider execution must stay inspect-only and must parse only the matched
  inspected file.
- No provider execution may happen for default reports or non-symbol inspect
  reports.
- No new flags are added in this feature.
- `--symbol-line-history` for Python is out of scope. If combined with a Python
  inspect target, behaviour must not claim Python symbol history or lineage. It
  may reject the combination clearly or degrade with explicit current-line
  evidence caveats only if fully validated.

### Python supported subset

The initial runtime subset follows Feature 0045:

- module file evidence maps to `module` when deterministic;
- top-level classes map to `type`;
- top-level functions map to `function`;
- methods inside classes map to `method`;
- simple module-level constants and assignments map to the chosen existing
  provider kind with caveats;
- decorators and nested definitions follow the query contract's caveat rules.

The provider must not evaluate Python packages, imports, virtual environments,
`pyproject.toml`, dependency graphs, notebooks, type checking, dynamic
assignments, custom queries, or LSP data.

### Ranges and ordering

- Symbol ranges must use deterministic one-based inclusive line ranges from the
  selected declaration node.
- Decorator and nested-definition handling must match the Feature 0044 query
  contract and Feature 0045 extraction proof.
- Symbol ordering must be deterministic and pinned in tests.
- Human outputs may use the existing human symbol display limit and sorting
  semantics, but JSON `symbols.items` must remain complete and deterministic.

### Output contract

- JSON must reuse the existing `symbols` envelope.
- JSON provider metadata for Python must identify the provider as Tree-sitter
  Python and include provider version, contract version, current-only state,
  freshness, failure, confidence, caveats, and local provenance for the matched
  path.
- Table output must not say `current Zig symbols` or `current Go symbols` for
  Python files.
- Table output must print the actual symbol kind instead of hardcoding a kind.
- Markdown output must identify the Python provider state, caveats, counts,
  kinds, and line ranges.
- Human outputs must state that symbols do not change score, rank, lineage,
  confidence, scope, co-change evidence, or file-level Git truth.
- Existing no-provider outputs must remain byte-stable.
- Existing Zig and Go `--symbols` outputs must remain byte-stable except for
  explicitly planned language-neutral wording that does not alter schema or
  semantics.

### Documentation

- README, `--help`, and `--explain` must acknowledge that inspect-only
  Tree-sitter symbols support Zig, Go, and Python.
- Docs must state that Python support is current working-tree symbol enrichment
  only.
- Docs must not claim Python symbol history, package analysis, dependency
  analysis, import resolution, virtualenv discovery, notebook handling,
  type-checking, or repo-wide provider scanning.

## Edge cases

- Unsupported extension with `--symbols` returns visible provider unsupported or
  existing clear behaviour without raw diagnostics.
- Empty Python file returns provider `ok` with zero symbols or a deterministic
  module-only result according to the approved contract.
- Invalid or partial Python returns deterministic failure or caveated partial
  output without raw parser diagnostics or source snippets.
- Missing current file, symlink/non-regular file, and too-large file degrade as
  unavailable.
- Python files with generated markers, decorators, nested definitions, dynamic
  assignments, Unicode identifiers, and Markdown-sensitive names/paths are
  handled deterministically and escaped in human outputs.
- Rename-alias inspect must parse the resolved matched path, not the requested
  alias.
- A fixture with two Python files must prove inspect-only behaviour: the
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
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-repo> -Dsmoke-label=sibling-local-repo
```

Additional validation expectations:

- Python symbol success goldens for JSON, Markdown, and table output.
- Explicit `--symbol-limit` human-output coverage for Python when applicable.
- Semantic JSON checks proving `symbols.items` remains complete under human
  limits.
- Unsupported, empty, invalid, unavailable, symlink/non-regular, too-large,
  generated, decorator, nested-definition, dynamic-assignment, rename-alias,
  and two-Python-file cases.
- Repeated-output determinism for Python symbol JSON, Markdown, and table
  outputs.
- Existing no-provider, Zig symbol, and Go symbol goldens remain stable.
- Privacy and prohibited-claim scans include new Python symbol outputs,
  fixtures, docs, and validation summaries.
- Runtime/dependency scans prove no network, telemetry, upload, fetch, parser
  generation, package-manager Python commands, global Tree-sitter CLI,
  submodules, repo-wide provider execution, cache, LSP, import resolution,
  virtualenv discovery, notebook handling, or dependency graph analysis.
- Real-repo close-out smoke may use the approved sibling repo only under the
  durable label `sibling-local-repo`; no raw private output or absolute private
  paths may be committed.

## Non-goals

- No Python line-history support in this feature.
- No symbol scoring or ranking.
- No symbol lineage or historical function tracking.
- No repo-wide provider scan.
- No package/module loading, import resolution, virtualenv discovery,
  `pyproject.toml` parsing, notebook handling, dependency graph, LSP, custom
  query execution, cache, network, telemetry, parser generation, release
  automation, or package publishing.
