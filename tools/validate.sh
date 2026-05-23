#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT" || exit 1

EXE=${1:-./zig-out/bin/git-hotspots}
PROJECT_EXCLUDE_ARGS="--exclude-prefix .flow/ --exclude-prefix .zig-cache/ --exclude-prefix zig-out/ --exclude-prefix target/ --exclude-prefix node_modules/ --exclude-prefix dist/ --exclude-prefix build/ --exclude-prefix coverage/"
if [ "$#" -gt 0 ]; then
  shift
fi

CLOSEOUT=false
SMOKE_REPO=
SMOKE_LABEL=
SMOKE_SKIP_REASON=

while [ "$#" -gt 0 ]; do
  case "$1" in
    --closeout)
      CLOSEOUT=true
      shift
      ;;
    --smoke-repo)
      [ "$#" -ge 2 ] || { echo "validate: --smoke-repo requires a value" >&2; exit 2; }
      SMOKE_REPO=$2
      shift 2
      ;;
    --smoke-label)
      [ "$#" -ge 2 ] || { echo "validate: --smoke-label requires a value" >&2; exit 2; }
      SMOKE_LABEL=$2
      shift 2
      ;;
    --smoke-skip-reason)
      [ "$#" -ge 2 ] || { echo "validate: --smoke-skip-reason requires a value" >&2; exit 2; }
      SMOKE_SKIP_REASON=$2
      shift 2
      ;;
    *)
      echo "validate: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

