# PRD: Tree-sitter vendoring readiness proof

## Problem

Feature 0023 recorded a conditional-go for a future Tree-sitter Zig provider,
but it also left blockers before vendored sources should enter the repository:
parser provenance, canonical source identity, minimal Tree-sitter core file
selection, license and notice handling, source-size impact, offline build proof,
and byte-stable no-provider output. Importing `third_party/` sources now would
commit a large generated parser before those gates are concrete enough.

## Outcome

Produce a documentation-only vendoring readiness artefact that turns the 0023
conditional-go into a concrete import gate. The artefact must define the
provenance template, notice template, source-size and build-impact measurement
plan, canonical source choices or unresolved blockers, and the exact go/no-go
criteria for a later vendored-source import feature.

This feature must not import parser sources or change build/runtime behaviour.

## Requirements

### Scope and artefact

- Add or update a focused readiness artefact, expected path:
  `docs/tree-sitter-vendoring-readiness.md`.
- The artefact must explicitly say that 0024 is a readiness gate, not a
  vendored-source import.
- The artefact must explain why actual source import remains a separate feature.
- The artefact must cover Tree-sitter core and the Zig grammar candidate from
  `docs/tree-sitter-dependency-vendoring-plan.md`.
- The artefact must distinguish known facts, chosen decisions, open blockers,
  and future requirements.

### Provenance template

The artefact must define a reusable future `PROVENANCE.md` template for each
vendored component. The template must include fields for:

- component name;
- upstream URL;
- immutable tag or commit;
- source archive or checkout identity;
- SHA-256 checksum or per-file checksum manifest;
- exact imported file list;
- generated-file provenance;
- local vendoring path;
- update procedure;
- verification commands;
- reviewer notes and unresolved risks.

### Notice and license template

The artefact must define a future notice or attribution template that preserves
MIT license obligations for Tree-sitter core and tree-sitter-zig. The template
must include:

- upstream project name;
- upstream URL;
- SPDX identifier;
- preserved copyright and license notice;
- local vendoring path;
- whether generated files are included;
- instruction not to include private/local metadata.

### Source-size and build-impact plan

The artefact must record the candidate source-size facts already known from
0023, including the large generated Zig parser size. It must define the
measurement commands and thresholds a future import feature must run before
close-out, including:

- current repository tree size before import;
- imported third-party byte count;
- file count;
- largest imported files;
- generated parser byte count;
- cold `zig build`, `zig build test`, and `zig build validate` timings;
- acceptable threshold or planner-review trigger for excessive size or build
  time.

### Canonical source decision state

The artefact must record one of these states for each component:

- `ready`: canonical source identity is selected and import can proceed;
- `conditional`: source identity is plausible but named blockers remain;
- `blocked`: import must not proceed.

If any component remains conditional or blocked, the artefact must list exact
blockers and required evidence before import.

### Future import gate

The artefact must define the close-out gate for a later vendored-source import
feature. That gate must require:

- no build-time network;
- no submodules;
- no global Tree-sitter CLI, system library, package manager, or remote parser
  service;
- preserved MIT license and notice files;
- recorded provenance for every imported file;
- byte-stable no-provider table, JSON, Markdown, and inspect outputs;
- no runtime provider behaviour, CLI flags, report schema fields, scoring,
  cache, provider registry, telemetry, upload, or remote enrichment unless a
  later feature explicitly shapes it.

### Non-goals

- No `third_party/` source import.
- No Tree-sitter core source files.
- No tree-sitter-zig grammar source or generated C files.
- No `build.zig.zon`.
- No `build.zig` C compilation or linking change.
- No parser wrapper or parser runtime.
- No provider registry.
- No CLI flags.
- No report schema changes.
- No scoring, ranking, cache, test fixture, CI, or release packaging changes.
- No network runtime, telemetry, upload, remote enrichment, or background
  analysis.

## Edge cases and stop conditions

Stop or record a blocker if:

- the readiness artefact cannot name exact future provenance fields;
- MIT license or notice handling remains unclear;
- generated parser provenance cannot be represented honestly;
- source-size impact cannot be estimated from current known facts;
- future import gates would require network, submodules, global packages, or
  system parser dependencies;
- proving future import safety would require adding actual vendored sources or
  build changes in this feature;
- the artefact would need private paths, private remotes, raw private output,
  source snippets, author identities, commercial strategy, hosted-product
  claims, bug-prediction claims, code-quality scoring, developer ranking, or
  maintainer judgement.

## Verification

Close-out requires:

- `git diff --check` passes;
- `zig build validate` passes;
- changed-path scan proves only docs and Flow state changed;
- no `third_party/`, `build.zig`, `build.zig.zon`, `src/`, `tests/`,
  `fixtures/`, `tools/`, parser sources, grammar sources, generated C,
  provider registry, CLI/report/schema/scoring/cache changes were added;
- no-network scan finds no fetch, upload, telemetry, remote enrichment,
  background analysis, submodule workflow, build-time fetch, `curl`, `wget`,
  `git clone`, npm, npx, pnpm, yarn, or global parser command added;
- privacy/prohibited-claim scan finds no absolute private paths, private
  remotes, raw private output, source snippets, raw parser stderr, author
  identities, hosted/pricing/sales strategy, bug-prediction, quality-score,
  developer-ranking, or maintainer-judgement claims;
- the artefact explicitly recommends the next feature as either source import,
  further proof, or no-go, with blockers if not source import.

Real-repo smoke beyond the existing `zig build validate` self-repo smoke is not
required because this feature is documentation-only and changes no runtime or
build behaviour.
