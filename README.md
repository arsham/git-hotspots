# git-hotspots

> Before you refactor, ask Git where the pain is.

`git-hotspots` is a planned local-first CLI for finding files that deserve
engineering attention because they change often. It turns Git history into
clear, reproducible hotspot evidence for maintainers, refactoring work, code
review, onboarding, and coding-agent context.

The project is intentionally early. A first Zig CLI spike now proves that a
small, transparent command-line tool can surface useful file-level hotspots
before adding deeper language-aware analysis.

## Why

Code that changes often is worth attention. It may be fragile, strategically
important, under-tested, or simply central to how a project evolves.

`git-hotspots` starts from a simple idea:

> The riskiest code is not always the ugliest code. It is often the code
> everyone keeps changing.

That does not mean a hotspot is bad code. A hotspot is an investigation prompt:
a place to inspect, understand, test, document, or refactor with better context.

## What it should help with

`git-hotspots` should help answer questions like:

- where should we inspect first?
- where might tests or documentation pay off?
- where should a refactor proposal start?
- which files deserve extra review attention?
- which files should a coding agent understand before suggesting changes?

The tool should be evidence-first and careful. It should not claim to predict
bugs, measure objective code quality, or rank developers.

## First useful layer

The first implementation target is file-level evidence from local Git history:

- change frequency;
- churn from additions and deletions;
- recency;
- co-change with other files;
- file size or similar scale signals;
- confidence and caveats;
- explainable evidence for each result.

The goal is to produce reports that humans can read and tools can consume,
without uploading source code or depending on runtime AI judgement.

## Local-first by default

The project should preserve trust by default:

- analyse local repositories;
- avoid network access by default;
- avoid telemetry by default;
- prefer project-relative paths in shareable output;
- treat author identity and ownership metrics as sensitive;
- report shallow or partial history honestly instead of silently fetching more.

## Future provider direction

Language and dependency insight should arrive through optional providers rather
than become the foundation of the project.

Possible future providers include:

- tree-sitter for current symbol spans;
- LSP data for richer language-aware relationships;
- ctags for broad symbol discovery;
- dependency graph data;
- blame or history enrichers;
- test and coverage evidence.

Provider output should be enrichment, not hidden truth. Future providers should
expose source, version, freshness, confidence, and failure state so reports can
degrade gracefully when a provider is unavailable or uncertain.

## Agent-ready, not agent-dependent

`git-hotspots` may produce Markdown, JSON, or other export formats that users
can pass to coding agents. Those exports should carry deterministic evidence,
provenance, and caveats.

The product truth remains local Git evidence. Agents are consumers of reports,
not the runtime authority for hotspot findings.

## CLI spike

Build and run the current local spike with Zig:

```sh
zig build
./zig-out/bin/git-hotspots --repo . --limit 10 --format table
./zig-out/bin/git-hotspots --repo . --limit 10 --format json
```

Supported options are `--repo`, `--limit`, `--format table|json`, `--since`,
and `--help`. The spike reads local Git history only. It does not fetch, push,
upload source, contact remotes, or emit telemetry.

## Status

This repository has an executable file-level CLI spike. It is not a packaged
release yet.
