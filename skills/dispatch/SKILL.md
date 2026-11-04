---
name: dispatch
description: Use when executing an implementation plan with independent tasks in the current session, dispatching implementation or review subagents per task, fanning out parallel agents on independent problems, or oneshot Phase 3
---

# Dispatch

Execute a plan by dispatching a fresh subagent per task, with two-stage review after each: spec compliance review first, then code quality review.

**Why subagents:** delegate tasks to agents with isolated context. By precisely crafting their instructions and context, they stay focused and succeed at their task. They never inherit this session's context or history: construct exactly what they need. This also preserves the main session's context for coordination work.

**Core principle:** fresh subagent per task + two-stage review (spec then quality) = high quality, fast iteration.

**Continuous execution:** do not pause to check in with the user between tasks. Execute all tasks from the plan without stopping. The only reasons to stop: BLOCKED status that cannot be resolved, ambiguity that genuinely prevents progress, or all tasks complete. "Should I continue?" prompts and progress summaries waste the user's time. They asked for the plan to run, so run it.

**Oneshot is the hub:** this skill is Phase 3 of the oneshot pipeline. Never delegate a whole plan or the whole pipeline to one subagent. Executing a plan always happens here; the main session orchestrates, subagents execute.

## When to Use

```dot
digraph when_to_use {
    "Have implementation plan?" [shape=diamond];
    "Tasks mostly independent?" [shape=diamond];
    "Run in this session?" [shape=diamond];
    "dispatch" [shape=box];
    "shape first" [shape=box];
    "Manual execution" [shape=box];

    "Have implementation plan?" -> "Tasks mostly independent?" [label="yes"];
    "Have implementation plan?" -> "shape first" [label="no"];
    "Tasks mostly independent?" -> "Run in this session?" [label="yes"];
    "Tasks mostly independent?" -> "Manual execution" [label="no - tightly coupled"];
    "Run in this session?" -> "dispatch" [label="yes"];
}
```

**vs manual execution:**
- Fresh subagent per task, no context pollution
- Two-stage review after each task: spec compliance first, then code quality
- Faster iteration, no human-in-loop between tasks
- Subagents can ask questions before and during work

## Working Branch

Work in place on a feature branch from a clean tree. Create the branch if none exists. No worktrees. Never develop on master or main without explicit user consent; master advances only via PR merge (the land skill handles that).

## The Process

