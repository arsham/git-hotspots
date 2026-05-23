# Feature 0025: Tree-sitter source import proof

## Purpose

Import pinned Tree-sitter source inputs into the repository in a way that is
local-first, auditable, license-aware, and reversible, while deliberately
stopping before parser compilation, provider runtime, CLI/report changes, or
symbol output.

This feature exists because Features 0023 and 0024 found a plausible local-first
path for a future Tree-sitter Zig provider, but left both components in a
`conditional` state until actual source import can prove provenance, notice
handling, source size, offline validation, and no-provider output stability.

## Operator decision

During shaping, Arsham approved allowing Feature 0025 to add pinned vendored
source files under `third_party/`, provided the feature stops before compile,
link, parser runtime, provider behavior, CLI/report/schema/scoring/cache changes,
network runtime, telemetry, upload, remote enrichment, or background analysis.

## Scope

In scope:

- Import pinned Tree-sitter core source files under a repo-relative
  `third_party/tree-sitter-core/` layout.
- Import pinned `tree-sitter-zig` grammar and generated parser source files under
  a repo-relative `third_party/tree-sitter-zig/` layout.
- Preserve upstream MIT license files for both components.
- Add a repo-level third-party notice or attribution artefact, preferably
  `THIRD_PARTY_NOTICES.md` unless implementation evidence shows a better public
  name.
- Add per-component `PROVENANCE.md` files using the Feature 0024 readiness
  template.
- Record an exact imported file bill of materials and excluded file classes.
- Record immutable upstream source identities:
  - Tree-sitter core upstream, tag `v0.26.9`, commit
    `7f534862c3ec939c3a6ee147f7600ef5c1bf900f`.
  - tree-sitter-zig upstream, tag `v1.1.2`, commit
    `b670c8df85a1568f498aa5c8cae42f51a90473c0`.
- Record source archive or checkout checksums when available from the import
  method.
- Represent `tree-sitter-zig/src/parser.c` provenance honestly by either:
  - reproducing or verifying it from pinned grammar inputs and an exact generator;
    or
  - recording a reviewed justification for trusting the pinned upstream generated
    artefact, including the known blob
    `cb09604e5dac45c2bd599e3bdc509411ea6ed2a1` and known size `5843608` bytes.
- Measure source size and largest files.
- Measure validation/build impact using existing no-provider validation.
- Prove `zig build validate` works offline from local repository inputs.
- Prove existing no-provider table, JSON, Markdown, and inspect outputs remain
  byte-stable.

Out of scope:

- No `build.zig.zon`.
- No `build.zig` C compilation or linking.
- No parser wrapper or runtime.
- No provider registry or provider execution.
- No CLI flags or user-visible report schema additions.
- No file-level scoring, ranking, co-change, inspect semantics, lineage, cache,
  CI, package/release, network runtime, telemetry, upload, remote enrichment, or
  background-analysis change.
- No dependency on system Tree-sitter packages, global parser packages,
  submodules, or build-time fetches.

## Requirements

### R1 - Source identity and BOM

The implementation must record exact imported paths and file sets for both
components. It must explain excluded upstream file classes. It must not import a
whole upstream repository by default.

The Tree-sitter core import should be limited to the public headers and C runtime
source area needed for a future local runtime proof, such as upstream `lib/include`
and `lib/src`. It must exclude CLI binaries, package-manager metadata, web/wasm
runtime, tests, examples, and language bindings unless a reviewed source-import
reason is recorded.

The tree-sitter-zig import should be limited to grammar/source artefacts needed
for a future Zig provider proof, including license, grammar metadata, generated
parser, node types, grammar JSON, and query files. It must exclude package-manager
wrappers, prebuilds, bindings, tests, examples, and unrelated packaging unless a
reviewed source-import reason is recorded.

### R2 - License and notice

The implementation must copy upstream MIT license text and copyright notices for
both components into the vendored component areas. It must add or update a
repo-level third-party notice/attribution artefact using only public upstream
metadata and repo-relative paths.

### R3 - Provenance

Each component must have a colocated `PROVENANCE.md` that records:

- component name;
- vendored path;
- import feature id;
- import date;
- upstream URL;
- selected tag and full commit;
- source archive or checkout identity;
- source archive SHA-256 or an explicit reason when not applicable;
- imported file list or manifest path;
- excluded file classes and reasons;
- generated-source provenance when applicable;
- license and notice handling;
- source-size measurements;
- build/no-provider stability evidence references;
- update policy.

### R4 - Generated parser provenance

`tree-sitter-zig/src/parser.c` must not be imported as unexplained bulk source.
The feature must either reproduce/verify it from pinned grammar inputs and an
exact Tree-sitter CLI version, or record a reviewed justification for trusting it
as a pinned upstream generated artefact. The justification must include the known
public blob hash, size, upstream tag/commit, and a bounded caveat that runtime
integration remains a later feature.

