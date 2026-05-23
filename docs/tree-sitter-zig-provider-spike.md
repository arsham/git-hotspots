# Tree-sitter Zig provider feasibility spike

This record is a documentation-only feasibility decision for a future
Tree-sitter Zig symbol provider. It preserves the current CLI and runtime: no
parser runtime, dependency, build graph, provider registry, CLI flag, report
schema, scoring, cache, network, telemetry, or background analysis is added by
this feature.

## Decision

Stop before runtime integration in this feature. A future implementation may
proceed only as a separate opt-in, inspect-oriented provider slice after it can
prove offline, pinned, license-reviewed parser sources and byte-stable
no-provider output.

The recommended future dependency path is to vendor pinned Tree-sitter core C
sources and pinned generated Zig grammar C sources only after license and notice
obligations are reviewed and recorded. The future provider must not depend on a
system Tree-sitter install, build-time network fetches, global packages, or a
remote parser service.

## Current dependency-free baseline

The current source-install baseline is intentionally small:

- `build.zig` builds the `git-hotspots` executable from local Zig sources.
- There is no `build.zig.zon` dependency manifest in the current source-install
  path.
- The supported install path remains local checkout plus `zig build`, as
  described in `README.md`.
- `zig build validate` runs the local validation workflow through
  `tools/validate.sh` without provider setup.
- Current table, JSON, and Markdown reports are file-level Git-history evidence
  and do not contain provider or symbol fields.

Any future Tree-sitter work must preserve this baseline for users who do not
explicitly opt in to provider inspection.

## Local feasibility evidence

Local inspection of the current provider seam shows that the repository already
has bounded data shapes for provider and current-symbol evidence in
`src/provider.zig`. Those shapes are synthetic and internal only; they do not
run a parser or alter CLI output today.

System Tree-sitter availability is not portable product evidence. A parser that
works because one developer has a local library, CLI, package manager install,
or generated grammar checkout does not prove that `git-hotspots` can build from
source offline or behave deterministically across platforms.

Current seam anchors:

| File | Symbol | Kind | Current range | Future mapping |
| --- | --- | --- | --- | --- |
| `src/provider.zig` | `ProviderEvidence` | type | lines 44-56 | Provider envelope: name, kind, version, contract version, config fingerprint, local input identity, freshness, failure, confidence, caveats, and provenance. |
| `src/provider.zig` | `CurrentSymbolEvidence` | type | lines 88-100 | Current symbol row: repo-relative path, symbol name, kind, current range, provider name, confidence, and caveats. |
| `src/provider.zig` | `validateRepoRelativePath` | function | starts at line 102 | Privacy boundary for repo-relative paths and bounded metadata. |
| `src/provider.zig` | `lessSymbol` | function | starts at line 118 | Deterministic ordering for current-symbol evidence. |

A future Tree-sitter Zig provider should fill `CurrentSymbolEvidence` values for
current working-tree Zig files and link each row to a `ProviderEvidence`
envelope. The first implementation should use line ranges unless byte ranges
are simpler to prove deterministic from the parser API.

## Provider envelope mapping

The future provider should populate the existing seam as follows:

- `ProviderEvidence.name`: `tree-sitter-zig` or another explicit provider name.
- `ProviderEvidence.kind`: `symbol`.
- `ProviderEvidence.version`: pinned Tree-sitter core and Zig grammar source
  identifiers, not a system package version.
- `ProviderEvidence.contract_version`: the existing provider contract version.
- `ProviderEvidence.config_fingerprint`: a stable digest of opt-in provider
  settings when settings affect output, otherwise `null`.
- `ProviderEvidence.input.identity`: local repository `HEAD`, file digest, or a
  bounded local input identity.
- `ProviderEvidence.freshness`: `fresh`, `stale`, `partial`, or `unknown`.
- `ProviderEvidence.failure`: `ok`, `unavailable`, `unsupported`, `failed`,
  `timed_out`, or `skipped`.
- `ProviderEvidence.confidence`: evidence-quality confidence only.
- `ProviderEvidence.caveats`: visible reasons for partial, ambiguous,
  unsupported, excluded, generated, stale, or failed evidence.
- `ProviderEvidence.provenance`: local-only provider and input labels.

Provider evidence must not include absolute paths, remotes, source snippets, raw
parser stderr, raw private reports, author identities, owner fields, or network
provenance.

## Symbol mapping plan

The future Tree-sitter Zig provider should limit the first runtime slice to
current working-tree Zig symbols:

- accept repo-relative `.zig` paths already selected by existing scope logic;
- parse only local working-tree file contents;
- map Tree-sitter captures or node kinds to `SymbolKind.function`,
  `SymbolKind.method`, `SymbolKind.type`, `SymbolKind.module`,
  `SymbolKind.variable`, or `SymbolKind.other`;
- emit symbol names only when the parser provides a stable name node;
- emit deterministic current line or byte ranges for each symbol;
- attach the provider name and provider envelope to every symbol row;
- add caveats for partial parse trees, generated or excluded files, unsupported
  constructs, missing names, and ambiguous ranges;
- leave file-level hotspot scoring, ranking, rename-lineage, co-change, and
  confidence logic unchanged.

Symbol evidence is current-only. Historical symbol lineage, symbol renames,
function moves, dependency propagation, multi-language parsing, and provider
registry work are separate features.

## Dependency strategy options considered

### Option A: no runtime parser in this feature

This is the chosen option for the current feature. It satisfies the feasibility
record requirement while preserving dependency-free source installs and current
runtime behaviour.

### Option B: rely on a system Tree-sitter install