```dot
digraph process {
    rankdir=TB;

    subgraph cluster_per_task {
        label="Per Task";
        "Dispatch implementer seat (agent: implementer, brief: implementer-prompt.md)" [shape=box];
        "Implementer asks questions?" [shape=diamond];
        "Answer questions, provide context" [shape=box];
        "Implementer implements, tests, commits or stages (parallel mode), self-reviews" [shape=box];
        "Dispatch spec reviewer subagent (spec-reviewer-prompt.md)" [shape=box];
        "Spec reviewer confirms code matches spec?" [shape=diamond];
        "Implementer fixes spec gaps" [shape=box];
        "Dispatch quality reviewer subagent (quality-reviewer-prompt.md)" [shape=box];
        "Quality reviewer approves?" [shape=diamond];
        "Implementer fixes quality issues" [shape=box];
        "Mark task complete in the todo list" [shape=box];
    }

    "Read plan once, extract all tasks with full text, create todo list" [shape=box];
    "More tasks remain?" [shape=diamond];
    "Dispatch final reviewer subagent for entire implementation" [shape=box];
    "Return to the controller with the final review verdict" [shape=box];
    "Oneshot: controller moves to verify (Phase 4), then land (Phase 5)" [shape=box style=filled fillcolor=lightgreen];
    "Standalone: run the verify skill yourself, then land" [shape=box];

    "Read plan once, extract all tasks with full text, create todo list" -> "Dispatch the implementer seat agent with the brief from implementer-prompt.md";
    "Dispatch the implementer seat agent with the brief from implementer-prompt.md" -> "Implementer asks questions?";
    "Implementer asks questions?" -> "Answer questions, provide context" [label="yes"];
    "Answer questions, provide context" -> "Dispatch the implementer seat agent with the brief from implementer-prompt.md";
    "Implementer asks questions?" -> "Implementer implements, tests, commits, self-reviews" [label="no"];
    "Implementer implements, tests, commits, self-reviews" -> "Dispatch spec reviewer subagent (spec-reviewer-prompt.md)";
    "Dispatch spec reviewer subagent (spec-reviewer-prompt.md)" -> "Spec reviewer confirms code matches spec?";
    "Spec reviewer confirms code matches spec?" -> "Implementer fixes spec gaps" [label="no"];
    "Implementer fixes spec gaps" -> "Dispatch spec reviewer subagent (spec-reviewer-prompt.md)" [label="re-review"];
    "Spec reviewer confirms code matches spec?" -> "Dispatch quality reviewer subagent (quality-reviewer-prompt.md)" [label="yes"];
    "Dispatch quality reviewer subagent (quality-reviewer-prompt.md)" -> "Quality reviewer approves?";
    "Quality reviewer approves?" -> "Implementer fixes quality issues" [label="no"];
    "Implementer fixes quality issues" -> "Dispatch quality reviewer subagent (quality-reviewer-prompt.md)" [label="re-review"];
    "Quality reviewer approves?" -> "Mark task complete in the todo list" [label="yes"];
    "Mark task complete in the todo list" -> "More tasks remain?";
    "More tasks remain?" -> "Dispatch implementer seat (agent: implementer)" [label="yes"];
    "More tasks remain?" -> "Dispatch final reviewer subagent for entire implementation" [label="no"];
    "Dispatch final reviewer subagent for entire implementation" -> "Return to the controller with the final review verdict";
    "Return to the controller with the final review verdict" -> "Oneshot: controller moves to verify (Phase 4), then land (Phase 5)" [label="running as Phase 3"];
    "Return to the controller with the final review verdict" -> "Standalone: run the verify skill yourself, then land" [label="no oneshot"];
}
```

Final handoff: return to the controller with the final review verdict. Inside the oneshot pipeline, the controller moves to verify (Phase 4) and then land (Phase 5). Do not call land from inside dispatch when running as Phase 3 - oneshot owns the phase ordering.

Standalone (no oneshot): after final review PASS, run the verify skill yourself, then land.

## Model Routing

Skills never hardcode model IDs. Route every subagent through the AGENTS.md ladder ("Model Tank"), by role. Named seat agents pin their primary in the agent file; ad-hoc dispatches must always pass an explicit `model` field so nothing inherits the main session model by accident.

**Three implementation seats exist** (models and effort levels pinned in their agent files; ladders in AGENTS.md "Model Tank"):
- `implementer` and `implementer-b` - the two default high-allowance implementation seats (medium effort class). Alternate or pick either for standard and mechanical tasks (`implementer` for confidential briefs).
- `implementer-deep` - the heavy-reasoning seat (`#high` effort) reserved for complex multi-file architecture tasks and difficult bugs escalated by `debug`.

Per-task dispatch = one of the three seats + the brief from `implementer-prompt.md`. On a usage-limit/429 error from a seat: re-dispatch the same seat agent id with an explicit `model` override along its AGENTS.md ladder, announce the demotion, and continue.

**Stage reviewers dispatch ad-hoc:** spec-reviewer and quality-reviewer subagents always carry an explicit `model` from the AGENTS.md "task-stage reviewers" rung, chosen after the task complexity call below. They are not seat agents; fresh context each time, model override each time.

**Mechanical implementation tasks** (isolated functions, clear specs, 1-2 files): cheapest rung on the implementation ladder. Most implementation tasks are mechanical when the plan is well-specified.

**Integration and judgment tasks** (multi-file coordination, pattern matching, debugging): a stronger rung.

**Architecture, design, and review tasks:** the strongest rung available. Reviews that need the council run on the AGENTS.md council rows.

**Task complexity signals:**
- Touches 1-2 files with a complete spec: cheapest rung
- Touches multiple files with integration concerns: mid rung
- Requires design judgment or broad codebase understanding: strongest rung

