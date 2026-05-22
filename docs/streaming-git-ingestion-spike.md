# Streaming Git ingestion spike

This note records privacy-safe evidence for Feature 0016. It keeps runtime truth local and deterministic; it is not a benchmark claim.

## What changed

- The main `git log --numstat` ingestion path now reads child-process stdout through a streaming parser seam instead of retaining the full stdout payload before parsing.
- The parser keeps only the current partial line, current commit metadata, and aggregate evidence state needed by the existing model.
- Parser coverage includes split headers and numstat rows, final input without a trailing newline, CRLF trimming, binary numstat rows, malformed or blank lines, braced renames, quoted tab paths, and unicode paths.
- `--progress` remains opt-in stderr-only and now includes bounded phase timing lines for repository checks, Git read/parse, score/result work, rendering, and total elapsed time.

## What was measured

Fresh validation was run on this repository and on the approved local sibling repository using only the label `sibling-local-repo`.

- `zig build test`: passed.
- `zig build validate`: passed, including fixture parity and stdout/stderr separation checks.
- `zig build validate -Dcloseout=true -Dsmoke-label=sibling-local-repo`: passed.
- `git diff --check`: passed as part of validation.

Privacy-safe close-out smoke summary:

- this-repo: all table/json/markdown routes passed; project progress route passed; 47 commits and 67 tracked files were observed by the validation script; output parity remained stable.
- sibling-local-repo: all table/json/markdown routes passed; project progress route passed; 1521 commits and 2840 tracked files were observed by the validation script; output parity remained stable.

## What remains unknown

- These observations do not prove performance characteristics across all large repositories.
- The streaming seam reduces the need to retain the full Git stdout payload, but aggregate memory still depends on repository history shape, result evidence, and co-change state.
- Cache remains a future optimisation and was not implemented here.
