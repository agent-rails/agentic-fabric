#!/usr/bin/env python3
"""Validate and normalize a review-convergence judge verdict.

The CLI deliberately has no model/provider dependency. It accepts one JSON
object on stdin and emits a normalized verdict. Invalid input fails closed to
`human_review` and exits 3, so callers cannot mistake parser failure for
convergence.
"""

from __future__ import annotations

import json
import sys
from typing import Any


DIMENSIONS = {
    "resolution",
    "novelty",
    "evidence",
    "execution",
    "independence",
    "expected_information_gain",
}
VERDICTS = {"continue", "converged", "human_review"}
REQUIRED = {
    "schema_version",
    "verdict",
    "confidence",
    "blocking_dimensions",
    "evidence_refs",
    "reason",
}


def fail_closed(reason: str) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "verdict": "human_review",
        "confidence": 0.0,
        "blocking_dimensions": ["evidence"],
        "evidence_refs": [],
        "reason": f"invalid judge output: {reason}"[:600],
    }


def validate(value: Any) -> tuple[dict[str, Any], bool]:
    if not isinstance(value, dict):
        return fail_closed("top level must be an object"), False
    if set(value) != REQUIRED:
        return fail_closed("fields do not match the v1 schema"), False
    if isinstance(value["schema_version"], bool) or value["schema_version"] != 1:
        return fail_closed("unsupported schema_version"), False
    if value["verdict"] not in VERDICTS:
        return fail_closed("unknown verdict"), False
    confidence = value["confidence"]
    if isinstance(confidence, bool) or not isinstance(confidence, (int, float)):
        return fail_closed("confidence must be numeric"), False
    if not 0 <= confidence <= 1:
        return fail_closed("confidence must be between 0 and 1"), False
    dimensions = value["blocking_dimensions"]
    if not isinstance(dimensions, list) or any(not isinstance(item, str) or item not in DIMENSIONS for item in dimensions):
        return fail_closed("invalid blocking_dimensions"), False
    if len(dimensions) != len(set(dimensions)):
        return fail_closed("blocking_dimensions must be unique"), False
    refs = value["evidence_refs"]
    if not isinstance(refs, list) or any(not isinstance(item, str) or not item or len(item) > 240 for item in refs):
        return fail_closed("invalid evidence_refs"), False
    if len(refs) != len(set(refs)):
        return fail_closed("evidence_refs must be unique"), False
    reason = value["reason"]
    if not isinstance(reason, str) or not reason or len(reason) > 600:
        return fail_closed("reason must contain 1-600 characters"), False
    if value["verdict"] == "converged" and dimensions:
        return fail_closed("converged verdict cannot have blocking dimensions"), False
    return value, True


def main() -> int:
    try:
        value = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        result, valid = fail_closed(f"malformed JSON: {error.msg}"), False
    else:
        try:
            result, valid = validate(value)
        except (TypeError, ValueError) as error:
            result, valid = fail_closed(f"invalid value: {error}"), False
    json.dump(result, sys.stdout, sort_keys=True)
    sys.stdout.write("\n")
    return 0 if valid else 3


if __name__ == "__main__":
    raise SystemExit(main())
