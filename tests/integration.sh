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
  if grep -q -- '^Usage:' "$err"; then
    echo "$label stderr unexpectedly dumped full help" >&2
    exit 1
  fi
}

assert_progress_stderr() {
  label=$1
  err=$2
  if ! grep -q -- 'progress: checking repository' "$err"; then
    echo "$label stderr missing checking repository phase" >&2
    exit 1
  fi
  if ! grep -q -- 'progress: reading Git history' "$err"; then
    echo "$label stderr missing reading Git history phase" >&2
    exit 1
  fi
  if ! grep -q -- 'progress: scoring files' "$err"; then
    echo "$label stderr missing scoring files phase" >&2
    exit 1
  fi
  if ! grep -q -- 'progress: rendering report' "$err"; then
    echo "$label stderr missing rendering report phase" >&2
    exit 1
  fi
  if ! grep -Eq '^progress: done in [0-9]+ms$' "$err"; then
    echo "$label stderr missing bounded elapsed line" >&2
    exit 1
  fi
  esc=$(printf '\033')
  cr=$(printf '\r')
  if LC_ALL=C grep -Eq '/|@|https?://|ssh://|git@|[0-9a-f]{12,40}' "$err" || LC_ALL=C grep -q '\\' "$err"; then
    echo "$label stderr failed progress privacy scan" >&2
    exit 1
  fi
  if LC_ALL=C grep -q "$esc" "$err" || LC_ALL=C grep -q "$cr" "$err"; then
    echo "$label stderr contained terminal control characters" >&2
    exit 1
  fi
}

ctrl=$(printf 'bad\001path')

sh tools/setup-fixtures.sh
PROJECT_EXCLUDE_ARGS="--exclude-prefix .flow/ --exclude-prefix .zig-cache/ --exclude-prefix zig-out/ --exclude-prefix target/ --exclude-prefix node_modules/ --exclude-prefix dist/ --exclude-prefix build/ --exclude-prefix coverage/"

tmp_dir=$(mktemp -d)
export TMP_DIR=$tmp_dir
cleanup_tmp_dir() {
  rm -rf "$tmp_dir"
}
trap cleanup_tmp_dir EXIT HUP INT TERM

"$EXE" --explain > "$tmp_dir/git-hotspots-explain.txt"
diff -u fixtures/expected/explain.txt "$tmp_dir/git-hotspots-explain.txt"
"$EXE" --explain > "$tmp_dir/git-hotspots-explain-2.txt"
diff -u "$tmp_dir/git-hotspots-explain.txt" "$tmp_dir/git-hotspots-explain-2.txt"
"$EXE" --help > "$tmp_dir/git-hotspots-help.txt"
grep -q -- "--explain" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "--version" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "--inspect PATH" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "--scope VALUE" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "project (default) or all" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "--progress" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "--symbols" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "--symbol-line-history" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "--symbol-limit N" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "-h, --help" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "Examples:" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "Local-first/no-telemetry boundaries:" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "Hotspots are investigation prompts" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "Provider capability:" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "current working-tree symbol evidence" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "no Cargo, crates, module" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "macro expansion, cfg/feature evaluation, type checking" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "dependency graphs, or semantic Rust analysis" "$tmp_dir/git-hotspots-help.txt"
grep -q -- "not true symbol history" "$tmp_dir/git-hotspots-help.txt"
"$EXE" -h > "$tmp_dir/git-hotspots-help-short.txt" 2> "$tmp_dir/git-hotspots-help-short.err"
diff -u "$tmp_dir/git-hotspots-help.txt" "$tmp_dir/git-hotspots-help-short.txt"
test ! -s "$tmp_dir/git-hotspots-help-short.err"
"$EXE" --progress --help > "$tmp_dir/git-hotspots-progress-help.txt" 2> "$tmp_dir/git-hotspots-progress-help.err"
grep -q -- "--progress" "$tmp_dir/git-hotspots-progress-help.txt"
test ! -s "$tmp_dir/git-hotspots-progress-help.err"
"$EXE" --symbols --help > "$tmp_dir/git-hotspots-symbols-help.txt" 2> "$tmp_dir/git-hotspots-symbols-help.err"
diff -u "$tmp_dir/git-hotspots-help.txt" "$tmp_dir/git-hotspots-symbols-help.txt"
test ! -s "$tmp_dir/git-hotspots-symbols-help.err"
"$EXE" --repo --help > "$tmp_dir/git-hotspots-repo-help.txt" 2> "$tmp_dir/git-hotspots-repo-help.err"
diff -u "$tmp_dir/git-hotspots-help.txt" "$tmp_dir/git-hotspots-repo-help.txt"
test ! -s "$tmp_dir/git-hotspots-repo-help.err"
"$EXE" --version > "$tmp_dir/git-hotspots-version.txt" 2> "$tmp_dir/git-hotspots-version.err"
test "$(cat "$tmp_dir/git-hotspots-version.txt")" = "git-hotspots 0.1.0-alpha.1"
test ! -s "$tmp_dir/git-hotspots-version.err"
explain_nongit=$(mktemp -d)
(cd "$explain_nongit" && "$EXE_ABS" --explain > "$tmp_dir/git-hotspots-explain-nongit.txt" 2> "$tmp_dir/git-hotspots-explain-nongit.err")
diff -u fixtures/expected/explain.txt "$tmp_dir/git-hotspots-explain-nongit.txt"
test ! -s "$tmp_dir/git-hotspots-explain-nongit.err"
version_nongit=$(mktemp -d)
(cd "$version_nongit" && "$EXE_ABS" --version > "$tmp_dir/git-hotspots-version-nongit.txt" 2> "$tmp_dir/git-hotspots-version-nongit.err")
test "$(cat "$tmp_dir/git-hotspots-version-nongit.txt")" = "git-hotspots 0.1.0-alpha.1"
test ! -s "$tmp_dir/git-hotspots-version-nongit.err"
help_nongit=$(mktemp -d)
(cd "$help_nongit" && "$EXE_ABS" -h > "$tmp_dir/git-hotspots-help-nongit.txt" 2> "$tmp_dir/git-hotspots-help-nongit.err")
diff -u "$tmp_dir/git-hotspots-help.txt" "$tmp_dir/git-hotspots-help-nongit.txt"
test ! -s "$tmp_dir/git-hotspots-help-nongit.err"
assert_fails_with_stderr explain-repo "--explain cannot be combined" "$EXE" --explain --repo .
assert_fails_with_stderr explain-limit "--explain cannot be combined" "$EXE" --explain --limit 1
assert_fails_with_stderr explain-format "--explain cannot be combined" "$EXE" --explain --format markdown
assert_fails_with_stderr explain-since "--explain cannot be combined" "$EXE" --explain --since HEAD~1
assert_fails_with_stderr explain-scope "--explain cannot be combined" "$EXE" --explain --scope project
assert_fails_with_stderr explain-include "--explain cannot be combined" "$EXE" --explain --include-prefix src/
assert_fails_with_stderr explain-exclude "--explain cannot be combined" "$EXE" --explain --exclude-prefix .flow/
assert_fails_with_stderr explain-inspect "--explain cannot be combined" "$EXE" --explain --inspect src/app.txt
assert_fails_with_stderr explain-progress "--explain cannot be combined" "$EXE" --explain --progress
assert_fails_with_stderr progress-explain "--explain cannot be combined" "$EXE" --progress --explain
assert_fails_with_stderr version-repo "--version cannot be combined" "$EXE" --version --repo .
assert_fails_with_stderr version-limit "--version cannot be combined" "$EXE" --version --limit 1
assert_fails_with_stderr version-format "--version cannot be combined" "$EXE" --version --format markdown
assert_fails_with_stderr version-since "--version cannot be combined" "$EXE" --version --since HEAD~1
assert_fails_with_stderr version-scope "--version cannot be combined" "$EXE" --version --scope project
assert_fails_with_stderr version-include "--version cannot be combined" "$EXE" --version --include-prefix src/
assert_fails_with_stderr version-exclude "--version cannot be combined" "$EXE" --version --exclude-prefix .flow/
assert_fails_with_stderr version-explain "--version cannot be combined" "$EXE" --version --explain
assert_fails_with_stderr version-inspect "--version cannot be combined" "$EXE" --version --inspect src/app.txt
assert_fails_with_stderr version-progress "--version cannot be combined" "$EXE" --version --progress
assert_fails_with_stderr progress-version "--version cannot be combined" "$EXE" --progress --version
assert_fails_with_stderr version-progress "--version cannot be combined" "$EXE" --version --progress
assert_fails_with_stderr repo-missing "--repo requires a local Git worktree path" "$EXE" --repo
assert_fails_with_stderr limit-missing "--limit requires a positive integer value" "$EXE" --limit
assert_fails_with_stderr limit-invalid "--limit must be a positive integer" "$EXE" --limit nope
assert_fails_with_stderr limit-zero "--limit must be a positive integer" "$EXE" --limit 0
assert_fails_with_stderr format-missing "--format requires a value" "$EXE" --format
assert_fails_with_stderr format-invalid "--format accepts one value" "$EXE" --format xml
assert_fails_with_stderr since-missing "--since requires a Git revision" "$EXE" --since
assert_fails_with_stderr scope-missing "--scope accepts one lowercase value" "$EXE" --scope
assert_fails_with_stderr scope-invalid "--scope accepts one lowercase value" "$EXE" --scope unknown
assert_fails_with_stderr include-missing "--include-prefix requires a repo-relative path prefix" "$EXE" --include-prefix
assert_fails_with_stderr exclude-missing "--exclude-prefix requires a repo-relative path prefix" "$EXE" --exclude-prefix
assert_fails_with_stderr inspect-missing "--inspect requires an exact repo-relative Git path" "$EXE" --inspect
assert_fails_with_stderr unknown-flag "unknown option" "$EXE" --wat
assert_fails_with_stderr unexpected-positional "unexpected positional argument" "$EXE" fixtures/basic
assert_fails_with_stderr inspect-limit "--limit cannot be combined with --inspect" "$EXE" --repo fixtures/basic --inspect src/app.txt --limit 1
assert_fails_with_stderr symbols-explain "--explain cannot be combined" "$EXE" --symbols --explain
assert_fails_with_stderr symbols-version "--version cannot be combined" "$EXE" --symbols --version
assert_fails_with_stderr symbol-line-history-alone "--symbol-line-history requires --symbols" "$EXE" --symbol-line-history
assert_fails_with_stderr symbol-line-history-no-symbols "--symbol-line-history requires --symbols" "$EXE" --inspect src/app.zig --symbol-line-history
assert_fails_with_stderr symbol-line-history-explain "--explain cannot be combined" "$EXE" --symbol-line-history --explain
assert_fails_with_stderr symbol-line-history-version "--version cannot be combined" "$EXE" --symbol-line-history --version
assert_fails_with_stderr symbol-limit-alone "--symbol-limit requires --symbols" "$EXE" --symbol-limit 1
assert_fails_with_stderr symbol-limit-no-symbols "--symbol-limit requires --symbols" "$EXE" --inspect src/app.zig --symbol-limit 1
assert_fails_with_stderr symbol-limit-missing "--symbol-limit must be a positive integer" "$EXE" --inspect src/app.zig --symbols --symbol-limit
assert_fails_with_stderr symbol-limit-zero "--symbol-limit must be a positive integer" "$EXE" --inspect src/app.zig --symbols --symbol-limit 0
assert_fails_with_stderr symbol-limit-invalid "--symbol-limit must be a positive integer" "$EXE" --inspect src/app.zig --symbols --symbol-limit nope

