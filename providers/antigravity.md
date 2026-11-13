# Antigravity provider profile

Single-subscription Antigravity profile (`provider: antigravity`, `google` + `anthropic` model families). Use `--profile antigravity` when Antigravity is your only active subscription, either standalone or through T3 Code. The shared implementer and council ladders also name Claude Code and Codex rungs; on an Antigravity-only host those rungs are `unreachable` and demote to the Antigravity rungs and backup rows below.

## Role distribution

- **Driver:** `gemini-4-carbon` (`thinking_level=high`, `google`), falling back to `claude-sonnet-5-5` (`thinking_level=medium`, `anthropic`).
- **Discovery (`scout`):** `gemini-3.8-flash` (`thinking_level=low`) -> `gemini-4-argon` (`low`) -> `claude-sonnet-5-5` (`low`).
- **Testing & surgical edits (`tester`, `patch`):** `gemini-3.8-flash` (`thinking_level=medium`) -> `gemini-4-argon` (`medium`) -> `claude-sonnet-5-5` (`low`).
- **Implementation:** `implementer` runs on `claude-opus-5-5` (`high`) -> `gemini-4-carbon` (`high`) -> Codex `gpt-6.1-sol`; `implementer-deep` prefers Claude Code `claude-fable-5-2` and demotes to `gemini-4-carbon`. Backup rows keep `gemini-4-argon` and `claude-sonnet-5-5` (`high`) for both.
- **Per-task review (`task-reviewer`):** starts on `claude-sonnet-5-5` (`anthropic`) so tasks authored on `google` models get cross-family review, with `gemini-3.8-flash` and `gemini-4-carbon` as fallbacks.
- **Council:** Seat A (captain) prefers Claude Code `claude-fable-5-2`, Seat B Codex `gpt-6-astra`, Seat C `gemini-4-carbon`. With only Antigravity reachable, `single-provider review: antigravity` seats draw from `gemini-4-carbon`, `claude-opus-5-5` and `gemini-4-argon` at `high`.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| driver | fallback | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |
| scout | primary | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| scout | fallback | antigravity | gemini-4-argon | thinking_level=low | google | ok |
| scout | last-resort | antigravity | claude-sonnet-5-5 | thinking_level=low | anthropic | ok |
| implementer | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| implementer | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| implementer | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| implementer-deep | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| implementer-deep | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| implementer-deep | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| tester | primary | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| tester | fallback | antigravity | gemini-4-argon | thinking_level=medium | google | ok |
| tester | last-resort | antigravity | claude-sonnet-5-5 | thinking_level=low | anthropic | ok |
| patch | primary | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| patch | fallback | antigravity | gemini-4-argon | thinking_level=medium | google | ok |
| patch | last-resort | antigravity | claude-sonnet-5-5 | thinking_level=low | anthropic | ok |
| task-reviewer | primary | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| task-reviewer | fallback | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| task-reviewer | last-resort | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| reviewer-a | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| reviewer-a | fallback | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| reviewer-a | last-resort | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| reviewer-b | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-b | fallback | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| reviewer-b | last-resort | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| reviewer-c | primary | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| reviewer-c | fallback | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| reviewer-c | last-resort | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| compaction | primary | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| antigravity-claude | antigravity | claude-* | 5h | - | - |
| antigravity-gemini | antigravity | gemini-* | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | implementer,implementer-deep | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| 2 | implementer,implementer-deep | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| 3 | reviewer-a,reviewer-b,reviewer-c | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| 4 | scout,implementer,implementer-deep,tester,patch,task-reviewer | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |

## Single-provider review

| provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- |
| antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| antigravity | gemini-4-argon | thinking_level=high | google | ok |
| claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |

## Runtime behavior and privacy

- **Standalone Antigravity (no T3 Code):** native `invoke_subagent` uses `self` with self-enforced `<contract-path>` / read-only policy for all seats (`scout`, `tester`, `implementer*`, `patch`, `reviewer-*`) and `task-reviewer` (`research` has no shell for `git diff`/`log`/`show` and may be used only for shell-free `design`), with `<contract-path>` at `<skills-dir>/_harness/agents/<seat>.md` (`<skills-dir>` = grandparent of `oneshot/SKILL.md`, i.e. parent of `oneshot/`, in `<skills>`; never substituting the driver's path). It passes `Model: inherit` only when `<model>` equals the active session model, or `Model: flash` only for a flash-tier `google` rung (`gemini-3.8-flash`) on a `google` session; all other rungs (including cross-family rungs) demote as `unreachable` (Path 4). On a standalone single-family session, `task-reviewer` falls back with `degraded task-review: single-family host (<family>)` and council stops with `yellow: degraded council` when fewer than 2 distinct non-author review models remain.
- **T3 Code Antigravity orchestration:** `delegate_task` reaches both `google` (`gemini-*`) and `anthropic` (`claude-*`) families, enabling cross-family `task-reviewer` and single-provider review across `gemini-4-carbon`, `claude-opus-5-5`, and `gemini-4-argon`.
- **Privacy & advisory rows:** `ok` assumes the Antigravity account has model-training opt-out enabled. `driver` and `compaction` rows are advisory host recommendations.