Confidential briefs: when a task brief is marked confidential, any rung marked as training on request data in AGENTS.md Privacy Footnotes auto-skips; demote straight to the next privacy-safe rung per the AGENTS.md ladder and announce.

## Handling Implementer Status

Implementer subagents report one of four statuses. Handle each appropriately:

**DONE:** proceed to spec compliance review.

**DONE_WITH_CONCERNS:** the implementer completed the work but flagged doubts. Read the concerns before proceeding. If they concern correctness or scope, address them before review. If they are observations (e.g. "this file is getting large"), note them and proceed to review.

**NEEDS_CONTEXT:** the implementer needs information that was not provided. Provide the missing context and re-dispatch.

**BLOCKED:** the implementer cannot complete the task. Assess the blocker:
1. Context problem: provide more context, re-dispatch with the same rung
2. Task needs more reasoning: re-dispatch on a stronger rung of the ladder
3. Task too large: break it into smaller pieces
4. Plan itself is wrong: escalate to the user

**Never** ignore an escalation or force the same rung to retry without changes. If the implementer said it is stuck, something needs to change.

## Review Stages

Both review stages dispatch fresh reviewer subagents that follow the council skill contract. Invoke the council skill via the skill tool for the reviewer instruction block, the one-line finding format (`path:line: severity: problem. fix.`), and receiving-side rigor (confirm every finding against real code before dispatching fixes).

- **Stage 1, spec compliance:** verify the implementer built what was requested, nothing more, nothing less.
- **Stage 2, code quality:** verify the implementation is well-built. Order is fixed. Never start quality review before spec compliance passes.

Reviewer never fixes. Fixer never reviews. Fresh reviewer subagent every round.

## Prompt Templates

- `implementer-prompt.md` - template: dispatch the `implementer` seat agent with this brief
- `spec-reviewer-prompt.md` - template for dispatching the spec compliance reviewer
- `quality-reviewer-prompt.md` - template for dispatching the code quality reviewer (council format)

## Example Workflow

```
[Announce] Running dispatch on this plan.

[Read plan file once: docs/plans/feature-plan.md]
[Extract all 5 tasks with full text and context]
[Create todo list with all tasks]

Task 1: Hook installation script

[Get Task 1 text and context (already extracted)]
[Dispatch the `implementer` seat agent with the brief from `implementer-prompt.md` (full task text + context)]

Implementer: "Before I begin - should the hook be installed at user or system level?"

You: "User level (~/.config/opencode/hooks/)"

Implementer: "Got it. Implementing now..."
[Later] Implementer:
  - Implemented install-hook command
  - Added tests, 5/5 passing
  - Self-review: found I missed --force flag, added it
  - Committed (or staged in parallel mode)

[Dispatch spec compliance reviewer]
Spec reviewer: PASS - all requirements met, nothing extra

[Get git SHAs, dispatch code quality reviewer]
Quality reviewer: Strengths: good test coverage, clean. Findings: none. Verdict: PASS.

[Mark Task 1 complete, run in place on the feature branch]

Task 2: Recovery modes

[Dispatch the `implementer` seat agent with the brief from `implementer-prompt.md` (full task text + context)]

Implementer: [No questions, proceeds]
Implementer:
  - Added verify/repair modes
  - 8/8 tests passing
  - Self-review: all good
  - Committed (or staged in parallel mode)

[Dispatch spec compliance reviewer]
Spec reviewer: FAIL. Findings:
  - red: missing progress reporting (spec says "report every 100 items")
  - red: extra --json flag added, not requested

[Implementer fixes issues]
Implementer: Removed --json flag, added progress reporting

[Spec reviewer reviews again]
Spec reviewer: PASS

[Dispatch code quality reviewer]
Quality reviewer: Strengths: solid. Findings: yellow: magic number (100)

[Implementer fixes]
Implementer: Extracted PROGRESS_INTERVAL constant

[Quality reviewer reviews again]
Quality reviewer: PASS

[Mark Task 2 complete]

...

[After all tasks]
[Dispatch final reviewer for entire implementation]
Final reviewer: All requirements met, ready to merge

[Return to the controller with the final review verdict]
[Inside oneshot: controller moves to verify (Phase 4), then land (Phase 5). Standalone: run the verify skill yourself, then land]
```

