# Tree-sitter Python grammar admission review

This is a documentation-only admission review for a possible future
Tree-sitter Python grammar import. It records the gates that must pass before
any Python parser source, generated parser source, build graph, runtime
provider, provider registry, CLI flag, report schema, scoring, cache, fixture,
CI, release, package, network, telemetry, upload, remote enrichment, or
background provider behaviour changes are made.

Python runtime support is not implemented by this feature. Current runtime
Tree-sitter support remains Zig and Go only. File-level Git evidence remains
the product truth. Any future Python symbol evidence must be optional,
inspect-oriented, current-only, additive, caveated provider evidence used to
explain local evidence, not to predict defects, score code quality, rank
people, or evaluate maintainers.

## Scope and preserved boundaries

This review adds only this document. It does not import
`tree-sitter-python` source, add fixtures, change tests, update `build.zig`, add
`build.zig.zon`, change validation scripts, wire provider runtime behaviour,
add a registry entry, alter CLI options, change report schemas, change scoring,
change cache behaviour, or add CI, release, package, or network behaviour.

A later Python source-import feature must keep the same local-first boundary
unless that later feature explicitly shapes and validates a narrower exception.
No build step may fetch source, use package-manager resolution, use submodules,
call a global parser package, upload data, use telemetry, perform remote
enrichment, or run a provider in the background.

## Candidate identity and import target

| Field | Admission state |
| --- | --- |
| Grammar candidate | Public upstream candidate: `https://github.com/tree-sitter/tree-sitter-python`. |
| Immutable revision | Not selected in this feature. A later import must select an immutable tag or full commit before source is copied. |
| Checksum requirement | Blocked until the later import records the selected source archive or checkout identity and a SHA-256 checksum where an archive is used. |
| Proposed vendored path | `third_party/tree-sitter-python/<revision>/`. |
| Import state | Conditional. The candidate identity is plausible, but source import is blocked until the named gates in this document pass. |

If the upstream identity changes or cannot be selected during the later import,
that feature must record `blocked` with the specific reason instead of guessing
or importing an unreviewed grammar.

## Tree-sitter core compatibility gate

Tree-sitter core is already vendored for current Tree-sitter provider work under
`third_party/tree-sitter-core/v0.26.9`. The existing core review records
`TREE_SITTER_LANGUAGE_VERSION` as `15` and the minimum compatible language
version as `13` for that vendored core.

A future Python import must prove that the selected Python grammar is compatible
with the existing vendored core ABI and language-version range before any parser
runtime or provider behaviour is added. If the selected grammar requires a
newer Tree-sitter core, the import must either include an explicitly approved
core-update scope or stop for a separate shaped core-update feature.

A Tree-sitter core update is not authorised by this admission review. It
requires a separate shaped feature unless a later Python import feature
explicitly includes, validates, and reviews that core update.

## License and notice gate

A later source-import feature must verify license and notice obligations at the
selected immutable revision before copying source. The expected gate is:

- record the upstream license name from the selected revision;
- copy the upstream license text to the vendored component path;
- preserve required copyright and notice text;
- record any notice file in repo-relative terms only;
- avoid private paths, private repository names, person-level review
  attribution, raw parser diagnostics, source snippets, remotes, author
  identities, and raw private reports; and
- stop as `blocked` if the selected revision has unclear or incompatible
  license or notice terms.

No license or notice conclusion in this document authorises source import by
itself. The conclusion must be refreshed against the exact selected revision.

## Generated parser and scanner provenance gates

The later import must represent generated Python parser provenance honestly.
Before closing, it must do one of the following:

1. reproduce generated parser files from pinned grammar inputs and an exact
   Tree-sitter generator version using local inputs only; or
2. verify generated files against a pinned upstream artefact and record why
   accepting that artefact is reviewable and deterministic.

The future evidence must name the generated files, grammar inputs, generator or
upstream artefact basis, selected revision, and known limitations. If this
cannot be reproduced, verified, or justified, generated parser provenance is a
blocker and Python source import must not close.

The later import must also prove the external scanner state for the exact
selected revision. If the grammar contains `src/scanner.c`, `src/scanner.cc`, or
another required scanner source, the import must include that source in the BOM,
record its upstream identity and checksum basis, and validate that it compiles
with local repository inputs only. If no external scanner is present or needed,
the import must record the inspected paths or upstream metadata that prove that
absence. Scanner assumptions are blockers until proved against the selected
revision.

## Bill-of-materials expectations

A future Python import must use a narrow, auditable file set. The expected
include classes are:

- upstream license and notice files;
- grammar metadata such as `tree-sitter.json` when present;
- grammar source files needed to review parser generation;
- generated C parser files and any required scanner files;
- node type metadata needed for query design; and
- project-owned query files only after their symbol contract is reviewed.

The expected excluded classes are:

- package-manager lockfiles and install metadata not needed for local source
  review;
- prebuilt binaries, wasm artefacts, and release bundles not selected as source
  evidence;
- editor, playground, benchmark, and example files unless a later import
  explains why a specific file is necessary;
- CI, release, packaging, and publishing configuration;
- language bindings or wrappers for Node, Python, Rust, Go, Swift, or other
  ecosystems unless explicitly shaped later; and
- custom user queries, global parser packages, and runtime registry wiring.

The future import must record the final BOM and excluded file classes in a
repo-relative provenance artefact. If the file set cannot be kept narrow and
reviewable, source import remains blocked.

## Local-first build supply-chain gate

A future Python import must prove that validation uses only repository-local
inputs. It must not fetch source at build time, require a package manager,
require a global Tree-sitter CLI, use submodules, use system Tree-sitter
packages, call a remote parser service, upload source, emit telemetry, or
perform remote enrichment.

