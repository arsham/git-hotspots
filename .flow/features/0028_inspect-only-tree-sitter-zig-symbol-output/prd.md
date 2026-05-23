# Feature 0028: Inspect-only Tree-sitter Zig symbol output

## Problem

The project has proven pinned vendored Tree-sitter sources, an offline build
proof, and an internal Zig current-symbol extraction proof. Users still cannot
ask why an inspected hot Zig file is interesting at the current-symbol level.
Exposing symbols too broadly would risk turning optional provider evidence into
hidden product truth, so the first user-visible symbol feature must be narrow,
opt-in, inspect-only, and clearly caveated.

## Outcome

Add opt-in Tree-sitter Zig symbol enrichment for inspected files only:

```sh
git-hotspots --inspect PATH --symbols
```

When `PATH` resolves through the existing inspect/scope/rename-alias logic to an
in-scope current `.zig` file, the report includes current working-tree Zig
function symbols extracted by the vendored Tree-sitter parser. File-level Git
history remains the ranking and scoring truth. Symbol evidence is additive,
current-only, provider-labelled, and failure-tolerant.

## Requirements

### CLI contract

- Add `--symbols` as an analysis flag.
- `--symbols` is valid only with `--inspect PATH`.
- `--symbols` without `--inspect` exits non-zero with deterministic stderr.
- `--symbols` cannot be combined with `--explain` or `--version`.
- Existing `--inspect` restrictions remain unchanged, including rejection with
  `--limit`.
- Without `--symbols`, all existing table, JSON, Markdown, and inspect output
  bytes remain stable.

### Provider execution contract

- Provider execution is opt-in and inspect-only.
- Provider parses only the existing inspected `matched_path`, not every result
  and not the requested alias path blindly.
- Provider supports only current working-tree `.zig` files.
- Provider uses only vendored local Tree-sitter core and tree-sitter-zig sources.
- Provider performs no network access, package-manager fetch, global
  Tree-sitter lookup, parser generation, telemetry, upload, cache, or
  background analysis.
- Provider evidence is current-only and never affects file score, rank,
  confidence, lineage, co-change evidence, or inclusion/exclusion decisions.

### Supported symbol subset

- Supported symbols are named Zig `function_declaration` descendants.
- Symbol evidence includes repo-relative path, name, kind, one-based inclusive
  line range, provider name, confidence, and caveats.
- Deterministic ordering must match the internal provider ordering contract.
- Unsupported Zig constructs such as type/container declarations, symbol
  lineage, moves, renames, methods beyond the supported node subset, dependency
  propagation, and ownership signals remain out of scope.

### Failure and unsupported states

- Non-`.zig` inspect targets preserve file evidence and report provider
  `unsupported`.
- Empty `.zig` files preserve file evidence and report provider `ok` with zero
  symbols.
- Invalid or partial Zig source preserves file evidence and reports provider
  `failed` or low-confidence partial evidence with caveats.
- Missing current working-tree file, non-regular file, symlink, too-large file,
  parser failure, or parser timeout/budget exhaustion preserves file evidence
  and reports provider failure or unavailability with caveats.
- Provider errors must not expose raw parser diagnostics, source snippets,
  absolute paths, remotes, author identities, commit messages, or private repo
  names.

### Report contract

Provider output appears only when `--symbols` is present.

JSON adds an inspect-only top-level `symbols` object:

```json
{
  "symbols": {
    "current_only": true,
    "provider": {
      "name": "tree-sitter-zig",
      "kind": "symbol",
      "version": "tree-sitter-core@v0.26.9/tree-sitter-zig@v1.1.2",
      "contract_version": "provider-symbol-evidence-v1",
      "freshness": "fresh",
      "failure": "ok",
      "confidence": "high",
      "caveats": ["current working-tree symbols only"],
      "provenance": { "input": "working-tree:<matched-path>", "local_only": true }
    },
    "items": [
      {
        "path": "src/main.zig",
        "name": "main",
        "kind": "function",
        "range": { "type": "lines", "start": 1, "end": 10 },
        "provider": "tree-sitter-zig",
        "confidence": "high",
        "caveats": ["current-only"]
      }
    ]
  }
}
```

