# Code Quality Reviewer Prompt Template

**Context-scoped effort ceiling:** Non-council work, including driver sessions, defaults, advisory/design work, task-reviewer, fixing and testing, must never request or inherit effort above `high`. Only runtime council reviewer-a/b/c seats and fresh captain rulings may use profile-configured `xhigh`; council is the only skill permitting above high, with maximum `xhigh`. `max`, `ultra`, `ultrathink`, `ultracode`, and equivalent higher levels are forbidden everywhere. Verify provider capabilities before dispatch; use explicit provider-native options from `PROVIDERS.md`. Models without `xhigh` support use explicit `high` in council. Unknown/unsafe defaults require an explicit safe option or an unreachable rung; non-council defaults must be verified at most `high`. Shared reviewer contracts do not grant task reviews the council exception. Invoking a skill never changes the driver session or its ceiling.

Use this template when dispatching a code quality reviewer subagent.

**Purpose:** verify the implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes or is explicitly recorded unavailable; unresolved spec findings still block.** One owner for the review contract: use the reviewer instruction block from `skills/council/SKILL.md` verbatim for this single reviewer (do not invoke the council skill via the skill tool, which would start the full 3-seat branch loop), then dispatch a fresh quality reviewer subagent:

```
dispatch through the AGENTS.md Dispatch Adapter (ad-hoc, NOT a seat): role `task-reviewer` from the active provider profile (`PROVIDERS.md`), without author-model or family exclusions. Record unavailable review as skipped after configured fallback attempts; actual findings and green verification remain required. ALWAYS name a rung. Never let a subagent inherit the driver's model by omission; follow the AGENTS.md Dispatch Adapter rules for `task-reviewer` (no contract line, explicit `Rung:` line). Fresh subagent per review, fresh context per round.
  description = quality review for Task N

  Give the reviewer (from the council instruction block):
  - SCOPE: the task diff [BASE_SHA: commit before task, HEAD_SHA: current commit]
  - PLAN_OR_REQUIREMENTS: Task N from [plan-file], plus the implementer's report summary
  - Instruction block: verbatim from the council skill request phase
    (adversarial, verify by reading code, one line per finding:
     path:line: severity: problem. fix., verdict PASS/FAIL, tests status,
     no praise, no scope creep)
```

**In addition to the standard council checks, the reviewer should check:**
- Does each file have one clear responsibility with a well-defined interface?
- Are units decomposed so they can be understood and tested independently?
- Is the implementation following the file structure from the plan?
- Did this implementation create new files that are already large, or significantly grow existing files? (Don't flag pre-existing file sizes. Focus on what this change contributed.)

**Reviewer returns:** one line per finding in council severity format (red bug / yellow risk / blue nit, nits only on request), verdict PASS or FAIL, tests status (green / red / no-tests).