"$EXE" --repo fixtures/basic --format json > "$tmp_dir/git-hotspots-basic.json" 2> "$tmp_dir/git-hotspots-basic.err"
test ! -s "$tmp_dir/git-hotspots-basic.err"
diff -u fixtures/expected/basic.json "$tmp_dir/git-hotspots-basic.json"
"$EXE" --repo fixtures/basic --progress --format json > "$tmp_dir/git-hotspots-basic-progress.json" 2> "$tmp_dir/git-hotspots-basic-progress.err"
diff -u "$tmp_dir/git-hotspots-basic.json" "$tmp_dir/git-hotspots-basic-progress.json"
assert_progress_stderr basic-json "$tmp_dir/git-hotspots-basic-progress.err"
"$EXE" --repo fixtures/basic --format json > "$tmp_dir/git-hotspots-basic-2.json"
diff -u "$tmp_dir/git-hotspots-basic.json" "$tmp_dir/git-hotspots-basic-2.json"
"$EXE" --repo fixtures/basic --format markdown > "$tmp_dir/git-hotspots-basic.md"
diff -u fixtures/expected/basic.md "$tmp_dir/git-hotspots-basic.md"
"$EXE" --repo fixtures/basic --progress --format markdown > "$tmp_dir/git-hotspots-basic-progress.md" 2> "$tmp_dir/git-hotspots-basic-progress-md.err"
diff -u "$tmp_dir/git-hotspots-basic.md" "$tmp_dir/git-hotspots-basic-progress.md"
assert_progress_stderr basic-markdown "$tmp_dir/git-hotspots-basic-progress-md.err"
"$EXE" --repo fixtures/basic --format markdown > "$tmp_dir/git-hotspots-basic-2.md"
diff -u "$tmp_dir/git-hotspots-basic.md" "$tmp_dir/git-hotspots-basic-2.md"
"$EXE" --repo fixtures/basic --format table > "$tmp_dir/git-hotspots-basic.txt"
"$EXE" --repo fixtures/basic --progress --format table > "$tmp_dir/git-hotspots-basic-progress.txt" 2> "$tmp_dir/git-hotspots-basic-progress-table.err"
diff -u "$tmp_dir/git-hotspots-basic.txt" "$tmp_dir/git-hotspots-basic-progress.txt"
assert_progress_stderr basic-table "$tmp_dir/git-hotspots-basic-progress-table.err"
"$EXE" --repo fixtures/basic --inspect src/app.txt --format json > "$tmp_dir/git-hotspots-basic-inspect.json"
diff -u fixtures/expected/basic-inspect.json "$tmp_dir/git-hotspots-basic-inspect.json"
"$EXE" --repo fixtures/basic --progress --inspect src/app.txt --format json > "$tmp_dir/git-hotspots-basic-inspect-progress.json" 2> "$tmp_dir/git-hotspots-basic-inspect-progress.err"
diff -u "$tmp_dir/git-hotspots-basic-inspect.json" "$tmp_dir/git-hotspots-basic-inspect-progress.json"
assert_progress_stderr basic-inspect "$tmp_dir/git-hotspots-basic-inspect-progress.err"
"$EXE" --repo fixtures/basic --inspect src/app.txt --format json > "$tmp_dir/git-hotspots-basic-inspect-2.json"
diff -u "$tmp_dir/git-hotspots-basic-inspect.json" "$tmp_dir/git-hotspots-basic-inspect-2.json"
"$EXE" --repo fixtures/basic --inspect src/app.txt --format markdown > "$tmp_dir/git-hotspots-basic-inspect.md"
diff -u fixtures/expected/basic-inspect.md "$tmp_dir/git-hotspots-basic-inspect.md"
"$EXE" --repo fixtures/basic --inspect src/app.txt --format table > "$tmp_dir/git-hotspots-basic-inspect.txt"
diff -u fixtures/expected/basic-inspect.txt "$tmp_dir/git-hotspots-basic-inspect.txt"
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --format json > "$tmp_dir/git-hotspots-symbols-inspect-symbols.json"
diff -u fixtures/expected/symbols-inspect-symbols.json "$tmp_dir/git-hotspots-symbols-inspect-symbols.json"
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --format markdown > "$tmp_dir/git-hotspots-symbols-inspect-symbols.md"
diff -u fixtures/expected/symbols-inspect-symbols.md "$tmp_dir/git-hotspots-symbols-inspect-symbols.md"
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --format table > "$tmp_dir/git-hotspots-symbols-inspect-symbols.txt"
diff -u fixtures/expected/symbols-inspect-symbols.txt "$tmp_dir/git-hotspots-symbols-inspect-symbols.txt"
"$EXE" --repo fixtures/symbols --symbols --symbol-limit 3 --format json > "$tmp_dir/git-hotspots-symbols-project.json"
python3 - "$tmp_dir/git-hotspots-symbols-project.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
project = data['project_symbols']
assert project['current_only'] is True
assert project['summary']['file_count'] == 3
assert project['summary']['unsupported_count'] == 1
assert project['summary']['unavailable_count'] == 1
assert project['human_display']['total_count'] == 3
assert project['human_display']['shown_count'] == 3
assert project['files'][0]['path'] == 'src/example.zig'
assert [item['name'] for item in project['files'][0]['items']] == ['alpha', 'zebra']
assert all('parent_rank' in item and 'parent_score' in item for f in project['files'] for item in f['items'])
assert 'symbols' not in data
PY
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format json > "$tmp_dir/git-hotspots-symbols-limit-json.json"
python3 - "$tmp_dir/git-hotspots-symbols-limit-json.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
assert len(data['symbols']['items']) == 2
assert data['symbols']['human_display']['shown_count'] == 1
assert data['symbols']['human_display']['omitted_count'] == 1
assert data['symbols']['human_display']['active_limit'] == 1
assert data['symbols']['human_display']['limit_source'] == 'explicit'
PY
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format markdown > "$tmp_dir/git-hotspots-symbols-limit.md"
diff -u fixtures/expected/symbols-limit.md "$tmp_dir/git-hotspots-symbols-limit.md"
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format markdown > "$tmp_dir/git-hotspots-symbols-limit-2.md"
diff -u "$tmp_dir/git-hotspots-symbols-limit.md" "$tmp_dir/git-hotspots-symbols-limit-2.md"
grep -Fq -- '- Total symbols: 2' "$tmp_dir/git-hotspots-symbols-limit.md"
grep -Fq -- '- Shown symbols: 1' "$tmp_dir/git-hotspots-symbols-limit.md"
grep -Fq -- '- Omitted symbols: 1' "$tmp_dir/git-hotspots-symbols-limit.md"
! grep -Fq -- 'zebra' "$tmp_dir/git-hotspots-symbols-limit.md"
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format table > "$tmp_dir/git-hotspots-symbols-limit.txt"
diff -u fixtures/expected/symbols-limit.txt "$tmp_dir/git-hotspots-symbols-limit.txt"
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format table > "$tmp_dir/git-hotspots-symbols-limit-2.txt"
diff -u "$tmp_dir/git-hotspots-symbols-limit.txt" "$tmp_dir/git-hotspots-symbols-limit-2.txt"
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-symbols-line-history.json"
python3 -m json.tool "$tmp_dir/git-hotspots-symbols-line-history.json" >/dev/null
grep -Fq -- '"current_line_history"' "$tmp_dir/git-hotspots-symbols-line-history.json"
grep -Fq -- '"basis": "current-line-range-at-head"' "$tmp_dir/git-hotspots-symbols-line-history.json"
grep -Fq -- '"distinct_last_touch_commit_count": 1' "$tmp_dir/git-hotspots-symbols-line-history.json"
! grep -Eiq -- 'Fixture Author|fixture@example|expand zig function|initial symbol files|file://' "$tmp_dir/git-hotspots-symbols-line-history.json"
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-line-history --format markdown > "$tmp_dir/git-hotspots-symbols-line-history.md"
grep -Fq -- 'Current-line Git evidence' "$tmp_dir/git-hotspots-symbols-line-history.md"
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-line-history --format table > "$tmp_dir/git-hotspots-symbols-line-history.txt"
grep -Fq -- 'Current-line Git evidence: commits=1' "$tmp_dir/git-hotspots-symbols-line-history.txt"
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-line-history-success.json"
diff -u fixtures/expected/line-history-success.json "$tmp_dir/git-hotspots-line-history-success.json"
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-line-history-success-2.json"
diff -u "$tmp_dir/git-hotspots-line-history-success.json" "$tmp_dir/git-hotspots-line-history-success-2.json"
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format markdown > "$tmp_dir/git-hotspots-line-history-success.md"
diff -u fixtures/expected/line-history-success.md "$tmp_dir/git-hotspots-line-history-success.md"
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format table > "$tmp_dir/git-hotspots-line-history-success.txt"
diff -u fixtures/expected/line-history-success.txt "$tmp_dir/git-hotspots-line-history-success.txt"
"$EXE" --repo fixtures/symbol-line-history --symbols --symbol-line-history --symbol-limit 5 --format json > "$tmp_dir/git-hotspots-line-history-project.json"
python3 - "$tmp_dir/git-hotspots-line-history-project.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
project = data['project_symbols']
current = project['files'][0]
assert current['path'] == 'src/current.zig'
assert [item['name'] for item in current['items']] == ['beta', 'alpha', 'gamma']
assert all('current_line_history' in item for item in current['items'])
assert all(item['current_line_history']['current_only'] is True for item in current['items'])
assert project['summary']['unsupported_count'] == 1
assert project['summary']['unavailable_count'] == 1
assert project['summary']['failed_count'] == 1
assert data['results'][0]['path'] == current['path']
PY
"$EXE" --repo fixtures/symbol-line-history-shallow --inspect src/current.zig --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-line-history-shallow.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$tmp_dir/git-hotspots-line-history-shallow.json"
"$EXE" --repo fixtures/symbol-line-history-partial --inspect src/current.zig --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-line-history-partial.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$tmp_dir/git-hotspots-line-history-partial.json"
"$EXE" --repo fixtures/symbol-line-history --inspect src/readme.txt --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-line-history-unsupported.json"
grep -Fq -- '"failure": "unsupported"' "$tmp_dir/git-hotspots-line-history-unsupported.json"
! grep -Fq -- '"current_line_history"' "$tmp_dir/git-hotspots-line-history-unsupported.json"
"$EXE" --repo fixtures/symbol-line-history --inspect src/empty.zig --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-line-history-empty.json"
grep -Fq -- '"items": [' "$tmp_dir/git-hotspots-line-history-empty.json"
! grep -Fq -- '"current_line_history"' "$tmp_dir/git-hotspots-line-history-empty.json"
"$EXE" --repo fixtures/symbol-line-history --inspect src/broken.zig --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-line-history-broken.json"
grep -Eq -- '"failure": "(failed|ok)"' "$tmp_dir/git-hotspots-line-history-broken.json"
"$EXE" --repo fixtures/symbol-line-history --inspect src/link.zig --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-line-history-link.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-line-history-link.json"
printf 'dirty inspected\n' >> fixtures/symbol-line-history/src/current.zig
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-line-history-dirty-inspected.json"
grep -Fq -- 'current-line Git evidence skipped: inspected file has staged or unstaged content changes' "$tmp_dir/git-hotspots-line-history-dirty-inspected.json"
git -C fixtures/symbol-line-history checkout -q -- src/current.zig
printf 'dirty unrelated\n' >> fixtures/symbol-line-history/src/readme.txt
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-line-history-dirty-unrelated.json"
grep -Fq -- '"failure": "ok"' "$tmp_dir/git-hotspots-line-history-dirty-unrelated.json"
git -C fixtures/symbol-line-history checkout -q -- src/readme.txt
! grep -Eiq -- 'Fixture Author|fixture@example|fixture function|private|file://|raw blame|source line|previous filename|ownership|productivity|developer ranking' "$tmp_dir/git-hotspots-symbols-inspect-symbols.json" "$tmp_dir/git-hotspots-symbols-inspect-symbols.md" "$tmp_dir/git-hotspots-symbols-inspect-symbols.txt" "$tmp_dir/git-hotspots-symbols-project.json" "$tmp_dir/git-hotspots-symbols-limit-json.json" "$tmp_dir/git-hotspots-symbols-limit.md" "$tmp_dir/git-hotspots-symbols-limit.txt" "$tmp_dir/git-hotspots-line-history-success.json" "$tmp_dir/git-hotspots-line-history-success.md" "$tmp_dir/git-hotspots-line-history-success.txt" "$tmp_dir/git-hotspots-line-history-project.json" "$tmp_dir/git-hotspots-line-history-shallow.json" "$tmp_dir/git-hotspots-line-history-partial.json" "$tmp_dir/git-hotspots-line-history-unsupported.json" "$tmp_dir/git-hotspots-line-history-empty.json" "$tmp_dir/git-hotspots-line-history-broken.json" "$tmp_dir/git-hotspots-line-history-link.json" "$tmp_dir/git-hotspots-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-line-history-dirty-unrelated.json" fixtures/expected/symbols-inspect-symbols.json fixtures/expected/symbols-inspect-symbols.md fixtures/expected/symbols-inspect-symbols.txt fixtures/expected/symbols-limit.md fixtures/expected/symbols-limit.txt fixtures/expected/line-history-success.json fixtures/expected/line-history-success.md fixtures/expected/line-history-success.txt
assert_fails_with_stderr symbol-line-history-alone "--symbol-line-history requires --symbols" "$EXE" --symbol-line-history
assert_fails_with_stderr symbol-line-history-no-symbols "--symbol-line-history requires --symbols" "$EXE" --repo fixtures/symbols --inspect src/example.zig --symbol-line-history
"$EXE" --repo fixtures/symbols --inspect src/readme.txt --symbols --format json > "$tmp_dir/git-hotspots-symbols-unsupported.json"
diff -u fixtures/expected/symbols-unsupported.json "$tmp_dir/git-hotspots-symbols-unsupported.json"
"$EXE" --repo fixtures/symbols --inspect src/link.zig --symbols --format json > "$tmp_dir/git-hotspots-symbols-symlink-unavailable.json"
diff -u fixtures/expected/symbols-symlink-unavailable.json "$tmp_dir/git-hotspots-symbols-symlink-unavailable.json"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format json > "$tmp_dir/git-hotspots-go-symbols.json"
diff -u fixtures/expected/go-symbols.json "$tmp_dir/git-hotspots-go-symbols.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-go-symbols.json"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format markdown > "$tmp_dir/git-hotspots-go-symbols.md"
diff -u fixtures/expected/go-symbols.md "$tmp_dir/git-hotspots-go-symbols.md"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format table > "$tmp_dir/git-hotspots-go-symbols.txt"
diff -u fixtures/expected/go-symbols.txt "$tmp_dir/git-hotspots-go-symbols.txt"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format json > "$tmp_dir/git-hotspots-go-symbols-2.json"
diff -u "$tmp_dir/git-hotspots-go-symbols.json" "$tmp_dir/git-hotspots-go-symbols-2.json"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format markdown > "$tmp_dir/git-hotspots-go-symbols-2.md"
diff -u "$tmp_dir/git-hotspots-go-symbols.md" "$tmp_dir/git-hotspots-go-symbols-2.md"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format table > "$tmp_dir/git-hotspots-go-symbols-2.txt"
diff -u "$tmp_dir/git-hotspots-go-symbols.txt" "$tmp_dir/git-hotspots-go-symbols-2.txt"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-limit 2 --format json > "$tmp_dir/git-hotspots-go-symbols-limit.json"
diff -u fixtures/expected/go-symbols-limit.json "$tmp_dir/git-hotspots-go-symbols-limit.json"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-limit 2 --format markdown > "$tmp_dir/git-hotspots-go-symbols-limit.md"
diff -u fixtures/expected/go-symbols-limit.md "$tmp_dir/git-hotspots-go-symbols-limit.md"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-limit 2 --format table > "$tmp_dir/git-hotspots-go-symbols-limit.txt"
diff -u fixtures/expected/go-symbols-limit.txt "$tmp_dir/git-hotspots-go-symbols-limit.txt"
"$EXE" --repo fixtures/symbols --inspect src/readme.txt --symbols --format json > "$tmp_dir/git-hotspots-go-symbols-unsupported.json"
diff -u fixtures/expected/symbols-unsupported.json "$tmp_dir/git-hotspots-go-symbols-unsupported.json"
"$EXE" --repo fixtures/go-symbols --inspect src/empty.go --symbols --format json > "$tmp_dir/git-hotspots-go-symbols-empty.json"
diff -u fixtures/expected/go-symbols-empty.json "$tmp_dir/git-hotspots-go-symbols-empty.json"
"$EXE" --repo fixtures/go-symbols --inspect src/broken.go --symbols --format json > "$tmp_dir/git-hotspots-go-symbols-invalid.json"
diff -u fixtures/expected/go-symbols-invalid.json "$tmp_dir/git-hotspots-go-symbols-invalid.json"
"$EXE" --repo fixtures/go-symbols --inspect src/caveated.go --symbols --format json > "$tmp_dir/git-hotspots-go-symbols-caveated.json"
diff -u fixtures/expected/go-symbols-caveated.json "$tmp_dir/git-hotspots-go-symbols-caveated.json"
"$EXE" --repo fixtures/go-symbols --inspect src/link.go --symbols --format json > "$tmp_dir/git-hotspots-go-symbols-symlink-unavailable.json"
diff -u fixtures/expected/go-symbols-symlink-unavailable.json "$tmp_dir/git-hotspots-go-symbols-symlink-unavailable.json"
"$EXE" --repo fixtures/go-symbols --inspect src/large.go --symbols --format json > "$tmp_dir/git-hotspots-go-symbols-large-unavailable.json"
diff -u fixtures/expected/go-symbols-large-unavailable.json "$tmp_dir/git-hotspots-go-symbols-large-unavailable.json"
"$EXE" --repo fixtures/go-symbols --inspect src/missing.go --symbols --format json > "$tmp_dir/git-hotspots-go-symbols-missing-unavailable.json"
diff -u fixtures/expected/go-symbols-missing-unavailable.json "$tmp_dir/git-hotspots-go-symbols-missing-unavailable.json"
"$EXE" --repo fixtures/go-symbols --inspect src/old-example.go --symbols --format json > "$tmp_dir/git-hotspots-go-symbols-rename-alias.json"
diff -u fixtures/expected/go-symbols-rename-alias.json "$tmp_dir/git-hotspots-go-symbols-rename-alias.json"
"$EXE" --repo fixtures/go-symbols --inspect src/other.go --symbols --format json > "$tmp_dir/git-hotspots-go-symbols-other.json"
! grep -Fq -- 'Zebra' "$tmp_dir/git-hotspots-go-symbols-other.json"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-success.json"
diff -u fixtures/expected/go-line-history-success.json "$tmp_dir/git-hotspots-go-line-history-success.json"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-success-2.json"
diff -u "$tmp_dir/git-hotspots-go-line-history-success.json" "$tmp_dir/git-hotspots-go-line-history-success-2.json"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format markdown > "$tmp_dir/git-hotspots-go-line-history-success.md"
diff -u fixtures/expected/go-line-history-success.md "$tmp_dir/git-hotspots-go-line-history-success.md"
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format table > "$tmp_dir/git-hotspots-go-line-history-success.txt"
diff -u fixtures/expected/go-line-history-success.txt "$tmp_dir/git-hotspots-go-line-history-success.txt"
"$EXE" --repo fixtures/go-symbols-shallow --inspect src/example.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-shallow.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$tmp_dir/git-hotspots-go-line-history-shallow.json"
"$EXE" --repo fixtures/go-symbols-partial --inspect src/example.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-partial.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$tmp_dir/git-hotspots-go-line-history-partial.json"
"$EXE" --repo fixtures/go-symbols --inspect src/empty.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-empty.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-go-line-history-empty.json"
"$EXE" --repo fixtures/go-symbols --inspect src/broken.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-invalid.json"
grep -Fq -- '"failure": "failed"' "$tmp_dir/git-hotspots-go-line-history-invalid.json"
"$EXE" --repo fixtures/go-symbols --inspect src/link.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-symlink-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-go-line-history-symlink-unavailable.json"
"$EXE" --repo fixtures/go-symbols --inspect src/large.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-large-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-go-line-history-large-unavailable.json"
"$EXE" --repo fixtures/go-symbols --inspect src/missing.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-missing-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-go-line-history-missing-unavailable.json"
"$EXE" --repo fixtures/go-symbols --inspect src/old-example.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-rename-alias.json"
grep -Fq -- '"matched_path": "src/example.go"' "$tmp_dir/git-hotspots-go-line-history-rename-alias.json"
printf '// dirty inspected\n' >> fixtures/go-symbols/src/example.go
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-dirty-inspected.json"
grep -Fq -- 'current-line Git evidence skipped: inspected file has staged or unstaged content changes' "$tmp_dir/git-hotspots-go-line-history-dirty-inspected.json"
git -C fixtures/go-symbols checkout -q -- src/example.go
printf '// dirty unrelated\n' >> fixtures/go-symbols/src/other.go
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-go-line-history-dirty-unrelated.json"
grep -Fq -- '"failure": "ok"' "$tmp_dir/git-hotspots-go-line-history-dirty-unrelated.json"
git -C fixtures/go-symbols checkout -q -- src/other.go
python3 - "$tmp_dir/git-hotspots-go-symbols.json" "$tmp_dir/git-hotspots-go-symbols-limit.json" "$tmp_dir/git-hotspots-go-symbols-empty.json" "$tmp_dir/git-hotspots-go-symbols-invalid.json" "$tmp_dir/git-hotspots-go-symbols-caveated.json" "$tmp_dir/git-hotspots-go-symbols-symlink-unavailable.json" "$tmp_dir/git-hotspots-go-symbols-large-unavailable.json" "$tmp_dir/git-hotspots-go-symbols-missing-unavailable.json" "$tmp_dir/git-hotspots-go-symbols-rename-alias.json" "$tmp_dir/git-hotspots-go-symbols-other.json" <<'PY'
import json, sys
success, limited, empty, invalid, caveated, symlink, large, missing, alias, other = [json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
assert success['symbols']['provider']['name'] == 'tree-sitter-go'
assert success['symbols']['provider']['failure'] == 'ok'
assert [row['kind'] for row in success['symbols']['items']] == ['other', 'other', 'variable', 'method', 'type', 'type', 'function', 'module']
assert all(row['path'] == 'src/example.go' for row in success['symbols']['items'])
assert len(limited['symbols']['items']) == len(success['symbols']['items'])
assert limited['symbols']['human_display']['shown_count'] == 2
assert limited['symbols']['human_display']['omitted_count'] == 6
assert empty['symbols']['provider']['failure'] == 'ok' and empty['symbols']['items'] == []
assert invalid['symbols']['provider']['failure'] == 'failed' and invalid['symbols']['items'] == []
assert symlink['symbols']['provider']['failure'] == 'unavailable' and symlink['symbols']['items'] == []
assert large['symbols']['provider']['failure'] == 'unavailable' and large['symbols']['items'] == []
assert missing['symbols']['provider']['failure'] == 'unavailable' and missing['symbols']['items'] == []
assert alias['inspect']['requested_path'] == 'src/old-example.go'
assert alias['inspect']['matched_path'] == 'src/example.go'
assert all(row['path'] == 'src/example.go' for row in alias['symbols']['items'])
assert any('build tags' in caveat and 'cgo' in caveat for caveat in caveated['symbols']['provider']['caveats'])
assert [row['name'] for row in other['symbols']['items']] == ['OtherOnly', 'symbols']
for data in (success, limited, empty, invalid, caveated, symlink, large, missing, alias, other):
    text = json.dumps(data, ensure_ascii=False)
    for forbidden in ('Fixture Author', 'fixture@example', 'source line'):
        assert forbidden not in text
PY
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --format json > "$tmp_dir/git-hotspots-python-symbols.json"
diff -u fixtures/expected/python-symbols.json "$tmp_dir/git-hotspots-python-symbols.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-python-symbols.json"
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --format markdown > "$tmp_dir/git-hotspots-python-symbols.md"
diff -u fixtures/expected/python-symbols.md "$tmp_dir/git-hotspots-python-symbols.md"
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --format table > "$tmp_dir/git-hotspots-python-symbols.txt"
diff -u fixtures/expected/python-symbols.txt "$tmp_dir/git-hotspots-python-symbols.txt"
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-limit 3 --format json > "$tmp_dir/git-hotspots-python-symbols-limit.json"
diff -u fixtures/expected/python-symbols-limit.json "$tmp_dir/git-hotspots-python-symbols-limit.json"
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-limit 3 --format markdown > "$tmp_dir/git-hotspots-python-symbols-limit.md"
diff -u fixtures/expected/python-symbols-limit.md "$tmp_dir/git-hotspots-python-symbols-limit.md"
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-limit 3 --format table > "$tmp_dir/git-hotspots-python-symbols-limit.txt"
diff -u fixtures/expected/python-symbols-limit.txt "$tmp_dir/git-hotspots-python-symbols-limit.txt"
"$EXE" --repo fixtures/python-symbols --inspect src/empty.py --symbols --format json > "$tmp_dir/git-hotspots-python-symbols-empty.json"
diff -u fixtures/expected/python-symbols-empty.json "$tmp_dir/git-hotspots-python-symbols-empty.json"
"$EXE" --repo fixtures/python-symbols --inspect src/invalid_partial.py --symbols --format json > "$tmp_dir/git-hotspots-python-symbols-invalid.json"
diff -u fixtures/expected/python-symbols-invalid.json "$tmp_dir/git-hotspots-python-symbols-invalid.json"
"$EXE" --repo fixtures/python-symbols --inspect src/generated.py --symbols --format json > "$tmp_dir/git-hotspots-python-symbols-generated.json"
diff -u fixtures/expected/python-symbols-generated.json "$tmp_dir/git-hotspots-python-symbols-generated.json"
"$EXE" --repo fixtures/python-symbols --inspect src/link.py --symbols --format json > "$tmp_dir/git-hotspots-python-symbols-symlink-unavailable.json"
diff -u fixtures/expected/python-symbols-symlink-unavailable.json "$tmp_dir/git-hotspots-python-symbols-symlink-unavailable.json"
"$EXE" --repo fixtures/python-symbols --inspect src/large.py --symbols --format json > "$tmp_dir/git-hotspots-python-symbols-large-unavailable.json"
diff -u fixtures/expected/python-symbols-large-unavailable.json "$tmp_dir/git-hotspots-python-symbols-large-unavailable.json"
"$EXE" --repo fixtures/python-symbols --inspect src/missing.py --symbols --format json > "$tmp_dir/git-hotspots-python-symbols-missing-unavailable.json"
diff -u fixtures/expected/python-symbols-missing-unavailable.json "$tmp_dir/git-hotspots-python-symbols-missing-unavailable.json"
"$EXE" --repo fixtures/python-symbols --inspect src/old_example.py --symbols --format json > "$tmp_dir/git-hotspots-python-symbols-rename-alias.json"
diff -u fixtures/expected/python-symbols-rename-alias.json "$tmp_dir/git-hotspots-python-symbols-rename-alias.json"
"$EXE" --repo fixtures/python-symbols --inspect src/other.py --symbols --format json > "$tmp_dir/git-hotspots-python-symbols-other.json"
! grep -Fq -- 'top_function' "$tmp_dir/git-hotspots-python-symbols-other.json"
"$EXE" --repo fixtures/python-symbols --inspect 'src/markdown|path.py' --symbols --format markdown > "$tmp_dir/git-hotspots-python-symbols-markdown-path.md"
grep -Fq -- 'markdown\|path.py' "$tmp_dir/git-hotspots-python-symbols-markdown-path.md"
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-python-line-history-success.json"
diff -u fixtures/expected/python-line-history-success.json "$tmp_dir/git-hotspots-python-line-history-success.json"
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-python-line-history-success-2.json"
diff -u "$tmp_dir/git-hotspots-python-line-history-success.json" "$tmp_dir/git-hotspots-python-line-history-success-2.json"
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format markdown > "$tmp_dir/git-hotspots-python-line-history-success.md"
diff -u fixtures/expected/python-line-history-success.md "$tmp_dir/git-hotspots-python-line-history-success.md"
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format table > "$tmp_dir/git-hotspots-python-line-history-success.txt"
diff -u fixtures/expected/python-line-history-success.txt "$tmp_dir/git-hotspots-python-line-history-success.txt"
"$EXE" --repo fixtures/python-symbols-shallow --inspect src/example.py --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-python-line-history-shallow.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$tmp_dir/git-hotspots-python-line-history-shallow.json"
"$EXE" --repo fixtures/python-symbols-partial --inspect src/example.py --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-python-line-history-partial.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$tmp_dir/git-hotspots-python-line-history-partial.json"
"$EXE" --repo fixtures/python-symbols --inspect src/empty.py --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-python-line-history-empty.json"
grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-python-line-history-empty.json"
grep -Fq -- 'current-line Git evidence has unblamable lines in this symbol range' "$tmp_dir/git-hotspots-python-line-history-empty.json"
"$EXE" --repo fixtures/python-symbols --inspect src/invalid_partial.py --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-python-line-history-invalid.json"
grep -Fq -- '"failure": "failed"' "$tmp_dir/git-hotspots-python-line-history-invalid.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-python-line-history-invalid.json"
"$EXE" --repo fixtures/python-symbols --inspect src/link.py --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-python-line-history-symlink-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-python-line-history-symlink-unavailable.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-python-line-history-symlink-unavailable.json"
"$EXE" --repo fixtures/python-symbols --inspect src/large.py --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-python-line-history-large-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-python-line-history-large-unavailable.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-python-line-history-large-unavailable.json"
"$EXE" --repo fixtures/python-symbols --inspect src/missing.py --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-python-line-history-missing-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-python-line-history-missing-unavailable.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-python-line-history-missing-unavailable.json"
printf '# dirty inspected\n' >> fixtures/python-symbols/src/example.py
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-python-line-history-dirty-inspected.json"
grep -Fq -- 'current-line Git evidence skipped: inspected file has staged or unstaged content changes' "$tmp_dir/git-hotspots-python-line-history-dirty-inspected.json"
git -C fixtures/python-symbols checkout -q -- src/example.py
printf '# dirty unrelated\n' >> fixtures/python-symbols/src/other.py
"$EXE" --repo fixtures/python-symbols --inspect src/example.py --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-python-line-history-dirty-unrelated.json"
grep -Fq -- '"failure": "ok"' "$tmp_dir/git-hotspots-python-line-history-dirty-unrelated.json"
git -C fixtures/python-symbols checkout -q -- src/other.py
python3 - "$tmp_dir/git-hotspots-python-symbols.json" "$tmp_dir/git-hotspots-python-symbols-limit.json" "$tmp_dir/git-hotspots-python-symbols-empty.json" "$tmp_dir/git-hotspots-python-symbols-invalid.json" "$tmp_dir/git-hotspots-python-symbols-generated.json" "$tmp_dir/git-hotspots-python-symbols-symlink-unavailable.json" "$tmp_dir/git-hotspots-python-symbols-large-unavailable.json" "$tmp_dir/git-hotspots-python-symbols-missing-unavailable.json" "$tmp_dir/git-hotspots-python-symbols-rename-alias.json" "$tmp_dir/git-hotspots-python-symbols-other.json" "$tmp_dir/git-hotspots-python-line-history-success.json" "$tmp_dir/git-hotspots-python-line-history-shallow.json" "$tmp_dir/git-hotspots-python-line-history-partial.json" "$tmp_dir/git-hotspots-python-line-history-empty.json" "$tmp_dir/git-hotspots-python-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-python-line-history-dirty-unrelated.json" <<'PY'
import json, sys
success, limited, empty, invalid, generated, symlink, large, missing, alias, other, line, line_shallow, line_partial, line_empty, line_dirty, line_unrelated = [json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
assert success['symbols']['provider']['name'] == 'tree-sitter-python'
assert success['symbols']['provider']['failure'] == 'ok'
assert [row['name'] for row in success['symbols']['items']] == ['src/example.py', 'CONSTANT', 'mutable_value', 'top_function', 'inner_function', 'InnerClass', 'Outer', 'Nested', 'method', 'method_inner', 'café']
assert [row['kind'] for row in success['symbols']['items']] == ['module', 'other', 'variable', 'function', 'function', 'class', 'class', 'class', 'method', 'function', 'function']
assert all(row['path'] == 'src/example.py' for row in success['symbols']['items'])
assert 'FIRST' not in json.dumps(success) and 'DYNAMIC' not in json.dumps(success)
assert len(limited['symbols']['items']) == len(success['symbols']['items'])
assert limited['symbols']['human_display']['shown_count'] == 3
assert limited['symbols']['human_display']['omitted_count'] == 8
assert empty['symbols']['provider']['failure'] == 'ok' and [row['name'] for row in empty['symbols']['items']] == ['src/empty.py']
assert invalid['symbols']['provider']['failure'] == 'failed' and invalid['symbols']['items'] == []
assert generated['symbols']['provider']['failure'] == 'ok' and any('generated-file markers' in caveat for caveat in generated['symbols']['provider']['caveats'])
assert symlink['symbols']['provider']['failure'] == 'unavailable' and symlink['symbols']['items'] == []
assert large['symbols']['provider']['failure'] == 'unavailable' and large['symbols']['items'] == []
assert missing['symbols']['provider']['failure'] == 'unavailable' and missing['symbols']['items'] == []
assert alias['inspect']['requested_path'] == 'src/old_example.py' and alias['inspect']['matched_path'] == 'src/example.py'
assert all(row['path'] == 'src/example.py' for row in alias['symbols']['items'])
assert [row['name'] for row in other['symbols']['items']] == ['src/other.py', 'OtherOnly']
assert all('current_line_history' in row for row in line['symbols']['items']), 'Python current-line evidence missing'
assert all(row['current_line_history']['basis'] == 'current-line-range-at-head' for row in line['symbols']['items'])
assert any(row['current_line_history']['most_recent_line_touched_timestamp'] == 1777593600 for row in line['symbols']['items'])
assert any('shallow' in ' '.join(row['current_line_history']['caveats']) for row in line_shallow['symbols']['items'])
assert any('partial/promisor' in ' '.join(row['current_line_history']['caveats']) for row in line_partial['symbols']['items'])
assert any(row['current_line_history']['uncommitted_or_unblamable_line_count'] > 0 for row in line_empty['symbols']['items'])
assert all(row['current_line_history']['failure'] == 'skipped' for row in line_dirty['symbols']['items'])
assert all(row['current_line_history']['failure'] == 'ok' for row in line_unrelated['symbols']['items'])
for data in (success, limited, empty, invalid, generated, symlink, large, missing, alias, other):
    text = json.dumps(data, ensure_ascii=False)
    assert 'current_line_history' not in text
    for forbidden in ('Fixture Author', 'fixture@example', 'source line'):
        assert forbidden not in text
for data in (line, line_shallow, line_partial, line_empty, line_dirty, line_unrelated):
    text = json.dumps(data, ensure_ascii=False)
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'ownership', 'productivity'):
        assert forbidden not in text
PY
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols.json"
diff -u fixtures/expected/javascript-symbols.json "$tmp_dir/git-hotspots-javascript-symbols.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-javascript-symbols.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --format markdown > "$tmp_dir/git-hotspots-javascript-symbols.md"
diff -u fixtures/expected/javascript-symbols.md "$tmp_dir/git-hotspots-javascript-symbols.md"
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --format table > "$tmp_dir/git-hotspots-javascript-symbols.txt"
diff -u fixtures/expected/javascript-symbols.txt "$tmp_dir/git-hotspots-javascript-symbols.txt"
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-limit 4 --format json > "$tmp_dir/git-hotspots-javascript-symbols-limit.json"
diff -u fixtures/expected/javascript-symbols-limit.json "$tmp_dir/git-hotspots-javascript-symbols-limit.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-limit 4 --format markdown > "$tmp_dir/git-hotspots-javascript-symbols-limit.md"
diff -u fixtures/expected/javascript-symbols-limit.md "$tmp_dir/git-hotspots-javascript-symbols-limit.md"
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-limit 4 --format table > "$tmp_dir/git-hotspots-javascript-symbols-limit.txt"
diff -u fixtures/expected/javascript-symbols-limit.txt "$tmp_dir/git-hotspots-javascript-symbols-limit.txt"
"$EXE" --repo fixtures/javascript-symbols --inspect src/commonjs.cjs --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols-commonjs.json"
diff -u fixtures/expected/javascript-symbols-commonjs.json "$tmp_dir/git-hotspots-javascript-symbols-commonjs.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/component.jsx --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols-jsx.json"
diff -u fixtures/expected/javascript-symbols-jsx.json "$tmp_dir/git-hotspots-javascript-symbols-jsx.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/anonymous_exports.js --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols-anonymous.json"
diff -u fixtures/expected/javascript-symbols-anonymous.json "$tmp_dir/git-hotspots-javascript-symbols-anonymous.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/empty.js --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols-empty.json"
diff -u fixtures/expected/javascript-symbols-empty.json "$tmp_dir/git-hotspots-javascript-symbols-empty.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/invalid_partial.js --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols-invalid.json"
diff -u fixtures/expected/javascript-symbols-invalid.json "$tmp_dir/git-hotspots-javascript-symbols-invalid.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/generated.min.js --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols-generated.json"
diff -u fixtures/expected/javascript-symbols-generated.json "$tmp_dir/git-hotspots-javascript-symbols-generated.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/link.js --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols-symlink-unavailable.json"
diff -u fixtures/expected/javascript-symbols-symlink-unavailable.json "$tmp_dir/git-hotspots-javascript-symbols-symlink-unavailable.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/large.js --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols-large-unavailable.json"
diff -u fixtures/expected/javascript-symbols-large-unavailable.json "$tmp_dir/git-hotspots-javascript-symbols-large-unavailable.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/missing.js --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols-missing-unavailable.json"
diff -u fixtures/expected/javascript-symbols-missing-unavailable.json "$tmp_dir/git-hotspots-javascript-symbols-missing-unavailable.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/old-example.mjs --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols-rename-alias.json"
diff -u fixtures/expected/javascript-symbols-rename-alias.json "$tmp_dir/git-hotspots-javascript-symbols-rename-alias.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/other.js --symbols --format json > "$tmp_dir/git-hotspots-javascript-symbols-other.json"
! grep -Fq -- 'topFunction' "$tmp_dir/git-hotspots-javascript-symbols-other.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-success.json"
diff -u fixtures/expected/javascript-line-history-success.json "$tmp_dir/git-hotspots-javascript-line-history-success.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-success-2.json"
diff -u "$tmp_dir/git-hotspots-javascript-line-history-success.json" "$tmp_dir/git-hotspots-javascript-line-history-success-2.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-line-history --format markdown > "$tmp_dir/git-hotspots-javascript-line-history-success.md"
diff -u fixtures/expected/javascript-line-history-success.md "$tmp_dir/git-hotspots-javascript-line-history-success.md"
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-line-history --format table > "$tmp_dir/git-hotspots-javascript-line-history-success.txt"
diff -u fixtures/expected/javascript-line-history-success.txt "$tmp_dir/git-hotspots-javascript-line-history-success.txt"
"$EXE" --repo fixtures/javascript-symbols-shallow --inspect src/example.mjs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-shallow.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$tmp_dir/git-hotspots-javascript-line-history-shallow.json"
"$EXE" --repo fixtures/javascript-symbols-partial --inspect src/example.mjs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-partial.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$tmp_dir/git-hotspots-javascript-line-history-partial.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/commonjs.cjs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-commonjs.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/component.jsx --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-jsx.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/anonymous_exports.js --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-anonymous.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/empty.js --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-empty.json"
grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-javascript-line-history-empty.json"
grep -Fq -- 'current-line Git evidence has unblamable lines in this symbol range' "$tmp_dir/git-hotspots-javascript-line-history-empty.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/invalid_partial.js --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-invalid.json"
grep -Fq -- '"failure": "failed"' "$tmp_dir/git-hotspots-javascript-line-history-invalid.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-javascript-line-history-invalid.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/generated.min.js --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-generated.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/link.js --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-symlink-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-javascript-line-history-symlink-unavailable.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-javascript-line-history-symlink-unavailable.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/large.js --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-large-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-javascript-line-history-large-unavailable.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-javascript-line-history-large-unavailable.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/missing.js --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-missing-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-javascript-line-history-missing-unavailable.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-javascript-line-history-missing-unavailable.json"
"$EXE" --repo fixtures/javascript-symbols --inspect src/old-example.mjs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-rename-alias.json"
grep -Fq -- '"matched_path": "src/example.mjs"' "$tmp_dir/git-hotspots-javascript-line-history-rename-alias.json"
printf '// dirty inspected\n' >> fixtures/javascript-symbols/src/example.mjs
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-dirty-inspected.json"
grep -Fq -- 'current-line Git evidence skipped: inspected file has staged or unstaged content changes' "$tmp_dir/git-hotspots-javascript-line-history-dirty-inspected.json"
git -C fixtures/javascript-symbols checkout -q -- src/example.mjs
printf '// dirty unrelated\n' >> fixtures/javascript-symbols/src/other.js
"$EXE" --repo fixtures/javascript-symbols --inspect src/example.mjs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-javascript-line-history-dirty-unrelated.json"
grep -Fq -- '"failure": "ok"' "$tmp_dir/git-hotspots-javascript-line-history-dirty-unrelated.json"
git -C fixtures/javascript-symbols checkout -q -- src/other.js
python3 - "$tmp_dir/git-hotspots-javascript-symbols.json" "$tmp_dir/git-hotspots-javascript-symbols-limit.json" "$tmp_dir/git-hotspots-javascript-symbols-commonjs.json" "$tmp_dir/git-hotspots-javascript-symbols-jsx.json" "$tmp_dir/git-hotspots-javascript-symbols-anonymous.json" "$tmp_dir/git-hotspots-javascript-symbols-empty.json" "$tmp_dir/git-hotspots-javascript-symbols-invalid.json" "$tmp_dir/git-hotspots-javascript-symbols-generated.json" "$tmp_dir/git-hotspots-javascript-symbols-symlink-unavailable.json" "$tmp_dir/git-hotspots-javascript-symbols-large-unavailable.json" "$tmp_dir/git-hotspots-javascript-symbols-missing-unavailable.json" "$tmp_dir/git-hotspots-javascript-symbols-rename-alias.json" "$tmp_dir/git-hotspots-javascript-symbols-other.json" "$tmp_dir/git-hotspots-javascript-line-history-success.json" "$tmp_dir/git-hotspots-javascript-line-history-shallow.json" "$tmp_dir/git-hotspots-javascript-line-history-partial.json" "$tmp_dir/git-hotspots-javascript-line-history-commonjs.json" "$tmp_dir/git-hotspots-javascript-line-history-jsx.json" "$tmp_dir/git-hotspots-javascript-line-history-anonymous.json" "$tmp_dir/git-hotspots-javascript-line-history-empty.json" "$tmp_dir/git-hotspots-javascript-line-history-invalid.json" "$tmp_dir/git-hotspots-javascript-line-history-generated.json" "$tmp_dir/git-hotspots-javascript-line-history-symlink-unavailable.json" "$tmp_dir/git-hotspots-javascript-line-history-large-unavailable.json" "$tmp_dir/git-hotspots-javascript-line-history-missing-unavailable.json" "$tmp_dir/git-hotspots-javascript-line-history-rename-alias.json" "$tmp_dir/git-hotspots-javascript-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-javascript-line-history-dirty-unrelated.json" <<'PY'
import json, sys
success, limited, commonjs, jsx, anonymous, empty, invalid, generated, symlink, large, missing, alias, other, line, line_shallow, line_partial, line_commonjs, line_jsx, line_anonymous, line_empty, line_invalid, line_generated, line_symlink, line_large, line_missing, line_alias, line_dirty, line_unrelated = [json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
assert success['symbols']['provider']['name'] == 'tree-sitter-javascript'
assert success['symbols']['provider']['failure'] == 'ok'
assert [row['name'] for row in success['symbols']['items']] == ['src/example.mjs', 'EXPORTED_CONSTANT', 'mutableValue', 'legacyValue', 'topFunction', 'innerFunction', 'LocalClass', 'methodOne', 'methodInner', 'ExportedClass', 'render', 'café', 'ignoredObject']
assert [row['kind'] for row in success['symbols']['items']] == ['module', 'other', 'variable', 'variable', 'function', 'function', 'class', 'method', 'function', 'class', 'method', 'function', 'variable']
assert all(row['path'] == 'src/example.mjs' for row in success['symbols']['items'])
assert 'dynamicName' not in json.dumps(success)
assert any(row['name'] == 'café' and row['kind'] == 'function' for row in success['symbols']['items'])
assert len(limited['symbols']['items']) == len(success['symbols']['items'])
assert limited['symbols']['human_display']['shown_count'] == 4
assert limited['symbols']['human_display']['omitted_count'] == 9
assert [row['name'] for row in commonjs['symbols']['items']] == ['src/commonjs.cjs', 'localOnly', 'makeThing', 'Widget', 'run', 'ANSWER']
assert [row['kind'] for row in commonjs['symbols']['items']] == ['module', 'variable', 'function', 'class', 'method', 'other']
assert [row['name'] for row in jsx['symbols']['items']] == ['src/component.jsx', 'View', 'element']
assert any('TSX remains unsupported' in caveat for caveat in jsx['symbols']['provider']['caveats'])
assert [row['name'] for row in anonymous['symbols']['items']] == ['src/anonymous_exports.js']
assert any('anonymous default' in caveat for caveat in anonymous['symbols']['provider']['caveats'])
assert empty['symbols']['provider']['failure'] == 'ok' and [row['name'] for row in empty['symbols']['items']] == ['src/empty.js']
assert invalid['symbols']['provider']['failure'] == 'failed' and invalid['symbols']['items'] == []
assert generated['symbols']['provider']['failure'] == 'ok' and any('generated-file markers' in caveat for caveat in generated['symbols']['provider']['caveats'])
assert symlink['symbols']['provider']['failure'] == 'unavailable' and symlink['symbols']['items'] == []
assert large['symbols']['provider']['failure'] == 'unavailable' and large['symbols']['items'] == []
assert missing['symbols']['provider']['failure'] == 'unavailable' and missing['symbols']['items'] == []
assert alias['inspect']['requested_path'] == 'src/old-example.mjs' and alias['inspect']['matched_path'] == 'src/example.mjs'
assert all(row['path'] == 'src/example.mjs' for row in alias['symbols']['items'])
assert [row['name'] for row in other['symbols']['items']] == ['src/other.js', 'OtherOnly']
assert all('current_line_history' in row for row in line['symbols']['items']), 'JavaScript current-line evidence missing'
assert all(row['current_line_history']['basis'] == 'current-line-range-at-head' for row in line['symbols']['items'])
assert any(row['current_line_history']['most_recent_line_touched_timestamp'] == 1777593600 for row in line['symbols']['items'])
assert any('shallow' in ' '.join(row['current_line_history']['caveats']) for row in line_shallow['symbols']['items'])
assert any('partial/promisor' in ' '.join(row['current_line_history']['caveats']) for row in line_partial['symbols']['items'])
assert all('current_line_history' in row for row in line_commonjs['symbols']['items'])
assert all('current_line_history' in row for row in line_jsx['symbols']['items'])
assert any('TSX remains unsupported' in caveat for caveat in line_jsx['symbols']['provider']['caveats'])
assert all('current_line_history' in row for row in line_anonymous['symbols']['items'])
assert any('anonymous default' in caveat for caveat in line_anonymous['symbols']['provider']['caveats'])
assert any(row['current_line_history']['uncommitted_or_unblamable_line_count'] > 0 for row in line_empty['symbols']['items'])
assert line_invalid['symbols']['provider']['failure'] == 'failed' and line_invalid['symbols']['items'] == []
assert all('current_line_history' in row for row in line_generated['symbols']['items'])
assert any('generated-file markers' in caveat for caveat in line_generated['symbols']['provider']['caveats'])
assert line_symlink['symbols']['provider']['failure'] == 'unavailable' and line_symlink['symbols']['items'] == []
assert line_large['symbols']['provider']['failure'] == 'unavailable' and line_large['symbols']['items'] == []
assert line_missing['symbols']['provider']['failure'] == 'unavailable' and line_missing['symbols']['items'] == []
assert line_alias['inspect']['requested_path'] == 'src/old-example.mjs' and line_alias['inspect']['matched_path'] == 'src/example.mjs'
assert all(row['path'] == 'src/example.mjs' for row in line_alias['symbols']['items'])
assert all(row['current_line_history']['failure'] == 'skipped' for row in line_dirty['symbols']['items'])
assert all(row['current_line_history']['failure'] == 'ok' for row in line_unrelated['symbols']['items'])
for data in (success, limited, commonjs, jsx, anonymous, empty, invalid, generated, symlink, large, missing, alias, other):
    text = json.dumps(data, ensure_ascii=False)
    assert 'current_line_history' not in text
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'ownership', 'productivity', 'Node package graph'):
        assert forbidden not in text
for data in (line, line_shallow, line_partial, line_commonjs, line_jsx, line_anonymous, line_empty, line_invalid, line_generated, line_symlink, line_large, line_missing, line_alias, line_dirty, line_unrelated):
    text = json.dumps(data, ensure_ascii=False)
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'ownership', 'productivity', 'Node package graph'):
        assert forbidden not in text