## Parallel Fan-out

The fresh-context rule applies to parallel work too. When multiple unrelated failures appear (different test files, different subsystems, different bugs), sequential investigation wastes time. Each independent piece can happen concurrently.

**Core rule:** one agent per independent problem domain. Let them work concurrently.

### When to Fan Out

```dot
digraph when_to_fan_out {
    "Multiple failures?" [shape=diamond];
    "Are they independent?" [shape=diamond];
    "Single agent investigates all" [shape=box];
    "One agent per problem domain" [shape=box];
    "Can they work in parallel?" [shape=diamond];
    "Sequential agents" [shape=box];
    "Parallel fan-out" [shape=box];

    "Multiple failures?" -> "Are they independent?" [label="yes check next"];
    "Multiple failures?" -> "Single agent investigates all" [label="no, only one"];
    "Are they independent?" -> "Single agent investigates all" [label="no - related"];
    "Are they independent?" -> "Can they work in parallel?" [label="yes"];
    "Can they work in parallel?" -> "Parallel fan-out" [label="yes"];
    "Can they work in parallel?" -> "Sequential agents" [label="no - shared state"];
}
```

**Use when:**
- 3+ test files failing with different root causes
- Multiple subsystems broken independently
- Each problem can be understood without context from the others
- No shared state between investigations

**Don't use when:**
- Failures are related (fixing one might fix the others)
- Need to understand full system state
- Agents would interfere with each other

### The Pattern

**1. Identify independent domains.** Group failures by what is broken:
- File A tests: tool approval flow
- File B tests: batch completion behavior
- File C tests: abort functionality

Each domain is independent: fixing tool approval does not affect abort tests.

**2. Create focused agent tasks.** Each agent gets:
- Specific scope: one test file or subsystem
- Clear goal: make these tests pass
- Constraints: don't change other code
- Expected output: summary of what was found and fixed

**3. Dispatch in parallel.**

```text
Task: "Fix agent-tool-abort.test.ts failures"
Task: "Fix batch-completion-behavior.test.ts failures"
Task: "Fix tool-approval-race-conditions.test.ts failures"
All three run concurrently as fresh subagents.
Parallel mode: pass `Parallel: true` in each brief; implementer Seats then leave their work staged instead of committing, and the main session commits each returned seat serially to avoid index contention.
```

**4. Review and integrate.** When agents return:
- Read each summary
- Verify fixes don't conflict
- Run the full test suite (the verify skill checks)
- Integrate all changes

### Agent Prompt Structure

Good fan-out prompts are:
1. Focused - one clear problem domain
2. Self-contained - all context needed to understand the problem
3. Specific about output - what should the agent return?

```markdown
Fix the 3 failing tests in src/agents/agent-tool-abort.test.ts:

1. "should abort tool with partial output capture" - expects 'interrupted at' in message
2. "should handle mixed completed and aborted tools" - fast tool aborted instead of completed
3. "should properly track pendingToolCount" - expects 3 results but gets 0

These are timing/race condition issues. Your task:

1. Read the test file and understand what each test verifies
2. Identify root cause - timing issues or actual bugs?
3. Fix by:
   - Replacing arbitrary timeouts with event-based waiting
   - Fixing bugs in abort implementation if found
   - Adjusting test expectations if testing changed behavior

Do NOT just increase timeouts - find the real issue.

Return: summary of what you found and what you fixed.
```

### Common Mistakes

- Too broad: "Fix all the tests" - agent gets lost. Fix: scope to one file.
- No context: "Fix the race condition" - agent does not know where. Fix: paste the error messages and test names.
- No constraints: agent might refactor everything. Fix: "Do NOT change production code" or "Fix tests only".
- Vague output: "Fix it" - you do not know what changed. Fix: "Return summary of root cause and changes".

