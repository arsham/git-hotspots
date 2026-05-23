# Feature 0021: Provider symbol evidence seam

## Problem

The provider contract is documented, but the runtime has no minimal internal seam for optional provider evidence. Jumping directly to a tree-sitter Zig dependency would combine dependency/build risk, report-shape decisions, symbol modelling, and parser correctness in one feature.

We need a small implementation boundary that turns the provider contract into safe internal Zig model primitives before the first real provider is wired in.

## Outcome

Add a minimal provider/symbol evidence seam that can be used by a later tree-sitter Zig spike, while keeping current CLI behaviour and file-level Git-history reports unchanged when no provider evidence exists.

## Requirements

### R1: Provider evidence model

Add a minimal internal provider evidence model aligned with `docs/provider-symbol-evidence-contract.md`.

The model should represent at least:

- provider name;
- provider kind;
- provider version;
- provider contract version;
- configuration fingerprint when relevant;
- analysed local input identity such as repository `HEAD` or input digest;
- freshness state;
- failure state;
- provider confidence;
- caveats;
- local-only provenance.

The model must use repo-relative paths and bounded metadata. It must not require absolute paths, remote URLs, author identities, source snippets, raw parser stderr, raw private reports, or network-derived provenance.

### R2: Current symbol evidence model

Add a minimal internal current-symbol evidence shape for future symbol providers.

The model should represent at least:

- repo-relative file path;
- symbol name;
- symbol kind;
- current line or byte range;
- provider envelope reference or association;
- provider confidence;
- caveats.

Symbol evidence is current working-tree evidence only. It must not imply historical symbol lineage, symbol renames, symbol moves, ownership, dependency propagation, or code-quality judgement.

### R3: Deterministic helpers and synthetic tests

Add deterministic helper behaviour and unit tests using synthetic in-memory evidence, not a real parser.

Tests should cover:

- deterministic provider and symbol ordering;
- accepted freshness/failure/confidence states;
- repo-relative path validation or rejection for unsafe absolute/parent/control paths;
- caveat storage/order;
- current-only semantics;
- no source snippets or private machine paths in model stringification or test-visible diagnostics.

### R4: No provider runtime yet

This feature must not add a tree-sitter dependency, grammar source, C build/linking, provider registry, plugin lifecycle, CLI flags, configuration files, report schema changes, cache, scoring changes, ranking changes, network access, telemetry, or background analysis.

Current file-level table, JSON, and Markdown output must remain unchanged for normal no-provider runs.

### R5: Documentation update

Update provider documentation only as needed to map the design contract to the internal seam and to name the next tree-sitter Zig spike boundary.

Documentation must keep file-level Git evidence as product truth and providers as optional enrichment.

### R6: Validation and close-out

Validation must prove:

- `zig build test` passes;
- `zig build validate` passes;
- existing table/JSON/Markdown fixture goldens are unchanged unless the feature explicitly and narrowly justifies a non-output-affecting update;
- no forbidden runtime provider/dependency/CLI/report/scoring/cache/network behaviour was added;
- close-out real-repo validation follows the existing privacy-safe sibling smoke pattern when available;
- repository artefacts remain OSS/publicity-oriented and avoid hosted/pricing/sales/commercial strategy and overclaiming.

## Edge cases

- Provider unavailable, unsupported, failed, timed out, skipped, stale, partial, and unknown states should be representable even if no runtime provider uses them yet.
- Symbol evidence should allow files with no symbols, invalid future parser output, and unsupported language rows to degrade to file-level evidence.
- Paths with spaces, unicode, tab-like escaped text, markdown metacharacters, or glob-like characters should remain bounded metadata and not become path traversal.
- The seam must not force future tree-sitter to use system dependencies, network fetches, or global provider state.

## Verification notes

Reviewer should reject close-out if this feature:

- adds a real tree-sitter dependency or parser runtime;
- changes default CLI output or report schema;
- changes score/rank/confidence semantics for file hotspots;
- makes provider evidence mandatory for useful reports;
- stores source snippets, absolute paths, remotes, author identities, raw parser stderr, or raw private report output;
- implies current symbol evidence exists in the CLI today.
