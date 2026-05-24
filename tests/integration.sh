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

"$EXE" --explain > /tmp/git-hotspots-explain.txt
diff -u fixtures/expected/explain.txt /tmp/git-hotspots-explain.txt
"$EXE" --explain > /tmp/git-hotspots-explain-2.txt
diff -u /tmp/git-hotspots-explain.txt /tmp/git-hotspots-explain-2.txt
"$EXE" --help > /tmp/git-hotspots-help.txt
grep -q -- "--explain" /tmp/git-hotspots-help.txt
grep -q -- "--version" /tmp/git-hotspots-help.txt
grep -q -- "--inspect PATH" /tmp/git-hotspots-help.txt
grep -q -- "--scope VALUE" /tmp/git-hotspots-help.txt
grep -q -- "project (default) or all" /tmp/git-hotspots-help.txt
grep -q -- "--progress" /tmp/git-hotspots-help.txt
grep -q -- "--symbols" /tmp/git-hotspots-help.txt
grep -q -- "--symbol-line-history" /tmp/git-hotspots-help.txt
grep -q -- "--symbol-limit N" /tmp/git-hotspots-help.txt
"$EXE" --progress --help > /tmp/git-hotspots-progress-help.txt 2> /tmp/git-hotspots-progress-help.err
grep -q -- "--progress" /tmp/git-hotspots-progress-help.txt
test ! -s /tmp/git-hotspots-progress-help.err
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
assert_fails_with_stderr symbols-alone "--symbols can only be combined with --inspect PATH" "$EXE" --symbols
assert_fails_with_stderr symbols-explain "--explain cannot be combined" "$EXE" --symbols --explain
assert_fails_with_stderr symbols-version "--version cannot be combined" "$EXE" --symbols --version
assert_fails_with_stderr symbol-line-history-explain "--explain cannot be combined" "$EXE" --symbol-line-history --explain
assert_fails_with_stderr symbol-line-history-version "--version cannot be combined" "$EXE" --symbol-line-history --version
assert_fails_with_stderr symbol-limit-alone "--symbol-limit can only be combined" "$EXE" --symbol-limit 1
assert_fails_with_stderr symbol-limit-no-symbols "--symbol-limit can only be combined" "$EXE" --inspect src/app.zig --symbol-limit 1
assert_fails_with_stderr symbol-limit-zero "--symbol-limit must be a positive integer" "$EXE" --inspect src/app.zig --symbols --symbol-limit 0
assert_fails_with_stderr symbol-limit-invalid "--symbol-limit must be a positive integer" "$EXE" --inspect src/app.zig --symbols --symbol-limit nope

