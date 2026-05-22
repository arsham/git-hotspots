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

assert_fails_with_stderr() {
  label=$1
  pattern=$2
  shift 2
  err=$(mktemp)
  if "$@" >/dev/null 2>"$err"; then
    echo "$label unexpectedly succeeded" >&2
    exit 1
  fi
  if ! grep -q -- "$pattern" "$err"; then
    echo "$label stderr did not contain $pattern" >&2
    exit 1
  fi
}

sh tools/setup-fixtures.sh

"$EXE" --repo fixtures/basic --format json > /tmp/git-hotspots-basic.json
diff -u fixtures/expected/basic.json /tmp/git-hotspots-basic.json
"$EXE" --repo fixtures/basic --format json > /tmp/git-hotspots-basic-2.json
diff -u /tmp/git-hotspots-basic.json /tmp/git-hotspots-basic-2.json
"$EXE" --repo fixtures/basic --format markdown > /tmp/git-hotspots-basic.md
diff -u fixtures/expected/basic.md /tmp/git-hotspots-basic.md
"$EXE" --repo fixtures/basic --format markdown > /tmp/git-hotspots-basic-2.md
diff -u /tmp/git-hotspots-basic.md /tmp/git-hotspots-basic-2.md
"$EXE" --repo fixtures/scope --format json > /tmp/git-hotspots-scope-unfiltered.json
"$EXE" --repo fixtures/scope --exclude-prefix .flow/ --format json > /tmp/git-hotspots-scope-filtered.json
diff -u fixtures/expected/scope-filtered.json /tmp/git-hotspots-scope-filtered.json
"$EXE" --repo fixtures/scope --exclude-prefix .flow/ --format markdown > /tmp/git-hotspots-scope-filtered.md
diff -u fixtures/expected/scope-filtered.md /tmp/git-hotspots-scope-filtered.md
"$EXE" --repo fixtures/scope --exclude-prefix .flow/ --format markdown > /tmp/git-hotspots-scope-filtered-2.md
diff -u /tmp/git-hotspots-scope-filtered.md /tmp/git-hotspots-scope-filtered-2.md
"$EXE" --repo fixtures/scope --exclude-prefix .flow/ --format table > /tmp/git-hotspots-scope-filtered.txt
"$EXE" --repo fixtures/scope --exclude-prefix vendor/ --format json > /tmp/git-hotspots-scope-vendor-filtered.json
"$EXE" --repo fixtures/scope --exclude-prefix src/ --format json > /tmp/git-hotspots-scope-src-filtered.json
"$EXE" --repo fixtures/scope --exclude-prefix weird/ --format json > /tmp/git-hotspots-scope-weird-filtered.json
"$EXE" --repo fixtures/scope --exclude-prefix 'glob/*' --format json > /tmp/git-hotspots-scope-glob-prefix.json
"$EXE" --repo fixtures/scope --exclude-prefix .flow/ --exclude-prefix src/ --exclude-prefix vendor/ --exclude-prefix glob/ --exclude-prefix weird/ --format json > /tmp/git-hotspots-scope-empty.json
"$EXE" --repo fixtures/scope --exclude-prefix .flow/ --exclude-prefix src/ --exclude-prefix vendor/ --exclude-prefix glob/ --exclude-prefix weird/ --format markdown > /tmp/git-hotspots-scope-empty.md

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
assert_fails_with_stderr invalid-format "invalid arguments" "$EXE" --repo fixtures/basic --format xml
assert_fails_with_stderr invalid-exclude-empty --exclude-prefix "$EXE" --repo fixtures/basic --exclude-prefix ""
assert_fails_with_stderr invalid-exclude-absolute --exclude-prefix "$EXE" --repo fixtures/basic --exclude-prefix /tmp
assert_fails_with_stderr invalid-exclude-parent --exclude-prefix "$EXE" --repo fixtures/basic --exclude-prefix src/../lib
ctrl=$(printf 'bad\001prefix')
assert_fails_with_stderr invalid-exclude-control --exclude-prefix "$EXE" --repo fixtures/basic --exclude-prefix "$ctrl"

"$EXE" --repo fixtures/edge --limit 200 --format json > /tmp/git-hotspots-edge.json
"$EXE" --repo fixtures/edge --limit 200 --format markdown > /tmp/git-hotspots-edge.md
"$EXE" --repo fixtures/medium --format json > /tmp/git-hotspots-medium.json
"$EXE" --repo fixtures/shallow --format json > /tmp/git-hotspots-shallow.json
"$EXE" --repo fixtures/partial --format json > /tmp/git-hotspots-partial.json
"$EXE" --repo fixtures/detached --format json > /tmp/git-hotspots-detached.json
"$EXE" --repo fixtures/linked --format json > /tmp/git-hotspots-linked.json

python3 - /tmp/git-hotspots-basic.md /tmp/git-hotspots-scope-filtered.md /tmp/git-hotspots-scope-empty.md /tmp/git-hotspots-edge.md <<'PY'
import json
import os
import re
import sys
from pathlib import Path

basic_md_path, scope_md_path, scope_empty_md_path, edge_md_path = map(Path, sys.argv[1:])

def load(path):
    return json.loads(Path(path).read_text())

def by_path(data):
    return {row['path']: row for row in data['results']}

