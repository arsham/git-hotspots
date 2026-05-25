# Tree-sitter TypeScript grammar admission review

This is a documentation-only admission review for a possible future
Tree-sitter TypeScript grammar import. It records the gates that must pass
before any TypeScript parser source, generated parser source, scanner source,
build graph, runtime provider, provider registry, CLI flag, report schema,
scoring, cache, fixture, CI, release, package, network, telemetry, upload,
remote enrichment, or background provider behaviour changes are made.

TypeScript runtime support is not implemented by this feature. Current runtime
Tree-sitter support remains Zig, Go, and Python only. File-level Git-history
evidence remains the product truth. Any future TypeScript symbol evidence must
be optional, inspect-oriented, current-only, additive, caveated provider
evidence used to explain local evidence, not to predict defects, score code
quality, rank people, or judge maintainers.

## Scope and preserved boundaries

This review adds only this document. It does not import
`tree-sitter-typescript` source, add fixtures, change tests, update
`build.zig`, add `build.zig.zon`, change validation scripts, wire provider
runtime behaviour, add a registry entry, alter CLI options, change report
schemas, change scoring, change cache behaviour, or add CI, release, package,
network, telemetry, upload, remote enrichment, or background provider behaviour.

A later TypeScript source-import feature must keep the same local-first boundary
unless that later feature explicitly shapes and validates a narrower exception.
No build step may fetch source, use `npm`, `pnpm`, `yarn`, `tsc`, another
package manager, submodules, a global parser package, upload data, use
telemetry, perform remote enrichment, or run a provider in the background.

## Candidate identity and import target

| Field | Admission state |
| --- | --- |
| Grammar candidate | Public upstream candidate: `https://github.com/tree-sitter/tree-sitter-typescript`. |
| Immutable revision | Not selected in this feature. A later import must select an immutable tag or full commit before source is copied. |
| Checksum requirement | Blocked until the later import records the selected source archive or checkout identity and a SHA-256 checksum where an archive is used. |
| Proposed vendored path | `third_party/tree-sitter-typescript/<revision>/`. |
| Import state | Conditional. The candidate identity is plausible, but source import is blocked until the named gates in this document pass. |

If the upstream identity changes or cannot be selected during the later import,
that feature must record `blocked` with the specific reason instead of guessing
or importing an unreviewed grammar.

No immutable revision, checksum, license, or notice conclusion in this document
authorises source import by itself. Each conclusion must be refreshed against
the exact selected revision in the later import feature.

## TypeScript and TSX path decision

Future TypeScript provider work must remain inspect-path-only and
extension-based. After a separate runtime feature exists, requested inspect
paths ending in `.ts`, `.mts`, `.cts`, or `.tsx` may be considered TypeScript
candidates because of those path extensions. Declaration files such as `.d.ts`
are TypeScript candidates only through the requested `.ts` path and require
separate fixture evidence before their symbols are trusted.

Decision: `.tsx` is admitted with TypeScript for the next TypeScript grammar
source-import plan, not as a separate language and not as Node support. `.tsx`
remains unsupported at runtime until a later shaped feature imports the selected
grammar, proves TSX parsing for that exact revision, adds TSX fixture coverage,
and wires provider behaviour deliberately. If that later evidence cannot prove
TSX support with local inputs, the later feature must split or defer `.tsx` and
keep it unsupported.

## Tree-sitter core compatibility gate

Tree-sitter core is already vendored for current Tree-sitter provider work under
`third_party/tree-sitter-core/v0.26.9`. Existing core admission evidence records
`TREE_SITTER_LANGUAGE_VERSION` as `15` and the minimum compatible language
version as `13` for that vendored core.

A future TypeScript import must prove that the selected TypeScript and TSX
grammars are compatible with the existing vendored core ABI and
language-version range before any parser runtime or provider behaviour is
added. If the selected grammar requires a newer Tree-sitter core, the import
must either include an explicitly approved core-update scope or stop for a
separate shaped core-update feature.

A Tree-sitter core update is not authorised by this admission review. It
requires a separate shaped feature unless a later TypeScript import feature
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

The later import must represent generated TypeScript and TSX parser provenance
honestly. Before closing, it must do one of the following:

1. reproduce generated parser files from pinned grammar inputs and an exact
   Tree-sitter generator version using local inputs only; or
