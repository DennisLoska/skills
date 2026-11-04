# Cybernetic SDLC Harness

Instructions for the `oneshot` cybernetic control system. Skills and ad-hoc dispatches never hardcode model IDs; the nine seat agents pin theirs in their own agent files; this file is the single source for routing and fallback ladders.

## Context Hygiene and Subagent Routing

- Any code search touching more than one file or 50+ lines goes to `scout` (read-only locator, compressed `path:line` tables) instead of inline search loops in the main session.
- The main session orchestrates and never writes implementation code inline; dispatch a fresh subagent per task (`implementer`, `implementer-b`, or `implementer-deep`) via `dispatch`.
- Surgical 1-2 file fixes (micro-loops and council fix rounds) go to `patch`.

## Model Tank

Provider: exclusively OpenCode Go (`opencode-go/*`, $10/mo tier). No local or non-Go providers are used in this harness. Primary seats sit on high-allowance request tiers (6,320 to 45,300 req/5h) so everyday work never hits usage limits; scarce frontier models live only in complex escalation or last-resort slots.

Effort defaults:
- **Implementers:** `medium` reasoning effort (`implementer-b` pins `#medium`; `deepseek-v4.1-flash` exposes `low|high|max` only so `implementer` and `patch` pin `#high`, its middle tier, while `reviewer-b` pins `#max` and `implementer-deep` pins `#high` for complex work).
- **Reviewers:** `high` or higher reasoning effort (`#xhigh`, `#max`, `#high` on primaries; `#high` on every fallback and last resort).
- **Scout:** `mimo-v2.6-flash` (catalog exposes a single default reasoning tier, no `#variant` suffix; fallbacks pin `#low`).

Skills reference the ROLE NAME or SEAT AGENT only. On a provider error mentioning usage limit, allowance, or 429, re-dispatch with the next entry in the ladder and announce the demotion.

| Role | Seat agent (pinned) | Primary (est. req / 5h) | Fallback | Last resort |
| --- | --- | --- | --- | --- |
| Implementation (default A) | `implementer` | `opencode-go/deepseek-v4.1-flash#high` (43,330) | `opencode-go/muse-spark-1.3-contributor#medium` (45,300) | `opencode-go/gpt-6-luna#medium` (4,230) |
| Implementation (default B) | `implementer-b` | `opencode-go/muse-spark-1.3-contributor#medium` (45,300) | `opencode-go/deepseek-v4.1-flash#high` (43,330) | `opencode-go/gpt-6-luna#medium` (4,230) |
| Complex tasks / difficult bugs | `implementer-deep` | `opencode-go/gemini-4-argon#high` (440) | `opencode-go/deepseek-v4.1-flash#max` (43,330) | `opencode-go/muse-spark-1.3-contributor#high` (45,300) |
| Surgical fixes (1-2 files, council fixers) | `patch` | `opencode-go/deepseek-v4.1-flash#high` (43,330) | `opencode-go/muse-spark-1.3-contributor#medium` (45,300) | `opencode-go/gpt-6-luna#medium` (4,230) |
| Task-stage reviewers (spec + quality) | ad-hoc, explicit model | `opencode-go/glm-5.3-flash#high` (6,320) | `opencode-go/claude-haiku-5-5#high` (3,850) | `opencode-go/gpt-6-luna#high` (4,230) |
| Scout / discovery | `scout` | `opencode-go/mimo-v2.6-flash` (30,100) | `opencode-go/deepseek-v4.1-flash#low` (43,330) | `opencode-go/glm-5.3-flash#low` (6,320) |
| Council reviewer A | `reviewer-a` | `opencode-go/muse-spark-1.3-contributor#xhigh` (45,300) | `opencode-go/claude-haiku-5-5#high` (3,850) | `opencode-go/kimi-k3.1-pro#high` (147) |
| Council reviewer B | `reviewer-b` | `opencode-go/deepseek-v4.1-flash#max` (43,330) | `opencode-go/gpt-6-luna#high` (4,230) | `opencode-go/kimi-k3.1-pro#high` (147) |
| Council reviewer C | `reviewer-c` | `opencode-go/glm-5.3-flash#high` (6,320) | `opencode-go/claude-haiku-5-5#high` (3,850) | `opencode-go/gpt-6-luna#high` (4,230) |
| Council escalation (last resort) | `reviewer-esc` | `opencode-go/kimi-k3.1-pro#high` (147) | `opencode-go/gemini-4-argon#high` (440) | `opencode-go/gpt-6-luna#high` (4,230) |
| Compaction / summary / memory | built-in agent config | `opencode-go/muse-spark-1.3-contributor#low` (45,300) | `opencode-go/claude-haiku-5-5#low` (3,850) | - |

