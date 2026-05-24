# Tree-sitter Go grammar admission review

This is a documentation-only admission review for a possible future
Tree-sitter Go grammar import. It records the gates that must pass before any
Go parser source, generated parser source, build graph, runtime provider,
provider registry, CLI flag, report schema, scoring, cache, fixture, CI,
release, package, network, telemetry, upload, remote enrichment, or background
provider behaviour changes are made.

Go runtime support is not implemented by this feature. Current runtime
Tree-sitter support remains Zig-only. File-level Git-history evidence remains
the product truth. Any future Go symbol evidence must be optional,
inspect-oriented, current-only, additive, caveated provider evidence used to
explain local evidence, not to predict defects, score code quality, rank
people, or judge maintainers.

## Scope and preserved boundaries

This review adds only this document. It does not import
`tree-sitter-go` source, add fixtures, change tests, update `build.zig`, add
`build.zig.zon`, change validation scripts, wire provider runtime behaviour,
add a registry entry, alter CLI options, change report schemas, change scoring,
change cache behaviour, or add CI, release, package, or network behaviour.

A later Go source-import feature must keep the same local-first boundary unless
that later feature explicitly shapes and validates a narrower exception. No
build step may fetch source, use package-manager resolution, use submodules,
call a global parser package, upload data, use telemetry, perform remote
enrichment, or run a provider in the background.

## Candidate identity and import target

| Field | Admission state |
| --- | --- |
| Grammar candidate | Public upstream candidate: `https://github.com/tree-sitter/tree-sitter-go`. |
| Immutable revision | Not selected in this feature. A later import must select an immutable tag or full commit before source is copied. |
| Checksum requirement | Blocked until the later import records the selected source archive or checkout identity and a SHA-256 checksum where an archive is used. |
| Proposed vendored path | `third_party/tree-sitter-go/<revision>/`. |
| Import state | Conditional. The candidate identity is plausible, but source import is blocked until the named gates in this document pass. |

If the upstream identity changes or cannot be selected during the later import,
that feature must record `blocked` with the specific reason instead of guessing
or importing an unreviewed grammar.

## Tree-sitter core compatibility gate

Tree-sitter core is already vendored and proven for the current Zig provider
path under `third_party/tree-sitter-core/v0.26.9`. The current core review
records `TREE_SITTER_LANGUAGE_VERSION` as `15` and the minimum compatible
language version as `13` for that vendored core.

A future Go import must prove that the selected Go grammar is compatible with
the existing vendored core ABI and language-version range before any parser
runtime or provider behaviour is added. If the selected grammar requires a
newer Tree-sitter core, the import must either include an explicitly approved
core-update scope or stop for a separate shaped core-update feature.

A Tree-sitter core update is not authorised by this admission review. It
requires a separate shaped feature unless a later Go import feature explicitly
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

## Generated parser provenance gate

The later import must represent generated Go parser provenance honestly. Before
closing, it must do one of the following:

1. reproduce the generated parser files from pinned grammar inputs and an exact
   Tree-sitter generator version using local inputs only; or
2. verify the generated files against a pinned upstream artefact and record why
   accepting that artefact is reviewable and deterministic.

The future evidence must name the generated files, grammar inputs, generator or
upstream artefact basis, selected revision, and known limitations. If this
cannot be reproduced, verified, or justified, generated parser provenance is a
blocker and Go source import must not close.

## Bill-of-materials expectations

A future Go import must use a narrow, auditable file set. The expected include
classes are:

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

A future Go import must prove that validation uses only repository-local inputs.
It must not fetch source at build time, require a package manager, require a
global Tree-sitter CLI, use submodules, use system Tree-sitter packages, call a
remote parser service, upload source, emit telemetry, or perform remote
enrichment.

Any parser generation or verification step must be either committed as evidence
from local pinned inputs or explicitly treated as a separate proof step. Normal
no-provider builds and reports must remain deterministic when Go provider work
is not requested.

## Source-size and build-impact gate

Before a later Go source import can close, it must measure and record:

- bytes added under `third_party/tree-sitter-go/<revision>/`;
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

Go query support is not admitted by this document. A later runtime feature may
add project-owned built-in Go symbol queries only after the source-import gates
pass.

The first Go query contract should focus on stable inspect-oriented symbols:
packages, functions, methods, structs, interfaces, constants, variables, and
fields when they can be mapped deterministically. It must define accepted
capture names, symbol-kind mapping, range semantics, deterministic ordering,
query version metadata, provider version metadata, and caveats for unsupported
or ambiguous constructs.

Fixture coverage for future Go work must include at least:

- package declarations;
- top-level functions;
- methods with receivers;
- structs and interfaces;
- constants, variables, and fields;
- generated files;
- build tags;
- cgo-adjacent files;
- empty files;
- invalid or partial files; and
- unsupported or skipped-provider states.

Built-in queries must not be blind imports of upstream highlight queries.
Custom user query execution is deferred to a separate safety-contract feature.
If Go cannot be useful without custom user queries, the next step is a custom
query safety feature, not an expansion of this admission review.

## No-provider and provider-boundary gates

Normal table, JSON, Markdown, and inspect outputs must remain byte-stable when
Go provider output is not requested. File-level Git evidence remains the
product truth regardless of provider state.

Future Go provider evidence, if implemented, must be:

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

Future Go support must not be described as implemented until a separate runtime
feature imports sources, proves offline build behaviour, adds a reviewed query
contract, validates fixtures, preserves no-provider output, and wires the
provider deliberately.

## Explicit deferrals

This admission review explicitly defers all of the following:

- Go source import;
- Go offline build proof;
- Go extraction proof;
- inspect-only Go symbol output;
- custom user query execution;
- LSP integration;
- provider registry changes;
- CLI and report schema changes;
- scoring and cache changes; and
- release or package work.

LSP is a separate provider class and must not be used to justify admitting a
Tree-sitter grammar. Go package-manager or module analysis is also out of scope;
future language detection should stay path-based for the requested inspect path
unless a later feature shapes something narrower.

## Decision state

Decision state: `conditionalgo`.

The public upstream candidate is plausible for a later Go source-import
feature, but this feature does not make the candidate ready for import and does
not implement Go runtime support. A future source-import feature may proceed
only after it resolves or records the blockers below.

Named blockers for a later Go source-import feature:

1. Select an immutable `tree-sitter-go` revision and record the source identity
   and checksum requirement.
2. Verify license and notice obligations at that selected revision.
3. Reproduce, verify, or explicitly justify generated parser provenance.
4. Define the exact BOM and excluded file classes for
   `third_party/tree-sitter-go/<revision>/`.
5. Prove compatibility with the existing vendored Tree-sitter core ABI and
   language-version range, or shape a separate core-update feature.
6. Measure source-size and build-impact evidence using local inputs only.
7. Prove offline validation and no-provider output stability.
8. Design and validate a project-owned Go symbol query contract with fixtures.
9. Preserve local-first behaviour, privacy-safe diagnostics, and file-level Git
   evidence as product truth.

If any blocker remains unresolved in the future import, keep the state at
`conditionalgo` or move it to `blocked`; do not claim Go runtime support.