PY
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols.json"
diff -u fixtures/expected/lua-symbols.json "$tmp_dir/git-hotspots-lua-symbols.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-lua-symbols.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --format markdown > "$tmp_dir/git-hotspots-lua-symbols.md"
diff -u fixtures/expected/lua-symbols.md "$tmp_dir/git-hotspots-lua-symbols.md"
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --format table > "$tmp_dir/git-hotspots-lua-symbols.txt"
diff -u fixtures/expected/lua-symbols.txt "$tmp_dir/git-hotspots-lua-symbols.txt"
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-limit 3 --format json > "$tmp_dir/git-hotspots-lua-symbols-limit.json"
diff -u fixtures/expected/lua-symbols-limit.json "$tmp_dir/git-hotspots-lua-symbols-limit.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-limit 3 --format markdown > "$tmp_dir/git-hotspots-lua-symbols-limit.md"
diff -u fixtures/expected/lua-symbols-limit.md "$tmp_dir/git-hotspots-lua-symbols-limit.md"
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-limit 3 --format table > "$tmp_dir/git-hotspots-lua-symbols-limit.txt"
diff -u fixtures/expected/lua-symbols-limit.txt "$tmp_dir/git-hotspots-lua-symbols-limit.txt"
"$EXE" --repo fixtures/lua-symbols --inspect src/empty.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols-empty.json"
diff -u fixtures/expected/lua-symbols-empty.json "$tmp_dir/git-hotspots-lua-symbols-empty.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/invalid_partial.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols-invalid.json"
diff -u fixtures/expected/lua-symbols-invalid.json "$tmp_dir/git-hotspots-lua-symbols-invalid.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/generated.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols-generated.json"
diff -u fixtures/expected/lua-symbols-generated.json "$tmp_dir/git-hotspots-lua-symbols-generated.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/dynamic_table_assignment.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols-dynamic-table.json"
diff -u fixtures/expected/lua-symbols-dynamic-table.json "$tmp_dir/git-hotspots-lua-symbols-dynamic-table.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/metatable_heavy.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols-metatable.json"
diff -u fixtures/expected/lua-symbols-metatable.json "$tmp_dir/git-hotspots-lua-symbols-metatable.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/embedded_dsl.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols-embedded-dsl.json"
diff -u fixtures/expected/lua-symbols-embedded-dsl.json "$tmp_dir/git-hotspots-lua-symbols-embedded-dsl.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/link.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols-symlink-unavailable.json"
diff -u fixtures/expected/lua-symbols-symlink-unavailable.json "$tmp_dir/git-hotspots-lua-symbols-symlink-unavailable.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/large.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols-large-unavailable.json"
diff -u fixtures/expected/lua-symbols-large-unavailable.json "$tmp_dir/git-hotspots-lua-symbols-large-unavailable.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/missing.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols-missing-unavailable.json"
diff -u fixtures/expected/lua-symbols-missing-unavailable.json "$tmp_dir/git-hotspots-lua-symbols-missing-unavailable.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/old-example.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols-rename-alias.json"
diff -u fixtures/expected/lua-symbols-rename-alias.json "$tmp_dir/git-hotspots-lua-symbols-rename-alias.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/other.lua --symbols --format json > "$tmp_dir/git-hotspots-lua-symbols-other.json"
! grep -Fq -- 'local_worker' "$tmp_dir/git-hotspots-lua-symbols-other.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history.json"
diff -u fixtures/expected/lua-line-history-success.json "$tmp_dir/git-hotspots-lua-line-history.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-2.json"
diff -u "$tmp_dir/git-hotspots-lua-line-history.json" "$tmp_dir/git-hotspots-lua-line-history-2.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format markdown > "$tmp_dir/git-hotspots-lua-line-history.md"
diff -u fixtures/expected/lua-line-history-success.md "$tmp_dir/git-hotspots-lua-line-history.md"
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format table > "$tmp_dir/git-hotspots-lua-line-history.txt"
diff -u fixtures/expected/lua-line-history-success.txt "$tmp_dir/git-hotspots-lua-line-history.txt"
"$EXE" --repo fixtures/lua-symbols-shallow --inspect src/example.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-shallow.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$tmp_dir/git-hotspots-lua-line-history-shallow.json"
"$EXE" --repo fixtures/lua-symbols-partial --inspect src/example.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-partial.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$tmp_dir/git-hotspots-lua-line-history-partial.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/empty.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-empty.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/invalid_partial.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-invalid.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/generated.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-generated.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/dynamic_table_assignment.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-dynamic-table.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/metatable_heavy.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-metatable.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/embedded_dsl.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-embedded-dsl.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/link.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-symlink-unavailable.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/large.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-large-unavailable.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/missing.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-missing-unavailable.json"
"$EXE" --repo fixtures/lua-symbols --inspect src/old-example.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-rename-alias.json"
printf 'local function untracked()\n  return true\nend\n' > fixtures/lua-symbols/src/untracked.lua
assert_fails_with_stderr lua-line-history-untracked "--inspect target has no matching" "$EXE" --repo fixtures/lua-symbols --inspect src/untracked.lua --symbols --symbol-line-history --format json
rm -f fixtures/lua-symbols/src/untracked.lua
printf '%s\n' '-- dirty inspected' >> fixtures/lua-symbols/src/example.lua
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-dirty-inspected.json"
grep -Fq -- 'current-line Git evidence skipped: inspected file has staged or unstaged content changes' "$tmp_dir/git-hotspots-lua-line-history-dirty-inspected.json"
git -C fixtures/lua-symbols checkout -q -- src/example.lua
printf '%s\n' '-- dirty unrelated' >> fixtures/lua-symbols/src/other.lua
"$EXE" --repo fixtures/lua-symbols --inspect src/example.lua --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-lua-line-history-dirty-unrelated.json"
grep -Fq -- '"failure": "ok"' "$tmp_dir/git-hotspots-lua-line-history-dirty-unrelated.json"
git -C fixtures/lua-symbols checkout -q -- src/other.lua
assert_fails_with_stderr lua-line-history-no-history "repository has no commits" sh -c 'tmp=$(mktemp -d); git init -q -b main "$tmp" && "$0" --repo "$tmp" --inspect src/example.lua --symbols --symbol-line-history --format json' "$EXE"
python3 - "$tmp_dir/git-hotspots-lua-symbols.json" "$tmp_dir/git-hotspots-lua-symbols-limit.json" "$tmp_dir/git-hotspots-lua-symbols-empty.json" "$tmp_dir/git-hotspots-lua-symbols-invalid.json" "$tmp_dir/git-hotspots-lua-symbols-generated.json" "$tmp_dir/git-hotspots-lua-symbols-dynamic-table.json" "$tmp_dir/git-hotspots-lua-symbols-metatable.json" "$tmp_dir/git-hotspots-lua-symbols-embedded-dsl.json" "$tmp_dir/git-hotspots-lua-symbols-symlink-unavailable.json" "$tmp_dir/git-hotspots-lua-symbols-large-unavailable.json" "$tmp_dir/git-hotspots-lua-symbols-missing-unavailable.json" "$tmp_dir/git-hotspots-lua-symbols-rename-alias.json" "$tmp_dir/git-hotspots-lua-symbols-other.json" "$tmp_dir/git-hotspots-lua-line-history.json" "$tmp_dir/git-hotspots-lua-line-history-shallow.json" "$tmp_dir/git-hotspots-lua-line-history-partial.json" "$tmp_dir/git-hotspots-lua-line-history-empty.json" "$tmp_dir/git-hotspots-lua-line-history-invalid.json" "$tmp_dir/git-hotspots-lua-line-history-generated.json" "$tmp_dir/git-hotspots-lua-line-history-dynamic-table.json" "$tmp_dir/git-hotspots-lua-line-history-metatable.json" "$tmp_dir/git-hotspots-lua-line-history-embedded-dsl.json" "$tmp_dir/git-hotspots-lua-line-history-symlink-unavailable.json" "$tmp_dir/git-hotspots-lua-line-history-large-unavailable.json" "$tmp_dir/git-hotspots-lua-line-history-missing-unavailable.json" "$tmp_dir/git-hotspots-lua-line-history-rename-alias.json" "$tmp_dir/git-hotspots-lua-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-lua-line-history-dirty-unrelated.json" <<'PY'
import json, sys
success, limited, empty, invalid, generated, dynamic, metatable, embedded, symlink, large, missing, alias, other, line, line_shallow, line_partial, line_empty, line_invalid, line_generated, line_dynamic, line_metatable, line_embedded, line_symlink, line_large, line_missing, line_alias, line_dirty, line_unrelated = [json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
assert success['symbols']['provider']['name'] == 'tree-sitter-lua', 'Lua provider missing'
assert success['symbols']['provider']['failure'] == 'ok', 'Lua provider failure changed'
assert [row['name'] for row in success['symbols']['items']] == ['src/example.lua', 'CONFIG', 'mutable_value', 'exports', 'answer', 'build', 'Nested', 'local_worker', 'make_thing', 'run'], 'Lua source order changed'
assert [row['kind'] for row in success['symbols']['items']] == ['module', 'other', 'variable', 'variable', 'variable', 'function', 'variable', 'function', 'function', 'method'], 'Lua kinds changed'
assert all(row['path'] == 'src/example.lua' for row in success['symbols']['items']), 'Lua path changed'
assert 'ignored_inner' not in json.dumps(success) and 'inside' not in json.dumps(success) and 'skipped' not in json.dumps(success), 'Lua nested implementation symbol leaked'
assert len(limited['symbols']['items']) == len(success['symbols']['items']), 'Lua limit truncated JSON'
assert limited['symbols']['human_display']['shown_count'] == 3, 'Lua limit shown changed'
assert limited['symbols']['human_display']['omitted_count'] == 7, 'Lua limit omitted changed'
assert empty['symbols']['provider']['failure'] == 'ok' and [row['name'] for row in empty['symbols']['items']] == ['src/empty.lua'], 'empty Lua changed'
assert invalid['symbols']['provider']['failure'] == 'failed' and invalid['symbols']['items'] == [], 'invalid Lua changed'
assert any('generated-file markers' in caveat for caveat in generated['symbols']['provider']['caveats']), 'Lua generated caveat missing'
assert any('dynamic bracket table assignments' in caveat for caveat in dynamic['symbols']['provider']['caveats']), 'Lua dynamic table caveat missing'
assert any('metatable-heavy Lua' in caveat for caveat in metatable['symbols']['provider']['caveats']), 'Lua metatable caveat missing'
assert any('embedded DSL strings' in caveat for caveat in embedded['symbols']['provider']['caveats']), 'Lua embedded DSL caveat missing'
assert symlink['symbols']['provider']['failure'] == 'unavailable' and symlink['symbols']['items'] == [], 'Lua symlink changed'
assert large['symbols']['provider']['failure'] == 'unavailable' and large['symbols']['items'] == [], 'Lua too-large changed'
assert missing['symbols']['provider']['failure'] == 'unavailable' and missing['symbols']['items'] == [], 'Lua missing current file changed'
assert alias['inspect']['requested_path'] == 'src/old-example.lua' and alias['inspect']['matched_path'] == 'src/example.lua', 'Lua rename alias changed'
assert all(row['path'] == 'src/example.lua' for row in alias['symbols']['items']), 'Lua alias parsed requested alias'
assert [row['name'] for row in other['symbols']['items']] == ['src/other.lua', 'other_only'], 'two-file Lua inspect changed'
assert all('current_line_history' in row for row in line['symbols']['items']), 'Lua current-line evidence missing'
assert all(row['current_line_history']['basis'] == 'current-line-range-at-head' for row in line['symbols']['items']), 'Lua line-history basis changed'
assert any(row['current_line_history']['most_recent_line_touched_timestamp'] == 1777593600 for row in line['symbols']['items']), 'Lua current-line timestamp evidence changed'
assert any(row['current_line_history']['uncommitted_or_unblamable_line_count'] > 0 for row in line['symbols']['items']), 'Lua module range did not report unblamable lines'
assert any('shallow' in ' '.join(row['current_line_history']['caveats']) for row in line_shallow['symbols']['items']), 'Lua shallow caveat missing'
assert any('partial/promisor' in ' '.join(row['current_line_history']['caveats']) for row in line_partial['symbols']['items']), 'Lua partial caveat missing'
assert any(row['current_line_history']['uncommitted_or_unblamable_line_count'] > 0 for row in line_empty['symbols']['items']), 'empty Lua line history did not degrade honestly'
assert line_invalid['symbols']['provider']['failure'] == 'failed' and line_invalid['symbols']['items'] == [], 'invalid Lua line-history should fail closed'
assert any('generated-file markers' in caveat for caveat in line_generated['symbols']['provider']['caveats']), 'Lua line-history generated caveat missing'
assert any('dynamic bracket table assignments' in caveat for caveat in line_dynamic['symbols']['provider']['caveats']), 'Lua line-history dynamic table caveat missing'
assert any('metatable-heavy Lua' in caveat for caveat in line_metatable['symbols']['provider']['caveats']), 'Lua line-history metatable caveat missing'
assert any('embedded DSL strings' in caveat for caveat in line_embedded['symbols']['provider']['caveats']), 'Lua line-history embedded DSL caveat missing'
for data in (line_generated, line_dynamic, line_metatable, line_embedded):
    assert all('current_line_history' in row for row in data['symbols']['items']), 'Lua caveated file lost current-line evidence'
for data in (line_symlink, line_large, line_missing):
    assert data['symbols']['provider']['failure'] == 'unavailable' and data['symbols']['items'] == [], 'unavailable Lua current file changed'
assert line_alias['inspect']['requested_path'] == 'src/old-example.lua' and line_alias['inspect']['matched_path'] == 'src/example.lua', 'Lua line-history rename alias changed'
assert all(row['path'] == 'src/example.lua' for row in line_alias['symbols']['items']), 'Lua line-history alias parsed requested alias'
assert all(row['current_line_history']['failure'] == 'skipped' for row in line_dirty['symbols']['items']), 'Lua dirty inspected file did not skip line history'
assert all(row['current_line_history']['failure'] == 'ok' for row in line_unrelated['symbols']['items']), 'Lua unrelated dirty file changed line history'
for data in (success, limited, empty, invalid, generated, dynamic, metatable, embedded, symlink, large, missing, alias, other):
    text = json.dumps(data, ensure_ascii=False)
    assert 'current_line_history' not in text, 'Lua line history unexpectedly emitted'
    for forbidden in ('Fixture Author', 'fixture@example', 'source line'):
        assert forbidden not in text, 'Lua private detail leaked'
for data in (line, line_shallow, line_partial, line_empty, line_invalid, line_generated, line_dynamic, line_metatable, line_embedded, line_symlink, line_large, line_missing, line_alias, line_dirty, line_unrelated):
    text = json.dumps(data, ensure_ascii=False)
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'previous filename', 'ownership', 'productivity', 'developer ranking'):
        assert forbidden not in text, 'Lua line-history private detail leaked'
