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
  mkdir -p "$repo/src" "$repo/.flow" "$repo/.zig-cache" "$repo/zig-out" "$repo/target" "$repo/node_modules/pkg" "$repo/dist" "$repo/build" "$repo/coverage" "$repo/vendor" "$repo/glob" "$repo/weird" "$repo/docs"
  setup_repo "$repo"

  printf 'pub fn main() void {}\n' > "$repo/src/app.txt"
  printf 'old name\n' > "$repo/src/old.zig"
  printf 'adapter one\n' > "$repo/src/vendor_adapter.zig"
  printf 'helper one\n' > "$repo/src/buildtool.zig"
  printf 'adapter one\n' > "$repo/src/vendoradapter.zig"
  printf 'included to excluded one\n' > "$repo/src/to-cache.txt"
  printf 'chain cross one\n' > "$repo/src/chain-start.txt"
  printf 'coverage docs one\n' > "$repo/docs/coverage.md"
  printf 'vendor one\n' > "$repo/vendor/lib.txt"
  printf 'literal glob\n' > "$repo/glob/[literal]*.txt"
  printf 'tab scoped\n' > "$repo/weird/tab	name.txt"
  printf 'state one\n' > "$repo/.flow/state.yaml"
  printf 'cache one\n' > "$repo/.zig-cache/file.txt"
  printf 'zig-out one\n' > "$repo/zig-out/app.bin"
  printf 'target one\n' > "$repo/target/app.o"
  printf 'module one\n' > "$repo/node_modules/pkg/index.js"
  printf 'dist one\n' > "$repo/dist/app.js"
  printf 'build one\n' > "$repo/build/app.o"
  printf 'coverage one\n' > "$repo/coverage/report.txt"
  commit_all "$repo" '2026-03-01T00:00:00+0000' 'initial source and workflow files'

  git -C "$repo" mv src/old.zig src/new.zig
  printf 'pub fn main() void {\n  // v2\n}\n' > "$repo/src/app.txt"
  printf 'state one\nstate two\n' > "$repo/.flow/state.yaml"
  printf 'cache one\ncache two\n' > "$repo/.zig-cache/file.txt"
  printf 'zig-out one\nzig-out two\n' > "$repo/zig-out/app.bin"
  printf 'target one\ntarget two\n' > "$repo/target/app.o"
  printf 'excluded to excluded one\n' > "$repo/target/excluded-chain-a.txt"
  printf 'module one\nmodule two\n' > "$repo/node_modules/pkg/index.js"
  printf 'dist one\ndist two\n' > "$repo/dist/app.js"
  printf 'build one\nbuild two\n' > "$repo/build/app.o"
  printf 'coverage one\ncoverage two\n' > "$repo/coverage/report.txt"
  commit_all "$repo" '2026-03-02T00:00:00+0000' 'change app and workflow state'

  printf 'state one\nstate two\nstate three\n' > "$repo/.flow/state.yaml"
  printf 'other workflow\n' > "$repo/.flow/other.yaml"
  printf 'cache one\ncache two\ncache three\n' > "$repo/.zig-cache/file.txt"
  printf 'module one\nmodule two\nmodule three\n' > "$repo/node_modules/pkg/index.js"
  git -C "$repo" mv src/to-cache.txt .zig-cache/from-src.txt
  git -C "$repo" mv target/excluded-chain-a.txt build/excluded-chain-b.txt
  git -C "$repo" mv src/chain-start.txt node_modules/pkg/chain-mid.txt
  commit_all "$repo" '2026-03-03T00:00:00+0000' 'workflow-only churn'

  printf 'vendor one\nvendor two\n' > "$repo/vendor/lib.txt"
  printf 'adapter one\nadapter two\n' > "$repo/src/vendor_adapter.zig"
  printf 'helper one\nhelper two\n' > "$repo/src/buildtool.zig"
  printf 'adapter one\nadapter two\n' > "$repo/src/vendoradapter.zig"
  printf 'coverage docs one\ncoverage docs two\n' > "$repo/docs/coverage.md"
  git -C "$repo" mv node_modules/pkg/chain-mid.txt src/chain-final.txt
  commit_all "$repo" '2026-03-04T00:00:00+0000' 'vendor and adapter change'

  printf 'pub fn main() void {\n  // v2\n  // v3\n}\n' > "$repo/src/app.txt"
  printf 'state one\nstate two\nstate three\nstate four\n' > "$repo/.flow/state.yaml"
  printf 'adapter one\nadapter two\nadapter three\n' > "$repo/src/vendor_adapter.zig"
  printf 'module one\nmodule two\nmodule three\nmodule four\n' > "$repo/node_modules/pkg/index.js"
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


