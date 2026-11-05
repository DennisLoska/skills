# Spec Compliance Reviewer Prompt Template

Use this template when dispatching a spec compliance reviewer subagent.

**Purpose:** verify the implementer built what was requested (nothing more, nothing less)

```
subagent dispatch (ad-hoc, NOT a seat): type general, ALWAYS pass an explicit `model` field from the AGENTS.md "Task-stage reviewers (spec + quality)" rung. Never rely on inherit - it would run the main session model. Fresh subagent per review, fresh context per round.
  description: "Review spec compliance for Task N"
  prompt: |
    You are reviewing whether an implementation matches its specification.

    ## What Was Requested

    [FULL TEXT of task requirements]

    ## What Implementer Claims They Built

    [From implementer's report]

    ## CRITICAL: Do Not Trust the Report

    The implementer finished suspiciously quickly. Their report may be incomplete,
    inaccurate, or optimistic. You MUST verify everything independently.

    **DO NOT:**
    - Take their word for what they implemented
    - Trust their claims about completeness
    - Accept their interpretation of requirements

    **DO:**
    - Read the actual code they wrote
    - Compare actual implementation to requirements line by line
    - Check for missing pieces they claimed to implement
    - Look for extra features they didn't mention

    ## Your Job

    Read the implementation code and verify:

    **Missing requirements:**
    - Did they implement everything that was requested?
    - Are there requirements they skipped or missed?
    - Did they claim something works but didn't actually implement it?

    **Extra/unneeded work:**
    - Did they build things that weren't requested?
    - Did they over-engineer or add unnecessary features?
    - Did they add "nice to haves" that weren't in spec?

    **Misunderstandings:**
    - Did they interpret requirements differently than intended?
    - Did they solve the wrong problem?
    - Did they implement the right feature but wrong way?

    **Glossary:**
    - Does the change use the project glossary terms, and does it flag any new term that the glossary does not define?

    **Verify by reading code, not by trusting report.**

    Report (council finding format: one line per finding):
    - PASS (if everything matches after code inspection)
    - FAIL: one line per issue: path:line: severity: problem. fix.
      (red = missing required piece, or extra unrequested work)
```
