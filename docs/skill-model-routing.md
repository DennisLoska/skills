# Skill and model routing

The repository has exactly 12 skills. Skills define workflows, not standalone model assignments. The driver stays in its current session when a skill is invoked; the `driver` advisory row does not automatically switch it. Delegated roles resolve explicit rungs from the active `PROVIDERS.md` using AGENTS.md's Dispatch Adapter. This document describes the fixed policy of all six shipped profiles and all 15 generated provider combinations; source profiles and installer validation remain the executable routing authority.

## Context-scoped effort ceiling

**Context-scoped effort ceiling:** Non-council work, including driver sessions, defaults, advisory/design work, task-reviewer, fixing and testing, must never request or inherit effort above `high`. Only runtime council reviewer-a/b/c seats and fresh captain rulings may use profile-configured `xhigh`; council is the only skill permitting above high, with maximum `xhigh`. `max`, `ultra`, `ultrathink`, `ultracode`, and equivalent higher levels are forbidden everywhere. Verify provider capabilities before dispatch; use explicit provider-native options from `PROVIDERS.md`. Argon uses explicit `thinking_level=high` because it has no xhigh support. Unknown/unsafe defaults require an explicit safe option or an unreachable rung; non-council defaults must be verified at most `high`. Shared reviewer contracts do not grant task reviews the council exception. Invoking a skill never changes the driver session or its ceiling.

Non-council work uses explicit provider-native options at `low`, `medium`, or `high`; council seats/rulings alone may use configured `xhigh`. A `-` default or omitted option is usable only when the effective default is verified at most `high`; otherwise explicitly set `high` or mark the rung unreachable. A native pin or inherited session setting is subject to the same check. Changing to a deeper model/seat never raises this ceiling.

## Roles in every shipped policy

| Role | Primary model and provider | Effort / routing notes |
| --- | --- | --- |
| `driver` (advisory) | GPT6.1 Sol (`gpt-6.1-sol`), Codex | At most high; stays in-session. |
| `designer` (optional ad-hoc) | Fable 5.2 (`claude-fable-5-2`), Claude Code | Read-only design draft, `effort=high`; only fallback Sol/Codex `reasoningEffort=high`. |
| `planner` (optional ad-hoc) | Fable 5.2, Claude Code | Read-only implementation-plan draft, high; only fallback Sol/Codex high. |
| `scout` | Deepseek V4.1 Flash (`opencode-go/deepseek-v4.1-flash`), OpenCode Go | `variant=high`; fallback GPT6 Luna, then terminal Gemini 3.8 Flash. |
| `tester` | Deepseek V4.1 Flash, OpenCode Go | High; fallback GPT6 Luna, then terminal Gemini 3.8 Flash. |
| `patch` | Deepseek V4.1 Flash, OpenCode Go | High; fallback GPT6 Luna, then terminal Gemini 3.8 Flash; 1–2 file edits without test runs. |
| `implementer` | Opus 5.5 (`claude-opus-5-5`), Claude Code | High; Sol fallback on Codex, then terminal Gemini 4 Argon on Antigravity. |
| `implementer-deep` | Fable 5.2, Claude Code | High; Sol fallback on Codex, then terminal Gemini 4 Argon on Antigravity. |
| `task-reviewer` (ad-hoc) | Sol, Codex | High; Astra then Fable. Both task stages and final task review use this role. |
| `reviewer-a` (preferred captain) | Opus 5.5, Claude Code | Xhigh; eligible review backups only from the three-model review set below. |
| `reviewer-b` | Sol, Codex | Xhigh; same allowlist and active-model checks. |
| `reviewer-c` | Argon, Antigravity | High (no xhigh support); same allowlist and active-model checks. |
| Captain ruling | Current healthy captain's model/rung | Fresh read-only council dispatch, captain rung effort (at most xhigh). |
| `design` (T3 transport role) | `designer`/`planner` profile rungs | Includes design-it-twice alternatives on designer rungs; distinct families where reachable. Legacy alternatives use deep/implementation rungs only when designer is absent. |
| `compaction` / summary (advisory) | Gemini 3.8 Flash (`gemini-3.8-flash`), Antigravity | Cheap low effort; fallback GPT6 Luna (`gpt-6-luna`), Codex, low. Never training-enabled routing. |

Fallback Gemini 3.8 Flash uses Antigravity's explicit safe `thinking_level`; GPT6 Luna uses Codex's explicit safe `reasoningEffort`. Both are at most high. Profiles carry the actual options, not skill text.

## All 12 skills

The recommended driver is Sol. Design and planning drafts are delegated to Fable with Sol fallback; invoking a skill keeps the driver session and its gates in place.

