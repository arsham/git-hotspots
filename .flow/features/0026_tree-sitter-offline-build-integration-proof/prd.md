# Feature 0026: Tree-sitter offline build integration proof

## Purpose

Prove that the pinned vendored Tree-sitter core and tree-sitter-zig sources can
be compiled and linked offline through the local Zig build, without changing the
installed `git-hotspots` runtime, CLI, report schema, scoring, provider
registry, cache, network behaviour, telemetry, or background analysis.

This feature is the build-supply-chain gate between the source import proof
(Feature 0025) and a later inspect-only Zig symbol provider. It should answer
one question: can the repository build a tiny non-product Tree-sitter proof from
local vendored files only?

## Scope

In scope:

- Add an explicit build proof step, preferably:

  ```sh
  zig build tree-sitter-build-proof
  ```

- Compile and link only local vendored Tree-sitter inputs:
  - `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c` as the core runtime
    translation unit, unless implementation evidence proves an equivalent
    local-only file set without duplicate or missing symbols.
  - `third_party/tree-sitter-zig/v1.1.2/src/parser.c` as the Zig grammar parser.
  - `third_party/tree-sitter-core/v0.26.9/lib/include` as the Tree-sitter public
    include path.
  - `third_party/tree-sitter-zig/v1.1.2/src` as the grammar parser include path.
- Link libc explicitly if required by Zig 0.16.0 and the target.
- Add one tiny non-product smoke target or test that parses an in-memory Zig
  snippet such as `const x = 1;` or `pub fn main() void {}`.
- Assert only parser setup and deterministic parse basics, such as parser
  creation, language assignment, non-null tree/root node, stable root kind, and
  cleanup/deinit.
- Add the proof to the canonical validation path if the measured overhead is
  acceptable; otherwise keep it as a separately required close-out command and
  record the reason.
- Record build timing, binary/object size where practical, target, Zig version,
  and local-only/offline evidence.
- Prove no-provider table, JSON, Markdown, and inspect outputs remain
  byte-stable.

Out of scope:

- No Tree-sitter provider runtime in the installed `git-hotspots` executable.
- No provider registry, parser wrapper for product use, or symbol extraction.
- No CLI flags, report fields, JSON schema changes, Markdown/table output
  changes, scoring/ranking changes, cache, CI, release packaging, telemetry,
  upload, remote enrichment, or background analysis.
- No `build.zig.zon`, package manager, `pkg-config`, submodule, system
  Tree-sitter package, global `tree-sitter` CLI, npm/npx/pnpm/yarn, curl/wget,
  git clone/fetch, or build-time download.
- No parser generation and no `tree-sitter generate`.
- No parsing of real repository files for product output.
- No user-visible parser diagnostics, raw parser stderr, source snippets, or
  private path exposure.

## Requirements

### R1 - Isolated proof target

The implementation must add a dedicated non-product build proof target. Running
normal `zig build` must keep building and installing only the normal
`git-hotspots` executable. The proof target must not be installed as a product
binary and must not add Tree-sitter runtime behaviour to normal CLI execution.

### R2 - Local vendored sources only

The proof must compile and link from the pinned local vendored source files
under `third_party/`. It must not rely on system Tree-sitter libraries, global
Tree-sitter CLI installs, `pkg-config`, build-time network, package managers,
submodules, or generated files outside the repository.

### R3 - Tree-sitter core compile strategy

The preferred core compile strategy is to compile
`third_party/tree-sitter-core/v0.26.9/lib/src/lib.c` as the single Tree-sitter
core translation unit. If the implementation uses individual `.c` files instead,
it must record evidence that there are no duplicate or missing symbols.

### R4 - Zig grammar parser compile strategy

The proof must compile
`third_party/tree-sitter-zig/v1.1.2/src/parser.c` from the pinned imported
source. Include paths must be repo-relative vendored paths only.

### R5 - Tiny in-memory parse smoke

The proof must parse a tiny in-memory Zig snippet using the compiled local core
and Zig grammar. It should assert only stable parser basics: language assignment,
parse success, non-null root node/tree, a stable root kind, and cleanup. It must
not produce symbol evidence or user-visible report output.

### R6 - No-provider output parity

Existing no-provider outputs must remain byte-stable for representative table,
JSON, Markdown, and inspect commands. The feature must not update fixture
expected outputs to accommodate provider fields or parser output.

### R7 - Validation and close-out smoke

The implementation must run and record:

```sh
zig fmt --check build.zig src tests
zig build test
zig build
zig build validate
zig build tree-sitter-build-proof
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-local-repo> -Dsmoke-label=sibling-local-repo
git diff --check
```

