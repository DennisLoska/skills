---
name: debug
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes. Triggers "debug", "this is broken", "why does it fail", flaky tests, build failures, or any unexplained behavior.
---

# Debug: Root Cause Before Fixes

## Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.

**Violating the letter of this process is violating the spirit of debugging.**

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

Phase 1 not complete? You cannot propose fixes.

## When to Use

Use for ANY technical issue:
- Test failures
- Bugs in production
- Unexpected behavior
- Performance problems
- Build failures
- Integration issues

**Use this ESPECIALLY when:**
- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes
- Previous fix didn't work
- You don't fully understand the issue

**Don't skip when:**
- Issue seems simple (simple bugs have root causes too)
- You're in a hurry (rushing guarantees rework)
- Someone wants it fixed NOW (systematic is faster than thrashing)

## The Four Phases

You MUST complete each phase before proceeding to the next.

### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

1. **Read Error Messages Carefully**
   - Don't skip past errors or warnings
   - They often contain the exact solution
   - Read stack traces completely
   - Note line numbers, file paths, error codes

2. **Reproduce Consistently**
   - Can you trigger it reliably?
   - What are the exact steps?
   - Does it happen every time?
   - Not reproducible? Gather more data, don't guess.

3. **Check Recent Changes**
   - What changed that could cause this?
   - Git diff, recent commits
   - New dependencies, config changes
   - Environmental differences

4. **Gather Evidence in Multi-Component Systems**

   **WHEN the system has multiple components (CI, build, signing, or API, service, database):**

   **BEFORE proposing fixes, add diagnostic instrumentation:**
   ```
   For EACH component boundary:
     - Log what data enters the component
     - Log what data exits the component
     - Verify environment/config propagation
     - Check state at each layer

   Run once to gather evidence showing WHERE it breaks
   THEN analyze the evidence to identify the failing component
   THEN investigate that specific component
   ```

   **Example (multi-layer system):**
   ```bash
   # Layer 1: Workflow
   echo "=== Secrets available in workflow: ==="
   echo "IDENTITY: ${IDENTITY:+SET}${IDENTITY:-UNSET}"

   # Layer 2: Build script
   echo "=== Env vars in build script: ==="
   env | grep IDENTITY || echo "IDENTITY not in environment"

   # Layer 3: Signing script
   echo "=== Keychain state: ==="
   security list-keychains
   security find-identity -v

   # Layer 4: Actual signing
   codesign --sign "$IDENTITY" --verbose=4 "$APP"
   ```

   **This reveals:** which layer fails (secrets, workflow: pass. workflow, build: fail).

5. **Trace Data Flow**

   **WHEN the error is deep in the call stack:**

   See `root-cause-tracing.md` in this directory for the complete backward tracing technique.

   **Quick version:**
   - Where does the bad value originate?
   - What called this with the bad value?
   - Keep tracing up until you find the source
   - Fix at source, not at symptom

### Phase 2: Pattern Analysis

**Find the pattern before fixing:**

1. **Find Working Examples**
   - Locate similar working code in the same codebase
   - What works that's similar to what's broken?

2. **Compare Against References**
   - Implementing a pattern? Read the reference implementation COMPLETELY.
   - Don't skim - read every line.
   - Understand the pattern fully before applying.

3. **Identify Differences**
   - What's different between working and broken?
   - List every difference, however small.
   - Don't assume "that can't matter".

4. **Understand Dependencies**
   - What other components does this need?
   - What settings, config, environment?
   - What assumptions does it make?

### Phase 3: Hypothesis and Testing

**Scientific method:**

1. **Form a Single Hypothesis**
   - State it clearly: "I think X is the root cause because Y"
   - Write it down
   - Be specific, not vague

2. **Test Minimally**
   - Make the SMALLEST possible change to test the hypothesis
   - One variable at a time
   - Don't fix multiple things at once

3. **Verify Before Continuing**
   - Worked? Phase 4.
   - Didn't work? Form a NEW hypothesis.
   - DON'T add more fixes on top.

4. **When You Don't Know**
   - Say "I don't understand X"
   - Don't pretend to know
   - Ask for help, research more

### Phase 4: Implementation

**Fix the root cause, not the symptom:**

