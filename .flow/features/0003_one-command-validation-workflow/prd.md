# Feature 0003 PRD: One-command validation workflow

## Purpose

Feature 0002 produced an executable file-level CLI spike, but its validation
ladder still lives partly in PRD prose, integration scripts, reviewer evidence,
and ad-hoc real-repository smoke commands.

Feature 0003 makes validation operational: future humans and agents should have
one canonical project-local command for full validation, plus an explicit
close-out mode for privacy-safe real-repository smoke evidence.

This is a developer workflow feature, not a new product capability.

## Source alignment

- Capability brief: `B001 Local-first hotspot intelligence CLI`.
- Depends on: Feature `0002 File-level CLI spike`.
- Existing fast gate: `zig build test`.
- Desired full gate: `zig build validate`.
- Active project constraint: implementation features need real-repository smoke
  validation once an executable exists.

## Requirements

### R1. Canonical validation command

Add a canonical validation command:

```bash
zig build validate
```

This is the command future Flow contracts, local developers, and agents should
use for full local validation. It may delegate implementation details to a small
helper such as `tools/validate.sh`, but the public project entrypoint must be the
Zig build step.

`zig build test` must remain available as the faster unit/integration fixture
gate. It must not become a hidden alias for every close-out smoke requirement.

### R2. Default validation ladder

The default validation command must run, or clearly report a portable equivalent
for, these rungs:

- `zig fmt --check build.zig src tests`;
- `zig build test`;
- `zig build`;
- `git diff --check`;
- shell syntax checks for project shell scripts such as `tools/*.sh` and
  `tests/*.sh`;
- deterministic fixture JSON proof;
- JSON validity checks;
- shallow and partial history assertions;
- privacy/path checks for default JSON output;
- bounded performance smoke on the medium fixture or a documented portable
  fallback.

The command must exit non-zero when a required rung fails.

### R3. Evidence summary

The validation workflow must print a concise, copyable evidence summary. The
summary should list validation rungs, pass/fail status, fallback tools used, and
real-repo smoke labels when applicable.

The summary must not include:

- absolute private paths;
- private repository names;
- raw private report dumps;
- source snippets from private repositories;
- author names or emails;
- remote URLs;
- telemetry identifiers.

### R4. Real-repo smoke default

Default validation must run a real-repository smoke against this repository once
an executable exists. It should verify both table and JSON output complete and
that default JSON uses project-relative paths.

This repo smoke may use a privacy-safe label such as `this-repo`.

### R5. Close-out mode for second real repo

Add an explicit close-out mode for implementation-feature final validation.
Preferred command shape:

```bash
zig build validate -Dcloseout=true \
  -Dsmoke-repo=<local-sibling-repo> \
  -Dsmoke-label=sibling-local-repo
```

Close-out mode must require either:

- a second local/sibling repository path and a privacy-safe label; or
- an explicit skip reason, for example `-Dsmoke-skip-reason=<reason>`.

It must not silently omit the second real-repo smoke target.

The validation workflow must never fetch, pull, clone, or contact a remote to
prepare the smoke target.

### R6. Privacy-safe smoke behaviour

Real-repository smoke must run table and JSON output, but the validation output
should record only compact evidence:

- privacy-safe repo label;
- whether table output completed;
- whether JSON output completed;
- result count or similar bounded summary;
- caveat summary;
- coarse elapsed time or fallback timing note.

Do not commit or print raw private report dumps by default.

### R7. Portable fallbacks

The workflow should prefer common local tools when available, but must degrade
with documented fallbacks:

- use Python JSON checks if `jq` is unavailable;
- use Python or allowlisted grep checks if `rg` is unavailable;
- use `/usr/bin/time -v` when available, otherwise `time -p`, shell elapsed
  seconds, or a clear timing fallback note.

Fallback substitutions must appear in the evidence summary.

### R8. Semantic privacy/local-first checks

Privacy and local-first checks should be semantic or allowlisted enough to avoid
false failures on safe documentation text such as "does not fetch".

The validation workflow should check runtime source and default output for the
relevant risk, not blindly fail because docs mention forbidden words as
non-goals.

### R9. Protected product behaviour

This feature should not change CLI product behaviour, scoring, Git history
semantics, output schema, or report copy unless validation exposes a concrete bug
that can be fixed within the existing Feature 0002 contract.

Any behaviour change must be covered by tests and called out for review.

### R10. Local-only defaults

The validation workflow must not introduce:

- network access;
- fetch, pull, push, clone, or remote enrichment;
- telemetry or crash upload;
- CI service dependency;
- provider runtimes;
- cache/database work;
- release automation or packaging.

### R11. Documentation

Update only brief public developer documentation, such as the README validation
section or a small docs file.

Docs should explain:

- `zig build test` as the fast gate;
- `zig build validate` as the full local gate;
- close-out mode with a sibling/local repo or skip reason;
- privacy-safe evidence expectations.

Public docs must stay visitor-facing. Do not add Flow process logs, hosted or
commercial strategy, bug-prediction claims, objective code-quality scoring, or
developer-ranking language.

### R12. Script side effects

Validation side effects must be limited to ignored fixtures, Zig cache/build
outputs, and temporary files. The command must not dirty tracked files in normal
operation.

## Edge cases

The validation workflow should account for:

- missing optional tools: `jq`, `rg`, `/usr/bin/time`;
- paths with spaces in the sibling smoke repo argument;
- missing or invalid sibling smoke repo in close-out mode;
- missing smoke label in close-out mode;
- explicit skip reason in close-out mode;
- dirty worktree before validation;
- generated fixtures already present or absent;
- repeated runs producing stable fixture JSON;
- safe docs containing words such as fetch, push, telemetry, or http.

## Packet plan

### P1. Canonical validation command

Add `zig build validate` and a helper script if useful. Cover fmt, fast tests,
build, diff check, and script syntax checks.

### P2. Evidence completeness checks

Expand validation to include deterministic JSON, JSON validity,
shallow/partial proof, semantic privacy/path checks, and bounded fixture
performance smoke with portable fallbacks.

### P3. Real-repo smoke mode and docs

Add close-out mode for this repo plus explicit sibling/local repo smoke, or an
explicit skip reason. Document usage without cluttering public docs with Flow
process detail.

## Verification

Close-out evidence should include:

```bash
zig build validate
zig build test
git diff --check
```

For close-out mode, use a suitable local repository selected at execution time:

```bash
zig build validate -Dcloseout=true \
  -Dsmoke-repo=<local-sibling-repo> \
  -Dsmoke-label=sibling-local-repo
```

If no suitable sibling/local repository exists, the runner must use the explicit
skip-reason path and record the reason:

```bash
zig build validate -Dcloseout=true -Dsmoke-skip-reason=<reason>
```

The reviewer should independently rerun the canonical command, inspect the
validation script, and confirm the evidence summary is privacy-safe.

Flow validation remains separate when Flow is available:

```bash
flow validate --target feature:0003 --format json
```

## Stop and reshape triggers

Stop and return to shaping if implementation appears to require:

- changing the public CLI product contract;
- changing scoring or Git parsing semantics beyond a small validation-discovered
  bug fix;
- adding dependencies solely for validation convenience;
- adding CI, release automation, packaging, cache, providers, or network access;
- committing private smoke targets, absolute paths, raw reports, or private repo
  names;
- making real-repo smoke depend on hidden local state without an explicit skip
  path;
- turning README into Flow process documentation.
