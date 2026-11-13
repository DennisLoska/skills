# Tri provider profile

Three subscriptions: Antigravity (Google + Anthropic models), Codex (OpenAI models), OpenCode Go Plus ($40/mo, open-weight flash and spark workhorses with large 5-hour allowances). Distribution principle: spend frontier output tokens where judgment matters most, switch provider quota pools on fallbacks so a single 429 never deadlocks a role, and keep OpenCode Go on high-allowance open-weight models for non-review roles.

- **Driver:** Codex `gpt-6.1-sol` (`medium`), Antigravity `claude-sonnet-5-5` (`medium`) fallback.
- **Discovery (`scout`):** OpenCode Go `mimo-v2.6-flash`, `deepseek-v4.1-flash` (`low`), Antigravity `gemini-3.8-flash`.
- **Testing & script running (`tester`, `patch`):** OpenCode Go `deepseek-v4.1-flash` (`high`), Codex `gpt-6-luna` (`medium`), Antigravity `gemini-3.8-flash`.
- **Implementation:** `implementer` runs on Antigravity `claude-opus-5-5` (`high`), then `gemini-4-carbon` and Codex `gpt-6.1-sol` (`high`); `implementer-deep` prefers `claudeAgent` `claude-fable-5-2` (`high`; unreachable without a Claude Code subscription, so it demotes to `gemini-4-hydrogen`), then `gpt-6.1-sol`.
- **Per-task review (`task-reviewer`):** Codex `gpt-6.1-terra` (`high`), OpenCode Go `glm-5.3-flash` (`high`), Antigravity `gemini-3.8-flash` (`high`), skipping author families.
- **Council:** Seat A, the review captain, prefers `claudeAgent` `claude-fable-5-2` and demotes to Codex `gpt-6.1-terra` here; Seat B runs on Codex `gpt-6-astra`; Seat C on Antigravity `gemini-4-hydrogen`, all at `high`. Review runs only on Anthropic, OpenAI and Google models; `## Single-provider review` covers the case where only one provider has budget left.

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

- **Antigravity:** carries `implementer` (`claude-opus-5-5`, then `gemini-4-carbon`), the `implementer-deep` fallback (`gemini-4-hydrogen`), and Seat C (`gemini-4-hydrogen`). For Claude Code subscriptions, use [`providers/quad.md`](./quad.md).
- **Codex:** carries `driver` (`gpt-6.1-sol`), `task-reviewer` (`gpt-6.1-terra`), Seat B (`gpt-6-astra`), the captain fallback, implementer last-resorts, and `gpt-6-luna` fallbacks for `tester`, `patch`, and `compaction`.
- **OpenCode Go Plus:** carries `scout`, `tester`, `patch`, `compaction` primary (`mimo-v2.6-flash`), and non-reviewer backup rows.
- **Council budget:** at most 3 rounds of 3 seats plus 3 captain rulings per PR.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |
| scout | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| scout | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=low | deepseek | ok |
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
| task-reviewer | fallback | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
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
| compaction | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| compaction | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| opencode-go | opencode | * | 5h | - | - |
| antigravity-claude | antigravity | claude-* | 5h | - | - |
| antigravity-gemini | antigravity | gemini-* | 5h | - | - |
| codex | codex | * | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | implementer,implementer-deep,tester,patch | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| 2 | task-reviewer | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| 3 | reviewer-a,reviewer-b,reviewer-c | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| 4 | reviewer-a,reviewer-b,reviewer-c | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| 5 | scout,implementer,implementer-deep,tester,patch,task-reviewer | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| 6 | scout,implementer,implementer-deep,tester,patch,task-reviewer | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| 7 | scout,implementer,implementer-deep,tester,patch,task-reviewer | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| 8 | scout,implementer,implementer-deep,tester,patch,task-reviewer | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |

## Single-provider review

When exactly one provider still has an eligible pool, every council seat draws pairwise-distinct, non-author models from that provider's rows (captain first).

| provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- |
| antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| opencode | opencode-go/muse-spark-1.3-contributor | variant=high | meta | trains |

## Supported driver setups

The `driver` row is advisory. Two setups are supported:

1. **Standalone host (without T3 Code):** OpenCode, Codex, or Antigravity (Gemini session) runs same-provider rungs natively via Dispatch Adapter Path 2/Path 3, falling back to matching `## Backup ladder` rows when primary rungs sit on other providers (standalone Claude Code uses `--profile claude` or `quad`; standalone Claude Antigravity sessions use `--profile antigravity`). Under `tri` on OpenCode, `implementer`, `implementer-deep`, and the council seats have no `opencode` ladder rung and install unpinned (never using Path 2).
2. **Any T3 Code provider session:** `./install.sh --target all` populates standalone roots and any T3 Antigravity instances (`skills/_harness/`), dispatching across all connected providers via `delegate_task` with child-enforced permissions.

## Privacy

The `ok` marks for Antigravity (`antigravity`), Codex (`codex`), and Claude Code (`claudeAgent`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. OpenCode Go rows use non-training privacy classes (`ok`), with `opencode-go/muse-spark-1.3-contributor` marked `trains` as it trains on request data (skip via privacy gate on confidential work).

Driver and compaction rows are advisory host recommendations; the installer validates them when present, never requires them, and never renders them.

## Catalog

Model ids are verified against the live provider catalogs: `opencode models` lists every `opencode-go/*` model id used in this table, and Codex model ids match `~/.codex/models_cache.json` (checked 2026-11-09; re-check with `orchestrator_capabilities` or `opencode models` after catalog updates). Allowance figures come from `opencode.ai/docs/go` on the Go Plus ($40/mo) tier; re-read them there when the plan changes, since Plus scales non-uniformly per model (2x-8x over Go).
