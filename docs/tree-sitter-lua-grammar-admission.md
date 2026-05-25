# Tree-sitter Lua grammar admission review

This is a documentation-only admission review for a possible future
Tree-sitter Lua grammar import. It records the gates that must pass before any
Lua parser source, generated parser source, scanner source, build graph,
runtime provider, provider registry, CLI flag, report schema, scoring, cache,
fixture, CI, release, package, network, telemetry, upload, remote enrichment,
or background provider behaviour changes are made.

Lua runtime support is not implemented by this feature. Current runtime
Tree-sitter support remains limited to already implemented inspect-only
languages. File-level Git-history evidence remains the product truth. Any
future Lua symbol evidence must be optional, inspect-oriented, current-only,
additive, caveated provider evidence used to explain local evidence. It must
not predict defects, score code quality, rank people, judge maintainers, or
evaluate developers.

## Scope and preserved boundaries

This review adds only this document. It does not import `tree-sitter-lua`
source, add fixtures, change tests, update `build.zig`, add `build.zig.zon`,
change validation scripts, wire provider runtime behaviour, add a registry
entry, alter CLI options, change report schemas, change scoring, change cache
behaviour, or add CI, release, package, network, telemetry, upload, remote
enrichment, or background provider behaviour.

A later Lua source-import feature must keep the same local-first boundary
unless that later feature explicitly shapes and validates a narrower exception.
No build step may fetch source, use LuaRocks, parse package manifests, use
package-manager resolution, use submodules, call a global parser package,
upload data, use telemetry, perform remote enrichment, or run a provider in the
background.

## Candidate identity and import target

| Field | Admission state |
| --- | --- |
| Grammar candidate | Public upstream candidate: `https://github.com/tree-sitter-grammars/tree-sitter-lua`. |
| Immutable revision | Not selected in this feature. A later import must select an immutable tag or full commit before source is copied. |
| Checksum requirement | Blocked until the later import records the selected source archive or checkout identity and a SHA-256 checksum where an archive is used. |
| Proposed vendored path | `third_party/tree-sitter-lua/<revision>/`. |
| Import state | Conditional. The candidate identity is plausible, but source import is blocked until the named gates in this document pass. |

If the upstream identity changes or cannot be selected during the later import,
that feature must record `blocked` with the specific reason instead of guessing
or importing an unreviewed grammar.

No immutable revision, checksum, license, notice, generated parser, or scanner
conclusion in this document authorises source import by itself. Each conclusion
must be refreshed against the exact selected revision in the later import
feature.

## Lua path decision

Future Lua provider work must remain inspect-path-only and extension-based.
After a separate runtime feature exists, requested inspect paths ending in
`.lua` may be considered Lua candidates because of that path extension. No other
extension, manifest, rockspec, package path, module name, runtime search path,
or dependency graph is admitted by this review.

The `.lua` path rule is intentionally narrow. It does not imply `require`
resolution, module resolution, LuaRocks package discovery, package path
analysis, embedded runtime execution, LSP integration, dependency graph
inference, or repo-wide scanning. Unsupported or ambiguous paths should fail
closed with a visible provider caveat while preserving file-level Git evidence.

## Tree-sitter core compatibility gate

Tree-sitter core is already vendored for current Tree-sitter provider work under
`third_party/tree-sitter-core/v0.26.9`. Existing core admission evidence records
`TREE_SITTER_LANGUAGE_VERSION` as `15` and the minimum compatible language
version as `13` for that vendored core.

A future Lua import must prove that the selected Lua grammar is compatible with
the existing vendored core ABI and language-version range before any parser
runtime or provider behaviour is added. If the selected grammar requires a
newer Tree-sitter core, the import must either include an explicitly approved
core-update scope or stop for a separate shaped core-update feature.

A Tree-sitter core update is not authorised by this admission review. It
requires a separate shaped feature unless a later Lua import feature explicitly
includes, validates, and reviews that core update.

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

The later import must represent generated Lua parser provenance honestly. Before
closing, it must do one of the following:

1. reproduce generated parser files from pinned grammar inputs and an exact
   Tree-sitter generator version using local inputs only; or
2. verify generated files against a pinned upstream artefact and record why
   accepting that artefact is reviewable and deterministic.

