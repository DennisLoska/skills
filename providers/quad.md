# Quad provider profile

Four subscriptions: `tri` (Antigravity + Codex + OpenCode Go) plus **Claude Code** (Anthropic subscription, T3 Code provider instance id `claudeAgent`). Pick `quad` (`./install.sh --profile quad`) when you have a Claude subscription alongside Antigravity, Codex, and OpenCode Go: Antigravity's Claude limits are low, so `quad` moves Anthropic roles (`driver` fallback, `implementer` fallback, `implementer-deep` primary, `task-reviewer` fallback, `compaction` primary, and `reviewer-b` primary/last-resort) onto `claudeAgent` and keeps Antigravity's Claude (`claude-opus-5-5`) as fallback. OpenCode Go roles avoid expensive Pro models (`kimi-k3.1-pro`, `qwen3.8-max`, `deepseek-v4-pro`) in favor of high-allowance models: `muse-spark-1.3-contributor` on Seat C (~90k req/5h), `mimo-v2.6-flash` (~60k req/5h), and `deepseek-v4.1-flash` (~86k req/5h).

## Connecting Claude Code in T3 Code

- **Provider instance id:** `claudeAgent` (camelCase, exact).
- **Connect steps:** authenticate your Claude subscription in Claude Code and enable the Claude provider instance in T3 Code settings. Before the first dispatch, the harness calls `orchestrator_capabilities`; `claudeAgent` must show as enabled there (otherwise the Dispatch Adapter treats `claudeAgent` rungs as unreachable and demotes to the next rung on the ladder).
- **Effort option id & values:** `effort` with values `low|medium|high|xhigh|max|ultracode|ultrathink` (written `effort=high` or `effort=medium` in the profile table).
- **Available models:** `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`, `claude-fable-5-2`, `claude-fable-5-1`.

## Role distribution

- **Driver** emits little (briefs, verdicts, gate decisions) but its mistakes fan out to every child: Codex `gpt-6.1-sol` at `medium` effort, with Claude Code `claudeAgent` `claude-sonnet-5-5` (`effort=medium`) as fallback.
- **Architecture & Design (`shape`, `domain-modeling`, `codebase-design`):** advisory recommendation for `claudeAgent` `claude-fable-5-2` (or `claude-fable-5-1`) in Phase 1 sessions, leveraging its superior conceptual synthesis and trade-off evaluation.
- **Discovery (`scout`)** is read-heavy, write-light: high-allowance OpenCode Go flash models (`mimo-v2.6-flash`, `deepseek-v4.1-flash` at `low`) with Antigravity `gemini-3.8-flash` as last resort.
- **Testing & script running (`tester`)** writes red-step failing tests and runs verification/CI scripts with compressed reports: high-volume OpenCode Go `deepseek-v4.1-flash` (`high`), falling back to Codex `gpt-6-luna` (`medium`) and Antigravity `gemini-3.8-flash` (`medium`).
- **Implementation (`implementer`, `implementer-deep`, `patch`):** `implementer` runs on Antigravity `gemini-4-argon` (`high`), falling back to `claudeAgent` `claude-sonnet-5-5` (`effort=medium`) and Codex `gpt-6.1-sol` (`medium`); `implementer-deep` runs on `claudeAgent` `claude-opus-5-5` (`effort=high`), falling back to Codex `gpt-6-astra` (`reasoningEffort=high`) and Antigravity `claude-opus-5-5` (`thinking_level=high`); `patch` shares the cheap `tester` ladder for 1-2 file no-test edits.
- **Per-task review (`task-reviewer`):** Codex `gpt-6.1-terra` (`high`), falling back to Claude Code `claudeAgent` `claude-sonnet-5-5` (`effort=high`) and Antigravity `gemini-3.8-flash` (`high`). Under Author Independence (`AGENTS.md` Author independence), when a task is implemented by Antigravity `gemini-4-argon` (`google`), primary Codex `gpt-6.1-terra` (`openai`) dispatches immediately; when code is authored by OpenAI (`gpt-6.1-sol`), the driver advances past primary to fallback Claude Code `claude-sonnet-5-5` (`anthropic`), ensuring cross-family review without self-grading.
- **Council (`reviewer-a`, `reviewer-b`, `reviewer-c`)** keeps Argon off council review so Argon never reviews its own code: OpenAI frontier lead / tie-breaker on Seat A (`gpt-6-astra` via Codex at `high`, falling back to `gpt-6.1-sol` and `gpt-6-sol`), Anthropic frontier on Seat B (`claude-opus-5-5` via `claudeAgent`, falling back to Antigravity `claude-opus-5-5` and `claudeAgent` `claude-sonnet-5-5`), and high-allowance Meta on Seat C (`opencode-go/muse-spark-1.3-contributor` at ~90,600 req/5h, falling back to `opencode-go/mimo-v2.6-flash` and `opencode-go/glm-5.3-flash`).
- **Escalation (`reviewer-esc`)** runs on high-volume OpenCode flash rungs: `opencode-go/mimo-v2.6-flash` (~60,200 req/5h, `xiaomi`), falling back to `opencode-go/glm-5.3-flash` (`variant=high`, `zhipu`, ~19,000 req/5h) and `opencode-go/deepseek-v4.1-flash` (`deepseek`, ~86,670 req/5h). Expensive quota-draining models are completely eliminated.

