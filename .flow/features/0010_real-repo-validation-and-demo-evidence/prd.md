# PRD: Real-repo validation and demo evidence

## Summary

Validate the current public alpha on real repositories before adding broader
product features. The feature uses the existing CLI only and commits only
privacy-safe evidence: public demo material from this repository and summary-only
evidence from one operator-provided local/sibling repository.

## Requirements

1. Use the existing `git-hotspots` CLI without changing scoring, Git traversal,
   report schemas, provider behaviour, cache behaviour, packaging, release, CI,
   network, telemetry, upload, or remote enrichment.
2. Generate this-repo demo evidence from a clean worktree where practical and use
   the approved scope filter `--exclude-prefix .flow/` for public demo material.
3. This-repo demo evidence must record the exact command shape, tool version,
   output format, clean/dirty flag, result count, caveat count, scope counts, and
   short non-judgemental observations.
4. This-repo public demo material may include bounded repo-relative paths from
   this public repository only.
5. Run a second real-repo smoke against the operator-provided local/sibling Git
   worktree using the privacy-safe label `sibling-local-repo`.
6. Do not persist the sibling repository path, name, remote URL, organisation,
   author identities, commit messages, source snippets, or raw table/JSON/Markdown
   reports in committed artefacts.
7. Sibling evidence may record only safe labels, command shapes, pass/fail status,
   result counts, caveat counts, dirty flag, scope-active flag, elapsed timing,
   scale counts, and categorical usefulness/noise observations.
8. Run `zig build validate` and close-out validation with the sibling repo using
   `-Dsmoke-label=sibling-local-repo`.
9. Verify JSON outputs are valid and contain non-empty results where expected,
   positive scores, confidence fields, caveat fields, and evidence commit fields.
10. Verify Markdown outputs contain Run summary, Scope, Caveats, Top hotspots,
    Evidence, and investigation-prompt/non-prediction framing.
11. Verify scoped this-repo output with `--exclude-prefix .flow/` contains no
    `.flow/` result or co-change paths and reports non-zero excluded counts when
    applicable.
12. Record basic scale and performance evidence: analysed commit count, tracked
    file count, elapsed time, result count, and whether output size stayed small.
13. Public wording must frame results as historical change-pressure prompts, not
    bug predictions, objective code-quality ratings, maintainer judgement,
    developer rankings, productivity analytics, or technical-debt scores.
14. Public artefacts must not name or excerpt third-party OSS repositories unless
    separately approved.
15. If validation exposes a product bug or scoring/noise problem, record it as a
    candidate future seam; do not fix it inside this feature unless it is required
    to keep evidence truthful and remains inside the existing CLI contract.

## Edge cases and privacy rules

- Reports may reveal repository structure even without absolute paths. Treat all
  sibling output as sensitive and summary-only.
- Dirty worktrees must be reported honestly. Prefer clean this-repo demo evidence
  after shaping/Flow changes are committed.
- Use project-relative paths only. Scan committed demo/evidence docs for absolute
  local paths, home-directory fragments, remote URLs, email-like identities, raw
  tabs, and private repo names.
- Do not clone, fetch, pull, or contact remotes to prepare the sibling repository.
  Use only the already-provided local worktree.
- Public demo excerpts from this repo must be small and scope-disclosed.

## Validation

Required close-out commands and checks:

```sh
zig build test
zig build validate
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-provided-local-repo> -Dsmoke-label=sibling-local-repo
git diff --check
git status --short --branch
```

Additional checks:

- Run this-repo table, JSON, and Markdown commands with `--exclude-prefix .flow/`.
- Run this-repo include-scope smoke such as `--include-prefix src/` where useful.
- Validate JSON with Python or `jq`.
- Scan committed docs/evidence for prohibited positive claims and private data.
- Confirm no implementation files changed unless a separately justified validation
  helper is added within scope.

## Done boundary

The feature is done when committed artefacts provide a privacy-safe real-repo
validation note and/or demo evidence from this repo, summary-only sibling smoke
findings, passing validation, and clear candidate next seams without committing a
new roadmap choice.
