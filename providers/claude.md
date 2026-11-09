# Claude Code provider profile

Single-subscription Anthropic profile (`provider: claudeAgent`, `family: anthropic`). Use `--profile claude` when Claude Code is your only active subscription or when running standalone Claude Code without cross-provider orchestration.

## Role distribution

- **Driver:** `claude-sonnet-5-5` (`effort=medium`), falling back to `claude-opus-5-5` (`effort=medium`).
- **Discovery (`scout`):** `claude-haiku-5-5` (`effort=low`) -> `claude-sonnet-5-5` (`low`) -> `claude-fable-5-1` (`low`).
- **Testing & surgical edits (`tester`, `patch`):** `claude-haiku-5-5` (`effort=medium`) -> `claude-sonnet-5-5` (`medium`) -> `claude-fable-5-1` (`medium`).
- **Implementation (`implementer`, `implementer-deep`):** `implementer` runs on `claude-sonnet-5-5` (`effort=high`) -> `claude-opus-5-5` (`medium`) -> `claude-haiku-5-5` (`high`); `implementer-deep` runs on `claude-opus-5-5` (`high`) -> `claude-sonnet-5-5` (`high`) -> `claude-fable-5-1` (`high`).
- **Per-task & council review (`task-reviewer`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`):** `high`-effort rungs across `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-fable-5-1`, and `claude-haiku-5-5`.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| driver | fallback | claudeAgent | claude-opus-5-5 | effort=medium | anthropic | ok |
| scout | primary | claudeAgent | claude-haiku-5-5 | effort=low | anthropic | ok |
| scout | fallback | claudeAgent | claude-sonnet-5-5 | effort=low | anthropic | ok |
| scout | last-resort | claudeAgent | claude-fable-5-1 | effort=low | anthropic | ok |
| implementer | primary | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| implementer | fallback | claudeAgent | claude-opus-5-5 | effort=medium | anthropic | ok |
| implementer | last-resort | claudeAgent | claude-haiku-5-5 | effort=high | anthropic | ok |
| implementer-deep | primary | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| implementer-deep | fallback | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| implementer-deep | last-resort | claudeAgent | claude-fable-5-1 | effort=high | anthropic | ok |
| tester | primary | claudeAgent | claude-haiku-5-5 | effort=medium | anthropic | ok |
| tester | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| tester | last-resort | claudeAgent | claude-fable-5-1 | effort=medium | anthropic | ok |
| patch | primary | claudeAgent | claude-haiku-5-5 | effort=medium | anthropic | ok |
| patch | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| patch | last-resort | claudeAgent | claude-fable-5-1 | effort=medium | anthropic | ok |
| task-reviewer | primary | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| task-reviewer | fallback | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| task-reviewer | last-resort | claudeAgent | claude-haiku-5-5 | effort=high | anthropic | ok |
| reviewer-a | primary | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| reviewer-a | fallback | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| reviewer-a | last-resort | claudeAgent | claude-haiku-5-5 | effort=high | anthropic | ok |
| reviewer-b | primary | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| reviewer-b | fallback | claudeAgent | claude-fable-5-1 | effort=high | anthropic | ok |
| reviewer-b | last-resort | claudeAgent | claude-haiku-5-5 | effort=high | anthropic | ok |
| reviewer-c | primary | claudeAgent | claude-fable-5-1 | effort=high | anthropic | ok |
| reviewer-c | fallback | claudeAgent | claude-haiku-5-5 | effort=high | anthropic | ok |
| reviewer-c | last-resort | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| reviewer-esc | primary | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| reviewer-esc | fallback | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| reviewer-esc | last-resort | claudeAgent | claude-fable-5-1 | effort=high | anthropic | ok |
| compaction | primary | claudeAgent | claude-haiku-5-5 | effort=low | anthropic | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| claude-code | claudeAgent | * | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | * | claudeAgent | claude-haiku-5-5 | effort=medium | anthropic | ok |

## Runtime behavior and privacy

- **Standalone Claude Code (no T3 Code):** dispatches every role natively via `Agent` (`run_in_background: false`, seat subagent or general-purpose for `task-reviewer`/`design`) with explicit `model` (Dispatch Adapter Path 3). Because every rung in this profile belongs to the `anthropic` family, standalone `task-reviewer` uses the `degraded task-review: single-family host (anthropic)` fallback when no cross-family provider is reachable, and the multi-family council stops with `yellow: degraded council` unless paired with another model family via T3 Code (`quad`).
- **T3 Code session:** dispatches via `delegate_task` (`providerInstanceId: claudeAgent`); combine with other providers via `--profile quad` for multi-family review and council consensus.
- **Privacy & advisory rows:** `ok` assumes the Claude account has model-training opt-out enabled. `driver` and `compaction` rows are advisory host recommendations.
