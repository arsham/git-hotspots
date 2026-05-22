#!/bin/sh
set -eu

EXE=$1
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
case "$EXE" in
  /*) EXE_ABS=$EXE ;;
  *) EXE_ABS=$ROOT/${EXE#./} ;;
esac

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

"$EXE" --explain > /tmp/git-hotspots-explain.txt
diff -u fixtures/expected/explain.txt /tmp/git-hotspots-explain.txt
"$EXE" --explain > /tmp/git-hotspots-explain-2.txt
diff -u /tmp/git-hotspots-explain.txt /tmp/git-hotspots-explain-2.txt
"$EXE" --help > /tmp/git-hotspots-help.txt
grep -q -- "--explain" /tmp/git-hotspots-help.txt
grep -q -- "--version" /tmp/git-hotspots-help.txt
"$EXE" --version > /tmp/git-hotspots-version.txt 2> /tmp/git-hotspots-version.err
test "$(cat /tmp/git-hotspots-version.txt)" = "git-hotspots 0.1.0-alpha.1"
test ! -s /tmp/git-hotspots-version.err
explain_nongit=$(mktemp -d)
(cd "$explain_nongit" && "$EXE_ABS" --explain > /tmp/git-hotspots-explain-nongit.txt 2> /tmp/git-hotspots-explain-nongit.err)
diff -u fixtures/expected/explain.txt /tmp/git-hotspots-explain-nongit.txt
test ! -s /tmp/git-hotspots-explain-nongit.err
version_nongit=$(mktemp -d)
(cd "$version_nongit" && "$EXE_ABS" --version > /tmp/git-hotspots-version-nongit.txt 2> /tmp/git-hotspots-version-nongit.err)
test "$(cat /tmp/git-hotspots-version-nongit.txt)" = "git-hotspots 0.1.0-alpha.1"
test ! -s /tmp/git-hotspots-version-nongit.err
assert_fails_with_stderr explain-repo "--explain cannot be combined" "$EXE" --explain --repo .
assert_fails_with_stderr explain-limit "--explain cannot be combined" "$EXE" --explain --limit 1
assert_fails_with_stderr explain-format "--explain cannot be combined" "$EXE" --explain --format markdown
assert_fails_with_stderr explain-since "--explain cannot be combined" "$EXE" --explain --since HEAD~1
assert_fails_with_stderr explain-include "--explain cannot be combined" "$EXE" --explain --include-prefix src/
assert_fails_with_stderr explain-exclude "--explain cannot be combined" "$EXE" --explain --exclude-prefix .flow/
assert_fails_with_stderr version-repo "--version cannot be combined" "$EXE" --version --repo .
assert_fails_with_stderr version-limit "--version cannot be combined" "$EXE" --version --limit 1
assert_fails_with_stderr version-format "--version cannot be combined" "$EXE" --version --format markdown
assert_fails_with_stderr version-since "--version cannot be combined" "$EXE" --version --since HEAD~1
assert_fails_with_stderr version-include "--version cannot be combined" "$EXE" --version --include-prefix src/
assert_fails_with_stderr version-exclude "--version cannot be combined" "$EXE" --version --exclude-prefix .flow/
assert_fails_with_stderr version-explain "--version cannot be combined" "$EXE" --version --explain

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
"$EXE" --repo fixtures/scope --include-prefix src/ --format json > /tmp/git-hotspots-scope-src-include.json
"$EXE" --repo fixtures/scope --include-prefix src/ --format markdown > /tmp/git-hotspots-scope-src-include.md
"$EXE" --repo fixtures/scope --include-prefix src/ --format table > /tmp/git-hotspots-scope-src-include.txt
"$EXE" --repo fixtures/scope --include-prefix src/ --include-prefix vendor/ --format json > /tmp/git-hotspots-scope-src-vendor-include.json
"$EXE" --repo fixtures/scope --include-prefix src/ --exclude-prefix src/vendor_adapter.zig --format json > /tmp/git-hotspots-scope-include-exclude.json
"$EXE" --repo fixtures/scope --exclude-prefix vendor/ --format json > /tmp/git-hotspots-scope-vendor-filtered.json
"$EXE" --repo fixtures/scope --exclude-prefix src/ --format json > /tmp/git-hotspots-scope-src-filtered.json
"$EXE" --repo fixtures/scope --exclude-prefix weird/ --format json > /tmp/git-hotspots-scope-weird-filtered.json
"$EXE" --repo fixtures/scope --exclude-prefix 'glob/*' --format json > /tmp/git-hotspots-scope-glob-prefix.json
"$EXE" --repo fixtures/scope --include-prefix weird/ --format json > /tmp/git-hotspots-scope-weird-include.json
"$EXE" --repo fixtures/scope --include-prefix 'glob/*' --format json > /tmp/git-hotspots-scope-glob-star-include.json
"$EXE" --repo fixtures/scope --include-prefix glob/ --format json > /tmp/git-hotspots-scope-glob-include.json
"$EXE" --repo fixtures/scope --include-prefix does-not-exist/ --format json > /tmp/git-hotspots-scope-include-empty.json
"$EXE" --repo fixtures/scope --include-prefix does-not-exist/ --format markdown > /tmp/git-hotspots-scope-include-empty.md
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
assert_fails_with_stderr invalid-include-empty --include-prefix "$EXE" --repo fixtures/basic --include-prefix ""
assert_fails_with_stderr invalid-include-absolute --include-prefix "$EXE" --repo fixtures/basic --include-prefix /tmp
assert_fails_with_stderr invalid-include-drive --include-prefix "$EXE" --repo fixtures/basic --include-prefix C:/tmp
assert_fails_with_stderr invalid-include-backslash --include-prefix "$EXE" --repo fixtures/basic --include-prefix '\tmp'
assert_fails_with_stderr invalid-include-parent --include-prefix "$EXE" --repo fixtures/basic --include-prefix src/../lib
assert_fails_with_stderr invalid-include-control --include-prefix "$EXE" --repo fixtures/basic --include-prefix "$ctrl"

"$EXE" --repo fixtures/edge --limit 200 --format json > /tmp/git-hotspots-edge.json
"$EXE" --repo fixtures/edge --limit 200 --format markdown > /tmp/git-hotspots-edge.md
"$EXE" --repo fixtures/medium --format json > /tmp/git-hotspots-medium.json
"$EXE" --repo fixtures/shallow --format json > /tmp/git-hotspots-shallow.json
"$EXE" --repo fixtures/partial --format json > /tmp/git-hotspots-partial.json
"$EXE" --repo fixtures/detached --format json > /tmp/git-hotspots-detached.json
"$EXE" --repo fixtures/linked --format json > /tmp/git-hotspots-linked.json

python3 - /tmp/git-hotspots-basic.md /tmp/git-hotspots-scope-filtered.md /tmp/git-hotspots-scope-empty.md /tmp/git-hotspots-edge.md /tmp/git-hotspots-scope-src-include.md /tmp/git-hotspots-scope-include-empty.md <<'PY'
import json
import os
import re
import sys
from pathlib import Path

basic_md_path, scope_md_path, scope_empty_md_path, edge_md_path, include_md_path, include_empty_md_path = map(Path, sys.argv[1:])

def load(path):
    return json.loads(Path(path).read_text())

def by_path(data):
    return {row['path']: row for row in data['results']}

basic = load('/tmp/git-hotspots-basic.json')
assert basic['analysis']['scope']['filters_active'] is False
assert basic['analysis']['scope']['include_prefixes'] == []
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
    'include_prefixes': [],
    'exclude_prefixes': ['.flow/'],
    'outside_include_path_count': 0,
    'outside_include_change_count': 0,
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

src_include = load('/tmp/git-hotspots-scope-src-include.json')
src_include_scope = src_include['analysis']['scope']
assert src_include_scope['filters_active'] is True
assert src_include_scope['include_prefixes'] == ['src/']
assert src_include_scope['exclude_prefixes'] == []
assert src_include_scope['outside_include_path_count'] >= 1
assert src_include_scope['outside_include_change_count'] >= 1
for row in src_include['results']:
    assert row['path'].startswith('src/'), row['path']
    assert all(cc['path'].startswith('src/') for cc in row['cochanges']), row['path']
assert 'src/new.zig' in by_path(src_include), 'include scope lost normalized rename target'
assert 'src/vendor_adapter.zig' in by_path(src_include), 'literal include prefix lost adapter path'

src_vendor_include = load('/tmp/git-hotspots-scope-src-vendor-include.json')
assert src_vendor_include['analysis']['scope']['include_prefixes'] == ['src/', 'vendor/']
for row in src_vendor_include['results']:
    assert row['path'].startswith(('src/', 'vendor/')), row['path']
    assert all(cc['path'].startswith(('src/', 'vendor/')) for cc in row['cochanges']), row['path']

include_exclude = load('/tmp/git-hotspots-scope-include-exclude.json')
assert include_exclude['analysis']['scope']['include_prefixes'] == ['src/']
assert include_exclude['analysis']['scope']['exclude_prefixes'] == ['src/vendor_adapter.zig']
assert include_exclude['analysis']['scope']['excluded_path_count'] == 1
assert 'src/vendor_adapter.zig' not in by_path(include_exclude), 'exclude did not win over include'
for row in include_exclude['results']:
    assert all(cc['path'] != 'src/vendor_adapter.zig' for cc in row['cochanges']), row['path']

weird_include = load('/tmp/git-hotspots-scope-weird-include.json')
assert [row['path'] for row in weird_include['results']] == ['weird/tab\tname.txt']

glob_star_include = load('/tmp/git-hotspots-scope-glob-star-include.json')
assert 'glob/[literal]*.txt' not in by_path(glob_star_include), 'include glob-like prefix acted as a glob'
glob_include = load('/tmp/git-hotspots-scope-glob-include.json')
assert 'glob/[literal]*.txt' in by_path(glob_include), 'literal glob/ include did not match path'

include_empty = load('/tmp/git-hotspots-scope-include-empty.json')
assert include_empty['results'] == []
assert include_empty['analysis']['scope']['filters_active'] is True
assert include_empty['analysis']['scope']['include_prefixes'] == ['does-not-exist/']
assert include_empty['analysis']['scope']['outside_include_path_count'] >= 1

scope_empty = load('/tmp/git-hotspots-scope-empty.json')
assert scope_empty['results'] == []
assert scope_empty['analysis']['scope']['filters_active'] is True
assert scope_empty['analysis']['scope']['excluded_path_count'] >= 1

table_text = Path('/tmp/git-hotspots-scope-filtered.txt').read_text()
assert 'scope: include_prefixes=[] exclude_prefixes=[.flow/]' in table_text
assert '.flow/' not in '\n'.join(line for line in table_text.splitlines() if line[:1].isdigit())
include_table_text = Path('/tmp/git-hotspots-scope-src-include.txt').read_text()
assert 'scope: include_prefixes=[src/] exclude_prefixes=[]' in include_table_text
for line in include_table_text.splitlines():
    if line[:1].isdigit():
        assert 'src/' in line, line
        assert '.flow/' not in line and 'vendor/' not in line and 'glob/' not in line and 'weird/' not in line, line

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
assert '- Include prefixes: None' in scope_md
assert '- Exclude prefixes: .flow/' in scope_md
assert '- Outside include path count: 0' in scope_md
assert '- Outside include change count: 0' in scope_md
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

include_md = include_md_path.read_text()
assert '- Include prefixes: src/' in include_md
assert '- Exclude prefixes: None' in include_md
assert '- Outside include path count:' in include_md
for line in include_md.splitlines():
    if line.startswith('| ') or line.startswith('### ') or line.startswith('  - '):
        assert '.flow/' not in line and 'vendor/' not in line and 'glob/' not in line and 'weird/' not in line, line

include_empty_md = include_empty_md_path.read_text()
assert '- Include prefixes: does\\-not\\-exist/' in include_empty_md
assert 'No hotspots matched the requested scope.' in include_empty_md
assert 'No result evidence to show.' in include_empty_md

edge_md = edge_md_path.read_text()
assert 'weird/tab\\tname.txt' in edge_md
assert 'glob/\\[literal\\]\\*.txt' in edge_md
assert 'path is deleted or not present at HEAD' in edge_md
assert 'binary or non\\-text churn unavailable for some changes' in edge_md
for text in [basic_md, scope_md, scope_empty_md, edge_md, include_md, include_empty_md]:
    assert '\t' not in text, 'raw tab leaked in markdown'
    assert 'Fixture Author' not in text
    assert 'fixture@example.invalid' not in text
    home = os.path.expanduser('~')
    assert not home or home not in text
    assert not re.search(r'https?://|ssh://|git@', text)
    assert not re.search(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', text)
PY
