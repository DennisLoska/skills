# Claude Code provider profile

Single-subscription Anthropic profile (`provider: claudeAgent`, `family: anthropic`). Use `--profile claude` when Claude Code is your only active subscription or when running standalone Claude Code without cross-provider orchestration. The shared ladders also name Antigravity and Codex rungs; on a Claude-only host those rungs are `unreachable` and demote to the Claude Code rungs and backup rows below. No Anthropic row exceeds `high` effort.

## Role distribution

- **Driver:** `claude-sonnet-5-5` (`effort=medium`), falling back to `claude-opus-5-5` (`effort=medium`).
- **Discovery (`scout`):** `claude-haiku-5-5` (`effort=low`) -> `claude-sonnet-5-5` (`low`) -> `claude-fable-5-1` (`low`).
- **Testing & surgical edits (`tester`, `patch`):** `claude-haiku-5-5` (`effort=medium`) -> `claude-sonnet-5-5` (`medium`) -> `claude-fable-5-1` (`medium`).
- **Implementation:** `implementer` runs on `claude-opus-5-5` (`high`) and `implementer-deep` on `claude-fable-5-2` (`high`), falling back to Antigravity `gemini-4-carbon` and `gemini-4-hydrogen` respectively, then Codex `gpt-6.1-sol`. Backup rows keep `claude-opus-5-5` and `claude-sonnet-5-5` (`high`) on Claude Code.
- **Per-task review (`task-reviewer`):** `high`-effort rungs across `claude-sonnet-5-5`, `claude-opus-5-5`, and `claude-haiku-5-5`.
- **Council:** Seat A (captain) runs on `claude-fable-5-2`; Seat B prefers Codex `gpt-6-astra` and Seat C Antigravity `gemini-4-hydrogen`. With only Claude Code reachable, `single-provider review: claudeAgent` seats draw from `claude-fable-5-2`, `claude-opus-5-5`, and `claude-sonnet-5-5` at `high`.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| driver | fallback | claudeAgent | claude-opus-5-5 | effort=medium | anthropic | ok |
| scout | primary | claudeAgent | claude-haiku-5-5 | effort=low | anthropic | ok |
| scout | fallback | claudeAgent | claude-sonnet-5-5 | effort=low | anthropic | ok |
| scout | last-resort | claudeAgent | claude-fable-5-1 | effort=low | anthropic | ok |
| implementer | primary | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| implementer | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| implementer | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| implementer-deep | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| implementer-deep | fallback | antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| implementer-deep | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| tester | primary | claudeAgent | claude-haiku-5-5 | effort=medium | anthropic | ok |
| tester | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| tester | last-resort | claudeAgent | claude-fable-5-1 | effort=medium | anthropic | ok |
| patch | primary | claudeAgent | claude-haiku-5-5 | effort=medium | anthropic | ok |
| patch | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| patch | last-resort | claudeAgent | claude-fable-5-1 | effort=medium | anthropic | ok |
| task-reviewer | primary | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| task-reviewer | fallback | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| task-reviewer | last-resort | claudeAgent | claude-haiku-5-5 | effort=high | anthropic | ok |
| reviewer-a | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| reviewer-a | fallback | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| reviewer-a | last-resort | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| reviewer-b | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-b | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| reviewer-b | last-resort | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| reviewer-c | primary | antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| reviewer-c | fallback | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| reviewer-c | last-resort | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| compaction | primary | claudeAgent | claude-haiku-5-5 | effort=low | anthropic | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| claude-code | claudeAgent | * | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | implementer | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| 2 | implementer-deep | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| 3 | implementer,implementer-deep | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| 4 | reviewer-a,reviewer-b,reviewer-c | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| 5 | scout,implementer,implementer-deep,tester,patch,task-reviewer | claudeAgent | claude-haiku-5-5 | effort=medium | anthropic | ok |

## Single-provider review

| provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- |
| claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |

## Runtime behavior and privacy

- **Standalone Claude Code (no T3 Code):** dispatches every reachable role natively via `Agent` (`run_in_background: false`, seat subagent or general-purpose for `task-reviewer`/`design`) with explicit `model` (Dispatch Adapter Path 3). Because every reachable rung belongs to the `anthropic` family, standalone `task-reviewer` uses the `degraded task-review: single-family host (anthropic)` fallback, and the council runs as `single-provider review: claudeAgent` on distinct non-author models.
- **T3 Code session:** dispatches via `delegate_task` (`providerInstanceId: claudeAgent`); combine with other providers via `--profile quad` for multi-family review.
- **Privacy & advisory rows:** `ok` assumes the Claude account has model-training opt-out enabled. `driver` and `compaction` rows are advisory host recommendations.
