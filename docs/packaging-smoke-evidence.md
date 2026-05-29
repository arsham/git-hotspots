# Packaging smoke evidence

This note records the privacy-safe local packaging evidence expected for the
current unpublished Linux dogfood path. Do not commit generated archives,
packages, absolute local paths, upload logs, or machine-specific raw output.

Expected validation sequence:

1. Run `./tools/release-linux.sh` on a native Linux host.
2. Unpack `dist/git-hotspots-0.1.0-alpha.3-linux-$(uname -m).tar.gz` into a
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