Any parser generation or verification step must be either committed as evidence
from local pinned inputs or explicitly treated as a separate proof step. Normal
no-provider builds and reports must remain deterministic when Python provider
work is not requested.

## Source-size and build-impact gate

Before a later Python source import can close, it must measure and record:

- bytes added under `third_party/tree-sitter-python/<revision>/`;
- largest imported files and their byte sizes;
- repository working-tree size before and after import, excluding transient
  build and Git directories;
- `zig build validate` before and after import;
- compile-time impact if C compilation changes; and
- byte-stable table, JSON, Markdown, and inspect no-provider outputs.

Planner review is required if a generated parser or scanner is unexpectedly
large, if total vendored source size makes source install materially worse, if
normal validation slows enough to affect source-install experience, or if any
measurement requires non-local inputs.

## Query and fixture gates

Python query support is not admitted by this document. A later runtime feature
may add project-owned built-in Python symbol queries only after the source-import
gates pass.

The first Python query contract should focus on stable inspect-oriented symbols:
modules, classes, functions, methods, constants, decorators when they affect
symbol meaning, and nested definitions when they can be mapped deterministically.
It must define accepted capture names, symbol-kind mapping, range semantics,
deterministic ordering, query version metadata, provider version metadata, and
caveats for unsupported or ambiguous constructs.

Fixture coverage for future Python work must include at least:

- module files, including empty modules;
- top-level classes;
- top-level functions;
- methods inside classes;
- constants and simple module-level assignments;
- decorators on classes, functions, and methods;
- nested functions and nested classes;
- indentation errors and partial indentation states;
- dynamic assignments that should be caveated or ignored deterministically;
- generated files;
- empty files;
- invalid or partial files; and
- unsupported paths and skipped-provider states.

Built-in queries must not be blind imports of upstream highlight queries.
Custom user query execution is deferred to a separate safety-contract feature.
If Python cannot be useful without custom user queries, the next step is a
custom query safety feature, not an expansion of this admission review.

## Monorepo and Python path behaviour

Future Python provider behaviour must remain inspect-path-only and
extension-based. A requested path ending in `.py` may be considered a Python
candidate because of that path extension after a Python runtime feature exists;
this admission review does not implement that behaviour.

Future Python provider work must not imply package discovery, virtual
environment discovery, workspace analysis, `pyproject.toml` parsing, dependency
graph inference, import resolution, namespace package handling, notebook
handling, or repo-wide scanning. It must not inspect sibling packages or a whole
monorepo unless a later feature explicitly shapes and validates that behaviour.
Ambiguous or unsupported paths should fail closed with a visible caveat while
preserving file-level Git evidence.

## No-provider and provider-boundary gates

Normal table, JSON, Markdown, and inspect outputs must remain byte-stable when
Python provider output is not requested. File-level Git evidence remains the
product truth regardless of provider state.

Future Python provider evidence, if implemented, must be:

- opt-in and inspect-oriented;
- current working-tree evidence only;
- additive to file-level Git evidence;
- caveated when parsing is unavailable, unsupported, partial, failed, timed
  out, empty, or skipped;
- deterministic for the same repository, ref, path, config, and provider
  version; and
- sanitized so diagnostics do not expose absolute paths, private repository
  details, source snippets, remotes, authors, raw parser stderr, or raw private
  reports.

Future Python support must not be described as implemented until a separate
runtime feature imports sources, proves offline build behaviour, adds a reviewed
query contract, validates fixtures, preserves no-provider output, and wires the
provider deliberately.

## Explicit deferrals

This admission review explicitly defers all of the following:

- Python source import;
- Python offline build proof;
- Python extraction proof;
- inspect-only Python symbol output;
- custom user query execution;
- LSP integration;
- provider registry changes;
- CLI and report schema changes;
- package, virtual environment, `pyproject.toml`, dependency graph, import
  resolution, and notebook handling;
- scoring and cache changes; and
- release or package work.

LSP is a separate provider class and must not be used to justify admitting a
Tree-sitter grammar. Python package-manager, virtual-environment, module, or
import analysis is also out of scope; future language detection should stay
path-based for the requested inspect path unless a later feature shapes
something narrower.

## Decision state

Decision state: `conditionalpython`.

The public upstream candidate is plausible for a later Python source-import
feature, but this feature does not make the candidate ready for import and does
not implement Python runtime support. A future source-import feature may proceed
only after it resolves or records the blockers below.

Named blockers for a later Python source-import feature:

1. Select an immutable `tree-sitter-python` revision and record the source
   identity and checksum requirement.
2. Verify license and notice obligations at that selected revision.
3. Reproduce, verify, or explicitly justify generated parser provenance.
4. Prove external scanner presence or absence for the selected revision and
   include any required scanner source in the BOM.
5. Define the exact BOM and excluded file classes for
   `third_party/tree-sitter-python/<revision>/`.
6. Prove compatibility with the existing vendored Tree-sitter core ABI and
   language-version range, or shape a separate core-update feature.
7. Measure source-size and build-impact evidence using local inputs only.
8. Prove offline validation and no-provider output stability.
9. Design and validate a project-owned Python symbol query contract with
   fixtures for modules, classes, functions, methods, constants, decorators,
   nested definitions, indentation errors, dynamic assignments, generated files,
   empty files, invalid files, and unsupported paths.
10. Preserve inspect-path-only, extension-based monorepo behaviour without
    package, venv, workspace, `pyproject.toml`, dependency graph, import
    resolution, notebook, or repo-wide scanning claims.
11. Preserve local-first behaviour, privacy-safe diagnostics, and file-level Git
    evidence as product truth.

If any blocker remains unresolved in the future import, keep the state at
`conditionalpython` or move it to `blocked`; do not claim Python runtime
support.
