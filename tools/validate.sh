#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT" || exit 1

EXE=${1:-./zig-out/bin/git-hotspots}
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
print('results=%d caveats=%d dirty=%s scope_active=%s excluded_paths=%d excluded_changes=%d' % (
    len(data.get('results', [])),
    len(data.get('analysis', {}).get('caveats', [])),
    str(data.get('analysis', {}).get('history', {}).get('dirty_worktree', False)).lower(),
    str(scope.get('filters_active', False)).lower(),
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

semantic_assertions() {
  have_python || return 1
  python3 - "$BASIC_A" "$SHALLOW_JSON" "$PARTIAL_JSON" "$SELF_JSON" "$SELF_SCOPED_JSON" "$SCOPE_UNFILTERED_JSON" "$SCOPE_FILTERED_JSON" "$SCOPE_SRC_FILTERED_JSON" "$SCOPE_WEIRD_FILTERED_JSON" "$SCOPE_EMPTY_JSON" <<'PY'
import json, os, re, sys
basic_path, shallow_path, partial_path, self_path, self_scoped_path, scope_unfiltered_path, scope_filtered_path, scope_src_filtered_path, scope_weird_filtered_path, scope_empty_path = sys.argv[1:]

def load(path):
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)

basic = load(basic_path)
assert basic['results'], 'basic results missing'
assert basic['results'][0]['path'] == 'src/app.txt', 'unexpected basic top result'
assert basic['analysis']['scope']['filters_active'] is False, 'basic scope unexpectedly active'
assert all(not os.path.isabs(row['path']) for row in basic['results']), 'absolute basic result path'

scope_unfiltered = load(scope_unfiltered_path)
assert any(row['path'].startswith('.flow/') for row in scope_unfiltered.get('results', [])), 'unfiltered scope fixture lost .flow paths'
unfiltered_paths = [row['path'] for row in scope_unfiltered.get('results', [])]
assert 'src/new.zig' in unfiltered_paths, 'braced rename fixture missing normalized new path'
assert '' not in unfiltered_paths, 'empty path leaked from braced rename parsing'
assert 'weird/tab\tname.txt' in unfiltered_paths, 'quoted tab fixture missing unquoted path'

scope_filtered = load(scope_filtered_path)
scope = scope_filtered['analysis']['scope']
assert scope['filters_active'] is True, 'filtered scope metadata inactive'
assert scope['exclude_prefixes'] == ['.flow/'], 'filtered prefix order changed'
assert scope['excluded_path_count'] == 2, 'filtered path count changed'
assert scope['excluded_change_count'] == 5, 'filtered change count changed'
for row in scope_filtered.get('results', []):
    assert not row['path'].startswith('.flow/'), 'excluded result leaked'
    for cc in row.get('cochanges', []):
        assert not cc['path'].startswith('.flow/'), 'excluded cochange leaked'

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

self_scoped = load(self_scoped_path)
assert self_scoped['analysis']['scope']['filters_active'] is True, 'self scoped metadata inactive'
assert self_scoped['analysis']['scope']['exclude_prefixes'] == ['.flow/'], 'self scoped prefix changed'
for row in self_scoped.get('results', []):
    assert not row['path'].startswith('.flow/'), 'self scoped result leaked .flow path'
    for cc in row.get('cochanges', []):
        assert not cc['path'].startswith('.flow/'), 'self scoped cochange leaked .flow path'

shallow = load(shallow_path)
history = shallow['analysis']['history']
assert history['is_shallow'] is True, 'shallow fixture not reported as shallow'
assert history['auto_fetch'] is False, 'shallow fixture auto_fetch changed'

partial = load(partial_path)
history = partial['analysis']['history']
assert history['is_partial'] is True, 'partial fixture not reported as partial'
assert history['auto_fetch'] is False, 'partial fixture auto_fetch changed'

for path in (basic_path, self_path, self_scoped_path, scope_filtered_path, scope_src_filtered_path, scope_weird_filtered_path, scope_empty_path):
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
  python3 - "$BASIC_MD_A" "$BASIC_MD_B" "$SCOPE_FILTERED_MD" "$SCOPE_FILTERED_MD_B" "$SCOPE_EMPTY_MD" "$EDGE_MD" "$SELF_MARKDOWN" "$SELF_SCOPED_MARKDOWN" <<'PY'
import os, re, sys
from pathlib import Path

basic_a, basic_b, scope_filtered, scope_filtered_b, scope_empty, edge, self_md, self_scoped = [Path(p) for p in sys.argv[1:]]

def read(path):
    return path.read_text(encoding='utf-8')

basic = read(basic_a)
assert basic == read(basic_b), 'basic markdown repeated output changed'
for section in ['# git-hotspots report', '## Run summary', '## Scope', '## Caveats', '## Top hotspots', '## Evidence']:
    assert section in basic, section
assert 'File-level Git-history investigation prompts, not bug predictions or code-quality ratings.' in basic

scope = read(scope_filtered)
assert scope == read(scope_filtered_b), 'scope markdown repeated output changed'
assert '- Filters active: true' in scope, 'scope filter flag missing'
assert '- Exclude prefixes: .flow/' in scope, 'scope prefix missing'
assert '- Excluded path count: 2' in scope, 'scope excluded path count missing'
assert '- Excluded change count: 5' in scope, 'scope excluded change count missing'
for line in scope.splitlines():
    if line.startswith('| ') or line.startswith('### ') or line.startswith('  - '):
        assert '.flow/' not in line, 'filtered path leaked in scoped markdown: %r' % line

empty = read(scope_empty)
for section in ['## Run summary', '## Scope', '## Caveats', '## Top hotspots', '## Evidence']:
    assert section in empty, 'empty scoped markdown missing %s' % section
assert 'No hotspots matched the requested scope.' in empty, 'empty scoped top-hotspots note missing'
assert 'No result evidence to show.' in empty, 'empty scoped evidence note missing'

edge_text = read(edge)
assert 'weird/tab\\tname.txt' in edge_text, 'tab path was not escaped deterministically'
assert 'glob/\\[literal\\]\\*.txt' in edge_text, 'glob-like path markdown escaping missing'
assert 'path is deleted or not present at HEAD' in edge_text, 'deleted-file caveat missing'
assert 'binary or non\\-text churn unavailable for some changes' in edge_text, 'binary caveat missing'

self_scoped_text = read(self_scoped)
assert '- Filters active: true' in self_scoped_text, 'self scoped markdown lost scope flag'
assert '- Exclude prefixes: .flow/' in self_scoped_text, 'self scoped markdown lost prefix'
for line in self_scoped_text.splitlines():
    if line.startswith('| ') or line.startswith('### ') or line.startswith('  - '):
        assert '.flow/' not in line, 'self scoped markdown leaked .flow path: %r' % line

for text in [basic, scope, empty, edge_text, read(self_md), self_scoped_text]:
    assert '\t' not in text, 'raw tab leaked in markdown'
    assert 'Fixture Author' not in text, 'fixture author name leaked'
    assert 'fixture@example.invalid' not in text, 'fixture author email leaked'
    home = os.path.expanduser('~')
    assert not home or home not in text, 'home path leaked'
    assert not re.search(r'https?://|ssh://|git@', text), 'remote URL leaked'
    assert not re.search(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', text), 'email-like identity leaked'
PY
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
  tool=$(choose_timing_tool)
  case "$tool" in
    '/usr/bin/time -v')
      if /usr/bin/time -v "$EXE" --repo "$repo" --format json > "$output" 2> "$timing_file"; then
        elapsed=$(awk -F': ' '/Elapsed \(wall clock\) time/ {print $2; exit}' "$timing_file")
        [ -n "$elapsed" ] || elapsed="recorded"
        printf '%s|%s\n' "$tool" "$elapsed"
        return 0
      fi
      return 1
      ;;
    '/usr/bin/time -p')
      if /usr/bin/time -p "$EXE" --repo "$repo" --format json > "$output" 2> "$timing_file"; then
        elapsed=$(awk '/^real / {print $2 "s"; exit}' "$timing_file")
        [ -n "$elapsed" ] || elapsed="recorded"
        printf '%s|%s\n' "$tool" "$elapsed"
        return 0
      fi
      return 1
      ;;
    *)
      start=$(date +%s 2>/dev/null || printf '0')
      if "$EXE" --repo "$repo" --format json > "$output" 2> "$timing_file"; then
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
  "$EXE" --repo fixtures/basic --format json > "$BASIC_A" || return 1
  "$EXE" --repo fixtures/basic --format json > "$BASIC_B" || return 1
  diff -u fixtures/expected/basic.json "$BASIC_A" >/dev/null || return 1
  diff -u "$BASIC_A" "$BASIC_B" >/dev/null || return 1
  "$EXE" --repo fixtures/basic --format markdown > "$BASIC_MD_A" || return 1
  "$EXE" --repo fixtures/basic --format markdown > "$BASIC_MD_B" || return 1
  diff -u fixtures/expected/basic.md "$BASIC_MD_A" >/dev/null || return 1
  diff -u "$BASIC_MD_A" "$BASIC_MD_B" >/dev/null || return 1
  "$EXE" --repo fixtures/scope --format json > "$SCOPE_UNFILTERED_JSON" || return 1
  "$EXE" --repo fixtures/scope --exclude-prefix .flow/ --format json > "$SCOPE_FILTERED_JSON" || return 1
  diff -u fixtures/expected/scope-filtered.json "$SCOPE_FILTERED_JSON" >/dev/null || return 1
  "$EXE" --repo fixtures/scope --exclude-prefix .flow/ --format markdown > "$SCOPE_FILTERED_MD" || return 1
  "$EXE" --repo fixtures/scope --exclude-prefix .flow/ --format markdown > "$SCOPE_FILTERED_MD_B" || return 1
  diff -u fixtures/expected/scope-filtered.md "$SCOPE_FILTERED_MD" >/dev/null || return 1
  diff -u "$SCOPE_FILTERED_MD" "$SCOPE_FILTERED_MD_B" >/dev/null || return 1
  "$EXE" --repo fixtures/scope --exclude-prefix src/ --format json > "$SCOPE_SRC_FILTERED_JSON" || return 1
  "$EXE" --repo fixtures/scope --exclude-prefix weird/ --format json > "$SCOPE_WEIRD_FILTERED_JSON" || return 1
  "$EXE" --repo fixtures/scope --exclude-prefix .flow/ --exclude-prefix src/ --exclude-prefix vendor/ --exclude-prefix glob/ --exclude-prefix weird/ --format json > "$SCOPE_EMPTY_JSON" || return 1
  "$EXE" --repo fixtures/scope --exclude-prefix .flow/ --exclude-prefix src/ --exclude-prefix vendor/ --exclude-prefix glob/ --exclude-prefix weird/ --format markdown > "$SCOPE_EMPTY_MD" || return 1
  "$EXE" --repo fixtures/edge --limit 200 --format markdown > "$EDGE_MD" || return 1
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
  timing_file=$(mktemp "$ARTIFACT_DIR/real-time.XXXXXX")

  if "$EXE" --repo "$repo" --format table > "$table_out" 2> "$timing_file"; then
    table_status=pass
  else
    table_status=fail
  fi

  timing=$(run_timed_json "$repo" "$json_out" "$timing_file") || timing='timing failed|unknown'
  case "$timing" in
    'timing failed|unknown') json_status=fail ;;
    *) json_status=pass ;;
  esac

  if "$EXE" --repo "$repo" --format markdown > "$markdown_out" 2> "$timing_file"; then
    markdown_status=pass
  else
    markdown_status=fail
  fi

  if [ "$table_status" = pass ] && [ "$json_status" = pass ] && [ "$markdown_status" = pass ]; then
    summary=$(json_count_summary "$json_out") || summary='results=unknown caveats=unknown dirty=unknown'
    elapsed=${timing#*|}
    printf 'real-repo label=%s table=%s json=%s markdown=%s %s elapsed=%s\n' "$label" "$table_status" "$json_status" "$markdown_status" "$summary" "$elapsed" >> "$SMOKES"
    pass_rung "real repo smoke $label"
    return 0
  fi

  fail_rung "real repo smoke $label" "table=$table_status json=$json_status markdown=$markdown_status"
  return 1
}

