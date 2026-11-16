# T3 Code Harness Alignment Implementation Plan

> **For agentic workers:** REQUIRED SKILL: invoke the dispatch skill via the skill tool to implement this plan task-by-task. Execution is subagent-driven only: never execute inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align delegation, durable state, PR linking, and CI monitoring with T3 Code’s async lifecycle while preserving standalone operation and existing council availability semantics.

**Auto-approved:** auto-approve: true

**Architecture:** Keep the authoritative delegation contract in `AGENTS.md` and repeat the operational requirements at the relevant skill entry points. Use documentation regression tests rather than introducing a runtime wrapper. Execute the two tasks sequentially because both modify `skills/oneshot/SKILL.md` and `test/t3-harness-alignment.sh`.

**Tech Stack:** Markdown skill contracts, Bash, Python 3 standard library, GitHub CLI, T3 Code MCP tools.

---

Save this plan as `docs/plans/2026-11-16-t3-harness-alignment.md`.

All paths below are relative to `/home/dennis/.t3/worktrees/skills/feat-t3-harness-alignment`.

Approved specification: `docs/specs/2026-11-16-t3-harness-alignment-design.md`.

Implementation preserves the `2cacea1` council semantics: self-review remains allowed, unavailable reviewers are skipped, and `SKIPPED mode=unavailable` remains mergeable with the required evidence and green actual verification. Provider/model selection, privacy gates, effort ceilings, routing ladders, review budgets, and merge evidence rules remain governed by the existing harness.

## File responsibilities and constraints

| File | Responsibility |
| --- | --- |
| `AGENTS.md` | Authoritative, compact Path 1 delegation contract |
| `skills/dispatch/SKILL.md` | Bootstrap, draft delegation, sequential task reviews |
| `skills/oneshot/SKILL.md` | Phase integration, durable state, PR and watcher lifecycle |
| `skills/council/SKILL.md` | Async seat/ruling dispatch and stable review scope |
| `skills/land/SKILL.md` | PR linking, REST recovery, merge-wait cleanup |
| `skills/make-ci-green/SKILL.md` | Parent-owned reactive watcher lifecycle and standalone polling |
| `test/t3-harness-alignment.sh` | Focused documentation contract regression tests |
| `test/install.sh` | Narrow compatibility adjustment to the existing transport-name audit |

`AGENTS.md` currently has 142 lines and 23,307 bytes. The approved limits are 150 lines and 24,576 bytes, but `test/install.sh` already requires **strictly fewer than 24,000 bytes**. Meet both limits by replacing Path 1 in place, preserving its single physical line, and keeping the resulting file below 24,000 bytes. Do not weaken the installer’s size assertion.

The existing installer audit bans T3 transport names outside the draft adapter. Updating that audit narrowly is necessary for the approved skill changes; do not remove the provider-name or model-ID audits.

No new runtime scripts, provider profiles, dependencies, or agent contracts are required.

### Task 1: T3 Code Delegation Contract, Async Lifecycle & State Preservation

**Files:**

- Modify: `AGENTS.md`, `## Dispatch Adapter`, Path 1
- Modify: `skills/dispatch/SKILL.md`, Step 0, Draft Delegation Adapter, Review Stages, final fix-loop instructions
- Modify: `skills/oneshot/SKILL.md`, Phase 3, Phase 6, State Artifact
- Modify: `skills/council/SKILL.md`, Request phase, Captain ruling, Output format
- Modify: `test/install.sh`, section 74 transport-name audit
- Create: `test/t3-harness-alignment.sh`

**Seams preserved:** profile-driven dispatch, task-review stages, council round evidence, worktree-local state.

- [ ] **Step 1: Tester writes the failing delegation regression test**

Create `test/t3-harness-alignment.sh` with the following complete content. These tests inspect documentation because the behavior being changed is the agent-facing contract; they do not pretend to execute MCP tools.

```bash
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

print("T3 delegation and state contracts passed")
PY
```

Leave the tests uncommitted.

- [ ] **Step 2: Tester confirms red**

Run:

```bash
bash test/t3-harness-alignment.sh
```

Expected: nonzero exit with an assertion identifying the missing exact Path 1 envelope, initially `target: { providerInstanceId, model, options }`. Do not weaken assertions to accommodate the old documentation.

Return the failure excerpt and test path to the implementer.