1. **Create a Failing Test Case**
   - Simplest possible reproduction
   - Automated test if possible
   - One-off test script if no framework
   - MUST exist before fixing
   - invoke the tdd skill via the skill tool for writing proper failing tests

2. **Implement a Single Fix**
   - Address the root cause identified
   - ONE change at a time
   - No "while I'm here" improvements
   - No bundled refactoring

3. **Verify the Fix**
   - Test passes now?
   - No other tests broken?
   - Issue actually resolved?

4. **If the Fix Doesn't Work**
   - STOP
   - Count: how many fixes have you tried?
   - Fewer than 3: return to Phase 1, re-analyze with the new information
   - **3 or more: STOP and question the architecture (step 5 below)**
   - DON'T attempt fix #4 without an architectural discussion

5. **If 3+ Fixes Failed: Question the Architecture**

   **Pattern indicating an architectural problem:**
   - Each fix reveals new shared state, coupling, or problems somewhere else
   - Fixes require "massive refactoring" to implement
   - Each fix creates new symptoms elsewhere

   **STOP and question fundamentals:**
   - Is this pattern fundamentally sound?
   - Are we sticking with it through sheer inertia?
   - Should we refactor the architecture instead of continuing to fix symptoms?

   **Discuss with your human partner before attempting more fixes.**

   This is NOT a failed hypothesis - this is a wrong architecture.

## Red Flags - STOP and Follow Process

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add multiple changes, run tests"
- "Skip the test, I'll manually verify"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "Pattern says X but I'll adapt it differently"
- "Here are the main problems: [lists fixes without investigation]"
- Proposing solutions before tracing data flow
- **"One more fix attempt" (when already tried 2+)**
- **Each fix reveals a new problem in a different place**

**ALL of these mean: STOP. Return to Phase 1.**

**3+ fixes failed: question the architecture (see Phase 4, step 5).**

## Human Partner Signals You're Doing It Wrong

**Watch for these redirections:**
- "Is that not happening?" - you assumed without verifying
- "Will it show us...?" - you should have gathered evidence first
- "Stop guessing" - you're proposing fixes without understanding
- "Think much harder about this" - question fundamentals, not just symptoms
- "We're stuck?" (frustrated) - your approach isn't working

**When you see these: STOP. Return to Phase 1.**

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | The first fix sets the pattern. Do it right from the start. |
| "I'll write the test after confirming the fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "Reference too long, I'll adapt the pattern" | Partial understanding guarantees bugs. Read it completely. |
| "I see the problem, let me fix it" | Seeing symptoms is not understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures means architectural problem. Question the pattern, don't fix again. |

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Root Cause** | Read errors, reproduce, check changes, gather evidence | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare | Identify differences |
| **3. Hypothesis** | Form theory, test minimally | Confirmed or new hypothesis |
| **4. Implementation** | Create test, fix, verify | Bug resolved, tests pass |

## When Process Reveals "No Root Cause"

If systematic investigation shows the issue is truly environmental, timing-dependent, or external:

1. You've completed the process
2. Document what you investigated
3. Implement appropriate handling (retry, timeout, error message)
4. Add monitoring/logging for future investigation

**But:** 95% of "no root cause" cases are incomplete investigation.

## Supporting Techniques

These techniques are part of this skill and available in this directory:

- **`root-cause-tracing.md`** - trace bugs backward through the call stack to the original trigger
- **`defense-in-depth.md`** - add validation at multiple layers after finding root cause
- **`condition-based-waiting.md`** - replace arbitrary timeouts with condition polling; `condition-based-waiting-example.ts` holds the complete implementation, `find-polluter.sh` bisection-computes which test creates unwanted state

**Related skills and seats:**
- **implementer-deep** (`agents/implementer-deep.md`) - heavy-reasoning seat dispatched when a bug resists standard implementer fixes or spans complex multi-file state
- **tdd** - for creating the failing test case (Phase 4, step 1): invoke via the skill tool
- **verify** - confirm the fix worked before claiming success: invoke via the skill tool

## Real-World Impact

From debugging sessions:
- Systematic approach: 15-30 minutes to fix
- Random fixes approach: 2-3 hours of thrashing
- First-time fix rate: 95% vs 40%
- New bugs introduced: near zero vs common
