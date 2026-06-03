# Historical provider-state fixture gap audit

Audit date: 2026-06-01

This audit records which historical-symbol provider states the executable
fixture covers and which states remain intentionally uncovered. It does not
change runtime behaviour, provider algorithms, CLI flags, JSON schema, scoring,
ranking, release state, tags, packages, remotes, network access, telemetry, or
cache semantics.

## Current coverage

The checked-in historical-symbol golden currently covers these provider states:

| State | Covered? | Current evidence |
| --- | --- | --- |
| `ok` | yes | parsed revision-local Zig rows for `alpha`, `zebra`, and `target` |
| `unsupported` | yes | `src/readme.txt` fallback row |
| `skipped` | yes | `src/link.zig` unattributed/root-commit fallback row |
| `failed` | yes | `src/broken.zig` malformed historical Zig blob produces a failed fallback row |
| `timed_out` | no | no provider timeout injection exists for historical attribution |
| `unavailable` | no | no historical blob fixture currently exercises unavailable provider input |

The fixture now covers `failed` with deterministic content-driven parser
failure evidence. `timed_out` and `unavailable` remain uncovered in the
fixture, this-repo sample, and sibling-local sample.

## Feasibility assessment

| Missing state | Feasible deterministic fixture? | Recommendation |
| --- | --- | --- |
| `failed` | covered | Keep the malformed historical Zig blob as executable fixture evidence; do not replace it with hand-authored golden output. |
| `timed_out` | not currently stable | Do not add now. The current provider paths do not expose a historical timeout injection seam, and relying on wall-clock timeout behaviour would be brittle. |
| `unavailable` | not currently stable for historical blobs | Do not add now. Historical attribution reads Git object data, so normal missing/symlink/current-file unavailable cases are represented as `skipped` or file fallback rather than a stable provider `unavailable` row. |

## Decision

Keep the deterministic `failed` fixture in this slice. The current matrix should
explicitly treat only `timed_out` and `unavailable` as uncovered historical
provider states, not as states proven impossible.

`timed_out` and `unavailable` should wait until the runtime has a deliberate,
testable injection seam or a real user-facing case.

## Reviewer notes

When reviewing future historical-symbol fixture work:

1. Keep `ok`, `unsupported`, `failed`, and `skipped` as required baseline
   states.
2. Treat `timed_out` and `unavailable` as explicit coverage gaps unless a
   shaped feature adds stable fixture evidence.
3. Reject wall-clock timeout fixtures or environment-dependent missing-provider
   fixtures as too brittle.
4. Preserve the local-first boundary: do not record raw reports, remotes,
   absolute paths, author identities, emails, parser diagnostics, source
   snippets, or commit messages.
5. Do not infer semantic lineage, ownership, code quality, dependency truth, or
   bug prediction from provider states.