PY
! grep -Eiq -- 'Fixture Author|fixture@example|source line|previous filename|ownership|productivity|developer ranking' "$tmp_dir/git-hotspots-lua-symbols.json" "$tmp_dir/git-hotspots-lua-symbols.md" "$tmp_dir/git-hotspots-lua-symbols.txt" "$tmp_dir/git-hotspots-lua-symbols-limit.json" "$tmp_dir/git-hotspots-lua-symbols-limit.md" "$tmp_dir/git-hotspots-lua-symbols-limit.txt" "$tmp_dir/git-hotspots-lua-symbols-empty.json" "$tmp_dir/git-hotspots-lua-symbols-invalid.json" "$tmp_dir/git-hotspots-lua-symbols-generated.json" "$tmp_dir/git-hotspots-lua-symbols-dynamic-table.json" "$tmp_dir/git-hotspots-lua-symbols-metatable.json" "$tmp_dir/git-hotspots-lua-symbols-embedded-dsl.json" "$tmp_dir/git-hotspots-lua-symbols-symlink-unavailable.json" "$tmp_dir/git-hotspots-lua-symbols-large-unavailable.json" "$tmp_dir/git-hotspots-lua-symbols-missing-unavailable.json" "$tmp_dir/git-hotspots-lua-symbols-rename-alias.json" "$tmp_dir/git-hotspots-lua-line-history.json" "$tmp_dir/git-hotspots-lua-line-history.md" "$tmp_dir/git-hotspots-lua-line-history.txt" "$tmp_dir/git-hotspots-lua-line-history-shallow.json" "$tmp_dir/git-hotspots-lua-line-history-partial.json" "$tmp_dir/git-hotspots-lua-line-history-empty.json" "$tmp_dir/git-hotspots-lua-line-history-invalid.json" "$tmp_dir/git-hotspots-lua-line-history-generated.json" "$tmp_dir/git-hotspots-lua-line-history-dynamic-table.json" "$tmp_dir/git-hotspots-lua-line-history-metatable.json" "$tmp_dir/git-hotspots-lua-line-history-embedded-dsl.json" "$tmp_dir/git-hotspots-lua-line-history-symlink-unavailable.json" "$tmp_dir/git-hotspots-lua-line-history-large-unavailable.json" "$tmp_dir/git-hotspots-lua-line-history-missing-unavailable.json" "$tmp_dir/git-hotspots-lua-line-history-rename-alias.json" "$tmp_dir/git-hotspots-lua-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-lua-line-history-dirty-unrelated.json" fixtures/expected/lua-symbols.json fixtures/expected/lua-symbols.md fixtures/expected/lua-symbols.txt fixtures/expected/lua-symbols-limit.json fixtures/expected/lua-symbols-limit.md fixtures/expected/lua-symbols-limit.txt fixtures/expected/lua-symbols-empty.json fixtures/expected/lua-symbols-invalid.json fixtures/expected/lua-symbols-generated.json fixtures/expected/lua-symbols-dynamic-table.json fixtures/expected/lua-symbols-metatable.json fixtures/expected/lua-symbols-embedded-dsl.json fixtures/expected/lua-symbols-symlink-unavailable.json fixtures/expected/lua-symbols-large-unavailable.json fixtures/expected/lua-symbols-missing-unavailable.json fixtures/expected/lua-symbols-rename-alias.json fixtures/expected/lua-line-history-success.json fixtures/expected/lua-line-history-success.md fixtures/expected/lua-line-history-success.txt
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols.json"
diff -u fixtures/expected/typescript-symbols.json "$tmp_dir/git-hotspots-typescript-symbols.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-typescript-symbols.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --format markdown > "$tmp_dir/git-hotspots-typescript-symbols.md"
diff -u fixtures/expected/typescript-symbols.md "$tmp_dir/git-hotspots-typescript-symbols.md"
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --format table > "$tmp_dir/git-hotspots-typescript-symbols.txt"
diff -u fixtures/expected/typescript-symbols.txt "$tmp_dir/git-hotspots-typescript-symbols.txt"
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-limit 4 --format json > "$tmp_dir/git-hotspots-typescript-symbols-limit.json"
diff -u fixtures/expected/typescript-symbols-limit.json "$tmp_dir/git-hotspots-typescript-symbols-limit.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-limit 4 --format markdown > "$tmp_dir/git-hotspots-typescript-symbols-limit.md"
diff -u fixtures/expected/typescript-symbols-limit.md "$tmp_dir/git-hotspots-typescript-symbols-limit.md"
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-limit 4 --format table > "$tmp_dir/git-hotspots-typescript-symbols-limit.txt"
diff -u fixtures/expected/typescript-symbols-limit.txt "$tmp_dir/git-hotspots-typescript-symbols-limit.txt"
"$EXE" --repo fixtures/typescript-symbols --inspect src/component.tsx --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols-tsx.json"
diff -u fixtures/expected/typescript-symbols-tsx.json "$tmp_dir/git-hotspots-typescript-symbols-tsx.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/component.tsx --symbols --format markdown > "$tmp_dir/git-hotspots-typescript-symbols-tsx.md"
diff -u fixtures/expected/typescript-symbols-tsx.md "$tmp_dir/git-hotspots-typescript-symbols-tsx.md"
"$EXE" --repo fixtures/typescript-symbols --inspect src/component.tsx --symbols --format table > "$tmp_dir/git-hotspots-typescript-symbols-tsx.txt"
diff -u fixtures/expected/typescript-symbols-tsx.txt "$tmp_dir/git-hotspots-typescript-symbols-tsx.txt"
"$EXE" --repo fixtures/typescript-symbols --inspect src/module_case.mts --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols-module.json"
diff -u fixtures/expected/typescript-symbols-module.json "$tmp_dir/git-hotspots-typescript-symbols-module.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/common_case.cts --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols-common.json"
diff -u fixtures/expected/typescript-symbols-common.json "$tmp_dir/git-hotspots-typescript-symbols-common.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/empty.ts --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols-empty.json"
diff -u fixtures/expected/typescript-symbols-empty.json "$tmp_dir/git-hotspots-typescript-symbols-empty.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/invalid_partial.ts --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols-invalid.json"
diff -u fixtures/expected/typescript-symbols-invalid.json "$tmp_dir/git-hotspots-typescript-symbols-invalid.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/generated.min.ts --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols-generated.json"
diff -u fixtures/expected/typescript-symbols-generated.json "$tmp_dir/git-hotspots-typescript-symbols-generated.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/link.ts --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols-symlink-unavailable.json"
diff -u fixtures/expected/typescript-symbols-symlink-unavailable.json "$tmp_dir/git-hotspots-typescript-symbols-symlink-unavailable.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/large.ts --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols-large-unavailable.json"
diff -u fixtures/expected/typescript-symbols-large-unavailable.json "$tmp_dir/git-hotspots-typescript-symbols-large-unavailable.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/missing.ts --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols-missing-unavailable.json"
diff -u fixtures/expected/typescript-symbols-missing-unavailable.json "$tmp_dir/git-hotspots-typescript-symbols-missing-unavailable.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/old-example.ts --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols-rename-alias.json"
diff -u fixtures/expected/typescript-symbols-rename-alias.json "$tmp_dir/git-hotspots-typescript-symbols-rename-alias.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/other.ts --symbols --format json > "$tmp_dir/git-hotspots-typescript-symbols-other.json"
! grep -Fq -- 'compute' "$tmp_dir/git-hotspots-typescript-symbols-other.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-success.json"
diff -u fixtures/expected/typescript-line-history-success.json "$tmp_dir/git-hotspots-typescript-line-history-success.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-success-2.json"
diff -u "$tmp_dir/git-hotspots-typescript-line-history-success.json" "$tmp_dir/git-hotspots-typescript-line-history-success-2.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-line-history --format markdown > "$tmp_dir/git-hotspots-typescript-line-history-success.md"
diff -u fixtures/expected/typescript-line-history-success.md "$tmp_dir/git-hotspots-typescript-line-history-success.md"
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-line-history --format table > "$tmp_dir/git-hotspots-typescript-line-history-success.txt"
diff -u fixtures/expected/typescript-line-history-success.txt "$tmp_dir/git-hotspots-typescript-line-history-success.txt"
"$EXE" --repo fixtures/typescript-symbols --inspect src/component.tsx --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-tsx.json"
diff -u fixtures/expected/typescript-line-history-tsx.json "$tmp_dir/git-hotspots-typescript-line-history-tsx.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/component.tsx --symbols --symbol-line-history --format markdown > "$tmp_dir/git-hotspots-typescript-line-history-tsx.md"
diff -u fixtures/expected/typescript-line-history-tsx.md "$tmp_dir/git-hotspots-typescript-line-history-tsx.md"
"$EXE" --repo fixtures/typescript-symbols --inspect src/component.tsx --symbols --symbol-line-history --format table > "$tmp_dir/git-hotspots-typescript-line-history-tsx.txt"
diff -u fixtures/expected/typescript-line-history-tsx.txt "$tmp_dir/git-hotspots-typescript-line-history-tsx.txt"
"$EXE" --repo fixtures/typescript-symbols-shallow --inspect src/example.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-shallow.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$tmp_dir/git-hotspots-typescript-line-history-shallow.json"
"$EXE" --repo fixtures/typescript-symbols-partial --inspect src/example.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-partial.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$tmp_dir/git-hotspots-typescript-line-history-partial.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/module_case.mts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-module.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/common_case.cts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-common.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/empty.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-empty.json"
grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-typescript-line-history-empty.json"
grep -Fq -- 'current-line Git evidence has unblamable lines in this symbol range' "$tmp_dir/git-hotspots-typescript-line-history-empty.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/invalid_partial.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-invalid.json"
grep -Fq -- '"failure": "failed"' "$tmp_dir/git-hotspots-typescript-line-history-invalid.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-typescript-line-history-invalid.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/generated.min.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-generated.json"
grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-typescript-line-history-generated.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/link.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-symlink-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-typescript-line-history-symlink-unavailable.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-typescript-line-history-symlink-unavailable.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/large.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-large-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-typescript-line-history-large-unavailable.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-typescript-line-history-large-unavailable.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/missing.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-missing-unavailable.json"
grep -Fq -- '"failure": "unavailable"' "$tmp_dir/git-hotspots-typescript-line-history-missing-unavailable.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-typescript-line-history-missing-unavailable.json"
"$EXE" --repo fixtures/typescript-symbols --inspect src/old-example.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-rename-alias.json"
grep -Fq -- '"matched_path": "src/example.ts"' "$tmp_dir/git-hotspots-typescript-line-history-rename-alias.json"
printf '// dirty inspected\n' >> fixtures/typescript-symbols/src/example.ts
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-dirty-inspected.json"
grep -Fq -- 'current-line Git evidence skipped: inspected file has staged or unstaged content changes' "$tmp_dir/git-hotspots-typescript-line-history-dirty-inspected.json"
git -C fixtures/typescript-symbols checkout -q -- src/example.ts
printf '// dirty unrelated\n' >> fixtures/typescript-symbols/src/other.ts
"$EXE" --repo fixtures/typescript-symbols --inspect src/example.ts --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-typescript-line-history-dirty-unrelated.json"
grep -Fq -- '"failure": "ok"' "$tmp_dir/git-hotspots-typescript-line-history-dirty-unrelated.json"
git -C fixtures/typescript-symbols checkout -q -- src/other.ts
python3 - "$tmp_dir/git-hotspots-typescript-symbols.json" "$tmp_dir/git-hotspots-typescript-symbols-limit.json" "$tmp_dir/git-hotspots-typescript-symbols-tsx.json" "$tmp_dir/git-hotspots-typescript-symbols-module.json" "$tmp_dir/git-hotspots-typescript-symbols-common.json" "$tmp_dir/git-hotspots-typescript-symbols-empty.json" "$tmp_dir/git-hotspots-typescript-symbols-invalid.json" "$tmp_dir/git-hotspots-typescript-symbols-generated.json" "$tmp_dir/git-hotspots-typescript-symbols-symlink-unavailable.json" "$tmp_dir/git-hotspots-typescript-symbols-large-unavailable.json" "$tmp_dir/git-hotspots-typescript-symbols-missing-unavailable.json" "$tmp_dir/git-hotspots-typescript-symbols-rename-alias.json" "$tmp_dir/git-hotspots-typescript-symbols-other.json" "$tmp_dir/git-hotspots-typescript-line-history-success.json" "$tmp_dir/git-hotspots-typescript-line-history-tsx.json" "$tmp_dir/git-hotspots-typescript-line-history-shallow.json" "$tmp_dir/git-hotspots-typescript-line-history-partial.json" "$tmp_dir/git-hotspots-typescript-line-history-module.json" "$tmp_dir/git-hotspots-typescript-line-history-common.json" "$tmp_dir/git-hotspots-typescript-line-history-empty.json" "$tmp_dir/git-hotspots-typescript-line-history-generated.json" "$tmp_dir/git-hotspots-typescript-line-history-rename-alias.json" "$tmp_dir/git-hotspots-typescript-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-typescript-line-history-dirty-unrelated.json" <<'PY'
import json, sys
ts, limited, tsx, module, common, empty, invalid, generated, symlink, large, missing, alias, other, line_ts, line_tsx, line_shallow, line_partial, line_module, line_common, line_empty, line_generated, line_alias, line_dirty, line_unrelated = [json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
assert ts['symbols']['provider']['name'] == 'tree-sitter-typescript'
assert ts['symbols']['provider']['failure'] == 'ok'
assert [row['name'] for row in ts['symbols']['items']] == ['src/example.ts', 'EXPORTED_FLAG', 'mutableCount', 'compute', 'localHelper', 'LocalWorker', 'run', 'methodHelper', 'UserShape', 'UserId', 'Mode', 'Tools', 'inside', 'café']
assert [row['kind'] for row in ts['symbols']['items']] == ['module', 'other', 'variable', 'function', 'function', 'class', 'method', 'function', 'type', 'type', 'type', 'type', 'function', 'function']
assert all(row['path'] == 'src/example.ts' for row in ts['symbols']['items'])
assert len(limited['symbols']['items']) == len(ts['symbols']['items'])
assert limited['symbols']['human_display']['shown_count'] == 4
assert limited['symbols']['human_display']['omitted_count'] == 10
assert tsx['symbols']['provider']['name'] == 'tree-sitter-tsx'
assert [row['name'] for row in tsx['symbols']['items']] == ['src/component.tsx', 'Props', 'Panel', 'InlineWidget', 'ClassWidget', 'render', 'PanelProps', 'DisplayMode']
assert [row['kind'] for row in tsx['symbols']['items']] == ['module', 'type', 'function', 'function', 'class', 'method', 'type', 'type']
assert any('TSX JSX syntax' in caveat for caveat in tsx['symbols']['provider']['caveats'])
assert [row['name'] for row in module['symbols']['items']] == ['src/module_case.mts', 'moduleEntry']
assert [row['name'] for row in common['symbols']['items']] == ['src/common_case.cts', 'legacyValue']
assert empty['symbols']['provider']['failure'] == 'ok' and [row['name'] for row in empty['symbols']['items']] == ['src/empty.ts']
assert invalid['symbols']['provider']['failure'] == 'failed' and invalid['symbols']['items'] == []
assert generated['symbols']['provider']['failure'] == 'ok' and any('generated-file markers' in caveat for caveat in generated['symbols']['provider']['caveats'])
assert symlink['symbols']['provider']['failure'] == 'unavailable' and symlink['symbols']['items'] == []
assert large['symbols']['provider']['failure'] == 'unavailable' and large['symbols']['items'] == []
assert missing['symbols']['provider']['failure'] == 'unavailable' and missing['symbols']['items'] == []
assert alias['inspect']['requested_path'] == 'src/old-example.ts' and alias['inspect']['matched_path'] == 'src/example.ts'
assert all(row['path'] == 'src/example.ts' for row in alias['symbols']['items'])
assert [row['name'] for row in other['symbols']['items']] == ['src/other.ts', 'OtherOnly']
assert all('current_line_history' in row for row in line_ts['symbols']['items']), 'TypeScript current-line evidence missing'
assert all(row['current_line_history']['basis'] == 'current-line-range-at-head' for row in line_ts['symbols']['items'])
assert any(row['current_line_history']['most_recent_line_touched_timestamp'] == 1777593600 for row in line_ts['symbols']['items'])
assert line_tsx['symbols']['provider']['name'] == 'tree-sitter-tsx'
assert all('current_line_history' in row for row in line_tsx['symbols']['items']), 'TSX current-line evidence missing'
assert any('shallow' in ' '.join(row['current_line_history']['caveats']) for row in line_shallow['symbols']['items'])
assert any('partial/promisor' in ' '.join(row['current_line_history']['caveats']) for row in line_partial['symbols']['items'])
assert all('current_line_history' in row for row in line_module['symbols']['items'])
assert all('current_line_history' in row for row in line_common['symbols']['items'])
assert any(row['current_line_history']['uncommitted_or_unblamable_line_count'] > 0 for row in line_empty['symbols']['items'])
assert all('current_line_history' in row for row in line_generated['symbols']['items'])
assert line_alias['inspect']['requested_path'] == 'src/old-example.ts' and line_alias['inspect']['matched_path'] == 'src/example.ts'
assert all(row['path'] == 'src/example.ts' for row in line_alias['symbols']['items'])
assert all(row['current_line_history']['failure'] == 'skipped' for row in line_dirty['symbols']['items'])
assert all(row['current_line_history']['failure'] == 'ok' for row in line_unrelated['symbols']['items'])
for data in (ts, limited, tsx, module, common, empty, invalid, generated, symlink, large, missing, alias, other):
    text = json.dumps(data, ensure_ascii=False)
    assert 'current_line_history' not in text
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'ownership', 'productivity', 'tsconfig path', 'Node package graph'):
        assert forbidden not in text
