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
  python3 - "$BASIC_A" "$BASIC_INSPECT_JSON" "$SHALLOW_JSON" "$PARTIAL_JSON" "$SELF_JSON" "$SELF_SCOPED_JSON" "$SCOPE_UNFILTERED_JSON" "$SCOPE_ALL_JSON" "$SCOPE_FILTERED_JSON" "$SCOPE_PROJECT_JSON" "$SCOPE_PROJECT_DUPLICATE_JSON" "$SCOPE_PROJECT_INCLUDE_FLOW_JSON" "$SCOPE_PROJECT_INCLUDE_NODE_JSON" "$SCOPE_ALL_INCLUDE_NODE_JSON" "$SCOPE_PROJECT_INCLUDE_SRC_JSON" "$SCOPE_PROJECT_INSPECT_JSON" "$SCOPE_ALL_INSPECT_FLOW_JSON" "$SCOPE_ALL_INSPECT_INCLUDED_TO_EXCLUDED_JSON" "$SCOPE_ALL_INSPECT_EXCLUDED_TO_EXCLUDED_JSON" "$SCOPE_ALL_INSPECT_CHAINED_CROSS_JSON" "$SCOPE_PROJECT_INSPECT_INCLUDED_TO_EXCLUDED_JSON" "$SCOPE_PROJECT_INSPECT_CHAINED_CROSS_JSON" "$SCOPE_INSPECT_EXCLUDED_FLOW_JSON" "$SCOPE_INSPECT_RENAMED_JSON" "$SCOPE_SRC_FILTERED_JSON" "$SCOPE_WEIRD_FILTERED_JSON" "$SCOPE_EMPTY_JSON" "$SCOPE_SRC_INCLUDE_JSON" "$SCOPE_SRC_VENDOR_INCLUDE_JSON" "$SCOPE_INCLUDE_EXCLUDE_JSON" "$SCOPE_WEIRD_INCLUDE_JSON" "$SCOPE_GLOB_STAR_INCLUDE_JSON" "$SCOPE_GLOB_INCLUDE_JSON" "$SCOPE_INCLUDE_EMPTY_JSON" "$EDGE_INSPECT_TAB_JSON" "$SYMBOL_RELATIONSHIPS_JSON" <<'PY'
import json, os, re, sys
basic_path, basic_inspect_path, shallow_path, partial_path, self_path, self_scoped_path, scope_unfiltered_path, scope_all_path, scope_filtered_path, scope_project_path, scope_project_duplicate_path, scope_project_include_flow_path, scope_project_include_node_path, scope_all_include_node_path, scope_project_include_src_path, scope_project_inspect_path, scope_all_inspect_flow_path, scope_all_inspect_included_to_excluded_path, scope_all_inspect_excluded_to_excluded_path, scope_all_inspect_chained_cross_path, scope_project_inspect_included_to_excluded_path, scope_project_inspect_chained_cross_path, scope_inspect_excluded_flow_path, scope_inspect_renamed_path, scope_src_filtered_path, scope_weird_filtered_path, scope_empty_path, scope_src_include_path, scope_src_vendor_include_path, scope_include_exclude_path, scope_weird_include_path, scope_glob_star_include_path, scope_glob_include_path, scope_include_empty_path, edge_inspect_tab_path, symbol_relationships_path = sys.argv[1:]

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

symbol_relationships = load(symbol_relationships_path)
relationships = symbol_relationships['symbol_relationships']
assert relationships['basis']['requires_symbols_flag'] is True, 'relationship basis lost symbols prerequisite'
assert relationships['basis']['scoring_effect'] == 'none', 'relationship report gained scoring effect'
assert relationships['provenance']['local_only'] is True and relationships['provenance']['network'] is False, 'relationship provenance is not local-only'
assert relationships['human_display']['active_limit'] == 4, 'relationship display limit changed'
assert relationships['human_display']['shown_count'] == 4, 'relationship shown count changed'
assert relationships['human_display']['omitted_count'] == relationships['human_display']['total_count'] - 4, 'relationship omitted count inconsistent'
assert relationships['summary']['relation_record_count'] == len(relationships['records']), 'relationship record count mismatch'
assert relationships['summary']['omitted_record_count'] == 0, 'relationship omitted record count changed'
assert relationships['providers'][0]['provider']['provenance']['local_only'] is True, 'relationship provider provenance is not local-only'
assert any(record['target_unresolved'] for record in relationships['records']), 'relationship unresolved target missing'
assert all(record['provider']['input'].startswith('working-tree:') for record in relationships['records']), 'relationship provider input lost bounded local identity'
assert all(record['evidence_basis'] and record['caveats'] for record in relationships['records']), 'relationship record lost basis or caveats'

for path in (basic_path, self_path, self_scoped_path, scope_filtered_path, scope_project_path, scope_project_duplicate_path, scope_project_include_flow_path, scope_project_include_src_path, scope_src_filtered_path, scope_weird_filtered_path, scope_empty_path, symbol_relationships_path):
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
  python3 - "$BASIC_MD_A" "$BASIC_MD_B" "$BASIC_INSPECT_MD" "$SCOPE_FILTERED_MD" "$SCOPE_FILTERED_MD_B" "$SCOPE_PROJECT_MD" "$SCOPE_PROJECT_MD_B" "$SCOPE_EMPTY_MD" "$EDGE_MD" "$EDGE_INSPECT_MD" "$SELF_MARKDOWN" "$SELF_SCOPED_MARKDOWN" "$SCOPE_SRC_INCLUDE_MD" "$SCOPE_INCLUDE_EMPTY_MD" "$SYMBOLS_MD" "$SYMBOLS_LIMIT_MD" "$PY_SYMBOLS_MD" "$PY_SYMBOLS_LIMIT_MD" "$PY_SYMBOLS_MARKDOWN_PATH_MD" "$SYMBOL_RELATIONSHIPS_MD" <<'PY'
import os, re, sys
from pathlib import Path

basic_a, basic_b, basic_inspect, scope_filtered, scope_filtered_b, scope_project, scope_project_b, scope_empty, edge, edge_inspect, self_md, self_scoped, scope_src_include_md, scope_include_empty_md, symbols_md, symbols_limit_md, py_symbols_md, py_symbols_limit_md, py_symbols_markdown_path_md, symbol_relationships_md = [Path(p) for p in sys.argv[1:]]

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

symbols_text = read(symbols_md)
symbols_limit_text = read(symbols_limit_md)
assert '- Total symbols: 2' in symbols_text, 'symbol markdown total missing'
assert '- Total symbols: 2' in symbols_limit_text, 'limited symbol markdown total missing'
assert '- Shown symbols: 1' in symbols_limit_text, 'limited symbol markdown shown count missing'
assert '- Omitted symbols: 1' in symbols_limit_text, 'limited symbol markdown omitted count missing'
assert 'zebra' not in symbols_limit_text, 'omitted symbol leaked into limited markdown'
py_symbols_text = read(py_symbols_md)
py_symbols_limit_text = read(py_symbols_limit_md)
py_symbols_path_text = read(py_symbols_markdown_path_md)
assert r'- Provider: tree\-sitter\-python' in py_symbols_text, 'Python provider markdown missing'
assert '- Total symbols: 11' in py_symbols_text, 'Python symbol markdown total missing'
assert 'café' in py_symbols_text, 'Unicode Python symbol missing from markdown'
assert '- Total symbols: 11' in py_symbols_limit_text, 'limited Python symbol markdown total missing'
assert '- Shown symbols: 3' in py_symbols_limit_text, 'limited Python symbol markdown shown count missing'
assert '- Omitted symbols: 8' in py_symbols_limit_text, 'limited Python symbol markdown omitted count missing'
assert r'top\_function' not in py_symbols_limit_text, 'omitted Python symbol leaked into limited markdown'
assert r'markdown\|path.py' in py_symbols_path_text, 'Markdown-sensitive Python path not escaped'
relationship_text = read(symbol_relationships_md)
assert '## Symbol relationships' in relationship_text, 'relationship markdown section missing'
assert '- Shown records: 4' in relationship_text, 'relationship markdown shown count missing'
assert '- Omitted records: 16' in relationship_text, 'relationship markdown omitted count missing'
assert 'Unresolved target' in relationship_text, 'relationship markdown unresolved column missing'
assert 'call-graph truth' in relationship_text, 'relationship markdown caveat language missing'
assert r'working\-tree:src/example.py' in relationship_text, 'relationship markdown provider input missing'

for text in [basic, basic_inspect_text, scope, project, empty, edge_text, edge_inspect_text, read(self_md), self_scoped_text, include_text, include_empty, symbols_text, symbols_limit_text, py_symbols_text, py_symbols_limit_text, py_symbols_path_text, relationship_text]:
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
  grep -q -- '--symbol-line-history' "$help_out" || return 1
  grep -q -- '--historical-symbols' "$help_out" || return 1
  grep -q -- '--symbol-relationships' "$help_out" || return 1
  grep -q -- '--symbol-limit N' "$help_out" || return 1
  grep -q -- '-h, --help' "$help_out" || return 1
  grep -q -- 'Examples:' "$help_out" || return 1
  grep -q -- 'Local-first/no-telemetry boundaries:' "$help_out" || return 1
  grep -q -- 'Hotspots are investigation prompts' "$help_out" || return 1
  grep -q -- 'Provider capability:' "$help_out" || return 1
  grep -q -- 'current working-tree symbol evidence' "$help_out" || return 1
  grep -q -- 'no Cargo, crates, module' "$help_out" || return 1
  grep -q -- 'macro expansion, cfg/feature evaluation, type checking' "$help_out" || return 1
  grep -q -- 'dependency graphs, or semantic Rust analysis' "$help_out" || return 1
  grep -q -- 'not true symbol history' "$help_out" || return 1
  "$EXE" -h > "$ARTIFACT_DIR/help-short.txt" 2> "$explain_err" || return 1
  [ ! -s "$explain_err" ] || return 1
  diff -u "$help_out" "$ARTIFACT_DIR/help-short.txt" >/dev/null || return 1
  "$EXE" --progress --help > "$ARTIFACT_DIR/help-progress.txt" 2> "$explain_err" || return 1
  [ ! -s "$explain_err" ] || return 1
  grep -q -- '--progress' "$ARTIFACT_DIR/help-progress.txt" || return 1
  "$EXE" --symbols --help > "$ARTIFACT_DIR/help-symbols.txt" 2> "$explain_err" || return 1
  [ ! -s "$explain_err" ] || return 1
  diff -u "$help_out" "$ARTIFACT_DIR/help-symbols.txt" >/dev/null || return 1
  "$EXE" --historical-symbols --help > "$ARTIFACT_DIR/help-historical-symbols.txt" 2> "$explain_err" || return 1
  [ ! -s "$explain_err" ] || return 1
  diff -u "$help_out" "$ARTIFACT_DIR/help-historical-symbols.txt" >/dev/null || return 1
  "$EXE" --symbol-relationships --help > "$ARTIFACT_DIR/help-symbol-relationships.txt" 2> "$explain_err" || return 1
  [ ! -s "$explain_err" ] || return 1
  diff -u "$help_out" "$ARTIFACT_DIR/help-symbol-relationships.txt" >/dev/null || return 1
  "$EXE" --repo --help > "$ARTIFACT_DIR/help-repo.txt" 2> "$explain_err" || return 1
  [ ! -s "$explain_err" ] || return 1
  diff -u "$help_out" "$ARTIFACT_DIR/help-repo.txt" >/dev/null || return 1
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
  (cd "$nongit" && "$EXE_ABS" -h > "$ARTIFACT_DIR/help-nongit.txt" 2> "$explain_err") || return 1
  [ ! -s "$explain_err" ] || return 1
  diff -u "$help_out" "$ARTIFACT_DIR/help-nongit.txt" >/dev/null || return 1

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
    '--symbols' \
    '--historical-symbols' \
    '--symbol-relationships'
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
    '--symbols' \
    '--historical-symbols' \
    '--symbol-relationships'
  do
    # shellcheck disable=SC2086
    if "$EXE" --version $args > "$ARTIFACT_DIR/version-invalid.out" 2> "$explain_err"; then
      return 1
    fi
    grep -q -- '--version cannot be combined' "$explain_err" || return 1
  done
}

cli_misuse_matrix_checks() {
  assert_cli_error() {
    label=$1
    pattern=$2
    shift 2
    out=$ARTIFACT_DIR/cli-misuse-$label.out
    err=$ARTIFACT_DIR/cli-misuse-$label.err
    if "$EXE" "$@" > "$out" 2> "$err"; then
      return 1
    fi
    grep -q -- '^error:' "$err" || return 1
    grep -q -- "$pattern" "$err" || return 1
    ! grep -q -- '^Usage:' "$err" || return 1
  }

  assert_cli_help() {
    label=$1
    shift
    out=$ARTIFACT_DIR/cli-help-$label.out
    err=$ARTIFACT_DIR/cli-help-$label.err
    "$EXE" "$@" > "$out" 2> "$err" || return 1
    [ ! -s "$err" ] || return 1
    grep -q -- 'git-hotspots: deterministic local Git-history hotspot prompts' "$out" || return 1
  }

  assert_cli_error symbol-line-history-alone '--symbol-line-history requires --symbols' --symbol-line-history || return 1
  assert_cli_error symbol-line-history-inspect-no-symbols '--symbol-line-history requires --symbols' --inspect src/app.zig --symbol-line-history || return 1
  assert_cli_error historical-symbols-alone '--historical-symbols requires --symbols' --historical-symbols || return 1
  assert_cli_error historical-symbols-inspect-no-symbols '--historical-symbols requires --symbols' --inspect src/app.zig --historical-symbols || return 1
  assert_cli_error symbol-relationships-alone '--symbol-relationships requires --symbols' --symbol-relationships || return 1
  assert_cli_error symbol-relationships-inspect-no-symbols '--symbol-relationships requires --symbols' --inspect src/app.zig --symbol-relationships || return 1
  assert_cli_error symbol-limit-alone '--symbol-limit requires --symbols' --symbol-limit 1 || return 1
  assert_cli_error symbol-limit-inspect-no-symbols '--symbol-limit requires --symbols' --inspect src/app.zig --symbol-limit 1 || return 1
  assert_cli_error symbol-limit-missing '--symbol-limit must be a positive integer' --inspect src/app.zig --symbols --symbol-limit || return 1
  assert_cli_error symbol-limit-zero '--symbol-limit must be a positive integer' --inspect src/app.zig --symbols --symbol-limit 0 || return 1
  assert_cli_error symbol-limit-invalid '--symbol-limit must be a positive integer' --inspect src/app.zig --symbols --symbol-limit nope || return 1
  assert_cli_error inspect-limit '--limit cannot be combined with --inspect' --repo fixtures/basic --inspect src/app.txt --limit 1 || return 1

  assert_cli_error repo-missing '--repo requires a local Git worktree path' --repo || return 1
  assert_cli_error limit-missing '--limit requires a positive integer value' --limit || return 1
  assert_cli_error limit-invalid '--limit must be a positive integer' --limit nope || return 1
  assert_cli_error format-missing '--format requires a value' --format || return 1
  assert_cli_error format-invalid '--format accepts one value' --format xml || return 1
  assert_cli_error since-missing '--since requires a Git revision' --since || return 1
  assert_cli_error include-missing '--include-prefix requires a repo-relative path prefix' --include-prefix || return 1
  assert_cli_error exclude-missing '--exclude-prefix requires a repo-relative path prefix' --exclude-prefix || return 1
  assert_cli_error inspect-missing '--inspect requires an exact repo-relative Git path' --inspect || return 1
  assert_cli_error scope-missing '--scope accepts one lowercase value' --scope || return 1
  assert_cli_error scope-invalid '--scope accepts one lowercase value' --scope unknown || return 1
  assert_cli_error unknown-flag 'unknown option' --wat || return 1
  assert_cli_error unexpected-positional 'unexpected positional argument' fixtures/basic || return 1

  assert_cli_error explain-symbols '--explain cannot be combined' --explain --symbols || return 1
  assert_cli_error symbols-explain '--explain cannot be combined' --symbols --explain || return 1
  assert_cli_error historical-symbols-explain '--explain cannot be combined' --historical-symbols --explain || return 1
  assert_cli_error symbol-relationships-explain '--explain cannot be combined' --symbol-relationships --explain || return 1
  assert_cli_error version-symbols '--version cannot be combined' --version --symbols || return 1
  assert_cli_error symbols-version '--version cannot be combined' --symbols --version || return 1
  assert_cli_error historical-symbols-version '--version cannot be combined' --historical-symbols --version || return 1
  assert_cli_error symbol-relationships-version '--version cannot be combined' --symbol-relationships --version || return 1

  assert_cli_help help-symbols --help --symbols || return 1
  assert_cli_help symbols-help --symbols --help || return 1
  assert_cli_help historical-symbols-help --historical-symbols --help || return 1
  assert_cli_help symbol-relationships-help --symbol-relationships --help || return 1
  assert_cli_help repo-help --repo --help || return 1

  zig_run_out=$ARTIFACT_DIR/cli-zig-run-symbol-line-history.out
  zig_run_err=$ARTIFACT_DIR/cli-zig-run-symbol-line-history.err
  zig_run_output=$(zig build run -- --symbol-line-history 2>&1 > "$zig_run_out")
  zig_run_status=$?
  printf '%s\n' "$zig_run_output" > "$zig_run_err"
  if [ "$zig_run_status" -eq 0 ]; then
    return 1
  fi
  grep -q -- '^error: --symbol-line-history requires --symbols' "$zig_run_err" || return 1
}

