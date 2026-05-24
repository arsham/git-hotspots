# Tree-sitter Go offline build proof

This is the Feature 0037 execution evidence for the non-product Go parser build
proof. It compiles the already-vendored Tree-sitter core and tree-sitter-go
parser sources through the Zig build graph, runs a tiny in-memory Go parse, and
stops before any Go provider runtime or symbol extraction behavior.

## Scope and protected surfaces

Changed implementation surfaces are limited to:

- `build.zig`: explicit `tree-sitter-go-build-proof` build step.
- `tests/tree_sitter_go_build_proof.zig`: tiny non-product proof executable.
- `.github/workflows/ci.yml`: CI invocation for the proof step.

The proof does not change CLI/report/schema/scoring/cache behavior, provider
registration, fixture expected outputs, runtime defaults, external reporting,
network enrichment, or background analysis. It does not add package manifests,
submodules, generated parser regeneration, a system Tree-sitter package, a C
package-discovery dependency, or a global Tree-sitter CLI dependency.

Protected-surface scan:

```sh
git diff --name-only -- src fixtures/expected tools/validate.sh build.zig.zon .gitmodules
```

Observed result: no output.

## Proof entry point

The dedicated proof step is:

```sh
zig build tree-sitter-go-build-proof
```

It compiles and links these C inputs only for the proof executable:

- `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`
- `third_party/tree-sitter-go/v0.25.0/src/parser.c`

It uses these include paths:

- `third_party/tree-sitter-core/v0.26.9/lib/include`
- `third_party/tree-sitter-go/v0.25.0/src`

The proof executable parses the in-memory source
`package main\nfunc main() {}\n` and asserts that the root node is
`source_file`. It is not installed by the normal product build and is not wired
into the CLI or provider registry.

## CI membership

CI now runs the proof explicitly after the existing validation and Zig
Tree-sitter proof steps:

```sh
zig build tree-sitter-go-build-proof
```

The proof remains separate from `zig build validate` so the canonical validation
path continues to exercise the product CLI and no-provider behavior, while CI
and close-out evidence still require the offline Go parser compile/link smoke.

## Offline compile/link evidence

Local environment:

- Zig version: `0.16.0`.
- Local target: `x86_64-linux.7.0.9...7.0.9-gnu.2.43`.

Fresh isolated-cache measurement:

- Command: `zig build --cache-dir <tmp>/cache --global-cache-dir <tmp>/global
  tree-sitter-go-build-proof`
- Exit status: `0`.
- Elapsed wall-clock time: `4684` ms.
- Proof executable size in the isolated Zig cache: `15121144` bytes.
- Sanitised output observation: no stdout or stderr were emitted.

Cached repo-local proof command:

- Command: `zig build tree-sitter-go-build-proof`.
- Exit status: `0`.
- Sanitised output observation: no stdout or stderr were emitted.

Result: no duplicate-symbol, missing-symbol, compile, or link failure was
observed for the Tree-sitter core `lib.c` single-translation-unit path linked
with the vendored Go parser. If this later needs an individual-file compile set,
parser generation, package-manager fetch, system package, network access, or Go
provider semantics, execution must stop for planning instead of broadening the
proof locally.

## No-provider byte-stability evidence

Representative product outputs were regenerated with the current binary and
matched the existing fixture expectations for JSON, Markdown, and inspect JSON.
The table output retained the existing stable digest from the no-provider proof
set.

| Output | Check | SHA-256 |
| --- | --- | --- |
| Basic table | Stable digest | `a5e76af80689af6cd365c22bf37aa5a04f6173c6147ba2de076f9005cbf3c02a` |
| Basic JSON | `cmp` against `fixtures/expected/basic.json` | `3437fc55042e9725d97e76652d97397a0f0fb724a6510b5d670003c632018fb3` |
| Basic Markdown | `cmp` against `fixtures/expected/basic.md` | `987dffcbf88e2bc081c4cd0b593b1724dde1041e29da0f5a0329cc8c62b12f75` |
| Basic inspect JSON | `cmp` against `fixtures/expected/basic-inspect.json` | `96495ca536a5c6019192eeb27f4b2abd9ac67a8f36b6483f7ac745382a73d292` |

This proof exercises product output only through existing fixture commands. The
Go parser proof step is separate and does not affect scoring, report rendering,
inspect semantics, current-symbol enrichment, or cache behavior.

## Validation ladder summary

| Command summary | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `zig fmt --check build.zig src tests` | `0` | Owned Zig files were formatted. |
| `zig build tree-sitter-build-proof` | `0` | Existing Zig parser proof still compiled, linked, and ran. |
| `zig build tree-sitter-symbol-proof` | `0` | Existing Zig symbol proof still passed. |
| `zig build tree-sitter-go-build-proof` | `0` | Go parser proof compiled, linked, and ran with no stdout/stderr. |
| `git diff --check` | `0` | No whitespace errors were reported. |
| `zig build test` | `0` | Unit and integration tests passed. |
| `zig build` | `0` | Normal product build completed without installing the proof executable. |
| `zig build validate` | `0` | Default validation rungs passed, including this-repo smoke. |
| `zig build validate -Dcloseout=true ... -Dsmoke-label=sibling-local-repo` | `0` | Close-out validation passed; sibling evidence used only the `sibling-local-repo` label. |

The close-out validation summary reported `PASS` for every rung, including real
repo smoke `this-repo` and real repo smoke `sibling-local-repo`. Its emitted
privacy statement said summaries use labels and bounded counts only, with raw
reports and absolute private paths omitted.

## Privacy and local-first evidence

Committed evidence intentionally omits the absolute sibling path, private repo
identity, raw sibling output, private person identities, source snippets, remote
URLs, and private history text. Validation reported local-only behavior: no
network transfer, external reporting, CI service dependency, default provider
runtime, cache requirement, packaging, or release automation.

A prohibited dependency and claim scan over the changed build, CI, proof, and
documentation surfaces found no new fetch/download tooling, parser generation,
submodules, system parser-package dependency, external reporting additions,
commercial strategy language, or unsupported behavioral and people-metric
claims.
