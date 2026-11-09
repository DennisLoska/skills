# Code Quality Reviewer Prompt Template

Use this template when dispatching a code quality reviewer subagent.

**Purpose:** verify the implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes.** One owner for the review contract: use the reviewer instruction block from `skills/council/SKILL.md` verbatim for this single reviewer (do not invoke the council skill via the skill tool, which would start the full 3-seat branch loop), then dispatch a fresh quality reviewer subagent:

```
dispatch through the AGENTS.md Dispatch Adapter (ad-hoc, NOT a seat): role `task-reviewer` from the active provider profile (`PROVIDERS.md`), skipping any rung whose family wrote the code or `tester` red tests for that task unless every non-author family is unreachable on a standalone single-family host (`degraded task-review: single-family host (<family>)`, per `AGENTS.md` Routing Rules, author independence; never for exhausted quota or soft-cap). ALWAYS name a rung. Never let a subagent inherit the driver's model by omission; follow the AGENTS.md Dispatch Adapter rules for `task-reviewer` (no contract line, explicit `Rung:` line). Fresh subagent per review, fresh context per round.
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