capability_matrix_checks() {
  have_python || return 1

  matrix_help=$ARTIFACT_DIR/capability-help.txt
  matrix_explain=$ARTIFACT_DIR/capability-explain.txt
  matrix_err=$ARTIFACT_DIR/capability.err
  matrix_zig=$ARTIFACT_DIR/capability-zig.json
  matrix_go=$ARTIFACT_DIR/capability-go.json
  matrix_python=$ARTIFACT_DIR/capability-python.json
  matrix_javascript=$ARTIFACT_DIR/capability-javascript.json
  matrix_lua=$ARTIFACT_DIR/capability-lua.json
  matrix_rust=$ARTIFACT_DIR/capability-rust.json
  matrix_typescript=$ARTIFACT_DIR/capability-typescript.json
  matrix_tsx=$ARTIFACT_DIR/capability-tsx.json
  matrix_unsupported=$ARTIFACT_DIR/capability-unsupported.json

  "$EXE" --help > "$matrix_help" 2> "$matrix_err" || return 1
  [ ! -s "$matrix_err" ] || return 1
  "$EXE" --explain > "$matrix_explain" 2> "$matrix_err" || return 1
  [ ! -s "$matrix_err" ] || return 1
  "$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-line-history --format json > "$matrix_zig" || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format json > "$matrix_go" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format json > "$matrix_python" || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-line-history --format json > "$matrix_javascript" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format json > "$matrix_lua" || return 1
  "$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --symbol-line-history --format json > "$matrix_rust" || return 1
  "$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-line-history --format json > "$matrix_typescript" || return 1
  "$EXE" --repo fixtures/typescript-symbols --inspect src/component.tsx --symbols --symbol-line-history --format json > "$matrix_tsx" || return 1
  "$EXE" --repo fixtures/symbols --inspect src/readme.txt --symbols --format json > "$matrix_unsupported" || return 1

  python3 - README.md "$matrix_explain" "$matrix_help" "$matrix_zig" "$matrix_go" "$matrix_python" "$matrix_javascript" "$matrix_lua" "$matrix_rust" "$matrix_typescript" "$matrix_tsx" "$matrix_unsupported" <<'PY'
import json
import sys
from pathlib import Path

readme = Path(sys.argv[1]).read_text(encoding='utf-8')
explain = Path(sys.argv[2]).read_text(encoding='utf-8')
help_text = Path(sys.argv[3]).read_text(encoding='utf-8')
zig, go, python, javascript, lua, rust, typescript, tsx, unsupported = [json.load(open(path, encoding='utf-8')) for path in sys.argv[4:]]

readme_rows = [
    '| Zig | `.zig` | `tree-sitter-zig` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no dependencies, semantic moves, true symbol history, scoring, or ownership claims |',
    '| Go | `.go` | `tree-sitter-go` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no packages, build tags, cgo, dependency graphs, true symbol history, scoring, or ownership claims |',
    '| Python | `.py` | `tree-sitter-python` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no imports, packages, virtual environments, dependency graphs, generated-source policy, true symbol history, scoring, or ownership claims |',
    '| JavaScript | `.js`, `.mjs`, `.cjs`, admitted `.jsx` | `tree-sitter-javascript` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no Node, packages, workspaces, module resolution, TypeScript, TSX, dependency graphs, true symbol history, scoring, or ownership claims |',
    '| Lua | `.lua` | `tree-sitter-lua` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no package, require, runtime module resolution, metatables, dynamic table keys, dependency graphs, runtime execution, true symbol history, scoring, or ownership claims |',
    '| Rust | `.rs` | `tree-sitter-rust` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no Cargo, crates, module resolution, macro expansion output, cfg feature selection, type checking, dependency graphs, true symbol history, scoring, or ownership claims |',
    '| TypeScript | `.ts`, `.mts`, `.cts` | `tree-sitter-typescript` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no packages, workspaces, tsconfig, module resolution, type checking, dependency graphs, cache, true symbol history, scoring, or ownership claims |',
    '| TSX | `.tsx` | `tree-sitter-tsx` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no React, DOM, packages, type analysis, dependency graphs, cache, true symbol history, scoring, or ownership claims |',
    '| Unsupported current files | all other paths | unsupported fallback | provider reports `unsupported` and keeps inspected file evidence | no current-line evidence | no parser diagnostics, source snippets, or parsed symbols |',
]
for row in readme_rows:
    assert row in readme, f'README capability row missing: {row}'

explain_rows = [row.replace('`', '') for row in readme_rows]
for row in explain_rows:
    assert row in explain, f'explain capability row missing: {row}'

for text, label in ((readme, 'README'), (explain, 'explain')):
    assert 'Provider capability matrix' in text, f'{label} matrix heading missing'
    assert 'current-line Git evidence for HEAD line ranges' in text, f'{label} current-line basis missing'
    assert 'not true symbol history' in text, f'{label} true history boundary missing'

for needle in (
    'Provider capability:',
    'current working-tree symbol evidence',
    'Other ranked current files are counted as unsupported while preserving file evidence.',
    'not true symbol history, lineage, scoring, or ownership',
):
    assert needle in help_text, f'help capability text missing: {needle}'

cases = [
    ('Zig', zig, 'tree-sitter-zig', 'src/example.zig'),
    ('Go', go, 'tree-sitter-go', 'src/example.go'),
    ('Python', python, 'tree-sitter-python', 'src/example.py'),
    ('JavaScript', javascript, 'tree-sitter-javascript', 'src/example.mjs'),
    ('Lua', lua, 'tree-sitter-lua', 'src/example.lua'),
    ('Rust', rust, 'tree-sitter-rust', 'src/example.rs'),
    ('TypeScript', typescript, 'tree-sitter-typescript', 'src/example.ts'),
    ('TSX', tsx, 'tree-sitter-tsx', 'src/component.tsx'),
]
for label, data, provider_name, matched_path in cases:
    symbols = data['symbols']
    provider = symbols['provider']
    assert data['inspect']['matched_path'] == matched_path, f'{label} inspect path changed'
    assert symbols['current_only'] is True, f'{label} symbols are not current-only'
    assert provider['name'] == provider_name, f'{label} provider name changed'
    assert provider['failure'] == 'ok', f'{label} provider failure changed'
    assert provider['provenance']['local_only'] is True, f'{label} local provenance missing'
    assert symbols['items'], f'{label} symbol list unexpectedly empty'
    assert all(row['path'] == matched_path for row in symbols['items']), f'{label} leaked non-inspected file symbols'
    assert all('current_line_history' in row for row in symbols['items']), f'{label} current-line evidence missing'
    for row in symbols['items']:
        history = row['current_line_history']
        assert history['basis'] == 'current-line-range-at-head', f'{label} line-history basis changed'
        assert history['current_only'] is True, f'{label} line-history current_only changed'

unsupported_symbols = unsupported['symbols']
assert unsupported['results'], 'unsupported inspect lost file evidence'
assert unsupported_symbols['current_only'] is True, 'unsupported symbols current_only missing'
assert unsupported_symbols['provider']['failure'] == 'unsupported', 'unsupported provider failure changed'
assert unsupported_symbols['items'] == [], 'unsupported language emitted symbol items'
assert 'current_line_history' not in json.dumps(unsupported, ensure_ascii=False), 'unsupported language emitted line history'
PY
}

prohibited_claim_scan() {
  have_python || return 1
  python3 - fixtures/expected/explain.txt fixtures/expected/symbols-inspect-symbols.json fixtures/expected/symbols-inspect-symbols.md fixtures/expected/symbols-inspect-symbols.txt fixtures/expected/symbols-limit.md fixtures/expected/symbols-limit.txt fixtures/expected/symbols-unsupported.json fixtures/expected/symbols-symlink-unavailable.json fixtures/expected/go-symbols.json fixtures/expected/go-symbols.md fixtures/expected/go-symbols.txt fixtures/expected/go-symbols-limit.json fixtures/expected/go-symbols-limit.md fixtures/expected/go-symbols-limit.txt fixtures/expected/go-symbols-empty.json fixtures/expected/go-symbols-invalid.json fixtures/expected/go-symbols-caveated.json fixtures/expected/go-symbols-symlink-unavailable.json fixtures/expected/go-symbols-large-unavailable.json fixtures/expected/go-symbols-missing-unavailable.json fixtures/expected/go-symbols-rename-alias.json fixtures/expected/python-symbols.json fixtures/expected/python-symbols.md fixtures/expected/python-symbols.txt fixtures/expected/python-symbols-limit.json fixtures/expected/python-symbols-limit.md fixtures/expected/python-symbols-limit.txt fixtures/expected/python-symbols-empty.json fixtures/expected/python-symbols-invalid.json fixtures/expected/python-symbols-generated.json fixtures/expected/python-symbols-symlink-unavailable.json fixtures/expected/python-symbols-large-unavailable.json fixtures/expected/python-symbols-missing-unavailable.json fixtures/expected/python-symbols-rename-alias.json fixtures/expected/rust-symbols.json fixtures/expected/rust-symbols.md fixtures/expected/rust-symbols.txt fixtures/expected/rust-symbols-limit.json fixtures/expected/rust-symbols-limit.md fixtures/expected/rust-symbols-limit.txt fixtures/expected/rust-symbols-unsupported.json fixtures/expected/rust-symbols-empty.json fixtures/expected/rust-symbols-invalid.json fixtures/expected/rust-symbols-generated.json fixtures/expected/rust-symbols-macro-cfg.json fixtures/expected/rust-symbols-symlink-unavailable.json fixtures/expected/rust-symbols-large-unavailable.json fixtures/expected/rust-symbols-missing-unavailable.json fixtures/expected/rust-symbols-rename-alias.json fixtures/expected/line-history-success.json fixtures/expected/line-history-success.md fixtures/expected/line-history-success.txt fixtures/expected/go-line-history-success.json fixtures/expected/go-line-history-success.md fixtures/expected/go-line-history-success.txt fixtures/expected/python-line-history-success.json fixtures/expected/python-line-history-success.md fixtures/expected/python-line-history-success.txt fixtures/expected/javascript-line-history-success.json fixtures/expected/javascript-line-history-success.md fixtures/expected/javascript-line-history-success.txt fixtures/expected/lua-line-history-success.json fixtures/expected/lua-line-history-success.md fixtures/expected/lua-line-history-success.txt README.md CONTRIBUTING.md docs/user-guide.md docs/developer-guide.md man/git-hotspots.1 <<'PY'
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
    re.compile(r'\bauthor ranking\b'),
    re.compile(r'\bcode[- ]quality scoring\b'),
    re.compile(r'\brisk prediction\b'),
    re.compile(r'\btrue (symbol )?history\b'),
    re.compile(r'\b(module|package|type|dependency) (meaning|understanding|analysis)\b'),
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
    'out of scope',
    'avoid ',
    'should not ',
    'does not ',
    'do not ',
    'never ',
    'non-claims',
    'limitations',
)

failures = []
line_history_public_paths = [
    Path('README.md'),
    Path('fixtures/expected/explain.txt'),
]
line_history_public_paths.extend(sorted(Path('fixtures/expected').glob('*line-history*.*')))
for extra_public_path in (Path('docs/user-guide.md'), Path('docs/developer-guide.md'), Path('man/git-hotspots.1')):
    if extra_public_path.exists():
        line_history_public_paths.append(extra_public_path)
src_explain_path = Path('src/explain.zig')
src_explain_public_lines = [
    (line_no, line)
    for line_no, line in enumerate(src_explain_path.read_text(encoding='utf-8').splitlines(), 1)
    if line.lstrip().startswith('\\\\')
]
for path in line_history_public_paths:
    if not path.exists():
        failures.append(f'{path}: missing from line-history public wording scan')
        continue
    for line_no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        if re.search(r'\bblame\b', line, re.IGNORECASE):
            failures.append(f'{path}:{line_no}: public current-line wording must not say blame: {line}')
for line_no, line in src_explain_public_lines:
    if re.search(r'\bblame\b', line, re.IGNORECASE):
        failures.append(f'src/explain.zig:{line_no}: public current-line wording must not say blame: {line}')

git_source = Path('src/git.zig').read_text(encoding='utf-8')
for match in re.finditer(r'"([^"]*current-line Git evidence[^"]*)"', git_source):
    if re.search(r'\bblame\b', match.group(1), re.IGNORECASE):
        failures.append(f'src/git.zig: public caveat must not say blame: {match.group(1)}')

claim_scan_paths = list(dict.fromkeys([Path(path_name) for path_name in sys.argv[1:]] + line_history_public_paths))
for path in claim_scan_paths:
    lines = path.read_text(encoding='utf-8').splitlines()
    for line_no, line in enumerate(lines, 1):
        context = ' '.join(lines[max(0, line_no - 3):line_no])
        normalized = f' {context.strip().lower()} '
        if any(pattern.search(line) for pattern in patterns):
            if not any(marker in normalized for marker in allowed_markers):
                failures.append(f'{path}:{line_no}: {line}')
for i, (line_no, line) in enumerate(src_explain_public_lines):
    context = ' '.join(text for _, text in src_explain_public_lines[max(0, i - 2):i + 1])
    normalized = f' {context.strip().lower()} '
    if any(pattern.search(line) for pattern in patterns):
        if not any(marker in normalized for marker in allowed_markers):
            failures.append(f'src/explain.zig:{line_no}: {line}')

if failures:
    raise SystemExit('positive prohibited claim(s):\n' + '\n'.join(failures))
PY
}

