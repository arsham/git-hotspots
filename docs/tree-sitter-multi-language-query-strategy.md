# Tree-sitter multi-language and query strategy

This is a design-only strategy for future Tree-sitter language expansion and
query support. It does not add runtime support, parser sources, grammar imports,
build changes, provider registry work, CLI flags, report fields, scoring
changes, cache behaviour, network access, telemetry, upload, remote enrichment,
or background provider execution.

Current runtime Tree-sitter support remains Zig-only unless later features
implement and validate more languages. File-level Git evidence remains the
product truth. Provider evidence is optional, additive, current-only, caveated,
and used only to explain local evidence when explicitly requested by a future
inspect-oriented flow.

## Scope and non-goals

This strategy covers future admission for Go, Python, Lua, JavaScript,
TypeScript, Rust, and Node as JavaScript or TypeScript runtime context. It also
sets gates for future grammars that are not listed here.

This strategy does not implement multi-language parsing or custom query
execution. It does not introduce repo-wide provider scanning, workspace
auto-discovery, package-manager analysis, dependency graph inference, LSP
integration, global parser tooling, or hidden provider execution.

## Language priority

The recommended first non-Zig language is Go. Go is a good first expansion
candidate because file extensions are simple, common symbol shapes are stable,
and fixtures can cover packages, functions, methods, interfaces, structs, and
invalid or partial files without package-manager calls.

Python is the next candidate after Go because it has broad user value and a
single common extension, but indentation-sensitive parsing and dynamic module
patterns need extra fixture coverage before runtime work.

Lua, JavaScript, TypeScript, and Rust should follow only after the same gates are
met. JavaScript and TypeScript must treat Node as runtime context, not as a
separate language provider. Node-specific guidance may explain how future users
inspect `.js`, `.mjs`, `.cjs`, `.ts`, `.tsx`, or package-adjacent paths, but it
must not create a `node` parser identity.

## Language admission criteria

A future language can be implemented only after its feature records all of these
items:

- pinned local grammar sources and pinned Tree-sitter core inputs;
- license and notice review for every parser and generated source input;
- generated-source provenance, including exact upstream revision labels;
- offline build proof with no network fetches or global parser packages;
- source-size and build-impact evidence for the added local inputs;
- query fixtures for supported symbol kinds and known language caveats;
- no-provider output stability for table, JSON, and Markdown reports;
- deterministic output for the same repo, ref, file path, config, and provider
  version;
- privacy-safe diagnostics that do not expose absolute paths, unsanitized
  parser diagnostics, source text, or private report output;
- visible failure and caveat behaviour for unavailable, unsupported, failed,
  partial, timed-out, empty, and skipped provider states.

If any legal, provenance, offline-build, source-size, fixture, or stability fact
is unresolved, record it as a future admission gate instead of guessing.

## Static built-in language registry concept

A later runtime feature may add a static built-in language registry. This
feature does not implement that registry. The registry should be compile-time or
otherwise fixed by the shipped binary so that provider behaviour is deterministic
and local.

Each future registry entry should include:

- language id, such as `zig`, `go`, `python`, `lua`, `javascript`,
  `typescript`, or `rust`;
- file extensions;
- special file names when a language needs them;
- grammar component identity;
- parser symbol;
- built-in query version;
- supported symbol kinds;
- language caveats;
- validation status.

The registry must not fetch parsers, discover packages, inspect package-manager
metadata, or scan a repository on its own.

## Deterministic language detection

Language detection should be path-based for the requested inspect path. It
should use the static registry entry for the file extension or special file name
and then either run the matching built-in provider or return a visible caveat.

Detection must not imply repo-wide package or workspace discovery. A request to
inspect `src/app.ts` should resolve that path as TypeScript because of its path,
not because a package manager, workspace manifest, or dependency graph was
analysed.

Ambiguous paths should fail closed with an unsupported-language or ambiguous-path
caveat. Future features may add explicit operator controls for ambiguity, but
those controls must remain local and deterministic.

## Built-in query ownership and requirements

Built-in symbol queries are project-owned curated queries. They must not be
blind imports of upstream highlight queries. Highlight queries are useful
reference material, but symbol extraction needs a smaller contract with stable
captures and report semantics.

Every built-in query version must define:

- accepted capture names;
- mapping from captures to common symbol kinds;
- range semantics, such as name range, declaration range, or enclosing node
  range;
- deterministic ordering for symbols with overlapping or equal ranges;
- query version and provider version metadata;
- fixture coverage for successful, partial, invalid, unsupported, generated, and
  empty files.

Changing a built-in query in a way that changes output requires a new query
version and fresh validation evidence.

## Capture schema and symbol-kind mapping

Future Tree-sitter symbol queries should use a small capture schema:

- `@symbol.name` for the display name when a stable name exists;
- `@symbol.definition` for the node that defines the symbol range;
- `@symbol.container` for an optional enclosing type, module, or namespace;
- `@symbol.visibility` for optional language visibility when it is stable;
- `@symbol.modifier` for optional language modifiers when they are stable.