- [ ] **Step 3: Implementer replaces Path 1 without expanding AGENTS.md beyond its limits**

Replace only the existing Path 1 paragraph with the following **single physical Markdown line**:

```markdown
1. **T3 Code orchestration tools available.** Discover eager, deferred/tool-search, ACP and `<mcp_servers>` tools; lazy schemas: `<appDataDir>/brain/<conversation-id>/mcp/t3-code/{orchestrator_capabilities,delegate_task}.json` (read once; `call_mcp_tool`). While `delegate_task` is present, NEVER use Path 2/3 native tools. Call `orchestrator_capabilities` once before dispatch; missing/disabled providers or invalid options hit Path 4; try `omittedModels` catalog IDs (Path 4 only if rejected). Envelope: `role`, `target: { providerInstanceId, model, options }`, `task` (self-contained brief), fresh `clientRequestId` per dispatch/round, `mode: "async"` default; `mode: "wait"` only for an immediate short result required this turn; `isolation: "shared"` default, `isolation: "worktree"` for overlapping parallel edits. Resolve target/options from `PROVIDERS.md`; `-` means `{}` only after verifying a safe default; otherwise set safe explicit options or mark unreachable (matching-driver `serviceTier=default` allowed). Never pass `modelSelection`, top-level `provider`, or `cwd`. Roles: `research`=scout, `test`=tester, `implementation`=implementer*/patch, `review`=reviewer-*/captain/task-reviewer, `design`=designer/planner/alternatives. Save `taskId`; `childThreadId` is storage only. Never use `t3_thread_send`, `create_threads`, `t3_thread_launch`, or `t3_thread_interrupt` on `childThreadId`. Follow `next`; end the turn for async completion wakeup, never poll `task_status` before wakeup. Timeout/missing reply is not approval or child termination: `task_cancel` by `taskId` for replaced/timed-out/aborted runs before replacement. No scoped-file edits while shared-checkout reviewers run.
```

Retain the surrounding role-contract path rules, Paths 2–4, routing rules, council availability, effort rules, and permission contracts.

Run:

```bash
wc -l -c AGENTS.md
```

Expected: no more than 150 lines and fewer than 24,000 bytes.

- [ ] **Step 4: Implementer aligns dispatch bootstrap and draft delegation**

Append this sentence to Step 0 check 2 in `skills/dispatch/SKILL.md`, keeping the four existing bootstrap checks:

```markdown
For Path 1, validate the `delegate_task` envelope before calling: `target: { providerInstanceId, model, options }`, explicit role, fresh `clientRequestId`, async default and selected isolation; never pass `modelSelection`, top-level `provider`, or `cwd`.
```

Replace Draft Delegation Adapter procedure step 3 with:

```markdown
3. T3 Code: call `orchestrator_capabilities` once before the first dispatch, then `delegate_task` with `role: "design"`, `target: { providerInstanceId, model, options }` resolved from the selected profile rung, `isolation: "shared"`, a self-contained `task` brief and fresh `clientRequestId`. Use `mode: "async"` by default so long drafts do not hit the 3-minute MCP call deadline; `mode: "wait"` is permitted only when this turn requires an immediate short result. Never pass `modelSelection`, top-level `provider`, or `cwd`. Apply the delegate lifecycle below. Native Path 3 retains explicit profile model/options and the existing host reachability and safe-default checks; these ad-hoc roles have no native seat pin or agent file.
```

Replace procedure step 5 with:

```markdown
5. Receive the draft through the delegate lifecycle below; follow `next` and end the turn when awaiting an async completion wakeup. Driver reads it against canonical docs and requirements, resolves open questions with the user, applies the draft to canonical artifacts, self-reviews and owns approvals, commits and phase advancement. Draft-only work does not enter code `author_models`/`author_families`; actual code authors still do. Author metadata is audit-only.
```

Immediately after the draft procedure, add:

```markdown
**T3 Code delegate lifecycle:** Save every returned `taskId` with its role, rung, scope and fresh `clientRequestId`; use a new request ID for every dispatch, replacement and review round. Retain `childThreadId` as storage/reference only. Never use `t3_thread_send`, `create_threads`, `t3_thread_launch`, or `t3_thread_interrupt` on `childThreadId`. Follow the returned `next`; end the turn when waiting for reactive completion. Never poll `task_status` before a completion wakeup. A timeout or missing reply neither approves work nor terminates the child: call `task_cancel` with the saved `taskId` for replaced, timed-out or aborted runs before starting a replacement. If the task ID was not returned, retain the original `clientRequestId` for recovery through the authoritative tool schema; do not blindly launch a duplicate.

**Shared review scope:** No scoped-file edits while shared-checkout reviewers run. The driver and all delegates must keep the reviewed files unchanged until every reviewer of that scope completes or is cancelled. Resolve cancellation before dispatching fixers; use `isolation: "worktree"` for overlapping parallel edits.
```

- [ ] **Step 5: Implementer makes the two task-review dispatches explicitly sequential**

Replace the two stage bullets and following reviewer-edit paragraph in `skills/dispatch/SKILL.md`, `## Review Stages`, with:

```markdown
- **Stage 1, spec compliance:** dispatch a fresh task-reviewer using `spec-reviewer-prompt.md`; verify the implementer built what was requested, nothing more, nothing less, and preserved tester-written tests unless the report supplies a valid reason.
- **Stage 2, code quality:** after Stage 1 passes or is explicitly recorded unavailable, dispatch another fresh task-reviewer using `quality-reviewer-prompt.md`; verify the implementation is well-built. Unresolved Stage 1 findings block Stage 2.

These are separate, sequential dispatches. Never combine Stage 1 and Stage 2 into one prompt or launch them concurrently. In T3 Code each uses `delegate_task` with `role: "review"`, `mode: "async"`, `target: { providerInstanceId, model, options }`, a fresh `clientRequestId`, a self-contained `task` and the selected isolation. Apply the saved `taskId`/`task_cancel` lifecycle above to every initial review and re-check.

No scoped-file edits while shared-checkout reviewers run. Reviewers do not edit; driver and implementation delegates also wait until all reviewers of that scope finish or are cancelled. Fixes and re-checks use fresh dispatches, including fresh task IDs and request IDs. The same model may author and review. Record unavailable stages as skipped after configured fallbacks; unresolved findings still block.
```

Near the end of the file, replace:

```markdown
**If the reviewer finds issues:** the implementer (same subagent) fixes them, reviewer reviews again, repeat until approved.
```

with:

```markdown
**If the reviewer finds issues:** after the reviewer completes or is cancelled, dispatch a fresh fixer for the confirmed findings and then a fresh reviewer re-check with the findings and objections in its brief; repeat until approved.
```

Keep the existing fix-attempt and debug-rotation caps following that sentence.

- [ ] **Step 6: Implementer adds the council and oneshot review lifecycle**

Insert the following complete block:

- In `skills/council/SKILL.md`, after the Request phase step 4 paragraph.
- In `skills/oneshot/SKILL.md`, immediately before `## Phase 3: DISPATCH`.

```markdown
**T3 Code review dispatch:** Every task-review stage, council seat and captain ruling uses `delegate_task` with `role: "review"`, `mode: "async"`, `target: { providerInstanceId, model, options }` resolved from its permitted profile rung, a fresh `clientRequestId`, a self-contained `task` and `isolation: "shared"` for the stable review checkout. Never pass `modelSelection`, top-level `provider`, or `cwd`. Save the returned `taskId` with the reviewed HEAD, scope, seat/stage, rung and request ID; every re-check, replacement and round gets a new request ID and fresh dispatch.

**Delegate lifecycle:** Retain `childThreadId` as storage/reference only; never use `t3_thread_send`, `create_threads`, `t3_thread_launch`, or `t3_thread_interrupt` on it. Follow `next` and end the turn when awaiting a reactive completion wakeup. Never poll `task_status` before a completion wakeup. Timeout or missing output is neither approval nor child termination: call `task_cancel` with the saved `taskId` for replaced, timed-out or aborted runs before starting a replacement. A missing task ID requires recovery using the original request ID and authoritative tool schema, never a blind duplicate.

**Shared review scope:** No scoped-file edits while shared-checkout reviewers run. Driver and delegates wait for every active reviewer of that scope to finish or be cancelled before any fixer edits. Council seats may review the same frozen scope in parallel; task-review stages remain sequential. Overlapping parallel editing requires `isolation: "worktree"` and a fresh review of the integrated result.
```

In `skills/oneshot/SKILL.md`, Phase 3 step 3, append:

```markdown
Stage 1 and Stage 2 are separate, sequential dispatches; never combine their prompts. Await Stage 1 completion and resolve its findings, or record its configured unavailability, before dispatching Stage 2.
```

In `skills/council/SKILL.md`, Captain ruling’s `**Dispatch:**` paragraph, append:

```markdown
This is a new `role: "review"`, `mode: "async"` dispatch with a new `clientRequestId` and saved `taskId`; apply the review lifecycle and shared-scope freeze above.
```

In `skills/oneshot/SKILL.md`, Phase 6 step 4, append:

```markdown
Apply the T3 Code review envelope and saved-task lifecycle above; the ruling is a fresh dispatch, never a message to a previous child thread.
```

- [ ] **Step 7: Implementer makes state updates lossless**

Insert this exact paragraph:

- In `skills/oneshot/SKILL.md`, directly under `## State Artifact`.
- In `skills/council/SKILL.md`, immediately before `State artifact lines`.

```markdown
**Lossless state updates:** Preserve all canonical keys in `$(git rev-parse --git-dir)/info/oneshot-state.md`: `dispatch_adapter`, `primary_rungs`, `phase`, `branch`, `pr_url`, `author_models`, `author_families`, `author_commits`, `tests_status`, `council_round`, `council_verdict`, `captain`, `backlog`, and `soft_cap_counts`. Preserve existing values unless the current event explicitly updates them, and preserve unknown keys, standing findings, `earliest_resume`, member attempts/skips, votes, rulings, backlog filing receipts and task lifecycle records. Use append for event history or read-merge-write for a keyed update, retaining unrelated content and the effective-last-verdict convention. Never overwrite the state artifact with a truncated summary. A council-only run creates missing state but merges with existing pipeline state; it never replaces routing or author history.
```

In the long existing State Artifact paragraph in `skills/oneshot/SKILL.md`, replace:

```markdown
(append or rewrite in place)
```

with:

```markdown
(using the lossless append or read-merge-write policy above)
```

Retain the existing state location, worktree behavior, phase activation timing, resume rules, and Phase 7 cleanup. Do not add state writes to Step 0 before the feature branch/worktree is active.

- [ ] **Step 8: Implementer narrows the installer audit exception**

In `test/install.sh`, section 74, replace the Python block starting at:

```bash
if python3 - "$ROOT" >"$TMPROOT/host-74.out" <<'PYHOST'
```

and ending at its matching `fi` with:

```bash
if python3 - "$ROOT" >"$TMPROOT/host-74.out" <<'PYHOST'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
provider_pattern = re.compile(r'opencode|antigravity|codex|claude', re.I)
transport_pattern = re.compile(
    r't3[-_ ]code|delegate_task|orchestrator_capabilities', re.I
)
transport_docs = {
    'skills/dispatch/SKILL.md',
    'skills/oneshot/SKILL.md',
    'skills/council/SKILL.md',
    'skills/land/SKILL.md',
    'skills/make-ci-green/SKILL.md',
}
found = False
for folder in ('skills', 'agents'):
    for path in sorted((root / folder).rglob('*')):
        if not path.is_file():
            continue
        relative = path.relative_to(root).as_posix()
        draft_adapter = False
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if line.startswith('## '):
                draft_adapter = (
                    relative == 'skills/dispatch/SKILL.md'
                    and line == '## Draft Delegation Adapter (shape/design/plan only)'
                )
            provider_violation = provider_pattern.search(line) and not draft_adapter
            transport_violation = (
                transport_pattern.search(line)
                and not draft_adapter
                and relative not in transport_docs
            )
            if provider_violation or transport_violation:
                print(f'{path}:{number}:{line}')
                found = True
sys.exit(0 if found else 1)
PYHOST
then
  cat "$TMPROOT/host-74.out" >&2
  fail "provider names remain draft-only; T3 transports stay in approved lifecycle skills"
fi
```

Update the immediately preceding audit comment to:

```bash
# Draft handoff may name provider transports. The five lifecycle skills may
# name T3 tools; provider names elsewhere and model IDs remain forbidden.
```

There are five modified skill files in this allowlist, plus `AGENTS.md` as the sixth lifecycle document. `AGENTS.md` is outside this `skills/` and `agents/` audit.

Keep the separate existing model-ID leak audit, all size assertions, and all council availability assertions intact.

- [ ] **Step 9: Implementer verifies green and commits**