docs_manual_checks() {
  [ -f docs/user-guide.md ] || return 1
  [ -f docs/developer-guide.md ] || return 1
  [ -f man/git-hotspots.1 ] || return 1

  grep -Fq '# git-hotspots user guide' docs/user-guide.md || return 1
  grep -Fq -- '--help' docs/user-guide.md || return 1
  grep -Fq -- '--explain' docs/user-guide.md || return 1
  grep -Fq -- '--inspect' docs/user-guide.md || return 1
  grep -Fq -- '--symbols' docs/user-guide.md || return 1
  grep -Fq -- '--symbol-line-history' docs/user-guide.md || return 1
  grep -Fq -- '--historical-symbols' docs/user-guide.md || return 1
  grep -Fq -- '--symbol-relationships' docs/user-guide.md || return 1
  grep -Fq 'Python, JavaScript,' docs/user-guide.md || return 1
  grep -Fq 'TypeScript, and TSX Tree-sitter lanes' docs/user-guide.md || return 1
  grep -Fq 'Rust support is syntax-only' docs/user-guide.md || return 1
  grep -Fq 'Cargo metadata, crates, module resolution' docs/user-guide.md || return 1
  grep -Fq -- '--scope all' docs/user-guide.md || return 1
  grep -Fq -- '--include-prefix' docs/user-guide.md || return 1
  grep -Fq -- '--exclude-prefix' docs/user-guide.md || return 1
  grep -Fq 'zig build validate' docs/user-guide.md || return 1
  grep -Fq 'tools/release-linux.sh' docs/user-guide.md || return 1
  grep -Fq 'unpublished use' docs/user-guide.md || return 1
  grep -Fq 'error: --symbol-line-history requires --symbols' docs/user-guide.md || return 1
  grep -Fq 'error: --historical-symbols requires --symbols' docs/user-guide.md || return 1
  grep -Fq 'error: --symbol-relationships requires --symbols' docs/user-guide.md || return 1
  grep -Fq 'local-first' docs/user-guide.md || return 1
  grep -Fq 'telemetry' docs/user-guide.md || return 1

  grep -Fq '# git-hotspots developer guide' docs/developer-guide.md || return 1
  grep -Fq 'src/cli.zig' docs/developer-guide.md || return 1
  grep -Fq 'tools/validate.sh' docs/developer-guide.md || return 1
  grep -Fq 'CLI misuse matrix' docs/developer-guide.md || return 1
  grep -Fq 'zig build validate-all' docs/developer-guide.md || return 1
  grep -Fq 'tools/release-linux.sh' docs/developer-guide.md || return 1
  grep -Fq 'packaging/aur/git-hotspots-bin/' docs/developer-guide.md || return 1
  grep -Fq 'prohibited-claim' docs/developer-guide.md || return 1
  grep -Fq 'Local-first' docs/developer-guide.md || return 1

  grep -Fq '.SH NAME' man/git-hotspots.1 || return 1
  grep -Fq '.SH SYNOPSIS' man/git-hotspots.1 || return 1
  grep -Fq '.SH DESCRIPTION' man/git-hotspots.1 || return 1
  grep -Fq '.SH OPTIONS' man/git-hotspots.1 || return 1
  grep -Fq '.SH EXAMPLES' man/git-hotspots.1 || return 1
  grep -Fq '.SH REPORT SEMANTICS' man/git-hotspots.1 || return 1
  grep -Fq '.SH PRIVACY AND LOCAL-FIRST CAVEATS' man/git-hotspots.1 || return 1
  grep -Fq '.SH PROVIDER BOUNDARIES' man/git-hotspots.1 || return 1
  grep -Fq '.SH DIAGNOSTICS' man/git-hotspots.1 || return 1
  grep -Fq '.SH EXIT STATUS' man/git-hotspots.1 || return 1
  grep -Fq '.SH RELATED DOCUMENTS' man/git-hotspots.1 || return 1
  grep -Fq -- '--help' man/git-hotspots.1 || return 1
  grep -Fq -- '--explain' man/git-hotspots.1 || return 1
  grep -Fq -- '--inspect' man/git-hotspots.1 || return 1
  grep -Fq -- '--symbols' man/git-hotspots.1 || return 1
  grep -Fq -- '--historical-symbols' man/git-hotspots.1 || return 1
  grep -Fq -- '--symbol-relationships' man/git-hotspots.1 || return 1
  grep -Fq 'Python, JavaScript, Rust, TypeScript, and TSX lanes' man/git-hotspots.1 || return 1
  grep -Fq -- '--progress' man/git-hotspots.1 || return 1
  grep -Fq 'local-first' man/git-hotspots.1 || return 1
  ! grep -Eq 'dogfood|tools/release-linux\.sh|packaging/aur|makepkg|pacman|pkg\.tar' man/git-hotspots.1 || return 1

  grep -Fq 'docs/user-guide.md' README.md || return 1
  grep -Fq 'Python, JavaScript, Rust, TypeScript, and' README.md || return 1
  grep -Fq 'retained ranked-file candidates in Python' README.md || return 1
  grep -Fq 'Invalid CLI combinations exit 2' README.md || return 1
  grep -Fq 'Local Linux dogfood packaging' README.md || return 1
  grep -Fq 'tools/release-linux.sh' README.md || return 1
  grep -Fq 'man/git-hotspots.1' README.md || return 1
  grep -Fq 'docs/developer-guide.md' README.md || return 1
  grep -Fq 'docs/developer-guide.md' CONTRIBUTING.md || return 1

  have_python || return 1
  python3 - docs/user-guide.md docs/developer-guide.md man/git-hotspots.1 <<'PY'
import os
import re
import sys
from pathlib import Path

failures = []
home = os.path.expanduser('~')
for path_name in sys.argv[1:]:
    path = Path(path_name)
    text = path.read_text(encoding='utf-8')
    if home and home in text:
        failures.append(f'{path}: home path leaked')
    for needle in ('/home/', '/Users/', 'file://', 'https://', 'http://', 'ssh://', 'git@'):
        if needle in text:
            failures.append(f'{path}: private path or remote marker leaked: {needle}')
    if re.search(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', text):
        failures.append(f'{path}: email-like identity leaked')

if failures:
    raise SystemExit('\n'.join(failures))
PY
}

packaging_surface_checks() {
  [ -x tools/release-linux.sh ] || return 1
  [ -f packaging/aur/git-hotspots-bin/PKGBUILD ] || return 1
  [ -f packaging/aur/git-hotspots-bin/README.md ] || return 1
  [ -f docs/packaging-smoke-evidence.md ] || return 1
  grep -Fq '/dist/' .gitignore || return 1
  grep -Fq 'local Linux host required' tools/release-linux.sh || return 1
  grep -Fq 'ReleaseSafe' tools/release-linux.sh || return 1
  grep -Fq 'LICENSE' tools/release-linux.sh || return 1
  grep -Fq 'THIRDPARTYNOTICES.md' tools/release-linux.sh || return 1
  grep -Fq 'pkgname=git-hotspots-bin' packaging/aur/git-hotspots-bin/PKGBUILD || return 1
  grep -Fq 'source_x86_64' packaging/aur/git-hotspots-bin/PKGBUILD || return 1
  grep -Fq 'provides=(' packaging/aur/git-hotspots-bin/PKGBUILD || return 1
  grep -Fq 'makepkg --printsrcinfo' packaging/aur/git-hotspots-bin/README.md || return 1
  grep -Fq 'package-extracted binary smoke' docs/packaging-smoke-evidence.md || return 1
  grep -Fq 'unpublished' README.md docs/user-guide.md docs/developer-guide.md || return 1
  for path in README.md docs/user-guide.md docs/developer-guide.md tools/validate.sh; do
    grep -Fq 'packaged' "$path" || return 1
  done
  ! grep -Eq 'dogfood|tools/release-linux\.sh|packaging/aur|makepkg|pacman|pkg\.tar' man/git-hotspots.1 || return 1
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

runtime_dependency_scan() {
  have_python || return 1
  python3 - <<'PY'
import re
from pathlib import Path

files = [Path('build.zig')]
for root in ('src', 'tests', 'tools'):
    files.extend(Path(root).glob('**/*'))
files = [p for p in files if p.is_file() and p.suffix in {'.zig', '.sh'}]

forbidden = [
    ('network command', re.compile(r'\b(curl|wget|nc|netcat|ssh|scp|rsync)\b')),
    ('git network command', re.compile(r'\bgit\s+[^\n]*(fetch|pull|push|ls-remote)\b')),
    ('go toolchain command', re.compile(r'(^|[;&|`$()\s])go(fmt|\s+(test|list|env|build|run|version|mod|work)\b)')),
    ('global tree-sitter cli', re.compile(r'(^|[;&|`$()\s])tree-sitter\b')),
]

allowed = (
    'git clone -q --depth 1 "file://$FIX/basic"',
    'git clone -q "$FIX/basic"',
    'git clone -q --depth 1 "file://$FIX/symbol-line-history"',
    'git clone -q "$FIX/symbol-line-history"',
    'git clone -q --depth 1 "file://$FIX/go-symbols"',
    'git clone -q "$FIX/go-symbols"',
    'git clone -q --depth 1 "file://$FIX/python-symbols"',
    'git clone -q "$FIX/python-symbols"',
    'git clone -q --depth 1 "file://$FIX/javascript-symbols"',
    'git clone -q "$FIX/javascript-symbols"',
    'https?://|ssh://|git@',
    "for needle in ('/home/', '/Users/', 'file://', 'https://', 'http://', 'ssh://', 'git@'):",
    "('network command', re.compile",
    "('git network command', re.compile",
    "('go toolchain command', re.compile",
    "('global tree-sitter cli', re.compile",
    'current-line Git evidence for HEAD line ranges',
    'runtime dependency scan: python3 source scan',
)

failures = []
for path in files:
    text = path.read_text(encoding='utf-8')
    for line_no, line in enumerate(text.splitlines(), 1):
        if any(marker in line for marker in allowed):
            continue
        for label, pattern in forbidden:
            if pattern.search(line):
                failures.append(f'{path}:{line_no}: {label}: {line.strip()}')

if failures:
    raise SystemExit('\n'.join(failures))
PY
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
  "$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format json > "$SYMBOLS_LIMIT_JSON" || return 1
  "$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format markdown > "$SYMBOLS_LIMIT_MD" || return 1
  "$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format markdown > "$SYMBOLS_LIMIT_MD_B" || return 1
  diff -u fixtures/expected/symbols-limit.md "$SYMBOLS_LIMIT_MD" >/dev/null || return 1
  diff -u "$SYMBOLS_LIMIT_MD" "$SYMBOLS_LIMIT_MD_B" >/dev/null || return 1
  "$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format table > "$SYMBOLS_LIMIT_TABLE" || return 1
  "$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format table > "$SYMBOLS_LIMIT_TABLE_B" || return 1
  diff -u fixtures/expected/symbols-limit.txt "$SYMBOLS_LIMIT_TABLE" >/dev/null || return 1
  diff -u "$SYMBOLS_LIMIT_TABLE" "$SYMBOLS_LIMIT_TABLE_B" >/dev/null || return 1
  "$EXE" --repo fixtures/symbols --symbols --historical-symbols --symbol-limit 2 --format json > "$HISTORICAL_SYMBOLS_JSON" || return 1
  diff -u fixtures/expected/historical-symbols.json "$HISTORICAL_SYMBOLS_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/symbols --symbols --historical-symbols --symbol-limit 2 --format markdown > "$HISTORICAL_SYMBOLS_MD" || return 1
  diff -u fixtures/expected/historical-symbols.md "$HISTORICAL_SYMBOLS_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/symbols --symbols --historical-symbols --symbol-limit 2 --format table > "$HISTORICAL_SYMBOLS_TABLE" || return 1
  diff -u fixtures/expected/historical-symbols.txt "$HISTORICAL_SYMBOLS_TABLE" >/dev/null || return 1
  grep -q -- '"historical_symbols"' "$HISTORICAL_SYMBOLS_JSON" || return 1
  grep -q -- '## Historical symbols' "$HISTORICAL_SYMBOLS_MD" || return 1
  grep -q -- 'historical symbols for retained ranked files:' "$HISTORICAL_SYMBOLS_TABLE" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-relationships --symbol-limit 4 --format json > "$SYMBOL_RELATIONSHIPS_JSON" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-relationships --symbol-limit 4 --format json > "$SYMBOL_RELATIONSHIPS_JSON_B" || return 1
  diff -u fixtures/expected/symbol-relationships.json "$SYMBOL_RELATIONSHIPS_JSON" >/dev/null || return 1
  diff -u "$SYMBOL_RELATIONSHIPS_JSON" "$SYMBOL_RELATIONSHIPS_JSON_B" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-relationships --symbol-limit 4 --format markdown > "$SYMBOL_RELATIONSHIPS_MD" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-relationships --symbol-limit 4 --format markdown > "$SYMBOL_RELATIONSHIPS_MD_B" || return 1
  diff -u fixtures/expected/symbol-relationships.md "$SYMBOL_RELATIONSHIPS_MD" >/dev/null || return 1
  diff -u "$SYMBOL_RELATIONSHIPS_MD" "$SYMBOL_RELATIONSHIPS_MD_B" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-relationships --symbol-limit 4 --format table > "$SYMBOL_RELATIONSHIPS_TABLE" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-relationships --symbol-limit 4 --format table > "$SYMBOL_RELATIONSHIPS_TABLE_B" || return 1
  diff -u fixtures/expected/symbol-relationships.txt "$SYMBOL_RELATIONSHIPS_TABLE" >/dev/null || return 1
  diff -u "$SYMBOL_RELATIONSHIPS_TABLE" "$SYMBOL_RELATIONSHIPS_TABLE_B" >/dev/null || return 1
  grep -q -- '"symbol_relationships"' "$SYMBOL_RELATIONSHIPS_JSON" || return 1
  grep -q -- '## Symbol relationships' "$SYMBOL_RELATIONSHIPS_MD" || return 1
  grep -q -- 'symbol relationships for retained ranked files:' "$SYMBOL_RELATIONSHIPS_TABLE" || return 1
  ! grep -Eiq -- 'Fixture Author|fixture@example|https?://|ssh://|git@|/home/|/Users/|source snippet|commit message' "$SYMBOL_RELATIONSHIPS_JSON" "$SYMBOL_RELATIONSHIPS_MD" "$SYMBOL_RELATIONSHIPS_TABLE" || return 1
  for lane in javascript typescript tsx rust; do
    case "$lane" in
      javascript) repo=fixtures/javascript-symbols; inspect=src/example.mjs ;;
      typescript) repo=fixtures/typescript-symbols; inspect=src/example.ts ;;
      tsx) repo=fixtures/typescript-symbols; inspect=src/component.tsx ;;
      rust) repo=fixtures/rust-relationships; inspect=src/relations.rs ;;
    esac
    lane_json="$ARTIFACT_DIR/symbol-relationships-$lane.json"
    lane_json_b="$ARTIFACT_DIR/symbol-relationships-$lane-b.json"
    lane_md="$ARTIFACT_DIR/symbol-relationships-$lane.md"
    lane_md_b="$ARTIFACT_DIR/symbol-relationships-$lane-b.md"
    lane_table="$ARTIFACT_DIR/symbol-relationships-$lane.txt"
    lane_table_b="$ARTIFACT_DIR/symbol-relationships-$lane-b.txt"
    "$EXE" --repo "$repo" --inspect "$inspect" --symbols --symbol-relationships --symbol-limit 6 --format json > "$lane_json" || return 1
    "$EXE" --repo "$repo" --inspect "$inspect" --symbols --symbol-relationships --symbol-limit 6 --format json > "$lane_json_b" || return 1
    diff -u "fixtures/expected/symbol-relationships-$lane.json" "$lane_json" >/dev/null || return 1
    diff -u "$lane_json" "$lane_json_b" >/dev/null || return 1
    "$EXE" --repo "$repo" --inspect "$inspect" --symbols --symbol-relationships --symbol-limit 6 --format markdown > "$lane_md" || return 1
    "$EXE" --repo "$repo" --inspect "$inspect" --symbols --symbol-relationships --symbol-limit 6 --format markdown > "$lane_md_b" || return 1
    diff -u "fixtures/expected/symbol-relationships-$lane.md" "$lane_md" >/dev/null || return 1
    diff -u "$lane_md" "$lane_md_b" >/dev/null || return 1
    "$EXE" --repo "$repo" --inspect "$inspect" --symbols --symbol-relationships --symbol-limit 6 --format table > "$lane_table" || return 1
    "$EXE" --repo "$repo" --inspect "$inspect" --symbols --symbol-relationships --symbol-limit 6 --format table > "$lane_table_b" || return 1
    diff -u "fixtures/expected/symbol-relationships-$lane.txt" "$lane_table" >/dev/null || return 1
    diff -u "$lane_table" "$lane_table_b" >/dev/null || return 1
    grep -q -- '"symbol_relationships"' "$lane_json" || return 1
    grep -q -- '## Symbol relationships' "$lane_md" || return 1
    grep -q -- 'symbol relationships for retained ranked files:' "$lane_table" || return 1
    ! grep -Eiq -- 'Fixture Author|fixture@example|https?://|ssh://|git@|/home/|/Users/|source snippet|commit message' "$lane_json" "$lane_md" "$lane_table" || return 1
  done
  have_python || return 1
  python3 - "$ARTIFACT_DIR/symbol-relationships-javascript.json" "$ARTIFACT_DIR/symbol-relationships-typescript.json" "$ARTIFACT_DIR/symbol-relationships-tsx.json" "$ARTIFACT_DIR/symbol-relationships-rust.json" <<'PY' || return 1
