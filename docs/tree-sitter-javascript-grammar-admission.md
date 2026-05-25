# Tree-sitter JavaScript grammar admission review

This is a documentation-only admission review for a possible future
Tree-sitter JavaScript grammar import. It records the gates that must pass before
any JavaScript parser source, generated parser source, scanner source, build
graph, runtime provider, provider registry, CLI flag, report schema, scoring,
cache, fixture, CI, release, package, network, telemetry, upload, remote
enrichment, or background provider behaviour changes are made.

JavaScript runtime support is not implemented by this feature. Current runtime
Tree-sitter support remains Zig, Go, and Python only. File-level Git-history
evidence remains the product truth. Any future JavaScript symbol evidence must
be optional, inspect-oriented, current-only, additive, caveated provider
evidence used to explain local evidence, not to predict defects, score code
quality, rank people, or judge maintainers.

## Scope and preserved boundaries

This review adds only this document. It does not import
`tree-sitter-javascript` source, add fixtures, change tests, update `build.zig`,
add `build.zig.zon`, change validation scripts, wire provider runtime
behaviour, add a registry entry, alter CLI options, change report schemas,
change scoring, change cache behaviour, or add CI, release, package, network,
telemetry, upload, remote enrichment, or background provider behaviour.

A later JavaScript source-import feature must keep the same local-first boundary
unless that later feature explicitly shapes and validates a narrower exception.
No build step may fetch source, use `npm` or another package manager, use
submodules, call a global parser package, upload data, use telemetry, perform
remote enrichment, or run a provider in the background.

## Candidate identity and import target

| Field | Admission state |
| --- | --- |
| Grammar candidate | Public upstream candidate: `https://github.com/tree-sitter/tree-sitter-javascript`. |
| Immutable revision | Not selected in this feature. A later import must select an immutable tag or full commit before source is copied. |
| Checksum requirement | Blocked until the later import records the selected source archive or checkout identity and a SHA-256 checksum where an archive is used. |
| Proposed vendored path | `third_party/tree-sitter-javascript/<revision>/`. |
| Import state | Conditional. The candidate identity is plausible, but source import is blocked until the named gates in this document pass. |

If the upstream identity changes or cannot be selected during the later import,
that feature must record `blocked` with the specific reason instead of guessing
or importing an unreviewed grammar.

No immutable revision, checksum, license, or notice conclusion in this document
authorises source import by itself. Each conclusion must be refreshed against
the exact selected revision in the later import feature.

## JavaScript and JSX path decision

Future JavaScript provider work must remain inspect-path-only and
extension-based. After a separate runtime feature exists, requested inspect paths
ending in `.js`, `.mjs`, `.cjs`, or `.jsx` may be considered JavaScript
candidates because of those path extensions.

Decision: `.jsx` is admitted with JavaScript for the next JavaScript grammar
source-import plan, not as a separate language and not as Node support. `.jsx`
remains unsupported at runtime until a later shaped feature imports the selected
grammar, proves JSX parsing for that exact revision, adds JSX fixture coverage,
and wires provider behaviour deliberately. If that later evidence cannot prove
JSX support with local inputs, the later feature must split or defer `.jsx` and
keep it unsupported.

## Tree-sitter core compatibility gate

Tree-sitter core is already vendored for current Tree-sitter provider work under
`third_party/tree-sitter-core/v0.26.9`. Existing core admission evidence records
`TREE_SITTER_LANGUAGE_VERSION` as `15` and the minimum compatible language
version as `13` for that vendored core.

A future JavaScript import must prove that the selected JavaScript grammar is
compatible with the existing vendored core ABI and language-version range before
any parser runtime or provider behaviour is added. If the selected grammar
requires a newer Tree-sitter core, the import must either include an explicitly
approved core-update scope or stop for a separate shaped core-update feature.

A Tree-sitter core update is not authorised by this admission review. It
requires a separate shaped feature unless a later JavaScript import feature
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

The later import must represent generated JavaScript parser provenance honestly.
Before closing, it must do one of the following:

1. reproduce generated parser files from pinned grammar inputs and an exact
   Tree-sitter generator version using local inputs only; or
2. verify generated files against a pinned upstream artefact and record why
   accepting that artefact is reviewable and deterministic.

The future evidence must name the generated files, grammar inputs, generator or
upstream artefact basis, selected revision, and known limitations. If this
cannot be reproduced, verified, or justified, generated parser provenance is a
blocker and JavaScript source import must not close.

The later import must also prove the external scanner state for the exact
selected revision. If the grammar contains `src/scanner.c`, `src/scanner.cc`, or
another required scanner source, the import must include that source in the BOM,
record its upstream identity and checksum basis, and validate that it compiles
with local repository inputs only. If no external scanner is present or needed,
the import must record the inspected paths or upstream metadata that prove that
absence. Scanner assumptions are blockers until proved against the selected
revision.

## Bill-of-materials expectations

A future JavaScript import must use a narrow, auditable file set. The expected
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
  ecosystems unless explicitly shaped later;
- package.json, workspace, bundler, dependency graph, and module-resolution
  analysis artefacts; and
- custom user queries, global parser packages, and runtime registry wiring.

The future import must record the final BOM and excluded file classes in a
repo-relative provenance artefact. If the file set cannot be kept narrow and
reviewable, source import remains blocked.

## Local-first build supply-chain gate

A future JavaScript import must prove that validation uses only
repository-local inputs. It must not fetch source at build time, require `npm` or
another package manager, require a global Tree-sitter CLI, use submodules, use
system Tree-sitter packages, call a remote parser service, upload source, emit
telemetry, or perform remote enrichment.

Any parser generation or verification step must be either committed as evidence
from local pinned inputs or explicitly treated as a separate proof step. Normal
no-provider builds and reports must remain deterministic when JavaScript
provider work is not requested.

## Source-size and build-impact gate

Before a later JavaScript source import can close, it must measure and record:

- bytes added under `third_party/tree-sitter-javascript/<revision>/`;
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

JavaScript query support is not admitted by this document. A later runtime
feature may add project-owned built-in JavaScript symbol queries only after the
source-import gates pass.

The first JavaScript query contract should focus on stable inspect-oriented
symbols: functions, classes, methods, constants, variables, exported values,
CommonJS exports, and JSX component definitions when JSX evidence is admitted.
It must define accepted capture names, symbol-kind mapping, range semantics,
deterministic ordering, query version metadata, provider version metadata, and
caveats for unsupported or ambiguous constructs.

Fixture coverage for future JavaScript work must include at least:

- `.js`, `.mjs`, and `.cjs` path examples;
- `.jsx` path examples because JSX is admitted only with fixture proof;
- top-level functions and function expressions;
- classes and methods;
- constants and variables;
- ESM named exports, default exports, and re-exports;
- CommonJS `module.exports` and `exports.*` patterns;
- anonymous exports that should be named, caveated, or skipped
  deterministically;
- JSX components, fragments, and expression-heavy examples;
- generated or minified bundles that should be caveated or skipped
  deterministically;
- empty files;
- invalid or partial files;
- unsupported paths and skipped-provider states; and
- monorepo-style project-relative paths.

Built-in queries must not be blind imports of upstream highlight queries.
Custom user query execution is deferred to a separate safety-contract feature.
If JavaScript cannot be useful without custom user queries, the next step is a
custom query safety feature, not an expansion of this admission review.

## Monorepo, path, and Node context behaviour

Future JavaScript provider behaviour must remain inspect-path-only and
extension-based. A requested path ending in `.js`, `.mjs`, `.cjs`, or `.jsx` may
be considered a JavaScript candidate because of that path extension after a
JavaScript runtime feature exists; this admission review does not implement that
behaviour.

Monorepo behaviour must not imply `package.json` parsing, workspace discovery,
bundler analysis, dependency graph inference, module resolution, LSP, Node
provider identity, or repo-wide scanning. It must not inspect sibling packages
or a whole monorepo unless a later feature explicitly shapes and validates that
behaviour. Ambiguous or unsupported paths should fail closed with a visible
caveat while preserving file-level Git evidence.