BASIC_A=$ARTIFACT_DIR/basic-a.json
BASIC_B=$ARTIFACT_DIR/basic-b.json
BASIC_MD_A=$ARTIFACT_DIR/basic-a.md
BASIC_MD_B=$ARTIFACT_DIR/basic-b.md
SCOPE_UNFILTERED_JSON=$ARTIFACT_DIR/scope-unfiltered.json
SCOPE_FILTERED_JSON=$ARTIFACT_DIR/scope-filtered.json
SCOPE_FILTERED_MD=$ARTIFACT_DIR/scope-filtered.md
SCOPE_FILTERED_MD_B=$ARTIFACT_DIR/scope-filtered-b.md
SCOPE_SRC_FILTERED_JSON=$ARTIFACT_DIR/scope-src-filtered.json
SCOPE_WEIRD_FILTERED_JSON=$ARTIFACT_DIR/scope-weird-filtered.json
SCOPE_EMPTY_JSON=$ARTIFACT_DIR/scope-empty.json
SCOPE_EMPTY_MD=$ARTIFACT_DIR/scope-empty.md
SHALLOW_JSON=$ARTIFACT_DIR/shallow.json
PARTIAL_JSON=$ARTIFACT_DIR/partial.json
EDGE_MD=$ARTIFACT_DIR/edge.md
SELF_JSON=$ARTIFACT_DIR/self.json
SELF_SCOPED_JSON=$ARTIFACT_DIR/self-scoped.json
SELF_MARKDOWN=$ARTIFACT_DIR/self.md
SELF_SCOPED_MARKDOWN=$ARTIFACT_DIR/self-scoped.md

