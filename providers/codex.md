# Codex provider profile

Single-subscription OpenAI profile (`provider: codex`, `family: openai`). Use `--profile codex` when Codex is your only active subscription or when running standalone Codex CLI/App without cross-provider orchestration.

## Role distribution

- **Driver:** `gpt-6.1-sol` (`reasoningEffort=medium`), falling back to `gpt-6-astra` (`reasoningEffort=medium`).
- **Discovery (`scout`):** fast read-heavy `gpt-6-luna` (`reasoningEffort=low`) -> `gpt-6.1-terra` (`low`) -> `gpt-6.1-sol` (`low`).
- **Testing & surgical edits (`tester`, `patch`):** `gpt-6-luna` (`reasoningEffort=medium`) -> `gpt-6.1-terra` (`medium`) -> `gpt-6.1-sol` (`low`).
- **Implementation (`implementer`, `implementer-deep`):** everyday coding on `gpt-6.1-sol` (`medium`) -> `gpt-6-astra` (`medium`) -> `gpt-6.1-terra` (`high`); complex architecture and hard bugs on `gpt-6-astra` (`high`) -> `gpt-6.1-sol` (`high`) -> `gpt-6-sol` (`high`).
- **Per-task & council review (`task-reviewer`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`):** `high`-effort rungs across `gpt-6-astra`, `gpt-6.1-sol`, `gpt-6.1-terra`, and `gpt-6-sol`.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | codex | gpt-6-astra | reasoningEffort=medium | openai | ok |
| scout | primary | codex | gpt-6-luna | reasoningEffort=low | openai | ok |
| scout | fallback | codex | gpt-6.1-terra | reasoningEffort=low | openai | ok |
| scout | last-resort | codex | gpt-6.1-sol | reasoningEffort=low | openai | ok |
| implementer | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| implementer | fallback | codex | gpt-6-astra | reasoningEffort=medium | openai | ok |
| implementer | last-resort | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| implementer-deep | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| implementer-deep | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| implementer-deep | last-resort | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| tester | primary | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| tester | fallback | codex | gpt-6.1-terra | reasoningEffort=medium | openai | ok |
| tester | last-resort | codex | gpt-6.1-sol | reasoningEffort=low | openai | ok |
| patch | primary | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| patch | fallback | codex | gpt-6.1-terra | reasoningEffort=medium | openai | ok |
| patch | last-resort | codex | gpt-6.1-sol | reasoningEffort=low | openai | ok |
| task-reviewer | primary | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| task-reviewer | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| task-reviewer | last-resort | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-a | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-a | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-a | last-resort | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| reviewer-b | primary | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-b | fallback | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| reviewer-b | last-resort | codex | gpt-6-astra | reasoningEffort=medium | openai | ok |
| reviewer-c | primary | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| reviewer-c | fallback | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| reviewer-c | last-resort | codex | gpt-6-luna | reasoningEffort=high | openai | ok |
| reviewer-esc | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-esc | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-esc | last-resort | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| compaction | primary | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| codex | codex | * | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | * | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |

## Runtime behavior and privacy

- **Standalone Codex (no T3 Code):** dispatches every role natively via `spawn_agent` + `wait` with explicit `model` and `reasoning_effort` (Dispatch Adapter Path 3). Because every rung in this profile belongs to the `openai` family, standalone `task-reviewer` uses the `degraded task-review: single-family host (openai)` fallback when no cross-family provider is reachable, and the multi-family council stops with `yellow: degraded council` unless paired with another model family via T3 Code (`tri` or `quad`).
- **T3 Code session:** dispatches via `delegate_task` (`providerInstanceId: codex`); combine with another provider profile (`tri` or `quad`) for multi-family review and council consensus.
- **Privacy & advisory rows:** `ok` assumes the Codex account has model-training opt-out enabled. `driver` and `compaction` rows are advisory host recommendations; model IDs match `~/.codex/models_cache.json`.
