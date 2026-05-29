# Release tag checklist

This checklist prepares a future operator decision for `v0.1.0-alpha.3`. It is
inert documentation only: do not create tags, push tags, publish packages,
create GitHub Releases, or announce the release until the explicit approval gate
below is satisfied.

## Proposed tag and target

- Proposed tag: `v0.1.0-alpha.3`.
- Target commit: resolve at approval time with `git rev-parse HEAD` after the
  cleaned release-readiness commits are pushed and before any tag is created.
- Target summary: the approved `master` `HEAD` at release-approval time.
- Version metadata: `src/version.zig` reports `0.1.0-alpha.3`.
- Release notes: `CHANGELOG.md` has the `v0.1.0-alpha.3 draft` section.
- Validation evidence: `docs/packaging-smoke-evidence.md` records the
  2026-05-29 release-readiness validation for features 0100, 0101, and 0102.

## Read-only checklist evidence

Record fresh evidence immediately before any future approval decision:

- `git status -sb` must show only the expected local branch status and no
  working-tree changes.
- `git tag --list 'v0.1.0-alpha.3'` must print no local tag.
- `git ls-remote --tags origin 'v0.1.0-alpha.3'` must print no remote tag.
- `git diff --check` must pass.
- `TARGET_COMMIT=$(git rev-parse HEAD)` should be recorded before approval.
- `git tag --points-at "$TARGET_COMMIT"` should be reviewed for any existing
  tag on the proposed target.

If `v0.1.0-alpha.3` exists locally or remotely, stop and ask the operator. Do
not overwrite, delete, or recreate the tag inside this checklist flow. If
`origin/master` changed unexpectedly since the evidence was recorded, stop with
a status report before preparing a tag decision. If validation evidence is
stale, route back to release validation instead of preparing a tag decision.

## Inert tag commands

The commands below document the future operation only. Do not run them during
checklist preparation.

```sh
# Create the annotated tag at the approved target commit.
TARGET_COMMIT=$(git rev-parse HEAD)
git tag -a v0.1.0-alpha.3 "$TARGET_COMMIT" \
  -m "git-hotspots v0.1.0-alpha.3"

# Push only after explicit operator approval.
git push origin v0.1.0-alpha.3
```

Rollback/delete-tag notes if an approved future tagging operation is made in
error:

```sh
# Local delete, only after explicit operator approval.
git tag -d v0.1.0-alpha.3

# Remote delete, only after explicit operator approval.
git push origin :refs/tags/v0.1.0-alpha.3
```

The prior accidental deletion of `v0.1.0-alpha.3` is an operational caution:
confirm the proposed target and approval gate before any tag creation, push, or
delete command.

## Approval gate

Before any tag creation, tag push, package publish, GitHub Release, or
announcement, the operator must explicitly approve all of these items in a new
message:

1. The tag name is `v0.1.0-alpha.3`.
2. The target commit is the freshly recorded `git rev-parse HEAD` value.
3. Fresh read-only evidence shows no local or remote `v0.1.0-alpha.3` tag.
4. Fresh validation evidence is accepted as current enough for tagging; stale
   validation evidence must route back to release validation before tagging.
5. The exact side effects being approved are named, such as local tag creation,
   tag push, package publish, GitHub Release creation, or announcement.

Without that explicit approval, stop before every tag, push, publish, release,
or announcement side effect.