### R5 - Local-first validation

The implementation must prove that normal validation remains local and offline.
It must not add build-time fetches, package resolution, submodules, global
Tree-sitter package dependency, system parser package dependency, or runtime
network behavior.

### R6 - No-provider output stability

The implementation must prove no-provider outputs remain byte-stable after source
import for representative table, JSON, Markdown, and inspect commands. Provider
or symbol terms must not appear in normal no-provider output unless they already
existed in help or documentation surfaces unrelated to reports.

### R7 - Source-size and build-impact evidence

The implementation must record:

- total bytes under `third_party/tree-sitter-core`;
- total bytes under `third_party/tree-sitter-zig`;
- largest ten vendored files by byte size;
- byte size of imported Zig `parser.c`;
- repository working-tree size before and after import, excluding `.git`,
  `.zig-cache`, and `zig-out`;
- `zig build validate` timing before/after when practical.

Planner review is required if:

- imported Zig `parser.c` materially differs from `5843608` bytes without an
  explanation;
- a single imported file exceeds `6000000` bytes;
- total vendored source exceeds `8000000` bytes;
- the implementation cannot explain why each large file is needed;
- validation time materially worsens; or
- measurement requires non-local files.

### R8 - Privacy and public-repo hygiene

Committed evidence must use repo-relative paths and public upstream URLs only. It
must not contain private local paths, private repository names, remotes, raw
private reports, raw parser stderr, source snippets copied into docs beyond the
vendored public source files themselves, author identities, person-level
attribution, commercial strategy, hosted-product claims, bug-prediction claims,
code-quality scoring claims, developer ranking, or maintainer judgement.

## Edge cases

- If upstream retrieval is unavailable during execution, stop with a blocker;
  do not fabricate source files or checksums.
- If source identity/checksum cannot be recorded, stop or reshape; do not close
  with incomplete provenance.
- If license or notice text is ambiguous, stop or reshape.
- If `parser.c` provenance cannot be represented honestly, stop or reshape.
- If importing generated source would exceed size thresholds without clear
  justification, stop or reshape.
- If any runtime/provider/build integration is needed to prove the import, stop
  and shape a separate feature.

## Verification

Required close-out commands and evidence include:

```sh
git diff --check
zig build validate
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-local-repo> -Dsmoke-label=sibling-local-repo
```

Use a privacy-safe skip reason only if a sibling repository is genuinely
unavailable. In the current project, the known execution-only sibling label is
`sibling-local-repo`.

Additional required checks:

```sh
git diff --name-status
find third_party -type f | LC_ALL=C sort
git ls-files -s | awk '$1=="160000"{print; bad=1} END{exit bad?1:0}'
test ! -f .gitmodules
test ! -f build.zig.zon
```

Protected runtime scan:

```sh
git diff --name-only -- src tests fixtures/expected build.zig build.zig.zon tools/validate.sh
```

This must show no protected runtime/source/test/build changes, except that
`tools/validate.sh` may change only to add local validation gates for this
feature if necessary.

No-network/local-only scan over executable surfaces:

```sh
rg -n 'curl|wget|git (clone|fetch|pull|submodule)|npm|npx|pnpm|yarn|pkg-config|tree-sitter generate|telemetry|upload|remote enrichment' build.zig tools tests src
```

This scan should find no new executable path requiring network, system package,
submodule, or global parser tooling.

Source-size checks:

```sh
find third_party/tree-sitter-core third_party/tree-sitter-zig -type f -print0 | xargs -0 wc -c
find third_party/tree-sitter-core third_party/tree-sitter-zig -type f -printf '%s %p\n' | sort -nr | head -10
wc -c third_party/tree-sitter-zig/*/src/parser.c
du -sk --exclude=.git --exclude=.zig-cache --exclude=zig-out .
```

Privacy scans:

```sh
rg -n "$HOME|/home/|/Users/|[A-Za-z]:\\|ssh://|git@|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}" docs third_party
rg -n 'https?://' docs third_party | rg -v 'github.com/tree-sitter/tree-sitter|github.com/tree-sitter-grammars/tree-sitter-zig'
```

No-provider output parity must compare representative before/after table, JSON,
Markdown, and inspect outputs. The implementation may create temporary outputs
outside the repo; committed evidence must summarize only repo-relative command
shapes and pass/fail results.

## Review focus

Reviewer must verify:

- imported files are limited to the approved scope;
- no submodules or build-time dependency manifests were added;
- license and notice files are present and public;
- `PROVENANCE.md` files are complete;
- generated parser provenance is honestly represented;
- source-size and build-impact evidence is present;
- no-provider outputs remain stable;
- no parser runtime/provider behavior slipped in;
- privacy and local-first boundaries hold.
