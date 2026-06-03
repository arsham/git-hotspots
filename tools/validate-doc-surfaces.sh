#!/bin/sh

  require_anchor() {
    grep -Fq -- "$2" "$1"
  }

  [ -f docs/user-guide.md ] || exit 1
  [ -f docs/developer-guide.md ] || exit 1
  [ -f docs/historical-symbol-fixture-realism-matrix.md ] || exit 1
  [ -f docs/historical-provider-state-fixture-gap-audit.md ] || exit 1
  [ -f man/git-hotspots.1 ] || exit 1

  grep -Fq '# git-hotspots user guide' docs/user-guide.md || exit 1
  grep -Fq -- '--help' docs/user-guide.md || exit 1
  grep -Fq -- '--explain' docs/user-guide.md || exit 1
  grep -Fq -- '--inspect' docs/user-guide.md || exit 1
  grep -Fq -- '--symbols' docs/user-guide.md || exit 1
  grep -Fq -- '--symbol-line-history' docs/user-guide.md || exit 1
  grep -Fq -- '--historical-symbols' docs/user-guide.md || exit 1
  grep -Fq -- '--symbol-relationships' docs/user-guide.md || exit 1
  grep -Fq 'Provider capability summary' docs/user-guide.md || exit 1
  grep -Fq 'Python, JavaScript,' docs/user-guide.md || exit 1
  grep -Fq 'TypeScript, and TSX Tree-sitter lanes' docs/user-guide.md || exit 1
  grep -Fq 'When pairing `--historical-symbols` with `--symbol-relationships`' docs/user-guide.md || exit 1
  grep -Fq 'Historical-symbol rows do not explain why churn happened' docs/user-guide.md || exit 1
  for anchor in \
    'Historical-symbol caveat glossary' \
    'Revision-local attribution' \
    'File-level fallback' \
    'Fallback hunk pressure' \
    'Read fallback row counts and fallback hunk counts separately' \
    'Unattributed hunk fallback' \
    'Historical provider-state guide' \
    '| `ok` | covered |' \
    '| `unsupported` | covered |' \
    '| `skipped` | covered |' \
    '| `failed` | covered |' \
    '| `timed_out` | uncovered |' \
    '| `unavailable` | uncovered |' \
    'Aggregate record bound' \
    'docs/historical-symbol-fixture-realism-matrix.md' \
    'docs/historical-provider-state-fixture-gap-audit.md' \
    'Combined evidence FAQ' \
    'Does this predict bugs?' \
    'Does relationship evidence prove dependencies or calls?' \
    'Does historical-symbol evidence prove semantic lineage?' \
    'Which document owns provider capability claims?'
  do
    require_anchor docs/user-guide.md "$anchor" || exit 1
  done
  for anchor in \
    'Relationship caveats and provider boundaries' \
    'Relationship row quick reference' \
    'Relationship caveat glossary' \
    'Use this section as the quick reference' \
    'Bounded syntax proof' \
    'Unknown relation-like syntax' \
    'Unresolved endpoint' \
    'External-string endpoint' \
    'Human display omission' \
    'Provider-cap omission' \
    'Provider caveat table' \
    'docs/relationship-fixture-realism-matrix.md' \
    'docs/provider-specific-caveat-wording-audit.md' \
    '| Lane | Main syntax evidence | Main caveats | Does not prove |' \
    '| Python | definitions, local references, calls, imports, unresolved names, ambiguous attributes |' \
    '| JavaScript | definitions, local references, calls, imports/includes, unresolved identifiers, member/computed syntax |' \
    '| Go | top-level declarations, imports, direct identifier calls, selector-like syntax, unresolved identifiers, unknown syntax |' \
    '| Lua | module-level symbols, `require`-like imports, direct calls, table/member reference-like syntax, unresolved identifiers, unknown syntax |' \
    '| Rust | modules, structs/enums/functions, `mod`/`use`, direct calls, path/member syntax, unresolved identifiers, unknown syntax |' \
    '| TypeScript | functions/classes/interfaces/types, imports, direct calls, unresolved identifiers, type-only and member syntax |' \
    '| TSX | components/functions/classes, imports, JSX/member syntax, unresolved identifiers, unknown syntax |' \
    '| Zig | declarations, `@import` strings, direct calls, local references, unresolved identifiers, member/comptime-like syntax |' \
    'package/module/vendor resolution, type/interface/method-set truth' \
    'React/runtime truth, type checker truth, module resolution' \
    'build graph truth, package resolution, comptime execution' \
    'Glossary example' \
    'Go provider observed a top-level declaration relationship' \
    'human_display_sample_omitted=9' \
    'target_unresolved: true' \
    'provider_partial_evidence_omitted' \
    'emitted=15 kinds=contains:8,reference:2,call:1,import_include:1,unknown:2,unresolved:1'
  do
    require_anchor docs/user-guide.md "$anchor" || exit 1
  done
  grep -Fq 'Zig `.zig` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-zig-relations`' docs/user-guide.md || exit 1
  grep -Fq 'Go `.go` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-go-relations`' docs/user-guide.md || exit 1
  grep -Fq 'Lua `.lua` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-lua-relations`' docs/user-guide.md || exit 1
  grep -Fq 'Rust `.rs` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-rust-relations`' docs/user-guide.md || exit 1
  grep -Fq 'Rust support is syntax-only' docs/user-guide.md || exit 1
  grep -Fq 'Cargo metadata, crates, module resolution' docs/user-guide.md || exit 1
  grep -Fq -- '--scope all' docs/user-guide.md || exit 1
  grep -Fq -- '--include-prefix' docs/user-guide.md || exit 1
  grep -Fq -- '--exclude-prefix' docs/user-guide.md || exit 1
  grep -Fq 'zig build validate' docs/user-guide.md || exit 1
  grep -Fq 'tools/release-linux.sh' docs/user-guide.md || exit 1
  grep -Fq 'unpublished use' docs/user-guide.md || exit 1
  grep -Fq 'error: --symbol-line-history requires --symbols' docs/user-guide.md || exit 1
  grep -Fq 'error: --historical-symbols requires --symbols' docs/user-guide.md || exit 1
  grep -Fq 'error: --symbol-relationships requires --symbols' docs/user-guide.md || exit 1
  grep -Fq 'local-first' docs/user-guide.md || exit 1
  grep -Fq 'telemetry' docs/user-guide.md || exit 1

  grep -Fq '# git-hotspots developer guide' docs/developer-guide.md || exit 1
  grep -Fq 'src/cli.zig' docs/developer-guide.md || exit 1
  grep -Fq 'tools/validate.sh' docs/developer-guide.md || exit 1
  grep -Fq 'CLI misuse matrix' docs/developer-guide.md || exit 1
  grep -Fq 'zig build validate-all' docs/developer-guide.md || exit 1
  grep -Fq 'tools/release-linux.sh' docs/developer-guide.md || exit 1
  grep -Fq 'packaging/aur/git-hotspots-bin/' docs/developer-guide.md || exit 1
  grep -Fq 'prohibited-claim' docs/developer-guide.md || exit 1
  grep -Fq 'Provider capability claims are validation-owned' docs/developer-guide.md || exit 1
  grep -Fq 'Capability documentation has one direction of travel' docs/developer-guide.md || exit 1
  grep -Fq 'docs/historical-symbol-fixture-realism-matrix.md' docs/developer-guide.md || exit 1
  grep -Fq 'Use `zig build validate-all` before publishing' docs/developer-guide.md || exit 1
  grep -Fq 'full proof aggregate' docs/developer-guide.md || exit 1
  grep -Fq 'TypeScript `.ts`, `.mts`, `.cts` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-typescript-relations`' docs/developer-guide.md || exit 1
  grep -Fq 'Local-first' docs/developer-guide.md || exit 1

  grep -Fq '.SH NAME' man/git-hotspots.1 || exit 1
  grep -Fq '.SH SYNOPSIS' man/git-hotspots.1 || exit 1
  grep -Fq '.SH DESCRIPTION' man/git-hotspots.1 || exit 1
  grep -Fq '.SH OPTIONS' man/git-hotspots.1 || exit 1
  grep -Fq '.SH EXAMPLES' man/git-hotspots.1 || exit 1
  grep -Fq '.SH REPORT SEMANTICS' man/git-hotspots.1 || exit 1
  grep -Fq '.SH PRIVACY AND LOCAL-FIRST CAVEATS' man/git-hotspots.1 || exit 1
  grep -Fq '.SH PROVIDER BOUNDARIES' man/git-hotspots.1 || exit 1
  grep -Fq '.SH DIAGNOSTICS' man/git-hotspots.1 || exit 1
  grep -Fq '.SH EXIT STATUS' man/git-hotspots.1 || exit 1
  grep -Fq '.SH RELATED DOCUMENTS' man/git-hotspots.1 || exit 1
  grep -Fq -- '--help' man/git-hotspots.1 || exit 1
  grep -Fq -- '--explain' man/git-hotspots.1 || exit 1
  grep -Fq -- '--inspect' man/git-hotspots.1 || exit 1
  grep -Fq -- '--symbols' man/git-hotspots.1 || exit 1
  grep -Fq -- '--historical-symbols' man/git-hotspots.1 || exit 1
  grep -Fq -- '--symbol-relationships' man/git-hotspots.1 || exit 1
  grep -Fq 'Capability by language' man/git-hotspots.1 || exit 1
  grep -Fq 'Zig, Go, Python, JavaScript, Lua, Rust, TypeScript, and TSX lanes' man/git-hotspots.1 || exit 1
  grep -Fq 'tree-sitter-zig-relations' man/git-hotspots.1 || exit 1
  grep -Fq 'tree-sitter-go-relations' man/git-hotspots.1 || exit 1
  grep -Fq 'tree-sitter-lua-relations' man/git-hotspots.1 || exit 1
  grep -Fq 'tree-sitter-rust-relations' man/git-hotspots.1 || exit 1
  grep -Fq 'Other current files preserve file evidence' man/git-hotspots.1 || exit 1
  grep -Fq 'For a focused historical-symbol and relationship workflow' man/git-hotspots.1 || exit 1
  grep -Fq 'historical attribution does not explain why churn happened' man/git-hotspots.1 || exit 1
  grep -Fq 'Historical-symbol caveat glossary' man/git-hotspots.1 || exit 1
  grep -Fq 'Revision-local attribution' man/git-hotspots.1 || exit 1
  grep -Fq 'docs/historical-symbol-fixture-realism-matrix.md' man/git-hotspots.1 || exit 1
  grep -Fq 'Relationship caveat glossary' man/git-hotspots.1 || exit 1
  grep -Fq 'provider caveat table' man/git-hotspots.1 || exit 1
  grep -Fq 'Bounded syntax proof' man/git-hotspots.1 || exit 1
  grep -Fq 'Unknown relation-like syntax' man/git-hotspots.1 || exit 1
  grep -Fq 'Unresolved endpoint' man/git-hotspots.1 || exit 1
  grep -Fq 'External-string endpoint' man/git-hotspots.1 || exit 1
  grep -Fq 'human_display_sample_omitted' man/git-hotspots.1 || exit 1
  grep -Fq 'provider_partial_evidence_omitted' man/git-hotspots.1 || exit 1
  grep -Fq 'emitted=15 kinds=contains:8,reference:2,call:1,import_include:1,unknown:2,unresolved:1' man/git-hotspots.1 || exit 1
  grep -Fq 'human_display_sample_omitted=9' man/git-hotspots.1 || exit 1
  grep -Fq -- '--progress' man/git-hotspots.1 || exit 1
  grep -Fq 'local-first' man/git-hotspots.1 || exit 1
  ! grep -Eq 'dogfood|tools/release-linux\.sh|packaging/aur|makepkg|pacman|pkg\.tar' man/git-hotspots.1 || exit 1

  grep -Fq 'docs/user-guide.md' README.md || exit 1
  grep -Fq 'docs/historical-symbol-fixture-realism-matrix.md' README.md || exit 1
  grep -Fq 'Provider capability claims are summarised' README.md || exit 1

  grep -Fq 'Fallback hunk pressure' docs/historical-symbol-fixture-realism-matrix.md || exit 1
  grep -Fq 'fallback row count separate from fallback hunk pressure' docs/historical-symbol-fixture-realism-matrix.md || exit 1
  grep -Fq 'fallback rows, and fallback hunk pressure' docs/historical-symbol-fixture-realism-matrix.md || exit 1
  grep -Fq 'Failed parser fallback' docs/historical-symbol-fixture-realism-matrix.md || exit 1
  grep -Fq '`timed_out` and `unavailable` remain explicit historical provider-state' docs/historical-symbol-fixture-realism-matrix.md || exit 1
  grep -Fq 'historical-provider-state-fixture-gap-audit.md' docs/historical-symbol-fixture-realism-matrix.md || exit 1
  grep -Fq 'Historical provider-state fixture gap audit' docs/historical-provider-state-fixture-gap-audit.md || exit 1
  grep -Fq '| `failed` | yes | `src/broken.zig` malformed historical Zig blob produces a failed fallback row |' docs/historical-provider-state-fixture-gap-audit.md || exit 1
  grep -Fq '| `timed_out` | no | no provider timeout injection exists for historical attribution |' docs/historical-provider-state-fixture-gap-audit.md || exit 1
  grep -Fq '| `unavailable` | no | no historical blob fixture currently exercises unavailable provider input |' docs/historical-provider-state-fixture-gap-audit.md || exit 1
  grep -Fq 'Keep the deterministic `failed` fixture in this slice' docs/historical-provider-state-fixture-gap-audit.md || exit 1
  grep -Fq 'wall-clock timeout fixtures or environment-dependent missing-provider' docs/historical-provider-state-fixture-gap-audit.md || exit 1
  grep -Fq 'Zig, Go, Python, JavaScript, Lua, Rust, TypeScript, and' README.md || exit 1
  grep -Fq 'retained ranked-file candidates in Zig' README.md || exit 1
  grep -Fq 'For a focused historical-symbol and relationship workflow' README.md || exit 1
  grep -Fq 'historical attribution does not' README.md || exit 1
  grep -Fq 'relationship caveat glossary' README.md || exit 1
  grep -Fq 'caveat table covering' README.md || exit 1
  grep -Fq 'syntax proof' README.md || exit 1
  grep -Fq 'external-string endpoints' README.md || exit 1
  grep -Fq 'emitted=15 kinds=contains:8,reference:2,call:1,import_include:1,unknown:2,unresolved:1' README.md || exit 1
  grep -Fq 'human_display_sample_omitted=9' README.md || exit 1
  grep -Fq 'Invalid CLI combinations exit 2' README.md || exit 1
  grep -Fq 'Local Linux dogfood packaging' README.md || exit 1
  grep -Fq 'tools/release-linux.sh' README.md || exit 1
  grep -Fq 'man/git-hotspots.1' README.md || exit 1
  grep -Fq 'docs/developer-guide.md' README.md || exit 1
  grep -Fq 'docs/developer-guide.md' CONTRIBUTING.md || exit 1

  command -v python3 >/dev/null 2>&1 || exit 1
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