for data in (line_ts, line_tsx, line_shallow, line_partial, line_module, line_common, line_empty, line_generated, line_alias, line_dirty, line_unrelated):
    text = json.dumps(data, ensure_ascii=False)
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'ownership', 'productivity', 'tsconfig path', 'Node package graph'):
        assert forbidden not in text
PY
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --format json > "$tmp_dir/git-hotspots-rust-symbols.json"
diff -u fixtures/expected/rust-symbols.json "$tmp_dir/git-hotspots-rust-symbols.json"
! grep -Fq -- 'current_line_history' "$tmp_dir/git-hotspots-rust-symbols.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --format markdown > "$tmp_dir/git-hotspots-rust-symbols.md"
diff -u fixtures/expected/rust-symbols.md "$tmp_dir/git-hotspots-rust-symbols.md"
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --format table > "$tmp_dir/git-hotspots-rust-symbols.txt"
diff -u fixtures/expected/rust-symbols.txt "$tmp_dir/git-hotspots-rust-symbols.txt"
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --symbol-limit 5 --format json > "$tmp_dir/git-hotspots-rust-symbols-limit.json"
diff -u fixtures/expected/rust-symbols-limit.json "$tmp_dir/git-hotspots-rust-symbols-limit.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --symbol-limit 5 --format markdown > "$tmp_dir/git-hotspots-rust-symbols-limit.md"
diff -u fixtures/expected/rust-symbols-limit.md "$tmp_dir/git-hotspots-rust-symbols-limit.md"
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --symbol-limit 5 --format table > "$tmp_dir/git-hotspots-rust-symbols-limit.txt"
diff -u fixtures/expected/rust-symbols-limit.txt "$tmp_dir/git-hotspots-rust-symbols-limit.txt"
"$EXE" --repo fixtures/rust-symbols --inspect src/unsupported.md --symbols --format json > "$tmp_dir/git-hotspots-rust-symbols-unsupported.json"
diff -u fixtures/expected/rust-symbols-unsupported.json "$tmp_dir/git-hotspots-rust-symbols-unsupported.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/empty.rs --symbols --format json > "$tmp_dir/git-hotspots-rust-symbols-empty.json"
diff -u fixtures/expected/rust-symbols-empty.json "$tmp_dir/git-hotspots-rust-symbols-empty.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/invalid_partial.rs --symbols --format json > "$tmp_dir/git-hotspots-rust-symbols-invalid.json"
diff -u fixtures/expected/rust-symbols-invalid.json "$tmp_dir/git-hotspots-rust-symbols-invalid.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/generated.rs --symbols --format json > "$tmp_dir/git-hotspots-rust-symbols-generated.json"
diff -u fixtures/expected/rust-symbols-generated.json "$tmp_dir/git-hotspots-rust-symbols-generated.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/macro_cfg.rs --symbols --format json > "$tmp_dir/git-hotspots-rust-symbols-macro-cfg.json"
diff -u fixtures/expected/rust-symbols-macro-cfg.json "$tmp_dir/git-hotspots-rust-symbols-macro-cfg.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/link.rs --symbols --format json > "$tmp_dir/git-hotspots-rust-symbols-symlink-unavailable.json"
diff -u fixtures/expected/rust-symbols-symlink-unavailable.json "$tmp_dir/git-hotspots-rust-symbols-symlink-unavailable.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/large.rs --symbols --format json > "$tmp_dir/git-hotspots-rust-symbols-large-unavailable.json"
diff -u fixtures/expected/rust-symbols-large-unavailable.json "$tmp_dir/git-hotspots-rust-symbols-large-unavailable.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/missing.rs --symbols --format json > "$tmp_dir/git-hotspots-rust-symbols-missing-unavailable.json"
diff -u fixtures/expected/rust-symbols-missing-unavailable.json "$tmp_dir/git-hotspots-rust-symbols-missing-unavailable.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/old-example.rs --symbols --format json > "$tmp_dir/git-hotspots-rust-symbols-rename-alias.json"
diff -u fixtures/expected/rust-symbols-rename-alias.json "$tmp_dir/git-hotspots-rust-symbols-rename-alias.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/other.rs --symbols --format json > "$tmp_dir/git-hotspots-rust-symbols-other.json"
! grep -Fq -- 'top_function' "$tmp_dir/git-hotspots-rust-symbols-other.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-success.json"
diff -u fixtures/expected/rust-line-history-success.json "$tmp_dir/git-hotspots-rust-line-history-success.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-success-2.json"
diff -u "$tmp_dir/git-hotspots-rust-line-history-success.json" "$tmp_dir/git-hotspots-rust-line-history-success-2.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --symbol-line-history --format markdown > "$tmp_dir/git-hotspots-rust-line-history-success.md"
diff -u fixtures/expected/rust-line-history-success.md "$tmp_dir/git-hotspots-rust-line-history-success.md"
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --symbol-line-history --format table > "$tmp_dir/git-hotspots-rust-line-history-success.txt"
diff -u fixtures/expected/rust-line-history-success.txt "$tmp_dir/git-hotspots-rust-line-history-success.txt"
"$EXE" --repo fixtures/rust-symbols-shallow --inspect src/example.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-shallow.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' "$tmp_dir/git-hotspots-rust-line-history-shallow.json"
"$EXE" --repo fixtures/rust-symbols-partial --inspect src/example.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-partial.json"
grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' "$tmp_dir/git-hotspots-rust-line-history-partial.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/empty.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-empty.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/invalid_partial.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-invalid.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/generated.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-generated.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/macro_cfg.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-macro-cfg.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/link.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-symlink-unavailable.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/large.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-large-unavailable.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/missing.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-missing-unavailable.json"
"$EXE" --repo fixtures/rust-symbols --inspect src/old-example.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-rename-alias.json"
printf '// dirty inspected\n' >> fixtures/rust-symbols/src/example.rs
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-dirty-inspected.json"
grep -Fq -- 'current-line Git evidence skipped: inspected file has staged or unstaged content changes' "$tmp_dir/git-hotspots-rust-line-history-dirty-inspected.json"
git -C fixtures/rust-symbols checkout -q -- src/example.rs
printf '// dirty unrelated\n' >> fixtures/rust-symbols/src/other.rs
"$EXE" --repo fixtures/rust-symbols --inspect src/example.rs --symbols --symbol-line-history --format json > "$tmp_dir/git-hotspots-rust-line-history-dirty-unrelated.json"
grep -Fq -- '"failure": "ok"' "$tmp_dir/git-hotspots-rust-line-history-dirty-unrelated.json"
git -C fixtures/rust-symbols checkout -q -- src/other.rs
python3 - "$tmp_dir/git-hotspots-rust-symbols.json" "$tmp_dir/git-hotspots-rust-symbols-limit.json" "$tmp_dir/git-hotspots-rust-symbols-unsupported.json" "$tmp_dir/git-hotspots-rust-symbols-empty.json" "$tmp_dir/git-hotspots-rust-symbols-invalid.json" "$tmp_dir/git-hotspots-rust-symbols-generated.json" "$tmp_dir/git-hotspots-rust-symbols-macro-cfg.json" "$tmp_dir/git-hotspots-rust-symbols-symlink-unavailable.json" "$tmp_dir/git-hotspots-rust-symbols-large-unavailable.json" "$tmp_dir/git-hotspots-rust-symbols-missing-unavailable.json" "$tmp_dir/git-hotspots-rust-symbols-rename-alias.json" "$tmp_dir/git-hotspots-rust-symbols-other.json" "$tmp_dir/git-hotspots-rust-line-history-success.json" "$tmp_dir/git-hotspots-rust-line-history-shallow.json" "$tmp_dir/git-hotspots-rust-line-history-partial.json" "$tmp_dir/git-hotspots-rust-line-history-empty.json" "$tmp_dir/git-hotspots-rust-line-history-invalid.json" "$tmp_dir/git-hotspots-rust-line-history-generated.json" "$tmp_dir/git-hotspots-rust-line-history-macro-cfg.json" "$tmp_dir/git-hotspots-rust-line-history-symlink-unavailable.json" "$tmp_dir/git-hotspots-rust-line-history-large-unavailable.json" "$tmp_dir/git-hotspots-rust-line-history-missing-unavailable.json" "$tmp_dir/git-hotspots-rust-line-history-rename-alias.json" "$tmp_dir/git-hotspots-rust-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-rust-line-history-dirty-unrelated.json" <<'PY'
import json, sys
success, limited, unsupported, empty, invalid, generated, macro_cfg, symlink, large, missing, alias, other, line, line_shallow, line_partial, line_empty, line_invalid, line_generated, line_macro_cfg, line_symlink, line_large, line_missing, line_alias, line_dirty, line_unrelated = [json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
assert success['symbols']['provider']['name'] == 'tree-sitter-rust', 'Rust provider missing'
assert success['symbols']['provider']['failure'] == 'ok', 'Rust provider failure changed'
assert [row['name'] for row in success['symbols']['items']] == ['src/example.rs', 'LIMIT', 'NAME', 'nested', 'Unit', 'Tuple', 'Record', 'Choice', 'First', 'Second', 'Third', 'Render', 'render', 'label', 'new', 'value', 'helper', 'top_function', 'external', 'r#async', 'MARKDOWN_NAME'], 'Rust source order changed'
assert [row['kind'] for row in success['symbols']['items']] == ['module', 'other', 'other', 'module', 'type', 'type', 'type', 'type', 'other', 'other', 'other', 'type', 'method', 'method', 'method', 'method', 'function', 'function', 'module', 'function', 'other'], 'Rust kinds changed'
assert all(row['path'] == 'src/example.rs' for row in success['symbols']['items']), 'Rust path changed'
assert len(limited['symbols']['items']) == len(success['symbols']['items']), 'Rust limit truncated JSON'
assert limited['symbols']['human_display']['shown_count'] == 5, 'Rust limit shown changed'
assert limited['symbols']['human_display']['omitted_count'] == 16, 'Rust limit omitted changed'
assert unsupported['symbols']['provider']['failure'] == 'unsupported' and unsupported['symbols']['items'] == [], 'Rust unsupported fallback changed'
assert empty['symbols']['provider']['failure'] == 'ok' and [row['name'] for row in empty['symbols']['items']] == ['src/empty.rs'], 'empty Rust changed'
assert invalid['symbols']['provider']['failure'] == 'failed' and invalid['symbols']['items'] == [], 'invalid Rust changed'
assert any('generated-file markers' in caveat for caveat in generated['symbols']['provider']['caveats']), 'Rust generated caveat missing'
assert any('macro definitions and invocations' in caveat for caveat in macro_cfg['symbols']['provider']['caveats']), 'Rust macro caveat missing'
assert any('conditional compilation attributes' in caveat for caveat in macro_cfg['symbols']['provider']['caveats']), 'Rust cfg caveat missing'
assert symlink['symbols']['provider']['failure'] == 'unavailable' and symlink['symbols']['items'] == [], 'Rust symlink changed'
assert large['symbols']['provider']['failure'] == 'unavailable' and large['symbols']['items'] == [], 'Rust too-large changed'
assert missing['symbols']['provider']['failure'] == 'unavailable' and missing['symbols']['items'] == [], 'Rust missing current file changed'
assert alias['inspect']['requested_path'] == 'src/old-example.rs' and alias['inspect']['matched_path'] == 'src/example.rs', 'Rust rename alias changed'
assert all(row['path'] == 'src/example.rs' for row in alias['symbols']['items']), 'Rust alias parsed requested alias'
assert [row['name'] for row in other['symbols']['items']] == ['src/other.rs', 'other_only'], 'two-file Rust inspect changed'
assert all('current_line_history' in row for row in line['symbols']['items']), 'Rust current-line evidence missing'
assert all(row['current_line_history']['basis'] == 'current-line-range-at-head' for row in line['symbols']['items']), 'Rust line-history basis changed'
assert any(row['current_line_history']['most_recent_line_touched_timestamp'] == 1777593600 for row in line['symbols']['items']), 'Rust current-line timestamp evidence changed'
assert any('shallow' in ' '.join(row['current_line_history']['caveats']) for row in line_shallow['symbols']['items']), 'Rust shallow caveat missing'
assert any('partial/promisor' in ' '.join(row['current_line_history']['caveats']) for row in line_partial['symbols']['items']), 'Rust partial caveat missing'
assert any(row['current_line_history']['uncommitted_or_unblamable_line_count'] > 0 for row in line_empty['symbols']['items']), 'empty Rust line history did not degrade honestly'
assert line_invalid['symbols']['provider']['failure'] == 'failed' and line_invalid['symbols']['items'] == [], 'invalid Rust line-history should fail closed'
assert any('generated-file markers' in caveat for caveat in line_generated['symbols']['provider']['caveats']), 'Rust line-history generated caveat missing'
assert any('macro definitions and invocations' in caveat for caveat in line_macro_cfg['symbols']['provider']['caveats']), 'Rust line-history macro caveat missing'
assert any('conditional compilation attributes' in caveat for caveat in line_macro_cfg['symbols']['provider']['caveats']), 'Rust line-history cfg caveat missing'
for data in (line_symlink, line_large, line_missing):
    assert data['symbols']['provider']['failure'] == 'unavailable' and data['symbols']['items'] == [], 'unavailable Rust current file changed'
assert line_alias['inspect']['requested_path'] == 'src/old-example.rs' and line_alias['inspect']['matched_path'] == 'src/example.rs', 'Rust line-history rename alias changed'
assert all(row['path'] == 'src/example.rs' for row in line_alias['symbols']['items']), 'Rust line-history alias parsed requested alias'
assert all(row['current_line_history']['failure'] == 'skipped' for row in line_dirty['symbols']['items']), 'Rust dirty inspected file did not skip line history'
assert all(row['current_line_history']['failure'] == 'ok' for row in line_unrelated['symbols']['items']), 'Rust unrelated dirty file changed line history'
for data in (success, limited, unsupported, empty, invalid, generated, macro_cfg, symlink, large, missing, alias, other):
    text = json.dumps(data, ensure_ascii=False)
    assert 'current_line_history' not in text, 'Rust line history unexpectedly emitted'
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'ownership', 'productivity', 'Cargo metadata'):
        assert forbidden not in text, 'Rust private detail leaked'
