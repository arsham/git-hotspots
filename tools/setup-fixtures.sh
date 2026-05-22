#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FIX="$ROOT/fixtures"
mkdir -p "$FIX"

setup_repo() {
  repo=$1
  git init -q -b main "$repo"
  git -C "$repo" config user.name "Fixture Author"
  git -C "$repo" config user.email "fixture@example.invalid"
  git -C "$repo" config commit.gpgsign false
}

commit_all() {
  repo=$1
  date=$2
  msg=$3
  git -C "$repo" add -A
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" git -C "$repo" commit -q -m "$msg"
}

make_basic() {
  repo="$FIX/basic"
  rm -rf "$repo"
  mkdir -p "$repo/src" "$repo/docs"
  setup_repo "$repo"

  printf 'Git Hotspots Fixture\n' > "$repo/README.md"
  printf 'one\n' > "$repo/src/app.txt"
  commit_all "$repo" '2026-01-01T00:00:00+0000' 'initial files'

  printf 'one\ntwo\nthree\n' > "$repo/src/app.txt"
  printf 'alpha\n' > "$repo/src/lib.txt"
  commit_all "$repo" '2026-01-02T00:00:00+0000' 'expand app and lib'

  printf 'one\ntwo\nthree\nfour\n' > "$repo/src/app.txt"
  printf 'guide\nnotes\n' > "$repo/docs/guide.md"
  commit_all "$repo" '2026-01-03T00:00:00+0000' 'add guide and app line'

  printf 'alpha\nbeta\ngamma\n' > "$repo/src/lib.txt"
  commit_all "$repo" '2026-01-04T00:00:00+0000' 'expand lib'
}

make_edge() {
  repo="$FIX/edge"
  rm -rf "$repo"
  mkdir -p "$repo/weird" "$repo/bin" "$repo/mass" "$repo/tie"
  setup_repo "$repo"

  printf 'one\n' > "$repo/tie/a.txt"
  printf 'one\n' > "$repo/tie/b.txt"
  printf 'space\n' > "$repo/weird/path with space.txt"
  printf 'unicode\n' > "$repo/weird/éclair.txt"
  printf 'tab\n' > "$repo/weird/tab	name.txt"
  printf 'old\n' > "$repo/old-name.txt"
  printf 'gone\n' > "$repo/gone.txt"
  printf '\000\001\002\003' > "$repo/bin/blob.bin"
  commit_all "$repo" '2026-02-01T00:00:00+0000' 'initial edge files'

  printf 'one\ntwo\n' > "$repo/tie/a.txt"
  printf 'one\ntwo\n' > "$repo/tie/b.txt"
  commit_all "$repo" '2026-02-02T00:00:00+0000' 'equal tie changes'

  git -C "$repo" mv old-name.txt renamed.txt
  rm "$repo/gone.txt"
  printf '\000\004\005\006' >> "$repo/bin/blob.bin"
  commit_all "$repo" '2026-02-03T00:00:00+0000' 'rename delete binary'

  i=1
  while [ "$i" -le 55 ]; do
    printf 'generated %s\n' "$i" > "$repo/mass/file-$i.txt"
    i=$((i + 1))
  done
  commit_all "$repo" '2026-02-04T00:00:00+0000' 'large generated import'

  git -C "$repo" checkout -q -b side HEAD~1
  printf 'side\n' > "$repo/side.txt"
  commit_all "$repo" '2026-02-05T00:00:00+0000' 'side branch change'
  git -C "$repo" checkout -q main
  GIT_AUTHOR_DATE='2026-02-06T00:00:00+0000' GIT_COMMITTER_DATE='2026-02-06T00:00:00+0000' git -C "$repo" merge -q --no-ff side -m 'merge side branch'
}

make_basic
make_edge
rm -rf "$FIX/shallow" "$FIX/medium" "$FIX/partial" "$FIX/detached" "$FIX/linked"
git clone -q --depth 1 "file://$FIX/basic" "$FIX/shallow"
git clone -q "$FIX/basic" "$FIX/medium"
printf 'local dirty note\n' >> "$FIX/medium/docs/guide.md"
git clone -q "$FIX/basic" "$FIX/partial"
git -C "$FIX/partial" config remote.origin.promisor true
git clone -q "$FIX/basic" "$FIX/detached"
git -C "$FIX/detached" checkout -q --detach HEAD~1
git -C "$FIX/basic" worktree add -q "$FIX/linked" HEAD
