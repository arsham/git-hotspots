# Feature 0037: Tree-sitter Go offline build proof

## Summary

Add an isolated, non-product proof that the vendored `tree-sitter-go` parser
can compile, link, and parse a tiny in-memory Go snippet with the existing
vendored Tree-sitter core.

This feature proves build compatibility only. It does not add Go symbol
extraction, Go provider runtime behaviour, CLI/report output, scoring, cache,
query support, or repository-wide parsing.

## Problem

Feature 0036 imported pinned `tree-sitter-go` sources and proved provenance,
license, BOM, generated parser provenance, core ABI compatibility, source size,
offline validation, and no-provider output stability. The next risk is whether
those sources actually compile and link with the existing vendored core in this
repository's Zig build.

Without an isolated proof, future Go provider work would combine build risk with
symbol-extraction and user-facing report risk.

## Goals

- Add a clearly named non-product proof target, expected to be:
  `zig build tree-sitter-go-build-proof`.
- Compile and link only local vendored sources:
  - `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`
  - `third_party/tree-sitter-go/v0.25.0/src/parser.c`
- Use repo-relative include paths only.
- Parse a tiny in-memory Go snippet such as:
  `package main\nfunc main() {}\n`.
- Assert parser creation, language assignment, parse tree creation, stable root
  kind, cleanup, and no root error.
- Preserve the existing Zig Tree-sitter proof targets.
- Record local/offline, timing/size, CI, output-stability, and close-out smoke
  evidence in a concise public evidence document.

## Non-goals

- No Go symbol extraction.
- No Go query contract or query fixtures.
- No Go provider registry entry.
- No Go provider runtime behaviour.
- No CLI flags or report/schema/output changes.
- No scoring, ranking, lineage, cache, CI release, package, or LSP work.
- No parser generation.
- No `tree-sitter generate`, global Tree-sitter CLI, npm/npx/pnpm/yarn, curl,
  wget, git clone/fetch/pull/submodule, package-manager dependency, pkg-config,
  system Tree-sitter package, build-time network, telemetry, upload, or remote
  enrichment.
- No source import changes beyond what is strictly necessary for a build proof;
  Go source import was completed in Feature 0036.

## Requirements

### R1 - Dedicated Go proof target

The implementation must add a clearly named non-product build step, expected as:

```sh
zig build tree-sitter-go-build-proof
```

The proof target must compile local vendored Tree-sitter core and Go parser
sources only. It must not install or run as part of the product CLI runtime.

### R2 - Tiny in-memory Go parse smoke

The proof executable or test must parse a hardcoded in-memory Go source string,
assign `tree_sitter_go`, create a tree, inspect the root node, and clean up all
Tree-sitter resources.

The minimum semantic assertion is a stable Go root node such as `source_file`,
plus an error-free root if the API exposes that check reliably.

### R3 - Existing proof preservation

Existing Zig proof commands must continue to pass and retain their Zig-specific
meaning:

```sh
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
```

### R4 - CI coverage decision

The Go proof must either be included in the public CI workflow or a durable,
explicit reason must be recorded for not adding it. If included, CI must remain
local/offline after checkout and Zig setup, and must not require sibling repo
smoke, secrets, release automation, artifacts, caches, package managers, or
network access beyond normal GitHub checkout/Zig setup.

### R5 - No-provider byte stability

Representative no-provider table, JSON, Markdown, and inspect outputs must stay
byte-stable. Expected fixtures must not be refreshed to absorb accidental Go
provider output because this feature must not add Go runtime behaviour.

### R6 - Evidence document

Add or update a concise public evidence document, expected path:

```text
docs/tree-sitter-go-offline-build-proof.md
```

It must record:

- proof command names;
- Zig version and local target;
- source files and include paths;
- timing or size observations;
- CI decision;
- output-stability evidence;
- offline/prohibited dependency scan results;
- close-out smoke summary using labels only;
- explicit non-runtime boundary.

### R7 - Protected surfaces

Allowed changed paths are limited to:

- `build.zig`;
- new or adjusted non-product proof test/source file(s);
- public evidence docs;
- optional CI workflow if the Go proof is added to CI;
- Flow state.

The implementation must not change `src/`, provider runtime, report/schema,
scoring, cache, existing expected outputs, `build.zig.zon`, `.gitmodules`,
package/release files, or runtime fixtures unless shaping is reopened.

### R8 - Privacy and claims

Committed evidence must use repo-relative paths and public upstream component
identifiers only. It must not include private paths, raw sibling reports, raw
parser stderr dumps, source snippets from private repos, remotes, author
identities, commercial strategy, bug prediction, quality scoring, developer
ranking, or maintainer judgement.

## Edge cases

- If the Go parser cannot compile/link with the existing vendored core, stop and
  report a blocker. Do not add system packages, generated sources, or a core
  update by local decision.
- If the proof needs an external scanner not present in the imported Go source,
  stop and reshape.
- If CI overhead is materially increased, stop for planning before broadening or
  excluding the proof.
- If no-provider output changes, block close-out. Do not update goldens without
  a separate report-change feature.
- If the proof target accidentally links Go parser code into the installed
  product runtime, block close-out.

## Verification

Close-out must include evidence for:

```sh
zig fmt --check build.zig src tests
zig build test
zig build
zig build validate
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build tree-sitter-go-build-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

The sibling path is execution-only context and must not be committed. Durable
summary evidence must use only the label `sibling-local-repo`.
