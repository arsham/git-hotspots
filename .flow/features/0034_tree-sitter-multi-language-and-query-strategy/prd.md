# Tree-sitter multi-language and query strategy

## Purpose

Define how `git-hotspots` should expand from the current Zig-only Tree-sitter
symbol provider to additional languages and, later, user-provided queries.

This is a design-only feature. It must not add parser runtime, grammar sources,
build changes, CLI flags, report schema changes, provider registry behaviour,
repo-wide parsing, cache, LSP integration, or custom query execution.

The goal is to make the next language provider feature small and safe rather
than creating a broad parser framework by momentum.

## Requirements

1. Add one strategy document at
   `docs/tree-sitter-multi-language-query-strategy.md`.
2. The document must state that current runtime Tree-sitter support remains
   Zig-only unless later features implement and validate more languages.
3. The document must state that file-level Git evidence remains product truth
   and provider evidence is optional, additive, current-only, and caveated.
4. The document must cover the requested language set: Go, Python, Lua,
   JavaScript, TypeScript, Rust, and Node as JavaScript or TypeScript runtime
   context.
5. The document must define language admission criteria before a language can
   be implemented.
6. Language admission criteria must include pinned local grammar sources,
   license and notice review, provenance, offline build proof, source-size and
   build-impact evidence, query fixtures, and no-provider output stability.
7. The document must define a static built-in language registry concept without
   implementing one.
8. The registry concept must include language id, file extensions, special file
   names when needed, grammar component identity, parser symbol, built-in query
   version, supported symbol kinds, caveats, and validation status.
9. Language detection must be deterministic for the requested inspect path and
   must not imply repo-wide package or workspace discovery.
10. Monorepo guidance must remain inspect-only and path-based by default.
11. Monorepo examples must use project-relative paths and existing supported
    options such as `--include-prefix`, `--scope project`, `--scope all`,
    `--inspect`, `--symbols`, and `--symbol-line-history`.
12. Monorepo guidance must not imply hidden workspace auto-discovery,
    package-manager analysis, dependency graph inference, or repo-wide provider
    scanning.
13. Built-in symbol queries must be project-owned curated queries rather than
    blindly imported highlight queries.
14. Built-in queries must define capture names, symbol-kind mapping, range
    semantics, deterministic ordering, versioning, and fixture coverage.
15. The document must define common symbol kinds across languages while allowing
    language-specific caveats.
16. The document must define provider failure states for unsupported language,
    unavailable grammar, query compile failure, parse failure, partial parse,
    timeout or limit exceeded, zero symbols, and skipped provider execution.
17. Failure states must preserve file-level hotspot output and appear as visible
    provider caveats when provider output is requested.
18. Custom user query execution must be explicitly deferred.
19. The document must define the minimum future safety contract for custom
    queries if a later feature accepts them.
20. The future custom-query safety contract must include explicit opt-in, local
    repo-relative query file paths, size and time limits, accepted capture names
    only, sanitized diagnostics, deterministic failure states, no raw source
    output, and a provider configuration fingerprint.
21. The document must recommend a future sequencing path that adds one language
    at a time.
22. The recommended first non-Zig language should be justified. Go or Python may
    be recommended, but the reason must be explicit.
23. JavaScript and TypeScript strategy must treat Node as runtime context, not a
    separate language provider.
24. The document must defer LSP integration and explain that LSP is a later
    provider class, not part of Tree-sitter language expansion.
25. The document must not claim runtime support for languages that are not yet
    implemented.
26. The document must not add or require network, telemetry, upload, remote
    enrichment, auto-fetch, background provider execution, package-manager
    calls, or global parser tooling.
27. The document must not contain commercial, SaaS, pricing, sales, or hosted
    product strategy.
28. The document must not contain positive claims that hotspots or provider
    symbols predict bugs, rate code quality, score risk, rank developers, judge
    maintainers, assess ownership, or measure productivity.
29. The feature must not change `src/`, `tests/`, `fixtures/`, `third_party/`,
    `build.zig`, `build.zig.zon`, `.github/`, report schemas, CLI flags,
    scoring, cache, runtime provider behaviour, or release/package artefacts.
30. The feature must preserve the current Zig inspect-only provider behaviour.

## Acceptance

- `docs/tree-sitter-multi-language-query-strategy.md` exists and is
  public-facing.
- The document is concrete enough to shape the next one-language provider
  feature without relying on this conversation.
- The document clearly says multi-language support and custom query execution
  are future work until implemented and validated by separate features.
- The language sequencing, language admission criteria, built-in query contract,
  custom-query deferral, monorepo guidance, failure states, and validation gates
  are all present.
- Changed paths are limited to the strategy document and Flow planning or
  lifecycle artefacts.
- `git diff --check` passes.
- `zig build validate` passes.
- Content scans find no private paths, raw private reports, remotes, author
  identities, source snippets, parser stderr, commercial strategy, or prohibited
  positive quality/risk/people claims.

## Edge cases

- If the strategy needs a parser import or build change to be credible, stop and
  reshape. Do not add runtime sources in this feature.
- If language sequencing depends on unresolved legal or provenance facts, record
  those as future admission gates rather than guessing.
- If custom queries appear necessary for the next language, defer custom query
  execution and shape a future query-safety feature first.
- If monorepo examples need package-manager, workspace, or dependency analysis,
  stop and keep them out of this feature.
- If the document mentions a language that is not implemented, it must use
  future-tense strategy language and not claim support.
- If reviewer evidence finds a public claim that implies bug prediction,
  code-quality scoring, risk scoring, developer ranking, ownership, or
  productivity analysis, fix the wording before close-out.

## Verification

Run the normal validation gate:

```sh
zig build validate
```

Run whitespace validation:

```sh
git diff --check
```

Verify changed-path scope. The delivery commit should change only:

```text
docs/tree-sitter-multi-language-query-strategy.md
```

plus Flow lifecycle metadata when closing the feature. It must not change
runtime, source, tests, fixtures, third-party sources, build files, workflow
files, report schemas, CLI flags, scoring, cache, provider runtime, or release
artefacts.

Run a docs content scan over the changed strategy document. It must prove:

- the current runtime language remains Zig-only;
- Go, Python, Lua, JavaScript, TypeScript, Rust, and Node-as-runtime-context are
  covered;
- custom query execution is deferred;
- future custom-query safety contract terms are present;
- monorepo examples use project-relative paths and existing supported options;
- no unsupported language support claims appear;
- no network, telemetry, upload, remote enrichment, auto-fetch, global parser
  tooling, package-manager execution, or background provider behaviour is
  introduced;
- no absolute local paths, remotes, source snippets, parser stderr, raw private
  reports, author identities, private repo names, commercial/SaaS/pricing/sales
  strategy, or prohibited positive bug/quality/risk/people claims appear.

Close-out evidence should record command exits, changed-path scope, scan summary,
and clean post-commit status. It must not commit or print private raw report
output.