make_symbols() {
  repo="$FIX/symbols"
  rm -rf "$repo"
  mkdir -p "$repo/src"
  setup_repo "$repo"

  cat > "$repo/src/example.zig" <<'EOF'
pub fn zebra() void {}

fn alpha() void {}
EOF
  printf 'not zig\n' > "$repo/src/readme.txt"
  cat > "$repo/src/target.zig" <<'EOF'
pub fn target() void {}
EOF
  ln -s target.zig "$repo/src/link.zig"
  commit_all "$repo" '2026-05-01T00:00:00+0000' 'initial symbol files'

  cat > "$repo/src/example.zig" <<'EOF'
pub fn zebra() void {
    return;
}

fn alpha() void {}
EOF
  commit_all "$repo" '2026-05-02T00:00:00+0000' 'expand zig function'
}

make_go_symbols() {
  repo="$FIX/go-symbols"
  rm -rf "$repo"
  mkdir -p "$repo/src"
  setup_repo "$repo"

  cat > "$repo/src/old-example.go" <<'EOF'
package symbols

const (
    Alpha = 1
    Beta = 2
)

var Gamma = 3

func Zebra() {}

type Service struct{}
type Runner interface{ Run() }

func (s Service) Method() {}
EOF
  printf '' > "$repo/src/empty.go"
  cat > "$repo/src/broken.go" <<'EOF'
package symbols
func {
EOF
  cat > "$repo/src/caveated.go" <<'EOF'
// Code generated by local fixture; DO NOT EDIT.
//go:build linux
package symbols

import "C"

func Visible() {}
EOF
  cat > "$repo/src/other.go" <<'EOF'
package symbols

func OtherOnly() {}
EOF
  cat > "$repo/src/target.go" <<'EOF'
package symbols

func Target() {}
EOF
  ln -s target.go "$repo/src/link.go"
  python3 - <<'PY' > "$repo/src/large.go"
print('package symbols')
print('func Large() {}')
print('// ' + 'x' * (1024 * 1024 + 1))
PY
  cat > "$repo/src/missing.go" <<'EOF'
package symbols

func Missing() {}
EOF
  commit_all "$repo" '2026-05-01T00:00:00+0000' 'initial go symbol files'

  git -C "$repo" mv src/old-example.go src/example.go
  cat > "$repo/src/example.go" <<'EOF'
package symbols

const (
    Alpha = 1
    Beta = 2
)

var Gamma = 3

func Zebra() {
    return
}

type Service struct{}
type Runner interface{ Run() }

func (s Service) Method() {}
EOF
  rm "$repo/src/missing.go"
  commit_all "$repo" '2026-05-02T00:00:00+0000' 'expand go symbol functions'
}

make_python_symbols() {
  repo="$FIX/python-symbols"
  rm -rf "$repo"
  mkdir -p "$repo/src"
  setup_repo "$repo"

  cat > "$repo/src/old_example.py" <<'EOF'
"""Module fixture with Markdown-sensitive text: ```python and | tables |."""

from __future__ import annotations

CONSTANT = 1
mutable_value = 2
FIRST, SECOND = (1, 2)
locals()["DYNAMIC"] = 3

@decorator
def top_function(arg):
    local_value = 1

    def inner_function():
        return arg

    class InnerClass:
        pass

    return inner_function

@decorator
class Outer:
    class Nested:
        pass

    @decorator
    def method(self):
        def method_inner():
            return self
        return method_inner

def café():
    return "unicode"
EOF
  printf '' > "$repo/src/empty.py"
  cat > "$repo/src/invalid_partial.py" <<'EOF'
def broken(:
    pass
EOF
  cat > "$repo/src/generated.py" <<'EOF'
# Code generated by local fixture; DO NOT EDIT.
AUTO_CONSTANT = 1

def generated_function():
    return AUTO_CONSTANT
EOF
  cat > "$repo/src/other.py" <<'EOF'
def OtherOnly():
    return 1
EOF
  cat > "$repo/src/markdown|path.py" <<'EOF'
def pipe_path():
    return "|"
EOF
  cat > "$repo/src/target.py" <<'EOF'
def target():
    return 1
EOF
  ln -s target.py "$repo/src/link.py"
  python3 - <<'PY' > "$repo/src/large.py"
print('def Large():')
print('    return 1')
print('# ' + 'x' * (1024 * 1024 + 1))
PY
  cat > "$repo/src/missing.py" <<'EOF'
def missing():
    return 1
EOF
  commit_all "$repo" '2026-05-01T00:00:00+0000' 'initial python symbol files'

  git -C "$repo" mv src/old_example.py src/example.py
  cat > "$repo/src/example.py" <<'EOF'
"""Module fixture with Markdown-sensitive text: ```python and | tables |."""

from __future__ import annotations

CONSTANT = 1
mutable_value = 2
FIRST, SECOND = (1, 2)
locals()["DYNAMIC"] = 3

@decorator
def top_function(arg):
    local_value = 1

    def inner_function():
        return arg

    class InnerClass:
        pass

    return inner_function

@decorator
class Outer:
    class Nested:
        pass

    @decorator
    def method(self):
        def method_inner():
            return self
        return method_inner

def café():
    return "unicode"
EOF
  rm "$repo/src/missing.py"
  commit_all "$repo" '2026-05-02T00:00:00+0000' 'expand python symbol functions'
}

make_symbol_line_history() {
  repo="$FIX/symbol-line-history"
  rm -rf "$repo"
  mkdir -p "$repo/src"
  setup_repo "$repo"

  cat > "$repo/src/current.zig" <<'EOF'
pub fn alpha() void {}

pub fn beta() void {}

fn gamma() void {}
EOF
  printf 'not zig\n' > "$repo/src/readme.txt"
  printf '' > "$repo/src/empty.zig"
  cat > "$repo/src/broken.zig" <<'EOF'
pub fn broken() void {
EOF
  cat > "$repo/src/target.zig" <<'EOF'
pub fn target() void {}
EOF
  ln -s target.zig "$repo/src/link.zig"
  commit_all "$repo" '2026-06-01T00:00:00+0000' 'initial current-line fixture files'

  cat > "$repo/src/current.zig" <<'EOF'
pub fn alpha() void {
    const value = 1;
    _ = value;
}

pub fn beta() void {}

fn gamma() void {}
EOF
  commit_all "$repo" '2026-06-02T00:00:00+0000' 'expand alpha fixture function'

  cat > "$repo/src/current.zig" <<'EOF'
// current-line fixture comment outside symbols
pub fn alpha() void {
    const value = 1;
    _ = value;
}

pub fn beta() void {
    return;
}

fn gamma() void {}
EOF
  commit_all "$repo" '2026-06-03T00:00:00+0000' 'shift lines and expand beta fixture function'
}

make_basic
make_edge
make_scope
make_lineage
make_symbols
make_go_symbols
make_python_symbols
make_symbol_line_history
rm -rf "$FIX/shallow" "$FIX/medium" "$FIX/partial" "$FIX/detached" "$FIX/linked" "$FIX/symbol-line-history-shallow" "$FIX/symbol-line-history-partial" "$FIX/go-symbols-shallow" "$FIX/go-symbols-partial" "$FIX/python-symbols-shallow" "$FIX/python-symbols-partial"
git clone -q --depth 1 "file://$FIX/basic" "$FIX/shallow"
git clone -q "$FIX/basic" "$FIX/medium"
printf 'local dirty note\n' >> "$FIX/medium/docs/guide.md"
git clone -q "$FIX/basic" "$FIX/partial"
git -C "$FIX/partial" config remote.origin.promisor true
git clone -q "$FIX/basic" "$FIX/detached"
git -C "$FIX/detached" checkout -q --detach HEAD~1
git -C "$FIX/basic" worktree add -q "$FIX/linked" HEAD
git clone -q --depth 1 "file://$FIX/symbol-line-history" "$FIX/symbol-line-history-shallow"
git clone -q "$FIX/symbol-line-history" "$FIX/symbol-line-history-partial"
git -C "$FIX/symbol-line-history-partial" config remote.origin.promisor true
git clone -q --depth 1 "file://$FIX/go-symbols" "$FIX/go-symbols-shallow"
git clone -q "$FIX/go-symbols" "$FIX/go-symbols-partial"
git -C "$FIX/go-symbols-partial" config remote.origin.promisor true
git clone -q --depth 1 "file://$FIX/python-symbols" "$FIX/python-symbols-shallow"
git clone -q "$FIX/python-symbols" "$FIX/python-symbols-partial"
git -C "$FIX/python-symbols-partial" config remote.origin.promisor true
