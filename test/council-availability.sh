#!/usr/bin/env bash
# Regression tests for council availability and reviewer eligibility.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
docs = {
    "root contract": (root / "AGENTS.md").read_text(),
    "council": (root / "skills/council/SKILL.md").read_text(),
    "oneshot": (root / "skills/oneshot/SKILL.md").read_text(),
    "land": (root / "skills/land/SKILL.md").read_text(),
}

def require(condition, message):
    if not condition:
        raise AssertionError(message)

def normalized(text):
    return re.sub(r"\s+", " ", text).lower()

# Author history remains useful for attribution, but cannot make a configured
# reviewer ineligible in either council or per-task review routing.
for name in ("root contract", "council", "oneshot", "land"):
    text = normalized(docs[name])
    require(not re.search(r"(?:skip|exclude|demote|never|outside|non-author)[^.\n]{0,100}author_models", text),
            f"{name}: author_models still filters reviewer eligibility")
    require(not re.search(r"task-reviewer[^.\n]{0,120}(?:authoring family|author_models)", text),
            f"{name}: per-task reviewer still has an author-family exclusion")

# Quorum is the number of usable configured reviewers, not provider count or
# an audited single-provider mode. A real one-reviewer PASS remains review.
council = normalized(docs["council"])
oneshot = normalized(docs["oneshot"])
require(re.search(r"one (?:available|healthy|eligible) reviewer[^.\n]{0,120}pass", council + " " + oneshot),
        "one available reviewer must be able to satisfy review with a real PASS")
require(not re.search(r"(?:0|zero|unknown) (?:eligible )?providers?[^.\n]{0,80}(?:stop|halt|block)", council + " " + oneshot),
        "provider count must not independently block a review with an available reviewer")

# No available reviewers is explicitly a skipped review, never a fabricated
# PASS; with verification green, the merge contract must handle that state.
all_text = normalized(" ".join(docs.values()))
require(re.search(r"(?:no|zero) (?:available|eligible|healthy) reviewers?[^.\n]{0,100}(?:skip|skipped)", all_text),
        "zero reviewers must be recorded as a skipped review")
require(re.search(r"skip(?:ped)?[^.\n]{0,100}(?:not|never) (?:a )?(?:council )?pass", all_text),
        "a skipped review must not be represented as PASS")
require(re.search(r"(?:skip(?:ped)? review|review skipped)[^.\n]{0,180}(?:green|checks?)[^.\n]{0,120}(?:merge|land)", all_text),
        "merge handling must allow an explicitly skipped review when verification is green")
PY
