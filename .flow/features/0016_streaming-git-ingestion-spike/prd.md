# Feature 0016: Streaming Git ingestion spike

## Problem

Large-repository runs currently collect the full `git log --numstat` output
before parsing it. Feature 0015 recorded that large local runs can be slow and
that the current CLI cannot separate Git subprocess/read time from parse,
aggregate, co-change, score, and render time. Persistent cache is premature
until the ingestion and measurement seam is improved.

## Outcome

Stream the existing Git history input into the current aggregation semantics and
record privacy-safe phase evidence, while preserving every report output
contract. The feature must reduce the need to retain the whole Git log output
before parsing, but it must not add cache or change product truth.

## Requirements

- Replace the monolithic `git log --numstat` stdout-buffer ingestion path with a
  streaming ingestion seam.
- Keep the existing Git history command semantics equivalent to the current
  command:
  `git log --format=%H%x09%ct --numstat --find-renames=40%` plus the existing
  repository and range options.
- Preserve table, JSON, and Markdown stdout byte-for-byte for existing fixture
  outputs unless an intentional and documented fixture update is required for a
  bug fix.
- Preserve scoring, ranking, confidence, caveats, co-change calculation, scope
  filtering, include/exclude filtering, `--inspect`, `--since`, shallow/partial
  detection, dirty-worktree caveats, and error handling semantics.
- Preserve `--progress` as opt-in stderr-only output.
- Add privacy-safe phase timing evidence on `--progress` stderr where practical.
  Timing may include Git subprocess/read, parse/aggregate/co-change,
  score/result build, and render phases.
- Do not add timing fields to table, JSON, or Markdown report schemas.
- Do not add cache files, cache flags, cache commands, database dependencies,
  persistent instrumentation state, providers, network access, telemetry,
  auto-fetch, CI, release packaging, or report schema changes.
- Do not expose source snippets, diffs, commit messages, author identities,
  remotes, absolute local paths, private repository names, raw sibling reports,
  or raw private output.
- If streaming cannot preserve Git failure stderr/exit fidelity or risks child
  process hangs, stop for follow-up instead of weakening error handling.
- If the implementation requires broad CLI/report rewrites, scoring changes, or
  changed Git history semantics, stop and return to shaping.

## Acceptance

- The main Git history ingestion path no longer needs to retain the full
  `git log --numstat` stdout payload before parsing.
- Existing fixture outputs for table, JSON, and Markdown remain stable.
- Parser or ingestion tests cover chunk boundaries, including split commit
  headers, split numstat rows, final commit without trailing newline, CRLF
  trimming, binary `-` numstat rows, malformed or blank lines, braced renames,
  quoted tab paths, and unicode paths.
- Existing CLI behaviours continue to pass for `--inspect`, `--scope all`,
  `--scope project`, include/exclude prefixes, valid and invalid `--since`, and
  `--progress`.
- `--progress` remains stderr-only and does not change stdout for table, JSON,
  or Markdown.
- Phase timing evidence is bounded and privacy-safe.
- Close-out evidence includes validation on this repository and the approved
  sibling/local repository using only the committed label `sibling-local-repo`.
- Any durable spike note or docs update avoids benchmark claims and records
  measured observations separately from unknowns.

## Edge cases and stop conditions

- Stop if Zig child-process streaming requires an async pipeline, worker pool,
  cancellation UX, progress spinner, cache, or broad architecture rewrite.
- Stop if output parity cannot be preserved without changing scoring, ranking,
  co-change, or report schemas.
- Stop if Git process errors lose stderr, exit status, or timeout/hang safety.
- Stop if useful evidence would require committing the real sibling path,
  repository name, remote URL, author identity, commit message, source snippet,
  raw report, or raw private output.
- Stop if timing output would expose paths, commit hashes, remotes, emails, or
  absolute local paths.

## Packet plan

### P1 - Streaming Git log ingestion parity

Replace the all-at-once Git log stdout buffer path with a streaming ingestion
seam that feeds the existing aggregation semantics.

Anchors: `src/git.zig`, current parser and aggregation helpers,
`tests/integration.sh`, existing fixtures.

In scope: child-process stdout streaming for Git history, parser seam tests,
fixture parity, and preserving current error fidelity.

Out of scope: cache, scoring changes, report schema changes, providers,
network, telemetry, release/CI, broad CLI parser rewrites.

Protected: table/JSON/Markdown outputs, scoring/ranking/co-change semantics,
scope/include/exclude/inspect behaviour, Git range semantics, and privacy
boundaries.

Validation/evidence: `zig build test`, fixture output diffs, targeted parser
boundary coverage, and `git diff --check`.

Review focus: streaming parser correctness, memory ownership, chunk boundary
handling, path normalization, rename/quoted-path handling, and Git failure
handling.

Escalate if: streaming needs broad rewrites, output schema changes, changed Git
arguments, or whole-history buffering remains the only safe path.

Done boundary: existing fixture outputs remain stable and analysis no longer
requires retaining the full Git log output before parsing.

### P2 - Phase timing evidence and close-out validation

Add minimal privacy-safe phase evidence for the streaming spike, primarily
through opt-in `--progress` stderr and a durable spike note when useful.

Anchors: `src/git.zig`, `src/main.zig`, `docs/performance-cache-decision.md` or
`docs/streaming-git-ingestion-spike.md`, `tools/validate.sh`.

In scope: bounded phase timing, stdout/stderr separation validation, privacy-safe
this-repo and `sibling-local-repo` evidence.

Out of scope: public benchmark claims, persistent instrumentation state, report
schema timing fields, cache, benchmark harness expansion, providers, CI, or
release packaging.

Protected: deterministic stdout, privacy boundaries, local-first defaults, and
cache-as-future-optimisation framing.

Validation/evidence: `zig build validate`, close-out smoke with
`sibling-local-repo`, stdout/stderr separation checks, privacy/prohibited-content
scan over any changed docs.

Review focus: progress privacy, phase evidence usefulness, absence of schema
changes, and no overclaim that streaming solves large-repo performance.

Escalate if: evidence requires raw private output, new public timing schema,
cache implementation, or persistent measurement state.

Done boundary: durable close-out evidence records what changed, what was
measured, what remains unknown, and whether cache remains deferred.

## Verification

Run and record:

```sh
zig build test
zig build validate
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<approved-local-repo> -Dsmoke-label=sibling-local-repo
```

Also verify that table, JSON, and Markdown stdout remain deterministic with and
without `--progress`, and that progress/timing stderr contains no private paths,
remotes, author identities, commit messages, or raw sibling output.
