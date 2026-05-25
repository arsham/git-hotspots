# Provider capability documentation consolidation

## Problem

The CLI now has inspect-only symbol evidence across Zig, Go, Python,
JavaScript, TypeScript, and TSX, plus current-line evidence for several
providers. The behaviour is feature-proven, but the user-facing capability story
is fragmented across README, help text, explain text, fixtures, validation
scripts, and feature-specific evidence documents.

This creates two risks:

- users may overread symbol evidence as default hotspot truth, true symbol
  history, type-aware analysis, ownership, risk, quality, or bug prediction;
- future provider changes may update behaviour without keeping the public
  capability surface and validation matrix aligned.

## Outcome

Add a concise, public provider capability surface and validation matrix that
state what the CLI currently supports, what remains inspect-only, what current
line evidence means, and what is deliberately absent.

The feature must not change runtime semantics except for wording, fixtures, or
validation checks that reflect existing behaviour.

## Requirements

### REQ-001 Provider capability matrix

Public documentation must include a compact provider capability matrix covering
Zig, Go, Python, JavaScript, TypeScript, and TSX.

The matrix must distinguish at least:

- inspect-only symbol support;
- current-line evidence support when `--symbol-line-history` is requested;
- unsupported or intentionally absent behaviours;
- deterministic local-first execution.

### REQ-002 Inspect-only framing

README, CLI help, and explain text touched by the feature must describe symbols
as opt-in inspect evidence, not as default hotspot truth.

### REQ-003 Current-line evidence framing

Current-line evidence must be described as evidence for the lines occupied by a
symbol at `HEAD`. It must not be described as true symbol history, historical
identity tracking, `git log -L`, authorship, ownership, risk, quality, or
performance judgement.

### REQ-004 Supported-language alignment

Documentation and validation must align with current support for Zig, Go,
Python, JavaScript, TypeScript, and TSX, including extension-specific behaviour
where the existing product exposes it.

### REQ-005 Unsupported and degraded cases

The public capability surface must preserve unsupported and degraded behaviour
language for unsupported providers, invalid or unavailable inputs, generated or
minified caveats, shallow or partial history, and dirty-worktree limitations
where applicable.

### REQ-006 Validation matrix

The implementation must add or extend validation so documented capability
claims are checked against current behaviour. The validation may be script,
integration, fixture, or golden based, but must be deterministic and local.

### REQ-007 Protected runtime semantics

The feature must not add or change provider extraction semantics, line-history
algorithms, default reports, scoring, ranking, confidence, co-change, cache,
CLI modes, schema fields, release packaging, CI network requirements, telemetry,
upload, or remote enrichment.

### REQ-008 Public and privacy-safe evidence

Public docs, fixtures, and validation output must avoid private absolute paths,
raw private report dumps, personal emails, developer-performance framing, bug
prediction, quality scoring, ownership claims, or maintainer judgement.

### REQ-009 Validation ladder

Close-out evidence must include:

- `git diff --check`;
- `zig fmt --check build.zig src tests` when those paths are touched;
- `zig build test`;
- `zig build validate`;
- targeted inspect, help, or explain fixture checks affected by the feature;
- capability-matrix validation for supported and unsupported languages;
- privacy and prohibited-claims scan;
- a privacy-safe close-out smoke using this repository and, when safe, a
  sibling local repository labelled `sibling-local-repo`.

## Edge cases and non-goals

- Do not add another language provider in this feature.
- Do not add type checking, package or workspace analysis, module resolution,
  `tsconfig` interpretation, Node execution, LSP, custom runtime queries, cache,
  network access, telemetry, upload, or remote enrichment.
- Do not turn current-line evidence into true symbol-history claims.
- Do not imply that hotspots predict bugs or judge code quality, owners,
  maintainers, teams, or developers.
- If accurate documentation requires behaviour changes, stop for planning rather
  than changing runtime scope inside this feature.

## Verification notes

Review should prove that this is a documentation and validation consolidation
feature, not a provider behaviour feature. The most important review questions
are:

1. Do the docs and help text match current behaviour exactly?
2. Do the new validation checks prevent capability-matrix drift?
3. Did any runtime output or semantics change outside intentional docs, help,
   explain, or validation fixtures?
4. Are all public claims local-first, deterministic, privacy-safe, and free of
   prohibited quality, ownership, risk, or prediction framing?
