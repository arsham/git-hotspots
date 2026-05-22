#!/bin/sh
set -eu

EXE=$1
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

assert_fails_with_output() {
  label=$1
  shift
  out=$(mktemp)
  err=$(mktemp)
  if "$@" >"$out" 2>"$err"; then
    echo "$label unexpectedly succeeded" >&2
    exit 1
  fi
  if [ ! -s "$err" ]; then
    echo "$label produced no stderr" >&2
    exit 1
  fi
}

sh tools/setup-fixtures.sh

"$EXE" --repo fixtures/basic --format json > /tmp/git-hotspots-basic.json
diff -u fixtures/expected/basic.json /tmp/git-hotspots-basic.json
"$EXE" --repo fixtures/basic --format json > /tmp/git-hotspots-basic-2.json
diff -u /tmp/git-hotspots-basic.json /tmp/git-hotspots-basic-2.json

nongit=$(mktemp -d)
assert_fails_with_output non-git "$EXE" --repo "$nongit"
empty=$(mktemp -d)
git -C "$empty" init -q
git -C "$empty" config commit.gpgsign false
assert_fails_with_output empty "$EXE" --repo "$empty"
bare=$(mktemp -d)
git init --bare -q "$bare/repo.git"
assert_fails_with_output bare "$EXE" --repo "$bare/repo.git"
assert_fails_with_output invalid-since "$EXE" --repo fixtures/basic --since does-not-exist

"$EXE" --repo fixtures/edge --limit 200 --format json > /tmp/git-hotspots-edge.json
"$EXE" --repo fixtures/medium --format json > /tmp/git-hotspots-medium.json
"$EXE" --repo fixtures/shallow --format json > /tmp/git-hotspots-shallow.json
"$EXE" --repo fixtures/partial --format json > /tmp/git-hotspots-partial.json
"$EXE" --repo fixtures/detached --format json > /tmp/git-hotspots-detached.json
"$EXE" --repo fixtures/linked --format json > /tmp/git-hotspots-linked.json

python3 - <<'PY'
import json
from pathlib import Path

def load(path):
    return json.loads(Path(path).read_text())

def by_path(data):
    return {row['path']: row for row in data['results']}

basic = load('/tmp/git-hotspots-basic.json')
assert basic['results'][0]['path'] == 'src/app.txt'
assert all(not row['path'].startswith('/') for row in basic['results'])

edge = load('/tmp/git-hotspots-edge.json')
rows = by_path(edge)
for path in ['weird/path with space.txt', 'weird/éclair.txt', 'renamed.txt']:
    assert path in rows, path
assert any('tab' in path for path in rows), 'tab path missing'
assert rows['gone.txt']['current_size'] is None
assert any('deleted' in c for c in rows['gone.txt']['caveats'])
assert any('binary' in c for c in rows['bin/blob.bin']['caveats'])
assert any(any('large commit' in c for c in row['caveats']) for row in edge['results'])
paths = [row['path'] for row in edge['results']]
assert paths.index('tie/a.txt') < paths.index('tie/b.txt')
assert edge['analysis']['history']['commit_count'] >= 5

medium = load('/tmp/git-hotspots-medium.json')
assert medium['analysis']['history']['dirty_worktree'] is True
assert any('dirty worktree' in c for c in medium['analysis']['caveats'])

shallow = load('/tmp/git-hotspots-shallow.json')
assert shallow['analysis']['history']['is_shallow'] is True
assert shallow['analysis']['history']['auto_fetch'] is False

partial = load('/tmp/git-hotspots-partial.json')
assert partial['analysis']['history']['is_partial'] is True
assert partial['analysis']['history']['auto_fetch'] is False

for label, path in [('detached','/tmp/git-hotspots-detached.json'), ('linked','/tmp/git-hotspots-linked.json')]:
    data = load(path)
    assert data['results'], label
PY
