# CI validation workflow

## Problem

The project now has non-trivial Zig validation, vendored Tree-sitter sources,
and inspect-only symbol evidence. Public contributors and publicity readers need
a visible CI signal that the public validation gate passes on GitHub without
adding release automation or changing runtime behaviour.

## Outcome

Add a minimal GitHub Actions validation workflow that runs the existing public
validation contract on push and pull request. CI proves the public/default gate
and explicit Tree-sitter proof steps only; close-out sibling/local repository
smoke remains a local operator gate.

## Requirements

- Add one workflow under `.github/workflows/`.
- Trigger the workflow on `pull_request` and `push` to the repository's primary
  branch.
- Use a single Linux job, currently `ubuntu-latest`.
- Use Zig `0.16.0`, matching the documented supported version.
- Checkout must use full history (`fetch-depth: 0`) because validation and the
  product are Git-history-sensitive.
- Set least-privilege workflow permissions, at minimum `contents: read`.
- Run the canonical local validation gate:

  ```sh
  zig build validate
  ```

- Run explicit Tree-sitter proof steps because they intentionally remain outside
  `zig build validate`:

  ```sh
  zig build tree-sitter-build-proof
  zig build tree-sitter-symbol-proof
  ```

- CI must not require or fake the sibling/local close-out smoke. That remains a
  local operator validation path.
- CI logs must remain privacy-safe and must not upload raw reports or private
  evidence.

## Non-goals

- No release automation, tags, changelog generation, package publishing,
  binaries, or artifact uploads.
- No OS matrix, Zig version matrix, nightly schedule, cache, coverage service,
  CodeQL, dependency audit, badges, deployment, or package-manager integration.
- No runtime product behaviour changes.
- No workflow secrets.
- No telemetry, upload, remote enrichment, or external analysis service.
- No parser generation, submodules, or build-time network fetches beyond normal
  GitHub checkout and Zig setup.

## Acceptance

- A minimal workflow exists and is named clearly for validation.
- Workflow triggers are limited to `push` and `pull_request`.
- Workflow permissions are least-privilege and do not grant write access.
- Workflow checks out full Git history.
- Workflow installs or selects Zig `0.16.0` through a pinned or acceptable setup
  mechanism.
- Workflow runs `zig build validate`.
- Workflow runs `zig build tree-sitter-build-proof`.
- Workflow runs `zig build tree-sitter-symbol-proof`.
- Workflow does not include release, package, artifact-upload, cache, coverage,
  telemetry, secrets, or publish steps.
- Local validation still passes after adding the workflow.
- Public docs are changed only if needed; no README badge is required in this
  feature.

## Edge cases

- If the chosen Zig setup mechanism is unpinned, unavailable, or requires broad
  permissions, stop and reshape or ask for operator approval.
- If `zig build validate` is too slow or flaky on hosted CI, stop and reshape;
  do not silently weaken CI to `zig build test` only.
- If GitHub Actions shallow checkout changes validation behaviour, keep
  `fetch-depth: 0` rather than changing the product or validation semantics.

## Verification

- Run `git diff --check`.
- Run `zig build validate` locally.
- Run `zig build tree-sitter-build-proof` locally.
- Run `zig build tree-sitter-symbol-proof` locally.
- Inspect the workflow for least-privilege permissions, full checkout history,
  Zig `0.16.0`, and absence of prohibited release/upload/cache/secret steps.
- Close-out does not require a real GitHub run, but the workflow syntax and local
  commands must be validated.
