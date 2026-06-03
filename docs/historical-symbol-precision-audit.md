# Historical-symbol precision audit

This audit records bounded, privacy-safe observations from real
`--historical-symbols` output. It is docs-only evidence for follow-up planning,
not a runtime, provider, schema, scoring, ranking, cache, network, telemetry,
release, tag, package, or remote change.

## Scope and privacy boundaries

Commands used the bounded shape below and recorded labels, aggregate counts,
provider-state categories, caveat categories, and project-relative public paths
only:

```text
zig build run -- --repo <repo> --limit 5 --symbols --historical-symbols \
  --symbol-limit 5 --format json
```

Repositories sampled:

- `this-repo`: this public repository.
- `sibling-local`: one local sibling repository. The audit records only the
  anonymised label and aggregate categories; no sibling repository name, remote,
  author identity, email, commit message, absolute path, raw report, source
  snippet, or parser diagnostic is recorded.

Both sampled commands completed successfully. The checked-in fixture comparison
uses `fixtures/expected/historical-symbols.json` and the coverage expectations
from `docs/historical-symbol-fixture-realism-matrix.md`.

## Aggregate observations

| Sample | Retained paths | Historical rows | Fallback records | Fallback hunks | Provider states | Display rows | Aggregate bound |
| --- | ---: | ---: | ---: | ---: | --- | --- | --- |
| Fixture | 4 | 8 | 4 | 7 | ok 4, unsupported 1, failed 1, skipped 2 | 2 shown / 6 omitted | 128, not exceeded |
| this-repo | 5 | 11 | 5 | 279 | ok 6, unsupported 3, skipped 2 | 5 shown / 6 omitted | 128, not exceeded |
| sibling-local | 6 | 88 | 3 | 65 | ok 85, unsupported 1, skipped 2 | 5 shown / 83 omitted | 128, not exceeded |

The fixture remains representative for the core output shapes: parsed
revision-local symbol rows, unsupported-file fallback, skipped unattributed
fallback, compact human display, explicit provider-state spread, and the
aggregate record bound. It now also demonstrates a skipped
`src/example.zig` row that carries multiple fallback hunks in one file-level
fallback record, so the distinction between fallback rows and fallback hunks is
visible even in the checked-in fixture. Real output also shows why the fixture
should be read as a coverage fixture rather than as a volume model. In this
repository, fallback-record rate was 5 of 11 rows, while fallback hunk
pressure was much higher because a small number of fallback rows represented
many unattributed or unsupported hunks. In the sibling sample, fallback-record
rate was 3 of 88 rows, but 65 fallback hunks were still present. Both
observations are useful and honest, but the distinction between fallback rows
and fallback hunks should stay clear in future docs and reviews.

## Comparison against fixture expectations

| Concern | Fixture expectation | Real-output observation | Precision finding |
| --- | --- | --- | --- |
| Fallback rate | Four fallback rows and seven fallback hunks among eight historical rows | Both real samples had bounded fallback rows; fallback hunk counts were larger than row counts | Row fallback and hunk fallback are different precision signals. Future audits should report both rather than a single ambiguous rate. |
| Provider states | `ok`, `unsupported`, `failed`, and `skipped` all appear | Both real samples also showed `ok`, `unsupported`, and `skipped`; no timed-out or unavailable historical rows appeared in the sampled outputs | The fixture covers the visible non-happy states seen in these samples, and it now exercises `failed` as well. It still does not exercise `timed_out` or `unavailable` historical rows. |
| Unattributed hunks | A skipped row carries `unattributed hunk fallback; no nearest-symbol guessing` | This repository had one row with that exact caveat; the sibling sample had skipped rows without that specific caveat in the bounded aggregate | The caveat is visible when present, and the output avoids nearest-symbol guessing. The skipped state can also represent other bounded skip reasons, so reviewers should inspect caveat categories, not state alone. |
| Aggregate-bound behaviour | Bound is `128` and not exceeded | Both real samples reported bound `128` and not exceeded | The bound is discoverable and honest for normal-sized bounded samples. No sampled output proved the exceeded path. |
| Display omissions | Human display shows two rows and omits four with `--symbol-limit 2` | Real samples with `--symbol-limit 5` showed five rows and omitted six or eighty-three rows | Compact display behaves as expected. The sibling sample shows omission counts are essential because useful aggregate evidence can be much larger than the displayed table. |
| Caveat clarity | Report caveats reject semantic lineage, ownership, bug prediction, scoring replacement, network, telemetry, and cache truth | Real outputs retained report caveats and local-only provenance categories | Caveats are clear enough for investigation prompts, but high fallback hunk counts would benefit from an explicit doc note distinguishing row counts from hunk pressure. |

## Usefulness and precision gaps

The historical-symbol output is useful as bounded investigation evidence. It
connects changed hunks to revision-local symbols when providers can parse the
historical blob, keeps unsupported or skipped evidence visible as file-level
fallback, and preserves local-first provenance. The real samples did not show
runtime evidence that the feature overclaims lineage, ownership, dependency,
quality, bug truth, or developer performance.

The main precision gap is interpretive rather than a runtime bug: `fallback
record count` and `fallback count` can diverge sharply. A reader who sees only
one fallback rate may misunderstand whether the problem is many fallback rows or
a small number of fallback rows carrying many unattributed hunks. The checked-in
fixture now demonstrates that divergence directly: one skipped `src/example.zig`
row carries multiple fallback hunks, while the other fallback rows remain tiny.

A secondary fixture gap is state coverage. The checked-in fixture exercises
`ok`, `unsupported`, and `skipped`, which matched the sampled real outputs. It
does not exercise `failed`, `timed_out`, or `unavailable` historical rows. That
is acceptable for the current fixture matrix as long as reviewers do not treat
absence of those states as proof that they cannot occur.

## Feature 0125 selected case

Feature 0125 inspects fallback hunk pressure in the checked-in historical
fixture and the existing validation surfaces. The selected safe case is now
materialised in `src/example.zig`: one parsed revision contains multiple hunks
where the symbol-backed hunk stays attributed and the unmatched hunks collapse
into a single skipped file-level fallback row.

This reduces overstated fallback hunk pressure without changing provider
admission, CLI flags, JSON schema, scoring, ranking, cache, network, telemetry,
release, tag, package, or remote behaviour. The fallback row still keeps the
`unattributed hunk fallback; no nearest-symbol guessing` caveat, and the
symbol-attributed rows still require direct intersection with revision-local
symbol ranges. Unsupported, failed, skipped, timed-out, and unavailable
provider-state semantics are unchanged.

## Successor recommendations

1. Add a future docs or fixture-review follow-up to name both fallback-row rate
   and fallback-hunk pressure wherever a fallback rate is discussed.
2. Consider a future synthetic fixture or fixture variant for failed, timed-out,
   or unavailable historical provider states if those states become important to
   user-facing review.
3. Keep the existing fixture matrix as the core realism checklist, but clarify
   that it proves output-shape coverage, not representative real-repository
   volume or fallback distribution.
4. Do not change runtime attribution, providers, CLI flags, JSON schema,
   scoring, ranking, cache, network, telemetry, releases, tags, packages, or
   remotes based on this audit alone.