basic = load('/tmp/git-hotspots-basic.json')
assert basic['analysis']['scope']['filters_active'] is False
assert basic['analysis']['scope']['exclude_prefixes'] == []
assert basic['results'][0]['path'] == 'src/app.txt'
assert all(not row['path'].startswith('/') for row in basic['results'])

scope_unfiltered = load('/tmp/git-hotspots-scope-unfiltered.json')
unfiltered_paths = [row['path'] for row in scope_unfiltered['results']]
assert any(path.startswith('.flow/') for path in unfiltered_paths), 'default scope fixture lost .flow paths'
assert 'src/new.zig' in unfiltered_paths, 'braced rename fixture missing new path'
assert any(path == 'weird/tab\tname.txt' for path in unfiltered_paths), 'quoted tab fixture missing unquoted path'
assert '' not in unfiltered_paths, 'empty path leaked from braced rename parsing'

scope_filtered = load('/tmp/git-hotspots-scope-filtered.json')
scope_meta = scope_filtered['analysis']['scope']
assert scope_meta == {
    'filters_active': True,
    'exclude_prefixes': ['.flow/'],
    'excluded_path_count': 2,
    'excluded_change_count': 5,
}, scope_meta
for row in scope_filtered['results']:
    assert not row['path'].startswith('.flow/'), row['path']
    assert all(not cc['path'].startswith('.flow/') for cc in row['cochanges']), row['path']
assert 'src/vendor_adapter.zig' in by_path(scope_filtered), 'vendor/ prefix semantics fixture missing adapter'

vendor_filtered = load('/tmp/git-hotspots-scope-vendor-filtered.json')
vendor_rows = by_path(vendor_filtered)
assert 'src/vendor_adapter.zig' in vendor_rows
assert 'vendor/lib.txt' not in vendor_rows

src_filtered = load('/tmp/git-hotspots-scope-src-filtered.json')
for row in src_filtered['results']:
    assert row['path'], 'empty path leaked from excluded braced rename'
    assert not row['path'].startswith('src/'), row['path']
    assert all(not cc['path'].startswith('src/') for cc in row['cochanges']), row['path']

weird_filtered = load('/tmp/git-hotspots-scope-weird-filtered.json')
for row in weird_filtered['results']:
    assert not row['path'].startswith('weird/'), row['path']
    assert not row['path'].startswith('"weird/'), row['path']
    assert all(not cc['path'].startswith('weird/') for cc in row['cochanges']), row['path']

glob_prefix = load('/tmp/git-hotspots-scope-glob-prefix.json')
assert 'glob/[literal]*.txt' in by_path(glob_prefix), 'glob-like prefix acted as a glob'

scope_empty = load('/tmp/git-hotspots-scope-empty.json')
assert scope_empty['results'] == []
assert scope_empty['analysis']['scope']['filters_active'] is True
assert scope_empty['analysis']['scope']['excluded_path_count'] >= 1

table_text = Path('/tmp/git-hotspots-scope-filtered.txt').read_text()
assert 'scope: exclude_prefixes=[.flow/]' in table_text
assert '.flow/' not in '\n'.join(line for line in table_text.splitlines() if line[:1].isdigit())

edge = load('/tmp/git-hotspots-edge.json')
rows = by_path(edge)
for path in ['weird/path with space.txt', 'weird/éclair.txt', 'renamed.txt']:
    assert path in rows, path
assert any('tab' in path for path in rows), 'tab path missing'
assert 'glob/[literal]*.txt' in rows, 'glob-looking literal path missing'
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

basic_md = basic_md_path.read_text()
assert '# git-hotspots report' in basic_md
assert 'File-level Git-history investigation prompts, not bug predictions or code-quality ratings.' in basic_md
for section in ['## Run summary', '## Scope', '## Caveats', '## Top hotspots', '## Evidence']:
    assert section in basic_md, section

scope_md = scope_md_path.read_text()
assert '- Filters active: true' in scope_md
assert '- Exclude prefixes: .flow/' in scope_md
assert '- Excluded path count: 2' in scope_md
assert '- Excluded change count: 5' in scope_md
for line in scope_md.splitlines():
    if line.startswith('| ') or line.startswith('### ') or line.startswith('  - '):
        assert '.flow/' not in line, line

scope_empty_md = scope_empty_md_path.read_text()
assert 'No hotspots matched the requested scope.' in scope_empty_md
assert 'No result evidence to show.' in scope_empty_md
for section in ['## Run summary', '## Scope', '## Caveats', '## Top hotspots', '## Evidence']:
    assert section in scope_empty_md, section

edge_md = edge_md_path.read_text()
assert 'weird/tab\\tname.txt' in edge_md
assert 'glob/\\[literal\\]\\*.txt' in edge_md
assert 'path is deleted or not present at HEAD' in edge_md
assert 'binary or non\\-text churn unavailable for some changes' in edge_md
for text in [basic_md, scope_md, scope_empty_md, edge_md]:
    assert '\t' not in text, 'raw tab leaked in markdown'
    assert 'Fixture Author' not in text
    assert 'fixture@example.invalid' not in text
    home = os.path.expanduser('~')
    assert not home or home not in text
    assert not re.search(r'https?://|ssh://|git@', text)
    assert not re.search(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', text)
PY
