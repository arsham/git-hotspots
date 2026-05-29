# Provider relationship capability matrix refresh

## Summary

Refresh public relationship capability claims after the conformance harness and
remaining-language proof features close. This is the only feature in the batch
that may update public provider support claims for Go, Lua, or Zig, and it may
admit only lanes proven by closed predecessor evidence.

The feature must keep capability claims, CLI help, explain text, docs, manual
page, fixtures, and validation aligned. Unsupported or no-admit lanes must stay
visibly unsupported or caveated. Public wording must not imply call graph truth,
dependency proof, type checking, package graph proof, ownership, code quality,
developer metrics, bug prediction, scoring changes, cache truth, network access,
or telemetry.

## Requirements

- REQ-001 - Depend on closed features 0091, 0092, 0093, and 0094.
- REQ-002 - Read predecessor outcomes before changing public support claims.
- REQ-003 - Admit Go, Lua, or Zig relationship support only when the matching
  proof feature closed with sufficient conformance, fixture, validation, and
  privacy-safe evidence.
- REQ-004 - Keep no-admit or unsupported lanes visibly unsupported or caveated
  in README, user guide, developer guide, manual page, help/explain text,
  fixtures, and validation.
- REQ-005 - Update README, docs/user-guide.md, docs/developer-guide.md,
  man/git-hotspots.1, CLI help/explain output, integration fixtures, and
  tools/validate.sh together when public claims change.
- REQ-006 - Keep relationship table, JSON, and Markdown golden fixtures
  deterministic and privacy-safe.
- REQ-007 - Add or preserve drift checks proving public documentation and
  inspectable provider behaviour agree.
- REQ-008 - Preserve existing file ranking, symbol ranking, historical symbol
  evidence, scoring, cache behaviour, network behaviour, telemetry defaults,
  and report schema compatibility.
- REQ-009 - Keep caveats visible for syntax-only evidence, unresolved targets,
  unsupported languages, parser failures, dynamic dispatch, macro or generated
  code, package/module resolution gaps, type checking gaps, and cap hits.
- REQ-010 - Run fresh close-out validation including `zig build test`,
  `zig build validate`, and privacy-safe real-repo smoke or explicit skip
  reason.

## Edge cases

- A predecessor closes with a no-admit result; public docs must not imply support.
- A language has current-symbol support but no admitted relationship provider.
- A provider emits internal evidence but public report support is deferred.
- Public table, JSON, and Markdown fixtures must sort deterministically.
- A validation drift check disagrees with docs or help output.
- Close-out smoke is unavailable and needs a privacy-safe skip reason.

## Verification

- `git diff --check`
- `zig fmt --check build.zig src tests`
- `zig build test`
- `zig build validate`
- Close-out smoke with a privacy-safe sibling/local label or explicit skip
  reason.
