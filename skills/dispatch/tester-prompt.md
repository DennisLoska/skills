# Tester Subagent Prompt Template (Red Step)

Use this template when dispatching the `tester` seat agent to write failing tests (the TDD red step) for a plan task that introduces or changes behaviour. Mechanical tasks with no new behaviour to test skip `tester` and dispatch `implementer` directly.

```
dispatch through the AGENTS.md Dispatch Adapter: role `tester` (seat model and effort level per the active provider profile; on a usage-limit/429 error or unreachable rung re-dispatch `tester` on the next rung per the AGENTS.md Routing Rules)
  description: "Write red tests for Task N: [task name]"
  prompt: |
    Role contract: read <harness-dir>/agents/tester.md; follow its body; its permissions block is your policy and you enforce it yourself.
    Rung: <provider>/<model> (<effort>), privacy: <ok|trains>.

    You are writing the failing tests (TDD red step) for Task N: [task name]

    ## Mode
    Mode: red-step

    ## Task Description

    [FULL TEXT of task from plan - paste it here, don't make subagent read file]

    ## Context

    [Scene-setting: where this fits, dependencies, architectural context]

    Domain vocabulary: <glossary terms this task must honor, or "none">

    ## Your Job

    1. Run `git branch --show-current` and STOP with `wrong-branch.` if the branch is `main` or `master`. This branch check is the branch protection; do not rely on shell deny patterns.
    2. Write the failing test(s) specified in the task brief that prove the target behaviour.
    3. Run the targeted test file/command for this task (rather than an unrelated broad suite) and confirm the tests fail for the expected reason (missing feature or unfixed bug, not syntax errors, broken imports, or typos). Fix any test-authoring mistakes until the failure is the right red failure.
    4. NEVER write or edit production code.
    5. NEVER stage or commit. Leave the failing test files in the working tree for `implementer` to turn green and commit alongside the implementation.
    6. Report back using the `tester` receipt format:
       - **Status:** DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
       - **Mode:** red-step
       - **Task:** Task N: [task name]
       - **Files:** test file paths written
       - **Command:** exact test command run
       - **Result:** concise failure excerpt proving the tests fail for the right reason
       - **Notes:** any concerns or "none"

    Work from: [directory] (current checkout or worktree on the feature branch)
```