import json, sys
cases = [
    (sys.argv[1], 'tree-sitter-javascript-relations', {'contains', 'reference', 'call', 'import_include', 'unresolved'}),
    (sys.argv[2], 'tree-sitter-typescript-relations', {'contains', 'call', 'unresolved', 'unknown'}),
    (sys.argv[3], 'tree-sitter-tsx-relations', {'contains', 'reference', 'unresolved', 'unknown'}),
    (sys.argv[4], 'tree-sitter-rust-relations', {'contains', 'reference', 'call', 'import_include', 'unresolved', 'unknown'}),
]
for path, provider_name, expected_kinds in cases:
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
    relationships = data['symbol_relationships']
    assert relationships['basis']['requires_symbols_flag'] is True
    assert relationships['basis']['scoring_effect'] == 'none'
    assert relationships['provenance']['local_only'] is True and relationships['provenance']['network'] is False
    assert relationships['providers'][0]['provider']['name'] == provider_name
    assert relationships['summary']['relation_record_count'] == len(relationships['records'])
    assert expected_kinds.issubset({item['kind'] for item in relationships['records']}), path
    assert any(item['target_unresolved'] for item in relationships['records']), path
    assert all(item['provider']['input'].startswith('working-tree:') for item in relationships['records'])
    assert 'call-graph truth' not in json.dumps(data)
PY
  "$EXE" --repo fixtures/symbols --inspect src/readme.txt --symbols --format json > "$SYMBOLS_UNSUPPORTED_JSON" || return 1
  diff -u fixtures/expected/symbols-unsupported.json "$SYMBOLS_UNSUPPORTED_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/symbols --inspect src/link.zig --symbols --format json > "$SYMBOLS_SYMLINK_JSON" || return 1
  diff -u fixtures/expected/symbols-symlink-unavailable.json "$SYMBOLS_SYMLINK_JSON" >/dev/null || return 1
  GO_SYMBOLS_JSON=$ARTIFACT_DIR/go-symbols.json
  GO_SYMBOLS_MD=$ARTIFACT_DIR/go-symbols.md
  GO_SYMBOLS_TABLE=$ARTIFACT_DIR/go-symbols.txt
  GO_SYMBOLS_LIMIT_JSON=$ARTIFACT_DIR/go-symbols-limit.json
  GO_SYMBOLS_LIMIT_MD=$ARTIFACT_DIR/go-symbols-limit.md
  GO_SYMBOLS_LIMIT_TABLE=$ARTIFACT_DIR/go-symbols-limit.txt
  GO_SYMBOLS_EMPTY_JSON=$ARTIFACT_DIR/go-symbols-empty.json
  GO_SYMBOLS_INVALID_JSON=$ARTIFACT_DIR/go-symbols-invalid.json
  GO_SYMBOLS_CAVEATED_JSON=$ARTIFACT_DIR/go-symbols-caveated.json
  GO_SYMBOLS_SYMLINK_JSON=$ARTIFACT_DIR/go-symbols-symlink.json
  GO_SYMBOLS_LARGE_JSON=$ARTIFACT_DIR/go-symbols-large.json
  GO_SYMBOLS_MISSING_JSON=$ARTIFACT_DIR/go-symbols-missing.json
  GO_SYMBOLS_ALIAS_JSON=$ARTIFACT_DIR/go-symbols-alias.json
  GO_SYMBOLS_OTHER_JSON=$ARTIFACT_DIR/go-symbols-other.json
  GO_LINE_HISTORY_JSON=$ARTIFACT_DIR/go-line-history.json
  GO_LINE_HISTORY_JSON_B=$ARTIFACT_DIR/go-line-history-b.json
  GO_LINE_HISTORY_MD=$ARTIFACT_DIR/go-line-history.md
  GO_LINE_HISTORY_TABLE=$ARTIFACT_DIR/go-line-history.txt
  GO_LINE_HISTORY_SHALLOW_JSON=$ARTIFACT_DIR/go-line-history-shallow.json
  GO_LINE_HISTORY_PARTIAL_JSON=$ARTIFACT_DIR/go-line-history-partial.json
  "$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format json > "$GO_SYMBOLS_JSON" || return 1
  diff -u fixtures/expected/go-symbols.json "$GO_SYMBOLS_JSON" >/dev/null || return 1
  ! grep -Fq -- 'current_line_history' "$GO_SYMBOLS_JSON" || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format markdown > "$GO_SYMBOLS_MD" || return 1
  diff -u fixtures/expected/go-symbols.md "$GO_SYMBOLS_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format table > "$GO_SYMBOLS_TABLE" || return 1
  diff -u fixtures/expected/go-symbols.txt "$GO_SYMBOLS_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-limit 2 --format json > "$GO_SYMBOLS_LIMIT_JSON" || return 1
  diff -u fixtures/expected/go-symbols-limit.json "$GO_SYMBOLS_LIMIT_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-limit 2 --format markdown > "$GO_SYMBOLS_LIMIT_MD" || return 1
  diff -u fixtures/expected/go-symbols-limit.md "$GO_SYMBOLS_LIMIT_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-limit 2 --format table > "$GO_SYMBOLS_LIMIT_TABLE" || return 1
  diff -u fixtures/expected/go-symbols-limit.txt "$GO_SYMBOLS_LIMIT_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/empty.go --symbols --format json > "$GO_SYMBOLS_EMPTY_JSON" || return 1
  diff -u fixtures/expected/go-symbols-empty.json "$GO_SYMBOLS_EMPTY_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/broken.go --symbols --format json > "$GO_SYMBOLS_INVALID_JSON" || return 1
  diff -u fixtures/expected/go-symbols-invalid.json "$GO_SYMBOLS_INVALID_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/caveated.go --symbols --format json > "$GO_SYMBOLS_CAVEATED_JSON" || return 1
  diff -u fixtures/expected/go-symbols-caveated.json "$GO_SYMBOLS_CAVEATED_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/link.go --symbols --format json > "$GO_SYMBOLS_SYMLINK_JSON" || return 1
  diff -u fixtures/expected/go-symbols-symlink-unavailable.json "$GO_SYMBOLS_SYMLINK_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/large.go --symbols --format json > "$GO_SYMBOLS_LARGE_JSON" || return 1
  diff -u fixtures/expected/go-symbols-large-unavailable.json "$GO_SYMBOLS_LARGE_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/missing.go --symbols --format json > "$GO_SYMBOLS_MISSING_JSON" || return 1
  diff -u fixtures/expected/go-symbols-missing-unavailable.json "$GO_SYMBOLS_MISSING_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/old-example.go --symbols --format json > "$GO_SYMBOLS_ALIAS_JSON" || return 1
  diff -u fixtures/expected/go-symbols-rename-alias.json "$GO_SYMBOLS_ALIAS_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/other.go --symbols --format json > "$GO_SYMBOLS_OTHER_JSON" || return 1
  ! grep -Fq -- 'Zebra' "$GO_SYMBOLS_OTHER_JSON" || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format json > "$GO_LINE_HISTORY_JSON" || return 1
  diff -u fixtures/expected/go-line-history-success.json "$GO_LINE_HISTORY_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format json > "$GO_LINE_HISTORY_JSON_B" || return 1
  diff -u "$GO_LINE_HISTORY_JSON" "$GO_LINE_HISTORY_JSON_B" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format markdown > "$GO_LINE_HISTORY_MD" || return 1
  diff -u fixtures/expected/go-line-history-success.md "$GO_LINE_HISTORY_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format table > "$GO_LINE_HISTORY_TABLE" || return 1
  diff -u fixtures/expected/go-line-history-success.txt "$GO_LINE_HISTORY_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/go-symbols-shallow --inspect src/example.go --symbols --symbol-line-history --format json > "$GO_LINE_HISTORY_SHALLOW_JSON" || return 1
  grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$GO_LINE_HISTORY_SHALLOW_JSON" || return 1
  "$EXE" --repo fixtures/go-symbols-partial --inspect src/example.go --symbols --symbol-line-history --format json > "$GO_LINE_HISTORY_PARTIAL_JSON" || return 1
  grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$GO_LINE_HISTORY_PARTIAL_JSON" || return 1
  PY_SYMBOLS_JSON=$ARTIFACT_DIR/python-symbols.json
  PY_SYMBOLS_JSON_B=$ARTIFACT_DIR/python-symbols-b.json
  PY_SYMBOLS_MD=$ARTIFACT_DIR/python-symbols.md
  PY_SYMBOLS_TABLE=$ARTIFACT_DIR/python-symbols.txt
  PY_SYMBOLS_LIMIT_JSON=$ARTIFACT_DIR/python-symbols-limit.json
  PY_SYMBOLS_LIMIT_MD=$ARTIFACT_DIR/python-symbols-limit.md
  PY_SYMBOLS_LIMIT_TABLE=$ARTIFACT_DIR/python-symbols-limit.txt
  PY_SYMBOLS_EMPTY_JSON=$ARTIFACT_DIR/python-symbols-empty.json
  PY_SYMBOLS_INVALID_JSON=$ARTIFACT_DIR/python-symbols-invalid.json
  PY_SYMBOLS_GENERATED_JSON=$ARTIFACT_DIR/python-symbols-generated.json
  PY_SYMBOLS_SYMLINK_JSON=$ARTIFACT_DIR/python-symbols-symlink.json
  PY_SYMBOLS_LARGE_JSON=$ARTIFACT_DIR/python-symbols-large.json
  PY_SYMBOLS_MISSING_JSON=$ARTIFACT_DIR/python-symbols-missing.json
  PY_SYMBOLS_ALIAS_JSON=$ARTIFACT_DIR/python-symbols-alias.json
  PY_SYMBOLS_OTHER_JSON=$ARTIFACT_DIR/python-symbols-other.json
  PY_SYMBOLS_MARKDOWN_PATH_MD=$ARTIFACT_DIR/python-symbols-markdown-path.md
  PY_LINE_HISTORY_JSON=$ARTIFACT_DIR/python-line-history.json
  PY_LINE_HISTORY_JSON_B=$ARTIFACT_DIR/python-line-history-b.json
  PY_LINE_HISTORY_MD=$ARTIFACT_DIR/python-line-history.md
  PY_LINE_HISTORY_TABLE=$ARTIFACT_DIR/python-line-history.txt
  PY_LINE_HISTORY_SHALLOW_JSON=$ARTIFACT_DIR/python-line-history-shallow.json
  PY_LINE_HISTORY_PARTIAL_JSON=$ARTIFACT_DIR/python-line-history-partial.json
  PY_LINE_HISTORY_EMPTY_JSON=$ARTIFACT_DIR/python-line-history-empty.json
  PY_LINE_HISTORY_INVALID_JSON=$ARTIFACT_DIR/python-line-history-invalid.json
  PY_LINE_HISTORY_SYMLINK_JSON=$ARTIFACT_DIR/python-line-history-symlink.json
  PY_LINE_HISTORY_LARGE_JSON=$ARTIFACT_DIR/python-line-history-large.json
  PY_LINE_HISTORY_MISSING_JSON=$ARTIFACT_DIR/python-line-history-missing.json
  PY_LINE_HISTORY_DIRTY_JSON=$ARTIFACT_DIR/python-line-history-dirty.json
  PY_LINE_HISTORY_UNRELATED_JSON=$ARTIFACT_DIR/python-line-history-unrelated.json
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --format json > "$PY_SYMBOLS_JSON" || return 1
  diff -u fixtures/expected/python-symbols.json "$PY_SYMBOLS_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --format json > "$PY_SYMBOLS_JSON_B" || return 1
  diff -u "$PY_SYMBOLS_JSON" "$PY_SYMBOLS_JSON_B" >/dev/null || return 1
  ! grep -Fq -- 'current_line_history' "$PY_SYMBOLS_JSON" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --format markdown > "$PY_SYMBOLS_MD" || return 1
  diff -u fixtures/expected/python-symbols.md "$PY_SYMBOLS_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --format table > "$PY_SYMBOLS_TABLE" || return 1
  diff -u fixtures/expected/python-symbols.txt "$PY_SYMBOLS_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-limit 3 --format json > "$PY_SYMBOLS_LIMIT_JSON" || return 1
  diff -u fixtures/expected/python-symbols-limit.json "$PY_SYMBOLS_LIMIT_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-limit 3 --format markdown > "$PY_SYMBOLS_LIMIT_MD" || return 1
  diff -u fixtures/expected/python-symbols-limit.md "$PY_SYMBOLS_LIMIT_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-limit 3 --format table > "$PY_SYMBOLS_LIMIT_TABLE" || return 1
  diff -u fixtures/expected/python-symbols-limit.txt "$PY_SYMBOLS_LIMIT_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/empty.py --symbols --format json > "$PY_SYMBOLS_EMPTY_JSON" || return 1
  diff -u fixtures/expected/python-symbols-empty.json "$PY_SYMBOLS_EMPTY_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/invalid_partial.py --symbols --format json > "$PY_SYMBOLS_INVALID_JSON" || return 1
  diff -u fixtures/expected/python-symbols-invalid.json "$PY_SYMBOLS_INVALID_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/generated.py --symbols --format json > "$PY_SYMBOLS_GENERATED_JSON" || return 1
  diff -u fixtures/expected/python-symbols-generated.json "$PY_SYMBOLS_GENERATED_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/link.py --symbols --format json > "$PY_SYMBOLS_SYMLINK_JSON" || return 1
  diff -u fixtures/expected/python-symbols-symlink-unavailable.json "$PY_SYMBOLS_SYMLINK_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/large.py --symbols --format json > "$PY_SYMBOLS_LARGE_JSON" || return 1
  diff -u fixtures/expected/python-symbols-large-unavailable.json "$PY_SYMBOLS_LARGE_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/missing.py --symbols --format json > "$PY_SYMBOLS_MISSING_JSON" || return 1
  diff -u fixtures/expected/python-symbols-missing-unavailable.json "$PY_SYMBOLS_MISSING_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/old_example.py --symbols --format json > "$PY_SYMBOLS_ALIAS_JSON" || return 1
  diff -u fixtures/expected/python-symbols-rename-alias.json "$PY_SYMBOLS_ALIAS_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/other.py --symbols --format json > "$PY_SYMBOLS_OTHER_JSON" || return 1
  ! grep -Fq -- 'top_function' "$PY_SYMBOLS_OTHER_JSON" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect 'src/markdown|path.py' --symbols --format markdown > "$PY_SYMBOLS_MARKDOWN_PATH_MD" || return 1
  grep -Fq -- 'markdown\|path.py' "$PY_SYMBOLS_MARKDOWN_PATH_MD" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format json > "$PY_LINE_HISTORY_JSON" || return 1
  diff -u fixtures/expected/python-line-history-success.json "$PY_LINE_HISTORY_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format json > "$PY_LINE_HISTORY_JSON_B" || return 1
  diff -u "$PY_LINE_HISTORY_JSON" "$PY_LINE_HISTORY_JSON_B" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format markdown > "$PY_LINE_HISTORY_MD" || return 1
  diff -u fixtures/expected/python-line-history-success.md "$PY_LINE_HISTORY_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format table > "$PY_LINE_HISTORY_TABLE" || return 1
  diff -u fixtures/expected/python-line-history-success.txt "$PY_LINE_HISTORY_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/python-symbols-shallow --inspect src/example.py --symbols --symbol-line-history --format json > "$PY_LINE_HISTORY_SHALLOW_JSON" || return 1
  grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$PY_LINE_HISTORY_SHALLOW_JSON" || return 1
  "$EXE" --repo fixtures/python-symbols-partial --inspect src/example.py --symbols --symbol-line-history --format json > "$PY_LINE_HISTORY_PARTIAL_JSON" || return 1
  grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$PY_LINE_HISTORY_PARTIAL_JSON" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/empty.py --symbols --symbol-line-history --format json > "$PY_LINE_HISTORY_EMPTY_JSON" || return 1
  grep -Fq -- 'current_line_history' "$PY_LINE_HISTORY_EMPTY_JSON" || return 1
  grep -Fq -- 'current-line Git evidence has unblamable lines in this symbol range' "$PY_LINE_HISTORY_EMPTY_JSON" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/invalid_partial.py --symbols --symbol-line-history --format json > "$PY_LINE_HISTORY_INVALID_JSON" || return 1
  grep -Fq -- '"failure": "failed"' "$PY_LINE_HISTORY_INVALID_JSON" || return 1
  ! grep -Fq -- 'current_line_history' "$PY_LINE_HISTORY_INVALID_JSON" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/link.py --symbols --symbol-line-history --format json > "$PY_LINE_HISTORY_SYMLINK_JSON" || return 1
  grep -Fq -- '"failure": "unavailable"' "$PY_LINE_HISTORY_SYMLINK_JSON" || return 1
  ! grep -Fq -- 'current_line_history' "$PY_LINE_HISTORY_SYMLINK_JSON" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/large.py --symbols --symbol-line-history --format json > "$PY_LINE_HISTORY_LARGE_JSON" || return 1
  grep -Fq -- '"failure": "unavailable"' "$PY_LINE_HISTORY_LARGE_JSON" || return 1
  ! grep -Fq -- 'current_line_history' "$PY_LINE_HISTORY_LARGE_JSON" || return 1
  "$EXE" --repo fixtures/python-symbols --inspect src/missing.py --symbols --symbol-line-history --format json > "$PY_LINE_HISTORY_MISSING_JSON" || return 1
  grep -Fq -- '"failure": "unavailable"' "$PY_LINE_HISTORY_MISSING_JSON" || return 1
  ! grep -Fq -- 'current_line_history' "$PY_LINE_HISTORY_MISSING_JSON" || return 1
  printf '# dirty inspected\n' >> fixtures/python-symbols/src/example.py
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format json > "$PY_LINE_HISTORY_DIRTY_JSON" || return 1
  grep -Fq -- 'current-line Git evidence skipped: inspected file has staged or unstaged content changes' "$PY_LINE_HISTORY_DIRTY_JSON" || return 1
  git -C fixtures/python-symbols checkout -q -- src/example.py
  printf '# dirty unrelated\n' >> fixtures/python-symbols/src/other.py
  "$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format json > "$PY_LINE_HISTORY_UNRELATED_JSON" || return 1
  grep -Fq -- '"failure": "ok"' "$PY_LINE_HISTORY_UNRELATED_JSON" || return 1
  git -C fixtures/python-symbols checkout -q -- src/other.py
  have_python || return 1
  python3 - "$SYMBOLS_JSON" "$SYMBOLS_UNSUPPORTED_JSON" "$SYMBOLS_SYMLINK_JSON" "$SYMBOLS_LIMIT_JSON" "$GO_SYMBOLS_JSON" "$GO_SYMBOLS_LIMIT_JSON" "$GO_SYMBOLS_EMPTY_JSON" "$GO_SYMBOLS_INVALID_JSON" "$GO_SYMBOLS_CAVEATED_JSON" "$GO_SYMBOLS_SYMLINK_JSON" "$GO_SYMBOLS_LARGE_JSON" "$GO_SYMBOLS_MISSING_JSON" "$GO_SYMBOLS_ALIAS_JSON" "$GO_SYMBOLS_OTHER_JSON" "$GO_LINE_HISTORY_JSON" "$GO_LINE_HISTORY_SHALLOW_JSON" "$GO_LINE_HISTORY_PARTIAL_JSON" "$PY_SYMBOLS_JSON" "$PY_SYMBOLS_LIMIT_JSON" "$PY_SYMBOLS_EMPTY_JSON" "$PY_SYMBOLS_INVALID_JSON" "$PY_SYMBOLS_GENERATED_JSON" "$PY_SYMBOLS_SYMLINK_JSON" "$PY_SYMBOLS_LARGE_JSON" "$PY_SYMBOLS_MISSING_JSON" "$PY_SYMBOLS_ALIAS_JSON" "$PY_SYMBOLS_OTHER_JSON" "$PY_LINE_HISTORY_JSON" "$PY_LINE_HISTORY_SHALLOW_JSON" "$PY_LINE_HISTORY_PARTIAL_JSON" "$PY_LINE_HISTORY_EMPTY_JSON" "$PY_LINE_HISTORY_DIRTY_JSON" "$PY_LINE_HISTORY_UNRELATED_JSON" <<'PY'
