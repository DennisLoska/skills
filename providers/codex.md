# Codex provider profile

Single-subscription OpenAI profile (`provider: codex`, `family: openai`). Use `--profile codex` when Codex is your only active subscription or when running standalone Codex CLI/App without cross-provider orchestration. The shared implementer and council ladders also name Antigravity and Claude Code rungs; on a Codex-only host those rungs are `unreachable` and demote to the Codex rungs and backup rows below.

## Role distribution

- **Driver:** `gpt-6.1-sol` (`reasoningEffort=medium`), falling back to `gpt-6-astra` (`reasoningEffort=medium`).
- **Discovery (`scout`):** fast read-heavy `gpt-6-luna` (`reasoningEffort=low`) -> `gpt-6.1-terra` (`low`) -> `gpt-6.1-sol` (`low`).
- **Testing & surgical edits (`tester`, `patch`):** `gpt-6-luna` (`reasoningEffort=medium`) -> `gpt-6.1-terra` (`medium`) -> `gpt-6.1-sol` (`low`).
- **Implementation:** `implementer` prefers Antigravity `claude-opus-5-5` and `implementer-deep` Claude Code `claude-fable-5-2`, falling back to `gemini-4-carbon` and `gemini-4-hydrogen` respectively, then Codex `gpt-6.1-sol` (`high`). Backup rows keep `gpt-6-astra` and `gpt-6-sol` (`high`) for both.
- **Per-task review (`task-reviewer`):** `high`-effort rungs across `gpt-6.1-terra`, `gpt-6.1-sol`, and `gpt-6-astra`.
- **Council:** Seat A (captain) prefers Claude Code `claude-fable-5-2` and demotes to `gpt-6.1-terra`; Seat B runs on `gpt-6-astra`; Seat C prefers `gemini-4-hydrogen`. With only Codex reachable, `single-provider review: codex` seats draw from `gpt-6-astra`, `gpt-6.1-terra`, and `gpt-6.1-sol` at `high`.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | codex | gpt-6-astra | reasoningEffort=medium | openai | ok |
| scout | primary | codex | gpt-6-luna | reasoningEffort=low | openai | ok |
| scout | fallback | codex | gpt-6.1-terra | reasoningEffort=low | openai | ok |
| scout | last-resort | codex | gpt-6.1-sol | reasoningEffort=low | openai | ok |
| implementer | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| implementer | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| implementer | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| implementer-deep | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| implementer-deep | fallback | antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| implementer-deep | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| tester | primary | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| tester | fallback | codex | gpt-6.1-terra | reasoningEffort=medium | openai | ok |
| tester | last-resort | codex | gpt-6.1-sol | reasoningEffort=low | openai | ok |
| patch | primary | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| patch | fallback | codex | gpt-6.1-terra | reasoningEffort=medium | openai | ok |
| patch | last-resort | codex | gpt-6.1-sol | reasoningEffort=low | openai | ok |
| task-reviewer | primary | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| task-reviewer | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| task-reviewer | last-resort | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-a | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| reviewer-a | fallback | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| reviewer-a | last-resort | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| reviewer-b | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-b | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| reviewer-b | last-resort | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| reviewer-c | primary | antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| reviewer-c | fallback | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| reviewer-c | last-resort | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| compaction | primary | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| codex | codex | * | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | implementer,implementer-deep | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| 2 | implementer,implementer-deep | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| 3 | reviewer-a,reviewer-b,reviewer-c | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| 4 | scout,implementer,implementer-deep,tester,patch,task-reviewer | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |

## Single-provider review

| provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- |
| codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |

## Runtime behavior and privacy

- **Standalone Codex (no T3 Code):** dispatches every reachable role natively via `spawn_agent` + `wait` with explicit `model` and `reasoning_effort` (Dispatch Adapter Path 3). Because every reachable rung belongs to the `openai` family, standalone `task-reviewer` uses the `degraded task-review: single-family host (openai)` fallback, and the council runs as `single-provider review: codex` on distinct non-author models.
- **T3 Code session:** dispatches via `delegate_task` (`providerInstanceId: codex`); combine with another provider profile (`tri` or `quad`) for multi-family review.
- **Privacy & advisory rows:** `ok` assumes the Codex account has model-training opt-out enabled. `driver` and `compaction` rows are advisory host recommendations; model IDs match `~/.codex/models_cache.json`.
