# PRD: CI status documentation and post-push verification

## Problem

The repository now has a GitHub Actions validation workflow, and Arsham has pushed it successfully. The project should record and lightly document the public validation signal without adding release automation, badges, or broader CI behaviour prematurely.

## Outcome

Verify that the public GitHub Actions workflow has run successfully on `master`, then add the smallest useful public contribution/documentation note so future contributors understand that CI mirrors the local validation gate.

## Requirements

1. Verify the latest public GitHub Actions `Validation` workflow run for `master` completed successfully after Feature 0030 was pushed.
2. Keep the verification evidence privacy-safe: workflow name, branch, conclusion, commit SHA prefix, and URL are acceptable; no private paths or unrelated account data.
3. Update public documentation only if it improves contributor or visitor clarity.
4. If documentation is updated, state that CI runs the validation gate on push and pull request.
5. If documentation is updated, keep local validation as the source of truth and preserve `zig build validate` as the primary local command.
6. Mention Tree-sitter proof steps only as part of the validation workflow if useful; do not over-emphasise implementation internals in the README.
7. Do not add a badge unless explicitly approved in a later feature.
8. Do not change `.github/workflows/ci.yml` unless verification reveals a concrete issue with the existing workflow.
9. Do not add release automation, package publishing, artifact uploads, cache, coverage, CodeQL, schedule, matrix, secrets, telemetry, or deployment behaviour.
10. Do not change product runtime code, validation scripts, build scripts, fixtures, scoring, reports, provider behaviour, or CLI output.

## Acceptance

1. Post-push GitHub Actions status is checked and recorded in Flow/run evidence.
2. The public docs either remain unchanged with an explicit reason, or receive a small CI/contribution note.
3. Any documentation change is polished, visitor-facing, and does not expose Flow process detail.
4. No CI badge is added.
5. No workflow behaviour is broadened.
6. Local validation remains green.

## Edge cases

1. If the GitHub Actions run is missing, pending, or failed, stop and report the blocker instead of documenting success.
2. If GitHub CLI access is unavailable, use a browser/API check if available; otherwise stop with the exact missing evidence.
3. If documentation would duplicate existing contribution guidance, prefer no README change or a tiny CONTRIBUTING-only clarification.
4. If workflow correction is needed, stop and reshape or dispatch a follow-up; do not silently expand this feature.

## Verification

1. Run `gh run list --repo arsham/git-hotspots --limit 5` or equivalent and prove the latest `Validation` run for `master` succeeded.
2. Run `git diff --check`.
3. Run `zig build validate`.
4. Inspect changed paths and confirm only documentation/Flow state changed unless a workflow fix was explicitly justified.
5. Scan documentation for prohibited commercial/SaaS/pricing/sales claims and bug-prediction/code-quality/developer-ranking overclaims.
6. Confirm `.github/workflows/ci.yml` is unchanged unless a concrete issue was found and documented.
