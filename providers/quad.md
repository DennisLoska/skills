# Quad provider profile

Four subscriptions: `tri` (Antigravity + Codex + OpenCode Go) plus **Claude Code** (Anthropic subscription, T3 Code provider instance id `claudeAgent`). Pick `quad` (`./install.sh --profile quad`) when you have a Claude subscription alongside Antigravity, Codex, and OpenCode Go: Antigravity's Claude limits are low, so `quad` moves high-volume Anthropic roles (`driver` fallback, `implementer` fallback, `implementer-deep` fallback, `task-reviewer` fallback, `compaction` primary, `reviewer-b` fallback, and `reviewer-esc` primary) onto `claudeAgent` while keeping Antigravity's Claude (`claude-opus-5-5` for `reviewer-b` primary and `claude-sonnet-5-5` for `reviewer-esc` fallback). OpenCode Go roles prioritize high-allowance `muse-spark-1.3-contributor` (~90k req/5h) and `deepseek-v4.1-flash` (~86k req/5h), with `mimo-v2.6-flash` (~60k req/5h) on `scout`.

## Connecting Claude Code in T3 Code

- **Provider instance id:** `claudeAgent` (camelCase, exact).
- **Connect steps:** authenticate your Claude subscription in Claude Code and enable the Claude provider instance in T3 Code settings. Before the first dispatch, the harness calls `orchestrator_capabilities`; `claudeAgent` must show as enabled there (otherwise the Dispatch Adapter treats `claudeAgent` rungs as unreachable and demotes to the next rung).
- **Effort option id & values:** `effort` with values `low|medium|high|xhigh|max|ultracode|ultrathink` (written `effort=high` or `effort=medium` in the profile table).
- **Available models:** `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`, `claude-fable-5-2`, `claude-fable-5-1`.

## Role distribution

- **Driver:** Codex `gpt-6.1-sol` at `medium`, with `claudeAgent` `claude-sonnet-5-5` (`effort=medium`) as fallback.
- **Architecture & Design (`shape`, `domain-modeling`, `codebase-design`):** advisory recommendation for `claudeAgent` `claude-fable-5-2` (or `claude-fable-5-1`) in Phase 1 sessions.
- **Discovery (`scout`):** OpenCode Go flash models (`mimo-v2.6-flash`, `deepseek-v4.1-flash` at `low`) with Antigravity `gemini-3.8-flash` as last resort.
- **Testing & script running (`tester`):** OpenCode Go `deepseek-v4.1-flash` (`high`), falling back to Codex `gpt-6-luna` (`medium`) and Antigravity `gemini-3.8-flash` (`medium`).
- **Implementation (`implementer`, `implementer-deep`, `patch`):** `implementer` runs on Antigravity `gemini-4-argon` (`high`), falling back to `claudeAgent` `claude-sonnet-5-5` (`effort=medium`) and Codex `gpt-6.1-sol` (`medium`); `implementer-deep` runs on Antigravity `gemini-4-argon` (`high`), falling back to `claudeAgent` `claude-opus-5-5` (`effort=high`) and Codex `gpt-6-astra` (`reasoningEffort=high`); `patch` shares the `tester` ladder.
- **Per-task review (`task-reviewer`):** Codex `gpt-6.1-terra` (`high`), falling back to `claudeAgent` `claude-sonnet-5-5` (`effort=high`) and Antigravity `gemini-3.8-flash` (`high`), skipping any rung whose family authored the task.
- **Council (`reviewer-a`, `reviewer-b`, `reviewer-c`):** OpenAI frontier on Seat A (`gpt-6-astra` via Codex at `high`, falling back cross-provider to Antigravity `gemini-4-carbon` and OpenCode Go `opencode-go/deepseek-v4.1-flash`), Anthropic frontier on Seat B (`claude-opus-5-5` via Antigravity, falling back cross-provider to `claudeAgent` `claude-opus-5-5` and OpenCode Go `opencode-go/deepseek-v4.1-flash`), and Meta on Seat C (`opencode-go/muse-spark-1.3-contributor` at ~90,600 req/5h, falling back to `opencode-go/deepseek-v4.1-flash` at `high` and `max`).
- **Escalation (`reviewer-esc`):** `claudeAgent` `claude-sonnet-5-5` (`effort=high`), falling back to Antigravity `claude-sonnet-5-5` (`thinking_level=high`) and OpenCode Go `opencode-go/deepseek-v4.1-flash` (`variant=high` ~86,670 req/5h), advancing past any model held by a council seat or author.

