# Feature 0043: Tree-sitter Python offline build proof

## Summary

Add an isolated, non-product proof that the vendored `tree-sitter-python`
parser and scanner compile, link, and parse a tiny in-memory Python snippet with
the existing vendored Tree-sitter core.

This feature proves build compatibility only. It does not add Python symbol
extraction, Python queries, runtime provider behaviour, CLI/report output,
scoring, cache, fixtures for product output, or repository-wide parsing.

## Problem

Feature 0042 imported pinned `tree-sitter-python` sources and proved provenance,
license, BOM, generated parser/scanner provenance, core ABI compatibility,
source size, offline validation, and no-provider output stability. The next risk
is whether the Python parser and scanner sources compile and link with the
existing vendored core in this repository's Zig build.

Without an isolated proof, later Python provider work would combine build risk
with query, extraction, and user-facing output risk.

## Goals

- Add a clearly named non-product proof target, expected as:

  ```sh
  zig build tree-sitter-python-build-proof
  ```

- Compile and link only local vendored sources:
  - `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`
  - `third_party/tree-sitter-python/v0.25.0/src/parser.c`
  - `third_party/tree-sitter-python/v0.25.0/src/scanner.c`
  - required repo-local include paths for parser/scanner headers.
- Parse a tiny in-memory Python snippet such as:
  `class Example:\n    def method(self):\n        return 1\n`.
- Assert parser creation, language assignment, parse tree creation, stable root
  kind, cleanup, and no root error.
- Preserve existing Tree-sitter Zig and Go proof targets.
- Record local/offline, timing/size, CI decision, output-stability, and
  close-out smoke evidence in a concise public evidence document.

## Non-goals

- No Python symbol extraction.
- No Python query contract or query fixtures.
- No Python provider registry entry.
- No Python provider runtime behaviour.
- No CLI flags or report/schema/output changes.
- No scoring, ranking, lineage, cache, CI release, package, LSP, import,
  dependency, virtualenv, notebook, or package-manager analysis.
- No parser generation.
- No `tree-sitter generate`, global Tree-sitter CLI, npm/npx/pnpm/yarn, curl,
  wget, git clone/fetch/pull/submodule, package-manager dependency,
  pkg-config, system Tree-sitter package, build-time network, telemetry,
  upload, or remote enrichment.
- No source import changes beyond what is strictly necessary for a build proof;
  Python source import was completed in Feature 0042.

## Requirements

### R1 - Dedicated Python proof target

The implementation must add a clearly named non-product build step, expected as:

```sh
zig build tree-sitter-python-build-proof
```

The proof target must compile local vendored Tree-sitter core and Python parser
and scanner sources only. It must not install or run as part of the product CLI
runtime.

### R2 - Scanner compilation

The proof must compile the Python scanner source and required helper headers
from `third_party/tree-sitter-python/v0.25.0/src/tree_sitter/` using repo-local
include paths only. It must not replace scanner behaviour with stubs or generated
sources.

### R3 - Tiny in-memory Python parse smoke

The proof executable or test must parse a hardcoded in-memory Python source
string, assign `tree_sitter_python`, create a tree, inspect the root node, and
clean up all Tree-sitter resources.

The minimum semantic assertion is a stable Python root node such as `module`,
plus an error-free root if the API exposes that check reliably.

### R4 - Existing proof preservation

Existing proof commands must continue to pass and retain their current meaning:

```sh
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build tree-sitter-go-build-proof
zig build tree-sitter-go-symbol-proof
```

### R5 - CI coverage decision

The Python proof must either be included in the public CI workflow or a durable,
explicit reason must be recorded for not adding it. If included, CI must remain
local/offline after checkout and Zig setup and must not require sibling repo
smoke, secrets, release automation, artifacts, caches, package managers, or
network access beyond normal GitHub checkout/Zig setup.

### R6 - No-provider byte stability

Representative no-provider table, JSON, Markdown, and inspect outputs must stay
byte-stable. Expected fixtures must not be refreshed to absorb accidental Python
provider output because this feature must not add Python runtime behaviour.

### R7 - Evidence document

Add a concise public evidence document, expected path:

```text
docs/tree-sitter-python-offline-build-proof.md
```

It must record proof command names, Zig version and local target, source files
and include paths, scanner handling, timing or size observations, CI decision,
output-stability evidence, offline/prohibited dependency scan results,
close-out smoke summary using labels only, and explicit non-runtime boundary.

### R8 - Protected surfaces

Allowed changed paths are limited to `build.zig`, new or adjusted non-product
proof test/source file(s), public evidence docs, optional CI workflow if the
Python proof is added to CI, and Flow state.

The implementation must not change `src/`, provider runtime, report/schema,
scoring, cache, existing expected outputs, `build.zig.zon`, `.gitmodules`,
package/release files, or runtime fixtures unless shaping is reopened.

### R9 - Privacy and claims

Committed evidence must use repo-relative paths and public upstream component
identifiers only. It must not include private paths, raw sibling reports, raw
parser stderr dumps, source snippets from private repos, remotes, author
identities, commercial strategy, bug prediction, quality scoring, developer
ranking, or maintainer judgement.

## Edge cases

- If the Python parser or scanner cannot compile/link with the existing vendored
  core, stop and report a blocker. Do not add system packages, generated
  sources, or a core update by local decision.
- If the proof needs additional scanner helper files beyond the Feature 0042
  BOM, stop and reshape unless the missing file is clearly a narrow local header
  already justified by provenance.
- If CI overhead is materially increased, stop for planning before broadening or
  excluding the proof.
- If no-provider output changes, block close-out. Do not update goldens without
  a separate report-change feature.
- If the proof target accidentally links Python parser code into the installed
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
zig build tree-sitter-go-symbol-proof
zig build tree-sitter-python-build-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

The sibling path is execution-only context and must not be committed. Durable
summary evidence must use only the label `sibling-local-repo`.
