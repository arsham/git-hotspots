#!/usr/bin/env python3
import json
import sys
from pathlib import Path

required_files = {
    'fixtures/expected/symbol-relationships.json': 'Python',
    'fixtures/expected/symbol-relationships-javascript.json': 'JavaScript',
    'fixtures/expected/symbol-relationships-go.json': 'Go',
    'fixtures/expected/symbol-relationships-lua.json': 'Lua',
    'fixtures/expected/symbol-relationships-rust.json': 'Rust',
    'fixtures/expected/symbol-relationships-tsx.json': 'TSX',
    'fixtures/expected/symbol-relationships-typescript.json': 'TypeScript',
    'fixtures/expected/symbol-relationships-zig.json': 'Zig',
}

def fail(label, message):
    raise SystemExit(f'{label}: {message}')

for arg in sys.argv[1:]:
    path = Path(arg)
    label = required_files.get(str(path), path.name)
    with path.open(encoding='utf-8') as fh:
        data = json.load(fh)
    relationships = data.get('symbol_relationships') or {}
    records = relationships.get('records') or []
    if not records:
        fail(label, 'relationship golden has no records')
    caveats = {caveat for record in records for caveat in (record.get('caveats') or [])}
    joined = '\n'.join(sorted(caveats))
    kinds = {record.get('kind') for record in records}
    has_unresolved = any(record.get('target_unresolved') for record in records)

    required_classes = [
        ('product-truth boundary', 'file-level Git evidence remains product truth'),
        ('optional-provider boundary', 'optional caveated provider evidence'),
        ('scoring/ranking boundary', 'not used for scoring, ranking'),
        ('bounded syntax proof', 'bounded'),
        ('syntax proof noun', 'syntax proof'),
    ]
    for class_name, needle in required_classes:
        if needle not in joined:
            fail(label, f'missing {class_name}: {needle!r}')

    if (
        'no local target mapping is fabricated' not in joined
        and 'unresolved and external-string endpoints are caveated' not in joined
    ):
        fail(label, 'missing endpoint-resolution boundary')

    if has_unresolved and not any(caveat.startswith('target is unresolved by this bounded') for caveat in caveats):
        fail(label, 'missing unresolved-target record caveat')

    if 'unknown' in kinds and not any('cannot be classified safely by this proof' in caveat for caveat in caveats):
        fail(label, 'missing unknown relation-like syntax caveat')

    if 'import_include' in kinds:
        external_strings = (
            'external string',
            'package, module',
            'Cargo, crate',
            'package lookup',
            'Node, package',
        )
        if not any(any(needle in caveat for needle in external_strings) for caveat in caveats):
            fail(label, 'missing external-string endpoint caveat')

    if 'unknown' in kinds and 'unknown relation-like syntax' not in joined and 'relation-like' not in joined:
        fail(label, 'missing relation-like wording for unknown records')

    provider = (relationships.get('providers') or [{}])[0]
    provider_name = ((provider.get('provider') or {}).get('name') or '')
    if provider_name and provider_name not in json.dumps(data):
        fail(label, 'provider identity missing from relationship evidence')