import json, sys
success, unsupported, symlink, limited, go_success, go_limited, go_empty, go_invalid, go_caveated, go_symlink, go_large, go_missing, go_alias, go_other, go_line, go_line_shallow, go_line_partial, py_success, py_limited, py_empty, py_invalid, py_generated, py_symlink, py_large, py_missing, py_alias, py_other, py_line, py_line_shallow, py_line_partial, py_line_empty, py_line_dirty, py_line_unrelated = [json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
for data in (success, unsupported, symlink, limited):
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
assert len(limited['symbols']['items']) == len(success['symbols']['items']), 'symbol limit truncated JSON items'
assert limited['symbols']['human_display']['shown_count'] == 1, 'symbol limit shown count changed'
assert limited['symbols']['human_display']['omitted_count'] == 1, 'symbol limit omitted count changed'
assert limited['symbols']['human_display']['active_limit'] == 1, 'symbol limit metadata changed'
assert limited['symbols']['human_display']['limit_source'] == 'explicit', 'symbol limit source changed'
assert unsupported['symbols']['provider']['failure'] == 'unsupported', 'unsupported provider failure changed'
assert symlink['symbols']['provider']['failure'] == 'unavailable', 'symlink should not parse as ok'
assert symlink['symbols']['items'] == [], 'symlink leaked parsed symbols'
assert symlink['results'], 'symlink did not preserve file evidence'
assert go_success['symbols']['provider']['name'] == 'tree-sitter-go', 'Go provider missing'
assert go_success['symbols']['provider']['failure'] == 'ok', 'Go provider failure changed'
assert [row['kind'] for row in go_success['symbols']['items']] == ['other', 'other', 'variable', 'method', 'type', 'type', 'function', 'module'], 'Go kinds changed'
assert len(go_limited['symbols']['items']) == len(go_success['symbols']['items']), 'Go limit truncated JSON'
assert go_limited['symbols']['human_display']['shown_count'] == 2, 'Go limit shown changed'
assert go_limited['symbols']['human_display']['omitted_count'] == 6, 'Go limit omitted changed'
assert go_empty['symbols']['provider']['failure'] == 'ok' and go_empty['symbols']['items'] == [], 'empty Go changed'
assert go_invalid['symbols']['provider']['failure'] == 'failed' and go_invalid['symbols']['items'] == [], 'invalid Go changed'
assert go_symlink['symbols']['provider']['failure'] == 'unavailable' and go_symlink['symbols']['items'] == [], 'Go symlink changed'
assert go_large['symbols']['provider']['failure'] == 'unavailable' and go_large['symbols']['items'] == [], 'Go too-large changed'
assert go_missing['symbols']['provider']['failure'] == 'unavailable' and go_missing['symbols']['items'] == [], 'Go missing current file changed'
assert go_alias['inspect']['requested_path'] == 'src/old-example.go' and go_alias['inspect']['matched_path'] == 'src/example.go', 'Go rename alias changed'
assert all(row['path'] == 'src/example.go' for row in go_alias['symbols']['items']), 'Go alias parsed requested alias'
assert any('build tags' in caveat and 'cgo' in caveat for caveat in go_caveated['symbols']['provider']['caveats']), 'Go caveat missing'
assert [row['name'] for row in go_other['symbols']['items']] == ['OtherOnly', 'symbols'], 'two-file inspect-only changed'
assert all('current_line_history' in row for row in go_line['symbols']['items']), 'Go current-line evidence missing'
assert any(row['current_line_history']['most_recent_line_touched_timestamp'] == 1777680000 for row in go_line['symbols']['items']), 'Go current-line timestamp evidence changed'
assert any('shallow' in ' '.join(row['current_line_history']['caveats']) for row in go_line_shallow['symbols']['items']), 'Go shallow caveat missing'
assert any('partial/promisor' in ' '.join(row['current_line_history']['caveats']) for row in go_line_partial['symbols']['items']), 'Go partial caveat missing'
assert py_success['symbols']['provider']['name'] == 'tree-sitter-python', 'Python provider missing'
assert py_success['symbols']['provider']['failure'] == 'ok', 'Python provider failure changed'
assert [row['name'] for row in py_success['symbols']['items']] == ['src/example.py', 'CONSTANT', 'mutable_value', 'top_function', 'inner_function', 'InnerClass', 'Outer', 'Nested', 'method', 'method_inner', 'café'], 'Python source order changed'
assert [row['kind'] for row in py_success['symbols']['items']] == ['module', 'other', 'variable', 'function', 'function', 'class', 'class', 'class', 'method', 'function', 'function'], 'Python kinds changed'
assert all(row['path'] == 'src/example.py' for row in py_success['symbols']['items']), 'Python path changed'
assert 'FIRST' not in json.dumps(py_success) and 'DYNAMIC' not in json.dumps(py_success), 'Python out-of-scope assignment leaked'
assert len(py_limited['symbols']['items']) == len(py_success['symbols']['items']), 'Python limit truncated JSON'
assert py_limited['symbols']['human_display']['shown_count'] == 3, 'Python limit shown changed'
assert py_limited['symbols']['human_display']['omitted_count'] == 8, 'Python limit omitted changed'
assert py_empty['symbols']['provider']['failure'] == 'ok' and [row['name'] for row in py_empty['symbols']['items']] == ['src/empty.py'], 'empty Python changed'
assert py_invalid['symbols']['provider']['failure'] == 'failed' and py_invalid['symbols']['items'] == [], 'invalid Python changed'
assert any('generated-file markers' in caveat for caveat in py_generated['symbols']['provider']['caveats']), 'Python generated caveat missing'
assert py_symlink['symbols']['provider']['failure'] == 'unavailable' and py_symlink['symbols']['items'] == [], 'Python symlink changed'
assert py_large['symbols']['provider']['failure'] == 'unavailable' and py_large['symbols']['items'] == [], 'Python too-large changed'
assert py_missing['symbols']['provider']['failure'] == 'unavailable' and py_missing['symbols']['items'] == [], 'Python missing current file changed'
assert py_alias['inspect']['requested_path'] == 'src/old_example.py' and py_alias['inspect']['matched_path'] == 'src/example.py', 'Python rename alias changed'
assert all(row['path'] == 'src/example.py' for row in py_alias['symbols']['items']), 'Python alias parsed requested alias'
assert [row['name'] for row in py_other['symbols']['items']] == ['src/other.py', 'OtherOnly'], 'two-file Python inspect changed'
assert all('current_line_history' in row for row in py_line['symbols']['items']), 'Python current-line evidence missing'
assert all(row['current_line_history']['basis'] == 'current-line-range-at-head' for row in py_line['symbols']['items']), 'Python line-history basis changed'
assert any(row['current_line_history']['most_recent_line_touched_timestamp'] == 1777593600 for row in py_line['symbols']['items']), 'Python current-line timestamp evidence changed'
assert any('shallow' in ' '.join(row['current_line_history']['caveats']) for row in py_line_shallow['symbols']['items']), 'Python shallow caveat missing'
assert any('partial/promisor' in ' '.join(row['current_line_history']['caveats']) for row in py_line_partial['symbols']['items']), 'Python partial caveat missing'
assert any(row['current_line_history']['uncommitted_or_unblamable_line_count'] > 0 for row in py_line_empty['symbols']['items']), 'Python empty-file line history did not degrade honestly'
assert all(row['current_line_history']['failure'] == 'skipped' for row in py_line_dirty['symbols']['items']), 'Python dirty inspected file did not skip line history'
assert all(row['current_line_history']['failure'] == 'ok' for row in py_line_unrelated['symbols']['items']), 'Python unrelated dirty file changed line history'
for data in (py_success, py_limited, py_empty, py_invalid, py_generated, py_symlink, py_large, py_missing, py_alias, py_other):
    text = json.dumps(data, ensure_ascii=False)
    assert 'current_line_history' not in text, 'Python line history unexpectedly emitted'
    for forbidden in ('Fixture Author', 'fixture@example', 'source line'):
        assert forbidden not in text, 'Python private detail leaked'
for data in (py_line, py_line_shallow, py_line_partial, py_line_empty, py_line_dirty, py_line_unrelated):
    text = json.dumps(data, ensure_ascii=False)
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'ownership', 'productivity'):
        assert forbidden not in text, 'Python line-history private detail leaked'