2. verify generated files against a pinned upstream artefact and record why
   accepting that artefact is reviewable and deterministic.

The future evidence must name the generated TypeScript and TSX files, grammar
inputs, generator or upstream artefact basis, selected revision, and known
limitations. If this cannot be reproduced, verified, or justified, generated
parser provenance is a blocker and TypeScript source import must not close.

The later import must also prove the external scanner state for the exact
selected revision. If either the TypeScript grammar or TSX grammar contains
`src/scanner.c`, `src/scanner.cc`, or another required scanner source, the
import must include that source in the BOM, record its upstream identity and
checksum basis, and validate that it compiles with local repository inputs only.
If no external scanner is present or needed for one component, the import must
record the inspected paths or upstream metadata that prove that absence. Scanner
assumptions are blockers until proved against the selected revision.

## Bill-of-materials expectations

A future TypeScript import must use a narrow, auditable file set. The expected
include classes are:

- upstream license and notice files;
- grammar metadata such as `tree-sitter.json` when present;
- grammar source files needed to review TypeScript and TSX parser generation;
- generated C parser files and any required scanner files for TypeScript and
  TSX;
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
- package.json, `tsconfig`, workspace, bundler, dependency graph, and
  module-resolution analysis artefacts; and
- custom user queries, global parser packages, and runtime registry wiring.

The future import must record the final BOM and excluded file classes in a
repo-relative provenance artefact. If the file set cannot be kept narrow and
reviewable, source import remains blocked.

## Local-first build supply-chain gate

A future TypeScript import must prove that validation uses only
repository-local inputs. It must not fetch source at build time, require `npm`,
`pnpm`, `yarn`, `tsc`, another package manager, require a global Tree-sitter
CLI, use submodules, use system Tree-sitter packages, call a remote parser
service, upload source, emit telemetry, or perform remote enrichment.

Any parser generation or verification step must be either committed as evidence
from local pinned inputs or explicitly treated as a separate proof step. Normal
no-provider builds and reports must remain deterministic when TypeScript
provider work is not requested.

## Source-size and build-impact gate

Before a later TypeScript source import can close, it must measure and record:

- bytes added under `third_party/tree-sitter-typescript/<revision>/`;
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

TypeScript query support is not admitted by this document. A later runtime
feature may add project-owned built-in TypeScript symbol queries only after the
source-import gates pass.

The first TypeScript query contract should focus on stable inspect-oriented
symbols: functions, classes, methods, interfaces, type aliases, enums,
namespaces, constants, variables, decorators when they affect symbol meaning,
and TSX component definitions because TSX is admitted with TypeScript only after
fixture proof. It must define accepted capture names, symbol-kind mapping, range
semantics, deterministic ordering, query version metadata, provider version
metadata, and caveats for unsupported or ambiguous constructs.

Fixture coverage for future TypeScript work must include at least:

- `.ts`, `.mts`, and `.cts` path examples;
- `.tsx` path examples because TSX is admitted only with fixture proof;
- declaration files such as `.d.ts`;
- top-level functions and function expressions;
- classes and methods;
- interfaces;
- type aliases and type-only exports or imports;
- enums and const enums;
- namespaces or modules when they can be mapped deterministically;
- constants, variables, and fields;
- decorators on classes, functions, methods, and fields;
- generics, overloads, and abstract members that should be named, caveated, or
  skipped deterministically;
- TSX components, fragments, and expression-heavy examples;
- generated or compiled output paths that should be caveated or skipped
  deterministically;
- empty files;
- invalid or partial files;
- unsupported paths and skipped-provider states; and
- monorepo-style project-relative paths.

Built-in queries must not be blind imports of upstream highlight queries.
Custom user query execution is deferred to a separate safety-contract feature.
If TypeScript cannot be useful without custom user queries, the next step is a
custom query safety feature, not an expansion of this admission review.

## Monorepo, path, and Node context behaviour

Future TypeScript provider behaviour must remain inspect-path-only and
extension-based. A requested path ending in `.ts`, `.mts`, `.cts`, or `.tsx` may
be considered a TypeScript candidate because of that path extension after a
TypeScript runtime feature exists; this admission review does not implement
that behaviour.

