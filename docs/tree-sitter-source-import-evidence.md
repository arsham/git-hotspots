# Tree-sitter source import evidence

This is the Feature 0025 execution evidence for the non-runtime source import. It
records repo-relative source identity, local source-size measurements, offline
validation, and no-provider byte stability. It adds no parser compile path, link
path, parser runtime, provider registry, CLI/report/schema/scoring/cache change,
network runtime, telemetry, upload, remote enrichment, or background analysis.

## Imported source identity

- Tree-sitter core is imported under
  `third_party/tree-sitter-core/v0.26.9` from public upstream tag `v0.26.9`,
  commit `7f534862c3ec939c3a6ee147f7600ef5c1bf900f`.
- tree-sitter-zig is imported under
  `third_party/tree-sitter-zig/v1.1.2` from public upstream tag `v1.1.2`,
  commit `b670c8df85a1568f498aa5c8cae42f51a90473c0`.
- Exact imported file BOMs are recorded in
  `third_party/tree-sitter-core/v0.26.9/IMPORTED_FILES.tsv` and
  `third_party/tree-sitter-zig/v1.1.2/IMPORTED_FILES.tsv`.
- Per-component provenance is recorded in each component `PROVENANCE.md`.
- Repo-level notice text is recorded in `THIRD_PARTY_NOTICES.md`.

## Generated parser basis

`third_party/tree-sitter-zig/v1.1.2/src/parser.c` is accepted as a pinned
upstream generated artefact. The selected Git commit and the public release
source asset contain identical parser content, Git blob
`cb09604e5dac45c2bd599e3bdc509411ea6ed2a1`, with byte size `5843608`. Parser
generation was not run locally, and no package-manager fetch or global
Tree-sitter CLI dependency was added.

## Source-size measurements

Commands used repo-relative paths only:

```sh
find third_party/tree-sitter-core third_party/tree-sitter-zig -type f -print0 | xargs -0 wc -c
find third_party/tree-sitter-core third_party/tree-sitter-zig -type f -printf '%s %p\n' | sort -nr | head -10
wc -c third_party/tree-sitter-zig/*/src/parser.c
du -sk --exclude=.git --exclude=.zig-cache --exclude=zig-out .
```

Observed source-size evidence:

- Imported source bytes, excluding provenance and manifest files:
  - Tree-sitter core: `770942` bytes.
  - tree-sitter-zig: `6091875` bytes.
- Bytes under the committed `third_party` component paths, including manifests
  and provenance files: `6880211` bytes.
- Zig parser size: `5843608` bytes.
- Largest ten vendored files:
  1. `third_party/tree-sitter-zig/v1.1.2/src/parser.c` - `5843608` bytes.
  2. `third_party/tree-sitter-core/v0.26.9/lib/src/query.c` - `161520` bytes.
  3. `third_party/tree-sitter-zig/v1.1.2/src/grammar.json` - `159437` bytes.
  4. `third_party/tree-sitter-core/v0.26.9/lib/src/wasm/wasm-stdlib.h` -
     `92720` bytes.
  5. `third_party/tree-sitter-core/v0.26.9/lib/src/parser.c` - `77844` bytes.
  6. `third_party/tree-sitter-core/v0.26.9/lib/src/wasm_store.c` - `67793`
     bytes.
  7. `third_party/tree-sitter-zig/v1.1.2/src/node-types.json` - `53932` bytes.
  8. `third_party/tree-sitter-core/v0.26.9/lib/include/tree_sitter/api.h` -
     `47478` bytes.
  9. `third_party/tree-sitter-core/v0.26.9/lib/src/subtree.c` - `34540` bytes.
  10. `third_party/tree-sitter-core/v0.26.9/lib/src/unicode/utf8.h` - `31698`
      bytes.
- Repository working-tree size excluding `.git`, `.zig-cache`, and `zig-out`:
  - Before import: `3732` KiB.
  - After import: `10532` KiB.

No planner-review size threshold is triggered: the parser is below `6000000`
bytes, no single file exceeds `6000000` bytes, and total vendored source is
below `8000000` bytes.

## Build-impact and offline validation evidence

The validation command shape was:

```sh
zig build validate
```

Observed timing evidence:

- Before import: pass, `real 8.76`, `user 7.24`, `sys 3.95`.
- After import: pass, `real 9.46`, `user 7.79`, `sys 4.34`.

Validation reported local-only behavior: no fetch, pull, push, upload,
telemetry, remote enrichment, CI service, provider runtime, cache requirement,
packaging, or release automation.

## No-provider byte-stability evidence

Representative table, JSON, Markdown, and inspect outputs were captured before
and after the source import using existing fixture commands. Each before/after
pair matched byte-for-byte with `cmp`.

Stable output digests were:

- Table: `a5e76af80689af6cd365c22bf37aa5a04f6173c6147ba2de076f9005cbf3c02a`.
- JSON: `3437fc55042e9725d97e76652d97397a0f0fb724a6510b5d670003c632018fb3`.
- Markdown: `987dffcbf88e2bc081c4cd0b593b1724dde1041e29da0f5a0329cc8c62b12f75`.
- Inspect JSON:
  `96495ca536a5c6019192eeb27f4b2abd9ac67a8f36b6483f7ac745382a73d292`.

## Protected-surface evidence

Protected runtime, test, fixture, build, and validation script paths were not
changed by this feature. The expected protected scan command is:

```sh
git diff --name-only -- src tests fixtures/expected build.zig build.zig.zon tools/validate.sh
```

The expected result is no output. The feature also keeps `.gitmodules` and
`build.zig.zon` absent, and uses ordinary tracked files rather than submodules.

## Close-out smoke privacy

The close-out smoke command uses a local operator-supplied repository and the
privacy-safe label `sibling-local-repo`. Committed evidence intentionally omits
the absolute sibling path, private repository name, raw private report output,
author identities, source snippets, remotes, and commit messages.