for data in (line, line_shallow, line_partial, line_empty, line_invalid, line_generated, line_macro_cfg, line_symlink, line_large, line_missing, line_alias, line_dirty, line_unrelated):
    text = json.dumps(data, ensure_ascii=False)
    for forbidden in ('Fixture Author', 'fixture@example', 'source line', 'previous filename', 'ownership', 'productivity', 'developer ranking', 'Cargo metadata'):
        assert forbidden not in text, 'Rust line-history private detail leaked'
PY
! grep -Eiq -- 'Fixture Author|fixture@example|fixture function|private|file://|raw blame|source line|previous filename|ownership|productivity|developer ranking|Cargo metadata' "$tmp_dir/git-hotspots-rust-symbols.json" "$tmp_dir/git-hotspots-rust-symbols.md" "$tmp_dir/git-hotspots-rust-symbols.txt" "$tmp_dir/git-hotspots-rust-symbols-limit.json" "$tmp_dir/git-hotspots-rust-symbols-limit.md" "$tmp_dir/git-hotspots-rust-symbols-limit.txt" "$tmp_dir/git-hotspots-rust-symbols-unsupported.json" "$tmp_dir/git-hotspots-rust-symbols-empty.json" "$tmp_dir/git-hotspots-rust-symbols-invalid.json" "$tmp_dir/git-hotspots-rust-symbols-generated.json" "$tmp_dir/git-hotspots-rust-symbols-macro-cfg.json" "$tmp_dir/git-hotspots-rust-symbols-symlink-unavailable.json" "$tmp_dir/git-hotspots-rust-symbols-large-unavailable.json" "$tmp_dir/git-hotspots-rust-symbols-missing-unavailable.json" "$tmp_dir/git-hotspots-rust-symbols-rename-alias.json" "$tmp_dir/git-hotspots-rust-line-history-success.json" "$tmp_dir/git-hotspots-rust-line-history-success.md" "$tmp_dir/git-hotspots-rust-line-history-success.txt" "$tmp_dir/git-hotspots-rust-line-history-shallow.json" "$tmp_dir/git-hotspots-rust-line-history-partial.json" "$tmp_dir/git-hotspots-rust-line-history-empty.json" "$tmp_dir/git-hotspots-rust-line-history-invalid.json" "$tmp_dir/git-hotspots-rust-line-history-generated.json" "$tmp_dir/git-hotspots-rust-line-history-macro-cfg.json" "$tmp_dir/git-hotspots-rust-line-history-symlink-unavailable.json" "$tmp_dir/git-hotspots-rust-line-history-large-unavailable.json" "$tmp_dir/git-hotspots-rust-line-history-missing-unavailable.json" "$tmp_dir/git-hotspots-rust-line-history-rename-alias.json" "$tmp_dir/git-hotspots-rust-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-rust-line-history-dirty-unrelated.json" fixtures/expected/rust-symbols.json fixtures/expected/rust-symbols.md fixtures/expected/rust-symbols.txt fixtures/expected/rust-symbols-limit.json fixtures/expected/rust-symbols-limit.md fixtures/expected/rust-symbols-limit.txt fixtures/expected/rust-symbols-unsupported.json fixtures/expected/rust-symbols-empty.json fixtures/expected/rust-symbols-invalid.json fixtures/expected/rust-symbols-generated.json fixtures/expected/rust-symbols-macro-cfg.json fixtures/expected/rust-symbols-symlink-unavailable.json fixtures/expected/rust-symbols-large-unavailable.json fixtures/expected/rust-symbols-missing-unavailable.json fixtures/expected/rust-symbols-rename-alias.json fixtures/expected/rust-line-history-success.json fixtures/expected/rust-line-history-success.md fixtures/expected/rust-line-history-success.txt
! grep -Eiq -- 'Fixture Author|fixture@example|fixture function|private|file://|raw blame|source line|previous filename|ownership|productivity|developer ranking' "$tmp_dir/git-hotspots-javascript-symbols.json" "$tmp_dir/git-hotspots-javascript-symbols.md" "$tmp_dir/git-hotspots-javascript-symbols.txt" "$tmp_dir/git-hotspots-javascript-symbols-limit.json" "$tmp_dir/git-hotspots-javascript-symbols-limit.md" "$tmp_dir/git-hotspots-javascript-symbols-limit.txt" "$tmp_dir/git-hotspots-javascript-symbols-commonjs.json" "$tmp_dir/git-hotspots-javascript-symbols-jsx.json" "$tmp_dir/git-hotspots-javascript-symbols-anonymous.json" "$tmp_dir/git-hotspots-javascript-symbols-empty.json" "$tmp_dir/git-hotspots-javascript-symbols-invalid.json" "$tmp_dir/git-hotspots-javascript-symbols-generated.json" "$tmp_dir/git-hotspots-javascript-symbols-symlink-unavailable.json" "$tmp_dir/git-hotspots-javascript-symbols-large-unavailable.json" "$tmp_dir/git-hotspots-javascript-symbols-missing-unavailable.json" "$tmp_dir/git-hotspots-javascript-symbols-rename-alias.json" "$tmp_dir/git-hotspots-javascript-symbols-other.json" "$tmp_dir/git-hotspots-typescript-symbols.json" "$tmp_dir/git-hotspots-typescript-symbols.md" "$tmp_dir/git-hotspots-typescript-symbols.txt" "$tmp_dir/git-hotspots-typescript-symbols-limit.json" "$tmp_dir/git-hotspots-typescript-symbols-limit.md" "$tmp_dir/git-hotspots-typescript-symbols-limit.txt" "$tmp_dir/git-hotspots-typescript-symbols-tsx.json" "$tmp_dir/git-hotspots-typescript-symbols-tsx.md" "$tmp_dir/git-hotspots-typescript-symbols-tsx.txt" "$tmp_dir/git-hotspots-typescript-symbols-module.json" "$tmp_dir/git-hotspots-typescript-symbols-common.json" "$tmp_dir/git-hotspots-typescript-symbols-empty.json" "$tmp_dir/git-hotspots-typescript-symbols-invalid.json" "$tmp_dir/git-hotspots-typescript-symbols-generated.json" "$tmp_dir/git-hotspots-typescript-symbols-symlink-unavailable.json" "$tmp_dir/git-hotspots-typescript-symbols-large-unavailable.json" "$tmp_dir/git-hotspots-typescript-symbols-missing-unavailable.json" "$tmp_dir/git-hotspots-typescript-symbols-rename-alias.json" "$tmp_dir/git-hotspots-typescript-symbols-other.json" "$tmp_dir/git-hotspots-typescript-line-history-success.json" "$tmp_dir/git-hotspots-typescript-line-history-success.md" "$tmp_dir/git-hotspots-typescript-line-history-success.txt" "$tmp_dir/git-hotspots-typescript-line-history-tsx.json" "$tmp_dir/git-hotspots-typescript-line-history-tsx.md" "$tmp_dir/git-hotspots-typescript-line-history-tsx.txt" "$tmp_dir/git-hotspots-typescript-line-history-shallow.json" "$tmp_dir/git-hotspots-typescript-line-history-partial.json" "$tmp_dir/git-hotspots-typescript-line-history-module.json" "$tmp_dir/git-hotspots-typescript-line-history-common.json" "$tmp_dir/git-hotspots-typescript-line-history-empty.json" "$tmp_dir/git-hotspots-typescript-line-history-invalid.json" "$tmp_dir/git-hotspots-typescript-line-history-generated.json" "$tmp_dir/git-hotspots-typescript-line-history-symlink-unavailable.json" "$tmp_dir/git-hotspots-typescript-line-history-large-unavailable.json" "$tmp_dir/git-hotspots-typescript-line-history-missing-unavailable.json" "$tmp_dir/git-hotspots-typescript-line-history-rename-alias.json" "$tmp_dir/git-hotspots-typescript-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-typescript-line-history-dirty-unrelated.json" fixtures/expected/javascript-symbols.json fixtures/expected/javascript-symbols.md fixtures/expected/javascript-symbols.txt fixtures/expected/javascript-symbols-limit.json fixtures/expected/javascript-symbols-limit.md fixtures/expected/javascript-symbols-limit.txt fixtures/expected/javascript-symbols-commonjs.json fixtures/expected/javascript-symbols-jsx.json fixtures/expected/javascript-symbols-anonymous.json fixtures/expected/javascript-symbols-empty.json fixtures/expected/javascript-symbols-invalid.json fixtures/expected/javascript-symbols-generated.json fixtures/expected/javascript-symbols-symlink-unavailable.json fixtures/expected/javascript-symbols-large-unavailable.json fixtures/expected/javascript-symbols-missing-unavailable.json fixtures/expected/javascript-symbols-rename-alias.json fixtures/expected/javascript-line-history-success.json fixtures/expected/javascript-line-history-success.md fixtures/expected/javascript-line-history-success.txt fixtures/expected/typescript-symbols.json fixtures/expected/typescript-symbols.md fixtures/expected/typescript-symbols.txt fixtures/expected/typescript-symbols-limit.json fixtures/expected/typescript-symbols-limit.md fixtures/expected/typescript-symbols-limit.txt fixtures/expected/typescript-symbols-tsx.json fixtures/expected/typescript-symbols-tsx.md fixtures/expected/typescript-symbols-tsx.txt fixtures/expected/typescript-symbols-module.json fixtures/expected/typescript-symbols-common.json fixtures/expected/typescript-symbols-empty.json fixtures/expected/typescript-symbols-invalid.json fixtures/expected/typescript-symbols-generated.json fixtures/expected/typescript-symbols-symlink-unavailable.json fixtures/expected/typescript-symbols-large-unavailable.json fixtures/expected/typescript-symbols-missing-unavailable.json fixtures/expected/typescript-symbols-rename-alias.json fixtures/expected/typescript-line-history-success.json fixtures/expected/typescript-line-history-success.md fixtures/expected/typescript-line-history-success.txt fixtures/expected/typescript-line-history-tsx.json fixtures/expected/typescript-line-history-tsx.md fixtures/expected/typescript-line-history-tsx.txt
! grep -Eiq -- 'Fixture Author|fixture@example|fixture function|private|file://|raw blame|source line|previous filename|ownership|productivity|developer ranking' "$tmp_dir/git-hotspots-go-line-history-success.json" "$tmp_dir/git-hotspots-go-line-history-success.md" "$tmp_dir/git-hotspots-go-line-history-success.txt" "$tmp_dir/git-hotspots-go-line-history-shallow.json" "$tmp_dir/git-hotspots-go-line-history-partial.json" "$tmp_dir/git-hotspots-go-line-history-empty.json" "$tmp_dir/git-hotspots-go-line-history-invalid.json" "$tmp_dir/git-hotspots-go-line-history-symlink-unavailable.json" "$tmp_dir/git-hotspots-go-line-history-large-unavailable.json" "$tmp_dir/git-hotspots-go-line-history-missing-unavailable.json" "$tmp_dir/git-hotspots-go-line-history-rename-alias.json" "$tmp_dir/git-hotspots-go-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-go-line-history-dirty-unrelated.json" "$tmp_dir/git-hotspots-python-line-history-success.json" "$tmp_dir/git-hotspots-python-line-history-success.md" "$tmp_dir/git-hotspots-python-line-history-success.txt" "$tmp_dir/git-hotspots-python-line-history-shallow.json" "$tmp_dir/git-hotspots-python-line-history-partial.json" "$tmp_dir/git-hotspots-python-line-history-empty.json" "$tmp_dir/git-hotspots-python-line-history-invalid.json" "$tmp_dir/git-hotspots-python-line-history-symlink-unavailable.json" "$tmp_dir/git-hotspots-python-line-history-large-unavailable.json" "$tmp_dir/git-hotspots-python-line-history-missing-unavailable.json" "$tmp_dir/git-hotspots-python-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-python-line-history-dirty-unrelated.json" "$tmp_dir/git-hotspots-javascript-line-history-success.json" "$tmp_dir/git-hotspots-javascript-line-history-success.md" "$tmp_dir/git-hotspots-javascript-line-history-success.txt" "$tmp_dir/git-hotspots-javascript-line-history-shallow.json" "$tmp_dir/git-hotspots-javascript-line-history-partial.json" "$tmp_dir/git-hotspots-javascript-line-history-commonjs.json" "$tmp_dir/git-hotspots-javascript-line-history-jsx.json" "$tmp_dir/git-hotspots-javascript-line-history-anonymous.json" "$tmp_dir/git-hotspots-javascript-line-history-empty.json" "$tmp_dir/git-hotspots-javascript-line-history-invalid.json" "$tmp_dir/git-hotspots-javascript-line-history-generated.json" "$tmp_dir/git-hotspots-javascript-line-history-symlink-unavailable.json" "$tmp_dir/git-hotspots-javascript-line-history-large-unavailable.json" "$tmp_dir/git-hotspots-javascript-line-history-missing-unavailable.json" "$tmp_dir/git-hotspots-javascript-line-history-rename-alias.json" "$tmp_dir/git-hotspots-javascript-line-history-dirty-inspected.json" "$tmp_dir/git-hotspots-javascript-line-history-dirty-unrelated.json" fixtures/expected/go-line-history-success.json fixtures/expected/go-line-history-success.md fixtures/expected/go-line-history-success.txt fixtures/expected/python-line-history-success.json fixtures/expected/python-line-history-success.md fixtures/expected/python-line-history-success.txt fixtures/expected/javascript-line-history-success.json fixtures/expected/javascript-line-history-success.md fixtures/expected/javascript-line-history-success.txt
"$EXE" --repo fixtures/scope --format json > "$tmp_dir/git-hotspots-scope-unfiltered.json"
"$EXE" --repo fixtures/scope --scope all --limit 200 --format json > "$tmp_dir/git-hotspots-scope-all.json"
"$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --format json > "$tmp_dir/git-hotspots-scope-filtered.json"
diff -u fixtures/expected/scope-filtered.json "$tmp_dir/git-hotspots-scope-filtered.json"
"$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --format markdown > "$tmp_dir/git-hotspots-scope-filtered.md"
diff -u fixtures/expected/scope-filtered.md "$tmp_dir/git-hotspots-scope-filtered.md"
"$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --format markdown > "$tmp_dir/git-hotspots-scope-filtered-2.md"
diff -u "$tmp_dir/git-hotspots-scope-filtered.md" "$tmp_dir/git-hotspots-scope-filtered-2.md"
"$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --format table > "$tmp_dir/git-hotspots-scope-filtered.txt"
"$EXE" --repo fixtures/scope --scope project --format json > "$tmp_dir/git-hotspots-scope-project.json"
diff -u "$tmp_dir/git-hotspots-scope-unfiltered.json" "$tmp_dir/git-hotspots-scope-project.json"
diff -u fixtures/expected/scope-project.json "$tmp_dir/git-hotspots-scope-project.json"
"$EXE" --repo fixtures/scope --scope project --progress --format json > "$tmp_dir/git-hotspots-scope-project-progress.json" 2> "$tmp_dir/git-hotspots-scope-project-progress.err"
diff -u "$tmp_dir/git-hotspots-scope-project.json" "$tmp_dir/git-hotspots-scope-project-progress.json"
assert_progress_stderr scope-project "$tmp_dir/git-hotspots-scope-project-progress.err"
"$EXE" --repo fixtures/scope --scope project --format json > "$tmp_dir/git-hotspots-scope-project-2.json"
diff -u "$tmp_dir/git-hotspots-scope-project.json" "$tmp_dir/git-hotspots-scope-project-2.json"
"$EXE" --repo fixtures/scope --scope project --format markdown > "$tmp_dir/git-hotspots-scope-project.md"
diff -u fixtures/expected/scope-project.md "$tmp_dir/git-hotspots-scope-project.md"
"$EXE" --repo fixtures/scope --scope project --format markdown > "$tmp_dir/git-hotspots-scope-project-2.md"
diff -u "$tmp_dir/git-hotspots-scope-project.md" "$tmp_dir/git-hotspots-scope-project-2.md"
"$EXE" --repo fixtures/scope --scope project --format table > "$tmp_dir/git-hotspots-scope-project.txt"
"$EXE" --repo fixtures/scope --scope project --inspect src/vendor_adapter.zig --format json > "$tmp_dir/git-hotspots-scope-project-inspect.json"
"$EXE" --repo fixtures/scope --scope all --inspect .flow/state.yaml --format json > "$tmp_dir/git-hotspots-scope-all-inspect-flow.json"
"$EXE" --repo fixtures/scope --scope all --inspect .zig-cache/from-src.txt --format json > "$tmp_dir/git-hotspots-scope-all-inspect-included-to-excluded.json"
"$EXE" --repo fixtures/scope --scope all --inspect build/excluded-chain-b.txt --format json > "$tmp_dir/git-hotspots-scope-all-inspect-excluded-to-excluded.json"
"$EXE" --repo fixtures/scope --scope all --inspect src/chain-final.txt --format json > "$tmp_dir/git-hotspots-scope-all-inspect-chained-cross-prefix.json"
assert_fails_with_stderr inspect-project-excluded-flow "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --scope project --inspect .flow/state.yaml --format json
assert_fails_with_stderr inspect-project-included-to-excluded "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --scope project --inspect .zig-cache/from-src.txt --format json
assert_fails_with_stderr inspect-project-excluded-to-excluded-new "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --scope project --inspect build/excluded-chain-b.txt --format json
assert_fails_with_stderr inspect-project-excluded-to-excluded-old "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --scope project --inspect target/excluded-chain-a.txt --format json
assert_fails_with_stderr inspect-project-chained-excluded-hop "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --scope project --inspect node_modules/pkg/chain-mid.txt --format json
"$EXE" --repo fixtures/scope --scope project --inspect src/to-cache.txt --format json > "$tmp_dir/git-hotspots-scope-project-inspect-included-to-excluded-old.json"
"$EXE" --repo fixtures/scope --scope project --inspect src/chain-final.txt --format json > "$tmp_dir/git-hotspots-scope-project-inspect-chained-cross-prefix.json"
"$EXE" --repo fixtures/scope --scope project --exclude-prefix .flow/ --format json > "$tmp_dir/git-hotspots-scope-project-duplicate-flow.json"
"$EXE" --repo fixtures/scope --scope project --include-prefix .flow/ --format json > "$tmp_dir/git-hotspots-scope-project-include-flow.json"
"$EXE" --repo fixtures/scope --scope project --include-prefix node_modules/ --format json > "$tmp_dir/git-hotspots-scope-project-include-node-modules.json"
"$EXE" --repo fixtures/scope --scope all --include-prefix node_modules/ --format json > "$tmp_dir/git-hotspots-scope-all-include-node-modules.json"
"$EXE" --repo fixtures/scope --scope project --include-prefix src/ --format json > "$tmp_dir/git-hotspots-scope-project-include-src.json"
"$EXE" --repo fixtures/scope --include-prefix src/ --format json > "$tmp_dir/git-hotspots-scope-src-include.json"
"$EXE" --repo fixtures/scope --include-prefix src/ --format markdown > "$tmp_dir/git-hotspots-scope-src-include.md"
"$EXE" --repo fixtures/scope --include-prefix src/ --format table > "$tmp_dir/git-hotspots-scope-src-include.txt"
"$EXE" --repo fixtures/scope --include-prefix src/ --include-prefix vendor/ --format json > "$tmp_dir/git-hotspots-scope-src-vendor-include.json"
"$EXE" --repo fixtures/scope --include-prefix src/ --exclude-prefix src/vendor_adapter.zig --format json > "$tmp_dir/git-hotspots-scope-include-exclude.json"
"$EXE" --repo fixtures/scope --exclude-prefix vendor/ --format json > "$tmp_dir/git-hotspots-scope-vendor-filtered.json"
"$EXE" --repo fixtures/scope --exclude-prefix src/ --format json > "$tmp_dir/git-hotspots-scope-src-filtered.json"
"$EXE" --repo fixtures/scope --exclude-prefix weird/ --format json > "$tmp_dir/git-hotspots-scope-weird-filtered.json"
"$EXE" --repo fixtures/scope --exclude-prefix 'glob/*' --format json > "$tmp_dir/git-hotspots-scope-glob-prefix.json"
"$EXE" --repo fixtures/scope --include-prefix weird/ --format json > "$tmp_dir/git-hotspots-scope-weird-include.json"
"$EXE" --repo fixtures/scope --include-prefix 'glob/*' --format json > "$tmp_dir/git-hotspots-scope-glob-star-include.json"
"$EXE" --repo fixtures/scope --include-prefix glob/ --format json > "$tmp_dir/git-hotspots-scope-glob-include.json"
"$EXE" --repo fixtures/scope --include-prefix does-not-exist/ --format json > "$tmp_dir/git-hotspots-scope-include-empty.json"
"$EXE" --repo fixtures/scope --include-prefix does-not-exist/ --format markdown > "$tmp_dir/git-hotspots-scope-include-empty.md"
"$EXE" --repo fixtures/scope --exclude-prefix .flow/ --exclude-prefix src/ --exclude-prefix vendor/ --exclude-prefix glob/ --exclude-prefix weird/ --exclude-prefix docs/ --format json > "$tmp_dir/git-hotspots-scope-empty.json"
"$EXE" --repo fixtures/scope --exclude-prefix .flow/ --exclude-prefix src/ --exclude-prefix vendor/ --exclude-prefix glob/ --exclude-prefix weird/ --exclude-prefix docs/ --format markdown > "$tmp_dir/git-hotspots-scope-empty.md"
"$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --inspect src/vendor_adapter.zig --format json > "$tmp_dir/git-hotspots-scope-inspect-excluded-flow.json"
"$EXE" --repo fixtures/scope --include-prefix src/ --inspect src/new.zig --format json > "$tmp_dir/git-hotspots-scope-inspect-include-renamed.json"
"$EXE" --repo fixtures/lineage --inspect simple-new.txt --format json > "$tmp_dir/git-hotspots-lineage-simple.json"
grep -Fq -- '"lineage": { "aliases": ["simple-old.txt"], "partial": false' "$tmp_dir/git-hotspots-lineage-simple.json"
"$EXE" --repo fixtures/lineage --inspect braced/new-name.txt --format json > "$tmp_dir/git-hotspots-lineage-braced.json"
grep -Fq -- '"lineage": { "aliases": ["braced/old-name.txt"], "partial": false' "$tmp_dir/git-hotspots-lineage-braced.json"
"$EXE" --repo fixtures/lineage --inspect chain/c.txt --format json > "$tmp_dir/git-hotspots-lineage-chain.json"
grep -Fq -- '"lineage": { "aliases": ["chain/a.txt", "chain/b.txt"], "partial": false' "$tmp_dir/git-hotspots-lineage-chain.json"
grep -Fq -- '"change_count": 3' "$tmp_dir/git-hotspots-lineage-chain.json"
"$EXE" --repo fixtures/lineage --inspect chain/a.txt --format json > "$tmp_dir/git-hotspots-lineage-alias-inspect.json"
grep -Fq -- '"inspect": { "requested_path": "chain/a.txt", "matched_path": "chain/c.txt"' "$tmp_dir/git-hotspots-lineage-alias-inspect.json"
"$EXE" --repo fixtures/lineage --inspect rename-edit-new.txt --format json > "$tmp_dir/git-hotspots-lineage-rename-edit.json"
grep -Fq -- '"lineage": { "aliases": ["rename-edit-old.txt"], "partial": false' "$tmp_dir/git-hotspots-lineage-rename-edit.json"
grep -Fq -- '"additions": 2' "$tmp_dir/git-hotspots-lineage-rename-edit.json"
"$EXE" --repo fixtures/lineage --inspect deleted-new.txt --format json > "$tmp_dir/git-hotspots-lineage-deleted.json"
grep -Fq -- '"lineage": { "aliases": ["deleted-old.txt"], "partial": false' "$tmp_dir/git-hotspots-lineage-deleted.json"
grep -Fq -- '"current_size": null' "$tmp_dir/git-hotspots-lineage-deleted.json"
"$EXE" --repo fixtures/lineage --inspect cochange/new.txt --format json > "$tmp_dir/git-hotspots-lineage-cochange.json"
grep -Fq -- '{ "path": "cochange/peer.txt", "count": 4 }' "$tmp_dir/git-hotspots-lineage-cochange.json"
"$EXE" --repo fixtures/lineage --include-prefix src/ --inspect src/cross-new.txt --format json > "$tmp_dir/git-hotspots-lineage-cross-scope.json"
grep -Fq -- '"lineage": { "aliases": [], "partial": true' "$tmp_dir/git-hotspots-lineage-cross-scope.json"
! grep -Fq -- 'vendor/cross-old.txt' "$tmp_dir/git-hotspots-lineage-cross-scope.json"
"$EXE" --repo fixtures/edge --inspect 'glob/[literal]*.txt' --format markdown > "$tmp_dir/git-hotspots-edge-inspect-glob.md"
"$EXE" --repo fixtures/edge --inspect 'weird/tab\tname.txt' --format json > "$tmp_dir/git-hotspots-edge-inspect-tab.json"
assert_fails_with_stderr inspect-limit "--limit cannot be combined with --inspect" "$EXE" --repo fixtures/basic --inspect src/app.txt --limit 1
assert_fails_with_stderr inspect-missing "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/basic --inspect src/missing.txt
assert_fails_with_stderr inspect-outside-include "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --include-prefix src/ --inspect vendor/lib.txt
assert_fails_with_stderr inspect-excluded "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --exclude-prefix src/ --inspect src/new.zig
assert_fails_with_stderr inspect-empty "--inspect must be" "$EXE" --repo fixtures/basic --inspect ""
assert_fails_with_stderr inspect-absolute "--inspect must be" "$EXE" --repo fixtures/basic --inspect /tmp/file
assert_fails_with_stderr inspect-drive "--inspect must be" "$EXE" --repo fixtures/basic --inspect C:/tmp/file
assert_fails_with_stderr inspect-backslash "--inspect must be" "$EXE" --repo fixtures/basic --inspect '\tmp\file'
assert_fails_with_stderr inspect-parent "--inspect must be" "$EXE" --repo fixtures/basic --inspect src/../app.txt
assert_fails_with_stderr inspect-control "--inspect must be" "$EXE" --repo fixtures/basic --inspect "$ctrl"

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
assert_fails_with_stderr progress-invalid-since "--since must name" "$EXE" --repo fixtures/basic --progress --since does-not-exist
assert_fails_with_stderr invalid-format "--format accepts one value" "$EXE" --repo fixtures/basic --format xml
assert_fails_with_stderr invalid-scope-missing "--scope accepts" "$EXE" --repo fixtures/basic --scope
assert_fails_with_stderr invalid-scope-unknown "--scope accepts" "$EXE" --repo fixtures/basic --scope unknown
assert_fails_with_stderr invalid-scope-case-title "--scope accepts" "$EXE" --repo fixtures/basic --scope Project
assert_fails_with_stderr invalid-scope-case-upper "--scope accepts" "$EXE" --repo fixtures/basic --scope PROJECT
assert_fails_with_stderr invalid-scope-repeated "--scope accepts" "$EXE" --repo fixtures/basic --scope all --scope project
assert_fails_with_stderr invalid-exclude-empty --exclude-prefix "$EXE" --repo fixtures/basic --exclude-prefix ""
assert_fails_with_stderr invalid-exclude-absolute --exclude-prefix "$EXE" --repo fixtures/basic --exclude-prefix /tmp
assert_fails_with_stderr invalid-exclude-parent --exclude-prefix "$EXE" --repo fixtures/basic --exclude-prefix src/../lib
assert_fails_with_stderr invalid-exclude-control --exclude-prefix "$EXE" --repo fixtures/basic --exclude-prefix "$ctrl"
assert_fails_with_stderr invalid-include-empty --include-prefix "$EXE" --repo fixtures/basic --include-prefix ""
assert_fails_with_stderr invalid-include-absolute --include-prefix "$EXE" --repo fixtures/basic --include-prefix /tmp
assert_fails_with_stderr invalid-include-drive --include-prefix "$EXE" --repo fixtures/basic --include-prefix C:/tmp
assert_fails_with_stderr invalid-include-backslash --include-prefix "$EXE" --repo fixtures/basic --include-prefix '\tmp'
assert_fails_with_stderr invalid-include-parent --include-prefix "$EXE" --repo fixtures/basic --include-prefix src/../lib
assert_fails_with_stderr invalid-include-control --include-prefix "$EXE" --repo fixtures/basic --include-prefix "$ctrl"

