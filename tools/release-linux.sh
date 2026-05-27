#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT" || exit 1

if [ "$(uname -s)" != "Linux" ]; then
  echo "release-linux: local Linux host required; cross-platform release builds are future work" >&2
  exit 2
fi

VERSION=$(sed -n 's/^pub const value = "\(.*\)";$/\1/p' src/version.zig)
if [ -z "$VERSION" ]; then
  echo "release-linux: could not read version from src/version.zig" >&2
  exit 1
fi

ARCH=$(uname -m)
case "$ARCH" in
  x86_64|aarch64) ;;
  *)
    echo "release-linux: unsupported local Linux architecture: $ARCH" >&2
    echo "release-linux: native Linux dogfood builds currently support x86_64 and aarch64" >&2
    exit 2
    ;;
esac

NAME=git-hotspots-${VERSION}-linux-${ARCH}
DIST_DIR=dist
WORK_DIR=$DIST_DIR/work/$NAME
INSTALL_PREFIX=$WORK_DIR/install
STAGE_DIR=$WORK_DIR/stage
ARCHIVE=$DIST_DIR/$NAME.tar.gz

rm -rf "$WORK_DIR"
mkdir -p "$INSTALL_PREFIX" "$STAGE_DIR/$NAME/man"

zig build -Doptimize=ReleaseSafe -p "$INSTALL_PREFIX"

install -Dm755 "$INSTALL_PREFIX/bin/git-hotspots" "$STAGE_DIR/$NAME/git-hotspots"
install -Dm644 LICENSE "$STAGE_DIR/$NAME/LICENSE"
install -Dm644 README.md "$STAGE_DIR/$NAME/README.md"
install -Dm644 man/git-hotspots.1 "$STAGE_DIR/$NAME/man/git-hotspots.1"
if [ -f THIRDPARTYNOTICES.md ]; then
  install -Dm644 THIRDPARTYNOTICES.md "$STAGE_DIR/$NAME/THIRDPARTYNOTICES.md"
fi

ACTUAL_VERSION=$("$STAGE_DIR/$NAME/git-hotspots" --version)
EXPECTED_VERSION="git-hotspots $VERSION"
if [ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]; then
  echo "release-linux: built binary reported '$ACTUAL_VERSION', expected '$EXPECTED_VERSION'" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
TMP_ARCHIVE=$ARCHIVE.tmp
rm -f "$TMP_ARCHIVE"
(
  cd "$STAGE_DIR"
  tar -czf "$ROOT/$TMP_ARCHIVE" "$NAME"
)
mv "$TMP_ARCHIVE" "$ARCHIVE"

printf 'release-linux: built %s\n' "$ARCHIVE"
printf 'release-linux: package source copy command: cp %s packaging/aur/git-hotspots-bin/\n' "$ARCHIVE"
