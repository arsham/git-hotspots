# Tree-sitter vendoring readiness gate

This document is the Feature 0024 readiness artefact for a possible later
Tree-sitter source import. It is a gate, not a vendored-source import. It adds
no Tree-sitter core source, no tree-sitter-zig source, no generated parser C,
no build graph change, no parser runtime, no provider registry, no CLI or
report change, no scoring or cache change, and no networked runtime behaviour.

The actual source import remains a separate feature because it must change the
repository contents and probably the build graph. Those changes need fresh
review of provenance, license notice handling, source size, compile impact,
offline build proof, and byte-stable no-provider output at the time the sources
are imported.

## Component decision states

Canonical decision states for this gate are:

- `ready`: canonical source identity is selected and import can proceed.
- `conditional`: source identity is plausible but named blockers remain.
- `blocked`: import must not proceed.

| Component | State | Canonical source candidate | Reason |
| --- | --- | --- | --- |
| Tree-sitter core | `conditional` | Upstream `https://github.com/tree-sitter/tree-sitter`, tag `v0.26.9`, commit `7f534862c3ec939c3a6ee147f7600ef5c1bf900f` | The candidate is public, MIT-licensed, and pinned, but the future import still needs a minimal file-set decision, notice copy, and offline build proof. |
| tree-sitter-zig grammar | `conditional` | Upstream `https://github.com/tree-sitter-grammars/tree-sitter-zig`, tag `v1.1.2`, commit `b670c8df85a1568f498aa5c8cae42f51a90473c0` | The candidate is public, MIT-licensed, and pinned, but the large generated parser needs generated-source provenance and source-size review before import. |

No component is `ready` in this feature. Neither component is `blocked`, because
Feature 0023 found a plausible local-first path if the blockers below are
resolved.

## Known facts

These facts come from the Feature 0023 dependency review and are carried forward
as readiness inputs, not as import proof.

### Tree-sitter core

- Candidate upstream: `https://github.com/tree-sitter/tree-sitter`.
- Candidate tag: `v0.26.9`.
- Candidate commit: `7f534862c3ec939c3a6ee147f7600ef5c1bf900f`.
- Observed source archive size: `914894` bytes.
- Observed source archive SHA-256:
  `849954d8d3054dbba4b55378f0df7aec804e3516ee55bf7967224e033215611e`.
- License: MIT according to the upstream `LICENSE` at the candidate tag.
- Relevant source area: C runtime and public headers under upstream `lib/src`
  and `lib/include`.
- ABI note: `TREE_SITTER_LANGUAGE_VERSION` is `15`; minimum compatible language
  version is `13` at this tag.

### tree-sitter-zig grammar

- Candidate upstream: `https://github.com/tree-sitter-grammars/tree-sitter-zig`.
- Candidate tag: `v1.1.2`.
- Candidate commit: `b670c8df85a1568f498aa5c8cae42f51a90473c0`.
- Observed complete release source size: `114816` bytes.
- Observed complete release source SHA-256:
  `80cbc2cae284b539930f9958003f8f28d4c056ddc3bed912f61bf64e7d6fd680`.
- Observed GitHub-generated source archive size: `264687` bytes.
- Observed GitHub-generated source archive SHA-256:
  `853caeac036440f39ab1fdb2f395d994ff4295a7adec67b2dd65f13b948da0d1`.
- License: MIT according to repository metadata, `tree-sitter.json`,
  `package.json`, and upstream `LICENSE` at the candidate tag.
- Generated parser candidate: `src/parser.c`, Git blob
  `cb09604e5dac45c2bd599e3bdc509411ea6ed2a1`, size `5843608` bytes.
- Grammar source candidates: `grammar.js`, `src/grammar.json`,
  `src/node-types.json`, and query files.
- Generation metadata: `package.json` declares `tree-sitter-cli` development
  dependency `^0.24.5`; release notes say `tree-sitter-zig.tar.xz` is the
  complete source code.

## Chosen decisions for a later import proposal

- Keep the 0024 change documentation-only.
- Treat both components as `conditional` until a future source-import feature
  proves the blockers in this document.
- Prefer pinned local sources over system packages or remote services.
- Preserve the current dependency-free source install until the future import
  proves that any local C compilation remains offline and deterministic.
- Preserve normal table, JSON, Markdown, and inspect output unless a later
  feature explicitly shapes an opt-in provider surface.