| Skill | In-session responsibility | Delegated seats/roles and primary models |
| --- | --- | --- |
| `codebase-design` | Module/interface decisions and canonical artifacts | `scout` → Deepseek; `designer` → Fable, Sol fallback; design-it-twice uses only designer rungs across distinct reachable families. |
| `council` | Orchestrate review, verify findings and record verdicts | A/captain → Opus (xhigh); B → Sol (xhigh); C → Argon (high); ruling → healthy captain; accepted-finding fixers → Opus/Fable; `tester` → Deepseek. |
| `debug` | Root-cause discipline and escalation decisions | `scout` → Deepseek for discovery; `tester` → Deepseek for reproduction/checks; fixers → Opus, or Fable for resistant bugs. |
| `dispatch` | Plan/task orchestration and review loop | `tester` → Deepseek; `implementer` → Opus; deep → Fable; `patch` → Deepseek; `task-reviewer` → Sol (Astra then Fable). |
| `domain-modeling` | Glossary/ADR decisions and domain terminology | `scout` → Deepseek when discovery needs delegation; substantive draft via `designer` → Fable, Sol fallback. |
| `land` | Branch/PR/merge decisions and backlog handoff | No dedicated landing model; uses `tester` → Deepseek and routes verification, council or CI work through their owning skills when needed. |
| `make-ci-green` | Monitor checks, assess findings, orchestrate fixes | `tester` → Deepseek for logs/reruns; fixers → Opus or Fable; `patch` is not a test-running fixer. |
| `oneshot` | Full controller pipeline in the driver session | All workflow roles above via owning skills; no whole-pipeline child or standalone oneshot model. |
| `plan` | Approve/apply decomposition of approved requirements | `scout` → Deepseek for discovery; `planner` → Fable, Sol fallback for draft only; execution belongs to `dispatch`. |
| `shape` | Intent/conversation, design approval and spec artifact | `scout` → Deepseek; `designer` → Fable, Sol fallback for design draft; includes domain/module guidance or design-it-twice alternatives without duplicate drafts. |
| `tdd` | Red/green/refactor discipline applied by the current worker | Under dispatch: `tester` → Deepseek for red; `implementer` → Opus or deep → Fable for green/refactor. No independent TDD model. |
| `verify` | Evidence-before-assertions gate | `tester` → Deepseek for suites/scripts/checks; failures route through `debug` and implementation seats. |

## Draft execution and legacy compatibility

`designer` and `planner` have no native agent files. The owning skills execute the Draft Delegation Adapter in `dispatch/SKILL.md`: both logical roles map to T3 `delegate_task` role `design`, with explicit profile options and `Rung:` only. Native dispatch uses general-purpose workers (OpenCode general task, Claude general-purpose, Codex explicit model/effort). Workers are repository-read-only, returning draft text and decisions with no commits, edits, execution or children. A worker already on a draft brief drafts directly, never recursively invokes its skill or re-dispatches.

The driver owns user conversation, approvals, canonical document application/self-review, commits and phase advancement. Oneshot invokes shape and plan once each; they own the draft handoffs. Domain/module guidance for the same draft is included in that brief, not duplicated. Draft-only authors are not automatically code authors; actual implementation authors are recorded for audit only.

Only the nine original dispatched roles are required for old profiles. Optional roles require primary iff mentioned, with ordinary rung/effort validation. Profiles without them retain driver drafting and the legacy deep/implementation family ladder for design-it-twice. Present roles use only their profile ladders and explicitly named backups, never generic `*` backups or implementation siblings; exhaustion/unreachability stops rather than using the driver. All privacy, quotas and at-most-high rules apply. Every shipped/generated profile has exactly Fable primary and Sol fallback for each, with no other backup.

## Closed review set and availability

Council uses **only Opus 5.5, Sol, and Argon**, including council fallbacks, backups, captain rulings and single-provider recovery. Task-reviewer retains **Sol, Astra and Fable at high**. The council exception never covers task review, fixers, testing or the driver.

The same model may author and review. Only simultaneously active council models must differ. Authorship never filters review eligibility or transfers captaincy.

Codex-only council permits Sol; Claude-only permits Opus; Antigravity-only permits Argon. Each may review its own code and proceed alone. Zero available members records SKIPPED; never widen the council allowlist.

Task reviews use configured task-reviewer ladders/backups without authorship exclusions. Record unavailable task reviews as skipped and proceed with green verification; actual findings remain required.

Council tries configured members and quota/reachability fallbacks, skipping unavailable members. One available reviewer may PASS regardless of provider count, inside or outside oneshot. The sole reviewer is captain and returns a real final `reviewer_vote: PASS|FAIL reviewer=<provider/model> head=<sha>` after fresh rulings. Single verdict: `council_verdict: PASS|FAIL round=<n> mode=single reviewer=<provider/model> head=<sha>`. Zero reviewers records `council_verdict: SKIPPED round=<n> mode=unavailable head=<sha>` with all configured attempts/skips and reasons, never PASS. Land accepts this skipped review with green actual verification and matching local/remote HEAD via `--match-head-commit`; no no-tests waiver for single/unavailable. Actual review FAIL and unresolved accepted findings still block. Authorship is audit-only; active model distinctness, allowlists, privacy, effort limits and three-round caps remain.

## Provider selection and portability

`--providers` retains and refreshes the canonical selected connection list. It preserves fixed provider paths: Opus and Fable use Claude Code, Sol uses Codex, and Gemini uses Antigravity. No provider instance aliases are invented. All profiles retain cross-provider roles, including Deepseek scout on OpenCode even when OpenCode was not selected. Selection does not filter policy or replace missing models. Unavailable paths demote under the adapter; unavailable exact draft ladders stop. Unavailable reviewers are skipped; one available reviewer proceeds, zero records SKIPPED. OpenCode has no configured council models. `--profile`, `--profile-file`, and `--providers` remain mutually exclusive; custom legacy profiles may omit draft roles.

Operational migration: refreshing a shipped profile adopts the fixed ladders above. For scout, tester, patch and both implementation seats, an explicit last-resort is terminal: ineligibility or routing failure stops the original role without terminal alternates, sibling hand-off or any backup rows; a transient retries once. Primary/fallback keep same-model alternates. Task failures keep fix/debug caps. Shipped backups are review-only. Custom profiles without explicit operational last-resort retain legacy sibling/backup routing. Standalone hosts may reach an unavailable terminal rung and stop; provider selection does not replace models or guarantee a complete pipeline. Review, design and planner policy is unchanged.