Node is runtime context only. Future documentation may explain that a requested
JavaScript path is often run by Node, but Node is not a parser identity, not a
provider name, not a separate language id, and not a reason to parse package or
workspace metadata.

## No-provider and provider-boundary gates

Normal table, JSON, Markdown, and inspect outputs must remain byte-stable when
JavaScript provider output is not requested. File-level Git evidence remains the
product truth regardless of provider state.

Future JavaScript provider evidence, if implemented, must be:

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

Future JavaScript support must not be described as implemented until a separate
runtime feature imports sources, proves offline build behaviour, adds a reviewed
query contract, validates fixtures, preserves no-provider output, and wires the
provider deliberately.

## Explicit deferrals

This admission review explicitly defers all of the following:

- JavaScript source import;
- JavaScript offline build proof;
- JavaScript extraction proof;
- inspect-only JavaScript symbol output;
- custom user query execution;
- LSP integration;
- provider registry changes;
- CLI and report schema changes;
- package.json, workspace, bundler, dependency graph, module resolution, and
  repo-wide scanning;
- Node provider identity;
- scoring and cache changes; and
- release or package work.

LSP is a separate provider class and must not be used to justify admitting a
Tree-sitter grammar. JavaScript package-manager, workspace, module, bundler, or
Node runtime analysis is also out of scope; future language detection should
stay path-based for the requested inspect path unless a later feature shapes
something narrower.

## Future sequencing

Future JavaScript work must proceed in this order unless a later shaped feature
narrows the plan:

1. Select an immutable `tree-sitter-javascript` revision and record source
   identity plus checksum evidence.
2. Verify license, notice, generated parser provenance, and scanner provenance
   for that exact revision.
3. Record the narrow BOM and excluded file classes before copying source.
4. Prove compatibility with the existing vendored Tree-sitter core ABI and
   language-version range, or shape a separate core-update feature.
5. Measure source size, build impact, offline validation, and no-provider output
   stability using local inputs only.
6. Design and validate a project-owned JavaScript query contract with fixtures,
   including JSX fixtures while `.jsx` remains admitted with JavaScript.
7. Only then add runtime provider behaviour in a separate reviewed feature.

## Decision state

Decision state: `conditionaljavascript`.

The public upstream candidate is plausible for a later JavaScript source-import
feature, but this feature does not make the candidate ready for import and does
not implement JavaScript runtime support. A future source-import feature may
proceed only after it resolves or records the blockers below.

Named blockers for a later JavaScript source-import feature:

1. Select an immutable `tree-sitter-javascript` revision and record the source
   identity and checksum requirement.
2. Verify license and notice obligations at that selected revision.
3. Reproduce, verify, or explicitly justify generated parser provenance.
4. Prove external scanner presence or absence for the selected revision and
   include any required scanner source in the BOM.
5. Define the exact BOM and excluded file classes for
   `third_party/tree-sitter-javascript/<revision>/`.
6. Prove compatibility with the existing vendored Tree-sitter core ABI and
   language-version range, or shape a separate core-update feature.
7. Measure source-size and build-impact evidence using local inputs only.
8. Prove offline validation and no-provider output stability.
9. Design and validate a project-owned JavaScript symbol query contract with
   fixtures for functions, classes, methods, constants, variables, ESM exports,
   CommonJS exports, anonymous exports, JSX, generated bundles, empty files,
   invalid files, unsupported paths, and monorepo paths.
10. Preserve inspect-path-only, extension-based monorepo behaviour without
    package.json, workspace, bundler, dependency graph, module resolution, LSP,
    Node provider identity, or repo-wide scanning claims.
11. Preserve local-first behaviour, privacy-safe diagnostics, and file-level Git
    evidence as product truth.

If any blocker remains unresolved in the future import, keep the state at
`conditionaljavascript` or move it to `blocked`; do not claim JavaScript runtime
support.
