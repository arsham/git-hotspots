# GitHub CI pipeline hardening

## Purpose

Ensure GitHub Actions provides a credible project CI gate for pushed branches and pull requests without introducing networked runtime behaviour, package publishing, release automation, or claims beyond local deterministic validation.

The repository already has `.github/workflows/ci.yml`; this feature hardens and aligns it with current project validation expectations rather than treating CI as absent.

## Requirements

- REQ-001: The GitHub CI workflow must run on pushes to `master` and pull requests.
- REQ-002: The workflow must check out full history where project validation requires Git-history evidence.
- REQ-003: The workflow must install the pinned supported Zig toolchain used by the project.
- REQ-004: The workflow must run the project’s authoritative full validation gate, currently `zig build validate-all`, or an equivalent project-owned aggregate that includes `zig build validate` plus proof gates.
- REQ-005: CI must include tree-sitter proof coverage for all currently admitted symbol/relationship provider lanes where project-owned build steps exist.
- REQ-006: CI must avoid duplicated shell logic when a project-owned aggregate command already expresses the same validation intent.
- REQ-007: CI must not publish packages, create releases, create or push tags, upload artefacts, mutate remotes, fetch private data, or require secrets.
- REQ-008: CI must not add runtime network, telemetry, cache, remote enrichment, or package-publishing behaviour to the CLI.
- REQ-009: CI must remain deterministic and local-first except for standard GitHub Actions dependency setup required to run validation on the hosted runner.
- REQ-010: CI must keep permissions minimal, with read-only repository contents unless a future explicit feature changes that.
- REQ-011: The workflow should use clear step names and avoid misleading claims that CI predicts bugs, scores code quality, ranks developers, or proves semantic dependency/call-graph truth.
- REQ-012: Documentation or validation references that mention CI must remain accurate after the workflow change.
- REQ-013: The implementation must preserve existing local hook behaviour: `.githooks/pre-commit` continues to run the fast gate and `.githooks/pre-push` continues to run `zig build validate-all`.
- REQ-014: The implementation must leave the repository clean and pass `git diff --check`, `zig build test`, and `zig build validate`; if CI config changes validation orchestration, `zig build validate-all` must also be run or explicitly justified.

## Acceptance

- GitHub Actions workflow exists and is aligned with the project validation baseline.
- Push and pull request CI run the full project validation/proof aggregate.
- Provider proof gates remain represented either through `validate-all` or explicit workflow steps with no missing admitted provider lane.
- No publish/release/tag/remote mutation steps are introduced.
- No runtime CLI behaviour, report schema, provider semantics, scoring/ranking, cache, network, telemetry, release, package, or Flow lifecycle behaviour changes.
- Reviewer can independently verify the workflow against local hook commands and current build steps.

## Edge cases

- If `zig build validate-all` already includes all currently explicit CI proof steps, prefer simplification to a single aggregate step plus any genuinely missing CI-only checks.
- If a proof step is intentionally not included in `validate-all`, document why it remains explicit in CI.
- If GitHub runner setup requires network access for `actions/checkout` or Zig setup, keep that limited to CI environment setup and do not imply runtime product network dependence.
- If a new admitted provider lacks a project-owned CI proof step, stop and shape a prerequisite validation feature rather than silently asserting coverage.

## Verification

- Inspect `.github/workflows/ci.yml`, `.githooks/pre-commit`, `.githooks/pre-push`, and `build.zig` validation/proof step definitions.
- Run `git diff --check`.
- Run `zig build test`.
- Run `zig build validate`.
- Run `zig build validate-all` when the workflow changes aggregate validation/proof coverage.
- Confirm no release/tag/package/publish or remote-mutation action was added.