"$EXE" --repo fixtures/basic --format json > /tmp/git-hotspots-basic.json 2> /tmp/git-hotspots-basic.err
test ! -s /tmp/git-hotspots-basic.err
diff -u fixtures/expected/basic.json /tmp/git-hotspots-basic.json
"$EXE" --repo fixtures/basic --progress --format json > /tmp/git-hotspots-basic-progress.json 2> /tmp/git-hotspots-basic-progress.err
diff -u /tmp/git-hotspots-basic.json /tmp/git-hotspots-basic-progress.json
assert_progress_stderr basic-json /tmp/git-hotspots-basic-progress.err
"$EXE" --repo fixtures/basic --format json > /tmp/git-hotspots-basic-2.json
diff -u /tmp/git-hotspots-basic.json /tmp/git-hotspots-basic-2.json
"$EXE" --repo fixtures/basic --format markdown > /tmp/git-hotspots-basic.md
diff -u fixtures/expected/basic.md /tmp/git-hotspots-basic.md
"$EXE" --repo fixtures/basic --progress --format markdown > /tmp/git-hotspots-basic-progress.md 2> /tmp/git-hotspots-basic-progress-md.err
diff -u /tmp/git-hotspots-basic.md /tmp/git-hotspots-basic-progress.md
assert_progress_stderr basic-markdown /tmp/git-hotspots-basic-progress-md.err
"$EXE" --repo fixtures/basic --format markdown > /tmp/git-hotspots-basic-2.md
diff -u /tmp/git-hotspots-basic.md /tmp/git-hotspots-basic-2.md
"$EXE" --repo fixtures/basic --format table > /tmp/git-hotspots-basic.txt
"$EXE" --repo fixtures/basic --progress --format table > /tmp/git-hotspots-basic-progress.txt 2> /tmp/git-hotspots-basic-progress-table.err
diff -u /tmp/git-hotspots-basic.txt /tmp/git-hotspots-basic-progress.txt
assert_progress_stderr basic-table /tmp/git-hotspots-basic-progress-table.err
"$EXE" --repo fixtures/basic --inspect src/app.txt --format json > /tmp/git-hotspots-basic-inspect.json
diff -u fixtures/expected/basic-inspect.json /tmp/git-hotspots-basic-inspect.json
"$EXE" --repo fixtures/basic --progress --inspect src/app.txt --format json > /tmp/git-hotspots-basic-inspect-progress.json 2> /tmp/git-hotspots-basic-inspect-progress.err
diff -u /tmp/git-hotspots-basic-inspect.json /tmp/git-hotspots-basic-inspect-progress.json
assert_progress_stderr basic-inspect /tmp/git-hotspots-basic-inspect-progress.err
"$EXE" --repo fixtures/basic --inspect src/app.txt --format json > /tmp/git-hotspots-basic-inspect-2.json
diff -u /tmp/git-hotspots-basic-inspect.json /tmp/git-hotspots-basic-inspect-2.json
"$EXE" --repo fixtures/basic --inspect src/app.txt --format markdown > /tmp/git-hotspots-basic-inspect.md
diff -u fixtures/expected/basic-inspect.md /tmp/git-hotspots-basic-inspect.md
"$EXE" --repo fixtures/basic --inspect src/app.txt --format table > /tmp/git-hotspots-basic-inspect.txt
diff -u fixtures/expected/basic-inspect.txt /tmp/git-hotspots-basic-inspect.txt
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --format json > /tmp/git-hotspots-symbols-inspect-symbols.json
diff -u fixtures/expected/symbols-inspect-symbols.json /tmp/git-hotspots-symbols-inspect-symbols.json
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --format markdown > /tmp/git-hotspots-symbols-inspect-symbols.md
diff -u fixtures/expected/symbols-inspect-symbols.md /tmp/git-hotspots-symbols-inspect-symbols.md
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --format table > /tmp/git-hotspots-symbols-inspect-symbols.txt
diff -u fixtures/expected/symbols-inspect-symbols.txt /tmp/git-hotspots-symbols-inspect-symbols.txt
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format json > /tmp/git-hotspots-symbols-limit-json.json
python3 - /tmp/git-hotspots-symbols-limit-json.json <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
assert len(data['symbols']['items']) == 2
assert data['symbols']['human_display']['shown_count'] == 1
assert data['symbols']['human_display']['omitted_count'] == 1
assert data['symbols']['human_display']['active_limit'] == 1
assert data['symbols']['human_display']['limit_source'] == 'explicit'
PY
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format markdown > /tmp/git-hotspots-symbols-limit.md
diff -u fixtures/expected/symbols-limit.md /tmp/git-hotspots-symbols-limit.md
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format markdown > /tmp/git-hotspots-symbols-limit-2.md
diff -u /tmp/git-hotspots-symbols-limit.md /tmp/git-hotspots-symbols-limit-2.md
grep -Fq -- '- Total symbols: 2' /tmp/git-hotspots-symbols-limit.md
grep -Fq -- '- Shown symbols: 1' /tmp/git-hotspots-symbols-limit.md
grep -Fq -- '- Omitted symbols: 1' /tmp/git-hotspots-symbols-limit.md
! grep -Fq -- 'zebra' /tmp/git-hotspots-symbols-limit.md
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format table > /tmp/git-hotspots-symbols-limit.txt
diff -u fixtures/expected/symbols-limit.txt /tmp/git-hotspots-symbols-limit.txt
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-limit 1 --format table > /tmp/git-hotspots-symbols-limit-2.txt
diff -u /tmp/git-hotspots-symbols-limit.txt /tmp/git-hotspots-symbols-limit-2.txt
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-line-history --format json > /tmp/git-hotspots-symbols-line-history.json
python3 -m json.tool /tmp/git-hotspots-symbols-line-history.json >/dev/null
grep -Fq -- '"current_line_history"' /tmp/git-hotspots-symbols-line-history.json
grep -Fq -- '"basis": "current-line-range-at-head"' /tmp/git-hotspots-symbols-line-history.json
grep -Fq -- '"distinct_last_touch_commit_count": 1' /tmp/git-hotspots-symbols-line-history.json
! grep -Eiq -- 'Fixture Author|fixture@example|expand zig function|initial symbol files|file://' /tmp/git-hotspots-symbols-line-history.json
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-line-history --format markdown > /tmp/git-hotspots-symbols-line-history.md
grep -Fq -- 'Current-line Git evidence' /tmp/git-hotspots-symbols-line-history.md
"$EXE" --repo fixtures/symbols --inspect src/example.zig --symbols --symbol-line-history --format table > /tmp/git-hotspots-symbols-line-history.txt
grep -Fq -- 'Current-line Git evidence: commits=1' /tmp/git-hotspots-symbols-line-history.txt
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format json > /tmp/git-hotspots-line-history-success.json
diff -u fixtures/expected/line-history-success.json /tmp/git-hotspots-line-history-success.json
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format json > /tmp/git-hotspots-line-history-success-2.json
diff -u /tmp/git-hotspots-line-history-success.json /tmp/git-hotspots-line-history-success-2.json
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format markdown > /tmp/git-hotspots-line-history-success.md
diff -u fixtures/expected/line-history-success.md /tmp/git-hotspots-line-history-success.md
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format table > /tmp/git-hotspots-line-history-success.txt
diff -u fixtures/expected/line-history-success.txt /tmp/git-hotspots-line-history-success.txt
"$EXE" --repo fixtures/symbol-line-history-shallow --inspect src/current.zig --symbols --symbol-line-history --format json > /tmp/git-hotspots-line-history-shallow.json
grep -Fq -- 'current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false' /tmp/git-hotspots-line-history-shallow.json
"$EXE" --repo fixtures/symbol-line-history-partial --inspect src/current.zig --symbols --symbol-line-history --format json > /tmp/git-hotspots-line-history-partial.json
grep -Fq -- 'current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false' /tmp/git-hotspots-line-history-partial.json
"$EXE" --repo fixtures/symbol-line-history --inspect src/readme.txt --symbols --symbol-line-history --format json > /tmp/git-hotspots-line-history-unsupported.json
grep -Fq -- '"failure": "unsupported"' /tmp/git-hotspots-line-history-unsupported.json
! grep -Fq -- '"current_line_history"' /tmp/git-hotspots-line-history-unsupported.json
"$EXE" --repo fixtures/symbol-line-history --inspect src/empty.zig --symbols --symbol-line-history --format json > /tmp/git-hotspots-line-history-empty.json
grep -Fq -- '"items": [' /tmp/git-hotspots-line-history-empty.json
! grep -Fq -- '"current_line_history"' /tmp/git-hotspots-line-history-empty.json
"$EXE" --repo fixtures/symbol-line-history --inspect src/broken.zig --symbols --symbol-line-history --format json > /tmp/git-hotspots-line-history-broken.json
grep -Eq -- '"failure": "(failed|ok)"' /tmp/git-hotspots-line-history-broken.json
"$EXE" --repo fixtures/symbol-line-history --inspect src/link.zig --symbols --symbol-line-history --format json > /tmp/git-hotspots-line-history-link.json
grep -Fq -- '"failure": "unavailable"' /tmp/git-hotspots-line-history-link.json
printf 'dirty inspected\n' >> fixtures/symbol-line-history/src/current.zig
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format json > /tmp/git-hotspots-line-history-dirty-inspected.json
grep -Fq -- 'current-line Git evidence skipped: inspected file has staged or unstaged content changes' /tmp/git-hotspots-line-history-dirty-inspected.json
git -C fixtures/symbol-line-history checkout -q -- src/current.zig
printf 'dirty unrelated\n' >> fixtures/symbol-line-history/src/readme.txt
"$EXE" --repo fixtures/symbol-line-history --inspect src/current.zig --symbols --symbol-line-history --format json > /tmp/git-hotspots-line-history-dirty-unrelated.json
grep -Fq -- '"failure": "ok"' /tmp/git-hotspots-line-history-dirty-unrelated.json
git -C fixtures/symbol-line-history checkout -q -- src/readme.txt
! grep -Eiq -- 'Fixture Author|fixture@example|fixture function|private|file://|raw blame|source line|previous filename|ownership|productivity|developer ranking' /tmp/git-hotspots-symbols-inspect-symbols.json /tmp/git-hotspots-symbols-inspect-symbols.md /tmp/git-hotspots-symbols-inspect-symbols.txt /tmp/git-hotspots-symbols-limit-json.json /tmp/git-hotspots-symbols-limit.md /tmp/git-hotspots-symbols-limit.txt /tmp/git-hotspots-line-history-success.json /tmp/git-hotspots-line-history-success.md /tmp/git-hotspots-line-history-success.txt /tmp/git-hotspots-line-history-shallow.json /tmp/git-hotspots-line-history-partial.json /tmp/git-hotspots-line-history-unsupported.json /tmp/git-hotspots-line-history-empty.json /tmp/git-hotspots-line-history-broken.json /tmp/git-hotspots-line-history-link.json /tmp/git-hotspots-line-history-dirty-inspected.json /tmp/git-hotspots-line-history-dirty-unrelated.json fixtures/expected/symbols-inspect-symbols.json fixtures/expected/symbols-inspect-symbols.md fixtures/expected/symbols-inspect-symbols.txt fixtures/expected/symbols-limit.md fixtures/expected/symbols-limit.txt fixtures/expected/line-history-success.json fixtures/expected/line-history-success.md fixtures/expected/line-history-success.txt
assert_fails_with_stderr symbol-line-history-alone "--symbol-line-history can only be combined" "$EXE" --symbol-line-history
assert_fails_with_stderr symbol-line-history-no-symbols "--symbol-line-history can only be combined" "$EXE" --repo fixtures/symbols --inspect src/example.zig --symbol-line-history
"$EXE" --repo fixtures/symbols --inspect src/readme.txt --symbols --format json > /tmp/git-hotspots-symbols-unsupported.json
diff -u fixtures/expected/symbols-unsupported.json /tmp/git-hotspots-symbols-unsupported.json
"$EXE" --repo fixtures/symbols --inspect src/link.zig --symbols --format json > /tmp/git-hotspots-symbols-symlink-unavailable.json
diff -u fixtures/expected/symbols-symlink-unavailable.json /tmp/git-hotspots-symbols-symlink-unavailable.json
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format json > /tmp/git-hotspots-go-symbols.json
diff -u fixtures/expected/go-symbols.json /tmp/git-hotspots-go-symbols.json
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format markdown > /tmp/git-hotspots-go-symbols.md
diff -u fixtures/expected/go-symbols.md /tmp/git-hotspots-go-symbols.md
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format table > /tmp/git-hotspots-go-symbols.txt
diff -u fixtures/expected/go-symbols.txt /tmp/git-hotspots-go-symbols.txt
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format json > /tmp/git-hotspots-go-symbols-2.json
diff -u /tmp/git-hotspots-go-symbols.json /tmp/git-hotspots-go-symbols-2.json
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format markdown > /tmp/git-hotspots-go-symbols-2.md
diff -u /tmp/git-hotspots-go-symbols.md /tmp/git-hotspots-go-symbols-2.md
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --format table > /tmp/git-hotspots-go-symbols-2.txt
diff -u /tmp/git-hotspots-go-symbols.txt /tmp/git-hotspots-go-symbols-2.txt
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-limit 2 --format json > /tmp/git-hotspots-go-symbols-limit.json
diff -u fixtures/expected/go-symbols-limit.json /tmp/git-hotspots-go-symbols-limit.json
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-limit 2 --format markdown > /tmp/git-hotspots-go-symbols-limit.md
diff -u fixtures/expected/go-symbols-limit.md /tmp/git-hotspots-go-symbols-limit.md
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-limit 2 --format table > /tmp/git-hotspots-go-symbols-limit.txt
diff -u fixtures/expected/go-symbols-limit.txt /tmp/git-hotspots-go-symbols-limit.txt
"$EXE" --repo fixtures/symbols --inspect src/readme.txt --symbols --format json > /tmp/git-hotspots-go-symbols-unsupported.json
diff -u fixtures/expected/symbols-unsupported.json /tmp/git-hotspots-go-symbols-unsupported.json
"$EXE" --repo fixtures/go-symbols --inspect src/empty.go --symbols --format json > /tmp/git-hotspots-go-symbols-empty.json
diff -u fixtures/expected/go-symbols-empty.json /tmp/git-hotspots-go-symbols-empty.json
"$EXE" --repo fixtures/go-symbols --inspect src/broken.go --symbols --format json > /tmp/git-hotspots-go-symbols-invalid.json
diff -u fixtures/expected/go-symbols-invalid.json /tmp/git-hotspots-go-symbols-invalid.json
"$EXE" --repo fixtures/go-symbols --inspect src/caveated.go --symbols --format json > /tmp/git-hotspots-go-symbols-caveated.json
diff -u fixtures/expected/go-symbols-caveated.json /tmp/git-hotspots-go-symbols-caveated.json
"$EXE" --repo fixtures/go-symbols --inspect src/link.go --symbols --format json > /tmp/git-hotspots-go-symbols-symlink-unavailable.json
diff -u fixtures/expected/go-symbols-symlink-unavailable.json /tmp/git-hotspots-go-symbols-symlink-unavailable.json
"$EXE" --repo fixtures/go-symbols --inspect src/large.go --symbols --format json > /tmp/git-hotspots-go-symbols-large-unavailable.json
diff -u fixtures/expected/go-symbols-large-unavailable.json /tmp/git-hotspots-go-symbols-large-unavailable.json
"$EXE" --repo fixtures/go-symbols --inspect src/missing.go --symbols --format json > /tmp/git-hotspots-go-symbols-missing-unavailable.json
diff -u fixtures/expected/go-symbols-missing-unavailable.json /tmp/git-hotspots-go-symbols-missing-unavailable.json
"$EXE" --repo fixtures/go-symbols --inspect src/old-example.go --symbols --format json > /tmp/git-hotspots-go-symbols-rename-alias.json
diff -u fixtures/expected/go-symbols-rename-alias.json /tmp/git-hotspots-go-symbols-rename-alias.json
"$EXE" --repo fixtures/go-symbols --inspect src/other.go --symbols --format json > /tmp/git-hotspots-go-symbols-other.json
! grep -Fq -- 'Zebra' /tmp/git-hotspots-go-symbols-other.json
"$EXE" --repo fixtures/go-symbols --inspect src/example.go --symbols --symbol-line-history --format json > /tmp/git-hotspots-go-symbols-no-line-history.json
! grep -Fq -- 'current_line_history' /tmp/git-hotspots-go-symbols-no-line-history.json
python3 - /tmp/git-hotspots-go-symbols.json /tmp/git-hotspots-go-symbols-limit.json /tmp/git-hotspots-go-symbols-empty.json /tmp/git-hotspots-go-symbols-invalid.json /tmp/git-hotspots-go-symbols-caveated.json /tmp/git-hotspots-go-symbols-symlink-unavailable.json /tmp/git-hotspots-go-symbols-large-unavailable.json /tmp/git-hotspots-go-symbols-missing-unavailable.json /tmp/git-hotspots-go-symbols-rename-alias.json /tmp/git-hotspots-go-symbols-other.json <<'PY'
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
"$EXE" --repo fixtures/scope --format json > /tmp/git-hotspots-scope-unfiltered.json
"$EXE" --repo fixtures/scope --scope all --limit 200 --format json > /tmp/git-hotspots-scope-all.json
"$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --format json > /tmp/git-hotspots-scope-filtered.json
diff -u fixtures/expected/scope-filtered.json /tmp/git-hotspots-scope-filtered.json
"$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --format markdown > /tmp/git-hotspots-scope-filtered.md
diff -u fixtures/expected/scope-filtered.md /tmp/git-hotspots-scope-filtered.md
"$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --format markdown > /tmp/git-hotspots-scope-filtered-2.md
diff -u /tmp/git-hotspots-scope-filtered.md /tmp/git-hotspots-scope-filtered-2.md
"$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --format table > /tmp/git-hotspots-scope-filtered.txt
"$EXE" --repo fixtures/scope --scope project --format json > /tmp/git-hotspots-scope-project.json
diff -u /tmp/git-hotspots-scope-unfiltered.json /tmp/git-hotspots-scope-project.json
diff -u fixtures/expected/scope-project.json /tmp/git-hotspots-scope-project.json
"$EXE" --repo fixtures/scope --scope project --progress --format json > /tmp/git-hotspots-scope-project-progress.json 2> /tmp/git-hotspots-scope-project-progress.err
diff -u /tmp/git-hotspots-scope-project.json /tmp/git-hotspots-scope-project-progress.json
assert_progress_stderr scope-project /tmp/git-hotspots-scope-project-progress.err
"$EXE" --repo fixtures/scope --scope project --format json > /tmp/git-hotspots-scope-project-2.json
diff -u /tmp/git-hotspots-scope-project.json /tmp/git-hotspots-scope-project-2.json
"$EXE" --repo fixtures/scope --scope project --format markdown > /tmp/git-hotspots-scope-project.md
diff -u fixtures/expected/scope-project.md /tmp/git-hotspots-scope-project.md
"$EXE" --repo fixtures/scope --scope project --format markdown > /tmp/git-hotspots-scope-project-2.md
diff -u /tmp/git-hotspots-scope-project.md /tmp/git-hotspots-scope-project-2.md
"$EXE" --repo fixtures/scope --scope project --format table > /tmp/git-hotspots-scope-project.txt
"$EXE" --repo fixtures/scope --scope project --inspect src/vendor_adapter.zig --format json > /tmp/git-hotspots-scope-project-inspect.json
"$EXE" --repo fixtures/scope --scope all --inspect .flow/state.yaml --format json > /tmp/git-hotspots-scope-all-inspect-flow.json
"$EXE" --repo fixtures/scope --scope all --inspect .zig-cache/from-src.txt --format json > /tmp/git-hotspots-scope-all-inspect-included-to-excluded.json
"$EXE" --repo fixtures/scope --scope all --inspect build/excluded-chain-b.txt --format json > /tmp/git-hotspots-scope-all-inspect-excluded-to-excluded.json
"$EXE" --repo fixtures/scope --scope all --inspect src/chain-final.txt --format json > /tmp/git-hotspots-scope-all-inspect-chained-cross-prefix.json
assert_fails_with_stderr inspect-project-excluded-flow "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --scope project --inspect .flow/state.yaml --format json
assert_fails_with_stderr inspect-project-included-to-excluded "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --scope project --inspect .zig-cache/from-src.txt --format json
assert_fails_with_stderr inspect-project-excluded-to-excluded-new "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --scope project --inspect build/excluded-chain-b.txt --format json
assert_fails_with_stderr inspect-project-excluded-to-excluded-old "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --scope project --inspect target/excluded-chain-a.txt --format json
assert_fails_with_stderr inspect-project-chained-excluded-hop "--inspect target has no matching Git-history evidence" "$EXE" --repo fixtures/scope --scope project --inspect node_modules/pkg/chain-mid.txt --format json
"$EXE" --repo fixtures/scope --scope project --inspect src/to-cache.txt --format json > /tmp/git-hotspots-scope-project-inspect-included-to-excluded-old.json
"$EXE" --repo fixtures/scope --scope project --inspect src/chain-final.txt --format json > /tmp/git-hotspots-scope-project-inspect-chained-cross-prefix.json
"$EXE" --repo fixtures/scope --scope project --exclude-prefix .flow/ --format json > /tmp/git-hotspots-scope-project-duplicate-flow.json
"$EXE" --repo fixtures/scope --scope project --include-prefix .flow/ --format json > /tmp/git-hotspots-scope-project-include-flow.json
"$EXE" --repo fixtures/scope --scope project --include-prefix node_modules/ --format json > /tmp/git-hotspots-scope-project-include-node-modules.json
"$EXE" --repo fixtures/scope --scope all --include-prefix node_modules/ --format json > /tmp/git-hotspots-scope-all-include-node-modules.json
"$EXE" --repo fixtures/scope --scope project --include-prefix src/ --format json > /tmp/git-hotspots-scope-project-include-src.json
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
"$EXE" --repo fixtures/scope --exclude-prefix .flow/ --exclude-prefix src/ --exclude-prefix vendor/ --exclude-prefix glob/ --exclude-prefix weird/ --exclude-prefix docs/ --format json > /tmp/git-hotspots-scope-empty.json
"$EXE" --repo fixtures/scope --exclude-prefix .flow/ --exclude-prefix src/ --exclude-prefix vendor/ --exclude-prefix glob/ --exclude-prefix weird/ --exclude-prefix docs/ --format markdown > /tmp/git-hotspots-scope-empty.md
"$EXE" --repo fixtures/scope --scope all $PROJECT_EXCLUDE_ARGS --inspect src/vendor_adapter.zig --format json > /tmp/git-hotspots-scope-inspect-excluded-flow.json
"$EXE" --repo fixtures/scope --include-prefix src/ --inspect src/new.zig --format json > /tmp/git-hotspots-scope-inspect-include-renamed.json
"$EXE" --repo fixtures/lineage --inspect simple-new.txt --format json > /tmp/git-hotspots-lineage-simple.json
grep -Fq -- '"lineage": { "aliases": ["simple-old.txt"], "partial": false' /tmp/git-hotspots-lineage-simple.json
"$EXE" --repo fixtures/lineage --inspect braced/new-name.txt --format json > /tmp/git-hotspots-lineage-braced.json
grep -Fq -- '"lineage": { "aliases": ["braced/old-name.txt"], "partial": false' /tmp/git-hotspots-lineage-braced.json
"$EXE" --repo fixtures/lineage --inspect chain/c.txt --format json > /tmp/git-hotspots-lineage-chain.json
grep -Fq -- '"lineage": { "aliases": ["chain/a.txt", "chain/b.txt"], "partial": false' /tmp/git-hotspots-lineage-chain.json
grep -Fq -- '"change_count": 3' /tmp/git-hotspots-lineage-chain.json
"$EXE" --repo fixtures/lineage --inspect chain/a.txt --format json > /tmp/git-hotspots-lineage-alias-inspect.json
grep -Fq -- '"inspect": { "requested_path": "chain/a.txt", "matched_path": "chain/c.txt"' /tmp/git-hotspots-lineage-alias-inspect.json
"$EXE" --repo fixtures/lineage --inspect rename-edit-new.txt --format json > /tmp/git-hotspots-lineage-rename-edit.json
grep -Fq -- '"lineage": { "aliases": ["rename-edit-old.txt"], "partial": false' /tmp/git-hotspots-lineage-rename-edit.json
grep -Fq -- '"additions": 2' /tmp/git-hotspots-lineage-rename-edit.json
"$EXE" --repo fixtures/lineage --inspect deleted-new.txt --format json > /tmp/git-hotspots-lineage-deleted.json
grep -Fq -- '"lineage": { "aliases": ["deleted-old.txt"], "partial": false' /tmp/git-hotspots-lineage-deleted.json
grep -Fq -- '"current_size": null' /tmp/git-hotspots-lineage-deleted.json
"$EXE" --repo fixtures/lineage --inspect cochange/new.txt --format json > /tmp/git-hotspots-lineage-cochange.json
grep -Fq -- '{ "path": "cochange/peer.txt", "count": 4 }' /tmp/git-hotspots-lineage-cochange.json
"$EXE" --repo fixtures/lineage --include-prefix src/ --inspect src/cross-new.txt --format json > /tmp/git-hotspots-lineage-cross-scope.json
grep -Fq -- '"lineage": { "aliases": [], "partial": true' /tmp/git-hotspots-lineage-cross-scope.json
! grep -Fq -- 'vendor/cross-old.txt' /tmp/git-hotspots-lineage-cross-scope.json
"$EXE" --repo fixtures/edge --inspect 'glob/[literal]*.txt' --format markdown > /tmp/git-hotspots-edge-inspect-glob.md
"$EXE" --repo fixtures/edge --inspect 'weird/tab\tname.txt' --format json > /tmp/git-hotspots-edge-inspect-tab.json
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
assert_fails_with_stderr invalid-format "invalid arguments" "$EXE" --repo fixtures/basic --format xml
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

