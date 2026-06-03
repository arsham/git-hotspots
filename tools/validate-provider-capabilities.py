#!/usr/bin/env python3
import json
import sys
from pathlib import Path

readme = Path(sys.argv[1]).read_text(encoding='utf-8')
user_guide = Path(sys.argv[2]).read_text(encoding='utf-8')
developer_guide = Path(sys.argv[3]).read_text(encoding='utf-8')
man_page = Path(sys.argv[4]).read_text(encoding='utf-8')
explain = Path(sys.argv[5]).read_text(encoding='utf-8')
help_text = Path(sys.argv[6]).read_text(encoding='utf-8')
payloads = [json.load(open(path, encoding='utf-8')) for path in sys.argv[7:]]
zig, go, python, javascript, lua, rust, typescript, tsx, unsupported = payloads[:9]
rel_zig, rel_go, rel_python, rel_javascript, rel_lua, rel_rust, rel_typescript, rel_tsx, rel_unsupported = payloads[9:]


def fail(message: str) -> None:
    raise SystemExit(message)


def check(condition: bool, message: str) -> None:
    if not condition:
        fail(message)

readme_rows = [
    '| Zig | `.zig` | `tree-sitter-zig` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | revision-local hunk attribution through `tree-sitter-zig` when parsing succeeds | public opt-in `tree-sitter-zig-relations` syntax evidence | no packages, build graph, comptime, generated-code truth, dependencies, semantic moves, true semantic lineage, scoring, or ownership claims |',
    '| Go | `.go` | `tree-sitter-go` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | revision-local hunk attribution through `tree-sitter-go` when parsing succeeds | public opt-in `tree-sitter-go-relations` syntax evidence | no packages, modules, build tags, cgo, dependency graphs, method-set or interface semantics, true semantic lineage, scoring, or ownership claims |',
    '| Python | `.py` | `tree-sitter-python` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | revision-local hunk attribution through `tree-sitter-python` when parsing succeeds | public opt-in `tree-sitter-python-relations` syntax evidence | no imports, packages, virtual environments, dependency graphs, generated-source policy, call-graph truth, scoring, or ownership claims |',
    '| JavaScript | `.js`, `.mjs`, `.cjs`, admitted `.jsx` | `tree-sitter-javascript` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | revision-local hunk attribution through `tree-sitter-javascript` when parsing succeeds | public opt-in `tree-sitter-javascript-relations` syntax evidence | no Node, packages, workspaces, module resolution, TypeScript, TSX, dependency graphs, call-graph truth, scoring, or ownership claims |',
    '| Lua | `.lua` | `tree-sitter-lua` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | revision-local hunk attribution through `tree-sitter-lua` when parsing succeeds | public opt-in `tree-sitter-lua-relations` syntax evidence | no package, require, runtime module resolution, metatables, dynamic table keys, dependency graphs, runtime execution, scoring, or ownership claims |',
    '| Rust | `.rs` | `tree-sitter-rust` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | revision-local hunk attribution through `tree-sitter-rust` when parsing succeeds | public opt-in `tree-sitter-rust-relations` syntax evidence | no Cargo, crates, module resolution, macro expansion output, cfg feature selection, type checking, dependency graphs, call-graph truth, scoring, or ownership claims |',
    '| TypeScript | `.ts`, `.mts`, `.cts` | `tree-sitter-typescript` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | revision-local hunk attribution through `tree-sitter-typescript` when parsing succeeds | public opt-in `tree-sitter-typescript-relations` syntax evidence | no packages, workspaces, tsconfig, module resolution, type checking, dependency graphs, cache, call-graph truth, scoring, or ownership claims |',
    '| TSX | `.tsx` | `tree-sitter-tsx` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | revision-local hunk attribution through `tree-sitter-tsx` when parsing succeeds | public opt-in `tree-sitter-tsx-relations` syntax evidence | no React, DOM, packages, type analysis, dependency graphs, cache, call-graph truth, scoring, or ownership claims |',
    '| Unsupported current files | all other paths | unsupported fallback | provider reports `unsupported` and keeps inspected file evidence | no current-line evidence | file-level fallback only when retained by historical attribution | unsupported | no parser diagnostics, source snippets, parsed symbols, relationship support, or scoring claims |',
]
for row in readme_rows:
    check(row in readme, f'README capability row missing: {row}')

explain_rows = [row.replace('`', '') for row in readme_rows]
for row in explain_rows:
    check(row in explain, f'explain capability row missing: {row}')

for text, label in ((readme, 'README'), (explain, 'explain')):
    normalized_text = text.replace('`', '')
    check('Provider capability matrix' in text, f'{label} matrix heading missing')
    check('current-line Git evidence for HEAD line ranges' in text, f'{label} current-line basis missing')
    check('--historical-symbols evidence' in normalized_text, f'{label} historical-symbol matrix column missing')
    check('--symbol-relationships evidence' in normalized_text, f'{label} relationship matrix column missing')
    check('public opt-in tree-sitter-zig-relations syntax evidence' in normalized_text, f'{label} Zig relationship support missing')
    check('public opt-in tree-sitter-go-relations syntax evidence' in normalized_text, f'{label} Go relationship support missing')
    check('public opt-in tree-sitter-lua-relations syntax evidence' in normalized_text, f'{label} Lua relationship support missing')
    check('public opt-in tree-sitter-rust-relations syntax evidence' in normalized_text, f'{label} Rust relationship support missing')
    check('file-level fallback only when retained by historical attribution' in text, f'{label} unsupported fallback wording missing')

