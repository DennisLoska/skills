# Tri provider profile

Three subscriptions: Antigravity (Google + Anthropic models), Codex (OpenAI models), OpenCode Go Plus ($40/mo, open-weight flash and spark workhorses with large 5-hour allowances). Distribution principle: spend frontier output tokens where judgment matters most, switch provider quota pools on fallbacks so a single 429 never deadlocks a role, and keep OpenCode Go strictly on high-allowance open-weight models.

- **Driver:** Codex `gpt-6.1-sol` (`medium`), Antigravity `claude-sonnet-5-5` (`medium`) fallback.
- **Discovery (`scout`):** OpenCode Go `mimo-v2.6-flash`, `deepseek-v4.1-flash` (`low`), Antigravity `gemini-3.8-flash`.
- **Testing & script running (`tester`):** OpenCode Go `deepseek-v4.1-flash` (`high`), Codex `gpt-6-luna` (`medium`), Antigravity `gemini-3.8-flash`.
- **Implementation (`implementer`, `implementer-deep`, `patch`):** `implementer` runs on Antigravity `gemini-4-argon` (`high`), falling back to `claude-sonnet-5-5` (`medium`) and Codex `gpt-6.1-sol` (`medium`); `implementer-deep` runs on Antigravity `gemini-4-argon` (`high`), falling back to Codex `gpt-6-astra` (`high`) and OpenCode Go `deepseek-v4.1-flash` (`max`); `patch` shares the `tester` ladder for 1-2 file edits.
- **Per-task review (`task-reviewer`):** Codex `gpt-6.1-terra` (`high`), OpenCode Go `glm-5.3-flash` (`high`), Antigravity `gemini-3.8-flash` (`high`), skipping author families.
- **Council (`reviewer-a`, `reviewer-b`, `reviewer-c`):** OpenAI frontier on Seat A (`gpt-6-astra` via Codex, fallback `deepseek-v4.1-flash` at `high` and `max`), Anthropic frontier on Seat B (`claude-opus-5-5` via Antigravity, fallback `deepseek-v4.1-flash` at `high` and `max`), and Meta frontier on Seat C (`opencode-go/muse-spark-1.3-contributor`, fallback `deepseek-v4.1-flash` at `high` and `max`). Three non-author families whenever Argon authors code.
- **Escalation (`reviewer-esc`):** OpenCode Go `deepseek-v4.1-flash` (`deepseek`, `variant=high` and `variant=max`).

## Budget facts and provider load split

From the local Codex catalog (`~/.codex/models_cache.json`):

| Model | Codex description |
| --- | --- |
| `gpt-6-astra` | frontier intelligence for the most demanding work |
| `gpt-6.1-sol` | latest workhorse for coding and everyday work |
| `gpt-6.1-terra` | balanced, for straightforward work (5.6-terra wording) |
| `gpt-6-luna` | fast and affordable, for easier tasks |

No Anthropic (`claude-*`), Google (`gemini-*`), or OpenAI (`gpt-*`) model routes through OpenCode Go in `tri`. Limits use rolling 5-hour windows. OpenCode Go estimates on **Go Plus ($40/mo)**:

| Model | est. req/5h | Model | est. req/5h |
| --- | --- | --- | --- |
| muse-spark-1.3-contributor | ~90,600 | mimo-v2.6-flash | ~60,200 |
| deepseek-v4.1-flash | ~86,700 | glm-5.3-flash | ~19,000 |

Expensive low-allowance Pro models are excluded from `tri`.

Provider load split and council budget notes:

- **Antigravity:** carries `implementer` (`gemini-4-argon`), fallback `claude-sonnet-5-5`, `implementer-deep` (`gemini-4-argon`), and `reviewer-b` (`claude-opus-5-5`). `antigravity-claude` is soft-capped at 6 dispatches and reserved for `reviewer-b`. For Claude Code subscriptions, use [`providers/quad.md`](./quad.md).
- **Codex:** carries `driver` (`gpt-6.1-sol`), `task-reviewer` (`gpt-6.1-terra`), council Seat A (`gpt-6-astra`), `implementer` last-resort, `implementer-deep` fallback, and `gpt-6-luna` fallbacks for `tester`, `patch`, and `compaction`.
- **OpenCode Go Plus:** carries `scout`, `tester`, `patch`, `compaction` primary (`mimo-v2.6-flash`), `implementer-deep` last-resort, Seat C `reviewer-c`, cross-provider fallbacks for `reviewer-a`, `reviewer-b`, `task-reviewer`, and `reviewer-esc`, and the primary backup ladder rungs (`deepseek-v4.1-flash`).
- **Council budget:** at most 3 rounds × 3 seats + 1 escalation per PR. Seat A (`gpt-6-astra`), Seat B (`claude-opus-5-5`), and Seat C (`muse-spark-1.3-contributor`) give three non-author families when Argon authors code; `reviewer-esc` starts on `deepseek-v4.1-flash`.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |
| scout | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| scout | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=low | deepseek | ok |
| scout | last-resort | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| implementer | primary | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| implementer | fallback | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |
| implementer | last-resort | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| implementer-deep | primary | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| implementer-deep | fallback | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| implementer-deep | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| tester | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| tester | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| tester | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| patch | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| patch | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| patch | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| task-reviewer | primary | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| task-reviewer | fallback | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| task-reviewer | last-resort | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| reviewer-a | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-a | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| reviewer-a | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| reviewer-b | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| reviewer-b | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| reviewer-c | primary | opencode | opencode-go/muse-spark-1.3-contributor | variant=xhigh | meta | trains |
| reviewer-c | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| reviewer-c | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| reviewer-esc | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| reviewer-esc | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| reviewer-esc | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| compaction | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| compaction | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| opencode-go | opencode | * | 5h | - | - |
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
| 6 | * | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |

## Supported driver setups

The `driver` row is advisory. Two setups are supported:

1. **Standalone host (without T3 Code):** OpenCode, Codex, or Antigravity (Gemini session) runs same-provider rungs natively via Dispatch Adapter Path 2/Path 3, falling back to the matching `*` row in `## Backup ladder` when primary rungs sit on other providers (standalone Claude Code uses `--profile claude` or `quad`; standalone Claude Antigravity sessions use `--profile antigravity`). Under `tri` on OpenCode, `implementer` has no `opencode` ladder rung and installs unpinned (never using Path 2).
2. **Any T3 Code provider session:** `./install.sh --target all` populates standalone roots and any T3 Antigravity instances (`skills/_harness/`), dispatching across all connected providers via `delegate_task` with child-enforced permissions.

## Privacy

The `ok` marks for Antigravity (`antigravity`) and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. OpenCode Go rows use non-training privacy classes (`ok`), with `opencode-go/muse-spark-1.3-contributor` marked `trains` as it trains on request data (skip via privacy gate on confidential work).

Driver and compaction rows are advisory host recommendations; the installer validates them when present, never requires them, and never renders them.

## Catalog

Model ids are verified against the live provider catalogs: `opencode models` lists every `opencode-go/*` model id used in this table, and Codex model ids match `~/.codex/models_cache.json` (checked 2026-11-09; re-check with `orchestrator_capabilities` or `opencode models` after catalog updates). Allowance figures come from `opencode.ai/docs/go` on the Go Plus ($40/mo) tier; re-read them there when the plan changes, since Plus scales non-uniformly per model (2x-8x over Go).
