# Feature 0015: Cache feasibility spike

## Problem

Large-repo runs can be slow enough that cache is tempting, but current evidence
is not enough to prove cache is the smallest safe optimisation. A runtime cache
would add invalidation, privacy, schema, determinism, storage, and operator UX
risk before we know whether the bottleneck is Git execution, full-buffer log
capture, parsing, aggregation, co-change expansion, sorting, file stats, or
rendering.

This feature records the decision evidence first. It does not implement cache.

## Outcome

Produce a durable performance profile and cache decision record that a future
planner can use to decide whether to implement cache, streaming Git ingestion,
or another optimisation. The record must keep cache as a local-only performance
optimisation, never product truth.

## Requirements

- Do not implement runtime cache behaviour in this feature.
- Do not add persistent cache files, cache schema, database dependency, cache
  command, cache flag, cache metadata in report schemas, or default cache
  behaviour.
- Document that fresh local Git analysis remains canonical product truth.
- Document cache as an optional future optimisation only.
- Document allowed cached data candidates and forbidden cached data.
- Forbidden cached data must include source blobs, diffs, commit messages,
  author identities, absolute local paths, private repo names, remote URLs, raw
  sibling reports, telemetry data, and any uploaded or remotely enriched data.
- Document candidate invalidation inputs:
  - analysed HEAD or explicit Git range;
  - `--since` value;
  - selected scope;
  - include and exclude prefixes;
  - inspect target when relevant;
  - scoring version;
  - output-relevant configuration;
  - tool version;
  - cache schema version;
  - future provider version placeholders.
- Document candidate local cache location and operator controls, including a
  disable path and clear/status UX, without committing implementation.
- Compare at least these directions:
  - no cache, continue with progress and bounded history recipes;
  - metadata or result cache;
  - streaming Git ingestion;
  - full persistent cache.
- State which direction is recommended, deferred, or blocked and why.
- Include privacy-safe performance/profile evidence from this repository and
  one approved sibling/local repository.
- Sibling/local repository evidence must use the label `sibling-local-repo` and
  must not commit the real path, repository name, remote URL, author identity,
  commit message, source snippet, raw report, or raw private output.
- Distinguish measured evidence from unknowns. If the current CLI cannot split
  Git subprocess time from parsing and aggregation time, say so instead of
  inferring it.
- Do not add public benchmark claims beyond bounded feasibility observations.
- Do not add commercial, hosted, SaaS, pricing, sales, bug-prediction,
  objective quality-score, developer-ranking, or maintainer-judgement claims.

## Acceptance

- A durable docs artefact, such as `docs/performance-cache-decision.md`, records
  the performance profile and cache decision.
- The artefact states that cache is not product truth and that the tool must
  work without cache.
- The artefact records allowed and forbidden cached data.
- The artefact records candidate invalidation inputs.
- The artefact records candidate local cache location and operator controls.
- The artefact compares no-cache guidance, metadata/result cache, streaming Git
  ingestion, and full persistent cache.
- The artefact makes a clear recommendation for the next optimisation feature.
- The artefact includes this-repo evidence and sibling-local-repo evidence using
  only bounded counts, timings, command shapes, and caveats.
- The feature changes no runtime CLI behaviour, source code, tests, fixtures,
  build configuration, validation scripts, output schemas, scoring, Git
  traversal, providers, CI, release packaging, network, or telemetry behaviour.
- Close-out evidence includes `zig build validate`, `git diff --check`, and
  privacy/prohibited-content scans over changed docs.

## Edge cases and stop conditions

- Stop and return to shaping if implementing cache appears necessary to answer
  the decision question.
- Stop if performance evidence would require committing raw private output or an
  absolute private path.
- Stop if a proposal makes cache required for correctness or changes report
  semantics.
- Stop if invalidation cannot be stated for Git range/ref, options, tool
  version, schema version, and future provider version inputs.
- Stop if a proposed design needs network access, telemetry, background upload,
  remote enrichment, auto-fetch, SaaS, or hosted product assumptions.

## Verification

Run and record:

```sh
zig build validate
git diff --check
```

Also run privacy and prohibited-content scans over the changed docs. The scans
must confirm that no private sibling path/name, raw private report, remote URL,
author identity, commit message, source snippet, commercial strategy, bug
prediction, quality-score claim, or developer-ranking claim was introduced.

Close-out should include bounded performance/profile evidence for this repo and
`sibling-local-repo`. Raw reports do not belong in committed artefacts.