Rejected for product behaviour. It is useful for local experiments but not for
portable evidence because versions, grammar availability, C ABI details, and
package names vary by platform.

### Option C: fetch Tree-sitter or grammar sources at build time

Rejected for the local-first default. Build-time network access would weaken
source-install reproducibility and violate the no-fetch baseline.

### Option D: vendor pinned Tree-sitter core and generated Zig grammar C sources

Recommended only for a future runtime provider feature after review. This keeps
build inputs local and pin-able, but it adds license, notice, source-size,
C-build, cross-platform, and maintenance obligations that are outside this
feature.

The future feature must record exact source revisions, generated-source
provenance, license files, notice text, and an offline build proof before
closing out.

### Option E: shell out to a Tree-sitter CLI

Rejected for the first product slice. A CLI dependency adds system-package and
version drift, complicates timeout handling, and makes source-install behaviour
less predictable than compiling pinned local sources.

## Risk assessment

| Risk | Assessment | Required mitigation before runtime work |
| --- | --- | --- |
| License and notice obligations | Unproven in this feature. | Review upstream Tree-sitter core and Zig grammar licenses before vendoring. |
| Offline build | Not proven until vendored sources are present. | Build with no network and no global parser package. |
| Source-install UX | C sources and generated grammar files can make builds slower or harder. | Keep provider opt-in and prove default `zig build` remains simple. |
| Cross-platform C build | Parser C sources may expose compiler or platform differences. | Validate on supported target set or stop before shipping. |
| Parser errors | Invalid or partial Zig is expected in working trees. | Represent errors through failure, freshness, confidence, and caveats. |
| Output semantics | Symbol rows could be mistaken for hotspot truth. | Keep provider output inspect-oriented and additive. |
| Privacy | Parser diagnostics can contain local paths or source snippets. | Sanitize or suppress raw stderr and scan reports. |

## First runtime surface

The intended first runtime surface is opt-in and inspect-oriented. It should not
run by default, should not add provider fields to normal reports, and should not
change file-level scoring or ranking.

A safe future slice would expose a narrow local inspection path for one Zig file
or for files already selected by an explicit inspect workflow. The output should
make provider state visible and clearly say that symbols are current working-tree
evidence only. If no provider is available, existing no-provider table, JSON,
and Markdown outputs must remain byte-stable.

## Stop conditions for the future provider

Stop before runtime integration if any of these conditions hold:

- generated Zig grammar sources cannot be pinned and built offline with Zig
  0.16.0;
- implementation requires build-time network fetches or global system packages;
- license or notice obligations are unclear;
- provider output would require scoring or report-schema commitments beyond the
  shaped spike;
- parser failures cannot be represented through the provider failure and caveat
  model;
- source-install UX becomes materially worse than the current `zig build`
  workflow;
- output would imply symbol-history truth, bug prediction, code-quality scoring,
  developer ranking, maintainer judgement, or ownership assessment;
- the implementation needs cache, telemetry, upload, remote enrichment, or
  background provider execution;
- deterministic ranges cannot be proven for the same repo, ref, config, and
  provider version.

## Validation matrix for a future runtime provider

A future runtime provider feature cannot close out until it records fresh
evidence for this matrix:

| Area | Required proof |
| --- | --- |
| Formatting | `git diff --check`. |
| Zig formatting | `zig fmt --check build.zig src tests` where applicable. |
| Unit and integration tests | `zig build test`. |
| Full local validation | `zig build validate`. |
| Real-repo smoke | This repo plus a privacy-safe sibling or local repo label when available. |
| No-provider stability | Byte-stable table, JSON, and Markdown outputs without provider execution. |
| Provider determinism | Same repo, ref, config, and tool version produce the same provider output. |
| Fixture coverage | Zig functions, methods, types, modules, nested symbols, invalid or partial Zig, empty files, unsupported files, and deterministic ranges. |
| Degradation | `unavailable`, `unsupported`, `failed`, `timed_out`, `skipped`, `stale`, `partial`, and `unknown` states are visible. |
| Privacy | Scan for absolute paths, remotes, source snippets, raw parser stderr, raw private reports, author identities, and private repo names. |
| Local-first behaviour | Scan for fetch, upload, telemetry, remote enrichment, and background provider execution. |

## Validation for this documentation-only feature

This feature should close out only if:

- only documentation and Flow handoff metadata changed;
- `git diff --check` passes;
- `zig build validate` passes;
- scans show no Tree-sitter sources, grammar sources, `build.zig.zon`, C
  build/linking, parser runtime, provider registry, CLI flags, report schema
  fields, scoring changes, cache, fixtures, network, telemetry, upload, remote
  enrichment, or background analysis were added;
- the new document contains no raw private paths, remotes, source snippets, raw
  private report output, author identities, commercial strategy, hosted-product
  claims, bug-prediction claims, code-quality scoring claims, developer ranking,
  or maintainer judgement.

## Recommended next implementation slice

If the future dependency review is safe, implement one narrow feature:

1. Add pinned, license-reviewed Tree-sitter core and generated Zig grammar C
   sources as local build inputs.
2. Add the minimal Zig wrapper needed to parse current working-tree Zig files.
3. Emit `CurrentSymbolEvidence` for one opt-in inspect path only.
4. Surface provider envelope, freshness, failure, confidence, and caveats in an
   inspect-only path.
5. Prove no-provider output remains byte-stable and that provider output is
   deterministic.

If any dependency, license, offline-build, source-install, privacy, or semantic
boundary remains unresolved, the next implementation slice should remain a
non-runtime dependency review instead of adding parser code.