case "$EXE" in
  /*) EXE_ABS=$EXE ;;
  *) EXE_ABS=$ROOT/${EXE#./} ;;
esac

TMPDIR_VALIDATE=${TMPDIR:-/tmp}
SUMMARY=$(mktemp "$TMPDIR_VALIDATE/git-hotspots-validate-summary.XXXXXX")
FALLBACKS=$(mktemp "$TMPDIR_VALIDATE/git-hotspots-validate-fallbacks.XXXXXX")
SMOKES=$(mktemp "$TMPDIR_VALIDATE/git-hotspots-validate-smokes.XXXXXX")
ARTIFACT_DIR=$(mktemp -d "$TMPDIR_VALIDATE/git-hotspots-validate.XXXXXX")
trap 'rm -f "$SUMMARY" "$FALLBACKS" "$SMOKES"; rm -rf "$ARTIFACT_DIR"' EXIT INT HUP TERM

FAILURES=0

note_fallback() {
  printf '%s\n' "$1" >> "$FALLBACKS"
}

pass_rung() {
  printf 'PASS %s\n' "$1" >> "$SUMMARY"
  printf 'validate: PASS %s\n' "$1"
}

fail_rung() {
  FAILURES=$((FAILURES + 1))
  printf 'FAIL %s - %s\n' "$1" "$2" >> "$SUMMARY"
  printf 'validate: FAIL %s - %s\n' "$1" "$2" >&2
}

print_log_excerpt() {
  log_file=$1
  if [ -s "$log_file" ]; then
    sed -n '1,80p' "$log_file" >&2
  fi
}

run_quiet() {
  label=$1
  shift
  log_file=$(mktemp "$ARTIFACT_DIR/log.XXXXXX")
  printf 'validate: RUN %s\n' "$label"
  if "$@" > "$log_file" 2>&1; then
    pass_rung "$label"
  else
    fail_rung "$label" "command exited non-zero"
    print_log_excerpt "$log_file"
  fi
}

have_python() {
  command -v python3 >/dev/null 2>&1
}

safe_label() {
  label=$1
  [ -n "$label" ] || return 1
  case "$label" in
    *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

safe_reason() {
  reason=$1
  [ -n "$reason" ] || return 1
  printf '%s' "$reason" | grep -Eq '^[A-Za-z0-9 ._,()_-]+$'
}

json_count_summary() {
  json_file=$1
  have_python || return 1
  python3 - "$json_file" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
scope = data.get('analysis', {}).get('scope', {})
print('results=%d caveats=%d dirty=%s scope_active=%s outside_include_paths=%d outside_include_changes=%d excluded_paths=%d excluded_changes=%d' % (
    len(data.get('results', [])),
    len(data.get('analysis', {}).get('caveats', [])),
    str(data.get('analysis', {}).get('history', {}).get('dirty_worktree', False)).lower(),
    '%s/%s' % (scope.get('selected_scope', 'all'), str(scope.get('filters_active', False)).lower()),
    int(scope.get('outside_include_path_count', 0) or 0),
    int(scope.get('outside_include_change_count', 0) or 0),
    int(scope.get('excluded_path_count', 0) or 0),
    int(scope.get('excluded_change_count', 0) or 0),
))
PY
}

json_validity() {
  label=$1
  shift
  if command -v jq >/dev/null 2>&1; then
    tool=jq
    for file in "$@"; do
      jq empty "$file" >/dev/null || return 1
    done
  elif have_python; then
    tool=python3
    for file in "$@"; do
      python3 -m json.tool "$file" >/dev/null || return 1
    done
    note_fallback "json validity: python3 fallback used because jq was unavailable"
  else
    note_fallback "json validity: jq and python3 unavailable"
    return 1
  fi
  note_fallback "json validity: $tool"
  pass_rung "$label"
}

progress_stderr_scan() {
  err_file=$1
  grep -q -- 'progress: checking repository' "$err_file" || return 1
  grep -q -- 'progress: reading Git history' "$err_file" || return 1
  grep -q -- 'progress: scoring files' "$err_file" || return 1
  grep -q -- 'progress: rendering report' "$err_file" || return 1
  grep -Eq '^progress: done in [0-9]+ms$' "$err_file" || return 1
  esc=$(printf '\033')
  cr=$(printf '\r')
  ! LC_ALL=C grep -Eq '/|@|https?://|ssh://|git@|[0-9a-f]{12,40}' "$err_file" && ! LC_ALL=C grep -q '\\' "$err_file" && ! LC_ALL=C grep -q "$esc" "$err_file" && ! LC_ALL=C grep -q "$cr" "$err_file"
}

semantic_assertions() {
  have_python || return 1
  python3 - "$BASIC_A" "$BASIC_INSPECT_JSON" "$SHALLOW_JSON" "$PARTIAL_JSON" "$SELF_JSON" "$SELF_SCOPED_JSON" "$SCOPE_UNFILTERED_JSON" "$SCOPE_ALL_JSON" "$SCOPE_FILTERED_JSON" "$SCOPE_PROJECT_JSON" "$SCOPE_PROJECT_DUPLICATE_JSON" "$SCOPE_PROJECT_INCLUDE_FLOW_JSON" "$SCOPE_PROJECT_INCLUDE_NODE_JSON" "$SCOPE_ALL_INCLUDE_NODE_JSON" "$SCOPE_PROJECT_INCLUDE_SRC_JSON" "$SCOPE_PROJECT_INSPECT_JSON" "$SCOPE_ALL_INSPECT_FLOW_JSON" "$SCOPE_ALL_INSPECT_INCLUDED_TO_EXCLUDED_JSON" "$SCOPE_ALL_INSPECT_EXCLUDED_TO_EXCLUDED_JSON" "$SCOPE_ALL_INSPECT_CHAINED_CROSS_JSON" "$SCOPE_PROJECT_INSPECT_INCLUDED_TO_EXCLUDED_JSON" "$SCOPE_PROJECT_INSPECT_CHAINED_CROSS_JSON" "$SCOPE_INSPECT_EXCLUDED_FLOW_JSON" "$SCOPE_INSPECT_RENAMED_JSON" "$SCOPE_SRC_FILTERED_JSON" "$SCOPE_WEIRD_FILTERED_JSON" "$SCOPE_EMPTY_JSON" "$SCOPE_SRC_INCLUDE_JSON" "$SCOPE_SRC_VENDOR_INCLUDE_JSON" "$SCOPE_INCLUDE_EXCLUDE_JSON" "$SCOPE_WEIRD_INCLUDE_JSON" "$SCOPE_GLOB_STAR_INCLUDE_JSON" "$SCOPE_GLOB_INCLUDE_JSON" "$SCOPE_INCLUDE_EMPTY_JSON" "$EDGE_INSPECT_TAB_JSON" <<'PY'
import json, os, re, sys
basic_path, basic_inspect_path, shallow_path, partial_path, self_path, self_scoped_path, scope_unfiltered_path, scope_all_path, scope_filtered_path, scope_project_path, scope_project_duplicate_path, scope_project_include_flow_path, scope_project_include_node_path, scope_all_include_node_path, scope_project_include_src_path, scope_project_inspect_path, scope_all_inspect_flow_path, scope_all_inspect_included_to_excluded_path, scope_all_inspect_excluded_to_excluded_path, scope_all_inspect_chained_cross_path, scope_project_inspect_included_to_excluded_path, scope_project_inspect_chained_cross_path, scope_inspect_excluded_flow_path, scope_inspect_renamed_path, scope_src_filtered_path, scope_weird_filtered_path, scope_empty_path, scope_src_include_path, scope_src_vendor_include_path, scope_include_exclude_path, scope_weird_include_path, scope_glob_star_include_path, scope_glob_include_path, scope_include_empty_path, edge_inspect_tab_path = sys.argv[1:]

def load(path):
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)

project_prefixes = ['.flow/', '.zig-cache/', 'zig-out/', 'target/', 'node_modules/', 'dist/', 'build/', 'coverage/']
def starts_project_prefix(path):
    return any(path.startswith(prefix) for prefix in project_prefixes)

basic = load(basic_path)
assert basic['results'], 'basic results missing'
assert basic['results'][0]['path'] == 'src/app.txt', 'unexpected basic top result'
assert basic['analysis']['scope']['selected_scope'] == 'project', 'basic selected scope changed'
assert basic['analysis']['scope']['filters_active'] is True, 'basic scope unexpectedly inactive'
assert basic['analysis']['scope']['include_prefixes'] == [], 'basic include prefixes changed'
assert basic['analysis']['scope']['exclude_prefixes'] == project_prefixes, 'basic exclude prefixes changed'
assert all(not os.path.isabs(row['path']) for row in basic['results']), 'absolute basic result path'
assert 'inspect' not in basic, 'normal JSON gained inspect metadata'
basic_inspect = load(basic_inspect_path)
assert basic_inspect.get('inspect') == {'requested_path': 'src/app.txt', 'matched_path': 'src/app.txt', 'rank': 1}, 'inspect metadata changed'
assert len(basic_inspect.get('results', [])) == 1, 'inspect result count changed'
assert basic_inspect['results'][0] == basic['results'][0], 'inspect result no longer matches full analysis row'

scope_unfiltered = load(scope_unfiltered_path)
scope_all = load(scope_all_path)
assert scope_unfiltered['analysis']['scope']['selected_scope'] == 'project', 'default selected scope changed'
assert scope_unfiltered['analysis']['scope']['exclude_prefixes'] == project_prefixes, 'default project prefix missing'
assert all(not starts_project_prefix(row['path']) for row in scope_unfiltered.get('results', [])), 'default leaked project-prefix paths'
all_paths = [row['path'] for row in scope_all.get('results', [])]
assert any(row['path'].startswith('.flow/') for row in scope_all.get('results', [])), '--scope all lost .flow paths'
assert any(row['path'].startswith('node_modules/') for row in scope_all.get('results', [])), '--scope all lost dependency path evidence'
assert 'src/new.zig' in all_paths, 'braced rename fixture missing normalized new path'
assert '' not in all_paths, 'empty path leaked from braced rename parsing'
assert 'weird/tab\tname.txt' in all_paths, 'quoted tab fixture missing unquoted path'

scope_filtered = load(scope_filtered_path)
scope = scope_filtered['analysis']['scope']
assert scope['selected_scope'] == 'all', 'filtered selected scope changed'
assert scope['filters_active'] is True, 'filtered scope metadata inactive'
assert scope['include_prefixes'] == [], 'filtered include prefixes changed'
assert scope['exclude_prefixes'] == project_prefixes, 'filtered prefix order changed'
assert scope['outside_include_path_count'] == 0, 'filtered outside include path count changed'
assert scope['outside_include_change_count'] == 0, 'filtered outside include change count changed'
assert scope['excluded_path_count'] == 13, 'filtered path count changed'
assert scope['excluded_change_count'] == 28, 'filtered change count changed'
for row in scope_filtered.get('results', []):
    assert not starts_project_prefix(row['path']), 'excluded result leaked'
    for cc in row.get('cochanges', []):
        assert not starts_project_prefix(cc['path']), 'excluded cochange leaked'
paths = [row['path'] for row in scope_filtered.get('results', [])]
assert 'src/buildtool.zig' in paths, 'near-miss buildtool path was excluded'
assert 'src/vendoradapter.zig' in paths, 'near-miss vendoradapter path was excluded'
assert 'docs/coverage.md' in paths, 'near-miss docs coverage path was excluded'

scope_project = load(scope_project_path)
project_scope = scope_project['analysis']['scope']
assert project_scope['selected_scope'] == 'project', 'project selected scope missing'
assert project_scope['filters_active'] is True, 'project scope metadata inactive'
assert project_scope['include_prefixes'] == [], 'project include prefixes changed'
assert project_scope['exclude_prefixes'] == project_prefixes, 'project exclude prefix changed'
assert project_scope['outside_include_path_count'] == 0, 'project outside include path count changed'
assert project_scope['outside_include_change_count'] == 0, 'project outside include change count changed'
assert project_scope['excluded_path_count'] == 13, 'project excluded path count changed'
assert project_scope['excluded_change_count'] == 28, 'project excluded change count changed'
assert scope_project['results'] == scope_filtered['results'], 'project preset rows differ from explicit project-prefix exclusions'
assert scope_project == scope_unfiltered, 'omitted scope differs from explicit project'
for row in scope_project.get('results', []):
    assert not starts_project_prefix(row['path']), 'project result leaked project-prefix path'
    for cc in row.get('cochanges', []):
        assert not starts_project_prefix(cc['path']), 'project cochange leaked project-prefix path'
scope_project_duplicate = load(scope_project_duplicate_path)
assert scope_project_duplicate['analysis']['scope']['exclude_prefixes'] == project_prefixes, 'duplicate project exclude was reported twice'
assert scope_project_duplicate['results'] == scope_project['results'], 'duplicate project exclude changed rows'
scope_project_include_flow = load(scope_project_include_flow_path)
assert scope_project_include_flow['analysis']['scope']['selected_scope'] == 'project', 'project include-flow selected scope changed'
assert scope_project_include_flow['analysis']['scope']['include_prefixes'] == ['.flow/'], 'project include-flow include prefix changed'
assert scope_project_include_flow['analysis']['scope']['exclude_prefixes'] == project_prefixes, 'project include-flow exclude prefix changed'
assert scope_project_include_flow['results'] == [], 'exclude did not win over include for project .flow/'
scope_project_include_node = load(scope_project_include_node_path)
assert scope_project_include_node['analysis']['scope']['include_prefixes'] == ['node_modules/'], 'project include-node include prefix changed'
assert scope_project_include_node['analysis']['scope']['exclude_prefixes'] == project_prefixes, 'project include-node exclude prefix changed'
assert scope_project_include_node['results'] == [], 'project built-in exclude did not win over node_modules include'
scope_all_include_node = load(scope_all_include_node_path)
assert scope_all_include_node['analysis']['scope']['selected_scope'] == 'all', 'all include-node selected scope changed'
assert scope_all_include_node['analysis']['scope']['include_prefixes'] == ['node_modules/'], 'all include-node include prefix changed'
assert scope_all_include_node['analysis']['scope']['exclude_prefixes'] == [], 'all include-node gained project excludes'
assert [row['path'] for row in scope_all_include_node['results']] == ['node_modules/pkg/index.js', 'node_modules/pkg/chain-mid.txt'], 'all include-node did not retain dependency path evidence'
scope_project_include_src = load(scope_project_include_src_path)
assert scope_project_include_src['analysis']['scope']['selected_scope'] == 'project', 'project include-src selected scope changed'
assert scope_project_include_src['analysis']['scope']['include_prefixes'] == ['src/'], 'project include-src include prefix changed'
assert scope_project_include_src['analysis']['scope']['exclude_prefixes'] == project_prefixes, 'project include-src exclude prefix changed'
for row in scope_project_include_src.get('results', []):
    assert row['path'].startswith('src/'), 'project include-src leaked result'
    for cc in row.get('cochanges', []):
        assert cc['path'].startswith('src/'), 'project include-src leaked cochange'
scope_project_inspect = load(scope_project_inspect_path)
project_by_path = {row['path']: row for row in scope_project.get('results', [])}
assert scope_project_inspect['results'][0] == project_by_path['src/vendor_adapter.zig'], 'project inspect row mismatch'
assert scope_project_inspect['inspect']['matched_path'] == 'src/vendor_adapter.zig', 'project inspect metadata mismatch'
scope_all_inspect_flow = load(scope_all_inspect_flow_path)
assert scope_all_inspect_flow['analysis']['scope']['selected_scope'] == 'all', 'all inspect selected scope changed'
assert len(scope_all_inspect_flow.get('results', [])) == 1, 'all inspect flow result count changed'
assert scope_all_inspect_flow['results'][0]['path'] == '.flow/state.yaml', 'all inspect flow path changed'
scope_all_included_to_excluded = load(scope_all_inspect_included_to_excluded_path)
assert scope_all_included_to_excluded['results'][0]['path'] == '.zig-cache/from-src.txt', 'all inspect included-to-excluded path changed'
assert scope_all_included_to_excluded['results'][0]['lineage']['aliases'] == ['src/to-cache.txt'], 'all inspect included-to-excluded alias changed'
assert scope_all_included_to_excluded['results'][0]['lineage']['partial'] is False, 'all inspect included-to-excluded unexpectedly partial'
scope_all_excluded_to_excluded = load(scope_all_inspect_excluded_to_excluded_path)
assert scope_all_excluded_to_excluded['results'][0]['path'] == 'build/excluded-chain-b.txt', 'all inspect excluded-to-excluded path changed'
assert scope_all_excluded_to_excluded['results'][0]['lineage']['aliases'] == ['target/excluded-chain-a.txt'], 'all inspect excluded-to-excluded alias changed'
assert scope_all_excluded_to_excluded['results'][0]['lineage']['partial'] is False, 'all inspect excluded-to-excluded unexpectedly partial'
scope_all_chained_cross = load(scope_all_inspect_chained_cross_path)
assert scope_all_chained_cross['results'][0]['path'] == 'src/chain-final.txt', 'all inspect chained cross-prefix path changed'
assert scope_all_chained_cross['results'][0]['lineage']['aliases'] == ['node_modules/pkg/chain-mid.txt', 'src/chain-start.txt'], 'all inspect chained cross-prefix aliases changed'
assert scope_all_chained_cross['results'][0]['lineage']['partial'] is False, 'all inspect chained cross-prefix unexpectedly partial'
scope_project_included_to_excluded = load(scope_project_inspect_included_to_excluded_path)
assert scope_project_included_to_excluded['results'][0]['path'] == 'src/to-cache.txt', 'project inspect included-to-excluded old row changed'
assert scope_project_included_to_excluded['results'][0]['lineage']['aliases'] == [], 'project included-to-excluded leaked excluded alias'
assert scope_project_included_to_excluded['results'][0]['lineage']['partial'] is False, 'project included-to-excluded old row unexpectedly partial'
scope_project_chained_cross = load(scope_project_inspect_chained_cross_path)
assert scope_project_chained_cross['results'][0]['path'] == 'src/chain-final.txt', 'project inspect chained cross-prefix path changed'
assert scope_project_chained_cross['results'][0]['lineage']['aliases'] == [], 'project chained cross-prefix leaked excluded alias'
assert scope_project_chained_cross['results'][0]['lineage']['partial'] is True, 'project chained cross-prefix did not record partial lineage'
for row in scope_project.get('results', []) + scope_project_included_to_excluded.get('results', []) + scope_project_chained_cross.get('results', []):
    assert not starts_project_prefix(row['path']), 'project cross-prefix row leaked excluded path'
    for alias in row.get('lineage', {}).get('aliases', []):
        assert not starts_project_prefix(alias), 'project cross-prefix lineage leaked excluded alias'
    for cc in row.get('cochanges', []):
        assert not starts_project_prefix(cc['path']), 'project cross-prefix cochange leaked excluded path'
scope_inspect_excluded_flow = load(scope_inspect_excluded_flow_path)
assert len(scope_inspect_excluded_flow.get('results', [])) == 1, 'scoped inspect result count changed'
filtered_by_path = {row['path']: row for row in scope_filtered.get('results', [])}
assert scope_inspect_excluded_flow['results'][0] == filtered_by_path['src/vendor_adapter.zig'], 'scoped inspect row does not match full scoped analysis'

scope_src_filtered = load(scope_src_filtered_path)
for row in scope_src_filtered.get('results', []):
    assert row['path'], 'empty path leaked from excluded braced rename'
    assert not row['path'].startswith('src/'), 'src result leaked'
    for cc in row.get('cochanges', []):
        assert not cc['path'].startswith('src/'), 'src cochange leaked'

scope_weird_filtered = load(scope_weird_filtered_path)
for row in scope_weird_filtered.get('results', []):
    assert not row['path'].startswith('weird/'), 'weird result leaked'
    assert not row['path'].startswith('"weird/'), 'quoted weird result leaked'
    for cc in row.get('cochanges', []):
        assert not cc['path'].startswith('weird/'), 'weird cochange leaked'

scope_empty = load(scope_empty_path)
assert scope_empty.get('results') == [], 'empty scoped fixture should produce no results'
assert scope_empty['analysis']['scope']['filters_active'] is True, 'empty scoped report lost scope metadata'

scope_src_include = load(scope_src_include_path)
scope = scope_src_include['analysis']['scope']
assert scope['selected_scope'] == 'project', 'include selected scope changed'
assert scope['filters_active'] is True, 'include scope metadata inactive'
assert scope['include_prefixes'] == ['src/'], 'include prefix order changed'
assert scope['exclude_prefixes'] == project_prefixes, 'include-only exclude metadata changed'
assert scope['outside_include_path_count'] >= 1, 'include scope outside path count missing'
assert scope['outside_include_change_count'] >= 1, 'include scope outside change count missing'
paths = [row['path'] for row in scope_src_include.get('results', [])]
assert 'src/new.zig' in paths, 'include scope lost normalized rename target'
assert 'src/vendor_adapter.zig' in paths, 'include scope lost adapter path'
for row in scope_src_include.get('results', []):
    assert row['path'].startswith('src/'), 'include scope leaked result'
    for cc in row.get('cochanges', []):
        assert cc['path'].startswith('src/'), 'include scope leaked cochange'
scope_inspect_renamed = load(scope_inspect_renamed_path)
included_by_path = {row['path']: row for row in scope_src_include.get('results', [])}
assert scope_inspect_renamed['results'][0] == included_by_path['src/new.zig'], 'renamed inspect row does not match full include analysis'

scope_src_vendor_include = load(scope_src_vendor_include_path)
assert scope_src_vendor_include['analysis']['scope']['include_prefixes'] == ['src/', 'vendor/'], 'repeated include prefixes changed'
for row in scope_src_vendor_include.get('results', []):
    assert row['path'].startswith(('src/', 'vendor/')), 'repeated include leaked result'
    for cc in row.get('cochanges', []):
        assert cc['path'].startswith(('src/', 'vendor/')), 'repeated include leaked cochange'

scope_include_exclude = load(scope_include_exclude_path)
assert scope_include_exclude['analysis']['scope']['include_prefixes'] == ['src/'], 'include+exclude include prefix changed'
assert scope_include_exclude['analysis']['scope']['exclude_prefixes'] == project_prefixes + ['src/vendor_adapter.zig'], 'include+exclude exclude prefix changed'
assert scope_include_exclude['analysis']['scope']['excluded_path_count'] == 14, 'exclude-over-include count changed'
assert 'src/vendor_adapter.zig' not in [row['path'] for row in scope_include_exclude.get('results', [])], 'exclude did not win over include'
for row in scope_include_exclude.get('results', []):
    for cc in row.get('cochanges', []):
        assert cc['path'] != 'src/vendor_adapter.zig', 'excluded cochange leaked'

scope_weird_include = load(scope_weird_include_path)
assert [row['path'] for row in scope_weird_include.get('results', [])] == ['weird/tab\tname.txt'], 'quoted tab include failed'

scope_glob_star_include = load(scope_glob_star_include_path)
assert 'glob/[literal]*.txt' not in [row['path'] for row in scope_glob_star_include.get('results', [])], 'include glob-like prefix acted as glob'
scope_glob_include = load(scope_glob_include_path)
assert 'glob/[literal]*.txt' in [row['path'] for row in scope_glob_include.get('results', [])], 'literal glob/ include failed'

scope_include_empty = load(scope_include_empty_path)
assert scope_include_empty.get('results') == [], 'empty include scope should produce no results'
assert scope_include_empty['analysis']['scope']['filters_active'] is True, 'empty include scope metadata inactive'
assert scope_include_empty['analysis']['scope']['include_prefixes'] == ['does-not-exist/'], 'empty include prefix changed'
assert scope_include_empty['analysis']['scope']['outside_include_path_count'] >= 1, 'empty include outside path count missing'

edge_inspect_tab = load(edge_inspect_tab_path)
assert edge_inspect_tab['inspect']['requested_path'] == 'weird/tab\tname.txt', 'tab inspect requested path was not decoded'
assert edge_inspect_tab['inspect']['matched_path'] == 'weird/tab\tname.txt', 'tab inspect matched path changed'
assert len(edge_inspect_tab.get('results', [])) == 1, 'tab inspect result count changed'
assert edge_inspect_tab['results'][0]['path'] == 'weird/tab\tname.txt', 'tab inspect did not match tab path'

self_scoped = load(self_scoped_path)
assert self_scoped['analysis']['scope']['selected_scope'] == 'project', 'self scoped selected scope changed'
assert self_scoped['analysis']['scope']['filters_active'] is True, 'self scoped metadata inactive'
assert self_scoped['analysis']['scope']['include_prefixes'] == [], 'self scoped include prefixes changed'
assert self_scoped['analysis']['scope']['exclude_prefixes'] == project_prefixes, 'self scoped prefix changed'
for row in self_scoped.get('results', []):
    assert not starts_project_prefix(row['path']), 'self scoped result leaked project-prefix path'
    for cc in row.get('cochanges', []):
        assert not starts_project_prefix(cc['path']), 'self scoped cochange leaked project-prefix path'

shallow = load(shallow_path)
history = shallow['analysis']['history']
assert history['is_shallow'] is True, 'shallow fixture not reported as shallow'
assert history['auto_fetch'] is False, 'shallow fixture auto_fetch changed'

partial = load(partial_path)
history = partial['analysis']['history']
assert history['is_partial'] is True, 'partial fixture not reported as partial'
assert history['auto_fetch'] is False, 'partial fixture auto_fetch changed'

for path in (basic_path, self_path, self_scoped_path, scope_filtered_path, scope_project_path, scope_project_duplicate_path, scope_project_include_flow_path, scope_project_include_src_path, scope_src_filtered_path, scope_weird_filtered_path, scope_empty_path):
    data = load(path)
    for row in data.get('results', []):
        assert not os.path.isabs(row.get('path', '')), 'absolute result path in %s' % path
    text = open(path, encoding='utf-8').read()
    assert 'Fixture Author' not in text, 'fixture author name leaked'
    assert 'fixture@example.invalid' not in text, 'fixture author email leaked'
    home = os.path.expanduser('~')
    assert not home or home not in text, 'home path leaked'
    assert not re.search(r'https?://|ssh://|git@', text), 'remote URL leaked'
    assert not re.search(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', text), 'email-like identity leaked'
PY
}

markdown_assertions() {
  have_python || return 1
  python3 - "$BASIC_MD_A" "$BASIC_MD_B" "$BASIC_INSPECT_MD" "$SCOPE_FILTERED_MD" "$SCOPE_FILTERED_MD_B" "$SCOPE_PROJECT_MD" "$SCOPE_PROJECT_MD_B" "$SCOPE_EMPTY_MD" "$EDGE_MD" "$EDGE_INSPECT_MD" "$SELF_MARKDOWN" "$SELF_SCOPED_MARKDOWN" "$SCOPE_SRC_INCLUDE_MD" "$SCOPE_INCLUDE_EMPTY_MD" <<'PY'
import os, re, sys
from pathlib import Path

basic_a, basic_b, basic_inspect, scope_filtered, scope_filtered_b, scope_project, scope_project_b, scope_empty, edge, edge_inspect, self_md, self_scoped, scope_src_include_md, scope_include_empty_md = [Path(p) for p in sys.argv[1:]]

def read(path):
    return path.read_text(encoding='utf-8')

project_prefixes = ['.flow/', '.zig-cache/', 'zig-out/', 'target/', 'node_modules/', 'dist/', 'build/', 'coverage/']

basic = read(basic_a)
assert basic == read(basic_b), 'basic markdown repeated output changed'
for section in ['# git-hotspots report', '## Run summary', '## Scope', '## Caveats', '## Top hotspots', '## Evidence']:
    assert section in basic, section
assert '- Selected scope: project' in basic, 'basic selected scope missing'
assert 'File-level Git-history investigation prompts, not bug predictions or code-quality ratings.' in basic
basic_inspect_text = read(basic_inspect)
assert '## Inspect' in basic_inspect_text, 'inspect markdown section missing'
assert '- Requested path: src/app.txt' in basic_inspect_text, 'inspect markdown requested path missing'
assert '- Matched path: src/app.txt' in basic_inspect_text, 'inspect markdown matched path missing'
assert '- Rank in scoped evidence universe: 1' in basic_inspect_text, 'inspect markdown rank missing'

scope = read(scope_filtered)
assert scope == read(scope_filtered_b), 'scope markdown repeated output changed'
assert '- Selected scope: all' in scope, 'scope selected scope missing'
assert '- Filters active: true' in scope, 'scope filter flag missing'
assert '- Include prefixes: None' in scope, 'scope include prefix metadata missing'
assert r'- Exclude prefixes: .flow/, .zig\-cache/, zig\-out/, target/, node\_modules/, dist/, build/, coverage/' in scope, 'scope prefix missing'
assert '- Outside include path count: 0' in scope, 'scope outside include path count missing'
assert '- Outside include change count: 0' in scope, 'scope outside include change count missing'
assert '- Excluded path count: 13' in scope, 'scope excluded path count missing'
assert '- Excluded change count: 28' in scope, 'scope excluded change count missing'
for line in scope.splitlines():
    if line.startswith('| ') or line.startswith('### ') or line.startswith('  - '):
        assert not any(prefix in line for prefix in project_prefixes), 'filtered path leaked in scoped markdown: %r' % line

project = read(scope_project)
assert project == read(scope_project_b), 'project markdown repeated output changed'
assert '- Selected scope: project' in project, 'project selected scope missing'
assert r'- Exclude prefixes: .flow/, .zig\-cache/, zig\-out/, target/, node\_modules/, dist/, build/, coverage/' in project, 'project exclude prefix missing'
for line in project.splitlines():
    if line.startswith('| ') or line.startswith('### ') or line.startswith('  - '):
        assert not any(prefix in line for prefix in project_prefixes), 'project path leaked in scoped markdown: %r' % line

empty = read(scope_empty)
for section in ['## Run summary', '## Scope', '## Caveats', '## Top hotspots', '## Evidence']:
    assert section in empty, 'empty scoped markdown missing %s' % section
assert 'No hotspots matched the requested scope.' in empty, 'empty scoped top-hotspots note missing'
assert 'No result evidence to show.' in empty, 'empty scoped evidence note missing'

include_text = read(scope_src_include_md)
assert '- Selected scope: project' in include_text, 'include markdown selected scope missing'
assert '- Filters active: true' in include_text, 'include markdown filter flag missing'
assert '- Include prefixes: src/' in include_text, 'include markdown prefix missing'
assert r'- Exclude prefixes: .flow/, .zig\-cache/, zig\-out/, target/, node\_modules/, dist/, build/, coverage/' in include_text, 'include markdown exclude metadata missing'
assert '- Outside include path count:' in include_text, 'include markdown outside path count missing'
for line in include_text.splitlines():
    if line.startswith('| ') or line.startswith('### ') or line.startswith('  - '):
        assert not any(prefix in line for prefix in project_prefixes) and 'vendor/' not in line and 'glob/' not in line and 'weird/' not in line, 'include markdown leaked out-of-scope path: %r' % line

include_empty = read(scope_include_empty_md)
assert '- Include prefixes: does\\-not\\-exist/' in include_empty, 'empty include prefix missing'
assert 'No hotspots matched the requested scope.' in include_empty, 'empty include top-hotspots note missing'
assert 'No result evidence to show.' in include_empty, 'empty include evidence note missing'

edge_text = read(edge)
assert 'weird/tab\\tname.txt' in edge_text, 'tab path was not escaped deterministically'
assert 'glob/\\[literal\\]\\*.txt' in edge_text, 'glob-like path markdown escaping missing'
assert 'path is deleted or not present at HEAD' in edge_text, 'deleted-file caveat missing'
assert 'binary or non\\-text churn unavailable for some changes' in edge_text, 'binary caveat missing'
edge_inspect_text = read(edge_inspect)
assert '## Inspect' in edge_inspect_text, 'edge inspect section missing'
assert 'glob/\\[literal\\]\\*.txt' in edge_inspect_text, 'edge inspect markdown escaping missing'

self_scoped_text = read(self_scoped)
assert '- Selected scope: project' in self_scoped_text, 'self scoped markdown lost selected scope'
assert '- Filters active: true' in self_scoped_text, 'self scoped markdown lost scope flag'
assert r'- Exclude prefixes: .flow/, .zig\-cache/, zig\-out/, target/, node\_modules/, dist/, build/, coverage/' in self_scoped_text, 'self scoped markdown lost prefix'
for line in self_scoped_text.splitlines():
    if line.startswith('| ') or line.startswith('### ') or line.startswith('  - '):
        assert '.flow/' not in line, 'self scoped markdown leaked .flow path: %r' % line

for text in [basic, basic_inspect_text, scope, project, empty, edge_text, edge_inspect_text, read(self_md), self_scoped_text, include_text, include_empty]:
    assert '\t' not in text, 'raw tab leaked in markdown'
    assert 'Fixture Author' not in text, 'fixture author name leaked'
    assert 'fixture@example.invalid' not in text, 'fixture author email leaked'
    home = os.path.expanduser('~')
    assert not home or home not in text, 'home path leaked'
    assert not re.search(r'https?://|ssh://|git@', text), 'remote URL leaked'
    assert not re.search(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', text), 'email-like identity leaked'
PY
}

explain_output_checks() {
  explain_a=$ARTIFACT_DIR/explain-a.txt
  explain_b=$ARTIFACT_DIR/explain-b.txt
  explain_nongit=$ARTIFACT_DIR/explain-nongit.txt
  version_out=$ARTIFACT_DIR/version.txt
  version_nongit=$ARTIFACT_DIR/version-nongit.txt
  explain_err=$ARTIFACT_DIR/explain.err
  help_out=$ARTIFACT_DIR/help.txt

  "$EXE" --explain > "$explain_a" 2> "$explain_err" || return 1
  [ ! -s "$explain_err" ] || return 1
  diff -u fixtures/expected/explain.txt "$explain_a" >/dev/null || return 1
  "$EXE" --explain > "$explain_b" 2> "$explain_err" || return 1
  [ ! -s "$explain_err" ] || return 1
  diff -u "$explain_a" "$explain_b" >/dev/null || return 1
  "$EXE" --help > "$help_out" 2> "$explain_err" || return 1
  [ ! -s "$explain_err" ] || return 1
  grep -q -- '--explain' "$help_out" || return 1
  grep -q -- '--version' "$help_out" || return 1
  grep -q -- '--inspect PATH' "$help_out" || return 1
  grep -q -- '--scope VALUE' "$help_out" || return 1
  grep -q -- 'project (default) or all' "$help_out" || return 1
  grep -q -- '--progress' "$help_out" || return 1
  grep -q -- '--symbols' "$help_out" || return 1
  "$EXE" --progress --help > "$ARTIFACT_DIR/help-progress.txt" 2> "$explain_err" || return 1
  [ ! -s "$explain_err" ] || return 1
  grep -q -- '--progress' "$ARTIFACT_DIR/help-progress.txt" || return 1
  "$EXE" --version > "$version_out" 2> "$explain_err" || return 1
  [ ! -s "$explain_err" ] || return 1
  [ "$(cat "$version_out")" = 'git-hotspots 0.1.0-alpha.1' ] || return 1

  nongit=$(mktemp -d "$ARTIFACT_DIR/nongit.XXXXXX")
  (cd "$nongit" && "$EXE_ABS" --explain > "$explain_nongit" 2> "$explain_err") || return 1
  [ ! -s "$explain_err" ] || return 1
  diff -u fixtures/expected/explain.txt "$explain_nongit" >/dev/null || return 1
  (cd "$nongit" && "$EXE_ABS" --version > "$version_nongit" 2> "$explain_err") || return 1
  [ ! -s "$explain_err" ] || return 1
  [ "$(cat "$version_nongit")" = 'git-hotspots 0.1.0-alpha.1' ] || return 1

  for args in \
    '--repo .' \
    '--limit 1' \
    '--format markdown' \
    '--since HEAD~1' \
    '--scope project' \
    '--include-prefix src/' \
    '--exclude-prefix .flow/' \
    '--inspect src/app.txt' \
    '--progress' \
    '--symbols'
  do
    # shellcheck disable=SC2086
    if "$EXE" --explain $args > "$ARTIFACT_DIR/explain-invalid.out" 2> "$explain_err"; then
      return 1
    fi
    grep -q -- '--explain cannot be combined' "$explain_err" || return 1
  done

  for args in \
    '--repo .' \
    '--limit 1' \
    '--format markdown' \
    '--since HEAD~1' \
    '--scope project' \
    '--include-prefix src/' \
    '--exclude-prefix .flow/' \
    '--inspect src/app.txt' \
    '--explain' \
    '--progress' \
    '--symbols'
  do
    # shellcheck disable=SC2086
    if "$EXE" --version $args > "$ARTIFACT_DIR/version-invalid.out" 2> "$explain_err"; then
      return 1
    fi
    grep -q -- '--version cannot be combined' "$explain_err" || return 1
  done
}

prohibited_claim_scan() {
  have_python || return 1
  python3 - fixtures/expected/explain.txt fixtures/expected/symbols-inspect-symbols.md fixtures/expected/symbols-inspect-symbols.txt README.md CONTRIBUTING.md <<'PY'
import re
import sys
from pathlib import Path

patterns = [
    re.compile(r'\bbug (prediction|predictions|predict|predicts)\b'),
    re.compile(r'\bobjective code[- ]quality (rating|ratings|score|scores)\b'),
    re.compile(r'\bmaintainer judgement\b'),
    re.compile(r'\bdeveloper (ranking|rankings)\b'),
    re.compile(r'\bproductivity analytics\b'),
    re.compile(r'\bAI/LLM judgement\b', re.IGNORECASE),
    re.compile(r'\btechnical-debt (score|scores)\b'),
    re.compile(r'\bauthor metrics\b'),
    re.compile(r'\bhosted product\b'),
    re.compile(r'\bpricing\b'),
    re.compile(r'\bsales strategy\b'),
    re.compile(r'\bsymbol (history|lineage)\b'),
    re.compile(r'\bdependency propagation\b'),
    re.compile(r'\bprovider evidence (replaces|replacing|supersedes|overrides)\b'),
    re.compile(r'\bprovider (truth|score|ranking)\b'),
]
allowed_markers = (
    ' not ',
    'not ',
    ' no ',
    'no ',
    'without ',
    'avoid ',
    'should not ',
    'does not ',
    'do not ',
    'never ',
    'non-claims',
    'limitations',
)

failures = []
for path_name in sys.argv[1:]:
    path = Path(path_name)
    lines = path.read_text(encoding='utf-8').splitlines()
    for line_no, line in enumerate(lines, 1):
        context = ' '.join(lines[max(0, line_no - 3):line_no])
        normalized = f' {context.strip().lower()} '
        if any(pattern.search(line) for pattern in patterns):
            if not any(marker in normalized for marker in allowed_markers):
                failures.append(f'{path}:{line_no}: {line}')

if failures:
    raise SystemExit('positive prohibited claim(s):\n' + '\n'.join(failures))
PY
}

license_version_checks() {
  [ -f LICENSE ] || return 1
  [ -f CONTRIBUTING.md ] || return 1
  grep -q 'Copyright 2026 Arsham Shirvani' LICENSE || return 1
  grep -q 'Apache License' LICENSE || return 1
  grep -q 'Version 2.0' LICENSE || return 1
  grep -q 'Apache License, Version 2.0' README.md || return 1
  grep -q '0.1.0-alpha.1' README.md || return 1
  grep -q 'Zig `0.16.0`' README.md || return 1
  grep -q 'zig build validate' CONTRIBUTING.md || return 1
  grep -q 'public alpha' CONTRIBUTING.md || return 1
  [ "$("$EXE" --version)" = 'git-hotspots 0.1.0-alpha.1' ] || return 1
  ! grep -R '0\.0\.0-spike' README.md CONTRIBUTING.md src fixtures/expected tests tools build.zig >/dev/null 2>&1 || return 1
}

source_install_smoke() {
  copy=$ARTIFACT_DIR/source-copy
  mkdir -p "$copy"
  tar -cf - \
    --exclude='./.git' \
    --exclude='./zig-out' \
    --exclude='./.zig-cache' \
    --exclude='./fixtures' \
    . | (cd "$copy" && tar -xf -) || return 1

  (cd "$copy" && zig build >/dev/null 2>&1) || return 1
  copy_exe=$copy/zig-out/bin/git-hotspots
  [ "$($copy_exe --version)" = 'git-hotspots 0.1.0-alpha.1' ] || return 1
  "$copy_exe" --help >/dev/null || return 1
  "$copy_exe" --explain >/dev/null || return 1
  copy_json=$ARTIFACT_DIR/source-copy-basic.json
  "$copy_exe" --repo "$copy/fixtures/basic" --format json > "$copy_json" || return 1
  summary=$(json_count_summary "$copy_json") || return 1
  printf 'source-install-copy %s version=0.1.0-alpha.1\n' "$summary" >> "$SMOKES"
}

choose_timing_tool() {
  if [ -x /usr/bin/time ] && /usr/bin/time -v sh -c ':' >/dev/null 2>&1; then
    printf '%s\n' '/usr/bin/time -v'
  elif [ -x /usr/bin/time ] && /usr/bin/time -p sh -c ':' >/dev/null 2>&1; then
    printf '%s\n' '/usr/bin/time -p'
  else
    printf '%s\n' 'shell elapsed seconds'
  fi
}

run_timed_json() {
  repo=$1
  output=$2
  timing_file=$3
  shift 3
  tool=$(choose_timing_tool)
  case "$tool" in
    '/usr/bin/time -v')
      if /usr/bin/time -v "$EXE" --repo "$repo" "$@" --format json > "$output" 2> "$timing_file"; then
        elapsed=$(awk -F': ' '/Elapsed \(wall clock\) time/ {print $2; exit}' "$timing_file")
        [ -n "$elapsed" ] || elapsed="recorded"
        printf '%s|%s\n' "$tool" "$elapsed"
        return 0
      fi
      return 1
      ;;
    '/usr/bin/time -p')
      if /usr/bin/time -p "$EXE" --repo "$repo" "$@" --format json > "$output" 2> "$timing_file"; then
        elapsed=$(awk '/^real / {print $2 "s"; exit}' "$timing_file")
        [ -n "$elapsed" ] || elapsed="recorded"
        printf '%s|%s\n' "$tool" "$elapsed"
        return 0
      fi
      return 1
      ;;
    *)
      start=$(date +%s 2>/dev/null || printf '0')
      if "$EXE" --repo "$repo" "$@" --format json > "$output" 2> "$timing_file"; then
        end=$(date +%s 2>/dev/null || printf '0')
        if [ "$start" -gt 0 ] && [ "$end" -ge "$start" ]; then
          elapsed=$((end - start))s
        else
          elapsed="fallback-note"
        fi
        printf '%s|%s\n' "$tool" "$elapsed"
        return 0
      fi
      return 1
      ;;
  esac
}

fixture_json_checks() {
  sh tools/setup-fixtures.sh >/dev/null 2>&1 || return 1
  "$EXE" --repo fixtures/basic --format json > "$BASIC_A" 2> "$BASIC_ERR" || return 1
  [ ! -s "$BASIC_ERR" ] || return 1
  "$EXE" --repo fixtures/basic --format json > "$BASIC_B" || return 1
  diff -u fixtures/expected/basic.json "$BASIC_A" >/dev/null || return 1
  diff -u "$BASIC_A" "$BASIC_B" >/dev/null || return 1
  "$EXE" --repo fixtures/basic --progress --format json > "$BASIC_PROGRESS_JSON" 2> "$BASIC_PROGRESS_ERR" || return 1
  diff -u "$BASIC_A" "$BASIC_PROGRESS_JSON" >/dev/null || return 1
  progress_stderr_scan "$BASIC_PROGRESS_ERR" || return 1
  "$EXE" --repo fixtures/basic --inspect src/app.txt --format json > "$BASIC_INSPECT_JSON" || return 1
  diff -u fixtures/expected/basic-inspect.json "$BASIC_INSPECT_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/basic --progress --inspect src/app.txt --format json > "$BASIC_INSPECT_PROGRESS_JSON" 2> "$BASIC_INSPECT_PROGRESS_ERR" || return 1
  diff -u "$BASIC_INSPECT_JSON" "$BASIC_INSPECT_PROGRESS_JSON" >/dev/null || return 1
  progress_stderr_scan "$BASIC_INSPECT_PROGRESS_ERR" || return 1
  "$EXE" --repo fixtures/basic --format markdown > "$BASIC_MD_A" || return 1
  "$EXE" --repo fixtures/basic --format markdown > "$BASIC_MD_B" || return 1
  diff -u fixtures/expected/basic.md "$BASIC_MD_A" >/dev/null || return 1
  diff -u "$BASIC_MD_A" "$BASIC_MD_B" >/dev/null || return 1
  "$EXE" --repo fixtures/basic --progress --format markdown > "$BASIC_PROGRESS_MD" 2> "$BASIC_PROGRESS_MD_ERR" || return 1
  diff -u "$BASIC_MD_A" "$BASIC_PROGRESS_MD" >/dev/null || return 1
  progress_stderr_scan "$BASIC_PROGRESS_MD_ERR" || return 1
  "$EXE" --repo fixtures/basic --format table > "$BASIC_TABLE" || return 1
  "$EXE" --repo fixtures/basic --progress --format table > "$BASIC_PROGRESS_TABLE" 2> "$BASIC_PROGRESS_TABLE_ERR" || return 1
  diff -u "$BASIC_TABLE" "$BASIC_PROGRESS_TABLE" >/dev/null || return 1
  progress_stderr_scan "$BASIC_PROGRESS_TABLE_ERR" || return 1
  "$EXE" --repo fixtures/basic --inspect src/app.txt --format markdown > "$BASIC_INSPECT_MD" || return 1
  diff -u fixtures/expected/basic-inspect.md "$BASIC_INSPECT_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/basic --inspect src/app.txt --format table > "$BASIC_INSPECT_TABLE" || return 1
  diff -u fixtures/expected/basic-inspect.txt "$BASIC_INSPECT_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --format json > "$SYMBOLS_JSON" || return 1
  diff -u fixtures/expected/symbols-inspect-symbols.json "$SYMBOLS_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --format markdown > "$SYMBOLS_MD" || return 1
  diff -u fixtures/expected/symbols-inspect-symbols.md "$SYMBOLS_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --format table > "$SYMBOLS_TABLE" || return 1
  diff -u fixtures/expected/symbols-inspect-symbols.txt "$SYMBOLS_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/symbols --inspect src/readme.txt --symbols --format json > "$SYMBOLS_UNSUPPORTED_JSON" || return 1
  diff -u fixtures/expected/symbols-unsupported.json "$SYMBOLS_UNSUPPORTED_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/symbols --inspect src/link.zig --symbols --format json > "$SYMBOLS_SYMLINK_JSON" || return 1
  diff -u fixtures/expected/symbols-symlink-unavailable.json "$SYMBOLS_SYMLINK_JSON" >/dev/null || return 1
  have_python || return 1
  python3 - "$SYMBOLS_JSON" "$SYMBOLS_UNSUPPORTED_JSON" "$SYMBOLS_SYMLINK_JSON" <<'PY'
import json, sys
success, unsupported, symlink = [json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
for data in (success, unsupported, symlink):
    symbols = data['symbols']
    assert symbols['current_only'] is True, 'symbols current_only missing'
    assert 'items' in symbols and 'rows' not in symbols, 'symbols items schema mismatch'
    provider = symbols['provider']
    assert provider['provenance']['local_only'] is True, 'local provenance missing'
    assert provider['provenance']['input'].startswith('working-tree:'), 'provider input provenance mismatch'
    assert 'provider_name' not in provider['provenance'] and 'input_identity' not in provider['provenance'], 'old provenance keys leaked'
for row in success['symbols']['items']:
    assert row['provider'] == 'tree-sitter-zig', 'symbol row provider missing'
assert success['symbols']['provider']['failure'] == 'ok', 'success provider failure changed'
assert unsupported['symbols']['provider']['failure'] == 'unsupported', 'unsupported provider failure changed'
assert symlink['symbols']['provider']['failure'] == 'unavailable', 'symlink should not parse as ok'
assert symlink['symbols']['items'] == [], 'symlink leaked parsed symbols'
assert symlink['results'], 'symlink did not preserve file evidence'
PY
  if "$EXE" --symbols > "$ARTIFACT_DIR/symbols-alone.out" 2> "$ARTIFACT_DIR/symbols-alone.err"; then return 1; fi
  grep -q -- '--symbols can only be combined with --inspect PATH' "$ARTIFACT_DIR/symbols-alone.err" || return 1
  if "$EXE" --repo fixtures/basic --inspect src/app.txt --limit 1 >/dev/null 2> "$ARTIFACT_DIR/inspect-limit.err"; then return 1; fi
  grep -q -- '--limit cannot be combined with --inspect' "$ARTIFACT_DIR/inspect-limit.err" || return 1
  if "$EXE" --repo fixtures/basic --inspect missing.txt >/dev/null 2> "$ARTIFACT_DIR/inspect-missing.err"; then return 1; fi
  grep -q -- '--inspect target has no matching' "$ARTIFACT_DIR/inspect-missing.err" || return 1
  "$EXE" --repo fixtures/scope --format json > "$SCOPE_UNFILTERED_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope all --limit 200 --format json > "$SCOPE_ALL_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --format json > "$SCOPE_FILTERED_JSON" || return 1
  diff -u fixtures/expected/scope-filtered.json "$SCOPE_FILTERED_JSON" >/dev/null || return 1
  if "$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --inspect .flow/secret.txt --format json > "$ARTIFACT_DIR/inspect-excluded.out" 2> "$ARTIFACT_DIR/inspect-excluded.err"; then return 1; fi
  grep -q -- '--inspect target has no matching' "$ARTIFACT_DIR/inspect-excluded.err" || return 1
  "$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --inspect src/vendor_adapter.zig --format json > "$SCOPE_INSPECT_EXCLUDED_FLOW_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --format markdown > "$SCOPE_FILTERED_MD" || return 1
  "$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --format markdown > "$SCOPE_FILTERED_MD_B" || return 1
  diff -u fixtures/expected/scope-filtered.md "$SCOPE_FILTERED_MD" >/dev/null || return 1
  diff -u "$SCOPE_FILTERED_MD" "$SCOPE_FILTERED_MD_B" >/dev/null || return 1
  "$EXE" --repo fixtures/scope --scope project --format json > "$SCOPE_PROJECT_JSON" || return 1
  diff -u "$SCOPE_UNFILTERED_JSON" "$SCOPE_PROJECT_JSON" >/dev/null || return 1
  diff -u fixtures/expected/scope-project.json "$SCOPE_PROJECT_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/scope --scope project --progress --format json > "$SCOPE_PROJECT_PROGRESS_JSON" 2> "$SCOPE_PROJECT_PROGRESS_ERR" || return 1
  diff -u "$SCOPE_PROJECT_JSON" "$SCOPE_PROJECT_PROGRESS_JSON" >/dev/null || return 1
  progress_stderr_scan "$SCOPE_PROJECT_PROGRESS_ERR" || return 1
  "$EXE" --repo fixtures/scope --scope project --format json > "$SCOPE_PROJECT_JSON_B" || return 1
  diff -u "$SCOPE_PROJECT_JSON" "$SCOPE_PROJECT_JSON_B" >/dev/null || return 1
  "$EXE" --repo fixtures/scope --scope project --format markdown > "$SCOPE_PROJECT_MD" || return 1
  "$EXE" --repo fixtures/scope --scope project --format markdown > "$SCOPE_PROJECT_MD_B" || return 1
  diff -u fixtures/expected/scope-project.md "$SCOPE_PROJECT_MD" >/dev/null || return 1
  diff -u "$SCOPE_PROJECT_MD" "$SCOPE_PROJECT_MD_B" >/dev/null || return 1
  "$EXE" --repo fixtures/scope --scope project --inspect src/vendor_adapter.zig --format json > "$SCOPE_PROJECT_INSPECT_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope project --progress --inspect src/vendor_adapter.zig --format json > "$SCOPE_PROJECT_INSPECT_PROGRESS_JSON" 2> "$SCOPE_PROJECT_INSPECT_PROGRESS_ERR" || return 1
  diff -u "$SCOPE_PROJECT_INSPECT_JSON" "$SCOPE_PROJECT_INSPECT_PROGRESS_JSON" >/dev/null || return 1
  progress_stderr_scan "$SCOPE_PROJECT_INSPECT_PROGRESS_ERR" || return 1
  "$EXE" --repo fixtures/scope --scope all --inspect .flow/state.yaml --format json > "$SCOPE_ALL_INSPECT_FLOW_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope all --inspect .zig-cache/from-src.txt --format json > "$SCOPE_ALL_INSPECT_INCLUDED_TO_EXCLUDED_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope all --inspect build/excluded-chain-b.txt --format json > "$SCOPE_ALL_INSPECT_EXCLUDED_TO_EXCLUDED_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope all --inspect src/chain-final.txt --format json > "$SCOPE_ALL_INSPECT_CHAINED_CROSS_JSON" || return 1
  if "$EXE" --repo fixtures/scope --scope project --inspect .flow/state.yaml --format json > "$ARTIFACT_DIR/project-inspect-flow.out" 2> "$ARTIFACT_DIR/project-inspect-flow.err"; then return 1; fi
  grep -q -- '--inspect target has no matching' "$ARTIFACT_DIR/project-inspect-flow.err" || return 1
  if "$EXE" --repo fixtures/scope --scope project --inspect .zig-cache/from-src.txt --format json > "$ARTIFACT_DIR/project-inspect-included-to-excluded.out" 2> "$ARTIFACT_DIR/project-inspect-included-to-excluded.err"; then return 1; fi
  grep -q -- '--inspect target has no matching' "$ARTIFACT_DIR/project-inspect-included-to-excluded.err" || return 1
  if "$EXE" --repo fixtures/scope --scope project --inspect build/excluded-chain-b.txt --format json > "$ARTIFACT_DIR/project-inspect-excluded-to-excluded-new.out" 2> "$ARTIFACT_DIR/project-inspect-excluded-to-excluded-new.err"; then return 1; fi
  grep -q -- '--inspect target has no matching' "$ARTIFACT_DIR/project-inspect-excluded-to-excluded-new.err" || return 1
  if "$EXE" --repo fixtures/scope --scope project --inspect target/excluded-chain-a.txt --format json > "$ARTIFACT_DIR/project-inspect-excluded-to-excluded-old.out" 2> "$ARTIFACT_DIR/project-inspect-excluded-to-excluded-old.err"; then return 1; fi
  grep -q -- '--inspect target has no matching' "$ARTIFACT_DIR/project-inspect-excluded-to-excluded-old.err" || return 1
  if "$EXE" --repo fixtures/scope --scope project --inspect node_modules/pkg/chain-mid.txt --format json > "$ARTIFACT_DIR/project-inspect-chained-excluded-hop.out" 2> "$ARTIFACT_DIR/project-inspect-chained-excluded-hop.err"; then return 1; fi
  grep -q -- '--inspect target has no matching' "$ARTIFACT_DIR/project-inspect-chained-excluded-hop.err" || return 1
  "$EXE" --repo fixtures/scope --scope project --inspect src/to-cache.txt --format json > "$SCOPE_PROJECT_INSPECT_INCLUDED_TO_EXCLUDED_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope project --inspect src/chain-final.txt --format json > "$SCOPE_PROJECT_INSPECT_CHAINED_CROSS_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope project --exclude-prefix .flow/ --format json > "$SCOPE_PROJECT_DUPLICATE_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope project --include-prefix .flow/ --format json > "$SCOPE_PROJECT_INCLUDE_FLOW_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope project --include-prefix node_modules/ --format json > "$SCOPE_PROJECT_INCLUDE_NODE_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope all --include-prefix node_modules/ --format json > "$SCOPE_ALL_INCLUDE_NODE_JSON" || return 1
  "$EXE" --repo fixtures/scope --scope project --include-prefix src/ --format json > "$SCOPE_PROJECT_INCLUDE_SRC_JSON" || return 1
  "$EXE" --repo fixtures/scope --include-prefix src/ --format json > "$SCOPE_SRC_INCLUDE_JSON" || return 1
  "$EXE" --repo fixtures/scope --include-prefix src/ --inspect src/new.zig --format json > "$SCOPE_INSPECT_RENAMED_JSON" || return 1
  "$EXE" --repo fixtures/scope --include-prefix src/ --format markdown > "$SCOPE_SRC_INCLUDE_MD" || return 1
  "$EXE" --repo fixtures/scope --include-prefix src/ --format table > "$SCOPE_SRC_INCLUDE_TABLE" || return 1
  "$EXE" --repo fixtures/scope --include-prefix src/ --include-prefix vendor/ --format json > "$SCOPE_SRC_VENDOR_INCLUDE_JSON" || return 1
  "$EXE" --repo fixtures/scope --include-prefix src/ --exclude-prefix src/vendor_adapter.zig --format json > "$SCOPE_INCLUDE_EXCLUDE_JSON" || return 1
  "$EXE" --repo fixtures/scope --exclude-prefix src/ --format json > "$SCOPE_SRC_FILTERED_JSON" || return 1
  "$EXE" --repo fixtures/scope --exclude-prefix weird/ --format json > "$SCOPE_WEIRD_FILTERED_JSON" || return 1
  "$EXE" --repo fixtures/scope --include-prefix weird/ --format json > "$SCOPE_WEIRD_INCLUDE_JSON" || return 1
  "$EXE" --repo fixtures/scope --include-prefix 'glob/*' --format json > "$SCOPE_GLOB_STAR_INCLUDE_JSON" || return 1
  "$EXE" --repo fixtures/scope --include-prefix glob/ --format json > "$SCOPE_GLOB_INCLUDE_JSON" || return 1
  "$EXE" --repo fixtures/scope --include-prefix does-not-exist/ --format json > "$SCOPE_INCLUDE_EMPTY_JSON" || return 1
  "$EXE" --repo fixtures/scope --include-prefix does-not-exist/ --format markdown > "$SCOPE_INCLUDE_EMPTY_MD" || return 1
  "$EXE" --repo fixtures/scope --exclude-prefix .flow/ --exclude-prefix src/ --exclude-prefix vendor/ --exclude-prefix glob/ --exclude-prefix weird/ --exclude-prefix docs/ --format json > "$SCOPE_EMPTY_JSON" || return 1
  "$EXE" --repo fixtures/scope --exclude-prefix .flow/ --exclude-prefix src/ --exclude-prefix vendor/ --exclude-prefix glob/ --exclude-prefix weird/ --exclude-prefix docs/ --format markdown > "$SCOPE_EMPTY_MD" || return 1
  "$EXE" --repo fixtures/edge --limit 200 --format markdown > "$EDGE_MD" || return 1
  "$EXE" --repo fixtures/edge --inspect 'glob/[literal]*.txt' --format markdown > "$EDGE_INSPECT_MD" || return 1
  "$EXE" --repo fixtures/edge --inspect 'weird/tab\tname.txt' --format json > "$EDGE_INSPECT_TAB_JSON" || return 1
  if "$EXE" --repo fixtures/basic --progress --since does-not-exist > "$ARTIFACT_DIR/progress-invalid-since.out" 2> "$ARTIFACT_DIR/progress-invalid-since.err"; then return 1; fi
  grep -q -- 'progress: checking repository' "$ARTIFACT_DIR/progress-invalid-since.err" || return 1
  grep -q -- '--since must name' "$ARTIFACT_DIR/progress-invalid-since.err" || return 1
  "$EXE" --repo fixtures/shallow --format json > "$SHALLOW_JSON" || return 1
  "$EXE" --repo fixtures/partial --format json > "$PARTIAL_JSON" || return 1
  "$EXE" --repo . --format json > "$SELF_JSON" || return 1
  "$EXE" --repo . --format markdown > "$SELF_MARKDOWN" || return 1
  "$EXE" --repo . --exclude-prefix .flow/ --limit 10 --format json > "$SELF_SCOPED_JSON" || return 1
  "$EXE" --repo . --exclude-prefix .flow/ --limit 10 --format markdown > "$SELF_SCOPED_MARKDOWN" || return 1
  summary=$(json_count_summary "$SELF_SCOPED_JSON") || return 1
  printf 'this-repo scoped-flow %s\n' "$summary" >> "$SMOKES"
}

fixture_performance_smoke() {
  timing_file=$(mktemp "$ARTIFACT_DIR/time.XXXXXX")
  medium_json=$(mktemp "$ARTIFACT_DIR/medium.XXXXXX.json")
  timing=$(run_timed_json fixtures/medium "$medium_json" "$timing_file") || return 1
  tool=${timing%%|*}
  elapsed=${timing#*|}
  note_fallback "timing: $tool"
  summary=$(json_count_summary "$medium_json") || return 1
  printf 'fixture-medium %s elapsed=%s\n' "$summary" "$elapsed" >> "$SMOKES"
}

real_repo_smoke() {
  label=$1
  repo=$2
  safe_label "$label" || { fail_rung "real repo smoke $label" "label must use only letters, digits, dot, underscore, or hyphen"; return 1; }
  if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail_rung "real repo smoke $label" "repository argument is not a Git worktree"
    return 1
  fi

  table_out=$(mktemp "$ARTIFACT_DIR/table.XXXXXX")
  json_out=$(mktemp "$ARTIFACT_DIR/real.XXXXXX.json")
  markdown_out=$(mktemp "$ARTIFACT_DIR/real.XXXXXX.md")
  project_table_out=$(mktemp "$ARTIFACT_DIR/project-table.XXXXXX")
  project_json_out=$(mktemp "$ARTIFACT_DIR/project-real.XXXXXX.json")
  project_markdown_out=$(mktemp "$ARTIFACT_DIR/project-real.XXXXXX.md")
  progress_json_out=$(mktemp "$ARTIFACT_DIR/progress-real.XXXXXX.json")
  progress_err=$(mktemp "$ARTIFACT_DIR/progress-real.XXXXXX.err")
  timing_file=$(mktemp "$ARTIFACT_DIR/real-time.XXXXXX")
  commit_count=$(git -C "$repo" rev-list --count HEAD 2>/dev/null || printf 'unknown')
  tracked_file_count=$(git -C "$repo" ls-files 2>/dev/null | wc -l | tr -d ' ' || printf 'unknown')

  if "$EXE" --repo "$repo" --scope all --format table > "$table_out" 2> "$timing_file"; then
    table_status=pass
  else
    table_status=fail
  fi

  timing=$(run_timed_json "$repo" "$json_out" "$timing_file" --scope all) || timing='timing failed|unknown'
  case "$timing" in
    'timing failed|unknown') json_status=fail ;;
    *) json_status=pass ;;
  esac

  if "$EXE" --repo "$repo" --scope all --format markdown > "$markdown_out" 2> "$timing_file"; then
    markdown_status=pass
  else
    markdown_status=fail
  fi

  if "$EXE" --repo "$repo" --scope project --format table > "$project_table_out" 2> "$timing_file"; then
    project_table_status=pass
  else
    project_table_status=fail
  fi

  project_timing=$(run_timed_json "$repo" "$project_json_out" "$timing_file" --scope project) || project_timing='timing failed|unknown'
  case "$project_timing" in
    'timing failed|unknown') project_json_status=fail ;;
    *) project_json_status=pass ;;
  esac

  if "$EXE" --repo "$repo" --scope project --format markdown > "$project_markdown_out" 2> "$timing_file"; then
    project_markdown_status=pass
  else
    project_markdown_status=fail
  fi

  if "$EXE" --repo "$repo" --scope project --progress --format json > "$progress_json_out" 2> "$progress_err" && diff -u "$project_json_out" "$progress_json_out" >/dev/null && progress_stderr_scan "$progress_err"; then
    progress_status=pass
  else
    progress_status=fail
  fi

  if [ "$table_status" = pass ] && [ "$json_status" = pass ] && [ "$markdown_status" = pass ] && [ "$project_table_status" = pass ] && [ "$project_json_status" = pass ] && [ "$project_markdown_status" = pass ] && [ "$progress_status" = pass ]; then
    summary=$(json_count_summary "$json_out") || summary='results=unknown caveats=unknown dirty=unknown'
    project_summary=$(json_count_summary "$project_json_out") || project_summary='results=unknown caveats=unknown dirty=unknown'
    elapsed=${timing#*|}
    project_elapsed=${project_timing#*|}
    printf 'real-repo label=%s commits=%s tracked_files=%s all_table=%s all_json=%s all_markdown=%s all_%s all_elapsed=%s project_table=%s project_json=%s project_markdown=%s project_progress=%s project_%s project_elapsed=%s\n' "$label" "$commit_count" "$tracked_file_count" "$table_status" "$json_status" "$markdown_status" "$summary" "$elapsed" "$project_table_status" "$project_json_status" "$project_markdown_status" "$progress_status" "$project_summary" "$project_elapsed" >> "$SMOKES"
    pass_rung "real repo smoke $label"
    return 0
  fi

  fail_rung "real repo smoke $label" "all_table=$table_status all_json=$json_status all_markdown=$markdown_status project_table=$project_table_status project_json=$project_json_status project_markdown=$project_markdown_status project_progress=$progress_status"
  return 1
}

BASIC_A=$ARTIFACT_DIR/basic-a.json
BASIC_B=$ARTIFACT_DIR/basic-b.json
BASIC_ERR=$ARTIFACT_DIR/basic.err
BASIC_PROGRESS_JSON=$ARTIFACT_DIR/basic-progress.json
BASIC_PROGRESS_ERR=$ARTIFACT_DIR/basic-progress.err
BASIC_INSPECT_JSON=$ARTIFACT_DIR/basic-inspect.json
BASIC_INSPECT_PROGRESS_JSON=$ARTIFACT_DIR/basic-inspect-progress.json
BASIC_INSPECT_PROGRESS_ERR=$ARTIFACT_DIR/basic-inspect-progress.err
BASIC_MD_A=$ARTIFACT_DIR/basic-a.md
BASIC_MD_B=$ARTIFACT_DIR/basic-b.md
BASIC_PROGRESS_MD=$ARTIFACT_DIR/basic-progress.md
BASIC_PROGRESS_MD_ERR=$ARTIFACT_DIR/basic-progress-md.err
BASIC_TABLE=$ARTIFACT_DIR/basic.txt
BASIC_PROGRESS_TABLE=$ARTIFACT_DIR/basic-progress.txt
BASIC_PROGRESS_TABLE_ERR=$ARTIFACT_DIR/basic-progress-table.err
BASIC_INSPECT_MD=$ARTIFACT_DIR/basic-inspect.md
BASIC_INSPECT_TABLE=$ARTIFACT_DIR/basic-inspect.txt
SYMBOLS_JSON=$ARTIFACT_DIR/symbols.json
SYMBOLS_MD=$ARTIFACT_DIR/symbols.md
SYMBOLS_TABLE=$ARTIFACT_DIR/symbols.txt
SYMBOLS_UNSUPPORTED_JSON=$ARTIFACT_DIR/symbols-unsupported.json
SYMBOLS_SYMLINK_JSON=$ARTIFACT_DIR/symbols-symlink.json
SCOPE_UNFILTERED_JSON=$ARTIFACT_DIR/scope-unfiltered.json
SCOPE_ALL_JSON=$ARTIFACT_DIR/scope-all.json
SCOPE_FILTERED_JSON=$ARTIFACT_DIR/scope-filtered.json
SCOPE_INSPECT_EXCLUDED_FLOW_JSON=$ARTIFACT_DIR/scope-inspect-excluded-flow.json
SCOPE_FILTERED_MD=$ARTIFACT_DIR/scope-filtered.md
SCOPE_FILTERED_MD_B=$ARTIFACT_DIR/scope-filtered-b.md
SCOPE_PROJECT_JSON=$ARTIFACT_DIR/scope-project.json
SCOPE_PROJECT_JSON_B=$ARTIFACT_DIR/scope-project-b.json
SCOPE_PROJECT_PROGRESS_JSON=$ARTIFACT_DIR/scope-project-progress.json
SCOPE_PROJECT_PROGRESS_ERR=$ARTIFACT_DIR/scope-project-progress.err
SCOPE_PROJECT_DUPLICATE_JSON=$ARTIFACT_DIR/scope-project-duplicate.json
SCOPE_PROJECT_INCLUDE_FLOW_JSON=$ARTIFACT_DIR/scope-project-include-flow.json
SCOPE_PROJECT_INCLUDE_NODE_JSON=$ARTIFACT_DIR/scope-project-include-node.json
SCOPE_ALL_INCLUDE_NODE_JSON=$ARTIFACT_DIR/scope-all-include-node.json
SCOPE_PROJECT_INCLUDE_SRC_JSON=$ARTIFACT_DIR/scope-project-include-src.json
SCOPE_PROJECT_INSPECT_JSON=$ARTIFACT_DIR/scope-project-inspect.json
SCOPE_PROJECT_INSPECT_PROGRESS_JSON=$ARTIFACT_DIR/scope-project-inspect-progress.json
SCOPE_PROJECT_INSPECT_PROGRESS_ERR=$ARTIFACT_DIR/scope-project-inspect-progress.err
SCOPE_ALL_INSPECT_FLOW_JSON=$ARTIFACT_DIR/scope-all-inspect-flow.json
SCOPE_ALL_INSPECT_INCLUDED_TO_EXCLUDED_JSON=$ARTIFACT_DIR/scope-all-inspect-included-to-excluded.json
SCOPE_ALL_INSPECT_EXCLUDED_TO_EXCLUDED_JSON=$ARTIFACT_DIR/scope-all-inspect-excluded-to-excluded.json
SCOPE_ALL_INSPECT_CHAINED_CROSS_JSON=$ARTIFACT_DIR/scope-all-inspect-chained-cross.json
SCOPE_PROJECT_INSPECT_INCLUDED_TO_EXCLUDED_JSON=$ARTIFACT_DIR/scope-project-inspect-included-to-excluded.json
SCOPE_PROJECT_INSPECT_CHAINED_CROSS_JSON=$ARTIFACT_DIR/scope-project-inspect-chained-cross.json
SCOPE_PROJECT_MD=$ARTIFACT_DIR/scope-project.md
SCOPE_PROJECT_MD_B=$ARTIFACT_DIR/scope-project-b.md
SCOPE_SRC_INCLUDE_JSON=$ARTIFACT_DIR/scope-src-include.json
SCOPE_INSPECT_RENAMED_JSON=$ARTIFACT_DIR/scope-inspect-renamed.json
SCOPE_SRC_INCLUDE_MD=$ARTIFACT_DIR/scope-src-include.md
SCOPE_SRC_INCLUDE_TABLE=$ARTIFACT_DIR/scope-src-include.txt
SCOPE_SRC_VENDOR_INCLUDE_JSON=$ARTIFACT_DIR/scope-src-vendor-include.json
SCOPE_INCLUDE_EXCLUDE_JSON=$ARTIFACT_DIR/scope-include-exclude.json
SCOPE_WEIRD_INCLUDE_JSON=$ARTIFACT_DIR/scope-weird-include.json
SCOPE_GLOB_STAR_INCLUDE_JSON=$ARTIFACT_DIR/scope-glob-star-include.json
SCOPE_GLOB_INCLUDE_JSON=$ARTIFACT_DIR/scope-glob-include.json
SCOPE_INCLUDE_EMPTY_JSON=$ARTIFACT_DIR/scope-include-empty.json
SCOPE_INCLUDE_EMPTY_MD=$ARTIFACT_DIR/scope-include-empty.md
SCOPE_SRC_FILTERED_JSON=$ARTIFACT_DIR/scope-src-filtered.json
SCOPE_WEIRD_FILTERED_JSON=$ARTIFACT_DIR/scope-weird-filtered.json
SCOPE_EMPTY_JSON=$ARTIFACT_DIR/scope-empty.json
SCOPE_EMPTY_MD=$ARTIFACT_DIR/scope-empty.md
SHALLOW_JSON=$ARTIFACT_DIR/shallow.json
PARTIAL_JSON=$ARTIFACT_DIR/partial.json
EDGE_MD=$ARTIFACT_DIR/edge.md
EDGE_INSPECT_MD=$ARTIFACT_DIR/edge-inspect.md
EDGE_INSPECT_TAB_JSON=$ARTIFACT_DIR/edge-inspect-tab.json
SELF_JSON=$ARTIFACT_DIR/self.json
SELF_SCOPED_JSON=$ARTIFACT_DIR/self-scoped.json
SELF_MARKDOWN=$ARTIFACT_DIR/self.md
SELF_SCOPED_MARKDOWN=$ARTIFACT_DIR/self-scoped.md

run_quiet "format check" zig fmt --check build.zig src tests
run_quiet "fast gate: zig build test" zig build test
run_quiet "build executable: zig build" zig build
run_quiet "help text smoke" "$EXE" --help
printf 'validate: RUN explain golden, determinism, standalone, and invalid combinations\n'
if explain_output_checks; then
  pass_rung "explain golden, determinism, standalone, and invalid combinations"
else
  fail_rung "explain golden, determinism, standalone, and invalid combinations" "explain output or parser contract failed"
fi
printf 'validate: RUN prohibited claim scan\n'
if prohibited_claim_scan; then
  note_fallback "prohibited claim scan: python3 allowlist-aware line scan"
  pass_rung "prohibited claim scan"
else
  fail_rung "prohibited claim scan" "positive prohibited claim detected or python3 unavailable"
fi
printf 'validate: RUN license and version consistency\n'
if license_version_checks; then
  pass_rung "license and version consistency"
else
  fail_rung "license and version consistency" "license, docs, fixtures, or CLI version contract failed"
fi
run_quiet "git diff whitespace check" git diff --check
run_quiet "shell syntax checks" sh -c "for file in tools/*.sh tests/*.sh; do sh -n \"\$file\" || exit 1; done"

printf 'validate: RUN deterministic fixture JSON and Markdown\n'
if fixture_json_checks; then
  pass_rung "deterministic fixture JSON and Markdown"
else
  fail_rung "deterministic fixture JSON and Markdown" "fixture output was invalid or unstable"
fi

printf 'validate: RUN JSON validity\n'
json_validity "JSON validity" "$BASIC_A" "$BASIC_B" "$BASIC_PROGRESS_JSON" "$BASIC_INSPECT_JSON" "$BASIC_INSPECT_PROGRESS_JSON" "$SYMBOLS_JSON" "$SYMBOLS_UNSUPPORTED_JSON" "$SYMBOLS_SYMLINK_JSON" "$SCOPE_UNFILTERED_JSON" "$SCOPE_ALL_JSON" "$SCOPE_FILTERED_JSON" "$SCOPE_PROJECT_JSON" "$SCOPE_PROJECT_JSON_B" "$SCOPE_PROJECT_PROGRESS_JSON" "$SCOPE_PROJECT_DUPLICATE_JSON" "$SCOPE_PROJECT_INCLUDE_FLOW_JSON" "$SCOPE_PROJECT_INCLUDE_NODE_JSON" "$SCOPE_ALL_INCLUDE_NODE_JSON" "$SCOPE_PROJECT_INCLUDE_SRC_JSON" "$SCOPE_PROJECT_INSPECT_JSON" "$SCOPE_PROJECT_INSPECT_PROGRESS_JSON" "$SCOPE_ALL_INSPECT_FLOW_JSON" "$SCOPE_ALL_INSPECT_INCLUDED_TO_EXCLUDED_JSON" "$SCOPE_ALL_INSPECT_EXCLUDED_TO_EXCLUDED_JSON" "$SCOPE_ALL_INSPECT_CHAINED_CROSS_JSON" "$SCOPE_PROJECT_INSPECT_INCLUDED_TO_EXCLUDED_JSON" "$SCOPE_PROJECT_INSPECT_CHAINED_CROSS_JSON" "$SCOPE_INSPECT_EXCLUDED_FLOW_JSON" "$SCOPE_INSPECT_RENAMED_JSON" "$SCOPE_SRC_INCLUDE_JSON" "$SCOPE_SRC_VENDOR_INCLUDE_JSON" "$SCOPE_INCLUDE_EXCLUDE_JSON" "$SCOPE_WEIRD_INCLUDE_JSON" "$SCOPE_GLOB_STAR_INCLUDE_JSON" "$SCOPE_GLOB_INCLUDE_JSON" "$SCOPE_INCLUDE_EMPTY_JSON" "$SCOPE_SRC_FILTERED_JSON" "$SCOPE_WEIRD_FILTERED_JSON" "$SCOPE_EMPTY_JSON" "$EDGE_INSPECT_TAB_JSON" "$SHALLOW_JSON" "$PARTIAL_JSON" "$SELF_JSON" "$SELF_SCOPED_JSON" || fail_rung "JSON validity" "no JSON checker succeeded"

printf 'validate: RUN shallow, partial, and privacy assertions\n'
if semantic_assertions; then
  note_fallback "privacy/path scans: python3 semantic checks; rg not required"
  pass_rung "shallow, partial, and privacy assertions"
else
  fail_rung "shallow, partial, and privacy assertions" "semantic assertions failed"
fi

printf 'validate: RUN Markdown semantic and privacy assertions\n'
if markdown_assertions; then
  note_fallback "markdown privacy/path scans: python3 semantic checks; rg not required"
  pass_rung "Markdown semantic and privacy assertions"
else
  fail_rung "Markdown semantic and privacy assertions" "semantic assertions failed"
fi

printf 'validate: RUN medium fixture performance smoke\n'
if fixture_performance_smoke; then
  pass_rung "medium fixture performance smoke"
else
  fail_rung "medium fixture performance smoke" "timed fixture command failed"
fi

printf 'validate: RUN source install smoke\n'
if source_install_smoke; then
  pass_rung "source install smoke"
else
  fail_rung "source install smoke" "clean disposable source build or basic analysis failed"
fi

real_repo_smoke this-repo "$ROOT" || true

if [ "$CLOSEOUT" = true ]; then
  if [ -n "$SMOKE_REPO" ]; then
    if [ -z "$SMOKE_LABEL" ]; then
      fail_rung "close-out sibling smoke" "--smoke-label is required with --smoke-repo"
    else
      real_repo_smoke "$SMOKE_LABEL" "$SMOKE_REPO" || true
    fi
  elif [ -n "$SMOKE_SKIP_REASON" ]; then
    if safe_reason "$SMOKE_SKIP_REASON"; then
      printf 'closeout-second-smoke skipped reason=%s\n' "$SMOKE_SKIP_REASON" >> "$SMOKES"
      pass_rung "close-out sibling smoke explicit skip"
    else
      fail_rung "close-out sibling smoke explicit skip" "skip reason is missing or not privacy-safe"
    fi
  else
    fail_rung "close-out sibling smoke" "provide --smoke-repo and --smoke-label or --smoke-skip-reason"
  fi
fi

printf '\nVALIDATION EVIDENCE SUMMARY\n'
printf 'command: zig build validate\n'
printf 'mode: %s\n' "$(if [ "$CLOSEOUT" = true ]; then printf 'close-out'; else printf 'default'; fi)"
printf 'rungs:\n'
sed 's/^/  - /' "$SUMMARY"
printf 'fallbacks:\n'
if [ -s "$FALLBACKS" ]; then
  sort -u "$FALLBACKS" | sed 's/^/  - /'
else
  printf '  - none\n'
fi
printf 'smoke evidence:\n'
if [ -s "$SMOKES" ]; then
  sed 's/^/  - /' "$SMOKES"
else
  printf '  - none\n'
fi
printf 'privacy: summary uses labels and bounded counts only; raw reports and absolute private paths are not printed.\n'
printf 'local-only: no fetch, pull, push, upload, telemetry, remote enrichment, CI service, default provider runtime, cache requirement, packaging, or release automation; opt-in inspect-only Tree-sitter Zig symbols are local current-file enrichment.\n'

if [ "$FAILURES" -ne 0 ]; then
  printf 'validate: %d rung(s) failed\n' "$FAILURES" >&2
  exit 1
fi

printf 'validate: all rungs passed\n'
