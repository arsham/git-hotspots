#!/usr/bin/env python3
import collections
import json
import re
import sys
from pathlib import Path

doc_path = Path(sys.argv[1])
text = doc_path.read_text(encoding='utf-8')
lanes = [
    ('Python', sys.argv[2], 'tree-sitter-python-relations', 'repeat endpoint pairs exercise duplicate-looking guard; provider-cap coverage remains in synthetic integration fixture, not this lane golden'),
    ('JavaScript', sys.argv[3], 'tree-sitter-javascript-relations', 'repeat endpoint pairs exercise duplicate-looking guard; provider-cap coverage remains in synthetic integration fixture, not this lane golden'),
    ('Go', sys.argv[4], 'tree-sitter-go-relations', 'stable Go fixture covers provider wording categories; provider-cap coverage remains in synthetic integration fixture'),
    ('Lua', sys.argv[5], 'tree-sitter-lua-relations', 'repeat endpoint pairs exercise duplicate-looking guard; provider-cap coverage remains in synthetic integration fixture, not this lane golden'),
    ('Rust', sys.argv[6], 'tree-sitter-rust-relations', 'repeat endpoint pairs exercise duplicate-looking guard; provider-cap coverage remains in synthetic integration fixture, not this lane golden'),
    ('TSX', sys.argv[7], 'tree-sitter-tsx-relations', 'no repeated endpoint-pair guard in this lane; cross-lane duplicate-looking guards cover the category; provider-cap coverage remains in synthetic integration fixture'),
    ('TypeScript', sys.argv[8], 'tree-sitter-typescript-relations', 'repeat endpoint pairs exercise duplicate-looking guard; provider-cap coverage remains in synthetic integration fixture, not this lane golden'),
    ('Zig', sys.argv[9], 'tree-sitter-zig-relations', 'no repeated endpoint-pair guard in this lane; stable Zig cap coverage would be oversized and cap-coupled, so cap coverage remains synthetic'),
]

required_phrases = [
    'zig build validate',
    'runtime behaviour',
    'CLI flags',
    'JSON schema',
    'scoring',
    'network behaviour',
    'telemetry',
    'release state',
    'private paths',
    'raw private reports',
]
for phrase in required_phrases:
    if phrase not in text:
        raise SystemExit(f'{doc_path}: missing matrix review phrase: {phrase}')

def expected_row(label, path_name, provider_name, rationale):
    with open(path_name, encoding='utf-8') as fh:
        relationships = json.load(fh)['symbol_relationships']
    records = relationships['records']
    kind_counts = collections.OrderedDict()
    for record in records:
        kind_counts[record['kind']] = kind_counts.get(record['kind'], 0) + 1
    kind_summary = ', '.join(f'{kind} {count}' for kind, count in kind_counts.items())
    unresolved = sum(1 for record in records if record.get('target_unresolved'))
    human_display = relationships['human_display']
    provider_omitted = sum(int(provider.get('omitted_count', provider.get('omitted_record_count', 0)) or 0) for provider in relationships.get('providers', []))
    provider_caps = sum(1 for provider in relationships.get('providers', []) if provider.get('cap_reached'))
    caveat_instances = sum(len(record.get('caveats', [])) for record in records)
    caveat_unique = len({caveat for record in records for caveat in record.get('caveats', [])})
    exact_duplicates = len(records) - len({
        (
            record['source_endpoint'],
            record['target_endpoint'],
            record['kind'],
            record['direction'],
            record['provider']['name'],
            record['evidence_basis'],
        )
        for record in records
    })
    endpoint_pairs = collections.Counter((record['source_endpoint'], record['target_endpoint']) for record in records)
    repeated_pairs = sum(1 for count in endpoint_pairs.values() if count > 1)
    return (
        f'| {label} | `{path_name}` | `{provider_name}` | {len(records)} | '
        f'{kind_summary} | {unresolved} | {human_display["shown_count"]}/{human_display["total_count"]}, '
        f'omitted {human_display["omitted_count"]} | {provider_omitted} omitted, {provider_caps} caps; '
        f'{rationale} | {caveat_instances} instances, {caveat_unique} unique | '
        f'exact duplicates {exact_duplicates}; repeated endpoint pairs {repeated_pairs} |'
    )

for lane in lanes:
    row = expected_row(*lane)
    if row not in text:
        raise SystemExit(f'{doc_path}: generated row drifted or is missing:\n{row}')

for needle in ('/home/', '/Users/', 'file://', 'https://', 'http://', 'ssh://', 'git@'):
    if needle in text:
        raise SystemExit(f'{doc_path}: private path or remote marker leaked: {needle}')
if re.search(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', text):
    raise SystemExit(f'{doc_path}: email-like identity leaked')
