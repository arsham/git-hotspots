# Tree-sitter JavaScript offline build proof

This is the Feature 0051 evidence for a non-product JavaScript parser build
proof. It compiles only repository-local vendored Tree-sitter core sources plus
vendored `tree-sitter-javascript` parser/scanner sources, parses tiny in-memory
JavaScript and JSX snippets, and does not add JavaScript runtime provider
behaviour.

## Proof target

- Dedicated command: `zig build tree-sitter-javascript-build-proof`.
- Zig version observed during proof: `0.16.0`.
- Local target observed during proof:
  `x86_64-linux.7.0.9...7.0.9-gnu.2.43`.
- Build target kind: `build.zig` non-installed executable proof target.
- Proof source: `tests/tree_sitter_javascript_build_proof.zig`.

The target is not added to `addTreeSitterProviders`, the product executable, the
provider registry, CLI/report/schema code, scoring, cache, fixtures, or runtime
output paths.

## Local source inputs

Tree-sitter core input:

- `third_party/tree-sitter-core/v0.26.9/lib/include`
- `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`

JavaScript grammar input:

- Include path: `third_party/tree-sitter-javascript/v0.25.0/src`
- Parser source:
  `third_party/tree-sitter-javascript/v0.25.0/src/parser.c`
- Scanner source:
  `third_party/tree-sitter-javascript/v0.25.0/src/scanner.c`
- Scanner helper header:
  `third_party/tree-sitter-javascript/v0.25.0/src/tree_sitter/parser.h`

Observed vendored source sizes:

| File | Bytes |
| --- | ---: |
| `third_party/tree-sitter-javascript/v0.25.0/src/parser.c` | 2855934 |
| `third_party/tree-sitter-javascript/v0.25.0/src/scanner.c` | 10576 |
| `third_party/tree-sitter-javascript/v0.25.0/src/tree_sitter/parser.h` | 7624 |

The scanner is compiled from the already-vendored `scanner.c` and uses the
narrow local include path above. No parser generation is run.

## Parse evidence

The proof creates a Tree-sitter parser, assigns `tree_sitter_javascript()`, and
asserts stable parse behaviour for:

- JavaScript: `function proof() { return 1; }` parses with root `program`, no
  parse errors, one named child, and child kind `function_declaration`.
- JSX: `const view = <main id="proof">ok</main>;` parses with root `program`,
  no parse errors, one named child, and child kind `lexical_declaration`.

JSX was admitted as source evidence by Feature 0050, so this proof records JSX
parse evidence rather than deferral. TypeScript and TSX remain unsupported and
are not compiled or parsed.

## CI decision

The public CI workflow includes `zig build tree-sitter-javascript-build-proof`
after repository checkout and Zig setup. The step uses only repository-local
vendored sources and does not add artifacts, caches, secrets, package-manager
steps, release automation, or network access beyond normal checkout/Zig setup.

## Validation evidence

Observed commands and outcomes:

| Command | Outcome | Notes |
| --- | --- | --- |
| `zig build tree-sitter-javascript-build-proof` | PASS | Timed proof run: `real 0.09`, `user 0.05`, `sys 0.04`. |
| `zig fmt --check build.zig src tests` | PASS | Formatting check passed. |
| `zig build validate` | PASS | Default validation passed all rungs, including `zig build test`, `zig build`, deterministic fixture JSON/Markdown, prohibited-claim scan, runtime dependency scan, source-install smoke, and real-repo smoke label `this-repo`. |
| `zig build tree-sitter-build-proof` | PASS | Existing Zig parser build proof preserved. |
| `zig build tree-sitter-symbol-proof` | PASS | Existing Zig symbol proof preserved. |
| `zig build tree-sitter-go-build-proof` | PASS | Existing Go parser build proof preserved. |
| `zig build tree-sitter-go-symbol-proof` | PASS | Existing Go symbol proof preserved. |
| `zig build tree-sitter-python-build-proof` | PASS | Existing Python parser build proof preserved. |
| `zig build tree-sitter-python-symbol-proof` | PASS | Existing Python symbol proof preserved. |
| `git diff --check` | PASS | No whitespace errors. |
| `zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo` | PASS | Close-out validation passed all rungs with labels `this-repo` and `sibling-local-repo`; raw private paths and reports were not printed. |

## Protected-surface and dependency scans

Changed paths are limited to the build proof, its test source, public evidence,
and the CI proof step:

- `.github/workflows/ci.yml`
- `build.zig`
- `docs/tree-sitter-javascript-offline-build-proof.md`
- `tests/tree_sitter_javascript_build_proof.zig`

A protected runtime/report scan over `src`, `fixtures`, `tools/validate.sh`, and
`build.zig.zon` reported no changed paths. No provider runtime source, CLI,
report/schema, scoring, cache, fixture, query, TypeScript/TSX, Node, package
workspace, module analysis, package-manager, release, or product install shape
changes are included.

A prohibited dependency scan over changed build/test/CI files reported no use of
`npm`, `npx`, `pnpm`, `yarn`, `curl`, `wget`, `git clone`, `git fetch`,
`git pull`, submodules, `pkg-config`, telemetry, upload, or remote enrichment.
`build.zig.zon` and `.gitmodules` remain absent.

## Output stability

No JavaScript provider runtime output is added. The default `zig build validate`
run passed deterministic fixture JSON/Markdown checks, explain golden and
standalone checks, runtime dependency scan, and source-install smoke. Close-out
validation passed table, JSON, and Markdown no-provider smoke checks for labels
`this-repo` and `sibling-local-repo` using bounded counts only.

## Non-runtime boundary

This proof is intentionally limited to offline compilation and tiny parse
smokes. It does not implement JavaScript symbol extraction, JavaScript query
contracts or fixtures, inspect-only JavaScript output, provider registration,
CLI flags, report/schema changes, scoring, cache changes, package/workspace or
module analysis, parser generation, TypeScript/TSX support, network access,
telemetry, upload, remote enrichment, or background JavaScript analysis.