The future evidence must name the generated files, grammar inputs, generator or
upstream artefact basis, selected revision, and known limitations. If this
cannot be reproduced, verified, or justified, generated parser provenance is a
blocker and Lua source import must not close.

The later import must also prove the scanner or external scanner state for the
exact selected revision. If the grammar contains `src/scanner.c`,
`src/scanner.cc`, or another required scanner source, the import must include
that source in the BOM, record its upstream identity and checksum basis, and
validate that it compiles with local repository inputs only. If no external
scanner is present or needed, the import must record the inspected paths or
upstream metadata that prove that absence. Scanner assumptions are blockers
until proved against the selected revision.

## Bill-of-materials expectations

A future Lua import must use a narrow, auditable file set. The expected include
classes are:

- upstream license and notice files;
- grammar metadata such as `tree-sitter.json` when present;
- grammar source files needed to review Lua parser generation;
- generated C parser files and any required scanner files;
- node type metadata needed for query design; and
- project-owned query files only after their symbol contract is reviewed.

The expected excluded classes are:

- package-manager lockfiles and install metadata not needed for local source
  review;
- prebuilt binaries, wasm artefacts, and release bundles not selected as source
  evidence;
- editor, playground, benchmark, corpus, and example files unless a later
  import explains why a specific file is necessary;
- CI, release, packaging, and publishing configuration;
- language bindings or wrappers for Node, Python, Rust, Go, Swift, Lua, or
  other ecosystems unless explicitly shaped later;
- rockspec files, LuaRocks metadata, package path metadata, runtime module
  resolution artefacts, and dependency graph analysis artefacts; and
- custom user queries, global parser packages, and runtime registry wiring.

The future import must record the final BOM and excluded file classes in a
repo-relative provenance artefact. If the file set cannot be kept narrow and
reviewable, source import remains blocked.

## Local-first build supply-chain gate

A future Lua import must prove that validation uses only repository-local
inputs. It must not fetch source at build time, require LuaRocks, parse rockspec
metadata, require a global Tree-sitter CLI, use submodules, use system
Tree-sitter packages, call a remote parser service, upload source, emit
telemetry, or perform remote enrichment.

Any parser generation or verification step must be either committed as evidence
from local pinned inputs or explicitly treated as a separate proof step. Normal
no-provider builds and reports must remain deterministic when Lua provider work
is not requested.

## Source-size and build-impact gate

Before a later Lua source import can close, it must measure and record:

- bytes added under `third_party/tree-sitter-lua/<revision>/`;
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

## Lua symbol scope and caveats

Lua query support is not admitted by this document. A later runtime feature may
add project-owned built-in Lua symbol queries only after the source-import gates
pass.

The first Lua query contract should focus on stable inspect-oriented syntax:
local functions, global functions, table-field functions, method definitions
using colon syntax, anonymous functions assigned to stable names, and
module-table patterns only when they can be represented syntactically. It must
define accepted capture names, symbol-kind mapping, range semantics,
deterministic ordering, query version metadata, provider version metadata, and
caveats for unsupported or ambiguous constructs.

Lua has dynamic patterns that can look like symbol evidence but require runtime
or project-specific interpretation for confident meaning. Future Lua symbol
output must caveat or skip constructs deterministically when dynamic table
assignment, metatables, generated Lua, embedded DSLs, dialect-specific syntax,
loader conventions, or module patterns make the symbol meaning ambiguous.

Future Lua work must not claim `require` or module resolution, package path
analysis, runtime execution, dependency graph analysis, LSP-backed
understanding, LuaRocks package understanding, or repo-wide scanning. If a
construct cannot be represented as current-only syntactic inspect evidence, it
should be caveated or omitted rather than promoted to product truth.

## Query and fixture gates

Fixture coverage for future Lua work must include at least:

- `.lua` path examples;
- local function declarations;
- global function declarations;
- table-field function declarations;
- colon-method function declarations;
- anonymous functions assigned to stable local, global, or table-field names;
- module-like tables when represented as syntax rather than runtime meaning;
- comments and strings that look like code and must not emit symbols;
- dynamic table assignment that should be caveated or skipped
  deterministically;
- metatable-heavy examples that should be caveated or skipped
  deterministically;
