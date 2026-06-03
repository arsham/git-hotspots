#!/usr/bin/env python3
"""Validate historical-symbol fixture docs against golden output."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PRIVATE_MARKERS = ("/home/", "/Users/", "file://", "https://", "http://", "ssh://", "git@")
EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")


def fail(message: str) -> None:
    raise SystemExit(message)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def require_anchor(path: Path, text: str, needle: str, label: str) -> None:
    if needle not in text:
        fail(f"{path}: missing {label}: {needle}")


def require_private_safe(path: Path, text: str) -> None:
    for needle in PRIVATE_MARKERS:
        if needle in text:
            fail(f"{path}: private path or remote marker leaked: {needle}")
    if EMAIL_RE.search(text):
        fail(f"{path}: email-like identity leaked")


def historical_items(golden: dict) -> list[dict]:
    return list(golden.get("historical_symbols", {}).get("items", []))


def items_by_path(golden: dict) -> dict[str, dict]:
    return {record.get("evidence_path"): record for record in historical_items(golden)}


def require_provider_record(
    golden_path: Path,
    by_path: dict[str, dict],
    path: str,
    state: str,
    fallback_count: int,
    context: str,
) -> None:
    record = by_path.get(path)
    if not record:
        fail(f"{golden_path}: missing {context} row {path}")
    if record.get("provider_state") != state:
        fail(f"{golden_path}: {path} provider_state drifted: {record.get('provider_state')!r}")
    if record.get("fallback_count") != fallback_count:
        fail(f"{golden_path}: {path} fallback_count drifted: {record.get('fallback_count')!r}")


def validate_provider_states(matrix_path: Path, audit_path: Path, golden_path: Path) -> None:
    matrix = read_text(matrix_path)
    audit = read_text(audit_path)
    golden = read_json(golden_path)

    states = golden["historical_symbols"]["summary"]["provider_states"]
    expected_states = {
        "ok": 4,
        "unsupported": 1,
        "failed": 1,
        "skipped": 1,
        "timed_out": 0,
        "unavailable": 0,
    }
    if states != expected_states:
        fail(f"{golden_path}: provider-state summary drifted: {states!r}")

    by_path = items_by_path(golden)
    required_records = {
        "src/broken.zig": ("failed", 1),
        "src/readme.txt": ("unsupported", 1),
        "src/link.zig": ("skipped", 1),
    }
    for path, (state, fallback_count) in required_records.items():
        require_provider_record(golden_path, by_path, path, state, fallback_count, "historical fixture")

    matrix_required = [
        "| Provider-state spread | summary includes `ok`, `unsupported`, `failed`, and `skipped` states |",
        "| Failed parser fallback | `src/broken.zig` has `provider_state: failed`, `fallback_count: 1`, and low confidence |",
        "`timed_out` and `unavailable` remain explicit historical provider-state",
        "coverage gaps, not states proven impossible.",
    ]
    for needle in matrix_required:
        require_anchor(matrix_path, matrix, needle, "provider-state matrix anchor")

    audit_rows = {
        "ok": "| `ok` | yes | parsed revision-local Zig rows for `alpha`, `zebra`, and `target` |",
        "unsupported": "| `unsupported` | yes | `src/readme.txt` fallback row |",
        "skipped": "| `skipped` | yes | `src/link.zig` unattributed/root-commit fallback row |",
        "failed": "| `failed` | yes | `src/broken.zig` malformed historical Zig blob produces a failed fallback row |",
        "timed_out": "| `timed_out` | no | no provider timeout injection exists for historical attribution |",
        "unavailable": "| `unavailable` | no | no historical blob fixture currently exercises unavailable provider input |",
    }
    for state, row in audit_rows.items():
        require_anchor(audit_path, audit, row, f"provider-state audit row for {state}")

    for state, count in expected_states.items():
        covered = count > 0
        expected_marker = f"| `{state}` | {'yes' if covered else 'no'} |"
        if expected_marker not in audit:
            fail(f"{audit_path}: coverage marker for {state} does not match golden count {count}")

    for needle in (
        "The fixture now covers `failed` with deterministic content-driven parser",
        "only `timed_out` and `unavailable` as uncovered historical",
        "Reject wall-clock timeout fixtures or environment-dependent missing-provider",
    ):
        require_anchor(audit_path, audit, needle, "uncovered-state rationale")

    require_private_safe(matrix_path, matrix)
    require_private_safe(audit_path, audit)


def validate_fallback_pressure(matrix_path: Path, guide_path: Path, golden_path: Path) -> None:
    matrix = read_text(matrix_path)
    guide = read_text(guide_path)
    golden = read_json(golden_path)

    historical = golden["historical_symbols"]
    summary = historical["summary"]
    records = historical_items(golden)

    expected_fallback_record_count = 3
    if summary.get("fallback_record_count") != expected_fallback_record_count:
        fail(f"{golden_path}: fallback_record_count drifted: {summary.get('fallback_record_count')!r}")
    if summary.get("fallback_count") != expected_fallback_record_count:
        fail(f"{golden_path}: fallback_count drifted: {summary.get('fallback_count')!r}")

    fallback_rows = [record for record in records if record.get("fallback_count", 0) > 0]
    if len(fallback_rows) != expected_fallback_record_count:
        fail(f"{golden_path}: fallback row count drifted: {len(fallback_rows)!r}")

    by_path = items_by_path(golden)
    expected_rows = {
        "src/broken.zig": ("failed", 1),
        "src/link.zig": ("skipped", 1),
        "src/readme.txt": ("unsupported", 1),
    }
    for path, (state, fallback_count) in expected_rows.items():
        require_provider_record(golden_path, by_path, path, state, fallback_count, "fallback-pressure")

    total_fallback_hunks = sum(record.get("fallback_count", 0) for record in records)
    if total_fallback_hunks != expected_fallback_record_count:
        fail(f"{golden_path}: total fallback hunk pressure drifted: {total_fallback_hunks!r}")

    required_matrix = [
        "| Fallback hunk pressure | fallback rows carry `fallback_count`; the fixture uses tiny counts while real repos may have a few fallback rows with many fallback hunks |",
        "| Mixed parsed revision fallback | mixed parsed revisions count only unmatched hunks as fallback pressure while symbol-intersecting hunks stay attributed |",
        "keeps fallback row count separate from fallback hunk pressure",
        "prevents symbol-backed hunks from inflating file-level fallback pressure",
        "fallback rows, and fallback hunk pressure",
        "Keep unsupported, skipped, fallback rows, and fallback hunk pressure",
        "only unmatched hunks contribute fallback pressure",
    ]
    for needle in required_matrix:
        require_anchor(matrix_path, matrix, needle, "fallback-pressure anchor")

    required_guide = [
        "Fallback hunk pressure",
        "Read fallback row counts and fallback hunk counts separately",
        "Mixed parsed revisions keep direct symbol",
        "intersections as symbol evidence",
        "count only unmatched hunks as fallback",
        "Whole-file fallback still applies when the provider state is",
        "a fallback row may aggregate one or many changed",
        "number of fallback rows can still represent substantial unattributed hunk",
    ]
    for needle in required_guide:
        require_anchor(guide_path, guide, needle, "fallback-pressure guide anchor")

    require_private_safe(matrix_path, matrix)
    require_private_safe(guide_path, guide)


def main(argv: list[str]) -> int:
    if len(argv) != 5 or argv[1] not in {"provider-states", "fallback-pressure"}:
        fail(
            "usage: validate-historical-symbol-docs.py "
            "provider-states <matrix.md> <audit.md> <golden.json> | "
            "fallback-pressure <matrix.md> <user-guide.md> <golden.json>"
        )

    mode = argv[1]
    first = Path(argv[2])
    second = Path(argv[3])
    golden = Path(argv[4])
    if mode == "provider-states":
        validate_provider_states(first, second, golden)
    else:
        validate_fallback_pressure(first, second, golden)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
