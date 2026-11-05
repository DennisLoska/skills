---
name: plan
description: Use when you have a spec or requirements for a multi-step task, before touching code. Triggers "write a plan", "implementation plan", "break this into tasks", "plan the work", or any spec ready to implement.
---

# Plan: Specs Into Bite-Sized Tasks

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for the codebase and questionable taste. Document everything they need: which files each task touches, code, testing, docs to check, how to verify. Deliver the whole thing as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume a skilled developer who knows almost nothing about the toolset or problem domain, and who doesn't know good test design.

**Announce at start:** "I'm using the plan skill to create the implementation plan."

**Context:** work happens on the active feature branch in the current checkout or git worktree.

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during shaping. If it wasn't, suggest separate plans - one per subsystem. Each plan must produce working, testable software on its own.

## File Structure

Before defining tasks, map which files get created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. One clear responsibility per file.
- Reasoning works best on code held in context at once, and edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. Don't unilaterally restructure, but if a file being modified has grown unwieldy, including a split in the plan is reasonable.

This structure drives task decomposition. Each task should produce self-contained changes that make sense independently.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SKILL: invoke the dispatch skill via the skill tool (recommended) to implement this plan task-by-task. For standalone plans only, inline execution with batch checkpoints is also allowed. Under oneshot or `auto-approve: true`, execution is subagent-driven only: never execute inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Auto-approved:** [omit this line unless `auto-approve: true` was set; when set, record `auto-approve: true` here]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

When a task touches a domain concept or a module interface, the task names the glossary term or seam it preserves.

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** - never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code - the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code steps require code blocks)
- References to types, functions, or methods not defined in any task

## Remember
- Exact file paths, always
- Complete code in every step - if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Self-Review

After writing the complete plan, reread the spec with fresh eyes and check the plan against it. Run this checklist yourself - not as a subagent dispatch.

**1. Spec coverage:** skim each section and requirement in the spec. Point to the task that implements it. List any gaps.

**2. Placeholder scan:** search the plan for every red flag pattern in "No Placeholders" above. Fix them.

**3. Type consistency:** do the types, method signatures, and property names in later tasks match what earlier tasks defined? `clearLayers()` in Task 3 vs `clearFullLayers()` in Task 7 is a bug.

**Calibration:** flag only issues that would cause real problems during implementation - missing spec requirements, contradictions, placeholders, tasks too vague to act on. Wording and style preferences don't block.

Fix issues inline. No re-review - just fix and move on. A spec requirement with no task: add the task.

## Execution Handoff

Read `auto-approve: true` from the committed spec header or the dispatch prompt.

When `auto-approve: true` is present under oneshot, do NOT offer the choice, do NOT offer inline execution, and do NOT invoke dispatch: record the plan and note `auto-approve: true` in the plan header; under auto-approve Gate 2 is auto-satisfied and recorded, and plan returns control to oneshot, which runs Phase 3 dispatch. Standalone dispatched mode invokes dispatch directly via the skill tool (immediately when run standalone with auto-approve, or when the user chooses Dispatched below). Under interactive oneshot (no auto-approve), save the plan and return control to the controller so Gate 2 can run (oneshot never authorizes inline main-session implementation).

For standalone use only, offer the execution choice after saving the plan:

**"Plan complete and saved to `docs/plans/<filename>.md`. Two execution options:**

**1. Dispatched (recommended)** - fresh subagent per task (subagent tool), review between tasks, fast iteration

**2. Inline** - execute the tasks in this session in batches, with checkpoint reviews

**Which approach?"**

**Dispatched chosen:**
- **REQUIRED SKILL:** invoke the dispatch skill via the skill tool
- Fresh subagent per task + two-stage review

**Inline chosen:**
- Execute in batches with a review checkpoint after each batch
- invoke the verify skill via the skill tool before claiming any task or the whole plan complete
