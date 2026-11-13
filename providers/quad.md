# Quad provider profile

Four subscriptions: `tri` (Antigravity + Codex + OpenCode Go) plus **Claude Code** (Anthropic subscription, T3 Code provider instance id `claudeAgent`). Pick `quad` (`./install.sh --profile quad`) when you have a Claude subscription alongside Antigravity, Codex, and OpenCode Go. Implementers run on Claude Opus 5.5 (`implementer`) and Claude Fable 5.2 (`implementer-deep`) at `high`, the review captain (Seat A) runs on Fable 5.2, and Claude Code absorbs Anthropic load when Antigravity's low Claude limits run out (same-model alternate). OpenCode Go carries cheap high-allowance roles (`scout`, `tester`, `patch`) and never reviews unless it is the last provider with budget.

## Connecting Claude Code in T3 Code

- **Provider instance id:** `claudeAgent` (camelCase, exact).
- **Connect steps:** authenticate your Claude subscription in Claude Code and enable the Claude provider instance in T3 Code settings. Before the first dispatch, the harness calls `orchestrator_capabilities`; `claudeAgent` must show as enabled there (otherwise the Dispatch Adapter treats `claudeAgent` rungs as unreachable and demotes to the next rung).
- **Effort option id & values:** `effort` with values `low|medium|high` (the Anthropic effort cap forbids `xhigh`, `max`, `ultracode`, and `ultrathink`).
- **Available models:** `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`, `claude-fable-5-2`, `claude-fable-5-1`.

## Role distribution

- **Driver:** Codex `gpt-6.1-sol` at `medium`, with `claudeAgent` `claude-sonnet-5-5` (`effort=medium`) as fallback.
- **Architecture & Design (`shape`, `domain-modeling`, `codebase-design`):** advisory recommendation for `claudeAgent` `claude-fable-5-2` (or `claude-fable-5-1`) in Phase 1 sessions.
- **Discovery (`scout`):** OpenCode Go `mimo-v2.6-flash`, then Claude Code `claude-haiku-5-5` (`low`), with Antigravity `gemini-3.8-flash` as last resort; `deepseek-v4.1-flash` stays reachable through the `## Backup ladder`.
- **Testing & script running (`tester`, `patch`):** OpenCode Go `deepseek-v4.1-flash` (`high`), falling back to Codex `gpt-6-luna` (`medium`) and Antigravity `gemini-3.8-flash` (`medium`).
- **Implementation:** `implementer` runs on Antigravity `claude-opus-5-5` (`high`), then Antigravity `gemini-4-carbon` and Codex `gpt-6.1-sol` (`high`); backup row 1 is the same-model alternate on `claudeAgent` `claude-opus-5-5`. `implementer-deep` runs on `claudeAgent` `claude-fable-5-2` (`high`), then `gemini-4-hydrogen` and `gpt-6.1-sol`.
- **Per-task review (`task-reviewer`):** Codex `gpt-6.1-terra` (`high`), falling back to `claudeAgent` `claude-sonnet-5-5` (`effort=high`) and Antigravity `gemini-3.8-flash` (`high`), skipping any rung whose family authored the task.
- **Council:** Seat A, the review captain, on `claudeAgent` `claude-fable-5-2`; Seat B on Codex `gpt-6-astra`; Seat C on Antigravity `gemini-4-hydrogen`, all at `high`. Fallbacks cross the three review providers so a seat can balance onto whichever pool has the most room. No OpenCode model sits in a review ladder or a reviewer backup row; `## Single-provider review` covers the case where only one provider has budget left.

## Budget facts and provider load split

No Anthropic (`claude-*`), Google (`gemini-*`), or OpenAI (`gpt-*`) model routes through OpenCode Go in `quad`.
- **Antigravity:** isolates `gemini-*` (`antigravity-gemini`) from `claude-*` (`antigravity-claude`); `implementer` starts there and moves to Claude Code when the pool is exhausted.
- **Claude Code (`claudeAgent`):** carries `implementer-deep`, the review captain, the `implementer` alternate, the `scout` and `task-reviewer` fallbacks, and `compaction`.
- **Codex:** carries `driver`, `task-reviewer`, Seat B (`gpt-6-astra`), and workhorse fallbacks.
- **OpenCode Go:** carries the `scout` primary, `tester`, `patch`, and non-reviewer backup rows (`deepseek-v4.1-flash`).

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| scout | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| scout | fallback | claudeAgent | claude-haiku-5-5 | effort=low | anthropic | ok |
| scout | last-resort | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| implementer | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| implementer | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| implementer | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| implementer-deep | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| implementer-deep | fallback | antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| implementer-deep | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| tester | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| tester | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| tester | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| patch | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| patch | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| patch | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| task-reviewer | primary | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| task-reviewer | fallback | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| task-reviewer | last-resort | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
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
| compaction | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| opencode-go | opencode | * | 5h | - | - |
| claude-code | claudeAgent | * | 5h | - | - |
| antigravity-claude | antigravity | claude-* | 5h | - | - |
| antigravity-gemini | antigravity | gemini-* | 5h | - | - |
| codex | codex | * | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | implementer | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| 2 | implementer,implementer-deep,tester,patch | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| 3 | task-reviewer | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| 4 | reviewer-a,reviewer-b,reviewer-c | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| 5 | reviewer-a,reviewer-b,reviewer-c | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| 6 | reviewer-a,reviewer-b,reviewer-c | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| 7 | scout,implementer,implementer-deep,tester,patch,task-reviewer | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| 8 | scout,implementer,implementer-deep,tester,patch,task-reviewer | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| 9 | scout,implementer,implementer-deep,tester,patch,task-reviewer | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| 10 | scout,implementer,implementer-deep,tester,patch,task-reviewer | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| 11 | scout,implementer,implementer-deep,tester,patch,task-reviewer | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |

## Single-provider review

When exactly one provider still has an eligible pool, every council seat draws pairwise-distinct, non-author models from that provider's rows (captain first).

| provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- |
| claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| opencode | opencode-go/muse-spark-1.3-contributor | variant=high | meta | trains |

## Supported driver setups

The `driver` row stays advisory; the installer validates it when present, never requires it, and never renders it. Two setups are supported:

1. **Standalone host (without T3 Code):** OpenCode, Codex, Antigravity (Gemini session; Claude sessions use `--profile antigravity`), or Claude Code runs same-provider rungs natively via Dispatch Adapter Path 2/Path 3 (falling back to matching `## Backup ladder` rows when primary rungs sit on other providers; single-provider users can also bind `--profile opencode-go|codex|antigravity|claude`). Under `quad` on OpenCode, `implementer`, `implementer-deep`, and the council seats have no `opencode` ladder rung and install unpinned (never using Path 2).
2. **Any T3 Code provider session:** `./install.sh --target all` populates standalone roots and any T3 Antigravity instances (`skills/_harness/`), dispatching across all connected providers via `delegate_task` with child-enforced permissions.

## Privacy

The `ok` marks for Claude Code (`claudeAgent`), Antigravity (`antigravity`), and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. OpenCode Go rows use non-training privacy classes (`ok`), with `opencode-go/muse-spark-1.3-contributor` marked `trains` as it trains on request data (skip via privacy gate on confidential work).