summary_rows = [
    '| Zig `.zig` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-zig-relations` |',
    '| Go `.go` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-go-relations` |',
    '| Python `.py` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-python-relations` |',
    '| JavaScript `.js`, `.mjs`, `.cjs`, `.jsx` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-javascript-relations` |',
    '| Lua `.lua` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-lua-relations` |',
    '| Rust `.rs` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-rust-relations` |',
    '| TypeScript `.ts`, `.mts`, `.cts` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-typescript-relations` |',
    '| TSX `.tsx` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-tsx-relations` |',
    '| Other current files | unsupported fallback | unsupported | file-level fallback only when retained | unsupported |',
]
for text, label in ((user_guide, 'user guide'), (developer_guide, 'developer guide')):
    check('Provider capability summary' in text or 'current public matrix' in text, f'{label} capability summary missing')
    for row in summary_rows:
        check(row in text, f'{label} capability row missing: {row}')

for needle in (
    'Zig', 'Go', 'Python', 'JavaScript', 'Lua', 'Rust', 'TypeScript', 'TSX',
    'tree-sitter-zig-relations', 'tree-sitter-go-relations',
    'tree-sitter-python-relations', 'tree-sitter-javascript-relations',
    'tree-sitter-lua-relations', 'tree-sitter-rust-relations',
    'tree-sitter-typescript-relations', 'tree-sitter-tsx-relations',
    'Other current files preserve file evidence',
    'file-level fallback only when',
):
    check(needle in man_page, f'man capability text missing: {needle}')

for needle in (
    'Provider capability:',
    'current working-tree symbol evidence',
    'Other ranked current files are counted as unsupported while preserving file evidence.',
    'not true symbol history, lineage, scoring, or ownership',
    'Zig, Go, Python, JavaScript, Lua,',
    'Rust, TypeScript, and TSX lanes only',
):
    check(needle in help_text, f'help capability text missing: {needle}')

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
    check(data['inspect']['matched_path'] == matched_path, f'{label} inspect path changed')
    check(symbols['current_only'] is True, f'{label} symbols are not current-only')
    check(provider['name'] == provider_name, f'{label} provider name changed')
    check(provider['failure'] == 'ok', f'{label} provider failure changed')
    check(provider['provenance']['local_only'] is True, f'{label} local provenance missing')
    check(symbols['items'], f'{label} symbol list unexpectedly empty')
    check(all(row['path'] == matched_path for row in symbols['items']), f'{label} leaked non-inspected file symbols')
    check(all('current_line_history' in row for row in symbols['items']), f'{label} current-line evidence missing')
    for row in symbols['items']:
        history = row['current_line_history']
        check(history['basis'] == 'current-line-range-at-head', f'{label} line-history basis changed')
        check(history['current_only'] is True, f'{label} line-history current_only changed')

relationship_supported = [
    ('Zig', rel_zig, 'tree-sitter-zig-relations'),
    ('Go', rel_go, 'tree-sitter-go-relations'),
    ('Python', rel_python, 'tree-sitter-python-relations'),
    ('JavaScript', rel_javascript, 'tree-sitter-javascript-relations'),
    ('Lua', rel_lua, 'tree-sitter-lua-relations'),
    ('Rust', rel_rust, 'tree-sitter-rust-relations'),
    ('TypeScript', rel_typescript, 'tree-sitter-typescript-relations'),
    ('TSX', rel_tsx, 'tree-sitter-tsx-relations'),
]
for label, data, provider_name in relationship_supported:
    relationships = data['symbol_relationships']
    check(relationships['basis']['requires_symbols_flag'] is True, f'{label} relation flag dependency changed')
    check(relationships['basis']['scoring_effect'] == 'none', f'{label} relation scoring effect changed')
    check(relationships['provenance']['local_only'] is True, f'{label} relation local provenance missing')
    check(relationships['records'], f'{label} relation records unexpectedly empty')
    provider_names = {entry['provider']['name'] for entry in relationships['providers']}
    check(provider_name in provider_names, f'{label} relation provider changed: {provider_names}')
    check(all(record['provider']['input'].startswith('working-tree:') for record in relationships['records']), f'{label} relation input provenance changed')

relationship_unsupported = [
    ('Unsupported', rel_unsupported),
]
for label, data in relationship_unsupported:
    relationships = data['symbol_relationships']
    check(relationships['basis']['requires_symbols_flag'] is True, f'{label} relation flag dependency changed')
    check(relationships['basis']['scoring_effect'] == 'none', f'{label} relation scoring effect changed')
    check(relationships['summary']['relation_record_count'] == 0, f'{label} relation records appeared despite unsupported public lane')
    check(relationships['records'] == [], f'{label} relation records appeared despite unsupported public lane')
    failures = {entry['provider']['failure'] for entry in relationships['providers']}
    check('unsupported' in failures, f'{label} unsupported relation provider state missing: {failures}')

unsupported_symbols = unsupported['symbols']
check(unsupported['results'], 'unsupported inspect lost file evidence')
check(unsupported_symbols['current_only'] is True, 'unsupported symbols current_only missing')
check(unsupported_symbols['provider']['failure'] == 'unsupported', 'unsupported provider failure changed')
check(unsupported_symbols['items'] == [], 'unsupported language emitted symbol items')
check('current_line_history' not in json.dumps(unsupported, ensure_ascii=False), 'unsupported language emitted line history')