Rules:

- Only `opencode-go/*` models are permitted in this harness.
- Never run the council with fewer than 2 independent reviewer families. If only 1 healthy model remains, surface it as a yellow finding instead of pretending consensus.
- Council runs at most 3 rounds per PR. Primary reviewers (`muse-spark-1.3-contributor#xhigh`, `deepseek-v4.1-flash#max`, `glm-5.3-flash#high`) have 6,320 to 45,300 req/5h so normal PRs never touch scarce limits; `kimi-k3.1-pro#high` (147 req/5h) is strictly last-resort / escalation.
- Deepseek v4 models are cheapest off-peak: 01:00-04:00, 06:00-10:00 UTC Mon-Fri is peak.
- Council budget guard: at most 12 reviewer dispatches per PR including escalation; a seat that demoted once holds its new rung for the rest of the day.
- Family independence holds across the whole PR, not just one round: when two seats demote in the same round, skip any fallback whose family is already active on another seat that round (for example, if Seat A already demoted to `claude-haiku-5-5#high`, Seat C skips straight to `gpt-6-luna#high`). Escalation only runs on a family no seat used this PR; if `kimi-k3.1-pro#high` was already consumed as a seat last-resort, `reviewer-esc` demotes to `gemini-4-argon#high`.
- Privacy gate: any rung marked as training on request data auto-skips when the task or diff carries a confidential flag; demote to the next privacy-safe rung and announce.
- Action-name aliases: some OpenCode builds register permission actions as `bash`/`task`, some as `shell`/`subagent`; agent files carry both spellings so denies never go inert.

## Privacy Footnotes

| Model | Reads your code as | Note |
| --- | --- | --- |
| muse-spark-\* | trains on request data | High-allowance workhorse (45,300 req/5h). Skip on confidential diffs via the privacy gate |
| claude-haiku-5-5 | 30-day retention on requests | Reviewer fallback and compaction backup |
| deepseek v4 family | region-gated | Confirm Global region is enabled in Console Privacy |

GPT Luna models: not used for training, 30-day abuse-monitor retention.
GLM / Kimi / Gemini 4 Argon / MiMo via Go: not used for training, 0-day retention.

## Council Contract

- Seats are named agents: `implementer` and `implementer-b` (default planned tasks), `implementer-deep` (complex tasks / difficult bugs), `scout`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, escalation `reviewer-esc`; each file pins its seat model and `#variant` effort level, so subagents never inherit the main session model.
- Three reviewers, three independent model families, fresh subagent each.
- One line per finding: `path:line: emoji severity: problem. fix.`
- Severity only: red bug, yellow risk, blue nit (nits only on request).
- No praise, no scope creep, no "looks good".
- PASS requires: agreed verdict from at least 2 of 3 reviewers + zero unresolved confirmed red findings + green tests.
- Reviewer never fixes, fixer never reviews.
- Receiving-side rigor: verify each finding against real code before acting; no performative agreement with hostile-but-wrong findings.

## Unit Naming Map

| Trigger | Unit |
| --- | --- |
| oneshot | full pipeline (controller) |
| shape, plan | spec and planning skills |
| dispatch | subagent-driven execution |
| tdd, debug, verify | discipline skills |
| council | consensus review (skill) |
| land | finish branch, PR options |
| make-ci-green | CI babysitting loop |
| implementer, implementer-b, implementer-deep, scout, patch | actuation / discovery agents (pinned Go models + effort) |
| reviewer-a, reviewer-b, reviewer-c, reviewer-esc | council seat agents (pinned Go models + high/xhigh/max effort) |

## Fallback Mechanics

Every agent file pins its primary model, so a subagent session never silently runs the main session model. When a seat's primary returns a usage-limit, allowance, or 429-style provider error: re-dispatch the SAME agent id with an explicit `model` pointing at the next ladder entry for that role in the Model Tank. Announce the demotion. Skip any ladder entry whose model family already serves another seat this round (independence rule). A seat with zero healthy ladder entries is lost; the council stops at `yellow: degraded council` when fewer than 2 independent families remain healthy.