"$EXE" --repo fixtures/edge --limit 200 --format json > "$tmp_dir/git-hotspots-edge.json"
"$EXE" --repo fixtures/edge --limit 200 --format markdown > "$tmp_dir/git-hotspots-edge.md"
"$EXE" --repo fixtures/medium --format json > "$tmp_dir/git-hotspots-medium.json"
"$EXE" --repo fixtures/shallow --format json > "$tmp_dir/git-hotspots-shallow.json"
"$EXE" --repo fixtures/partial --format json > "$tmp_dir/git-hotspots-partial.json"
"$EXE" --repo fixtures/detached --format json > "$tmp_dir/git-hotspots-detached.json"
"$EXE" --repo fixtures/linked --format json > "$tmp_dir/git-hotspots-linked.json"

python3 - "$tmp_dir/git-hotspots-basic.md" "$tmp_dir/git-hotspots-scope-filtered.md" "$tmp_dir/git-hotspots-scope-project.md" "$tmp_dir/git-hotspots-scope-empty.md" "$tmp_dir/git-hotspots-edge.md" "$tmp_dir/git-hotspots-scope-src-include.md" "$tmp_dir/git-hotspots-scope-include-empty.md" "$tmp_dir/git-hotspots-basic-inspect.md" "$tmp_dir/git-hotspots-edge-inspect-glob.md" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

def tmp(name):
    return os.path.join(os.environ['TMP_DIR'], name)

basic_md_path, scope_md_path, project_md_path, scope_empty_md_path, edge_md_path, include_md_path, include_empty_md_path, basic_inspect_md_path, edge_inspect_md_path = map(Path, sys.argv[1:])

def load(path):
    return json.loads(Path(path).read_text())

def by_path(data):
    return {row['path']: row for row in data['results']}

project_prefixes = ['.flow/', '.zig-cache/', 'zig-out/', 'target/', 'node_modules/', 'dist/', 'build/', 'coverage/']
def starts_project_prefix(path):
    return any(path.startswith(prefix) for prefix in project_prefixes)

basic = load(tmp('git-hotspots-basic.json'))
assert basic['analysis']['scope']['selected_scope'] == 'project'
assert basic['analysis']['scope']['filters_active'] is True
assert basic['analysis']['scope']['include_prefixes'] == []
assert basic['analysis']['scope']['exclude_prefixes'] == project_prefixes
assert basic['results'][0]['path'] == 'src/app.txt'
assert all(not row['path'].startswith('/') for row in basic['results'])
basic_inspect = load(tmp('git-hotspots-basic-inspect.json'))
assert basic_inspect['inspect'] == {'requested_path': 'src/app.txt', 'matched_path': 'src/app.txt', 'rank': 1}
assert len(basic_inspect['results']) == 1
assert basic_inspect['results'][0] == basic['results'][0]
assert 'inspect' not in basic

