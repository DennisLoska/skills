# Antigravity provider profile

Single-subscription Antigravity profile (`provider: antigravity`, `google` + `anthropic` model families). Use `--profile antigravity` when Antigravity is your only active subscription, either standalone or through T3 Code.

## Role distribution

- **Driver:** `gemini-4-carbon` (`thinking_level=high`, `google`), falling back to `claude-sonnet-5-5` (`thinking_level=medium`, `anthropic`).
- **Discovery (`scout`):** `gemini-3.8-flash` (`thinking_level=low`) -> `gemini-4-argon` (`low`) -> `claude-sonnet-5-5` (`low`).
- **Testing & surgical edits (`tester`, `patch`):** `gemini-3.8-flash` (`thinking_level=medium`) -> `gemini-4-argon` (`medium`) -> `claude-sonnet-5-5` (`low`).
- **Implementation (`implementer`, `implementer-deep`):** `implementer` runs on `gemini-4-argon` (`high`) -> `claude-sonnet-5-5` (`medium`) -> `gemini-3.8-flash` (`high`); `implementer-deep` runs on `gemini-4-argon` (`high`) -> `claude-opus-5-5` (`high`) -> `claude-sonnet-5-5` (`high`).
- **Per-task & council review (`task-reviewer`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`):** `task-reviewer` starts on `claude-sonnet-5-5` (`anthropic`) so tasks authored on `gemini-4-argon` (`google`) get cross-family per-task review when `anthropic` rungs are reachable, with `gemini-3.8-flash` and `gemini-4-carbon` (`google`) as fallbacks; `antigravity-claude` is soft-capped at 6 dispatches and reserved for `reviewer-a,reviewer-b`.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| driver | fallback | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |
| scout | primary | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| scout | fallback | antigravity | gemini-4-argon | thinking_level=low | google | ok |
| scout | last-resort | antigravity | claude-sonnet-5-5 | thinking_level=low | anthropic | ok |
| implementer | primary | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| implementer | fallback | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |
| implementer | last-resort | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| implementer-deep | primary | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| implementer-deep | fallback | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| implementer-deep | last-resort | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| tester | primary | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| tester | fallback | antigravity | gemini-4-argon | thinking_level=medium | google | ok |
| tester | last-resort | antigravity | claude-sonnet-5-5 | thinking_level=low | anthropic | ok |
| patch | primary | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| patch | fallback | antigravity | gemini-4-argon | thinking_level=medium | google | ok |
| patch | last-resort | antigravity | claude-sonnet-5-5 | thinking_level=low | anthropic | ok |
| task-reviewer | primary | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| task-reviewer | fallback | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| task-reviewer | last-resort | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| reviewer-a | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| reviewer-a | fallback | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| reviewer-a | last-resort | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| reviewer-b | primary | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| reviewer-b | fallback | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| reviewer-b | last-resort | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| reviewer-c | primary | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| reviewer-c | fallback | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| reviewer-c | last-resort | antigravity | claude-opus-5-5 | thinking_level=medium | anthropic | ok |
| reviewer-esc | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| reviewer-esc | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| reviewer-esc | last-resort | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| compaction | primary | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| antigravity-claude | antigravity | claude-* | 5h | 6 | reviewer-a,reviewer-b |
| antigravity-gemini | antigravity | gemini-* | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | * | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |

## Runtime behavior and privacy

- **Standalone Antigravity (no T3 Code):** native `invoke_subagent` uses `self` with self-enforced `<contract-path>` / read-only policy for all seats (`scout`, `tester`, `implementer*`, `patch`, `reviewer-*`) and `task-reviewer` (`research` has no shell for `git diff`/`log`/`show` and may be used only for shell-free `design`), with `<contract-path>` at `<skills-dir>/_harness/agents/<seat>.md` (`<skills-dir>` = grandparent of `oneshot/SKILL.md`, i.e. parent of `oneshot/`, in `<skills>`; never substituting the driver's path). It passes `Model: inherit` only when `<model>` equals the active session model, or `Model: flash` only for a flash-tier `google` rung (`gemini-3.8-flash`) on a `google` session; all other rungs (including cross-family rungs) demote as `unreachable` (Path 4). On a standalone single-family session, `task-reviewer` falls back with `degraded task-review: single-family host (<family>)` and council stops with `yellow: degraded council`.
- **T3 Code Antigravity orchestration:** `delegate_task` reaches both `google` (`gemini-*`) and `anthropic` (`claude-*`) families across every ladder, enabling cross-family `task-reviewer` and a 2-family council (`reviewer-a` on `anthropic`, `reviewer-b` on `google`; `reviewer-c` demotes out as a duplicate family, and if both `google` and `anthropic` authored commits on the PR, council stops with `yellow: degraded council` unless paired with a third family via `tri` or `quad`).
- **Privacy & advisory rows:** `ok` assumes the Antigravity account has model-training opt-out enabled. `driver` and `compaction` rows are advisory host recommendations.