"$EXE" --repo fixtures/edge --limit 200 --format json > /tmp/git-hotspots-edge.json
"$EXE" --repo fixtures/edge --limit 200 --format markdown > /tmp/git-hotspots-edge.md
"$EXE" --repo fixtures/medium --format json > /tmp/git-hotspots-medium.json
"$EXE" --repo fixtures/shallow --format json > /tmp/git-hotspots-shallow.json
"$EXE" --repo fixtures/partial --format json > /tmp/git-hotspots-partial.json
"$EXE" --repo fixtures/detached --format json > /tmp/git-hotspots-detached.json
"$EXE" --repo fixtures/linked --format json > /tmp/git-hotspots-linked.json

python3 - /tmp/git-hotspots-basic.md /tmp/git-hotspots-scope-filtered.md /tmp/git-hotspots-scope-project.md /tmp/git-hotspots-scope-empty.md /tmp/git-hotspots-edge.md /tmp/git-hotspots-scope-src-include.md /tmp/git-hotspots-scope-include-empty.md /tmp/git-hotspots-basic-inspect.md /tmp/git-hotspots-edge-inspect-glob.md <<'PY'
import json
import os
import re
import sys
from pathlib import Path

basic_md_path, scope_md_path, project_md_path, scope_empty_md_path, edge_md_path, include_md_path, include_empty_md_path, basic_inspect_md_path, edge_inspect_md_path = map(Path, sys.argv[1:])

