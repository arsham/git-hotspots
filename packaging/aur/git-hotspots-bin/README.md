# git-hotspots-bin local dogfood package

This directory contains an unpublished Arch/AUR-compatible `PKGBUILD` for local
Linux dogfood use. It consumes the local release archive produced by
`tools/release-linux.sh`; it does not fetch release data, upload packages, or
publish to AUR.

From the repository root:

```sh
./tools/release-linux.sh
cp dist/git-hotspots-0.1.0-alpha.1-linux-$(uname -m).tar.gz packaging/aur/git-hotspots-bin/
cd packaging/aur/git-hotspots-bin
makepkg --printsrcinfo
makepkg -f
pacman -Qp git-hotspots-bin-0.1.0_alpha.1-1-$(uname -m).pkg.tar*
```

To smoke-test without installing system-wide, extract the built package into a
temporary directory and run the binary from that directory:

```sh
mkdir -p /tmp/git-hotspots-package-smoke
bsdtar -xf git-hotspots-bin-0.1.0_alpha.1-1-$(uname -m).pkg.tar* -C /tmp/git-hotspots-package-smoke
/tmp/git-hotspots-package-smoke/usr/bin/git-hotspots --version
/tmp/git-hotspots-package-smoke/usr/bin/git-hotspots --help
```

If local installation is safe for your machine, install with pacman and remove
with pacman when done:

```sh
sudo pacman -U git-hotspots-bin-0.1.0_alpha.1-1-$(uname -m).pkg.tar*
git-hotspots --version
git-hotspots --help
sudo pacman -R git-hotspots-bin
```

Do not require privileged installation for automated validation. Use the
package-extracted smoke path when an existing user-managed `git-hotspots` could
be overwritten.
