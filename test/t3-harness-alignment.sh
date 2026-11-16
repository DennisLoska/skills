#!/usr/bin/env bash
# Regression tests for the T3 Code harness contracts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])

def read(path):
    return (root / path).read_text()

def require(condition, message):
    if not condition:
        raise AssertionError(message)

def section(text, heading):
    require(heading in text, f"missing section: {heading}")
    body = text.split(heading, 1)[1]
    return re.split(r"\n## ", body, maxsplit=1)[0]

def contains(text, needles, label):
    for needle in needles:
        require(needle in text, f"{label}: missing {needle!r}")

agents = read("AGENTS.md")
dispatch = read("skills/dispatch/SKILL.md")
oneshot = read("skills/oneshot/SKILL.md")
council = read("skills/council/SKILL.md")

require(len(agents.splitlines()) <= 150, "AGENTS.md exceeds 150 lines")
require(len(agents.encode()) <= 24576, "AGENTS.md exceeds 24576 bytes")
require(len(agents.encode()) < 24000, "AGENTS.md breaks installer byte limit")

path1 = agents.split("1. **T3 Code orchestration tools available.**", 1)[1]
path1 = path1.split("\n2. **Standalone OpenCode native pin", 1)[0]
contains(path1, (
    "orchestrator_capabilities",
    "omittedModels",
    "Path 4 only if rejected",
    'role',
    'target: { providerInstanceId, model, options }',
    'mode: "async"',
    'mode: "wait"',
    'isolation: "shared"',
    'isolation: "worktree"',
    "clientRequestId",
    "taskId",
    "task_cancel",
    "childThreadId",
    "task_status",
    "next",
    "research",
    "test",
    "implementation",
    "review",
    "design",
), "Path 1")
require(re.search(r"Never pass[^.]*modelSelection[^.]*top-level `provider`[^.]*`cwd`",
                  path1), "Path 1 must prohibit invented envelope keys")
require("Never use `t3_thread_send`, `create_threads`, `t3_thread_launch`, "
        "or `t3_thread_interrupt` on `childThreadId`" in path1,
        "Path 1 must prohibit child-thread control")
require("No scoped-file edits while shared-checkout reviewers run" in path1,
        "Path 1 must freeze shared review scope")

bootstrap = section(dispatch, "## Step 0: Routing Bootstrap")
contains(bootstrap, ("delegate_task", "clientRequestId", "target",
                     "modelSelection"), "dispatch bootstrap")

draft = section(dispatch, "## Draft Delegation Adapter (shape/design/plan only)")
contains(draft, (
    'role: "design"',
    'mode: "async"',
    'mode: "wait"',
    "immediate short result",
    "3-minute",
    "taskId",
    "task_cancel",
    "clientRequestId",
), "draft adapter")
require("`mode: wait` (or `async` for alternative fan-out)" not in draft,
        "draft adapter still defaults to blocking wait")

reviews = section(dispatch, "## Review Stages")
contains(reviews, (
    "Stage 1",
    "spec-reviewer-prompt.md",
    "Stage 2",
    "quality-reviewer-prompt.md",
    "separate, sequential",
    "Never combine",
    'role: "review"',
    'mode: "async"',
    "shared-checkout",
), "task reviews")
require(reviews.index("spec-reviewer-prompt.md")
        < reviews.index("quality-reviewer-prompt.md"),
        "spec review must precede quality review")

lifecycle = (
    "taskId",
    "clientRequestId",
    "childThreadId",
    "task_cancel",
    "task_status",
    "wakeup",
    "replaced",
    "timed-out",
    "aborted",
)
for name, text in (
    ("dispatch", dispatch),
    ("oneshot", oneshot),
    ("council", council),
):
    contains(text, lifecycle, name)
    contains(text, (
        'role: "review"',
        'mode: "async"',
        "target: { providerInstanceId, model, options }",
        "No scoped-file edits while shared-checkout reviewers run",
        "Never poll `task_status` before a completion wakeup",
    ), name)

canonical_keys = (
    "dispatch_adapter",
    "primary_rungs",
    "phase",
    "branch",
    "pr_url",
    "author_models",
    "author_families",
    "author_commits",
    "tests_status",
    "council_round",
    "council_verdict",
    "captain",
    "backlog",
    "soft_cap_counts",
)
for name, text in (("oneshot", oneshot), ("council", council)):
    contains(text, canonical_keys, f"{name} canonical state")
    contains(text, (
        "Preserve all canonical keys",
        "Never overwrite the state artifact with a truncated summary",
        "$(git rev-parse --git-dir)/info/oneshot-state.md",
    ), f"{name} state preservation")