def load(path):
    return json.loads(Path(path).read_text())

def by_path(data):
    return {row['path']: row for row in data['results']}

project_prefixes = ['.flow/', '.zig-cache/', 'zig-out/', 'target/', 'node_modules/', 'dist/', 'build/', 'coverage/']
def starts_project_prefix(path):
    return any(path.startswith(prefix) for prefix in project_prefixes)

basic = load('/tmp/git-hotspots-basic.json')
assert basic['analysis']['scope']['selected_scope'] == 'project'
assert basic['analysis']['scope']['filters_active'] is True
assert basic['analysis']['scope']['include_prefixes'] == []
assert basic['analysis']['scope']['exclude_prefixes'] == project_prefixes
assert basic['results'][0]['path'] == 'src/app.txt'
assert all(not row['path'].startswith('/') for row in basic['results'])
basic_inspect = load('/tmp/git-hotspots-basic-inspect.json')
assert basic_inspect['inspect'] == {'requested_path': 'src/app.txt', 'matched_path': 'src/app.txt', 'rank': 1}
assert len(basic_inspect['results']) == 1
assert basic_inspect['results'][0] == basic['results'][0]
assert 'inspect' not in basic

scope_unfiltered = load('/tmp/git-hotspots-scope-unfiltered.json')
scope_all = load('/tmp/git-hotspots-scope-all.json')
assert scope_unfiltered['analysis']['scope']['selected_scope'] == 'project', 'default selected scope changed'
assert scope_unfiltered['analysis']['scope']['exclude_prefixes'] == project_prefixes, 'default project prefix missing'
assert all(not starts_project_prefix(row['path']) for row in scope_unfiltered['results']), 'default leaked project-prefix path'
all_paths = [row['path'] for row in scope_all['results']]
assert any(path.startswith('.flow/') for path in all_paths), '--scope all lost .flow paths'
assert any(path.startswith('node_modules/') for path in all_paths), '--scope all lost generated/dependency path evidence'
assert 'src/new.zig' in all_paths, 'braced rename fixture missing new path'
assert any(path == 'weird/tab\tname.txt' for path in all_paths), 'quoted tab fixture missing unquoted path'
assert '' not in all_paths, 'empty path leaked from braced rename parsing'

