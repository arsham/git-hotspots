# Tree-sitter Python query contract and fixtures

This is a non-product, test-only contract for a future Python Tree-sitter symbol
provider. It adds a project-owned query asset, fixture corpus, and proof target
without exposing Python symbols through the CLI, reports, provider registry,
scoring, cache, or runtime defaults.

## Scope and protected surfaces

Changed implementation surfaces are limited to:

- `tests/fixtures/tree_sitter_python_query/python-symbols.scm`: the
  project-owned Python symbol candidate query.
- `tests/fixtures/tree_sitter_python_query/*.py` and
  `tests/fixtures/tree_sitter_python_query/unsupported.md`: local proof
  fixtures.
- `tests/tree_sitter_python_query_proof.zig`: test-only query contract proof.
- `build.zig`: the explicit `tree-sitter-python-query-proof` build step.
- `docs/tree-sitter-python-query-contract.md`: this evidence record.

The contract does not change `src/`, fixture expected product outputs, CLI
flags, report schemas, scoring, cache behavior, provider registration, runtime
Python symbol output, CI/release/package behavior, LSP behavior, network access,
telemetry, uploads, remote enrichment, parser generation, system package use, or
custom user query execution.

## Query identity

| Field | Value |
| --- | --- |
| Query version | `python-symbol-query-v1` |
| Provider proof name | `tree-sitter-python-query-proof` |
| Grammar input | vendored `third_party/tree-sitter-python/v0.25.0` |
| Query asset | `tests/fixtures/tree_sitter_python_query/python-symbols.scm` |
| Proof command | `zig build tree-sitter-python-query-proof` |

The query is project-owned. It is not an upstream highlight, tags, or user query
import.

## Capture contract

The supported capture names are:

| Capture | Meaning |
| --- | --- |
| `@python.module` | Python module root candidate. |
| `@python.class.definition` | Class definition node. |
| `@python.function.definition` | Function definition node. |
| `@python.assignment.definition` | Simple assignment node. |
| `@python.definition.name` | Identifier paired with a class, function, or assignment definition. |
| `@python.decorator` | Decorator node used to prove decorator coverage and decorated range handling. |

Future runtime work must stop for planning if it needs new capture names,
custom user queries, imports/package discovery, notebooks, virtual environments,
LSP, or dependency resolution.

## Symbol-kind and range mapping

The proof maps query candidates into the existing
`provider.CurrentSymbolEvidence` shape only inside tests:

| Query candidate | Proof mapping |
| --- | --- |
| Module root | `SymbolKind.module`; symbol name is the repo-relative `.py` path. |
| Class definition | `SymbolKind.class`; symbol name is the captured identifier. |
| Function definition in a direct class body | `SymbolKind.method`; method names are bare identifiers. |
| Other function definition | `SymbolKind.function`; nested functions use bare names. |
| Module-level uppercase simple assignment | `SymbolKind.other`, because there is no constant-specific kind. |
| Other module-level simple assignment | `SymbolKind.variable`. |

Ranges are one-based inclusive line ranges from the symbol definition node.
Decorated class and function ranges use the enclosing `decorated_definition` so
that decorators are included. The module range is the Tree-sitter module node
range. Ordering is deterministic source order by symbol node start byte, with
the module symbol first.

## Supported and caveated subset

The proof-covered subset includes modules, empty modules, top-level classes,
top-level functions, direct class-body methods, module-level simple assignments,
constant-like uppercase assignments, decorators, nested classes/functions,
Unicode identifiers, generated-file markers, invalid/partial files,
unsupported paths, and Markdown-sensitive fixture text.

The contract intentionally excludes tuple/list destructuring, dynamic
assignments, imports as symbols, qualified name construction, package discovery,
virtual environments, dependency graphs, notebooks, generated-source policy,
parser diagnostics, source snippets in failures, LSP data, lineage, ownership,
people metrics, scoring, and bug prediction.

Unsupported non-`.py` paths return `unsupported` without parsing. Unsafe paths
are rejected before parsing. Invalid or partial Python source returns `failed`
with caveats only; raw parser diagnostics and source snippets are not exposed.
Generated-file markers are caveated only and do not change scoring or runtime
behavior.

## Fixture corpus

| Fixture | Coverage |
| --- | --- |
| `tests/fixtures/tree_sitter_python_query/supported_subset.py` | Module, constants, variables, ignored tuple/dynamic/local assignments, decorators, top-level and nested functions/classes, direct class-body method, Unicode identifier, Markdown-sensitive docstring text. |
| `tests/fixtures/tree_sitter_python_query/generated.py` | Generated marker, module-level constant, and function with generated caveat. |
| `tests/fixtures/tree_sitter_python_query/invalid_partial.py` | Invalid/partial Python failure without diagnostics or snippets. |
| `tests/fixtures/tree_sitter_python_query/empty.py` | Empty module symbol only. |
| `tests/fixtures/tree_sitter_python_query/unsupported.md` | Unsupported path that contains Python-looking Markdown but is not parsed. |

All fixture paths are project-relative. No private paths, raw private reports,
remote URLs, authors, email addresses, commit messages, or source from sibling
repositories are recorded.

## Validation evidence

Fresh local validation on 2026-05-24:

| Command | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `zig build tree-sitter-python-query-proof` | `0` | Query compiled, expected capture names were present, and all local fixtures passed. |
| `zig build tree-sitter-python-build-proof` | `0` | Existing Python parser/scanner build proof still compiled, linked, and ran. |
| `zig build validate` | `0` | Product validation passed without Python runtime provider output. |
| `git diff --check` | `0` | No whitespace errors were reported. |

The proof uses only repository-local vendored Tree-sitter core and Python parser
sources plus local fixtures. It performs no network access, package-manager
resolution, parser generation, telemetry, upload, remote enrichment, background
analysis, or provider runtime registration.
