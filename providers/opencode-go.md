# OpenCode Go provider profile

Provider: exclusively OpenCode Go (`opencode-go/*`, $10/mo tier). No local or non-Go providers are used in this profile. Most seats sit on high-allowance request tiers (6,320 to 45,300 req/5h). Two are scarce and reserved: `implementer-deep` (440) for complex tasks and hard bugs, and `reviewer-esc` (147) for escalation only.

Effort defaults:
- **Implementers and tester:** each seat pins its own effort variant (`implementer` `#high`, `implementer-deep` `#high`, `tester` `#high`; `patch` also pins `#high`). `deepseek-v4.1-flash` exposes `low|high|max` only, so `#high` is its middle tier, while `reviewer-b` pins `#max`.
- **Reviewers:** `high` or higher reasoning effort (`#xhigh`, `#max`, `#high` on primaries; `#high` on every fallback and last resort).
- **Scout:** `mimo-v2.6-flash` (catalog exposes a single default reasoning tier, no `#variant` suffix; fallbacks pin `#low`).

Only `opencode-go/*` models are permitted in this profile.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| implementer | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| implementer | fallback | opencode | opencode-go/muse-spark-1.3-contributor | variant=medium | meta | trains |
| implementer | last-resort | opencode | opencode-go/gpt-6-luna | variant=medium | openai | ok |
| implementer-deep | primary | opencode | opencode-go/gemini-4-argon | variant=high | google | ok |
| implementer-deep | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| implementer-deep | last-resort | opencode | opencode-go/muse-spark-1.3-contributor | variant=high | meta | trains |
| tester | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| tester | fallback | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| tester | last-resort | opencode | opencode-go/gpt-6-luna | variant=medium | openai | ok |
| patch | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| patch | fallback | opencode | opencode-go/muse-spark-1.3-contributor | variant=medium | meta | trains |
| patch | last-resort | opencode | opencode-go/gpt-6-luna | variant=medium | openai | ok |
| task-reviewer | primary | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| task-reviewer | fallback | opencode | opencode-go/claude-haiku-5-5 | variant=high | anthropic | ok |
| task-reviewer | last-resort | opencode | opencode-go/gpt-6-luna | variant=high | openai | ok |
| scout | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| scout | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=low | deepseek | ok |
| scout | last-resort | opencode | opencode-go/glm-5.3-flash | variant=low | zhipu | ok |
| reviewer-a | primary | opencode | opencode-go/muse-spark-1.3-contributor | variant=xhigh | meta | trains |
| reviewer-a | fallback | opencode | opencode-go/claude-haiku-5-5 | variant=high | anthropic | ok |
| reviewer-a | last-resort | opencode | opencode-go/kimi-k3.1-pro | variant=high | moonshot | ok |
| reviewer-b | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| reviewer-b | fallback | opencode | opencode-go/gpt-6-luna | variant=high | openai | ok |
| reviewer-b | last-resort | opencode | opencode-go/kimi-k3.1-pro | variant=high | moonshot | ok |
| reviewer-c | primary | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| reviewer-c | fallback | opencode | opencode-go/claude-haiku-5-5 | variant=high | anthropic | ok |
| reviewer-c | last-resort | opencode | opencode-go/gpt-6-luna | variant=high | openai | ok |
| reviewer-esc | primary | opencode | opencode-go/kimi-k3.1-pro | variant=high | moonshot | ok |
| reviewer-esc | fallback | opencode | opencode-go/gemini-4-argon | variant=high | google | ok |
| reviewer-esc | last-resort | opencode | opencode-go/gpt-6-luna | variant=high | openai | ok |
| compaction | primary | opencode | opencode-go/claude-haiku-5-5 | variant=low | anthropic | ok |
| compaction | fallback | opencode | opencode-go/gpt-6-luna | variant=low | openai | ok |
| driver | primary | - | host-default | - | - | ok |

## Quotas and provider notes

Estimated allowance per model (req/5h):

| Model | req/5h |
| --- | --- |
| deepseek-v4.1-flash | 43,330 |
| muse-spark-1.3-contributor | 45,300 |
| gpt-6-luna | 4,230 |
| gemini-4-argon | 440 |
| glm-5.3-flash | 6,320 |
| claude-haiku-5-5 | 3,850 |
| mimo-v2.6-flash | 30,100 |
| kimi-k3.1-pro | 147 |

Driver is advisory and uses the host default. Compaction is advisory and configured by the host.

Deepseek v4 models are cheapest off-peak: 01:00-04:00, 06:00-10:00 UTC Mon-Fri is peak.

## Privacy Footnotes

| Model | Reads your code as | Note |
| --- | --- | --- |
| muse-spark-\* | trains on request data | High-allowance workhorse (45,300 req/5h). Skip on confidential diffs via the privacy gate |
| claude-haiku-5-5 | 30-day retention on requests | Reviewer fallback and compaction primary |
| deepseek v4 family | region-gated | Confirm Global region is enabled in Console Privacy |

GPT Luna models: not used for training, 30-day abuse-monitor retention.
GLM / Kimi / Gemini 4 Argon / MiMo via Go: not used for training, 0-day retention.

Compaction and summary never route to a training family.

