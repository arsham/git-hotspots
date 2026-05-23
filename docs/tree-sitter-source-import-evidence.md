# Tree-sitter source import evidence

This is the Feature 0025 execution evidence for the non-runtime source import. It
records repo-relative source identity, local source-size measurements, offline
validation, a non-product compile proof, and no-provider byte stability. It adds
no parser runtime, provider registry, CLI/report/schema/scoring/cache change,
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
zig build validate -Dcloseout=true -Dsmoke-repo <local-sibling-path> -Dsmoke-label sibling-local-repo
```

The proof step intentionally remains separate from `zig build validate`. The
reason is that it compiles non-product vendored C parser sources only for this
import gate, while the canonical validation path continues to exercise the
installed CLI and no-provider product behavior. Close-out still treats
`zig build tree-sitter-build-proof` as mandatory and records explicit proof that
it ran.

Observed timing evidence:

- Before import: pass, `real 8.76`, `user 7.24`, `sys 3.95`.
- After import: pass, `real 9.46`, `user 7.79`, `sys 4.34`.
- Execute close-out rerun after the proof step: pass, including the
  `sibling-local-repo` smoke label.

Fresh validation ladder summary from the Feature 0026 repair pass:

| Command summary | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `zig fmt --check build.zig src tests` | `0` | Owned Zig files were already formatted; vendored C/generated files were not reformatted. |
| `zig build test` | `0` | Unit and integration tests passed with local fixtures. |
| `zig build` | `0` | Normal product build completed without installing the proof executable. |
| `zig build validate` | `0` | All default validation rungs passed, including no-provider fixture and this-repo smoke checks. |
| `zig build tree-sitter-build-proof` | `0` | Explicit proof target compiled, linked, and ran with no stdout or stderr. |
| `git diff --check` | `0` | No whitespace errors were reported. |
| `zig build validate -Dcloseout=true -Dsmoke-repo <local-sibling-path> -Dsmoke-label sibling-local-repo` | `0` | Close-out validation passed; sibling evidence used only the `sibling-local-repo` label. |

The close-out validation summary reported `PASS` for every rung, including real
repo smoke `this-repo` and real repo smoke `sibling-local-repo`. Its emitted
privacy statement said summaries use labels and bounded counts only, with raw
reports and absolute private paths omitted.

Validation reported local-only behavior: no fetch, pull, push, upload,
telemetry, remote enrichment, CI service, provider runtime, cache requirement,
packaging, or release automation.

## Non-product compile proof

The dedicated proof step compiles the imported Tree-sitter C runtime and Zig
grammar parser with a tiny Zig executable, runs one in-memory parse of
`const x = 1;`, and asserts that the root node is `source_file`. The proof is
not installed by the normal product build, is not wired into the CLI, and does
not add provider runtime, parser registry, report schema, scoring, cache, or
network behavior.

Proof entry points:

- `zig build tree-sitter-build-proof`
- `build.zig` step: `tree-sitter-build-proof`
- Zig proof source: `tests/tree_sitter_build_proof.zig`
- C inputs:
  - `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`
  - `third_party/tree-sitter-zig/v1.1.2/src/parser.c`
- Include paths:
  - `third_party/tree-sitter-core/v0.26.9/lib/include`
  - `third_party/tree-sitter-zig/v1.1.2/src`
- Zig version: `0.16.0`.
- Local target: `x86_64-linux.7.0.9...7.0.9-gnu.2.43`.

Fresh isolated-cache measurement:

- Command: `zig build --cache-dir <tmp>/cache --global-cache-dir <tmp>/global tree-sitter-build-proof`
- Result: pass.
- Elapsed wall-clock time: `5439` ms.
- Proof executable size in the isolated Zig cache: `16964216` bytes.
- Target from local `zig env`: `x86_64-linux.7.0.9...7.0.9-gnu.2.43`.

Cached repo-local proof measurement:

- Command: `zig build tree-sitter-build-proof`
- Result: pass.
- Elapsed wall-clock time: `70` ms.
- Existing cached proof executable size: `16960117` bytes.

Single translation unit compile/link cleanliness proof:

- The proof step passes `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c` to
  Zig as one C source file. That file includes the selected Tree-sitter runtime
  implementation units and is linked together with the Zig grammar
  `parser.c`.
- Command summary: `zig build tree-sitter-build-proof`.
- Exit status: `0`.
- Sanitised output observation: no stdout and no stderr were emitted.
- Result: no duplicate-symbol, missing-symbol, compile, or link failure was
  observed for the `lib.c` single-translation-unit path.
- Stop condition: if this command later emits duplicate/missing symbols or
  requires an individual-file compile set, system package, package manager,
  network access, parser generation, or provider runtime semantics, this proof
  must stop for planning rather than broadening locally.

Platform caveat:

- This proof is recorded for the local Zig `0.16.0` target shown above. No
  broader platform matrix is claimed. Cross-platform or Windows-specific
  failures should be recorded as a later portability follow-up unless they
  block the current supported local target.

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

Protected runtime, fixture, expected-output, package-manifest, validation script,
provider, scoring, report, and CLI paths were not changed by this feature. The
build graph change is limited to the explicit non-product proof step, and the
test path change is limited to the proof executable source. The expected
protected scan command is:

```sh
git diff --name-only -- src fixtures/expected build.zig.zon tools/validate.sh
```

The expected result is no output. The feature also keeps `.gitmodules` and
`build.zig.zon` absent, and uses ordinary tracked files rather than submodules.

## Close-out smoke privacy

The close-out smoke command uses a local operator-supplied repository and the
privacy-safe label `sibling-local-repo`. Committed evidence intentionally omits
the absolute sibling path, private repository name, raw private report output,
author identities, source snippets, remotes, and commit messages.

## Feature 0026 close-out evidence set

- Build proof transcript summary: `zig build tree-sitter-build-proof`, exit
  status `0`, no stdout/stderr, proof source and C inputs listed above.
- Default validation summary: `zig build validate`, exit status `0`, all rungs
  passed.
- Close-out smoke summary: `zig build validate -Dcloseout=true ...
  -Dsmoke-label sibling-local-repo`, exit status `0`, all rungs passed,
  sibling evidence labelled only `sibling-local-repo`.
- No-provider parity result: representative table, JSON, Markdown, and inspect
  outputs matched byte-for-byte; stable digests are listed above.
- Changed-path/protected-surface proof: protected runtime, fixture,
  expected-output, package-manifest, validation script, provider, scoring,
  report, and CLI paths were not changed by the proof repair.
- Local-only/offline scan result: no `build.zig.zon`, package manager,
  pkg-config, submodule, system Tree-sitter package, global Tree-sitter CLI,
  parser generation, build-time download, telemetry, upload, remote enrichment,
  or background analysis was introduced.
- Privacy/prohibited-claim scan result: committed evidence uses repo-relative
  paths and public upstream component identifiers only; it omits private paths,
  private repo names, raw sibling output, raw parser stderr, author identities,
  commercial strategy, bug-prediction claims, quality scoring, developer
  ranking, and maintainer judgement.
