# Dogfood Linux binary packaging and local install PRD

## Context

`git-hotspots` is currently source-buildable with `zig build`; public docs still
say there is no packaged release. Arsham wants the first release-packaging slice
to stay local and dogfood-oriented: Linux only, aimed at his own machine, with
tracked package setup that can later become the basis for GitHub Release binary
uploads and AUR publication.

This feature must not publish anything. It should create the local build and
package path, keep generated outputs ignored, and describe future publishing as
future work only.

## Requirements

- R1: Provide a local Linux release artifact command or script that builds a
  release-mode `git-hotspots` binary from the checked-out source and assembles a
  release archive suitable for later manual GitHub Release upload.
- R2: The release archive must include the executable plus redistributable
  project notices needed for a binary distribution, including `LICENSE` and
  `THIRD_PARTY_NOTICES.md` when present.
- R3: Generated release and package outputs must stay under ignored local build
  directories such as `dist/` or `zig-out/`; no generated binary archive or
  system package is committed.
- R4: Default release and package commands must not contact GitHub, create tags,
  upload files, publish to AUR, fetch remote release metadata, emit telemetry,
  or require credentials.
- R5: Provide an Arch/AUR-compatible package setup for local dogfood use. The
  default package direction is `git-hotspots-bin`, consuming the generated local
  release archive, because the first intended public distribution surface is a
  binary artifact.
- R6: Document local Arch build and install commands for Arsham's machine using
  standard local tooling such as `makepkg` and `pacman`, while clearly labelling
  the package as unpublished dogfood setup.
- R7: The installed or package-extracted binary must expose `git-hotspots` on
  `PATH` and preserve existing `--version` and `--help` behaviour.
- R8: Keep source-build instructions as the public default until binaries and
  AUR packages are actually published.
- R9: Update `README.md`, `docs/user-guide.md`, `docs/developer-guide.md`,
  `man/git-hotspots.1`, and validation guidance where their current
  source-build-only or no-packaging statements become stale.
- R10: Scope the implementation to native Linux dogfooding. macOS, Windows,
  multi-architecture release builds, CI release automation, signing,
  reproducible-build guarantees, official checksums, and publication workflows
  are out of scope.

## Non-goals

- Publishing a GitHub Release or creating release tags.
- Publishing to AUR or creating/maintaining an AUR remote.
- Adding hosted release automation, credentials, or GitHub Actions release
  workflows.
- Supporting non-Linux platforms or cross-compilation in this first pass.
- Changing runtime hotspot evidence semantics or adding network access,
  telemetry, remote enrichment, or package-manager dependencies at runtime.

## Edge cases

- If release packaging is invoked on a non-Linux host, it should either be
  unavailable or fail with an actionable Linux-only diagnostic.
- If `makepkg`, `pacman`, or other Arch tooling is unavailable, validation must
  record an explicit unavailable-tool finding and still prove the release
  archive path independently.
- If local package installation would overwrite an existing user-managed
  `git-hotspots`, implementation must document a safe inspect/extract smoke
  path and avoid requiring privileged installation for automated validation.
- If package metadata needs a version value, it should derive from or be checked
  against the existing CLI version contract so `--version`, docs, and package
  metadata do not drift silently.
- If a source-building AUR package is preferred instead of `git-hotspots-bin`,
  stop and replan the package packet before execution.

## Verification notes

- Build and validate existing source behaviour with `zig build test` and
  `zig build validate`.
- Run the release artifact command, unpack the archive, and run the unpacked
  binary with `--version` and `--help`.
- Prove generated archives and packages remain ignored local outputs and do not
  dirty tracked state.
- When Arch tooling is available, run package metadata checks such as
  `makepkg --printsrcinfo`, build the package with `makepkg -f`, inspect it with
  `pacman -Qp`, and smoke-test the package-extracted or installed binary.
- When Arch tooling is unavailable, record that explicitly and include the
  manual command sequence Arsham can run on his Linux machine.
- Use privacy-safe evidence only: no absolute local paths, credentials, package
  upload logs, or raw private repository output in committed artifacts.