state = section(oneshot, "## State Artifact")
contains(state, ("unknown keys", "standing findings", "earliest_resume",
                 "append", "read-merge-write"), "state update policy")
require("(append or rewrite in place)" not in state,
        "state section still permits an unqualified destructive rewrite")

install = read("test/install.sh")
contains(install, (
    "transport_docs",
    "provider_pattern",
    "transport_pattern",
    "skills/dispatch/SKILL.md",
    "skills/oneshot/SKILL.md",
    "skills/council/SKILL.md",
    "skills/land/SKILL.md",
    "skills/make-ci-green/SKILL.md",
), "bounded installer transport audit")

land = read("skills/land/SKILL.md")
ci = read("skills/make-ci-green/SKILL.md")

for name, text in (("land", land), ("oneshot", oneshot)):
    contains(text, (
        "link_pull_request",
        "link_pull_requests",
        "full PR URL",
        "immediately",
        "created",
        "taken over",
        "pushed",
        "GraphQL",
        "gh api repos/{owner}/{repo}/pulls",
        "existing PR before retrying creation",
        "unwatch_pull_request",
    ), f"{name} PR contract")

for name, text in (("CI", ci), ("oneshot", oneshot)):
    contains(text, (
        "watch_pull_request",
        "unwatch_pull_request",
        "parent thread",
        "delegate_task",
        "one watcher per PR",
        "checks and comments first",
        "branch update",
        "push",
        "link_pull_request",
        "end the turn",
        "wakeup",
        "Outside T3 Code",
        "gh api repos/{owner}/{repo}/commits/{sha}/check-runs",
        "Never run a manual 30-second",
    ), f"{name} watcher contract")
    require(re.search(r"children[^.]*never[^.]*watch_pull_request", text),
            f"{name}: children must not own watchers")

for name, text in (("land", land), ("CI", ci), ("oneshot", oneshot)):
    contains(text, (
        "before handback",
        "stopping",
        "asking the user a question",
        "unwatch_pull_request",
    ), f"{name} watcher cleanup")

phase5 = section(oneshot, "## Phase 5: LAND - push and file the PR")
phase65 = section(oneshot, "## Phase 6.5: MAKE-CI-GREEN")
phase7 = section(oneshot, "## Phase 7: FINISH")
contains(phase5, ("link_pull_request", "GraphQL", "existing PR"),
         "oneshot Phase 5")
contains(phase65, ("watch_pull_request", "parent thread", "end the turn",
                   "check-runs"), "oneshot Phase 6.5")
contains(phase7, ("link_pull_request", "unwatch_pull_request",
                  "watch_pull_request", "GraphQL"), "oneshot Phase 7")

t3loop = section(ci, "## T3 Code reactive monitoring")
standalone = section(ci, "## Non-T3 CLI loop")
require("sleep" not in t3loop and "30-second wait" not in t3loop,
        "T3 monitoring must not contain a sleep/poll loop")
contains(standalone, ("30-second wait", "10 minutes", "3 polls"),
         "standalone bounded polling")
contains(ci, ("fix_rounds", "Stop at 3", "CI green at <sha>"),
         "existing CI completion and retry caps")
contains(land, ("--method POST", "--method GET", "--method PATCH",
                "head=", "state=open", "head.sha", "html_url"),
         "REST PR recovery")

contains(land, ("base=$base", "base.ref", "git symbolic-ref refs/remotes/origin/HEAD",
                "state=all", "422", "before the step 1 push",
                "fresh branch with no existing PR", "--paginate"),
         "REST PR target, recovery, ordering and pagination")
contains(phase65, ("only when checks or reviews remain pending", "proceed directly to step 4",
                   "re-enters step 3/4 before any green handoff"),
         "oneshot conditional monitoring and wakeup re-entry")
contains(phase7, ("Do not remove state when merely awaiting a watcher wakeup",),
         "oneshot state retention")
require(phase7.count("Do not remove state when merely awaiting a watcher wakeup") == 2,
        "oneshot lifecycle and completion step must both retain state during wakeup waits")
for name, loop in (("T3", t3loop), ("non-T3", standalone)):
    contains(loop, ("Shared finding and flake handling",), f"{name} shared CI handling")

print("T3 PR linking and watcher contracts passed")
print("T3 delegation and state contracts passed")
PY