scope_filtered = load('/tmp/git-hotspots-scope-filtered.json')
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

scope_project = load('/tmp/git-hotspots-scope-project.json')
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
scope_project_duplicate = load('/tmp/git-hotspots-scope-project-duplicate-flow.json')
assert scope_project_duplicate['analysis']['scope']['exclude_prefixes'] == project_prefixes
assert scope_project_duplicate['results'] == scope_project['results'], 'duplicate project exclude changed rows'
scope_project_include_flow = load('/tmp/git-hotspots-scope-project-include-flow.json')
assert scope_project_include_flow['analysis']['scope']['selected_scope'] == 'project'
assert scope_project_include_flow['analysis']['scope']['include_prefixes'] == ['.flow/']
assert scope_project_include_flow['analysis']['scope']['exclude_prefixes'] == project_prefixes
assert scope_project_include_flow['results'] == [], 'exclude did not win over include for project .flow/'
scope_project_include_node = load('/tmp/git-hotspots-scope-project-include-node-modules.json')
assert scope_project_include_node['analysis']['scope']['include_prefixes'] == ['node_modules/']
assert scope_project_include_node['analysis']['scope']['exclude_prefixes'] == project_prefixes
assert scope_project_include_node['results'] == [], 'project built-in exclude did not win over node_modules include'
scope_all_include_node = load('/tmp/git-hotspots-scope-all-include-node-modules.json')
assert scope_all_include_node['analysis']['scope']['selected_scope'] == 'all'
assert scope_all_include_node['analysis']['scope']['include_prefixes'] == ['node_modules/']
assert scope_all_include_node['analysis']['scope']['exclude_prefixes'] == []
assert [row['path'] for row in scope_all_include_node['results']] == ['node_modules/pkg/index.js', 'node_modules/pkg/chain-mid.txt']
scope_project_include_src = load('/tmp/git-hotspots-scope-project-include-src.json')
assert scope_project_include_src['analysis']['scope']['selected_scope'] == 'project'
assert scope_project_include_src['analysis']['scope']['include_prefixes'] == ['src/']
assert scope_project_include_src['analysis']['scope']['exclude_prefixes'] == project_prefixes
for row in scope_project_include_src['results']:
    assert row['path'].startswith('src/'), row['path']
    assert all(cc['path'].startswith('src/') for cc in row['cochanges']), row['path']
