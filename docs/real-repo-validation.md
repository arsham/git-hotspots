# Real-repo validation evidence

Feature 0010 records a narrow validation-and-demo slice for the existing
`git-hotspots` CLI. It intentionally changes no scoring, Git traversal,
providers, cache, packaging, release, CI, network, telemetry, upload, or remote
enrichment behaviour.

## Evidence policy

- Treat hotspot rows as historical change-pressure investigation prompts.
  They are not predictions, not quality ratings, not maintainer judgement,
  not developer rankings, and not productivity analytics.
- Public demo material may use bounded, repo-relative paths from this public
  repository only.
- Sibling repository output is sensitive even when paths are relative. Commit
  only the label `sibling-local-repo`, command shapes, pass/fail status,
  bounded counts, timing, dirty/scope flags, and categorical observations.
- Do not commit sibling repository paths, names, remotes, author identities,
  commit messages, source snippets, or raw table/JSON/Markdown reports.
- Use placeholder command shapes for private inputs, for example
  `-Dsmoke-repo=<operator-provided-local-repo>`.

## This-repository demo evidence

Run context:

- Tool version: `git-hotspots 0.1.0-alpha.1`.
- Zig version: `0.16.0`.
- Git version: `git version 2.54.0`.
- Analysed commit count: 28.
- Tracked-file count: 48.
- Worktree state for the demo commands: clean.

Command shapes exercised:

```sh
zig build
./zig-out/bin/git-hotspots --repo . --limit 10 --format json
./zig-out/bin/git-hotspots --repo . --limit 10 --format table
./zig-out/bin/git-hotspots --repo . --limit 10 --format markdown
./zig-out/bin/git-hotspots --repo . --exclude-prefix .flow/ --limit 10 --format json
./zig-out/bin/git-hotspots --repo . --exclude-prefix .flow/ --limit 10 --format table
./zig-out/bin/git-hotspots --repo . --exclude-prefix .flow/ --limit 10 --format markdown
./zig-out/bin/git-hotspots --repo . --include-prefix src/ --limit 10 --format json
./zig-out/bin/git-hotspots --explain
```

Bounded observations:

| Run | Results | Analysis caveats | Result caveat rows | Scope observation | Evidence observation |
| --- | ---: | ---: | ---: | --- | --- |
| Unscoped JSON/table/Markdown | 10 | 0 | 0 | filters inactive | all result rows had positive total scores, high confidence, and evidence commits |
| `.flow/` excluded JSON/table/Markdown | 10 | 0 | 0 | filters active; 26 excluded paths and 63 excluded changes | no `.flow/` result or co-change paths; all result rows had positive total scores, high confidence, and evidence commits |
| `src/` included JSON | 7 | 0 | 0 | filters active; 41 outside-include paths and 109 outside-include changes | all result rows had positive total scores; confidence values were high and low |

Additional checks:

- Scoped Markdown contained `Run summary`, `Scope`, `Caveats`, `Top hotspots`,
  and `Evidence` sections.
- Scoped Markdown retained investigation-prompt and non-prediction framing.
- Scoped table output stayed small at 17 lines; scoped Markdown stayed bounded
  at 266 lines.
- `--explain` produced deterministic standalone explanatory output.

Usefulness/noise observations:

- Excluding `.flow/` removed process-state paths from the public demo, making
  the report easier to read without changing runtime behaviour.
- `--include-prefix src/` narrowed attention to source paths and made scope
  metadata visible enough for a reviewer to see what was omitted.

## Sibling local-repository smoke evidence

The sibling smoke used only the operator-provided local Git worktree and did not
clone, fetch, pull, push, or contact remotes.

Command shape exercised:

```sh
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-provided-local-repo> -Dsmoke-label=sibling-local-repo
```

Privacy-safe summary:

| Label | Table | JSON | Markdown | Results | Caveats | Dirty | Scope active | Elapsed | Analysed commits | Tracked files |
| --- | --- | --- | --- | ---: | ---: | --- | --- | ---: | ---: | ---: |
| `sibling-local-repo` | pass | pass | pass | 10 | 1 | true | false | 58s | 1521 | 2840 |

Categorical observations:

- The unscoped top-10 report was non-empty and bounded across table, JSON, and
  Markdown output shapes.
- The dirty-worktree caveat was visible in the privacy-safe summary, so the
  evidence remains honest without exposing private repository details.

## Validation summary

Commands run for this feature:

```sh
zig build validate
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-provided-local-repo> -Dsmoke-label=sibling-local-repo
git diff --check
git status --short --branch
```

Observed validation status:

- `zig build validate`: pass.
- Close-out validation with `sibling-local-repo`: pass.
- Default and close-out validation included format checks, tests, fixture JSON
  and Markdown determinism, JSON validity, Markdown semantic checks, privacy
  assertions, source-install smoke, and real-repo smoke rungs.
- `git diff --check` passed with this document included in the diff.
- Prohibited-claim and privacy scans passed for this document.

## Python current-line history execution evidence

Fresh local validation on 2026-05-25 exercised the Python opt-in
`--symbol-line-history` path without committing raw private report output.

Command shapes exercised:

```sh
zig build tree-sitter-python-symbol-proof
zig build validate
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-provided-local-repo> -Dsmoke-label=sibling-local-repo
git diff --check
```

Privacy-safe close-out smoke summary:

| Label | Python symbols | Python line history | Results | Caveats | Dirty | Scope active | All elapsed | Analysed commits | Tracked files | Tracked Python files |
| --- | --- | --- | ---: | ---: | --- | --- | ---: | ---: | ---: | ---: |
| `sibling-local-repo` | pass | pass | 10 | 2 | true | false | 60s | 1521 | 2840 | 4 |

Additional privacy-safe observations:

- The sibling smoke found a tracked Python file suitable for current-line
  history validation and reported `python_line_history=pass` by label only.
- Close-out validation also passed the project-scope sibling smoke; the summary
  recorded bounded counts and did not print sibling paths, remotes, authors,
  emails, commit messages, source snippets, or raw JSON/Markdown/table output.

## Candidate next seams from evidence

These are candidate product seams, not roadmap commitments:

- A dedicated evidence-export or validation-summary command could make real-repo
  smoke summaries easier to collect without copying from the validation ladder.
- Larger local repositories may need clearer progress or timing feedback before
  any scoring or provider work is considered.
- Scope examples in public docs should keep showing filters explicitly so users
  can separate product source paths from local process or generated paths.
