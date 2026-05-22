# Feature 0009: Public alpha readiness

## Summary

Prepare `git-hotspots` for a narrow public source alpha. The feature adds the
missing OSS license, alpha version identity, `--version`, minimal source-build
and contribution docs, and public-alpha validation/hygiene evidence.

This is not a packaged release feature. It must not add CI, package-manager
publishing, GitHub release automation, hosted services, provider/cache design,
or commercial strategy.

## Operator decisions

The operator approved these decisions for this feature:

- License: Apache-2.0.
- Copyright holder/year: Copyright 2026 Arsham Shirvani.
- Alpha version: `0.1.0-alpha.1`.
- Version flag: add `git-hotspots --version`.
- Contribution posture: issues and small focused PRs are welcome.
- Zig version to document: `0.16.0` is the currently validated Zig version.

## Requirements

1. Add a root `LICENSE` file containing Apache-2.0 license text and the agreed
   copyright identity where appropriate.
2. Add a compact README license note that names Apache-2.0.
3. Update README alpha status so visitors understand this is a source-buildable
   public alpha, not a packaged release.
4. Add install-from-source documentation with prerequisites for local Git and the
   currently validated Zig version `0.16.0`.
5. Keep README public-facing and free of Flow lifecycle or process exposition.
6. Add `CONTRIBUTING.md` with lightweight alpha contribution guidance.
7. `CONTRIBUTING.md` must say issues and small focused PRs are welcome.
8. `CONTRIBUTING.md` must instruct contributors to run `zig build validate`.
9. `CONTRIBUTING.md` must preserve the local-first/no-network/no-telemetry
   default and the no-overclaim boundaries.
10. Centralise the version string `0.1.0-alpha.1` in source rather than keeping
    separate hard-coded report literals.
11. JSON report metadata must use `0.1.0-alpha.1`.
12. Markdown report metadata must use `0.1.0-alpha.1`.
13. Add `git-hotspots --version`.
14. `git-hotspots --version` must exit 0 outside a Git repository.
15. `git-hotspots --version` must write a deterministic version line to stdout
    and no stderr on success.
16. `--version` must be documented in help text and README.
17. If `--version` is standalone, combinations with analysis flags must fail
    clearly on stderr; if another combination policy is chosen, it must be
    documented and tested.
18. Existing default analysis output remains table format.
19. Existing `--help` and `--explain` behaviour remain available and local-only.
20. Existing scoring, ranking, Git traversal, filter semantics, confidence,
    caveats, co-change calculation, and result limiting must not change.
21. Existing table, JSON, and Markdown report shapes must remain stable except
    for intentional version metadata changes and docs/help additions.
22. Fixture expectations must be updated only for intentional alpha identity,
    help, version, or docs validation changes.
23. `zig build validate` must continue to pass.
24. Close-out validation must include the standard validation ladder and either a
    privacy-safe sibling/local repo smoke or an explicit approved skip reason.
25. Close-out evidence must include help, explain, version, and at least one
    analysis smoke.
26. Close-out evidence must include an install-from-source smoke in a clean
    disposable copy or worktree.
27. Close-out evidence must include a license/version consistency check.
28. Close-out evidence must include docs/prohibited-claim scans and their
    interpretation.
29. Close-out evidence must include git status and branch/remote hygiene summary.
30. Public docs and runtime text must not include monetisation, SaaS, hosted
    product, pricing, sales, or commercial roadmap plans.
31. Public docs and runtime text must not claim bug prediction, objective
    code-quality rating, technical-debt score, maintainer judgement, developer
    ranking, productivity analytics, author metrics, or AI/LLM judgement.
32. Runtime defaults must remain local-first: no fetch, pull, push, upload,
    telemetry, remote enrichment, or network behaviour by default.
33. This feature must not add providers, cache/database, package registries,
    binary release automation, Homebrew, GitHub Actions, release tags, or remote
    publishing.
34. No raw private smoke output, absolute local paths, private repo names, author
    identities, or commercial strategy may be committed.
35. If a history leak is found, stop and ask before any history rewrite.

## Acceptance

The feature is done when:

- Apache-2.0 licensing is present and documented.
- README describes public alpha status, source install, validation, and current
  limitations honestly.
- `CONTRIBUTING.md` gives lightweight contribution guidance.
- `0.1.0-alpha.1` is the central version used by reports and `--version`.
- `git-hotspots --version` works outside a Git repository.
- `zig build validate` and close-out validation pass.
- A clean-copy source install smoke is recorded.
- Docs and runtime text pass prohibited-claim scans.
- Git hygiene evidence is recorded.
- No out-of-scope release automation, package publishing, hosted/commercial
  strategy, providers, cache, telemetry, or network behaviour is added.

## Edge cases

- Running `--version` outside a Git repository should not attempt repo analysis.
- Running `--version` with analysis flags should follow the documented policy and
  fail clearly if standalone semantics are used.
- README should not imply binary downloads, package-manager installation, or
  tagged release availability unless those are implemented in a later feature.
- License docs should not imply legal advice.
- Contributing docs should not promise broad maintainer capacity or long-term API
  stability during alpha.
- Install-from-source docs should avoid absolute local paths and should not rely
  on private project structure.
- Backup branches created during local history cleanup must remain local and must
  not be presented as release branches.
- The remote configuration may be incomplete locally; do not push or tag as part
  of this feature.

## Verification

Required validation/evidence:

```sh
zig fmt --check build.zig src tests
zig build test
zig build
zig build run -- --help
zig build run -- --explain
zig build run -- --version
zig build validate
zig build validate -Dcloseout=true -Dsmoke-repo=<local-repo> -Dsmoke-label=<safe-label>
# or an explicit approved skip reason when no sibling repo is available

git diff --check
git status --short --branch
```

Also record:

- `zig version` and `git --version`.
- License file presence and Apache-2.0 identification.
- Search results for remaining `0.0.0-spike` literals.
- Docs/prohibited-claim scan results with safe negative-disclaimer
  interpretation.
- Help/version/report consistency checks.
- Clean disposable copy or worktree source-install smoke:
  - build from source;
  - run `--help`;
  - run `--explain`;
  - run `--version`;
  - run one local repo analysis.
- Branch/remote hygiene summary, including local backup branches and whether a
  usable remote is configured.

Do not print or commit raw private smoke reports, absolute local paths, private
repo names, author identities, or private commercial context.
