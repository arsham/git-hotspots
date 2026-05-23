# Tree-sitter dependency review and vendoring plan

This is a documentation-only dependency review for a future Tree-sitter Zig
provider. It records candidate facts, separates them from decisions, and stops
before any vendored source, generated grammar source, build graph change,
parser runtime, provider registry, CLI flag, report schema, scoring, cache,
network runtime, telemetry, upload, remote enrichment, or background analysis.

## Current baseline to preserve

The current source install stays dependency-free for provider work:

- `zig build` builds from the repository's local Zig sources.
- There is no `build.zig.zon` in the source-install path.
- `zig build validate` runs local validation without provider setup.
- Normal table, JSON, and Markdown reports remain file-level Git-history
  evidence and do not include provider or symbol fields.

A future Tree-sitter provider must preserve byte-stable no-provider output and
must be opt-in, local-only, and inspect-oriented.

## Candidate facts

These facts were collected from public upstream metadata on 2026-05-23. They
are not product decisions by themselves.

### Tree-sitter core

| Field | Candidate fact |
| --- | --- |
| Upstream | `https://github.com/tree-sitter/tree-sitter` |
| Candidate tag | `v0.26.9` |
| Candidate commit | `7f534862c3ec939c3a6ee147f7600ef5c1bf900f` |
| Source archive identity | GitHub source tarball for tag `v0.26.9`; observed size `914894` bytes; observed SHA-256 `849954d8d3054dbba4b55378f0df7aec804e3516ee55bf7967224e033215611e` |
| License | MIT, according to upstream `LICENSE` at the candidate tag |
| Notice obligation | Preserve the upstream MIT license text and copyright notice in any vendored copy |
| Relevant source area | C runtime and public headers under upstream `lib/src` and `lib/include` |
| ABI note | `TREE_SITTER_LANGUAGE_VERSION` is `15`; minimum compatible language version is `13` at this tag |
| Release asset note | CLI and binary release assets publish SHA-256 digests, but those binaries are not candidates for vendoring |

The GitHub-generated source tarball checksum is an observed review checksum,
not a long-term supply-chain guarantee. A future vendoring feature should prefer
a pinned Git commit checkout or a separately mirrored source archive whose
checksum is recorded in the repository review artefact.

### Zig grammar source

| Field | Candidate fact |
| --- | --- |
| Upstream | `https://github.com/tree-sitter-grammars/tree-sitter-zig` |
| Candidate tag | `v1.1.2` |
| Candidate commit | `b670c8df85a1568f498aa5c8cae42f51a90473c0` |
| Complete release source | Release asset `tree-sitter-zig.tar.xz`; observed size `114816` bytes; observed SHA-256 `80cbc2cae284b539930f9958003f8f28d4c056ddc3bed912f61bf64e7d6fd680` |
| GitHub tarball identity | GitHub source tarball for tag `v1.1.2`; observed size `264687` bytes; observed SHA-256 `853caeac036440f39ab1fdb2f395d994ff4295a7adec67b2dd65f13b948da0d1` |
| License | MIT, according to repository metadata, `tree-sitter.json`, `package.json`, and upstream `LICENSE` at the candidate tag |
| Notice obligation | Preserve the upstream MIT license text and copyright notice in any vendored copy |
| Generated parser file | `src/parser.c`, Git blob `cb09604e5dac45c2bd599e3bdc509411ea6ed2a1`, size `5843608` bytes |
| Grammar source files | `grammar.js`, `src/grammar.json`, `src/node-types.json`, and query files |
| Generation metadata | `package.json` declares `tree-sitter-cli` development dependency `^0.24.5`; release notes say the `tree-sitter-zig.tar.xz` asset is the complete source code |

Generated-source provenance is only partially proven by public metadata. Before
vendoring, a separate feature must reproduce or otherwise verify that the
selected `src/parser.c` corresponds to the selected grammar sources and a pinned
Tree-sitter CLI version. If reproduction is not practical, that feature must
record why the generated file is acceptable as a pinned upstream artefact.

## Bill-of-materials candidate

The candidate bill of materials for a later vendored-source import is:

| Component | Include | Exclude |
| --- | --- | --- |
| Tree-sitter core C runtime | Minimal C runtime files and public headers required by `TSParser`, `TSTree`, `TSNode`, and `TSQuery` use | Tree-sitter CLI binaries, npm package metadata, web/wasm runtime unless explicitly needed later |
| Zig grammar | Pinned `src/parser.c`, `src/grammar.json`, `src/node-types.json`, query files needed for symbol captures, `tree-sitter.json`, and license file | Node, Python, Go, Rust, Swift, package-manager build wrappers, prebuilds, wasm asset unless explicitly needed later |
| Project wrapper | Future Zig wrapper and tests in a separate feature | Any wrapper, runtime parser, registry, CLI flag, schema field, scoring, or cache change in this feature |

