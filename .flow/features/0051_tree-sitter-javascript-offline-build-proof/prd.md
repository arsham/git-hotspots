# Feature 0051: JavaScript offline build proof

## Summary

Add an isolated, non-product proof that the vendored `tree-sitter-javascript`
parser and any required scanner sources compile, link, and parse tiny in-memory
JavaScript and admitted JSX snippets with the existing vendored Tree-sitter
core.

This feature proves build compatibility only. It does not add JavaScript symbol
extraction, JavaScript queries, runtime provider behaviour, CLI/report output,
scoring, cache, fixtures for product output, package analysis, Node provider
identity, or repository-wide parsing.

## Problem

Feature 0050 imports pinned `tree-sitter-javascript` sources and proves
provenance, license, BOM, generated parser/scanner provenance, core ABI
compatibility, source size, JSX source admission state, offline validation, and
no-provider output stability. The next risk is whether the JavaScript parser and
scanner sources compile and link with the existing vendored core in this
repository's Zig build.

Without an isolated proof, later JavaScript provider work would combine build
risk with query, extraction, and user-facing output risk.

## Goals

- Add a clearly named non-product build step, expected as:

  ```sh
  zig build tree-sitter-javascript-build-proof
  ```

- Compile and link only local vendored sources:
  - `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`;
  - `third_party/tree-sitter-javascript/<revision>/src/parser.c`;
  - any required JavaScript scanner source for the selected revision; and
  - required repo-local include paths for parser/scanner headers.
- Parse tiny in-memory JavaScript source such as `function proof() { return 1; }`.
- If Feature 0050 admitted JSX for the selected revision, parse a tiny in-memory
  JSX snippet and assert a stable root without errors; otherwise record that JSX
  remains deferred.
- Assert parser creation, language assignment, parse tree creation, stable root
  kind, cleanup, and no root error where the API exposes that check reliably.
- Preserve existing Tree-sitter Zig, Go, and Python proof targets.
- Record local/offline, timing/size, CI decision, output-stability, and
  close-out smoke evidence in a concise public evidence document.

## Non-goals

- No JavaScript symbol extraction.
- No JavaScript query contract or query fixtures.
- No JavaScript provider registry entry.
- No JavaScript provider runtime behaviour.
- No CLI flags or report/schema/output changes.
- No scoring, ranking, lineage, cache, CI release, package, LSP, Node,
  package/workspace/module, dependency, bundler, or package-manager analysis.
- No TypeScript or TSX grammar work.
- No parser generation.
- No `tree-sitter generate`, global Tree-sitter CLI, npm/npx/pnpm/yarn, curl,
  wget, git clone/fetch/pull/submodule, package-manager dependency,
  pkg-config, system Tree-sitter package, build-time network, telemetry, upload,
  or remote enrichment.
- No source import changes beyond what is strictly necessary for a build proof;
  JavaScript source import was completed in Feature 0050.

## Requirements

### R1 Dedicated JavaScript proof target

The implementation must add a clearly named non-product build step, expected as:

```sh
zig build tree-sitter-javascript-build-proof
```

The proof target must compile local vendored Tree-sitter core and JavaScript
parser and scanner sources only. It must not install or run as part of the
product CLI runtime.

### R2 Scanner compilation

The proof must compile any required JavaScript scanner source from the selected
vendored revision using repo-local include paths only. It must not replace
scanner behaviour with stubs or generated sources. If the selected revision has
no scanner, the proof evidence must record the inspected basis for that absence.

### R3 Tiny in-memory JavaScript parse smoke

The proof executable or test must parse a hardcoded in-memory JavaScript source
string, assign `tree_sitter_javascript`, create a tree, inspect the root node,
and clean up all Tree-sitter resources.

The minimum semantic assertion is a stable JavaScript root node such as
`program`, plus an error-free root if the API exposes that check reliably.

### R4 JSX build proof when admitted

If Feature 0050 admitted `.jsx` for the selected revision, the proof must parse
a hardcoded in-memory JSX source string and assert a stable root without errors.
If `.jsx` was deferred in Feature 0050, the proof must not claim JSX runtime
support and must record that JSX remains deferred.

### R5 Existing proof preservation

Existing proof commands must continue to pass and retain their current meaning:

```sh
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build tree-sitter-go-build-proof
zig build tree-sitter-go-symbol-proof
zig build tree-sitter-python-build-proof
zig build tree-sitter-python-symbol-proof
```

### R6 CI coverage decision

The JavaScript proof must either be included in the public CI workflow or a
durable, explicit reason must be recorded for not adding it. If included, CI
must remain local/offline after checkout and Zig setup and must not require
sibling repo smoke, secrets, release automation, artifacts, caches, package
managers, or network access beyond normal GitHub checkout/Zig setup.

### R7 No-provider byte stability

Representative no-provider table, JSON, Markdown, and inspect outputs must stay
byte-stable. Expected fixtures must not be refreshed to absorb accidental
JavaScript provider output because this feature must not add JavaScript runtime
behaviour.

### R8 Evidence document

Add a concise public evidence document, expected path:

```text
docs/tree-sitter-javascript-offline-build-proof.md
```

It must record proof command names, Zig version and local target, source files
and include paths, scanner handling, JSX proof or deferral state, timing or size
observations, CI decision, output-stability evidence, offline/prohibited
dependency scan results, close-out smoke summary using labels only, and explicit
non-runtime boundary.

### R9 Protected surfaces

Allowed changed paths are limited to `build.zig`, new or adjusted non-product
proof test/source file(s), public evidence docs, optional CI workflow if the
JavaScript proof is added to CI, and Flow state.

The implementation must not change `src/`, provider runtime, report/schema,
scoring, cache, existing expected outputs, `build.zig.zon`, `.gitmodules`,
package/release files, runtime fixtures, TypeScript/TSX sources, or
package/workspace analysis unless shaping is reopened.

### R10 Privacy and claims

Committed evidence must use repo-relative paths and public upstream component
identifiers only. It must not include private paths, raw sibling reports, raw
parser stderr dumps, source snippets from private repos, remotes, author
identities, commercial strategy, bug prediction, quality scoring, developer
ranking, or maintainer judgement.

## Edge cases

- If the JavaScript parser or scanner cannot compile/link with the existing
  vendored core, stop and report a blocker. Do not add system packages,
  generated sources, or a core update by local decision.
- If the proof needs additional scanner helper files beyond the Feature 0050
  BOM, stop and reshape unless the missing file is clearly a narrow local header
  already justified by provenance.
- If CI overhead is materially increased, stop for planning before broadening or
  excluding the proof.
- If no-provider output changes, block close-out. Do not update goldens without
  a separate report-change feature.
- If the proof target accidentally links JavaScript parser code into the
  installed product runtime, block close-out.
- If JSX parse proof fails, preserve `.js`, `.mjs`, and `.cjs` build proof and
  defer `.jsx`; do not import TypeScript or TSX to compensate.

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
zig build tree-sitter-python-symbol-proof
zig build tree-sitter-javascript-build-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

Close-out evidence must also include a changed-path protected-surface scan,
prohibited dependency scan, no-provider byte-stability evidence, and explicit
JSX proof or deferral evidence.