Monorepo behaviour must not imply `package.json` parsing, `tsconfig` parsing,
workspace discovery, bundler analysis, dependency graph inference, module
resolution, LSP, Node provider identity, or repo-wide scanning. It must not
inspect sibling packages or a whole monorepo unless a later feature explicitly
shapes and validates that behaviour. Ambiguous or unsupported paths should fail
closed with a visible caveat while preserving file-level Git evidence.

Node is runtime context only. Future documentation may explain that a requested
TypeScript path is often compiled for or run by Node, but Node is not a parser
identity, not a provider name, not a separate language id, and not a reason to
parse package, workspace, dependency, module-resolution, or `tsconfig` metadata.

## No-provider and provider-boundary gates

Normal table, JSON, Markdown, and inspect outputs must remain byte-stable when
TypeScript provider output is not requested. File-level Git evidence remains
the product truth regardless of provider state.

Future TypeScript provider evidence, if implemented, must be:

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

Future TypeScript support must not be described as implemented until a separate
runtime feature imports sources, proves offline build behaviour, adds a reviewed
query contract, validates fixtures, preserves no-provider output, and wires the
provider deliberately.

## Explicit deferrals

This admission review explicitly defers all of the following:

- TypeScript source import;
- TypeScript offline build proof;
- TypeScript extraction proof;
- inspect-only TypeScript symbol output;
- custom user query execution;
- LSP integration;
- provider registry changes;
- CLI and report schema changes;
- package.json, `tsconfig`, workspace, bundler, dependency graph, module
  resolution, and repo-wide scanning;
- Node provider identity;
- scoring and cache changes; and
- release or package work.

LSP is a separate provider class and must not be used to justify admitting a
Tree-sitter grammar. TypeScript package-manager, workspace, module, bundler,
`tsconfig`, or Node runtime analysis is also out of scope; future language
detection should stay path-based for the requested inspect path unless a later
feature shapes something narrower.

## Future sequencing

Future TypeScript work must proceed in this order unless a later shaped feature
narrows the plan:

1. Select an immutable `tree-sitter-typescript` revision and record source
   identity plus checksum evidence.
2. Verify license, notice, generated parser provenance, and scanner provenance
   for TypeScript and TSX at that exact revision.
3. Record the narrow BOM and excluded file classes before copying source.
4. Prove compatibility with the existing vendored Tree-sitter core ABI and
   language-version range, or shape a separate core-update feature.
5. Measure source size, build impact, offline validation, and no-provider output
   stability using local inputs only.
6. Design and validate a project-owned TypeScript query contract with fixtures,
   including TSX fixtures while `.tsx` remains admitted with TypeScript.
7. Only then add runtime provider behaviour in a separate reviewed feature.

## Decision state

Decision state: `conditionaltypescript`.

The public upstream candidate is plausible for a later TypeScript source-import
feature, but this feature does not make the candidate ready for import and does
not implement TypeScript runtime support. A future source-import feature may
proceed only after it resolves or records the blockers below.

Named blockers for a later TypeScript source-import feature:

1. Select an immutable `tree-sitter-typescript` revision and record the source
   identity and checksum requirement.
2. Verify license and notice obligations at that selected revision.
3. Reproduce, verify, or explicitly justify generated TypeScript and TSX parser
   provenance.
4. Prove external scanner presence or absence for TypeScript and TSX at the
   selected revision and include any required scanner source in the BOM.
5. Define the exact BOM and excluded file classes for
   `third_party/tree-sitter-typescript/<revision>/`.
6. Prove compatibility with the existing vendored Tree-sitter core ABI and
   language-version range, or shape a separate core-update feature.
7. Measure source-size and build-impact evidence using local inputs only.
8. Prove offline validation and no-provider output stability.
9. Design and validate a project-owned TypeScript symbol query contract with
   fixtures for functions, classes, methods, interfaces, type aliases, enums,
   type-only constructs, decorators, declaration files, TSX, empty files,
   invalid files, unsupported paths, and monorepo paths.
10. Preserve inspect-path-only, extension-based monorepo behaviour without
    package.json, `tsconfig`, workspace, bundler, dependency graph, module
    resolution, LSP, Node provider identity, or repo-wide scanning claims.
11. Preserve local-first behaviour, privacy-safe diagnostics, and file-level Git
    evidence as product truth.

If any blocker remains unresolved in the future import, keep the state at
`conditionaltypescript` or move it to `blocked`; do not claim TypeScript runtime
support.