If `zig build tree-sitter-build-proof` is integrated into `zig build validate`,
still record explicit evidence that the proof ran. If `zig fmt --check` cannot
address vendored C or generated source files, limit it to owned Zig/test files
and say so.

### R8 - Offline and protected-surface scans

Close-out must prove:

- `.gitmodules` is absent or empty.
- `git submodule status` shows no submodule dependency.
- `build.zig.zon` is absent unless a later feature explicitly shapes it.
- `build.zig`, `tools/`, `tests/`, and new proof code do not introduce
  `pkg-config`, Tree-sitter CLI shell-out, npm/npx/pnpm/yarn, curl/wget, git
  clone/fetch/pull/submodule, package resolution, network transfer, telemetry,
  upload, remote enrichment, or background execution.
- Include paths for Tree-sitter proof code are repo-relative `third_party/...`
  paths.

### R9 - Evidence document

The implementation must update or add a concise evidence document, likely
`docs/tree-sitter-offline-build-proof.md`, with:

- exact proof command(s);
- Zig version and target;
- source files and include paths used;
- proof target scope and explicit non-product boundary;
- timing/size observations;
- no-provider parity evidence;
- offline/local-only scan results;
- close-out smoke summary using only `sibling-local-repo` for the sibling repo;
- any platform caveats or stop conditions encountered.

### R10 - Privacy and public framing

Committed evidence must use repo-relative paths and bounded counts/timings only.
It must not include private local paths, private repo names, raw sibling output,
raw parser stderr, parser diagnostics with source snippets, remotes, author
identities, commercial strategy, bug-prediction claims, code-quality scoring,
developer ranking, or maintainer judgement.

## Edge cases

- If compiling the vendored C sources requires system packages, package manager
  resolution, a global parser generator, network access, or submodules, stop
  and return a planning or prerequisite split.
- If `lib.c` does not compile cleanly as a single translation unit, either prove
  an explicit individual-file compile set without duplicate/missing symbols or
  stop.
- If the tiny parse smoke needs provider semantics, report fields, CLI flags, or
  real repo file parsing to pass, stop and split the provider runtime feature.
- If build time, binary/object size, or source-install UX worsens materially,
  stop for planner review.
- If no-provider output bytes change, stop. Do not update goldens unless a
  planning change explicitly approves a report change.
- If parser diagnostics expose private paths, source text, or raw stderr, stop
  and sanitise or remove the diagnostic path before close-out.
- If cross-platform or Windows-specific failures appear, record them as a later
  portability follow-up unless they block the current supported local target.

## Verification

Required validation commands:

```sh
zig fmt --check build.zig src tests
zig build test
zig build
zig build validate
zig build tree-sitter-build-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-local-repo> -Dsmoke-label=sibling-local-repo
```

Required local-only scans:

```sh
test ! -f build.zig.zon
test ! -f .gitmodules
git submodule status
rg -n 'pkg-config|tree-sitter generate|\btree-sitter\b|npm|npx|pnpm|yarn|curl|wget|git (clone|fetch|pull|submodule)|telemetry|upload|remote enrichment' build.zig tools tests src
```

The scan may need an allowlist for documentation/help text or for literal words
inside the evidence document. It must not allow build or test code to shell out
to global Tree-sitter tools or network commands.

Protected output parity must cover representative no-provider outputs:

```sh
# Representative examples; implementation may use existing fixture helpers.
fixtures/basic --format table
fixtures/basic --format json
fixtures/basic --format markdown
fixtures/basic --inspect src/app.txt --format table
fixtures/basic --inspect src/app.txt --format json
fixtures/basic --inspect src/app.txt --format markdown
```

Existing project validation already covers many JSON, Markdown, inspect, scope,
and real-repo paths. If normal table output does not have a committed golden,
this feature must either add a public table golden or record a before/after
capture protocol that proves byte stability without committing private output.

Close-out evidence must include:

- command transcript summary for the build proof;
- `zig build validate` summary;
- close-out smoke summary with `sibling-local-repo` only;
- no-provider parity result;
- changed-path/protected-surface proof;
- local-only/offline scan result;
- privacy/prohibited-claim scan result.

## Non-goal reminder

A passing Feature 0026 means only that the vendored parser sources can be built
and used by a tiny internal proof from local files. It does not mean that
`git-hotspots` has symbol hotspot reports, Tree-sitter provider output, function
ranking, parser-backed scoring, or historical symbol lineage.