PY
  JS_SYMBOLS_JSON=$ARTIFACT_DIR/javascript-symbols.json
  JS_LINE_HISTORY_JSON=$ARTIFACT_DIR/javascript-line-history.json
  JS_LINE_HISTORY_JSON_B=$ARTIFACT_DIR/javascript-line-history-b.json
  JS_LINE_HISTORY_MD=$ARTIFACT_DIR/javascript-line-history.md
  JS_LINE_HISTORY_TABLE=$ARTIFACT_DIR/javascript-line-history.txt
  JS_LINE_HISTORY_SHALLOW_JSON=$ARTIFACT_DIR/javascript-line-history-shallow.json
  JS_LINE_HISTORY_PARTIAL_JSON=$ARTIFACT_DIR/javascript-line-history-partial.json
  JS_LINE_HISTORY_COMMONJS_JSON=$ARTIFACT_DIR/javascript-line-history-commonjs.json
  JS_LINE_HISTORY_JSX_JSON=$ARTIFACT_DIR/javascript-line-history-jsx.json
  JS_LINE_HISTORY_EMPTY_JSON=$ARTIFACT_DIR/javascript-line-history-empty.json
  JS_LINE_HISTORY_INVALID_JSON=$ARTIFACT_DIR/javascript-line-history-invalid.json
  JS_LINE_HISTORY_SYMLINK_JSON=$ARTIFACT_DIR/javascript-line-history-symlink.json
  JS_LINE_HISTORY_LARGE_JSON=$ARTIFACT_DIR/javascript-line-history-large.json
  JS_LINE_HISTORY_MISSING_JSON=$ARTIFACT_DIR/javascript-line-history-missing.json
  "$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --format json > "$JS_SYMBOLS_JSON" || return 1
  diff -u fixtures/expected/javascript-symbols.json "$JS_SYMBOLS_JSON" >/dev/null || return 1
  ! grep -Fq -- 'current_line_history' "$JS_SYMBOLS_JSON" || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-line-history --format json > "$JS_LINE_HISTORY_JSON" || return 1
  diff -u fixtures/expected/javascript-line-history-success.json "$JS_LINE_HISTORY_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-line-history --format json > "$JS_LINE_HISTORY_JSON_B" || return 1
  diff -u "$JS_LINE_HISTORY_JSON" "$JS_LINE_HISTORY_JSON_B" >/dev/null || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-line-history --format markdown > "$JS_LINE_HISTORY_MD" || return 1
  diff -u fixtures/expected/javascript-line-history-success.md "$JS_LINE_HISTORY_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-line-history --format table > "$JS_LINE_HISTORY_TABLE" || return 1
  diff -u fixtures/expected/javascript-line-history-success.txt "$JS_LINE_HISTORY_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/javascript-symbols-shallow --inspect src/example.mjs --symbols --symbol-line-history --format json > "$JS_LINE_HISTORY_SHALLOW_JSON" || return 1
  grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$JS_LINE_HISTORY_SHALLOW_JSON" || return 1
  "$EXE" --repo fixtures/javascript-symbols-partial --inspect src/example.mjs --symbols --symbol-line-history --format json > "$JS_LINE_HISTORY_PARTIAL_JSON" || return 1
  grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$JS_LINE_HISTORY_PARTIAL_JSON" || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/commonjs.cjs --symbols --symbol-line-history --format json > "$JS_LINE_HISTORY_COMMONJS_JSON" || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/component.jsx --symbols --symbol-line-history --format json > "$JS_LINE_HISTORY_JSX_JSON" || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/empty.js --symbols --symbol-line-history --format json > "$JS_LINE_HISTORY_EMPTY_JSON" || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/invalid_partial.js --symbols --symbol-line-history --format json > "$JS_LINE_HISTORY_INVALID_JSON" || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/link.js --symbols --symbol-line-history --format json > "$JS_LINE_HISTORY_SYMLINK_JSON" || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/large.js --symbols --symbol-line-history --format json > "$JS_LINE_HISTORY_LARGE_JSON" || return 1
  "$EXE" --repo fixtures/javascript-symbols --inspect src/missing.js --symbols --symbol-line-history --format json > "$JS_LINE_HISTORY_MISSING_JSON" || return 1
  python3 - "$JS_LINE_HISTORY_JSON" "$JS_LINE_HISTORY_SHALLOW_JSON" "$JS_LINE_HISTORY_PARTIAL_JSON" "$JS_LINE_HISTORY_COMMONJS_JSON" "$JS_LINE_HISTORY_JSX_JSON" "$JS_LINE_HISTORY_EMPTY_JSON" "$JS_LINE_HISTORY_INVALID_JSON" "$JS_LINE_HISTORY_SYMLINK_JSON" "$JS_LINE_HISTORY_LARGE_JSON" "$JS_LINE_HISTORY_MISSING_JSON" <<'PY'
import json, sys
line, shallow, partial, commonjs, jsx, empty, invalid, symlink, large, missing = [json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
assert all('current_line_history' in row for row in line['symbols']['items']), 'JavaScript current-line evidence missing'
assert any(row['current_line_history']['most_recent_line_touched_timestamp'] == 1777593600 for row in line['symbols']['items']), 'JavaScript line-history timestamp changed'
assert any('shallow' in ' '.join(row['current_line_history']['caveats']) for row in shallow['symbols']['items']), 'JavaScript shallow caveat missing'
assert any('partial/promisor' in ' '.join(row['current_line_history']['caveats']) for row in partial['symbols']['items']), 'JavaScript partial caveat missing'
assert all('current_line_history' in row for row in commonjs['symbols']['items']), 'CommonJS current-line evidence missing'
assert all('current_line_history' in row for row in jsx['symbols']['items']), 'JSX current-line evidence missing'
assert any('TSX remains unsupported' in caveat for caveat in jsx['symbols']['provider']['caveats']), 'JSX caveat missing'
assert any(row['current_line_history']['uncommitted_or_unblamable_line_count'] > 0 for row in empty['symbols']['items']), 'empty JavaScript did not degrade safely'
assert invalid['symbols']['provider']['failure'] == 'failed' and invalid['symbols']['items'] == [], 'invalid JavaScript should fail closed'
for data in (symlink, large, missing):
    assert data['symbols']['provider']['failure'] == 'unavailable' and data['symbols']['items'] == [], 'unavailable JavaScript current file changed'
for data in (line, shallow, partial, commonjs, jsx, empty, invalid, symlink, large, missing):
    text = json.dumps(data, ensure_ascii=False)
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'ownership', 'productivity', 'Node package graph'):
        assert forbidden not in text, 'JavaScript private detail leaked'
PY
  LUA_SYMBOLS_JSON=$ARTIFACT_DIR/lua-symbols.json
  LUA_LINE_HISTORY_JSON=$ARTIFACT_DIR/lua-line-history.json
  LUA_LINE_HISTORY_JSON_B=$ARTIFACT_DIR/lua-line-history-b.json
  LUA_LINE_HISTORY_MD=$ARTIFACT_DIR/lua-line-history.md
  LUA_LINE_HISTORY_TABLE=$ARTIFACT_DIR/lua-line-history.txt
  LUA_LINE_HISTORY_SHALLOW_JSON=$ARTIFACT_DIR/lua-line-history-shallow.json
  LUA_LINE_HISTORY_PARTIAL_JSON=$ARTIFACT_DIR/lua-line-history-partial.json
  LUA_LINE_HISTORY_EMPTY_JSON=$ARTIFACT_DIR/lua-line-history-empty.json
  LUA_LINE_HISTORY_INVALID_JSON=$ARTIFACT_DIR/lua-line-history-invalid.json
  LUA_LINE_HISTORY_GENERATED_JSON=$ARTIFACT_DIR/lua-line-history-generated.json
  LUA_LINE_HISTORY_DYNAMIC_JSON=$ARTIFACT_DIR/lua-line-history-dynamic.json
  LUA_LINE_HISTORY_METATABLE_JSON=$ARTIFACT_DIR/lua-line-history-metatable.json
  LUA_LINE_HISTORY_EMBEDDED_JSON=$ARTIFACT_DIR/lua-line-history-embedded.json
  LUA_LINE_HISTORY_SYMLINK_JSON=$ARTIFACT_DIR/lua-line-history-symlink.json
  LUA_LINE_HISTORY_LARGE_JSON=$ARTIFACT_DIR/lua-line-history-large.json
  LUA_LINE_HISTORY_MISSING_JSON=$ARTIFACT_DIR/lua-line-history-missing.json
  LUA_LINE_HISTORY_ALIAS_JSON=$ARTIFACT_DIR/lua-line-history-alias.json
  LUA_LINE_HISTORY_DIRTY_JSON=$ARTIFACT_DIR/lua-line-history-dirty.json
  LUA_LINE_HISTORY_UNRELATED_JSON=$ARTIFACT_DIR/lua-line-history-unrelated.json
  "$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --format json > "$LUA_SYMBOLS_JSON" || return 1
  diff -u fixtures/expected/lua-symbols.json "$LUA_SYMBOLS_JSON" >/dev/null || return 1
  ! grep -Fq -- 'current_line_history' "$LUA_SYMBOLS_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_JSON" || return 1
  diff -u fixtures/expected/lua-line-history-success.json "$LUA_LINE_HISTORY_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_JSON_B" || return 1
  diff -u "$LUA_LINE_HISTORY_JSON" "$LUA_LINE_HISTORY_JSON_B" >/dev/null || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format markdown > "$LUA_LINE_HISTORY_MD" || return 1
  diff -u fixtures/expected/lua-line-history-success.md "$LUA_LINE_HISTORY_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format table > "$LUA_LINE_HISTORY_TABLE" || return 1
  diff -u fixtures/expected/lua-line-history-success.txt "$LUA_LINE_HISTORY_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/lua-symbols-shallow --inspect src/example.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_SHALLOW_JSON" || return 1
  grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$LUA_LINE_HISTORY_SHALLOW_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols-partial --inspect src/example.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_PARTIAL_JSON" || return 1
  grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$LUA_LINE_HISTORY_PARTIAL_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/empty.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_EMPTY_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/invalid_partial.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_INVALID_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/generated.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_GENERATED_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/dynamic_table_assignment.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_DYNAMIC_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/metatable_heavy.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_METATABLE_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/embedded_dsl.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_EMBEDDED_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/link.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_SYMLINK_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/large.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_LARGE_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/missing.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_MISSING_JSON" || return 1
  "$EXE" --repo fixtures/lua-symbols --inspect src/old-example.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_ALIAS_JSON" || return 1
  printf 'local function untracked()\n  return true\nend\n' > fixtures/lua-symbols/src/untracked.lua
  if "$EXE" --repo fixtures/lua-symbols --inspect src/untracked.lua --symbols --symbol-line-history --format json > "$ARTIFACT_DIR/lua-line-history-untracked.out" 2> "$ARTIFACT_DIR/lua-line-history-untracked.err"; then return 1; fi
  grep -q -- '--inspect target has no matching' "$ARTIFACT_DIR/lua-line-history-untracked.err" || return 1
  rm -f fixtures/lua-symbols/src/untracked.lua
  printf '%s\n' '-- dirty inspected' >> fixtures/lua-symbols/src/example.lua
  "$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_DIRTY_JSON" || return 1
  grep -Fq -- 'current-line Git evidence skipped: inspected file has staged or unstaged content changes' "$LUA_LINE_HISTORY_DIRTY_JSON" || return 1
  git -C fixtures/lua-symbols checkout -q -- src/example.lua
  printf '%s\n' '-- dirty unrelated' >> fixtures/lua-symbols/src/other.lua
  "$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format json > "$LUA_LINE_HISTORY_UNRELATED_JSON" || return 1
  grep -Fq -- '"failure": "ok"' "$LUA_LINE_HISTORY_UNRELATED_JSON" || return 1
  git -C fixtures/lua-symbols checkout -q -- src/other.lua
  if sh -c 'tmp=$(mktemp -d); git init -q -b main "$tmp" && "$0" --repo "$tmp" --inspect src/example.lua --symbols --symbol-line-history --format json' "$EXE" > "$ARTIFACT_DIR/lua-line-history-no-history.out" 2> "$ARTIFACT_DIR/lua-line-history-no-history.err"; then return 1; fi
  grep -q -- 'repository has no commits' "$ARTIFACT_DIR/lua-line-history-no-history.err" || return 1
  python3 - "$LUA_SYMBOLS_JSON" "$LUA_LINE_HISTORY_JSON" "$LUA_LINE_HISTORY_SHALLOW_JSON" "$LUA_LINE_HISTORY_PARTIAL_JSON" "$LUA_LINE_HISTORY_EMPTY_JSON" "$LUA_LINE_HISTORY_INVALID_JSON" "$LUA_LINE_HISTORY_GENERATED_JSON" "$LUA_LINE_HISTORY_DYNAMIC_JSON" "$LUA_LINE_HISTORY_METATABLE_JSON" "$LUA_LINE_HISTORY_EMBEDDED_JSON" "$LUA_LINE_HISTORY_SYMLINK_JSON" "$LUA_LINE_HISTORY_LARGE_JSON" "$LUA_LINE_HISTORY_MISSING_JSON" "$LUA_LINE_HISTORY_ALIAS_JSON" "$LUA_LINE_HISTORY_DIRTY_JSON" "$LUA_LINE_HISTORY_UNRELATED_JSON" <<'PY'
import json, sys
symbols, line, shallow, partial, empty, invalid, generated, dynamic, metatable, embedded, symlink, large, missing, alias, dirty, unrelated = [json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
assert symbols['symbols']['provider']['name'] == 'tree-sitter-lua', 'Lua provider missing'
assert all('current_line_history' in row for row in line['symbols']['items']), 'Lua current-line evidence missing'
assert all(row['current_line_history']['basis'] == 'current-line-range-at-head' for row in line['symbols']['items']), 'Lua line-history basis changed'
assert any(row['current_line_history']['most_recent_line_touched_timestamp'] == 1777593600 for row in line['symbols']['items']), 'Lua timestamp changed'
assert any('shallow' in ' '.join(row['current_line_history']['caveats']) for row in shallow['symbols']['items']), 'Lua shallow caveat missing'
assert any('partial/promisor' in ' '.join(row['current_line_history']['caveats']) for row in partial['symbols']['items']), 'Lua partial caveat missing'
assert any(row['current_line_history']['uncommitted_or_unblamable_line_count'] > 0 for row in empty['symbols']['items']), 'empty Lua did not degrade safely'
assert invalid['symbols']['provider']['failure'] == 'failed' and invalid['symbols']['items'] == [], 'invalid Lua should fail closed'
assert any('generated-file markers' in caveat for caveat in generated['symbols']['provider']['caveats']), 'Lua generated caveat missing'
assert any('dynamic bracket table assignments' in caveat for caveat in dynamic['symbols']['provider']['caveats']), 'Lua dynamic caveat missing'
assert any('metatable-heavy Lua' in caveat for caveat in metatable['symbols']['provider']['caveats']), 'Lua metatable caveat missing'
assert any('embedded DSL strings' in caveat for caveat in embedded['symbols']['provider']['caveats']), 'Lua embedded DSL caveat missing'
for data in (generated, dynamic, metatable, embedded):
    assert all('current_line_history' in row for row in data['symbols']['items']), 'caveated Lua file lost current-line evidence'
for data in (symlink, large, missing):
    assert data['symbols']['provider']['failure'] == 'unavailable' and data['symbols']['items'] == [], 'unavailable Lua file changed'
assert alias['inspect']['requested_path'] == 'src/old-example.lua' and alias['inspect']['matched_path'] == 'src/example.lua', 'Lua alias changed'
assert all(row['current_line_history']['failure'] == 'skipped' for row in dirty['symbols']['items']), 'Lua dirty inspected file did not skip'
assert all(row['current_line_history']['failure'] == 'ok' for row in unrelated['symbols']['items']), 'Lua unrelated dirty file changed line history'
for data in (line, shallow, partial, empty, invalid, generated, dynamic, metatable, embedded, symlink, large, missing, alias, dirty, unrelated):
    text = json.dumps(data, ensure_ascii=False)
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'previous filename', 'ownership', 'productivity', 'developer ranking'):
        assert forbidden not in text, 'Lua private detail leaked'
