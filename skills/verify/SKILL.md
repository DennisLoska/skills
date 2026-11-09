---
name: verify
description: Use when about to claim work is complete, fixed, or passing, before committing, pushing, or filing a PR - says "done", "passing", "fixed", "should work now", or oneshot Phase 4. Requires running verification commands and confirming output before any success claim; evidence before assertions always
---

# Verify

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command on the current state, you cannot claim it passes.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- ANY wording implying success without having run verification

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence does not equal evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter is not the compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion is not an excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**Tests:**
```
[Run test command] [See: 34/34 pass] -> "All tests pass"
"Should pass now" / "Looks correct" -> NO
```

**Regression tests (red-green with tdd):**
```
Write -> Run (pass) -> Revert fix -> Run (MUST FAIL) -> Restore -> Run (pass)
"I've written a regression test" without red-green verification -> NO
```

**Build:**
```
[Run build] [See: exit 0] -> "Build passes"
"Linter passed" -> NO (linter doesn't check compilation)
```

**Requirements:**
```
Re-read plan -> Create checklist -> Verify each -> Report gaps or completion
"Tests pass, phase complete" -> NO
```

**Agent delegation:**
```
Agent reports success -> Check VCS diff -> Verify changes -> Report actual state
Trusting the agent report -> NO
```

## Why This Matters

Compiled from recorded failure memories:
- A user said "I don't believe you" - trust broken
- Undefined functions shipped - would crash
- Missing requirements shipped - incomplete features
- Time wasted on false completion, then redirect, then rework
- Violates: "Honesty is a core value. If you lie, you'll be replaced."

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**
- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness

## Pipeline Integration

- Oneshot Phase 4 (and standalone `verify`) dispatches the `tester` seat as a script runner through the AGENTS.md Dispatch Adapter to run the test suite, lint, typecheck, build, and project scripts, then acts on its compressed pass/fail report (exit codes, pass/fail counts, failing test or check names, and first-error excerpts - never dumping full raw logs into the main session). Failures route to the debug skill. Never proceed on failures.
- Council fix loops: after every fix round, re-run these checks via `tester` (tests, lint, typecheck, build) before re-review. This skill wins every argument with speed.
- Receiving council findings: verifying each finding against real code before acting is the same discipline on the input side. Invoke the council skill via the skill tool for receiving-side rigor.
- tdd supplies the red-green discipline for regression tests. Invoke the tdd skill via the skill tool before writing tests-first.

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.
