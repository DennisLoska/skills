# OpenCode Go provider profile

Provider: OpenCode Go (`opencode-go/*`, sized for the $40/mo Go Plus tier; the $10 Go tier grants 2x-8x less per model) for every non-review role. No Anthropic, Google, OpenAI, or low-allowance Pro models are routed through OpenCode Go. Cheap seats sit on high-allowance open-weight request tiers (18,960 to 90,600 req/5h): `deepseek-v4.1-flash`, `muse-spark-1.3-contributor`, `mimo-v2.6-flash`, and `glm-5.3-flash`.

The shared implementer and council ladders name Antigravity, Claude Code and Codex rungs (implementers on Claude Opus 5.5 / Fable 5.2 at `high`; council captain on `claude-fable-5-2`, Seat B `gpt-6-astra`, Seat C `gemini-4-hydrogen`). On an OpenCode-only host those rungs are `unreachable`: implementers demote to the OpenCode backup rows, and the council runs as `single-provider review: opencode` on the rows in `## Single-provider review`.

Effort defaults:
- **Tester and patch:** `deepseek-v4.1-flash` pinned `#high` (its middle tier; the catalog exposes `low|high|max`).
- **Implementers (backup rows):** `deepseek-v4.1-flash` `#high` (`implementer`) and `#max` (`implementer-deep`), then `glm-5.3-flash` `#high`.
- **Scout:** `mimo-v2.6-flash` (catalog exposes a single default reasoning tier, no `#variant` suffix; fallbacks pin `#low`).

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| implementer | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| implementer | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
| implementer | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| implementer-deep | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| implementer-deep | fallback | antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| implementer-deep | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| tester | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| tester | fallback | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| tester | last-resort | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| patch | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| patch | fallback | opencode | opencode-go/muse-spark-1.3-contributor | variant=medium | meta | trains |
| patch | last-resort | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| task-reviewer | primary | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| task-reviewer | fallback | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| task-reviewer | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| scout | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| scout | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=low | deepseek | ok |
| scout | last-resort | opencode | opencode-go/glm-5.3-flash | variant=low | zhipu | ok |
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
| compaction | fallback | opencode | opencode-go/glm-5.3-flash | variant=low | zhipu | ok |
| driver | primary | - | host-default | - | - | ok |

## Quota pools

Each OpenCode Go model has its own per-model monthly dollar limit and 5-hour cap (`<provider>/<model>` by default when no pool row matches):

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| opencode-go | opencode | * | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | implementer,tester,patch | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| 2 | implementer-deep | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| 3 | implementer,implementer-deep | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| 4 | task-reviewer | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |

## Single-provider review

| provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- |
| opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| opencode | opencode-go/muse-spark-1.3-contributor | variant=high | meta | trains |
| claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| antigravity | gemini-4-carbon | thinking_level=high | google | ok |

## Quotas and provider notes

Estimated allowance per model (req/5h, Go Plus $40/mo tier):

| Model | req/5h |
| --- | --- |
| muse-spark-1.3-contributor | 90,600 |
| deepseek-v4.1-flash | 86,670 |
| mimo-v2.6-flash | 60,200 |
| glm-5.3-flash | 18,960 |

Driver is advisory and uses the host default. Compaction is advisory and configured by the host.

Deepseek v4 models are cheapest off-peak: 01:00-04:00, 06:00-10:00 UTC Mon-Fri is peak.

## Privacy Footnotes

| Model | Reads your code as | Note |
| --- | --- | --- |
| muse-spark-\* | trains on request data | High-allowance workhorse (90,600 req/5h). Skip on confidential diffs via the privacy gate |
| deepseek v4 family | region-gated | Confirm Global region is enabled in Console Privacy |

GLM / MiMo via Go: not used for training, 0-day retention. Antigravity, Claude Code and Codex `ok` marks assume model-training opt-out on those accounts.

Compaction and summary never route to a training family.
