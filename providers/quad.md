# Quad provider profile

Four subscriptions: `tri` (Antigravity + Codex + OpenCode Go) plus **Claude Code** (Anthropic subscription, T3 Code provider instance id `claudeAgent`). Pick `quad` (`./install.sh --profile quad`) when you have a Claude subscription alongside Antigravity, Codex, and OpenCode Go: Antigravity's Claude limits are low, so `quad` moves Anthropic roles (`driver` fallback, `implementer-deep` primary, and `reviewer-b` primary/last-resort) onto `claudeAgent` and keeps Antigravity's Claude (`claude-opus-5-5`) as fallback.

## Connecting Claude Code in T3 Code

- **Provider instance id:** `claudeAgent` (camelCase, exact).
- **Connect steps:** authenticate your Claude subscription in Claude Code and enable the Claude provider instance in T3 Code settings. Before the first dispatch, the harness calls `orchestrator_capabilities`; `claudeAgent` must show as enabled there (otherwise the Dispatch Adapter treats `claudeAgent` rungs as unreachable and demotes to the next rung on the ladder).
- **Effort option id & values:** `effort` with values `low|medium|high|xhigh|max|ultracode|ultrathink` (written `effort=high` or `effort=medium` in the profile table).
- **Available models:** `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`, `claude-fable-5-1`.

## Role distribution

- **Driver** emits little (briefs, verdicts, gate decisions) but its mistakes fan out to every child: Codex `gpt-6.1-sol` at `medium` effort, with Claude Code `claudeAgent` `claude-sonnet-5-5` (`effort=medium`) as fallback.
- **Discovery (`scout`)** is read-heavy, write-light: high-allowance OpenCode Go flash models (`mimo-v2.6-flash`, `deepseek-v4.1-flash` at `low`) with Antigravity `gemini-3.8-flash` as last resort.
- **Testing & script running (`tester`)** writes red-step failing tests and runs verification/CI scripts with compressed reports: high-volume OpenCode Go `deepseek-v4.1-flash` (`high`), falling back to Codex `gpt-6-luna` (`medium`) and Antigravity `gemini-3.8-flash` (`medium`).
- **Implementation (`implementer`, `implementer-deep`, `patch`):** `implementer` runs on Antigravity `gemini-4-argon` (`medium`), falling back to OpenCode Go `gemini-4-argon` (`high`) and Codex `gpt-6.1-sol` (`medium`); `implementer-deep` runs on `claudeAgent` `claude-opus-5-5` (`effort=high`), falling back to Codex `gpt-6-astra` (`reasoningEffort=high`) and Antigravity `claude-opus-5-5` (`thinking_level=high`); `patch` shares the cheap `tester` ladder for 1-2 file no-test edits.
- **Per-task review (`task-reviewer`):** Codex `gpt-6.1-terra` (`high`), falling back to OpenCode Go `glm-5.3-flash` (`high`) and Antigravity `gemini-3.8-flash` (`high`), skipping any rung whose family authored the task.
- **Council (`reviewer-a`, `reviewer-b`, `reviewer-c`)** gets the strongest model of each frontier family at `high` effort: Google (`gemini-4-argon` on Seat A, falling back to OpenCode Go `opencode-go/gemini-4-argon` and `opencode-go/qwen3.8-max`), Anthropic (`claude-opus-5-5` on Seat B via `claudeAgent`, falling back to Antigravity `claude-opus-5-5` and `claudeAgent` `claude-sonnet-5-5`), and OpenAI (`gpt-6-astra` on Seat C via Codex, falling back to `gpt-6.1-sol` and `gpt-6-sol`). Review is short output with the highest stakes, so frontier tokens pay off most here. Under the author-family PASS rule, while Argon (Google) authors the code, the required non-author PASS vote comes from Opus (Anthropic) or Astra (OpenAI).
- **Escalation (`reviewer-esc`)** sits on the best open-weight families unused by the council seats (`opencode-go/kimi-k3.1-pro` at `high`, then `opencode-go/deepseek-v4-pro` and `opencode-go/mimo-v2.6-pro`), so its verdict stays independent of all three frontier council families; `reviewer-esc` also supplies the non-author council vote when every council seat's family is an author family.