Table output adds a deterministic symbols section after the existing inspect/file
row information. Markdown output adds a deterministic `## Symbols` section.
Both human formats must show provider state, current-only caveat, symbol count,
and symbol rows when available.

## Acceptance

- `--symbols` exists and is accepted only with `--inspect PATH`.
- `git-hotspots --inspect PATH --symbols` preserves the existing inspected file
  evidence and adds provider symbol evidence only for the matched in-scope file.
- Table, JSON, and Markdown support successful symbol output.
- JSON uses the schema described in this PRD and includes provider envelope,
  current-only state, failure state, confidence, caveats, local provenance, and
  ordered symbol rows.
- Human outputs disclose that symbols are current working-tree enrichment and do
  not affect score, rank, lineage, or file-level evidence.
- Non-`.zig`, empty `.zig`, invalid/partial Zig, missing current file, and
  provider failure/degradation cases are covered and preserve file evidence.
- No-provider output remains byte-for-byte stable for table, JSON, Markdown, and
  plain inspect fixture cases.
- Tree-sitter runtime uses only vendored pinned local sources and does not use
  network, global packages, submodules, parser generation, cache, telemetry, or
  upload.
- Validation passes, including Tree-sitter proof steps and close-out smoke with
  this repo and `sibling-local-repo`.

## Edge cases

- `--symbols` without `--inspect`.
- `--symbols --explain` and `--symbols --version`.
- `--inspect --symbols --limit`.
- Inspect target is a rename alias; provider must parse `matched_path`.
- Inspect target is excluded or outside include scope; existing inspect error
  remains unchanged and provider does not run.
- Inspected file has no current working-tree file.
- Inspected file is non-Zig.
- Inspected file is empty Zig.
- Inspected file is invalid or partial Zig.
- Symbol names include unicode and Markdown-sensitive characters.
- Symbol ranges span multiple lines.
- Parser returns zero supported function declarations.

## Packet plan

### P1 - Runtime symbol module and build safety

Create a reusable internal Tree-sitter Zig symbol module for current working-tree
files, wire the product build safely to vendored sources as needed, and prove the
normal no-symbol product path remains stable. No CLI/report output in this
packet except possible hidden internal plumbing.

### P2 - Inspect-only CLI and report output

Add the `--symbols` flag, enforce valid combinations, run the provider only for
`--inspect`, and render additive symbol/provider output in table, JSON, and
Markdown according to this PRD.

### P3 - Validation, docs, and real-repo evidence

Update fixtures, validation, README/help/explain/docs, privacy scans, and close
out with this repo plus `sibling-local-repo` evidence.

## Verification

Required commands include:

```sh
zig fmt --check build.zig src tests
zig build test
zig build
zig build validate
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo <local-sibling-path> -Dsmoke-label sibling-local-repo
```

Additional verification:

- Golden fixtures for table, JSON, and Markdown success output.
- Golden or semantic checks for unsupported, empty, invalid/partial, and missing
  current-file degradation.
- Byte-for-byte comparison for no-symbol table, JSON, Markdown, and inspect
  outputs.
- Privacy scans over committed docs, fixtures, goldens, and validation summaries.
- Prohibited-claim scans for bug prediction, objective code quality, developer
  ranking, ownership/productivity analytics, technical-debt scoring, AI
  judgement, hosted product/pricing/sales, symbol history/lineage, dependency
  propagation, or provider evidence replacing Git truth.

## Non-goals

- No default provider execution.
- No all-file symbol parsing.
- No symbol scoring, ranking, hotspot calculation, or file score changes.
- No historical symbol lineage, rename/move tracking, ownership, author metrics,
  dependency propagation, or function-level Git history.
- No provider registry/plugin framework.
- No multi-language support.
- No cache, network, telemetry, upload, remote enrichment, CI, release packaging,
  package-manager dependency, parser generation, or global Tree-sitter lookup.
