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
  mkdir -p "$repo/weird" "$repo/bin" "$repo/mass" "$repo/tie" "$repo/glob"
  setup_repo "$repo"

  printf 'one\n' > "$repo/tie/a.txt"
  printf 'one\n' > "$repo/tie/b.txt"
  printf 'space\n' > "$repo/weird/path with space.txt"
  printf 'unicode\n' > "$repo/weird/éclair.txt"
  printf 'tab\n' > "$repo/weird/tab	name.txt"
  printf 'glob literal\n' > "$repo/glob/[literal]*.txt"
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

make_scope() {
  repo="$FIX/scope"
  rm -rf "$repo"
  mkdir -p "$repo/src" "$repo/.flow" "$repo/vendor" "$repo/glob" "$repo/weird"
  setup_repo "$repo"

  printf 'pub fn main() void {}\n' > "$repo/src/app.txt"
  printf 'old name\n' > "$repo/src/old.zig"
  printf 'adapter one\n' > "$repo/src/vendor_adapter.zig"
  printf 'vendor one\n' > "$repo/vendor/lib.txt"
  printf 'literal glob\n' > "$repo/glob/[literal]*.txt"
  printf 'tab scoped\n' > "$repo/weird/tab	name.txt"
  printf 'state one\n' > "$repo/.flow/state.yaml"
  commit_all "$repo" '2026-03-01T00:00:00+0000' 'initial source and workflow files'

  git -C "$repo" mv src/old.zig src/new.zig
  printf 'pub fn main() void {\n  // v2\n}\n' > "$repo/src/app.txt"
  printf 'state one\nstate two\n' > "$repo/.flow/state.yaml"
  commit_all "$repo" '2026-03-02T00:00:00+0000' 'change app and workflow state'

  printf 'state one\nstate two\nstate three\n' > "$repo/.flow/state.yaml"
  printf 'other workflow\n' > "$repo/.flow/other.yaml"
  commit_all "$repo" '2026-03-03T00:00:00+0000' 'workflow-only churn'

  printf 'vendor one\nvendor two\n' > "$repo/vendor/lib.txt"
  printf 'adapter one\nadapter two\n' > "$repo/src/vendor_adapter.zig"
  commit_all "$repo" '2026-03-04T00:00:00+0000' 'vendor and adapter change'

  printf 'pub fn main() void {\n  // v2\n  // v3\n}\n' > "$repo/src/app.txt"
  printf 'state one\nstate two\nstate three\nstate four\n' > "$repo/.flow/state.yaml"
  printf 'adapter one\nadapter two\nadapter three\n' > "$repo/src/vendor_adapter.zig"
  commit_all "$repo" '2026-03-05T00:00:00+0000' 'mixed source and workflow churn'
}

make_lineage() {
  repo="$FIX/lineage"
  rm -rf "$repo"
  mkdir -p "$repo/src" "$repo/vendor" "$repo/braced" "$repo/chain" "$repo/cochange"
  setup_repo "$repo"

  printf 'simple one\n' > "$repo/simple-old.txt"
  printf 'braced one\n' > "$repo/braced/old-name.txt"
  printf 'chain one\n' > "$repo/chain/a.txt"
  printf 'edit one\n' > "$repo/rename-edit-old.txt"
  printf 'deleted one\n' > "$repo/deleted-old.txt"
  printf 'cross one\n' > "$repo/vendor/cross-old.txt"
  printf 'co one\n' > "$repo/cochange/old.txt"
  printf 'peer one\n' > "$repo/cochange/peer.txt"
  commit_all "$repo" '2026-04-01T00:00:00+0000' 'initial lineage files'

  printf 'co one\nco two\n' > "$repo/cochange/old.txt"
  printf 'peer one\npeer two\n' > "$repo/cochange/peer.txt"
  commit_all "$repo" '2026-04-02T00:00:00+0000' 'cochange before rename'

  git -C "$repo" mv simple-old.txt simple-new.txt
  git -C "$repo" mv braced/old-name.txt braced/new-name.txt
  git -C "$repo" mv chain/a.txt chain/b.txt
  git -C "$repo" mv rename-edit-old.txt rename-edit-new.txt
  printf 'edit one\nedit two\n' > "$repo/rename-edit-new.txt"
  git -C "$repo" mv deleted-old.txt deleted-new.txt
  git -C "$repo" mv vendor/cross-old.txt src/cross-new.txt
  git -C "$repo" mv cochange/old.txt cochange/new.txt
  printf 'co one\nco two\nco three\n' > "$repo/cochange/new.txt"
  printf 'peer one\npeer two\npeer three\n' > "$repo/cochange/peer.txt"
  commit_all "$repo" '2026-04-03T00:00:00+0000' 'rename files with edits'

  git -C "$repo" mv chain/b.txt chain/c.txt
  printf 'chain one\nchain two\n' > "$repo/chain/c.txt"
  rm "$repo/deleted-new.txt"
  printf 'co one\nco two\nco three\nco four\n' > "$repo/cochange/new.txt"
  printf 'peer one\npeer two\npeer three\npeer four\n' > "$repo/cochange/peer.txt"
  commit_all "$repo" '2026-04-04T00:00:00+0000' 'chained rename delete and cochange after rename'
}

make_basic
make_edge
make_scope
make_lineage
rm -rf "$FIX/shallow" "$FIX/medium" "$FIX/partial" "$FIX/detached" "$FIX/linked"
git clone -q --depth 1 "file://$FIX/basic" "$FIX/shallow"
git clone -q "$FIX/basic" "$FIX/medium"
printf 'local dirty note\n' >> "$FIX/medium/docs/guide.md"
git clone -q "$FIX/basic" "$FIX/partial"
git -C "$FIX/partial" config remote.origin.promisor true
git clone -q "$FIX/basic" "$FIX/detached"
git -C "$FIX/detached" checkout -q --detach HEAD~1
git -C "$FIX/basic" worktree add -q "$FIX/linked" HEAD