- Preserve file-level Git-history evidence as product truth. Tree-sitter symbol
  evidence, if later implemented, must remain additive and inspect-oriented.

## Open blockers before source import

A future source-import feature must not close while any of these blockers remain
unresolved:

1. Select one canonical source identity for each component and record immutable
   commits, archive identities, and checksums.
2. Decide the minimal Tree-sitter core file set instead of importing the whole
   upstream repository by default.
3. Preserve the upstream MIT license text and copyright notice for both
   components.
4. Represent generated parser provenance honestly: either reproduce or verify
   the Zig `src/parser.c` from pinned grammar inputs and a pinned generator, or
   record a reviewed reason to trust the pinned generated file as upstream
   source.
5. Measure source-size impact, including the `5843608` byte Zig generated
   parser.
6. Measure local build impact after any C compilation is introduced.
7. Prove offline validation with only local repository inputs.
8. Prove no-provider table, JSON, Markdown, and inspect output remain
   byte-stable.
9. Keep provider execution, parser runtime, registry wiring, CLI flags, report
   fields, scoring, cache, tests, fixtures, CI, and release packaging out of the
   import unless a later approved feature explicitly includes them.

## Future `PROVENANCE.md` template

Each vendored component should include a `PROVENANCE.md` file beside the copied
source. The future import may refine wording, but it must preserve these fields.

```markdown
# Provenance for <component>

## Component

- Component name: <Tree-sitter core or tree-sitter-zig>
- Vendored path: <repo-relative path>
- Import decision state: <ready|conditional|blocked at import time>
- Import feature: <feature id>
- Import date: <YYYY-MM-DD>

## Upstream identity

- Upstream repository: <public upstream URL>
- Selected tag: <tag or none>
- Selected commit: <full commit hash>
- Source archive identity: <archive name or checkout description>
- Source archive SHA-256: <hex digest or not used with reason>
- Imported file list: <repo-relative list or manifest path>
- Excluded file classes: <classes and reasons>

## Generated-source provenance

- Generated files imported: <files or none>
- Grammar/source inputs: <files and selected revisions>
- Generator identity: <pinned local generator version or reviewed upstream
  artefact basis>
- Reproduction or verification evidence: <command transcript location or
  reviewed justification>
- Known limitations: <bounded caveats>

## License and notice

- Upstream license: <license name>
- License file copied to: <repo-relative path>
- Notice file copied to: <repo-relative path>
- Notice obligations reviewed by: <role or review id, not a person identity>
- Changes from upstream license or notice text: <none or explanation>

## Measurement

- Imported byte size: <bytes>
- Largest imported file: <path and bytes>
- Build-time delta: <measurement and command>
- No-provider output proof: <evidence path>
- Offline validation proof: <evidence path>

## Update policy

- Update owner role: <role>
- Required review before update: provenance, license, generated-source,
  source-size, build-impact, and no-provider stability.
- Floating branches or remote build inputs allowed: no.
```

## Future notice and attribution template

A later import should add or update a repository notice artefact with this
shape. The artefact must contain only public upstream attribution and
repo-relative paths.

```text
Tree-sitter vendored source notices

This repository vendors selected source files from the components below for
local, offline provider work. The copied sources remain under their upstream
licenses.

Component: Tree-sitter core
Upstream: https://github.com/tree-sitter/tree-sitter
Selected revision: <tag and full commit>
Vendored path: <repo-relative path>
License: MIT
Notice: Preserve the upstream MIT license text and copyright notice copied in
<repo-relative license path>.

Component: tree-sitter-zig
Upstream: https://github.com/tree-sitter-grammars/tree-sitter-zig
Selected revision: <tag and full commit>
Vendored path: <repo-relative path>
License: MIT
Notice: Preserve the upstream MIT license text and copyright notice copied in
<repo-relative license path>.

Generated-source note:
<One paragraph explaining whether generated parser files were reproduced from
pinned inputs or accepted as pinned upstream artefacts, with the evidence path.>
```

## Source-size and build-impact measurement plan

The future import must record measurements before it can close. Use commands
that operate on local repository files only.

### Required source-size measurements

- Total bytes added under each vendored component path.
- Largest ten files by byte size under the vendored component paths.
- Byte size of the Zig generated parser file.
- Total repository working-tree size before and after import, excluding the
  `.git` directory.

Suggested local commands:

