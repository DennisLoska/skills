# OpenCode Go provider profile

Provider: exclusively OpenCode Go (`opencode-go/*`, sized for the $40/mo Go Plus tier; the $10 Go tier grants 2x-8x less per model). No local or non-Go providers are used in this profile, and no Anthropic, Google, OpenAI, or low-allowance Pro models are routed through OpenCode Go. Every seat sits on high-allowance open-weight request tiers (18,960 to 90,600 req/5h): `deepseek-v4.1-flash`, `muse-spark-1.3-contributor`, `mimo-v2.6-flash`, and `glm-5.3-flash`.

Effort defaults:
- **Implementers and tester:** each seat pins its own effort variant (`implementer` `#high`, `implementer-deep` `#max`, `tester` `#high`; `patch` also pins `#high`). `deepseek-v4.1-flash` exposes `low|high|max` only, so `#high` is its middle tier, while `implementer-deep` and `reviewer-b` pin `#max`.
- **Reviewers:** `high` or higher reasoning effort (`#xhigh`, `#max`, `#high` on primaries; `#high` or default on every fallback and last resort).
- **Scout:** `mimo-v2.6-flash` (catalog exposes a single default reasoning tier, no `#variant` suffix; fallbacks pin `#low`).

Only `opencode-go/*` models are permitted in this profile.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| implementer | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| implementer | fallback | opencode | opencode-go/muse-spark-1.3-contributor | variant=medium | meta | trains |
| implementer | last-resort | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| implementer-deep | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| implementer-deep | fallback | opencode | opencode-go/muse-spark-1.3-contributor | variant=high | meta | trains |
| implementer-deep | last-resort | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
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
| reviewer-a | primary | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| reviewer-a | fallback | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| reviewer-a | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| reviewer-b | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| reviewer-b | fallback | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| reviewer-b | last-resort | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| reviewer-c | primary | opencode | opencode-go/muse-spark-1.3-contributor | variant=xhigh | meta | trains |
| reviewer-c | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| reviewer-c | last-resort | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| reviewer-esc | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| reviewer-esc | fallback | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| reviewer-esc | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| compaction | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| compaction | fallback | opencode | opencode-go/glm-5.3-flash | variant=low | zhipu | ok |
| driver | primary | - | host-default | - | - | ok |

## Quota pools

Each OpenCode Go model has its own per-model monthly dollar limit and 5-hour cap (`<provider>/<model>` by default when no pool row matches):

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | implementer,implementer-deep,tester,patch | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| 2 | reviewer-a,reviewer-b,reviewer-c,task-reviewer | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |

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

GLM / MiMo via Go: not used for training, 0-day retention.

Compaction and summary never route to a training family.