scope_project_inspect = load('/tmp/git-hotspots-scope-project-inspect.json')
assert scope_project_inspect['results'][0] == by_path(scope_project)['src/vendor_adapter.zig']
assert scope_project_inspect['inspect']['matched_path'] == 'src/vendor_adapter.zig'
scope_all_inspect_flow = load('/tmp/git-hotspots-scope-all-inspect-flow.json')
assert scope_all_inspect_flow['analysis']['scope']['selected_scope'] == 'all'
assert len(scope_all_inspect_flow['results']) == 1
assert scope_all_inspect_flow['results'][0]['path'] == '.flow/state.yaml'
scope_all_included_to_excluded = load('/tmp/git-hotspots-scope-all-inspect-included-to-excluded.json')
assert scope_all_included_to_excluded['results'][0]['path'] == '.zig-cache/from-src.txt'
assert scope_all_included_to_excluded['results'][0]['lineage']['aliases'] == ['src/to-cache.txt']
assert scope_all_included_to_excluded['results'][0]['lineage']['partial'] is False
scope_all_excluded_to_excluded = load('/tmp/git-hotspots-scope-all-inspect-excluded-to-excluded.json')
assert scope_all_excluded_to_excluded['results'][0]['path'] == 'build/excluded-chain-b.txt'
assert scope_all_excluded_to_excluded['results'][0]['lineage']['aliases'] == ['target/excluded-chain-a.txt']
assert scope_all_excluded_to_excluded['results'][0]['lineage']['partial'] is False
scope_all_chained_cross = load('/tmp/git-hotspots-scope-all-inspect-chained-cross-prefix.json')
assert scope_all_chained_cross['results'][0]['path'] == 'src/chain-final.txt'
assert scope_all_chained_cross['results'][0]['lineage']['aliases'] == ['node_modules/pkg/chain-mid.txt', 'src/chain-start.txt']
assert scope_all_chained_cross['results'][0]['lineage']['partial'] is False
scope_project_included_to_excluded = load('/tmp/git-hotspots-scope-project-inspect-included-to-excluded-old.json')
assert scope_project_included_to_excluded['results'][0]['path'] == 'src/to-cache.txt'
assert scope_project_included_to_excluded['results'][0]['lineage']['aliases'] == []
assert scope_project_included_to_excluded['results'][0]['lineage']['partial'] is False
assert all(not starts_project_prefix(cc['path']) for cc in scope_project_included_to_excluded['results'][0]['cochanges'])
scope_project_chained_cross = load('/tmp/git-hotspots-scope-project-inspect-chained-cross-prefix.json')
assert scope_project_chained_cross['results'][0]['path'] == 'src/chain-final.txt'
assert scope_project_chained_cross['results'][0]['lineage']['aliases'] == []
assert scope_project_chained_cross['results'][0]['lineage']['partial'] is True
assert all(not starts_project_prefix(cc['path']) for cc in scope_project_chained_cross['results'][0]['cochanges'])
for row in scope_project['results'] + scope_project_included_to_excluded['results'] + scope_project_chained_cross['results']:
    assert not starts_project_prefix(row['path']), row['path']
    assert all(not starts_project_prefix(alias) for alias in row['lineage']['aliases']), row['path']
    assert all(not starts_project_prefix(cc['path']) for cc in row['cochanges']), row['path']
