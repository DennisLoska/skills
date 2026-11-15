# Skill and model routing

The repository has exactly 12 skills. Skills define workflows, not standalone model assignments. The driver stays in its current session when a skill is invoked; the `driver` advisory row does not automatically switch it. Delegated roles resolve explicit rungs from the active `PROVIDERS.md` using AGENTS.md's Dispatch Adapter. This document describes the fixed policy of all six shipped profiles and all 15 generated provider combinations; source profiles and installer validation remain the executable routing authority.

## Universal ceiling: no reasoning above high

Never request or inherit a reasoning level above `high`, regardless of model, provider capability, role, or workflow. This includes the driver, advisory work, compaction, design alternatives, task reviews, council seats, captain rulings, all fallbacks and backups, and ad-hoc calls. `xhigh`, `max`, `ultra`, `ultrathink`, `ultracode`, and equivalent levels are forbidden. There are no exceptions or effort escalations.

Use explicit provider-native options at `low`, `medium`, or `high`. A `-` default or omitted option is usable only when the effective default is verified at most `high`; otherwise explicitly set `high` or mark the rung unreachable. A native pin or inherited session setting is subject to the same check. Changing to a deeper model/seat never raises this ceiling.

## Roles in every shipped policy

| Role | Primary model and provider | Effort / routing notes |
| --- | --- | --- |
| `driver` (advisory) | GPT6.1 Sol (`gpt-6.1-sol`), Codex | At most high; stays in-session. |
| `designer` (optional ad-hoc) | Fable 5.2 (`claude-fable-5-2`), Claude Code | Read-only design draft, `effort=high`; only fallback Sol/Codex `reasoningEffort=high`. |
| `planner` (optional ad-hoc) | Fable 5.2, Claude Code | Read-only implementation-plan draft, high; only fallback Sol/Codex high. |
| `scout` | Deepseek V4.1 Flash (`opencode-go/deepseek-v4.1-flash`), OpenCode Go | `variant=high`; fallback Gemini 3.8 Flash, then GPT6 Luna. |
| `tester` | Deepseek V4.1 Flash, OpenCode Go | High; fallback Gemini 3.8 Flash, then GPT6 Luna. |
| `patch` | Deepseek V4.1 Flash, OpenCode Go | High; fallback Gemini 3.8 Flash, then GPT6 Luna; 1–2 file edits without test runs. |
| `implementer` | Opus 5.5 (`claude-opus-5-5`), Antigravity | High; same-model alternate on Claude Code before leaving Opus; generic Google fallback uses Gemini 4 Argon, then Sol. |
| `implementer-deep` | Fable 5.2, Claude Code | High; Gemini 4 Hydrogen then Sol for implementation fallback. |
| `task-reviewer` (ad-hoc) | Sol, Codex | High; Astra then Fable, subject to author independence. Both task stages and final task review use this role. |
| `reviewer-a` (preferred captain) | Fable 5.2, Claude Code | High; eligible review backups only from the three-model review set below. |
| `reviewer-b` | Astra (`gpt-6-astra`), Codex | High; same allowlist and independence checks. |
| `reviewer-c` | Sol, Codex | High; same allowlist and independence checks. |
| Captain ruling | Current healthy captain's model/rung | Fresh read-only review dispatch, high, never the author model. |
| `design` (T3 transport role) | `designer`/`planner` profile rungs | Includes design-it-twice alternatives on designer rungs; distinct families where reachable. Legacy alternatives use deep/implementation rungs only when designer is absent. |
| `compaction` / summary (advisory) | Gemini 3.8 Flash (`gemini-3.8-flash`), Antigravity | Cheap low effort; fallback GPT6 Luna (`gpt-6-luna`), Codex, low. Never training-enabled routing. |

Fallback Gemini 3.8 Flash uses Antigravity's explicit safe `thinking_level`; GPT6 Luna uses Codex's explicit safe `reasoningEffort`. Both are at most high. Profiles carry the actual options, not skill text.

## All 12 skills

The recommended driver is Sol. Design and planning drafts are delegated to Fable with Sol fallback; invoking a skill keeps the driver session and its gates in place.

| Skill | In-session responsibility | Delegated seats/roles and primary models |
| --- | --- | --- |
| `codebase-design` | Module/interface decisions and canonical artifacts | `scout` → Deepseek; `designer` → Fable, Sol fallback; design-it-twice uses only designer rungs across distinct reachable families. |
| `council` | Orchestrate review, verify findings and record verdicts | A/captain → Fable; B → Astra; C → Sol; ruling → healthy captain; accepted-finding fixers → Opus/Fable; `tester` → Deepseek. |
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

The driver owns user conversation, approvals, canonical document application/self-review, commits and phase advancement. Oneshot invokes shape and plan once each; they own the draft handoffs. Domain/module guidance for the same draft is included in that brief, not duplicated. Draft-only authors are not automatically code authors; actual implementation authors still enter the independence checks.

Only the nine original dispatched roles are required for old profiles. Optional roles require primary iff mentioned, with ordinary rung/effort validation. Profiles without them retain driver drafting and the legacy deep/implementation family ladder for design-it-twice. Present roles use only their profile ladders and explicitly named backups, never generic `*` backups or implementation siblings; exhaustion/unreachability stops rather than using the driver. All privacy, quotas and at-most-high rules apply. Every shipped/generated profile has exactly Fable primary and Sol fallback for each, with no other backup.

## Closed review set and author independence

All shipped/generated reviews use **only Fable 5.2, Astra, and Sol**, for task reviews, council seats, captain rulings, review backups, and single-provider recovery. No Gemini model, Opus, Sonnet, Terra, Haiku, or OpenCode model may enter review through a fallback or ad-hoc exception. Gemini models remain eligible for non-review work described above.

A Fable implementation author cannot review that diff, even through another provider. Exclude Fable, seat the healthy GPT models (Astra and Sol), and pass captaincy to the first healthy eligible GPT seat (normally Seat B/Astra). Both must pass in degraded mode. Similarly exclude Sol or Astra whenever either authored branch code; driver-authored implementation counts as authorship too.

Codex-only review has exactly Astra and Sol; it requires both healthy and outside `author_models`. Claude-only availability has only Fable in the allowed set and therefore cannot form a council. With fewer than two eligible independent review models, stop with `yellow: degraded council` (and budget/reset details when quota is the cause), rather than borrowing an excluded model. Pairwise-distinct models are mandatory; different families are preferred but do not override this allowlist. A two-family profile cannot satisfy a three-distinct-family primary rule, so the shipped policy uses model-level distinctness.

Task reviews first skip the author family. If only same-family permitted candidates remain, apply the recorded degraded task-review rule and require a model outside `author_models`; never self-review. This does not relax the council's two-model minimum.

## Provider selection and portability

`--providers` retains and refreshes the canonical selected connection list. It prefers selected paths for the same required model: Opus uses Claude Code when Claude is selected without Antigravity; otherwise Antigravity is preferred, with the other Opus path as its same-model alternate. Fable stays on Claude Code. No provider instance aliases are invented. All profiles retain cross-provider roles, including Deepseek scout on OpenCode even when OpenCode was not selected. Selection does not filter policy or replace missing models. Unavailable paths demote under the adapter; unavailable exact draft ladders or fewer than two independent allowed review models stop. Antigravity-only, Claude-only and OpenCode-only review cannot form a panel. `--profile`, `--profile-file`, and `--providers` remain mutually exclusive; custom legacy profiles may omit draft roles.
