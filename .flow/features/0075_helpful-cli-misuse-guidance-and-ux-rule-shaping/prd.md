# Helpful CLI misuse guidance and UX rule shaping

## Context

A user ran:

```sh
zig build run -- --symbols
```

The binary rejected the flag combination because `--symbols` is inspect-only and
requires `--inspect PATH`. The current direct-binary diagnostic states the
constraint, but it does not provide a concrete recovery command or a systematic
UX rule for future flag changes. Through `zig build run`, Zig also wraps the
application exit with build-run failure text, so the application diagnostic must
be especially actionable before that wrapper noise.

## Requirements

- R1: Define and execute a deterministic CLI misuse matrix before changing
  behaviour. The matrix must cover dependency errors, missing values, invalid
  enum values, standalone command combinations, help precedence, unknown flags,
  and the symbol-specific cases that triggered this feature.
- R2: For invalid CLI usage, stderr must include the immediate cause and, where
  a recovery is unambiguous, an accepted command shape or concrete example. The
  output must remain deterministic, concise, local-first, and free of absolute
  local paths, remotes, author identities, source snippets, commit messages, or
  telemetry implications.
- R3: `--symbols` without `--inspect PATH` must guide the user to an inspect
  command, for example `git-hotspots --inspect src/main.zig --symbols`, without
  changing the inspect-only provider semantics.
- R4: Dependent symbol flags must keep their existing semantics:
  `--symbol-line-history` requires `--inspect PATH --symbols`, and
  `--symbol-limit N` requires `--inspect PATH --symbols` with a positive
  integer.
- R5: Generic parser failures such as missing values, invalid enum values, and
  unknown flags should not collapse to a vague `invalid arguments` when the
  parser can identify the specific flag family.
- R6: CLI help, README, user guide, manual page, developer guide, integration
  tests, and validation greps must stay aligned with any changed user-facing
  wording.
- R7: Add or update agent-facing repository guidance so future refactors,
  added flags, changed flags, and removed flags preserve the misuse matrix,
  actionable diagnostics, docs/help alignment, and local-first/privacy-safe
  boundaries.
- R8: Do not add new runtime analysis modes, repo-wide symbol scanning,
  interactive prompts, shell completions, packaging, network access, telemetry,
  cache requirements, or provider scope expansion as part of this UX feature.

## Edge cases

- E1: `--help` and `-h` remain standalone, repository-independent, and high
  precedence; `git-hotspots --help --symbols` should still show help and exit 0
  rather than treating `--symbols` as an invalid combination.
- E2: `--explain` and `--version` remain standalone and reject analysis flags
  with actionable messages.
- E3: Diagnostics must be useful both when running the installed/direct binary
  and when using `zig build run -- ...`, acknowledging that Zig may append build
  wrapper failure text after the application exits non-zero.
- E4: JSON, Markdown, and table report output contracts must not change for
  successful analysis or inspect runs unless a test-backed wording change is
  explicitly required.
- E5: Privacy scans must continue to reject raw private report output,
  absolute paths, remotes, author identities, source snippets, and commit
  messages in public docs and diagnostics.

## Verification notes

- Run the misuse matrix against the direct binary (`./zig-out/bin/git-hotspots`)
  so application stderr can be asserted without Zig build-run wrapper noise.
- Include at least one `zig build run -- --symbols` smoke check to confirm the
  originally reported command surfaces the helpful application diagnostic before
  Zig wrapper text.
- Run narrow checks while iterating:
  `zig fmt --check build.zig src tests`, `zig build test`, and focused direct
  binary misuse commands.
- Run the full local validation gate before handoff: `zig build validate`.
- Because this is an implementation feature, perform real-repository smoke
  validation on this repo plus one suitable sibling/local repo when executable
  behaviour changes; record only privacy-safe labels and summaries, not absolute
  paths or raw private report output.
