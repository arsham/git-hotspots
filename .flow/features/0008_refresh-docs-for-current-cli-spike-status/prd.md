# Feature 0008 PRD - Refresh docs for current CLI spike status

## Summary

Refresh stale public and planning documentation after Features 0002-0007 delivered
the initial executable CLI, validation workflow, scope filters, Markdown export,
and standalone explanation output.

This is a docs-only maintenance feature. It must not change runtime behaviour,
validation tooling, fixtures, build configuration, or implementation code.

## Requirements

1. `docs/planning-handoff.md` no longer describes the file-level CLI spike as a
   future feature.
2. `docs/planning-handoff.md` describes current CLI capabilities accurately:
   table, JSON, Markdown, `--repo`, `--limit`, `--format`, `--since`, repeatable
   `--include-prefix`, repeatable `--exclude-prefix`, `--explain`, `--help`, and
   `zig build validate`.
3. `docs/planning-handoff.md` does not choose a new next implementation feature;
   future seams may be listed only as candidates.
4. `.flow/project-memory.md` no longer tells planners that the next likely slice
   is the file-level CLI spike.
5. `README.md` remains visitor-facing and free of Flow lifecycle/process clutter;
   change it only if current CLI truth requires a correction.
6. No implementation, build, test, fixture, tool, generated-output, provider,
   cache, release, CI, network, telemetry, or runtime behaviour files are edited.
7. Docs preserve local-first OSS framing and do not add hosted-product, pricing,
   sales, monetisation, commercial-roadmap, bug-prediction, objective
   code-quality, technical-debt-score, author-metric, maintainer-judgement,
   developer-ranking, or productivity-analytics claims.
8. Committed docs contain no absolute local paths, private repo names, raw private
   smoke output, author identities, or Flow run logs.

## Edge cases

- If a scan finds commercial or diagnostic terms in `.flow/project-memory.md`, the
  hit is acceptable only when it is an explicit prohibition or guardrail.
- If README retains `.flow/` as a literal CLI scope-filter example, it must not
  read as Flow process documentation.
- If updating docs would require claiming unimplemented CLI behaviour, stop and
  reshape instead of editing docs to overpromise.
- If a next feature seems obvious, record it only as a candidate seam unless the
  operator explicitly selects it.

## Validation

Required close-out evidence:

```sh
git diff --check
./zig-out/bin/git-hotspots --help
./zig-out/bin/git-hotspots --explain
```

Docs-only changed-path scan:

```sh
git diff --name-only | rg '^(src/|tests/|tools/|fixtures/|build\.zig$)' && exit 1 || true
```

Stale-language scan:

```sh
rg -n -i 'next likely|future file-level CLI spike|should probably be|Feature 0001 must not create|later feature to shape' README.md docs/planning-handoff.md .flow/project-memory.md
```

Prohibited positive-claim scan:

```sh
rg -n -i 'saas|commercial|pricing|sales|moneti[sz]e|revenue|subscription|paid|hosted product|bug[- ]?prediction|predicts? bugs|objective code quality|code[- ]?quality (score|rating)|technical-debt score|developer[- ]?(ranking|performance|score)|productivity analytics|maintainer judgement' README.md docs/planning-handoff.md .flow/project-memory.md
```

All hits must be absent or explicit negative guardrails. Run `zig build validate`
if README CLI examples, validation wording, or public claims are materially
changed.