The source-size risk is concentrated in the Zig grammar generated parser:
`src/parser.c` is about 5.8 MB at the candidate tag. That size may affect
source checkout size, compile time, and review burden. A future import should
measure source-install impact before closing.

## Expected vendoring layout

If a later feature proceeds, keep vendored material narrow and auditable. A
candidate layout is:

```text
third_party/tree-sitter-core/<version-or-commit>/
  LICENSE
  lib/include/tree_sitter/api.h
  lib/src/...
third_party/tree-sitter-zig/<version-or-commit>/
  LICENSE
  tree-sitter.json
  grammar.js
  queries/...
  src/grammar.json
  src/node-types.json
  src/parser.c
  PROVENANCE.md
```

The future `PROVENANCE.md` should record upstream URLs, immutable commits,
archive checksums, exact files imported, generated-source verification, license
and notice handling, and update instructions. The layout must not rely on Git
submodules, build-time fetches, global packages, or remote parser services.

## Strategy comparison

| Strategy | Decision | Reason |
| --- | --- | --- |
| System packages | Reject for product runtime | Package names, versions, ABI details, and installed grammars vary by platform; this is not portable source-install evidence. |
| Build-time fetches | Reject | Fetching source during build would violate local-first and offline-build expectations. |
| Tree-sitter CLI shell-out | Reject for first product slice | It introduces global tool/version drift, timeout and stderr sanitisation work, and non-portable source installs. |
| Vendored pinned local sources | Conditional go | This is the only reviewed path that can remain local-first and offline, but it needs separate vendoring, license, provenance, and build proof. |
| Deferral | Keep available | If provenance, source-size, or build risk stays unresolved, defer runtime integration and keep provider work documentation-only. |

## Update policy

A future update must be explicit, reviewable, and offline-verifiable:

1. Select new immutable commits or tags for Tree-sitter core and the Zig
   grammar.
2. Record source archive or checkout identities and checksums.
3. Compare license files and notice obligations before importing.
4. Reproduce or verify generated grammar files, especially `src/parser.c`.
5. Measure source-size and build-time impact.
6. Prove `zig build validate` and no-provider report bytes remain unchanged.
7. Keep provider behaviour opt-in and inspect-oriented.

Do not update through floating branches, package-manager resolution, submodules,
or build-time network access.

## Acceptance requirements for a future vendored-source import

A later vendoring feature cannot close until it proves:

- vendored sources are limited to the approved bill of materials;
- exact upstream commits, source identities, and checksums are recorded;
- MIT license files and required notices are preserved;
- generated grammar provenance is reproduced or explicitly justified;
- no build-time network, submodule, global parser package, or remote service is
  required;
- `build.zig` changes, if any, compile only local pinned sources;
- normal no-provider table, JSON, and Markdown outputs remain byte-stable;
- source-install size and compile-time impact are measured and acceptable; and
- no runtime provider, CLI, report, scoring, cache, or registry behaviour is
  added unless that exact behaviour is shaped in the same later feature.

## Acceptance requirements for a future offline runtime proof

A later provider runtime proof cannot close until it proves:

- `zig build validate` passes with no network and no global parser dependency;
- the provider is opt-in and inspect-oriented;
- provider output is current working-tree symbol evidence only;
- provider failures become visible caveats without hiding file-level Git
  evidence;
- normal no-provider reports remain byte-stable;
- parser diagnostics are sanitised or suppressed before user-visible reports;
- provider evidence uses repo-relative paths and bounded local provenance; and
- confidence describes evidence quality only, not source health or people.

## Recommendation

Recommendation: `conditional_go`.

Proceed to a separate vendored-source import feature only after the blockers
below are resolved. Do not add parser code, generated C, C compilation/linking,
provider runtime, CLI flags, report fields, scoring, cache, or registry changes
in this documentation-only feature.

### Blockers and required evidence before vendoring

- Reproduce or verify the Zig grammar `src/parser.c` from pinned grammar
  sources and an exact Tree-sitter CLI version, or record a reviewed reason to
  trust the pinned generated file as upstream source.
- Decide whether to use the Zig grammar release asset or a pinned Git checkout;
  record one canonical source identity and checksum for import.
- Define the minimal Tree-sitter core file set instead of importing the full
  repository by default.
- Record a future notice file that preserves both upstream MIT license notices
  without adding private or irrelevant metadata.
- Measure the source-size and compile-time impact of the large generated Zig
  parser file.
- Prove an offline build with no build-time network, no submodule checkout, and
  no global parser package.
- Prove byte-stable no-provider output before adding any opt-in provider path.

If any blocker remains unresolved in the next feature, keep the decision at
`conditional_go` or move to `no_go` for runtime integration.

## Validation record for this feature

This feature intentionally changes only documentation and Flow handoff state.
It adds no vendored sources, no generated grammar sources, no build dependency,
no parser runtime, no provider registry, no CLI/report/schema/scoring/cache
change, no network runtime, no telemetry, no upload, no remote enrichment, and
no background analysis.