scope_unfiltered = load(tmp('git-hotspots-scope-unfiltered.json'))
scope_all = load(tmp('git-hotspots-scope-all.json'))
assert scope_unfiltered['analysis']['scope']['selected_scope'] == 'project', 'default selected scope changed'
assert scope_unfiltered['analysis']['scope']['exclude_prefixes'] == project_prefixes, 'default project prefix missing'
assert all(not starts_project_prefix(row['path']) for row in scope_unfiltered['results']), 'default leaked project-prefix path'
all_paths = [row['path'] for row in scope_all['results']]
assert any(path.startswith('.flow/') for path in all_paths), '--scope all lost .flow paths'
assert any(path.startswith('node_modules/') for path in all_paths), '--scope all lost generated/dependency path evidence'
assert 'src/new.zig' in all_paths, 'braced rename fixture missing new path'
assert any(path == 'weird/tab\tname.txt' for path in all_paths), 'quoted tab fixture missing unquoted path'
assert '' not in all_paths, 'empty path leaked from braced rename parsing'

scope_filtered = load(tmp('git-hotspots-scope-filtered.json'))
scope_meta = scope_filtered['analysis']['scope']
assert scope_meta == {
    'selected_scope': 'all',
    'filters_active': True,
    'include_prefixes': [],
    'exclude_prefixes': project_prefixes,
    'outside_include_path_count': 0,
    'outside_include_change_count': 0,
    'excluded_path_count': 13,
    'excluded_change_count': 28,
}, scope_meta
for row in scope_filtered['results']:
    assert not starts_project_prefix(row['path']), row['path']
    assert all(not starts_project_prefix(cc['path']) for cc in row['cochanges']), row['path']
assert 'src/vendor_adapter.zig' in by_path(scope_filtered), 'vendor/ prefix semantics fixture missing adapter'
assert 'src/buildtool.zig' in by_path(scope_filtered), 'near-miss buildtool path was excluded'
assert 'src/vendoradapter.zig' in by_path(scope_filtered), 'near-miss vendoradapter path was excluded'
assert 'docs/coverage.md' in by_path(scope_filtered), 'near-miss docs coverage path was excluded'

scope_project = load(tmp('git-hotspots-scope-project.json'))
project_meta = scope_project['analysis']['scope']
assert project_meta == {
    'selected_scope': 'project',
    'filters_active': True,
    'include_prefixes': [],
    'exclude_prefixes': project_prefixes,
    'outside_include_path_count': 0,
    'outside_include_change_count': 0,
    'excluded_path_count': 13,
    'excluded_change_count': 28,
}, project_meta
assert scope_project['results'] == scope_filtered['results'], 'project preset rows differ from explicit project-prefix exclusions'
assert scope_project == scope_unfiltered, 'omitted scope differs from explicit project'
for row in scope_project['results']:
    assert not starts_project_prefix(row['path']), row['path']
    assert all(not starts_project_prefix(cc['path']) for cc in row['cochanges']), row['path']
scope_project_duplicate = load(tmp('git-hotspots-scope-project-duplicate-flow.json'))
assert scope_project_duplicate['analysis']['scope']['exclude_prefixes'] == project_prefixes
assert scope_project_duplicate['results'] == scope_project['results'], 'duplicate project exclude changed rows'
scope_project_include_flow = load(tmp('git-hotspots-scope-project-include-flow.json'))
assert scope_project_include_flow['analysis']['scope']['selected_scope'] == 'project'
assert scope_project_include_flow['analysis']['scope']['include_prefixes'] == ['.flow/']
assert scope_project_include_flow['analysis']['scope']['exclude_prefixes'] == project_prefixes
assert scope_project_include_flow['results'] == [], 'exclude did not win over include for project .flow/'
scope_project_include_node = load(tmp('git-hotspots-scope-project-include-node-modules.json'))
assert scope_project_include_node['analysis']['scope']['include_prefixes'] == ['node_modules/']
assert scope_project_include_node['analysis']['scope']['exclude_prefixes'] == project_prefixes
assert scope_project_include_node['results'] == [], 'project built-in exclude did not win over node_modules include'
scope_all_include_node = load(tmp('git-hotspots-scope-all-include-node-modules.json'))
assert scope_all_include_node['analysis']['scope']['selected_scope'] == 'all'
assert scope_all_include_node['analysis']['scope']['include_prefixes'] == ['node_modules/']
assert scope_all_include_node['analysis']['scope']['exclude_prefixes'] == []
assert [row['path'] for row in scope_all_include_node['results']] == ['node_modules/pkg/index.js', 'node_modules/pkg/chain-mid.txt']
scope_project_include_src = load(tmp('git-hotspots-scope-project-include-src.json'))
assert scope_project_include_src['analysis']['scope']['selected_scope'] == 'project'
assert scope_project_include_src['analysis']['scope']['include_prefixes'] == ['src/']
assert scope_project_include_src['analysis']['scope']['exclude_prefixes'] == project_prefixes
for row in scope_project_include_src['results']:
    assert row['path'].startswith('src/'), row['path']
    assert all(cc['path'].startswith('src/') for cc in row['cochanges']), row['path']
scope_project_inspect = load(tmp('git-hotspots-scope-project-inspect.json'))
assert scope_project_inspect['results'][0] == by_path(scope_project)['src/vendor_adapter.zig']
assert scope_project_inspect['inspect']['matched_path'] == 'src/vendor_adapter.zig'
scope_all_inspect_flow = load(tmp('git-hotspots-scope-all-inspect-flow.json'))
assert scope_all_inspect_flow['analysis']['scope']['selected_scope'] == 'all'
assert len(scope_all_inspect_flow['results']) == 1
assert scope_all_inspect_flow['results'][0]['path'] == '.flow/state.yaml'
scope_all_included_to_excluded = load(tmp('git-hotspots-scope-all-inspect-included-to-excluded.json'))
assert scope_all_included_to_excluded['results'][0]['path'] == '.zig-cache/from-src.txt'
assert scope_all_included_to_excluded['results'][0]['lineage']['aliases'] == ['src/to-cache.txt']
assert scope_all_included_to_excluded['results'][0]['lineage']['partial'] is False
scope_all_excluded_to_excluded = load(tmp('git-hotspots-scope-all-inspect-excluded-to-excluded.json'))
assert scope_all_excluded_to_excluded['results'][0]['path'] == 'build/excluded-chain-b.txt'
assert scope_all_excluded_to_excluded['results'][0]['lineage']['aliases'] == ['target/excluded-chain-a.txt']
assert scope_all_excluded_to_excluded['results'][0]['lineage']['partial'] is False
scope_all_chained_cross = load(tmp('git-hotspots-scope-all-inspect-chained-cross-prefix.json'))
assert scope_all_chained_cross['results'][0]['path'] == 'src/chain-final.txt'
assert scope_all_chained_cross['results'][0]['lineage']['aliases'] == ['node_modules/pkg/chain-mid.txt', 'src/chain-start.txt']
assert scope_all_chained_cross['results'][0]['lineage']['partial'] is False
scope_project_included_to_excluded = load(tmp('git-hotspots-scope-project-inspect-included-to-excluded-old.json'))
assert scope_project_included_to_excluded['results'][0]['path'] == 'src/to-cache.txt'
assert scope_project_included_to_excluded['results'][0]['lineage']['aliases'] == []
assert scope_project_included_to_excluded['results'][0]['lineage']['partial'] is False
assert all(not starts_project_prefix(cc['path']) for cc in scope_project_included_to_excluded['results'][0]['cochanges'])
scope_project_chained_cross = load(tmp('git-hotspots-scope-project-inspect-chained-cross-prefix.json'))
assert scope_project_chained_cross['results'][0]['path'] == 'src/chain-final.txt'
assert scope_project_chained_cross['results'][0]['lineage']['aliases'] == []
assert scope_project_chained_cross['results'][0]['lineage']['partial'] is True
assert all(not starts_project_prefix(cc['path']) for cc in scope_project_chained_cross['results'][0]['cochanges'])
for row in scope_project['results'] + scope_project_included_to_excluded['results'] + scope_project_chained_cross['results']:
    assert not starts_project_prefix(row['path']), row['path']
    assert all(not starts_project_prefix(alias) for alias in row['lineage']['aliases']), row['path']
    assert all(not starts_project_prefix(cc['path']) for cc in row['cochanges']), row['path']
scope_inspect_excluded_flow = load(tmp('git-hotspots-scope-inspect-excluded-flow.json'))
assert len(scope_inspect_excluded_flow['results']) == 1
assert scope_inspect_excluded_flow['results'][0] == by_path(scope_filtered)['src/vendor_adapter.zig']
assert scope_inspect_excluded_flow['inspect']['matched_path'] == 'src/vendor_adapter.zig'

vendor_filtered = load(tmp('git-hotspots-scope-vendor-filtered.json'))
vendor_rows = by_path(vendor_filtered)
assert 'src/vendor_adapter.zig' in vendor_rows
assert 'vendor/lib.txt' not in vendor_rows

src_filtered = load(tmp('git-hotspots-scope-src-filtered.json'))
for row in src_filtered['results']:
    assert row['path'], 'empty path leaked from excluded braced rename'
    assert not row['path'].startswith('src/'), row['path']
    assert all(not cc['path'].startswith('src/') for cc in row['cochanges']), row['path']

weird_filtered = load(tmp('git-hotspots-scope-weird-filtered.json'))
for row in weird_filtered['results']:
    assert not row['path'].startswith('weird/'), row['path']
    assert not row['path'].startswith('"weird/'), row['path']
    assert all(not cc['path'].startswith('weird/') for cc in row['cochanges']), row['path']

glob_prefix = load(tmp('git-hotspots-scope-glob-prefix.json'))
assert 'glob/[literal]*.txt' in by_path(glob_prefix), 'glob-like prefix acted as a glob'

src_include = load(tmp('git-hotspots-scope-src-include.json'))
src_include_scope = src_include['analysis']['scope']
assert src_include_scope['selected_scope'] == 'project'
assert src_include_scope['filters_active'] is True
assert src_include_scope['include_prefixes'] == ['src/']
assert src_include_scope['exclude_prefixes'] == project_prefixes
assert src_include_scope['outside_include_path_count'] >= 1
assert src_include_scope['outside_include_change_count'] >= 1
for row in src_include['results']:
    assert row['path'].startswith('src/'), row['path']
    assert all(cc['path'].startswith('src/') for cc in row['cochanges']), row['path']
assert 'src/new.zig' in by_path(src_include), 'include scope lost normalized rename target'
assert 'src/vendor_adapter.zig' in by_path(src_include), 'literal include prefix lost adapter path'
scope_inspect_renamed = load(tmp('git-hotspots-scope-inspect-include-renamed.json'))
assert len(scope_inspect_renamed['results']) == 1
assert scope_inspect_renamed['results'][0] == by_path(src_include)['src/new.zig']
assert scope_inspect_renamed['inspect']['matched_path'] == 'src/new.zig'

src_vendor_include = load(tmp('git-hotspots-scope-src-vendor-include.json'))
assert src_vendor_include['analysis']['scope']['include_prefixes'] == ['src/', 'vendor/']
for row in src_vendor_include['results']:
    assert row['path'].startswith(('src/', 'vendor/')), row['path']
    assert all(cc['path'].startswith(('src/', 'vendor/')) for cc in row['cochanges']), row['path']

include_exclude = load(tmp('git-hotspots-scope-include-exclude.json'))
assert include_exclude['analysis']['scope']['include_prefixes'] == ['src/']
assert include_exclude['analysis']['scope']['exclude_prefixes'] == project_prefixes + ['src/vendor_adapter.zig']
assert include_exclude['analysis']['scope']['excluded_path_count'] == 14
assert 'src/vendor_adapter.zig' not in by_path(include_exclude), 'exclude did not win over include'
for row in include_exclude['results']:
    assert all(cc['path'] != 'src/vendor_adapter.zig' for cc in row['cochanges']), row['path']

weird_include = load(tmp('git-hotspots-scope-weird-include.json'))
assert [row['path'] for row in weird_include['results']] == ['weird/tab\tname.txt']

glob_star_include = load(tmp('git-hotspots-scope-glob-star-include.json'))
assert 'glob/[literal]*.txt' not in by_path(glob_star_include), 'include glob-like prefix acted as a glob'
glob_include = load(tmp('git-hotspots-scope-glob-include.json'))
assert 'glob/[literal]*.txt' in by_path(glob_include), 'literal glob/ include did not match path'

include_empty = load(tmp('git-hotspots-scope-include-empty.json'))
assert include_empty['results'] == []
assert include_empty['analysis']['scope']['filters_active'] is True
assert include_empty['analysis']['scope']['include_prefixes'] == ['does-not-exist/']
assert include_empty['analysis']['scope']['outside_include_path_count'] >= 1

scope_empty = load(tmp('git-hotspots-scope-empty.json'))
assert scope_empty['results'] == []
assert scope_empty['analysis']['scope']['filters_active'] is True
assert scope_empty['analysis']['scope']['excluded_path_count'] >= 1

table_text = Path(tmp('git-hotspots-scope-filtered.txt')).read_text()
assert 'scope: selected=all include_prefixes=[] exclude_prefixes=[.flow/,.zig-cache/,zig-out/,target/,node_modules/,dist/,build/,coverage/]' in table_text
assert '.flow/' not in '\n'.join(line for line in table_text.splitlines() if line[:1].isdigit())
project_table_text = Path(tmp('git-hotspots-scope-project.txt')).read_text()
assert 'scope: selected=project include_prefixes=[] exclude_prefixes=[.flow/,.zig-cache/,zig-out/,target/,node_modules/,dist/,build/,coverage/]' in project_table_text
assert '.flow/' not in '\n'.join(line for line in project_table_text.splitlines() if line[:1].isdigit())
include_table_text = Path(tmp('git-hotspots-scope-src-include.txt')).read_text()
assert 'scope: selected=project include_prefixes=[src/] exclude_prefixes=[.flow/,.zig-cache/,zig-out/,target/,node_modules/,dist/,build/,coverage/]' in include_table_text
for line in include_table_text.splitlines():
    if line[:1].isdigit():
        assert 'src/' in line, line
        assert '.flow/' not in line and 'vendor/' not in line and 'glob/' not in line and 'weird/' not in line, line

edge = load(tmp('git-hotspots-edge.json'))
rows = by_path(edge)
for path in ['weird/path with space.txt', 'weird/éclair.txt', 'renamed.txt']:
    assert path in rows, path
assert any('tab' in path for path in rows), 'tab path missing'
edge_inspect_tab = load(tmp('git-hotspots-edge-inspect-tab.json'))
assert edge_inspect_tab['inspect']['requested_path'] == 'weird/tab\tname.txt'
assert edge_inspect_tab['inspect']['matched_path'] == 'weird/tab\tname.txt'
assert edge_inspect_tab['results'][0] == rows['weird/tab\tname.txt']
assert 'glob/[literal]*.txt' in rows, 'glob-looking literal path missing'
assert rows['gone.txt']['current_size'] is None
assert any('deleted' in c for c in rows['gone.txt']['caveats'])
assert any('binary' in c for c in rows['bin/blob.bin']['caveats'])
assert any(any('large commit' in c for c in row['caveats']) for row in edge['results'])
paths = [row['path'] for row in edge['results']]
assert paths.index('tie/a.txt') < paths.index('tie/b.txt')
assert edge['analysis']['history']['commit_count'] >= 5

medium = load(tmp('git-hotspots-medium.json'))
assert medium['analysis']['history']['dirty_worktree'] is True
assert any('dirty worktree' in c for c in medium['analysis']['caveats'])

shallow = load(tmp('git-hotspots-shallow.json'))
assert shallow['analysis']['history']['is_shallow'] is True
assert shallow['analysis']['history']['auto_fetch'] is False

partial = load(tmp('git-hotspots-partial.json'))
assert partial['analysis']['history']['is_partial'] is True
assert partial['analysis']['history']['auto_fetch'] is False

for label, path in [('detached',tmp('git-hotspots-detached.json')), ('linked',tmp('git-hotspots-linked.json'))]:
    data = load(path)
    assert data['results'], label

basic_md = basic_md_path.read_text()
assert '# git-hotspots report' in basic_md
assert 'File-level Git-history investigation prompts, not bug predictions or code-quality ratings.' in basic_md
for section in ['## Run summary', '## Scope', '## Caveats', '## Top hotspots', '## Evidence']:
    assert section in basic_md, section
assert '- Selected scope: project' in basic_md
basic_inspect_md = basic_inspect_md_path.read_text()
assert '## Inspect' in basic_inspect_md
assert '- Requested path: src/app.txt' in basic_inspect_md
assert '- Matched path: src/app.txt' in basic_inspect_md
assert '- Rank in scoped evidence universe: 1' in basic_inspect_md

scope_md = scope_md_path.read_text()
assert '- Selected scope: all' in scope_md
assert '- Filters active: true' in scope_md
assert '- Include prefixes: None' in scope_md
assert r'- Exclude prefixes: .flow/, .zig\-cache/, zig\-out/, target/, node\_modules/, dist/, build/, coverage/' in scope_md
assert '- Outside include path count: 0' in scope_md
assert '- Outside include change count: 0' in scope_md
assert '- Excluded path count: 13' in scope_md
assert '- Excluded change count: 28' in scope_md
for line in scope_md.splitlines():
    if line.startswith('| ') or line.startswith('### ') or line.startswith('  - '):
        assert not any(prefix in line for prefix in project_prefixes), line

project_md = project_md_path.read_text()
assert '- Selected scope: project' in project_md
assert r'- Exclude prefixes: .flow/, .zig\-cache/, zig\-out/, target/, node\_modules/, dist/, build/, coverage/' in project_md
for line in project_md.splitlines():
    if line.startswith('| ') or line.startswith('### ') or line.startswith('  - '):
        assert not any(prefix in line for prefix in project_prefixes), line

scope_empty_md = scope_empty_md_path.read_text()
assert 'No hotspots matched the requested scope.' in scope_empty_md
assert 'No result evidence to show.' in scope_empty_md
for section in ['## Run summary', '## Scope', '## Caveats', '## Top hotspots', '## Evidence']:
    assert section in scope_empty_md, section

include_md = include_md_path.read_text()
assert '- Include prefixes: src/' in include_md
assert r'- Exclude prefixes: .flow/, .zig\-cache/, zig\-out/, target/, node\_modules/, dist/, build/, coverage/' in include_md
assert '- Outside include path count:' in include_md
for line in include_md.splitlines():
    if line.startswith('| ') or line.startswith('### ') or line.startswith('  - '):
        assert not any(prefix in line for prefix in project_prefixes) and 'vendor/' not in line and 'glob/' not in line and 'weird/' not in line, line

include_empty_md = include_empty_md_path.read_text()
assert '- Include prefixes: does\\-not\\-exist/' in include_empty_md
assert 'No hotspots matched the requested scope.' in include_empty_md
assert 'No result evidence to show.' in include_empty_md

edge_md = edge_md_path.read_text()
assert 'weird/tab\\tname.txt' in edge_md
assert 'glob/\\[literal\\]\\*.txt' in edge_md
assert 'path is deleted or not present at HEAD' in edge_md
assert 'binary or non\\-text churn unavailable for some changes' in edge_md
edge_inspect_md = edge_inspect_md_path.read_text()
assert 'glob/\\[literal\\]\\*.txt' in edge_inspect_md
assert '## Inspect' in edge_inspect_md
for text in [basic_md, scope_md, project_md, scope_empty_md, edge_md, include_md, include_empty_md, basic_inspect_md, edge_inspect_md]:
    assert '\t' not in text, 'raw tab leaked in markdown'
    assert 'Fixture Author' not in text
    assert 'fixture@example.invalid' not in text
    home = os.path.expanduser('~')
    assert not home or home not in text
    assert not re.search(r'https?://|ssh://|git@', text)
    assert not re.search(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', text)
PY