## Budget facts and provider load split

No Anthropic (`claude-*`), Google (`gemini-*`), or OpenAI (`gpt-*`) model routes through OpenCode Go in `quad`.
- **Antigravity:** isolates `gemini-*` (`antigravity-gemini`) from `claude-*` (`antigravity-claude`, soft-capped at 6 dispatches and reserved for `reviewer-b`).
- **Claude Code (`claudeAgent`):** offloads high-volume Claude roles (`implementer*` fallbacks, `task-reviewer` fallback, `reviewer-esc` primary, and `compaction`).
- **Codex:** carries `driver`, `task-reviewer`, council Seat A primary (`gpt-6-astra`), and workhorse fallbacks.
- **OpenCode Go:** carries `scout`, `tester`, `patch`, Seat C `reviewer-c`, and cross-provider last-resorts (`deepseek-v4.1-flash`).

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| scout | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| scout | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=low | deepseek | ok |
| scout | last-resort | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| implementer | primary | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| implementer | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| implementer | last-resort | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| implementer-deep | primary | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| implementer-deep | fallback | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| implementer-deep | last-resort | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| tester | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| tester | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| tester | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| patch | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| patch | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| patch | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| task-reviewer | primary | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| task-reviewer | fallback | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| task-reviewer | last-resort | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| reviewer-a | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-a | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| reviewer-a | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| reviewer-b | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | fallback | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| reviewer-b | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| reviewer-c | primary | opencode | opencode-go/muse-spark-1.3-contributor | variant=xhigh | meta | trains |
| reviewer-c | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| reviewer-c | last-resort | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| reviewer-esc | primary | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| reviewer-esc | fallback | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| reviewer-esc | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| compaction | primary | claudeAgent | claude-haiku-5-5 | effort=low | anthropic | ok |
| compaction | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| opencode-go | opencode | * | 5h | - | - |
| claude-code | claudeAgent | * | 5h | - | - |
| antigravity-claude | antigravity | claude-* | 5h | 6 | reviewer-b |
| antigravity-gemini | antigravity | gemini-* | 5h | - | - |
| codex | codex | * | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | implementer,implementer-deep,tester,patch | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| 2 | reviewer-a,reviewer-b,reviewer-c,task-reviewer | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| 3 | * | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| 4 | * | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| 5 | * | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| 6 | * | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| 7 | * | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |

## Supported driver setups

The `driver` row stays advisory; the installer validates it when present, never requires it, and never renders it. Two setups are supported:

1. **Standalone host (without T3 Code):** OpenCode, Codex, Antigravity (Gemini session; Claude sessions use `--profile antigravity`), or Claude Code runs same-provider rungs natively via Dispatch Adapter Path 2/Path 3 (falling back to the matching `*` row in `## Backup ladder` when primary rungs sit on other providers; single-provider users can also bind `--profile opencode-go|codex|antigravity|claude`). Under `quad` on OpenCode, `implementer` and `implementer-deep` have no `opencode` ladder rung and install unpinned (never using Path 2).
2. **Any T3 Code provider session:** `./install.sh --target all` populates standalone roots and any T3 Antigravity instances (`skills/_harness/`), dispatching across all connected providers via `delegate_task` with child-enforced permissions.

## Privacy

The `ok` marks for Claude Code (`claudeAgent`), Antigravity (`antigravity`), and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. OpenCode Go rows use non-training privacy classes (`ok`), with `opencode-go/muse-spark-1.3-contributor` marked `trains` as it trains on request data (skip via privacy gate on confidential work).
