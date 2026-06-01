# Relationship evidence drilldown examples

## Purpose

Add documentation examples that show how to interpret relationship evidence across table, Markdown, and JSON without changing runtime behaviour.

## Requirements

- REQ-001: Add or update public documentation with relationship evidence drilldown examples grounded in checked-in fixture outputs.
- REQ-002: Cover table, Markdown, and JSON perspectives without implying any output format is more truthful than the others.
- REQ-003: Explain relation records as local syntax evidence and investigation prompts, not call-graph, dependency, package, runtime, ownership, quality, or bug-prediction truth.
- REQ-004: Show how to read provider names, relation kinds, evidence basis, caveats, uncertainty summaries, and omission wording together.
- REQ-005: Use project-relative paths and bounded snippets only; do not add private paths, remotes, identities, emails, raw private reports, or commit messages.
- REQ-006: Preserve CLI flags, JSON schema, report fields, provider behaviour, scoring, ranking, caps, cache, network, telemetry, release, tag, remote, package, and publish behaviour.
- REQ-007: Update validation if new docs need a stable guardrail.
- REQ-008: Run `git diff --check`, `zig build test`, and `zig build validate` before close-out.

## Acceptance

- A fresh reader can follow one relationship record from human output to JSON fields and understand caveats and limits.
- Public wording remains evidence-only and local-first.
- No runtime or schema files change unless validation discovers an existing doc guardrail bug.

## Edge cases

- Examples must handle unknown/unresolved evidence without overclaiming.
- Examples must distinguish human display omissions from provider-cap omissions.
- Duplicate-looking records must be explained as meaningful when kind or evidence basis differs.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- Reviewer-owned discovery and execution of credible lint/test gates.