run_quiet "format check" zig fmt --check build.zig src tests
run_quiet "fast gate: zig build test" zig build test
run_quiet "build executable: zig build" zig build
run_quiet "help text smoke" "$EXE" --help
run_quiet "git diff whitespace check" git diff --check
run_quiet "shell syntax checks" sh -c "for file in tools/*.sh tests/*.sh; do sh -n \"\$file\" || exit 1; done"

printf 'validate: RUN deterministic fixture JSON and Markdown\n'
if fixture_json_checks; then
  pass_rung "deterministic fixture JSON and Markdown"
else
  fail_rung "deterministic fixture JSON and Markdown" "fixture output was invalid or unstable"
fi

printf 'validate: RUN JSON validity\n'
json_validity "JSON validity" "$BASIC_A" "$BASIC_B" "$SCOPE_UNFILTERED_JSON" "$SCOPE_FILTERED_JSON" "$SCOPE_SRC_FILTERED_JSON" "$SCOPE_WEIRD_FILTERED_JSON" "$SCOPE_EMPTY_JSON" "$SHALLOW_JSON" "$PARTIAL_JSON" "$SELF_JSON" "$SELF_SCOPED_JSON" || fail_rung "JSON validity" "no JSON checker succeeded"

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
printf 'local-only: no fetch, pull, push, upload, telemetry, remote enrichment, CI service, provider runtime, cache requirement, packaging, or release automation.\n'

if [ "$FAILURES" -ne 0 ]; then
  printf 'validate: %d rung(s) failed\n' "$FAILURES" >&2
  exit 1
fi

printf 'validate: all rungs passed\n'
