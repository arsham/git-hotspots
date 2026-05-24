# Feature 0044: Tree-sitter Python query contract and fixtures

## Summary

Define and validate the first project-owned Tree-sitter Python symbol query
contract and fixture corpus for future Python symbol extraction.

This feature is a contract and fixture proof. It may add internal query assets
and validation fixtures, but it must not expose Python symbols in CLI output or
wire a Python provider into product runtime.

## Problem

Feature 0043 will prove that the vendored Python parser and scanner compile and
parse. The next risk is semantic: which Python nodes count as useful current
symbols, how captures map to the existing provider model, how ranges and
ordering stay deterministic, and which Python constructs must be caveated.

Without a separate query contract, future Python extraction would mix query
semantics, fixture design, runtime plumbing, and user-facing output changes.

## Goals

- Add a project-owned Python symbol query contract for the first supported
  subset.
- Add deterministic fixture inputs for modules, classes, functions, methods,
  constants, decorators, nested definitions, invalid/partial files, empty files,
  generated files, and unsupported paths.
- Define capture names, symbol-kind mapping, range semantics, deterministic
  ordering, provider/query version metadata, and caveats.
- Prove the contract with internal validation or proof tests where practical.
- Record concise public evidence for the chosen query contract and fixture
  coverage.

## Non-goals

- No user-facing Python `--symbols` output.
- No Python provider registry entry.
- No CLI flags, report/schema/output changes, scoring, ranking, lineage, cache,
  CI release, package, or LSP work.
- No package discovery, virtual environment discovery, workspace analysis,
  `pyproject.toml` parsing, dependency graph inference, import resolution,
  namespace package handling, notebook handling, or repo-wide scanning.
- No custom user query execution.
- No parser generation, network fetches, package-manager resolution, submodules,
  global Tree-sitter CLI, system parser packages, or `build.zig.zon`.

## Requirements

### R1 - Project-owned query contract

The feature must define a project-owned Python symbol query contract rather than
blindly importing upstream highlight or tags queries. The contract must name the
supported capture names and their intended meaning.

### R2 - Supported Python subset

The first contract must cover at least:

- module file evidence as a `module` symbol when useful and deterministic;
- top-level classes as `type` symbols;
- top-level functions as `function` symbols;
- methods inside classes as `method` symbols;
- simple module-level constants or assignments as `variable` or `other` with a
  documented caveat;
- decorators on classes, functions, and methods as caveats or metadata when
  they affect symbol meaning; and
- nested functions and nested classes with deterministic ranges and caveats.

Unsupported constructs must be documented rather than silently overclaimed.

### R3 - Range semantics

Each symbol must use deterministic one-based inclusive line ranges from the
selected declaration node. Decorators must either be included in the range or
caveated with an explicit rule. Nested definitions must not create ambiguous or
unstable ranges.

### R4 - Ordering semantics

The contract must define deterministic ordering for repeated runs on the same
input. Expected order is source order using start byte, end byte, kind rank, and
bytewise symbol name as tie-breakers, unless the feature documents a stronger
existing helper.

### R5 - Fixture coverage

Fixtures or proof inputs must cover at least:

- empty module;
- module with top-level class;
- top-level function;
- methods inside classes;
- module constants and simple assignments;
- decorators on classes, functions, and methods;
- nested functions and nested classes;
- indentation errors and partial indentation states;
- dynamic assignments that are caveated or ignored deterministically;
- generated-file marker;
- empty file;
- invalid or partial file;
- unsupported path and skipped-provider states; and
- Unicode and Markdown-sensitive symbol names when accepted by the parser.

### R6 - Existing provider shape

The contract must map into `provider.CurrentSymbolEvidence` or a directly
compatible internal shape. If existing symbol kinds are insufficient, map
conservatively with caveats or stop for a seam-extension feature.

### R7 - Local-only validation

Any proof or validation must use local vendored Tree-sitter sources and
project-owned fixtures only. It must not fetch queries, invoke global
Tree-sitter CLI tools, run package managers, import Python packages, inspect
virtual environments, or call remote services.

### R8 - Evidence document

Add a concise public evidence document, expected path:

```text
docs/tree-sitter-python-query-contract.md
```

It must record supported subset, capture names, symbol-kind mapping, range and
ordering rules, fixture coverage, caveats, validation commands, and explicit
statement that Python runtime output is not implemented yet.

### R9 - Protected surfaces

No-provider table, JSON, Markdown, and inspect outputs must remain byte-stable.
Existing Zig and Go symbol outputs must remain byte-stable unless a separate
feature explicitly changes them. Do not update expected product output goldens
to absorb Python runtime behaviour.

### R10 - Privacy and claims

Committed evidence and fixtures must avoid private paths, raw private source,
raw parser stderr, remotes, author identities, commercial strategy, bug
prediction, quality scoring, developer ranking, or maintainer judgement.

## Edge cases

- If the Python query cannot express the supported subset deterministically,
  stop and reshape instead of adding ad-hoc runtime parsing by local decision.
- If decorator or nested definition ranges are ambiguous, choose a conservative
  caveated rule or stop for planning.
- If dynamic assignment support would require Python semantic evaluation, mark
  it unsupported or caveated.
- If a fixture would require private source, replace it with synthetic public
  input.

## Verification

Close-out must include evidence for:

```sh
zig fmt --check build.zig src tests
zig build test
zig build
zig build validate
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build tree-sitter-go-build-proof
zig build tree-sitter-go-symbol-proof
zig build tree-sitter-python-build-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

If the feature adds a dedicated Python query proof command, close-out must run
that command and record its result. The sibling path is execution-only context
and must not be committed.
