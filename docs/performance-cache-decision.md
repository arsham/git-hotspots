# Performance profile and cache decision

Feature 0015 records a bounded performance profile and cache decision for the
current public alpha. It intentionally changes no runtime CLI behaviour, source
code, tests, fixtures, build configuration, validation scripts, report schemas,
scoring, Git traversal, providers, CI, release packaging, network behaviour, or
telemetry behaviour.

## Decision summary

Recommendation: implement streaming Git ingestion next, before any persistent
cache. The current evidence shows large-repository runs are slow enough to
justify an optimisation feature, but the CLI does not yet isolate Git subprocess
cost from parse, aggregate, co-change, score, and render cost. Streaming the Git
history input is the next safest optimisation because it can reduce peak work and
improve observability without making cached data part of product truth.

Deferred: metadata or result caching remains a future option after streaming and
instrumentation clarify the bottleneck. Blocked for now: a full persistent cache,
because it adds invalidation, privacy, and operator-control surface area before
there is enough measured evidence that a cache is the right first optimisation.

Cache, if added later, must be an optional performance optimisation only. Fresh
local Git analysis remains canonical product truth, and the tool must work
without cache.

## Privacy and product-truth boundaries

Allowed future cached-data candidates:

- derived per-file counters, such as change counts, additions, deletions,
  recency inputs, co-change counts, and bounded confidence inputs;
- output-independent Git history metadata needed to avoid repeated local work;
- result summaries for an exact analysed range, option set, tool version, and
  cache schema version;
- cache bookkeeping such as schema version, creation time, and invalidation
  inputs.

Forbidden cached data:

- source blobs;
- diffs;
- commit messages;
- author identities;
- absolute local paths;
- private repository names;
- remote URLs;
- raw sibling reports;
- telemetry data;
- uploaded or remotely enriched data.

A future cache must not fetch, push, upload, enrich remotely, contact remotes,
or make background network requests. It must not change report semantics,
scoring truth, or the meaning of a hotspot.

## Candidate cache identity and invalidation inputs

A future cache key should include every input that can affect output-relevant
results:

- analysed HEAD or explicit Git range;
- `--since` value;
- selected scope;
- include and exclude prefixes;
- inspect target when relevant;
- scoring version;
- output-relevant configuration;
- tool version;
- cache schema version;
- future provider-version placeholders.

The invalidation rule should be conservative: if any key input differs, treat
the cached entry as unavailable and run fresh local analysis. If provider output
is added later, provider name, version, configuration, freshness, and failure
state should become part of the key before provider-derived data can be reused.

## Candidate storage and operator controls

Candidate local cache location: an operating-system cache directory scoped to
`git-hotspots`, with repository entries keyed by a privacy-preserving repository
identity rather than by an absolute path or repository name. The exact location
and key format should be decided in the cache implementation feature, not here.

Candidate operator controls, without committing implementation:

- disable path: a flag or environment setting that forces fresh analysis and
  ignores cache reads and writes;
- clear UX: a command or documented operation that removes local cache entries;
- status UX: a command or report section that explains whether a run used fresh
  analysis or an optional cache entry;
- conservative default: the CLI must remain correct and usable when cache is
  disabled, missing, stale, or corrupt.

## Alternatives compared

| Direction | Status | Rationale |
| --- | --- | --- |
| No cache, continue with progress and bounded history recipes | Available now | Preserves the simplest local-first model. It is still useful for small repositories and scoped exploratory runs, but it does not address repeated large-repository latency. |
| Metadata or result cache | Deferred | Could speed repeated identical runs, but it needs precise invalidation, privacy-safe keys, operator controls, and proof that repeated-run latency is the priority. |
| Streaming Git ingestion | Recommended next | Keeps fresh local Git analysis as truth while creating a seam to measure Git subprocess, parse, aggregate, co-change, and render phases separately. It can reduce memory and latency risk without adding cache correctness semantics. |
| Full persistent cache | Blocked for now | Too much storage, schema, privacy, invalidation, and UX surface for the current evidence. Reconsider only after streaming and instrumentation identify repeated local work that is safe to reuse. |

## Privacy-safe performance profile

The profile used the current CLI and committed only bounded timings, counts,
command shapes, and caveats. Raw reports are not committed.

Run context:

- Tool version: `git-hotspots 0.1.0-alpha.5`.
- Timing method: shell elapsed time around existing CLI commands.
- This repository: 44 analysed commits and 64 tracked files at collection time.
- `sibling-local-repo`: 1521 analysed commits and 2840 tracked files at
  collection time.

Command shapes exercised:

```sh
zig build
./zig-out/bin/git-hotspots --repo . --limit 10 --format table
./zig-out/bin/git-hotspots --repo . --scope project --limit 10 --format markdown
./zig-out/bin/git-hotspots --repo <sibling-local-repo> --limit 10 --format table
./zig-out/bin/git-hotspots --repo <sibling-local-repo> --progress --limit 10 --format markdown
```

Bounded observations:

| Label | Command shape | Elapsed | Output count | Caveat |
| --- | --- | ---: | ---: | --- |
| this-repo | full table, limit 10 | 0.068s | 16 lines | Small repository timing only; not a benchmark claim. |
| this-repo | project Markdown, limit 10 | 0.074s | 267 lines | Project scope excludes workflow metadata by supported prefix rules. |
| `sibling-local-repo` | full table, limit 10 | 66.554s | not committed | Large local run confirms latency pressure without exposing raw output. |
| `sibling-local-repo` | progress Markdown, limit 10 | 67.488s | 267 lines and 5 progress lines | Progress is useful but does not reduce elapsed time. |

Measured now:

- end-to-end local elapsed time for selected command shapes;
- analysed commit and tracked-file counts;
- bounded output and progress-line counts.

Unknown with the current CLI:

- Git subprocess time versus parser time;
- aggregation and co-change time;
- scoring time;
- render time;
- memory pressure and allocation profile;
- cold versus repeated-run behaviour under a defined benchmark harness.

Because those phase timings are not separately instrumented, this decision does
not infer the dominant bottleneck. The next optimisation feature should add the
streaming seam and measurement points needed to make that distinction.

## Next implementation boundary

The next optimisation feature should implement streaming Git ingestion and phase
instrumentation only. It should not add persistent cache storage in the same
step. Acceptance for that feature should include privacy-safe timing evidence
that distinguishes Git subprocess, parse, aggregate/co-change, score, and render
phases where practical.

After streaming and instrumentation land, a separate cache feature can decide
whether metadata/result cache is still justified and can reuse the privacy,
invalidation, storage, and operator-control constraints recorded here.

## Validation evidence

Commands required for this feature:

```sh
zig build validate
git diff --check
privacy/prohibited-content scan over docs/performance-cache-decision.md
```

Validation observations recorded during implementation:

- `zig build validate`: pass.
- `git diff --check`: pass.
- Privacy/prohibited-content scans over this document: pass.
- No runtime cache, persistent cache files, cache schema, database dependency,
  cache command, cache flag, report metadata, scoring change, Git traversal
  change, provider, CI, release packaging, network behaviour, or telemetry
  behaviour was added.
