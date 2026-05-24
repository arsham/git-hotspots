# PRD: Tree-sitter Go grammar admission review

## Summary

Create a documentation-only Go grammar admission review before importing or
running a Go Tree-sitter provider. The review decides whether `tree-sitter-go`
is ready for a later source-import feature and records the provenance, license,
query, validation, and build-supply-chain gates that future Go work must satisfy.

This feature must not add Go parser sources, build integration, runtime provider
behaviour, CLI flags, report schema fields, scoring changes, cache behaviour,
network activity, or CI changes.

## Problem

The multi-language strategy identifies Go as the preferred first non-Zig
Tree-sitter language, but the repository has no Go grammar provenance, license
review, generated-source basis, vendoring plan, source-size measurement, build
compatibility proof, or Go query fixture plan. Importing or running Go support
without that admission evidence would weaken the local-first supply-chain and
public-claim boundary.

## Outcome

A public, repo-safe Go admission document records the candidate grammar facts,
blockers, future import gates, and decision state for `tree-sitter-go`. Future
source-import or runtime Go provider features can proceed only from this durable
admission record.

## Requirements

### R1 Documentation-only scope

- Add one documentation artefact: `docs/tree-sitter-go-grammar-admission.md`.
- The feature may update Flow planning state only in addition to that document.
- Do not change `third_party/`, `src/`, `tests/`, `fixtures/`, `build.zig`,
  `build.zig.zon`, `.github/`, `tools/validate.sh`, CLI flags, report schemas,
  scoring, cache, provider runtime, provider registry, CI, release, or package
  behaviour.

### R2 Runtime truth and public claims

- State clearly that Go support is not implemented yet.
- State clearly that current runtime Tree-sitter support remains Zig-only.
- State that Go grammar admission is a prerequisite gate before source import,
  build proof, symbol extraction, or inspect output.
- Preserve file-level Git evidence as product truth.
- Describe future Go symbols only as optional, current-only, inspect-oriented,
  additive, caveated provider evidence.
- Avoid claims that hotspots predict bugs, score code quality, rank developers,
  judge maintainers, or prove ownership or productivity.

### R3 Candidate grammar identity

The document must record a `tree-sitter-go` candidate section with:

- public upstream URL;
- immutable tag or revision to investigate;
- full commit hash if selected;
- canonical source identity candidate, such as archive or pinned checkout;
- checksum evidence requirement;
- proposed repo-relative vendored path;
- imported file BOM expectations;
- excluded file-class expectations.

If any identity fact is not yet proven, the document must mark it as a blocker
or required future evidence instead of guessing.

### R4 Tree-sitter core compatibility

- State that Tree-sitter core is already vendored/proven for the current Zig
  provider path.
- Require a future Go import to prove compatibility with the existing vendored
  core ABI/language-version.
- State that a Tree-sitter core update requires a separate shaped feature unless
  explicitly included in a later import feature.

### R5 License and notice review

The document must require a future Go source-import feature to:

- identify upstream license from authoritative upstream files;
- preserve license text and copyright notices;
- update repository third-party notices as needed;
- reject missing, changed, ambiguous, or incompatible license/notice facts.

### R6 Generated parser provenance

The document must require future Go source import to identify generated parser or
scanner sources and record:

- grammar/source inputs;
- generator identity or reviewed upstream artefact basis;
- whether generated files are reproduced, verified, or accepted as pinned
  upstream artefacts with reviewed justification;
- no dependency on global Tree-sitter CLI, package-manager fetches, or build-time
  generation for product builds.

### R7 Build supply-chain and local-first gates

The document must require future Go work to preserve:

- no build-time network fetches;
- no Git submodules;
- no system or global parser packages for product runtime/build;
- no package-manager resolution in product runtime/build;
- no remote parser service, telemetry, upload, remote enrichment, or background
  provider execution;
- future build changes may compile only local pinned sources.

### R8 Source-size and build-impact gates

The document must require future Go source import/build proof to record:

- bytes added under the proposed Go grammar path;
- largest files and generated parser/scanner sizes;
- build-impact evidence if any C compilation is introduced;
- planner review if size/build deltas are unexplained or materially affect
  source-install experience.

### R9 Query and fixture readiness

The document must outline a future Go built-in query plan covering at least:

- packages;
- functions;
- methods;
- structs;
- interfaces;
- constants and variables only if stable enough for the first Go provider.

It must require future fixtures for generated files, build tags, cgo-adjacent
files, invalid or partial files, empty files, deterministic ordering and ranges,
and unsupported-file behaviour. It must say not to import highlight queries
blindly as product symbol queries.

### R10 Future sequencing decision

The document must end with a decision state such as `conditional_go`,
`ready_for_import`, or `blocked`, plus named blockers. For this feature, the
default expected result is `conditional_go` unless evidence proves otherwise.

The document must explicitly defer:

- Go source import;
- Go offline build proof;
- Go extraction proof;
- inspect-only Go symbol output;
- custom user query execution;
- LSP integration.

## Acceptance criteria

- `docs/tree-sitter-go-grammar-admission.md` exists and is the only non-Flow
  artefact added or changed.
- The document records the Go admission gates listed in Requirements R2-R10.
- The document does not claim Go runtime support exists.
- The document does not change or imply changes to CLI, report schemas, scoring,
  provider runtime, registry, cache, build, CI, or third-party source state.
- The document uses repo-relative paths and public upstream identifiers only.
- The document contains no private paths, private repo names, raw parser stderr,
  source snippets, remotes, author identities, raw private reports, commercial
  strategy, bug prediction, code-quality scoring, developer ranking, or
  maintainer judgement.

## Edge cases

- If upstream Go grammar identity cannot be selected, record `blocked` or a
  named blocker rather than inventing a candidate.
- If generated parser provenance cannot be reproduced or reviewed, record it as
  a future import blocker.
- If the Go grammar requires a newer Tree-sitter core than the vendored core,
  require a separate core-update feature before import.
- If Go query semantics require custom user queries to be useful, defer custom
  query execution to a separate safety-contract feature.

## Verification

Close-out must prove:

```sh
git diff --check
zig build validate
```

Optional CI-parity proof may also run:

```sh
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
```

Close-out scans must prove:

- changed paths are limited to docs and Flow state;
- no `tree-sitter-go` source is added under `third_party/`;
- no runtime, build, provider registry, CLI, schema, scoring, cache, CI, or
  release behaviour changes;
- no network, telemetry, upload, remote enrichment, package-manager, global
  parser, or background provider behaviour is introduced;
- public docs do not overclaim Go support or make prohibited claims.