Run:

```bash
bash test/t3-harness-alignment.sh
bash test/council-availability.sh
bash test/council-effort.sh
bash test/install.sh
git diff --check
```

Expected:

- New test prints `T3 delegation and state contracts passed`.
- Council availability and effort tests exit 0.
- Installer reports all tests passed and zero failures.
- Diff check exits 0 without output.

Commit tests and implementation together:

```bash
git add AGENTS.md skills/dispatch/SKILL.md skills/oneshot/SKILL.md skills/council/SKILL.md test/install.sh test/t3-harness-alignment.sh
git commit -m "fix: align T3 delegation and preserve harness state"
```

Run the two sequential task-review stages after the implementer finishes. Keep scoped files frozen throughout each shared-checkout review.

### Task 2: T3 Code PR Linking, GraphQL-to-REST Fallback & Watcher Lifecycle

**Depends on:** Task 1.

**Files:**

- Modify: `skills/land/SKILL.md`, Parts 1–3 and Rules
- Modify: `skills/make-ci-green/SKILL.md`, Loop, Prevents, Exit
- Modify: `skills/oneshot/SKILL.md`, Phases 5, 6.5, 7
- Modify: `test/t3-harness-alignment.sh`

**Seams preserved:** full-URL PR identity, parent-owned monitoring, final-HEAD verification, existing non-T3 CLI behavior.

- [ ] **Step 1: Tester adds failing PR lifecycle assertions**

In `test/t3-harness-alignment.sh`, insert the following Python code immediately before the existing final `print("T3 delegation and state contracts passed")`:

```python
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

print("T3 PR linking and watcher contracts passed")
```

Leave the added assertions uncommitted.

- [ ] **Step 2: Tester confirms red**

Run:

```bash
bash test/t3-harness-alignment.sh
```

Expected: nonzero exit for the missing `link_pull_request` contract in `skills/land/SKILL.md`. Task 1 assertions must still pass before the new failure.

- [ ] **Step 3: Implementer adds immediate PR linking and REST fallback to land**

In `skills/land/SKILL.md`, Part 1 step 2, replace the current create-only instruction with:

```markdown
2. Inspect whether the branch already has an open PR before creating one. Use `gh pr view` normally, then `gh pr create --title <short> --body-file /tmp/pr-body.md` only when none exists. If GraphQL rate limits block `gh pr create`, `gh pr view` or `gh pr checks`, use the REST recovery procedure below; always check for an existing PR before retrying creation.
```

Immediately after Part 1 step 4, insert:

```markdown
### T3 Code PR identity and REST recovery

In T3 Code, immediately after a PR is created, taken over or pushed, make the next tool call `link_pull_request` with the full PR URL; use `link_pull_requests` for multiple PRs and include every stack layer. If the PR already exists, resolve its URL before pushing so linking can follow the push immediately. Links persist across pushes, but linking remains required after the work described here. Report a linking failure; do not silently substitute a title, branch name or bare PR number.

For GitHub GraphQL rate limits, use `gh api repos/{owner}/{repo}/pulls` through REST. Resolve `owner` and `repo` from the repository remote, `head_owner` from the pushed head repository, and `branch` and `base` from the actual PR branches. Use `gh api --method GET 'repos/{owner}/{repo}/pulls' -f state=open -f "head=$head_owner:$branch"` to check for an existing PR before retrying creation. Confirm the returned head repository and branch match the intended PR. Reuse its `html_url` and number; do not create a duplicate after an ambiguous CLI error.

If no matching PR exists, use `gh api --method POST 'repos/{owner}/{repo}/pulls' -f "title=$pr_title" -f "head=$head_owner:$branch" -f "base=$base" -F body=@/tmp/pr-body.md`. The `pr_title` variable holds the intended PR title; the body remains in the previously written file. Recover PR details with `gh api --method GET "repos/{owner}/{repo}/pulls/$pr_number"`; use `html_url` for linking and `head.sha` for remote-head verification. If a PR body update hits the same GraphQL limit, use `gh api --method PATCH "repos/{owner}/{repo}/pulls/$pr_number" -F body=@/tmp/pr-body.md`. The `pr_number` variable is the number returned by the matching GET or successful POST.

For GraphQL-limited checks, inspect `gh api repos/{owner}/{repo}/commits/{sha}/check-runs` through REST, with `sha` set to the current remote PR head. Also inspect paginated combined commit statuses and review/comment endpoints when needed; check-runs alone do not prove every required check or review is satisfied. A REST transport fallback never relaxes the same-head merge, review or verification gates.
```