Common symbol kinds should include `function`, `method`, `type`, `class`,
`interface`, `module`, `namespace`, `variable`, `constant`, `field`, and
`other`. A language may map unavailable or ambiguous constructs to `other` with
a visible caveat. Language-specific kinds can be proposed later only if a common
kind loses necessary meaning for inspect output.

## Requested language notes

| Language | Future path rule | Initial symbol focus | Caveats to prove |
| --- | --- | --- | --- |
| Go | `.go` | packages, functions, methods, structs, interfaces, constants, variables | generated files, build tags, cgo-adjacent files, invalid partial files |
| Python | `.py` | modules, classes, functions, methods, constants | indentation errors, decorators, nested definitions, dynamic assignments |
| Lua | `.lua` | modules, functions, table-style methods, local variables | table conventions, anonymous functions, dialect differences |
| JavaScript | `.js`, `.mjs`, `.cjs`, `.jsx` | functions, classes, methods, constants, exported values | module style, JSX, anonymous exports, generated bundles |
| TypeScript | `.ts`, `.tsx`, `.mts`, `.cts` | functions, classes, methods, interfaces, types, enums | type-only constructs, decorators, JSX, declaration files |
| Rust | `.rs` | modules, functions, methods, structs, enums, traits, impl blocks | macros, generated code, nested modules, partial files |
| Node context | JavaScript or TypeScript paths | no separate provider | runtime context only; no `node` language id |

These are future strategy notes, not runtime support claims.

## Monorepo inspect guidance

Monorepo behaviour stays inspect-only and path-based by default. Future provider
execution should run only for requested inspect paths or for files already chosen
by an explicit inspect flow. It must not scan every package in a repository.

Examples should use project-relative paths and existing supported options:

```sh
git-hotspots --include-prefix packages/api --scope project --inspect packages/api/src/server.go --symbols
git-hotspots --scope all --inspect crates/core/src/lib.rs --symbol-line-history
git-hotspots --include-prefix apps/web --scope project --inspect apps/web/src/app.ts --symbols
```

These examples describe future Tree-sitter language behaviour only after the
specific language provider exists. They do not imply hidden workspace discovery,
package-manager calls, dependency graph inference, or repo-wide provider
scanning.

## Provider failure states

Future provider output should preserve file-level hotspot output for every
failure state. When provider output is requested, the state should be visible as
a provider caveat.

Required states:

- `unsupported_language`: no built-in language entry matches the inspect path;
- `unavailable_grammar`: the language is admitted by strategy but the shipped
  provider cannot load its local grammar component;
- `query_compile_failure`: the built-in query version cannot compile;
- `parse_failure`: parsing failed before useful symbols were available;
- `partial_parse`: symbols may be incomplete because the parser reported an
  incomplete or error-containing tree;
- `timeout_or_limit_exceeded`: bounded runtime, file size, symbol count, or
  memory limits stopped provider execution;
- `zero_symbols`: the provider ran but emitted no symbols;
- `skipped_provider_execution`: provider execution was not requested or was
  intentionally disabled.

None of these states may hide or rewrite file-level Git evidence.

## Validation gates for a future language

A future one-language provider feature should validate at least:

- `git diff --check`;
- `zig build validate`;
- fixture coverage for accepted captures and symbol-kind mappings;
- deterministic ordering for repeated runs;
- no-provider output stability;
- failure-state visibility;
- privacy-safe diagnostics and caveats;
- local-first behaviour with no network, telemetry, upload, remote enrichment,
  auto-fetch, package-manager execution, global parser tooling, or background
  provider execution;
- documentation that names the language as implemented only after the runtime
  feature actually ships.

## Custom user queries are deferred

Custom user query execution is deferred. It should remain unavailable unless a
later feature accepts and validates a safe local-only contract. In short,
custom user query execution is deferred until that separate contract exists.

The minimum future custom-query safety contract should include:

- explicit opt-in;
- local repo-relative query file paths;
- query file size limits;
- provider runtime limits;
- accepted capture names only;
- sanitized diagnostics;
- deterministic failure states;
- no raw source output;
- provider configuration fingerprint included in the provider envelope.

If a future language appears to need custom queries before it can be useful,
shape a separate query-safety feature first instead of adding custom execution
to the language provider.

## LSP deferral

LSP integration is deferred. LSP is a later provider class with different
availability, configuration, workspace, and diagnostic semantics. It is not part
of Tree-sitter language expansion and should not be used to justify admitting a
Tree-sitter grammar.

## Future sequencing

Future work should add one language at a time:

1. Record the language admission evidence.
2. Add pinned local parser and grammar inputs only after license and notice
   review.
3. Add one static registry entry and one built-in query version.
4. Validate fixtures, deterministic ordering, failure states, no-provider
   stability, and local-first behaviour.
5. Keep provider output inspect-only, current-only, optional, additive,
   caveated, and separate from file-level Git evidence.
6. Update this strategy or the provider contract only when evidence from the
   one-language feature shows a contract gap.

Future grammars outside the requested set must pass the same admission gates and
must not claim runtime support until their own implementation and validation
feature closes.