```sh
find third_party/tree-sitter-core third_party/tree-sitter-zig -type f -print0 | xargs -0 wc -c
find third_party/tree-sitter-core third_party/tree-sitter-zig -type f -printf '%s %p\n' | sort -nr | head -10
wc -c third_party/tree-sitter-zig/<revision>/src/parser.c
du -sk --exclude=.git .
```

Planner review is required if any of these triggers occur:

- the Zig generated parser differs materially from the known `5843608` byte
  candidate without an explanation;
- a single imported file exceeds `6000000` bytes;
- total vendored source exceeds `8000000` bytes;
- the future import cannot explain why each large file is needed; or
- source-size measurement requires anything other than local files.

### Required build-impact measurements

- `zig build validate` before import.
- `zig build validate` after import.
- If C compilation is introduced, a clean-build timing before and after import.
- No-provider table, JSON, Markdown, and inspect output byte comparison before
  and after import.

Suggested local commands:

```sh
zig build validate
time -p zig build validate
cmp <before-table-output> <after-table-output>
cmp <before-json-output> <after-json-output>
cmp <before-markdown-output> <after-markdown-output>
cmp <before-inspect-output> <after-inspect-output>
```

Planner review is required if any of these triggers occur:

- `zig build validate` fails;
- build timing increases enough to affect normal source-install experience;
- no-provider output bytes differ;
- the build needs non-local inputs; or
- parser diagnostics expose paths, source text, or other private machine state.

## Import close-out gate

A future source-import feature may close only when all gate rows are satisfied:

| Gate | Required proof |
| --- | --- |
| Source identity | Immutable upstream identity and checksum are recorded for Tree-sitter core and tree-sitter-zig. |
| File set | Imported files match the approved bill of materials and excluded file classes are explained. |
| Provenance | Each component has `PROVENANCE.md` with all required fields. |
| License and notice | MIT license files and notice obligations are preserved for both components. |
| Generated parser | Zig `src/parser.c` provenance is reproduced, verified, or justified as a pinned upstream artefact. |
| Size | Source-size measurements are recorded and do not trigger unresolved planner review. |
| Build | Local validation passes without non-local build inputs. |
| No-provider stability | Existing no-provider outputs remain byte-stable. |
| Product boundary | No parser runtime, provider registry, CLI/report/schema/scoring/cache change, or background analysis is included unless explicitly shaped. |
| Privacy | Evidence uses repo-relative paths and contains no private machine paths, private repository locations, copied source text, unsanitised parser diagnostics, or person-level attribution. |

## Future requirements checklist

Before source import starts, the future feature should have an approved packet
that includes:

- exact vendored paths and file-set limits;
- source identity and checksum capture procedure;
- license and notice copy procedure;
- generated parser provenance procedure;
- source-size and build-impact measurement commands;
- no-provider output stability commands;
- offline validation evidence plan;
- rollback plan for removing vendored sources if a gate fails; and
- reviewer focus on local-first behaviour, provenance honesty, source size,
  license handling, and protected runtime surfaces.

## Recommendation for the next feature

Recommendation: further proof before source import.

The next feature should not be runtime integration. It should either:

1. perform a narrow source-import proof that resolves every blocker above and
   stops before parser runtime or provider behaviour; or
2. remain a further documentation/provenance proof if generated parser
   provenance, minimal core file selection, or source-size/build impact cannot
   be represented honestly yet.

Do not move to no-go today. Feature 0023 found a plausible local-first path, but
this gate keeps the state at `conditional` until the future feature proves
provenance, notice handling, source-size impact, offline validation, and
no-provider stability with actual imported sources.

## Validation record for Feature 0024

Feature 0024 is complete only if validation shows:

- this document is the only non-Flow artefact added or changed;
- `git diff --check` passes;
- `zig build validate` passes;
- changed paths stay within documentation and Flow handoff state;
- no `third_party`, source, test, fixture, tool, `build.zig`, or
  `build.zig.zon` paths change;
- no parser source, generated C, C build/linking, parser runtime, provider
  registry, CLI/report/schema/scoring/cache change is added;
- no online data-transfer path, usage-reporting path, server-side enrichment,
  or background execution is added; and
- this document contains no private paths, private repository locations, raw
  private output, copied source text, unsanitised parser diagnostics,
  commercial product strategy, predictive defect claims, quality-score claims,
  people-ranking claims, or maintainer-assessment claims.