- generated Lua files;
- embedded DSL examples;
- empty files;
- invalid or partial files;
- unsupported paths and skipped-provider states; and
- monorepo-style project-relative paths.

Built-in queries must not be blind imports of upstream highlight queries.
Custom user query execution is deferred to a separate safety-contract feature.
If Lua cannot be useful without custom user queries, the next step is a custom
query safety feature, not an expansion of this admission review.

## Monorepo and Lua path behaviour

Future Lua provider behaviour must remain inspect-path-only and
extension-based. A requested path ending in `.lua` may be considered a Lua
candidate because of that path extension after a Lua runtime feature exists;
this admission review does not implement that behaviour.

Future Lua provider work must not imply `require` resolution, package path
analysis, LuaRocks package discovery, workspace analysis, dependency graph
inference, runtime execution, LSP integration, or repo-wide scanning. It must
not inspect sibling packages, plugin directories, embedded runtimes, or a whole
monorepo unless a later feature explicitly shapes and validates that behaviour.
Ambiguous or unsupported paths should fail closed with a visible caveat while
preserving file-level Git evidence.

## No-provider and provider-boundary gates

Normal table, JSON, Markdown, and inspect outputs must remain byte-stable when
Lua provider output is not requested. File-level Git evidence remains the
product truth regardless of provider state.

Future Lua provider evidence, if implemented, must be:

- opt-in and inspect-oriented;
- current working-tree evidence only;
- additive to file-level Git evidence;
- caveated when parsing is unavailable, unsupported, partial, failed, timed
  out, empty, ambiguous, or skipped;
- deterministic for the same repository, ref, path, config, and provider
  version; and
- sanitized so diagnostics do not expose absolute paths, private repository
  details, source snippets, remotes, authors, raw parser stderr, or raw private
  reports.

Future Lua support must not be described as implemented until a separate
runtime feature imports sources, proves offline build behaviour, adds a
reviewed query contract, validates fixtures, preserves no-provider output, and
wires provider behaviour deliberately.

## Explicit deferrals

This admission review explicitly defers all of the following:

- Lua source import;
- Lua offline build proof;
- Lua extraction proof;
- inspect-only Lua symbol output;
- custom user query execution;
- `require` or module resolution;
- package path analysis;
- runtime execution;
- LSP integration;
- provider registry changes;
- CLI or report schema changes;
- cache changes;
- scoring changes;
- release or package changes;
- CI changes; and
- network, telemetry, upload, remote enrichment, or background provider
  behaviour.

Each deferred item requires a separate shaped feature or an explicit later
scope that names and validates that work.

## Admission decision and future sequencing

Admission state: conditional documentation admission only. The public candidate
identity is recorded for future review, but source import remains blocked until
a later feature selects an immutable revision, refreshes checksum, license, and
notice evidence, proves generated parser and scanner provenance, proves
Tree-sitter core compatibility, records a narrow BOM, records source-size and
build-impact evidence, and validates Lua query fixtures.

Recommended sequence:

1. select the exact upstream revision and record checksum, license, notice, BOM,
   generated parser, scanner, and core compatibility evidence;
2. import only the admitted local source set under
   `third_party/tree-sitter-lua/<revision>/` with no runtime wiring;
3. prove offline build behaviour from repository-local inputs;
4. add a project-owned Lua query contract and fixtures for the admitted symbol
   subset and caveats; and
5. only then consider inspect-only runtime Lua provider wiring that preserves
   no-provider output stability and local-first behaviour.

This document is not evidence that Lua runtime support exists. It is only a
review checklist and sequencing guardrail for future Lua grammar work.

## Validation checklist for this admission review

This documentation-only admission review is complete only when fresh evidence
shows:

- `git diff --check` passes;
- `zig build validate` passes;
- changed paths are documentation and runner-safe Flow handoff state only;
- no `third_party/tree-sitter-lua` path was added;
- no runtime, source, test, build, fixture, CI, CLI, report schema, scoring,
  cache, provider registry, release, package, network, telemetry, upload,
  remote enrichment, or background behaviour files changed;
- no public claim says Lua support exists;
- prohibited-claim, privacy, and local-first scans over changed documentation
  pass; and
- future import, proof, query, fixture, and runtime sequencing is explicit.