### When NOT to Fan Out

- Related failures: fixing one might fix the others, investigate together first
- Full context needed: understanding requires seeing the entire system
- Exploratory debugging: don't know what is broken yet (use the debug skill first)
- Shared state: agents would interfere (editing same files, same resources)

### Fan-out Example from Practice

6 test failures across 3 files after major refactoring:
- agent-tool-abort.test.ts: 3 failures (timing issues)
- batch-completion-behavior.test.ts: 2 failures (tools not executing)
- tool-approval-race-conditions.test.ts: 1 failure (execution count = 0)

Decision: independent domains. Abort logic separate from batch completion, separate from race conditions. 3 agents dispatched in parallel:

- Agent 1: replaced timeouts with event-based waiting
- Agent 2: fixed event structure bug (threadId in wrong place)
- Agent 3: added wait for async tool execution to complete

Integration: all fixes independent, no conflicts, full suite green. 3 problems solved in the time of 1.

### Verification After Fan-out

1. Review each summary, understand what changed
2. Check for conflicts: did agents edit the same code?
3. Run the full suite, verify all fixes work together
4. Spot check: agents can make systematic errors

## Advantages

**Quality gates:**
- Self-review catches issues before handoff
- Two-stage review: spec compliance, then code quality
- Review loops ensure fixes actually work
- Spec compliance prevents over/under-building
- Code quality ensures the implementation is well-built

**Efficiency gains:**
- No file reading overhead: the controller provides full text
- Controller curates exactly the context needed
- Subagent gets complete information upfront
- Questions surface before work begins, not after

**Costs:**
- More subagent invocations (implementer + 2 reviewers per task)
- Controller does more prep work (extracting all tasks upfront)
- Review loops add iterations
- Still cheaper than debugging later

## Red Flags - Never

- Start implementation on master/main without explicit user consent
- Skip reviews (spec compliance OR code quality)
- Proceed with unfixed issues
- Dispatch multiple implementation subagents in parallel when they can collide (fan-out governs the independent case)
- Push a subagent to read the plan file (provide full text instead)
- Skip scene-setting context (the subagent needs to know where the task fits)
- Ignore subagent questions (answer before letting them proceed)
- Accept "close enough" on spec compliance (spec reviewer found issues = not done)
- Skip review loops (reviewer found issues = implementer fixes = review again)
- Let implementer self-review replace actual review (both are needed)
- Start code quality review before spec compliance passes (wrong order)
- Move to the next task while either review has open issues
- Hardcode a model ID (route by role through AGENTS.md)
- Violate plan task dependency order

**If the subagent asks questions:** answer clearly and completely, provide additional context if needed, don't rush into implementation.

**If the reviewer finds issues:** the implementer (same subagent) fixes them, reviewer reviews again, repeat until approved. Never skip the re-review. Caps: at most 3 fix attempts per task, then route through the debug skill; at most 2 debug rotations; past that STOP and escalate to the user with the exact failing state. Budget exhaustion is an allowed stop point.

**If the subagent fails the task:** dispatch a fix subagent with specific instructions. Don't fix manually (context pollution). If the failure is a bug to root-cause, route through the debug skill first, then re-dispatch.

## Integration

**Required workflow skills:**
- Invoke the `plan` skill via the skill tool: creates the plan this skill executes
- Invoke the `council` skill via the skill tool: reviewer contract for both per-task review stages and the final implementation review
- Invoke the `verify` skill via the skill tool: after the final review PASS, run tests/lint/typecheck/build on the final state
- Invoke the `land` skill via the skill tool: completes development after verify

**Subagents follow:**
- Invoke the `tdd` skill via the skill tool: each task implements failing-test-first

**Routing:**
- The AGENTS.md routing file: model ladders and roles, never model IDs in skill text

**Oneshot:** dispatch is the execution phase of the oneshot pipeline. The pipeline hub lives in the oneshot skill; it enters here at Phase 3 with a user-approved plan. Verify and council follow it inside that pipeline, but this skill runs correctly standalone against any plan file.
