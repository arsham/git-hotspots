# Packaging smoke evidence

This note records the privacy-safe local packaging evidence expected for the
current unpublished Linux dogfood path. Do not commit generated archives,
packages, absolute local paths, upload logs, or machine-specific raw output.

Expected validation sequence:

1. Run `./tools/release-linux.sh` on a native Linux host.
2. Unpack `dist/git-hotspots-0.1.0-alpha.5-linux-$(uname -m).tar.gz` into a
   temporary directory.
3. Run the unpacked `git-hotspots --version` and `git-hotspots --help`.
4. Copy the archive into `packaging/aur/git-hotspots-bin/`.
5. When Arch tooling is available, run `makepkg --printsrcinfo`, `makepkg -f`,
   `pacman -Qp` on the built package, and a package-extracted binary smoke
   test.
6. When Arch tooling is unavailable, record that finding and use the release
   archive smoke as independent evidence.
7. Confirm generated `dist/` and package output files are ignored local outputs
   and do not require committing binaries or packages.

Current status: local dogfood only. Publishing GitHub Releases, AUR uploads,
release signing, official checksums, multi-platform builds, and hosted release
automation remain future work.

## Release-readiness validation evidence, 2026-05-29

Privacy-safe local release-readiness validation for the future tag decision ran
without creating or pushing tags, releases, package uploads, or remote metadata.

- `git diff --check`: passed.
- `zig build test`: passed.
- `zig build validate -Dcloseout=true -Dsmoke-repo=../git-hotspots.rs
  -Dsmoke-label=sibling-rs`: passed.
- `tools/flow-closeout-check.sh --smoke-repo ../git-hotspots.rs
  --smoke-label sibling-rs`: passed.

Bounded smoke evidence from the validation summary:

- `this-repo`: commits=250, tracked_files=679, results=10,
  project_excluded_paths=213, project_excluded_changes=548.
- `sibling-rs`: commits=30, tracked_files=54, results=10,
  project_excluded_paths=0, project_excluded_changes=0.
- Deterministic fixture budgets passed for file hotspots, current symbols,
  historical symbols, and relationship enrichment within the named validation
  limits.
- Source-install copy smoke passed with version `0.1.0-alpha.5`.

The recorded evidence uses labels and bounded counts only; raw reports,
absolute local paths, generated archives, and private output were not committed.