scope_inspect_excluded_flow = load('/tmp/git-hotspots-scope-inspect-excluded-flow.json')
assert len(scope_inspect_excluded_flow['results']) == 1
assert scope_inspect_excluded_flow['results'][0] == by_path(scope_filtered)['src/vendor_adapter.zig']
assert scope_inspect_excluded_flow['inspect']['matched_path'] == 'src/vendor_adapter.zig'

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
scope_inspect_renamed = load('/tmp/git-hotspots-scope-inspect-include-renamed.json')
assert len(scope_inspect_renamed['results']) == 1
assert scope_inspect_renamed['results'][0] == by_path(src_include)['src/new.zig']
assert scope_inspect_renamed['inspect']['matched_path'] == 'src/new.zig'

src_vendor_include = load('/tmp/git-hotspots-scope-src-vendor-include.json')
assert src_vendor_include['analysis']['scope']['include_prefixes'] == ['src/', 'vendor/']
for row in src_vendor_include['results']:
    assert row['path'].startswith(('src/', 'vendor/')), row['path']
    assert all(cc['path'].startswith(('src/', 'vendor/')) for cc in row['cochanges']), row['path']

include_exclude = load('/tmp/git-hotspots-scope-include-exclude.json')
assert include_exclude['analysis']['scope']['include_prefixes'] == ['src/']
assert include_exclude['analysis']['scope']['exclude_prefixes'] == project_prefixes + ['src/vendor_adapter.zig']
assert include_exclude['analysis']['scope']['excluded_path_count'] == 14
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
assert 'scope: selected=all include_prefixes=[] exclude_prefixes=[.flow/,.zig-cache/,zig-out/,target/,node_modules/,dist/,build/,coverage/]' in table_text
assert '.flow/' not in '\n'.join(line for line in table_text.splitlines() if line[:1].isdigit())
project_table_text = Path('/tmp/git-hotspots-scope-project.txt').read_text()
assert 'scope: selected=project include_prefixes=[] exclude_prefixes=[.flow/,.zig-cache/,zig-out/,target/,node_modules/,dist/,build/,coverage/]' in project_table_text
assert '.flow/' not in '\n'.join(line for line in project_table_text.splitlines() if line[:1].isdigit())
include_table_text = Path('/tmp/git-hotspots-scope-src-include.txt').read_text()
assert 'scope: selected=project include_prefixes=[src/] exclude_prefixes=[.flow/,.zig-cache/,zig-out/,target/,node_modules/,dist/,build/,coverage/]' in include_table_text
for line in include_table_text.splitlines():
    if line[:1].isdigit():
        assert 'src/' in line, line
        assert '.flow/' not in line and 'vendor/' not in line and 'glob/' not in line and 'weird/' not in line, line

edge = load('/tmp/git-hotspots-edge.json')
rows = by_path(edge)
for path in ['weird/path with space.txt', 'weird/éclair.txt', 'renamed.txt']:
    assert path in rows, path
assert any('tab' in path for path in rows), 'tab path missing'
edge_inspect_tab = load('/tmp/git-hotspots-edge-inspect-tab.json')
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