PY
  TS_LINE_HISTORY_JSON=$ARTIFACT_DIR/typescript-line-history.json
  TS_LINE_HISTORY_JSON_B=$ARTIFACT_DIR/typescript-line-history-b.json
  TS_LINE_HISTORY_MD=$ARTIFACT_DIR/typescript-line-history.md
  TS_LINE_HISTORY_TABLE=$ARTIFACT_DIR/typescript-line-history.txt
  TSX_LINE_HISTORY_JSON=$ARTIFACT_DIR/typescript-line-history-tsx.json
  TSX_LINE_HISTORY_MD=$ARTIFACT_DIR/typescript-line-history-tsx.md
  TSX_LINE_HISTORY_TABLE=$ARTIFACT_DIR/typescript-line-history-tsx.txt
  TS_LINE_HISTORY_SHALLOW_JSON=$ARTIFACT_DIR/typescript-line-history-shallow.json
  TS_LINE_HISTORY_PARTIAL_JSON=$ARTIFACT_DIR/typescript-line-history-partial.json
  "$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-line-history --format json > "$TS_LINE_HISTORY_JSON" || return 1
  diff -u fixtures/expected/typescript-line-history-success.json "$TS_LINE_HISTORY_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-line-history --format json > "$TS_LINE_HISTORY_JSON_B" || return 1
  diff -u "$TS_LINE_HISTORY_JSON" "$TS_LINE_HISTORY_JSON_B" >/dev/null || return 1
  "$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-line-history --format markdown > "$TS_LINE_HISTORY_MD" || return 1
  diff -u fixtures/expected/typescript-line-history-success.md "$TS_LINE_HISTORY_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-line-history --format table > "$TS_LINE_HISTORY_TABLE" || return 1
  diff -u fixtures/expected/typescript-line-history-success.txt "$TS_LINE_HISTORY_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/typescript-symbols --inspect src/component.tsx --symbols --symbol-line-history --format json > "$TSX_LINE_HISTORY_JSON" || return 1
  diff -u fixtures/expected/typescript-line-history-tsx.json "$TSX_LINE_HISTORY_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/typescript-symbols --inspect src/component.tsx --symbols --symbol-line-history --format markdown > "$TSX_LINE_HISTORY_MD" || return 1
  diff -u fixtures/expected/typescript-line-history-tsx.md "$TSX_LINE_HISTORY_MD" >/dev/null || return 1
  "$EXE" --repo fixtures/typescript-symbols --inspect src/component.tsx --symbols --symbol-line-history --format table > "$TSX_LINE_HISTORY_TABLE" || return 1
  diff -u fixtures/expected/typescript-line-history-tsx.txt "$TSX_LINE_HISTORY_TABLE" >/dev/null || return 1
  "$EXE" --repo fixtures/typescript-symbols-shallow --inspect src/example.ts --symbols --symbol-line-history --format json > "$TS_LINE_HISTORY_SHALLOW_JSON" || return 1
  grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$TS_LINE_HISTORY_SHALLOW_JSON" || return 1
  "$EXE" --repo fixtures/typescript-symbols-partial --inspect src/example.ts --symbols --symbol-line-history --format json > "$TS_LINE_HISTORY_PARTIAL_JSON" || return 1
  grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$TS_LINE_HISTORY_PARTIAL_JSON" || return 1
  python3 - "$TS_LINE_HISTORY_JSON" "$TSX_LINE_HISTORY_JSON" "$TS_LINE_HISTORY_SHALLOW_JSON" "$TS_LINE_HISTORY_PARTIAL_JSON" <<'PY'
import json, sys
ts, tsx, shallow, partial = [json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
assert all('current_line_history' in row for row in ts['symbols']['items']), 'TypeScript current-line evidence missing'
assert all(row['current_line_history']['basis'] == 'current-line-range-at-head' for row in ts['symbols']['items']), 'TypeScript line-history basis changed'
assert any(row['current_line_history']['most_recent_line_touched_timestamp'] == 1777593600 for row in ts['symbols']['items']), 'TypeScript timestamp changed'
assert tsx['symbols']['provider']['name'] == 'tree-sitter-tsx', 'TSX provider missing'
assert all('current_line_history' in row for row in tsx['symbols']['items']), 'TSX current-line evidence missing'
assert any('shallow' in ' '.join(row['current_line_history']['caveats']) for row in shallow['symbols']['items']), 'TypeScript shallow caveat missing'
assert any('partial/promisor' in ' '.join(row['current_line_history']['caveats']) for row in partial['symbols']['items']), 'TypeScript partial caveat missing'
for data in (ts, tsx, shallow, partial):
    text = json.dumps(data, ensure_ascii=False)
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'ownership', 'productivity', 'tsconfig path', 'Node package graph'):
        assert forbidden not in text, 'TypeScript private detail leaked'
PY
  "$EXE" --repo fixtures/symbols --symbols --format json > "$ARTIFACT_DIR/symbols-project.json" || return 1
  python3 - "$ARTIFACT_DIR/symbols-project.json" <<'PY2'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
assert 'project_symbols' in data and 'symbols' not in data
assert data['project_symbols']['summary']['file_count'] >= 1
assert data['project_symbols']['human_display']['total_count'] >= 1
PY2
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
  tracked_go_count=$(git -C "$repo" ls-files '*.go' 2>/dev/null | wc -l | tr -d ' ' || printf 'unknown')
  tracked_python_count=$(git -C "$repo" ls-files '*.py' 2>/dev/null | wc -l | tr -d ' ' || printf 'unknown')
  tracked_javascript_count=$(git -C "$repo" ls-files '*.js' '*.mjs' '*.cjs' '*.jsx' 2>/dev/null | wc -l | tr -d ' ' || printf 'unknown')
  tracked_lua_count=$(git -C "$repo" ls-files '*.lua' 2>/dev/null | wc -l | tr -d ' ' || printf 'unknown')
  tracked_rust_count=$(git -C "$repo" ls-files '*.rs' 2>/dev/null | wc -l | tr -d ' ' || printf 'unknown')
  tracked_typescript_count=$(git -C "$repo" ls-files '*.ts' '*.mts' '*.cts' '*.tsx' 2>/dev/null | wc -l | tr -d ' ' || printf 'unknown')

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

  first_go_path=$(git -C "$repo" ls-files '*.go' 2>/dev/null | LC_ALL=C sort | head -n 1 || true)
  go_symbol_status=skip-no-tracked-go-file
  if [ -n "$first_go_path" ]; then
    go_symbol_out=$(mktemp "$ARTIFACT_DIR/real-go-symbol.XXXXXX.json")
    if "$EXE" --repo "$repo" --inspect "$first_go_path" --symbols --format json > "$go_symbol_out" 2> "$timing_file" && python3 -m json.tool "$go_symbol_out" >/dev/null 2>&1; then
      go_symbol_status=pass
    else
      go_symbol_status=fail
    fi
  fi

  first_python_path=$(git -C "$repo" ls-files '*.py' 2>/dev/null | LC_ALL=C sort | head -n 1 || true)
  python_symbol_status=skip-no-tracked-python-file
  python_line_history_status=skip-no-tracked-python-file
  if [ -n "$first_python_path" ]; then
    python_symbol_status=skip-no-successful-python-symbol-file
    python_line_history_status=skip-no-safe-tracked-python-file
    python_candidates=$(mktemp "$ARTIFACT_DIR/real-python-candidates.XXXXXX")
    git -C "$repo" ls-files '*.py' 2>/dev/null | LC_ALL=C sort | head -n 12 > "$python_candidates" || true
    while IFS= read -r python_path; do
      [ -n "$python_path" ] || continue
      python_symbol_out=$(mktemp "$ARTIFACT_DIR/real-python-symbol.XXXXXX.json")
      if [ "$python_symbol_status" != pass ] && "$EXE" --repo "$repo" --inspect "$python_path" --symbols --format json > "$python_symbol_out" 2> "$timing_file" && python3 -m json.tool "$python_symbol_out" >/dev/null 2>&1; then
        python_symbol_status=pass
      fi
      python_line_history_out=$(mktemp "$ARTIFACT_DIR/real-python-line-history.XXXXXX.json")
      if "$EXE" --repo "$repo" --inspect "$python_path" --symbols --symbol-line-history --format json > "$python_line_history_out" 2> "$timing_file" && python3 - "$python_line_history_out" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
symbols = data.get('symbols') or {}
if (symbols.get('provider') or {}).get('failure') != 'ok':
    raise SystemExit(2)
items = symbols.get('items') or []
if not items:
    raise SystemExit(3)
histories = [row.get('current_line_history') for row in items]
if not all(histories):
    raise SystemExit(4)
if not any(history.get('failure') == 'ok' and int(history.get('distinct_last_touch_commit_count') or 0) > 0 for history in histories):
    raise SystemExit(5)
PY
      then
        python_line_history_status=pass
        break
      fi
    done < "$python_candidates"
  fi

  first_javascript_path=$(git -C "$repo" ls-files '*.js' '*.mjs' '*.cjs' '*.jsx' 2>/dev/null | LC_ALL=C sort | head -n 1 || true)
  javascript_symbol_status=skip-no-tracked-javascript-file
  javascript_line_history_status=skip-no-tracked-javascript-file
  if [ -n "$first_javascript_path" ]; then
    javascript_symbol_status=skip-no-successful-javascript-symbol-file
    javascript_line_history_status=skip-no-safe-tracked-javascript-file
    javascript_candidates=$(mktemp "$ARTIFACT_DIR/real-javascript-candidates.XXXXXX")
    git -C "$repo" ls-files '*.js' '*.mjs' '*.cjs' '*.jsx' 2>/dev/null | LC_ALL=C sort | head -n 12 > "$javascript_candidates" || true
    while IFS= read -r javascript_path; do
      [ -n "$javascript_path" ] || continue
      javascript_symbol_out=$(mktemp "$ARTIFACT_DIR/real-javascript-symbol.XXXXXX.json")
      if [ "$javascript_symbol_status" != pass ] && "$EXE" --repo "$repo" --inspect "$javascript_path" --symbols --format json > "$javascript_symbol_out" 2> "$timing_file" && python3 -m json.tool "$javascript_symbol_out" >/dev/null 2>&1; then
        javascript_symbol_status=pass
      fi
      javascript_line_history_out=$(mktemp "$ARTIFACT_DIR/real-javascript-line-history.XXXXXX.json")
      if "$EXE" --repo "$repo" --inspect "$javascript_path" --symbols --symbol-line-history --format json > "$javascript_line_history_out" 2> "$timing_file" && python3 - "$javascript_line_history_out" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
symbols = data.get('symbols') or {}
if (symbols.get('provider') or {}).get('failure') != 'ok':
    raise SystemExit(2)
items = symbols.get('items') or []
if not items:
    raise SystemExit(3)
histories = [row.get('current_line_history') for row in items]
if not all(histories):
    raise SystemExit(4)
if not any(history.get('failure') == 'ok' and int(history.get('distinct_last_touch_commit_count') or 0) > 0 for history in histories):
    raise SystemExit(5)
PY
      then
        javascript_line_history_status=pass
        break
      fi
    done < "$javascript_candidates"
  fi

  first_lua_path=$(git -C "$repo" ls-files '*.lua' 2>/dev/null | LC_ALL=C sort | head -n 1 || true)
  lua_symbol_status=skip-no-tracked-lua-file
  lua_line_history_status=skip-no-tracked-lua-file
  if [ -n "$first_lua_path" ]; then
    lua_symbol_status=skip-no-successful-lua-symbol-file
    lua_line_history_status=skip-no-safe-tracked-lua-file
    lua_candidates=$(mktemp "$ARTIFACT_DIR/real-lua-candidates.XXXXXX")
    git -C "$repo" ls-files '*.lua' 2>/dev/null | LC_ALL=C sort | head -n 12 > "$lua_candidates" || true
    while IFS= read -r lua_path; do
      [ -n "$lua_path" ] || continue
      lua_symbol_out=$(mktemp "$ARTIFACT_DIR/real-lua-symbol.XXXXXX.json")
      if [ "$lua_symbol_status" != pass ] && "$EXE" --repo "$repo" --inspect "$lua_path" --symbols --format json > "$lua_symbol_out" 2> "$timing_file" && python3 -m json.tool "$lua_symbol_out" >/dev/null 2>&1; then
        lua_symbol_status=pass
      fi
      lua_line_history_out=$(mktemp "$ARTIFACT_DIR/real-lua-line-history.XXXXXX.json")
      if "$EXE" --repo "$repo" --inspect "$lua_path" --symbols --symbol-line-history --format json > "$lua_line_history_out" 2> "$timing_file" && python3 - "$lua_line_history_out" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
symbols = data.get('symbols') or {}
if (symbols.get('provider') or {}).get('failure') != 'ok':
    raise SystemExit(2)
items = symbols.get('items') or []
if not items:
    raise SystemExit(3)
histories = [row.get('current_line_history') for row in items]
if not all(histories):
    raise SystemExit(4)
if not any(history.get('failure') == 'ok' and int(history.get('distinct_last_touch_commit_count') or 0) > 0 for history in histories):
    raise SystemExit(5)
PY
      then
        lua_line_history_status=pass
        break
      fi
    done < "$lua_candidates"
  fi

  first_rust_path=$(git -C "$repo" ls-files '*.rs' 2>/dev/null | LC_ALL=C sort | head -n 1 || true)
  rust_symbol_status=skip-no-tracked-rust-file
  rust_line_history_status=skip-no-tracked-rust-file
  if [ -n "$first_rust_path" ]; then
    rust_symbol_status=skip-no-successful-rust-symbol-file
    rust_line_history_status=skip-no-safe-tracked-rust-file
    rust_candidates=$(mktemp "$ARTIFACT_DIR/real-rust-candidates.XXXXXX")
    git -C "$repo" ls-files '*.rs' 2>/dev/null | LC_ALL=C sort | head -n 12 > "$rust_candidates" || true
    while IFS= read -r rust_path; do
      [ -n "$rust_path" ] || continue
      rust_symbol_out=$(mktemp "$ARTIFACT_DIR/real-rust-symbol.XXXXXX.json")
      if [ "$rust_symbol_status" != pass ] && "$EXE" --repo "$repo" --inspect "$rust_path" --symbols --format json > "$rust_symbol_out" 2> "$timing_file" && python3 -m json.tool "$rust_symbol_out" >/dev/null 2>&1; then
        rust_symbol_status=pass
      fi
      rust_line_history_out=$(mktemp "$ARTIFACT_DIR/real-rust-line-history.XXXXXX.json")
      if "$EXE" --repo "$repo" --inspect "$rust_path" --symbols --symbol-line-history --format json > "$rust_line_history_out" 2> "$timing_file" && python3 - "$rust_line_history_out" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
symbols = data.get('symbols') or {}
if (symbols.get('provider') or {}).get('failure') != 'ok':
    raise SystemExit(2)
items = symbols.get('items') or []
if not items:
    raise SystemExit(3)
histories = [row.get('current_line_history') for row in items]
if not all(histories):
    raise SystemExit(4)
if not any(history.get('failure') == 'ok' and int(history.get('distinct_last_touch_commit_count') or 0) > 0 for history in histories):
    raise SystemExit(5)
PY
      then
        rust_line_history_status=pass
        break
      fi
    done < "$rust_candidates"
  fi

  first_typescript_path=$(git -C "$repo" ls-files '*.ts' '*.mts' '*.cts' '*.tsx' 2>/dev/null | LC_ALL=C sort | head -n 1 || true)
  typescript_symbol_status=skip-no-tracked-typescript-file
  typescript_line_history_status=skip-no-tracked-typescript-file
  if [ -n "$first_typescript_path" ]; then
    typescript_symbol_status=skip-no-successful-typescript-symbol-file
    typescript_line_history_status=skip-no-safe-tracked-typescript-file
    typescript_candidates=$(mktemp "$ARTIFACT_DIR/real-typescript-candidates.XXXXXX")
    git -C "$repo" ls-files '*.ts' '*.mts' '*.cts' '*.tsx' 2>/dev/null | LC_ALL=C sort | head -n 12 > "$typescript_candidates" || true
    while IFS= read -r typescript_path; do
      [ -n "$typescript_path" ] || continue
      typescript_symbol_out=$(mktemp "$ARTIFACT_DIR/real-typescript-symbol.XXXXXX.json")
      if [ "$typescript_symbol_status" != pass ] && "$EXE" --repo "$repo" --inspect "$typescript_path" --symbols --format json > "$typescript_symbol_out" 2> "$timing_file" && python3 -m json.tool "$typescript_symbol_out" >/dev/null 2>&1; then
        typescript_symbol_status=pass
      fi
      typescript_line_history_out=$(mktemp "$ARTIFACT_DIR/real-typescript-line-history.XXXXXX.json")
      if "$EXE" --repo "$repo" --inspect "$typescript_path" --symbols --symbol-line-history --format json > "$typescript_line_history_out" 2> "$timing_file" && python3 - "$typescript_line_history_out" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