## Budget facts and provider load split

No Google or OpenAI (`gpt-*`) model is routed through OpenCode Go in `quad`: all Google models come from Antigravity and all `gpt-*` models come from the Codex subscription. Antigravity, Codex, and Claude Code limits depend on the plan, with rolling 5-hour windows (check with `/status` in the provider), so the profile ranks those models relatively rather than by fixed request count.

- **Antigravity Separate Quota Pools:** Antigravity isolates `gemini-*` (`antigravity-gemini`) from `claude-*` (`antigravity-claude`). The `antigravity-claude` pool is soft-capped at 6 dispatches per run, reserved for `reviewer-b`; 5h is the exhaustion cooldown. Using Claude on Antigravity does **not** consume Gemini Argon quota; `implementer-deep` can use this pool only until the soft cap is reached, after which it is reserved strictly for `reviewer-b`.
- **Claude Code (`claudeAgent`):** carries `implementer-deep` primary (`claude-opus-5-5`), `implementer` fallback (`claude-sonnet-5-5`), `task-reviewer` fallback (`claude-sonnet-5-5`), `reviewer-b` primary (`claude-opus-5-5`) and last-resort (`claude-sonnet-5-5`), `driver` fallback (`claude-sonnet-5-5`), and `compaction` primary (`claude-haiku-5-5`), relieving Antigravity's lower Claude quota.
- **Antigravity:** focuses on Google models (`implementer` primary `gemini-4-argon` at `high` and `gemini-3.8-flash` last-resorts), plus `claude-opus-5-5` fallback for `implementer-deep` and `reviewer-b`.
- **Codex:** carries `driver` (`gpt-6.1-sol`), per-task review `task-reviewer` (`gpt-6.1-terra`), council Seat A `reviewer-a` (`gpt-6-astra` -> `gpt-6.1-sol` -> `gpt-6-sol`), `implementer` last-resort (`gpt-6.1-sol`), `implementer-deep` fallback (`gpt-6-astra`), and `gpt-6-luna` fallbacks for `tester`, `patch`, and `compaction`.
- **OpenCode Go:** carries exclusively high-allowance roles (`scout`, `tester`, `patch`), council Seat C `reviewer-c` (`muse-spark-1.3-contributor` -> `mimo-v2.6-flash` -> `glm-5.3-flash`), and `reviewer-esc` (`mimo-v2.6-flash` -> `glm-5.3-flash` -> `deepseek-v4.1-flash`). Expensive Pro models are eliminated to protect OpenCode subscription credits.
- **Council budget:** Seat C (`muse-spark-1.3-contributor` ~90,600 req/5h) and `reviewer-esc` (`mimo-v2.6-flash` ~60,200 req/5h) have vast OpenCode Go allowances and will never exhaust the subscription.

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
| implementer-deep | primary | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| implementer-deep | fallback | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| implementer-deep | last-resort | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
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
| reviewer-a | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-a | last-resort | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| reviewer-b | primary | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| reviewer-b | fallback | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | last-resort | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| reviewer-c | primary | opencode | opencode-go/muse-spark-1.3-contributor | variant=xhigh | meta | trains |
| reviewer-c | fallback | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| reviewer-c | last-resort | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| reviewer-esc | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| reviewer-esc | fallback | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| reviewer-esc | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| compaction | primary | claudeAgent | claude-haiku-5-5 | effort=low | anthropic | ok |
| compaction | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| claude-code | claudeAgent | * | 5h | - | - |
| antigravity-claude | antigravity | claude-* | 5h | 6 | reviewer-b |
| antigravity-gemini | antigravity | gemini-* | 5h | - | - |
| codex | codex | * | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | implementer,implementer-deep,tester,patch | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| 2 | reviewer-a,reviewer-b,reviewer-c,task-reviewer | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| 3 | * | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| 4 | * | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| 5 | * | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| 6 | * | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |

## Supported driver setups

The `driver` row stays advisory; the installer validates it when present, never requires it, and never renders it. Two setups are supported:

1. **Standalone host (without T3 Code):** OpenCode, Codex, Antigravity (Gemini session; Claude sessions use `--profile antigravity`), or Claude Code runs same-provider rungs natively via Dispatch Adapter Path 2/Path 3 (falling back to the matching `*` row in `## Backup ladder` when primary rungs sit on other providers; single-provider users can also bind `--profile opencode-go|codex|antigravity|claude`). Under `quad` on OpenCode, `implementer`, `implementer-deep`, `reviewer-a`, and `reviewer-b` have no `opencode` ladder rung and install unpinned (never using Path 2).
2. **Any T3 Code provider session:** `./install.sh --target all` populates standalone roots and any T3 Antigravity instances (`skills/_harness/`), dispatching across all connected providers via `delegate_task` with child-enforced permissions.

## Privacy

The `ok` marks for Claude Code (`claudeAgent`), Antigravity (`antigravity`), and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. OpenCode Go rows use non-training privacy classes (`ok`), with `opencode-go/muse-spark-1.3-contributor` marked `trains` as it trains on request data (skip via privacy gate on confidential work).