The brace notation in `gh api repos/{owner}/{repo}` uses GitHub CLI’s supported repository substitution. `sha` is the fetched remote head, not an invented fixed hash.

- [ ] **Step 4: Implementer adds land watcher ownership and cleanup**

Before Part 2’s auto-approve paragraph, add:

```markdown
**T3 Code watcher ownership:** Only the parent thread owning the PR calls `watch_pull_request`; delegate_task children never call `watch_pull_request`. If an authorized merge is waiting on checks or reviews, inspect checks and comments first, finish any needed branch update and push, immediately call `link_pull_request` with the full PR URL, then maintain one watcher per PR with `watch_pull_request` and end the turn for T3 Code's wakeup. Do not use a manual CLI polling loop in T3 Code. Revalidate the current remote head and existing merge evidence on wakeup.

Call `unwatch_pull_request` before handback, stopping, or asking the user a question, and before the next-feature handoff. The async turn ending solely to await a requested watcher wakeup keeps the watcher active; it is not a completed handback. Outside T3 Code, retain the existing CLI check and merge flow.
```

At the start of Part 3 add:

```markdown
Before this handoff in T3 Code, call `unwatch_pull_request` for each PR monitored by this parent thread.
```

Preserve all merge-verdict rules and finish options.

- [ ] **Step 5: Implementer separates reactive monitoring from standalone polling**

In `skills/make-ci-green/SKILL.md`, insert the following before the existing `## Loop`, then rename `## Loop` to `## Non-T3 CLI loop`.

```markdown
## T3 Code reactive monitoring

Use this path in T3 Code. Inspect existing checks and comments first, including reviews and unresolved bot findings; do useful diagnosis before registering a watcher. Failing logs and local reproduction still go through tester, and confirmed findings still go through fresh implementation-seat fixers.

Only the parent thread owning the PR calls `watch_pull_request`; delegate_task children never call `watch_pull_request`. Children return the full PR URL, head SHA, check/review state and remaining blockers to their parent.

Finish any needed branch update and push before waiting. Immediately after a PR is created, taken over or pushed, call `link_pull_request` with the full PR URL as the next tool call; use `link_pull_requests` for multiple PRs. Resolve an existing PR URL before the push. Then use `watch_pull_request`, maintain one watcher per PR, and end the turn to await T3 Code's reactive wakeup. An existing watcher remains valid across pushes; do not create a duplicate.

Never run a manual 30-second `gh pr checks` polling loop in T3 Code. On wakeup, inspect the new checks/comments and current remote HEAD, classify new information, fix confirmed findings within the existing caps, and watch again only when work still waits on checks or reviews. Preserve fix counters and the monitored head across wakeups. Green evidence must match the final head.

When `gh pr checks` or `gh pr view` hits GraphQL rate limits, use `gh api repos/{owner}/{repo}/commits/{sha}/check-runs` for checks and REST PR, review and comment endpoints for the remaining evidence. Resolve the current remote PR head before querying check runs; paginate responses and inspect combined commit statuses when required. Do not infer green from an empty or incomplete check-runs response.

Call `unwatch_pull_request` before handback, stopping, or asking the user a question, and when monitoring completes or is cancelled. Ending a turn solely to await the requested reactive wakeup keeps the watcher active; completed handoff to council does not.

Outside T3 Code, use the bounded CLI loop below.
```

Retain the existing bounded CLI loop, including:

- 30-second wait;
- ten-minute total cap;
- three unchanged polls;
- three fix rounds;
- single evidence-backed flake rerun;
- existing finding classification and fixer routing.

In `## Prevents`, replace:

```markdown
- Silent reds (announcement each poll: state summary in one line)
```

with:

```markdown
- Silent reds (announce the state on each reactive wakeup or non-T3 CLI poll)
```

Append to `## Exit`:

```markdown
In T3 Code, call `unwatch_pull_request` before returning green to council or reporting a stop. Retain the watcher only when ending the turn to await its requested wakeup.
```

- [ ] **Step 6: Implementer connects the oneshot phases**

In `skills/oneshot/SKILL.md`, replace Phase 5 step 3 with:

```markdown
3. Save the full PR URL as `pr_url` using the lossless state policy. In T3 Code, immediately after the PR is created, taken over or pushed, make the next tool call `link_pull_request` with the full PR URL, or `link_pull_requests` for multiple PRs. Resolve an existing PR URL before pushing. If `gh pr create`, `gh pr view` or `gh pr checks` hits GraphQL rate limits, follow land's REST fallback using `gh api repos/{owner}/{repo}/pulls`; check for an existing PR before retrying creation. Reuse `html_url`, and preserve all existing same-head evidence.
```

After Phase 6.5 step 2, add:

```markdown
3. In T3 Code, the parent thread inspects checks and comments first, finishes any needed branch update and push, immediately calls `link_pull_request` with the full PR URL, then uses `watch_pull_request` with one watcher per PR and ends the turn for a reactive wakeup. delegate_task children never call `watch_pull_request`; they report PR URL, head SHA, check/review state and blockers to the parent. Existing watchers persist across pushes; avoid duplicates. Never run a manual 30-second polling loop in T3 Code. On wakeup, re-read current checks/comments and remote HEAD before acting. For GraphQL-limited checks use `gh api repos/{owner}/{repo}/commits/{sha}/check-runs`, plus paginated commit-status/review evidence as needed. Outside T3 Code, retain make-ci-green's bounded CLI polling flow.
4. Call `unwatch_pull_request` before handback, stopping, or asking the user a question, including the completed handoff to council. A turn ending solely to await the requested watcher wakeup keeps monitoring active. Preserve phase, head and fix counters across wakeups; do not mark CI green until actual checks on the final HEAD are green.
```

In Phase 7, immediately before existing step 1, add:

```markdown
**T3 Code finish lifecycle:** If finishing creates, takes over or pushes to a PR, immediately call `link_pull_request` with the full PR URL, or `link_pull_requests` for multiple PRs. On GraphQL rate limits use land's REST PR/check recovery, checking for an existing PR before retrying creation. If an authorized merge still waits on checks or reviews, inspect current evidence, complete any branch update/push and linking, then call parent-owned `watch_pull_request` and end the turn. Revalidate merge evidence and remote HEAD on wakeup. Call `unwatch_pull_request` before handback, stopping, or asking the user a question; only a turn ending to await the requested watcher wakeup retains it.
```

Keep Phase 7’s verdict, final-head, backlog, finish-choice, and state-removal rules intact. Do not remove state when merely awaiting a watcher wakeup.

- [ ] **Step 7: Implementer verifies the complete change**

Run from the feature worktree:

```bash
bash test/t3-harness-alignment.sh
bash test/council-availability.sh
bash test/council-effort.sh
bash test/install.sh
git diff --check
wc -l -c AGENTS.md
```

Expected:

- Alignment test prints both:
  - `T3 PR linking and watcher contracts passed`
  - `T3 delegation and state contracts passed`
- Availability and effort suites exit 0.
- Installer reports all tests passed and zero failures.
- Diff check exits 0.
- `AGENTS.md` stays at most 150 lines and below 24,000 bytes.

These are documentation contract checks. Do not create a live PR, launch delegates, or register watchers merely to test the documentation.

- [ ] **Step 8: Implementer commits**

```bash
git add skills/land/SKILL.md skills/make-ci-green/SKILL.md skills/oneshot/SKILL.md test/t3-harness-alignment.sh
git commit -m "fix: align T3 PR linking and reactive CI monitoring"
```

Run Stage 1 spec review and then Stage 2 quality review as fresh sequential dispatches, freezing the shared scope during each review.

## Phase 2 decisions and handoff

- Two sequential tasks keep changes reviewable and avoid overlapping edits.
- `test/install.sh` receives a narrow transport audit adjustment because its current blanket ban conflicts with the approved operational instructions.
- Watcher waiting and completed handback are distinguished explicitly: pending reactive waits retain monitoring; completed handoff, stops, and user questions cancel it.
- State preservation covers canonical and unknown keys, so future fields survive council updates.
- Existing council availability and effort suites remain mandatory compatibility gates.
- No repository files were changed and no verification commands were executed during this read-only draft.

Gate 2 is auto-satisfied by `auto-approve: true`. Return this draft to the driver to save and commit the canonical plan, then let oneshot invoke Phase 3 dispatch.