symbols = data.get('symbols') or {}
if (symbols.get('provider') or {}).get('failure') != 'ok':
    raise SystemExit(2)
items = symbols.get('items') or []
if not items:
    raise SystemExit(3)
histories = [row.get('current_line_history') for row in items]
if not all(histories):
    raise SystemExit(4)
if not any(history.get('failure') == 'ok' and int(history.get('distinct_last_touch_commit_count') or 0) > 0 for history in histories):
    raise SystemExit(5)
PY
      then
        typescript_line_history_status=pass
        break
      fi
    done < "$typescript_candidates"
  fi

  if [ "$table_status" = pass ] && [ "$json_status" = pass ] && [ "$markdown_status" = pass ] && [ "$project_table_status" = pass ] && [ "$project_json_status" = pass ] && [ "$project_markdown_status" = pass ] && [ "$progress_status" = pass ]; then
    summary=$(json_count_summary "$json_out") || summary='results=unknown caveats=unknown dirty=unknown'
    project_summary=$(json_count_summary "$project_json_out") || project_summary='results=unknown caveats=unknown dirty=unknown'
    elapsed=${timing#*|}
    project_elapsed=${project_timing#*|}
    printf 'real-repo label=%s commits=%s tracked_files=%s tracked_go_files=%s tracked_python_files=%s tracked_javascript_files=%s tracked_lua_files=%s tracked_rust_files=%s tracked_typescript_files=%s go_symbol=%s python_symbol=%s python_line_history=%s javascript_symbol=%s javascript_line_history=%s lua_symbol=%s lua_line_history=%s rust_symbol=%s rust_line_history=%s typescript_symbol=%s typescript_line_history=%s all_table=%s all_json=%s all_markdown=%s all_%s all_elapsed=%s project_table=%s project_json=%s project_markdown=%s project_progress=%s project_%s project_elapsed=%s\n' "$label" "$commit_count" "$tracked_file_count" "$tracked_go_count" "$tracked_python_count" "$tracked_javascript_count" "$tracked_lua_count" "$tracked_rust_count" "$tracked_typescript_count" "$go_symbol_status" "$python_symbol_status" "$python_line_history_status" "$javascript_symbol_status" "$javascript_line_history_status" "$lua_symbol_status" "$lua_line_history_status" "$rust_symbol_status" "$rust_line_history_status" "$typescript_symbol_status" "$typescript_line_history_status" "$table_status" "$json_status" "$markdown_status" "$summary" "$elapsed" "$project_table_status" "$project_json_status" "$project_markdown_status" "$progress_status" "$project_summary" "$project_elapsed" >> "$SMOKES"
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
SYMBOLS_LIMIT_JSON=$ARTIFACT_DIR/symbols-limit.json
SYMBOLS_LIMIT_MD=$ARTIFACT_DIR/symbols-limit.md
SYMBOLS_LIMIT_MD_B=$ARTIFACT_DIR/symbols-limit-b.md
SYMBOLS_LIMIT_TABLE=$ARTIFACT_DIR/symbols-limit.txt
SYMBOLS_LIMIT_TABLE_B=$ARTIFACT_DIR/symbols-limit-b.txt
HISTORICAL_SYMBOLS_JSON=$ARTIFACT_DIR/historical-symbols.json
HISTORICAL_SYMBOLS_MD=$ARTIFACT_DIR/historical-symbols.md
HISTORICAL_SYMBOLS_TABLE=$ARTIFACT_DIR/historical-symbols.txt
SYMBOL_RELATIONSHIPS_JSON=$ARTIFACT_DIR/symbol-relationships.json
SYMBOL_RELATIONSHIPS_JSON_B=$ARTIFACT_DIR/symbol-relationships-b.json
SYMBOL_RELATIONSHIPS_MD=$ARTIFACT_DIR/symbol-relationships.md
SYMBOL_RELATIONSHIPS_MD_B=$ARTIFACT_DIR/symbol-relationships-b.md
SYMBOL_RELATIONSHIPS_TABLE=$ARTIFACT_DIR/symbol-relationships.txt
SYMBOL_RELATIONSHIPS_TABLE_B=$ARTIFACT_DIR/symbol-relationships-b.txt
SYMBOLS_UNSUPPORTED_JSON=$ARTIFACT_DIR/symbols-unsupported.json
SYMBOLS_SYMLINK_JSON=$ARTIFACT_DIR/symbols-symlink.json
PY_SYMBOLS_JSON=$ARTIFACT_DIR/python-symbols.json
PY_SYMBOLS_JSON_B=$ARTIFACT_DIR/python-symbols-b.json
PY_SYMBOLS_MD=$ARTIFACT_DIR/python-symbols.md
PY_SYMBOLS_TABLE=$ARTIFACT_DIR/python-symbols.txt
PY_SYMBOLS_LIMIT_JSON=$ARTIFACT_DIR/python-symbols-limit.json
PY_SYMBOLS_LIMIT_MD=$ARTIFACT_DIR/python-symbols-limit.md
PY_SYMBOLS_LIMIT_TABLE=$ARTIFACT_DIR/python-symbols-limit.txt
PY_SYMBOLS_EMPTY_JSON=$ARTIFACT_DIR/python-symbols-empty.json
PY_SYMBOLS_INVALID_JSON=$ARTIFACT_DIR/python-symbols-invalid.json
PY_SYMBOLS_GENERATED_JSON=$ARTIFACT_DIR/python-symbols-generated.json
PY_SYMBOLS_SYMLINK_JSON=$ARTIFACT_DIR/python-symbols-symlink.json
PY_SYMBOLS_LARGE_JSON=$ARTIFACT_DIR/python-symbols-large.json
PY_SYMBOLS_MISSING_JSON=$ARTIFACT_DIR/python-symbols-missing.json
PY_SYMBOLS_ALIAS_JSON=$ARTIFACT_DIR/python-symbols-alias.json
PY_SYMBOLS_OTHER_JSON=$ARTIFACT_DIR/python-symbols-other.json
PY_SYMBOLS_MARKDOWN_PATH_MD=$ARTIFACT_DIR/python-symbols-markdown-path.md
PY_LINE_HISTORY_JSON=$ARTIFACT_DIR/python-line-history.json
PY_LINE_HISTORY_JSON_B=$ARTIFACT_DIR/python-line-history-b.json
PY_LINE_HISTORY_SHALLOW_JSON=$ARTIFACT_DIR/python-line-history-shallow.json
PY_LINE_HISTORY_PARTIAL_JSON=$ARTIFACT_DIR/python-line-history-partial.json
PY_LINE_HISTORY_EMPTY_JSON=$ARTIFACT_DIR/python-line-history-empty.json
PY_LINE_HISTORY_INVALID_JSON=$ARTIFACT_DIR/python-line-history-invalid.json
PY_LINE_HISTORY_SYMLINK_JSON=$ARTIFACT_DIR/python-line-history-symlink.json
PY_LINE_HISTORY_LARGE_JSON=$ARTIFACT_DIR/python-line-history-large.json
PY_LINE_HISTORY_MISSING_JSON=$ARTIFACT_DIR/python-line-history-missing.json
PY_LINE_HISTORY_DIRTY_JSON=$ARTIFACT_DIR/python-line-history-dirty.json
PY_LINE_HISTORY_UNRELATED_JSON=$ARTIFACT_DIR/python-line-history-unrelated.json
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
printf 'validate: RUN CLI misuse matrix diagnostics\n'
if cli_misuse_matrix_checks; then
  note_fallback "cli misuse matrix: direct binary stderr checked for actionable cause, recovery shape where deterministic, help precedence, no full usage dump, and zig build run -- --symbol-line-history wrapper smoke"
  pass_rung "CLI misuse matrix diagnostics"
else
  fail_rung "CLI misuse matrix diagnostics" "parser diagnostic matrix failed"
fi
printf 'validate: RUN provider capability matrix drift checks\n'
if capability_matrix_checks; then
  note_fallback "provider capability matrix: python3 compared README/explain/help claims with supported and unsupported inspect behaviour"
  pass_rung "provider capability matrix drift checks"
else
  fail_rung "provider capability matrix drift checks" "documented capability matrix no longer matches inspect behaviour"
fi
printf 'validate: RUN prohibited claim scan\n'
if prohibited_claim_scan; then
  note_fallback "prohibited claim scan: python3 allowlist-aware line scan"
  pass_rung "prohibited claim scan"
else
  fail_rung "prohibited claim scan" "positive prohibited claim detected or python3 unavailable"
fi
printf 'validate: RUN docs and man surface checks\n'
if docs_manual_checks; then
  note_fallback "docs/man: presence, anchors, prohibited-claim coverage, and privacy scan"
  pass_rung "docs and man surface checks"
else
  fail_rung "docs and man surface checks" "documentation anchors or privacy surface checks failed"
fi
printf 'validate: RUN packaged dogfood surface checks\n'
if packaging_surface_checks; then
  note_fallback "packaged dogfood: local release script, ignored dist outputs, and unpublished Arch package anchors"
  pass_rung "packaged dogfood surface checks"
else
  fail_rung "packaged dogfood surface checks" "local release or Arch package surface checks failed"
fi
printf 'validate: RUN license and version consistency\n'
if license_version_checks; then
  pass_rung "license and version consistency"
else
  fail_rung "license and version consistency" "license, docs, fixtures, or CLI version contract failed"
fi
run_quiet "git diff whitespace check" git diff --check
run_quiet "shell syntax checks" sh -c "for file in tools/*.sh tests/*.sh; do sh -n \"\$file\" || exit 1; done"
printf 'validate: RUN runtime dependency scan\n'
if runtime_dependency_scan; then
  note_fallback "runtime dependency scan: python3 source scan for no network, Go toolchain, or global tree-sitter CLI commands"
  pass_rung "runtime dependency scan"
else
  fail_rung "runtime dependency scan" "forbidden runtime dependency command detected or python3 unavailable"
fi

printf 'validate: RUN deterministic fixture JSON and Markdown\n'
if fixture_json_checks; then
  pass_rung "deterministic fixture JSON and Markdown"
else
  fail_rung "deterministic fixture JSON and Markdown" "fixture output was invalid or unstable"
fi

printf 'validate: RUN JSON validity\n'
json_validity "JSON validity" "$BASIC_A" "$BASIC_B" "$BASIC_PROGRESS_JSON" "$BASIC_INSPECT_JSON" "$BASIC_INSPECT_PROGRESS_JSON" "$SYMBOLS_JSON" "$SYMBOLS_LIMIT_JSON" "$HISTORICAL_SYMBOLS_JSON" "$SYMBOL_RELATIONSHIPS_JSON" "$SYMBOL_RELATIONSHIPS_JSON_B" "$SYMBOLS_UNSUPPORTED_JSON" "$SYMBOLS_SYMLINK_JSON" "$PY_SYMBOLS_JSON" "$PY_SYMBOLS_JSON_B" "$PY_SYMBOLS_LIMIT_JSON" "$PY_SYMBOLS_EMPTY_JSON" "$PY_SYMBOLS_INVALID_JSON" "$PY_SYMBOLS_GENERATED_JSON" "$PY_SYMBOLS_SYMLINK_JSON" "$PY_SYMBOLS_LARGE_JSON" "$PY_SYMBOLS_MISSING_JSON" "$PY_SYMBOLS_ALIAS_JSON" "$PY_SYMBOLS_OTHER_JSON" "$PY_LINE_HISTORY_JSON" "$PY_LINE_HISTORY_JSON_B" "$PY_LINE_HISTORY_SHALLOW_JSON" "$PY_LINE_HISTORY_PARTIAL_JSON" "$PY_LINE_HISTORY_EMPTY_JSON" "$PY_LINE_HISTORY_INVALID_JSON" "$PY_LINE_HISTORY_SYMLINK_JSON" "$PY_LINE_HISTORY_LARGE_JSON" "$PY_LINE_HISTORY_MISSING_JSON" "$PY_LINE_HISTORY_DIRTY_JSON" "$PY_LINE_HISTORY_UNRELATED_JSON" "$SCOPE_UNFILTERED_JSON" "$SCOPE_ALL_JSON" "$SCOPE_FILTERED_JSON" "$SCOPE_PROJECT_JSON" "$SCOPE_PROJECT_JSON_B" "$SCOPE_PROJECT_PROGRESS_JSON" "$SCOPE_PROJECT_DUPLICATE_JSON" "$SCOPE_PROJECT_INCLUDE_FLOW_JSON" "$SCOPE_PROJECT_INCLUDE_NODE_JSON" "$SCOPE_ALL_INCLUDE_NODE_JSON" "$SCOPE_PROJECT_INCLUDE_SRC_JSON" "$SCOPE_PROJECT_INSPECT_JSON" "$SCOPE_PROJECT_INSPECT_PROGRESS_JSON" "$SCOPE_ALL_INSPECT_FLOW_JSON" "$SCOPE_ALL_INSPECT_INCLUDED_TO_EXCLUDED_JSON" "$SCOPE_ALL_INSPECT_EXCLUDED_TO_EXCLUDED_JSON" "$SCOPE_ALL_INSPECT_CHAINED_CROSS_JSON" "$SCOPE_PROJECT_INSPECT_INCLUDED_TO_EXCLUDED_JSON" "$SCOPE_PROJECT_INSPECT_CHAINED_CROSS_JSON" "$SCOPE_INSPECT_EXCLUDED_FLOW_JSON" "$SCOPE_INSPECT_RENAMED_JSON" "$SCOPE_SRC_INCLUDE_JSON" "$SCOPE_SRC_VENDOR_INCLUDE_JSON" "$SCOPE_INCLUDE_EXCLUDE_JSON" "$SCOPE_WEIRD_INCLUDE_JSON" "$SCOPE_GLOB_STAR_INCLUDE_JSON" "$SCOPE_GLOB_INCLUDE_JSON" "$SCOPE_INCLUDE_EMPTY_JSON" "$SCOPE_SRC_FILTERED_JSON" "$SCOPE_WEIRD_FILTERED_JSON" "$SCOPE_EMPTY_JSON" "$EDGE_INSPECT_TAB_JSON" "$SHALLOW_JSON" "$PARTIAL_JSON" "$SELF_JSON" "$SELF_SCOPED_JSON" || fail_rung "JSON validity" "no JSON checker succeeded"

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
printf 'local-only: no fetch, pull, push, upload, telemetry, remote enrichment, CI service, default provider runtime, cache requirement, package publishing, release automation, or remote release metadata; unpublished local Linux packaged dogfood uses ignored dist outputs only; opt-in Tree-sitter Zig, Go, Python, JavaScript, Lua, Rust, TypeScript, or TSX symbols are local current-file enrichment.\n'

if [ "$FAILURES" -ne 0 ]; then
  printf 'validate: %d rung(s) failed\n' "$FAILURES" >&2
  exit 1
fi

printf 'validate: all rungs passed\n'