## Budget facts and provider load split

No OpenAI model is routed through OpenCode Go in `quad`: all `gpt-*` models come from the Codex subscription. Antigravity, Codex, and Claude Code limits depend on the plan, with rolling 5-hour windows (check with `/status` in the provider), so the profile ranks those models relatively rather than by fixed request count.

- **Claude Code (`claudeAgent`):** carries `implementer-deep` primary (`claude-opus-5-5`), `reviewer-b` primary (`claude-opus-5-5`) and last-resort (`claude-sonnet-5-5`), and `driver` fallback (`claude-sonnet-5-5`), relieving Antigravity's lower Claude quota.
- **Antigravity:** focuses on Google models (`implementer` primary `gemini-4-argon` and `reviewer-a` primary `gemini-4-argon`), plus `claude-opus-5-5` fallback for `implementer-deep` and `reviewer-b`.
- **Codex:** carries `driver` (`gpt-6.1-sol`), per-task review `task-reviewer` (`gpt-6.1-terra`), council Seat C `reviewer-c` (`gpt-6-astra` -> `gpt-6.1-sol` -> `gpt-6-sol`), `implementer-deep` fallback (`gpt-6-astra`), and `gpt-6-luna` fallbacks for `tester`, `patch`, and `compaction`.
- **OpenCode Go:** carries the high-volume cheap roles (`scout`, `tester`, `patch`, `compaction`), `reviewer-esc` (`kimi-k3.1-pro` -> `deepseek-v4-pro` -> `mimo-v2.6-pro`), and `reviewer-a` fallbacks (`opencode-go/gemini-4-argon` is a separate ~440 req/5h pool from Antigravity's Argon quota).
- **Council budget:** the council runs at most 3 rounds × 3 seats + 1 escalation per PR. `kimi-k3.1-pro`'s ~147 req/5h allowance on OpenCode Go is plenty for single-dispatch escalation (`reviewer-esc`).

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| scout | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| scout | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=low | deepseek | ok |
| scout | last-resort | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| implementer | primary | antigravity | gemini-4-argon | thinking_level=medium | google | ok |
| implementer | fallback | opencode | opencode-go/gemini-4-argon | variant=high | google | ok |
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
| task-reviewer | fallback | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| task-reviewer | last-resort | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| reviewer-a | primary | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| reviewer-a | fallback | opencode | opencode-go/gemini-4-argon | variant=high | google | ok |
| reviewer-a | last-resort | opencode | opencode-go/qwen3.8-max | - | alibaba | ok |
| reviewer-b | primary | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| reviewer-b | fallback | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | last-resort | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| reviewer-c | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-c | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-c | last-resort | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| reviewer-esc | primary | opencode | opencode-go/kimi-k3.1-pro | variant=high | moonshot | ok |
| reviewer-esc | fallback | opencode | opencode-go/deepseek-v4-pro | - | deepseek | ok |
| reviewer-esc | last-resort | opencode | opencode-go/mimo-v2.6-pro | - | xiaomi | ok |
| compaction | primary | opencode | opencode-go/claude-haiku-5-5 | variant=low | anthropic | ok |
| compaction | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Supported driver setups

The `driver` row stays advisory; the installer validates it when present, never requires it, and never renders it. Two setups are supported:

1. **OpenCode host:** native seats (for seats with an `opencode` rung), plus `delegate_task` when OpenCode runs inside T3 Code. Under `quad`, `implementer-deep`, `reviewer-b`, and `reviewer-c` have no `opencode` rung, so they are installed with no `model:` pin and reached only through `delegate_task`.
2. **Any T3 Code provider session** (for example Codex `gpt-6.1-sol`, Claude Code `claude-sonnet-5-5`, or Antigravity `gemini-4-argon`): tell the session to load `<dest>/HARNESS.md`, `<dest>/PROVIDERS.md`, and the skills from `<dest>/skills/`. It dispatches only via `delegate_task`, and permissions are self-enforced by the children.

## Privacy

The `ok` marks for Claude Code (`claudeAgent`), Antigravity (`antigravity`), and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. OpenCode Go rows use non-training privacy classes (`ok`). `muse-spark-*` trains on request data and is excluded from this profile.
