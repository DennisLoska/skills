# Opencode-Go provider profile

All six shipped profiles and every `--providers` combination share the same model policy. Profile/provider selection records the connection preference, not an exclusive provider allowlist. Cross-provider roles remain portable: unavailable rungs are marked unreachable; design/planning stops when its exact ladder is unavailable, and review never substitutes an excluded model. A single-provider host may therefore be unable to complete the pipeline.

## Role distribution

- **Driver:** Codex `gpt-6.1-sol` at `medium`, with Claude Sonnet 5.5 at `medium` as fallback. Invoking a skill does not switch the driver.
- **Design and planning drafts:** `designer` (`shape`, `domain-modeling`, `codebase-design`) and `planner` (`plan`) delegate read-only drafts to Claude Fable 5.2 at `high`, falling back only to Sol at `high`. The driver owns conversation, approvals, canonical artifacts and phase advancement.
- **Discovery, testing, patching:** OpenCode Go Deepseek V4.1 Flash at `variant=high`, then Gemini 3.8 Flash and GPT Luna at `low` for discovery or `medium` for testing and patching.
- **Implementation:** Claude Opus 5.5 at `high` on Antigravity, with the same-model Claude Code alternate. Deep implementation uses Claude Fable 5.2 at `high`.
- **Per-task review:** GPT Sol, then GPT Astra, then Claude Fable 5.2, all at `high`, with author-family/model exclusions enforced by the harness.
- **Council:** Fable 5.2 is preferred captain (A), GPT Astra is Seat B, and GPT Sol is Seat C, all at `high`. Every fallback, backup and captain ruling stays within this exact three-model allowlist. A model that authored the diff is excluded across all providers. For Fable-authored changes, a healthy GPT seat becomes captain; it cannot receive Fable's author vote.
- **Compaction:** Gemini 3.8 Flash at `low`, then GPT Luna at `low`.

## Budget facts and provider load split

Antigravity isolates Gemini and Claude quota pools. Claude Code carries deep implementation, the Opus alternate, and the Fable review captain. Codex carries the driver and both GPT review models. OpenCode Go carries only Deepseek Flash for cheap non-review work. Every explicit effort is at most `high`; default effort requires runtime verification before dispatch.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| designer | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| designer | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| planner | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| planner | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| scout | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| scout | fallback | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| scout | last-resort | codex | gpt-6-luna | reasoningEffort=low | openai | ok |
| implementer | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| implementer | fallback | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| implementer | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| implementer-deep | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| implementer-deep | fallback | antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
| implementer-deep | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| tester | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| tester | fallback | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| tester | last-resort | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| patch | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| patch | fallback | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| patch | last-resort | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| task-reviewer | primary | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| task-reviewer | fallback | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| task-reviewer | last-resort | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| reviewer-a | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| reviewer-a | fallback | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-a | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-b | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-b | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-b | last-resort | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| reviewer-c | primary | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-c | fallback | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-c | last-resort | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| compaction | primary | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| compaction | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| opencode-go | opencode | * | 5h | - | - |
| claude-code | claudeAgent | * | 5h | - | - |
| antigravity-claude | antigravity | claude-* | 5h | - | - |
| antigravity-gemini | antigravity | gemini-* | 5h | - | - |
| codex | codex | * | 5h | - | - |

## Backup ladder

Review rows are separate from implementation rows: no cheap or mixed backup grants review eligibility. Resolve author exclusions and distinct active models before selecting any row.

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | implementer | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| 2 | scout,implementer,implementer-deep,tester,patch | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| 3 | task-reviewer,reviewer-a,reviewer-b,reviewer-c | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| 4 | task-reviewer,reviewer-a,reviewer-b,reviewer-c | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| 5 | task-reviewer,reviewer-a,reviewer-b,reviewer-c | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| 6 | scout,implementer,implementer-deep,tester,patch | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| 7 | scout,implementer,implementer-deep,tester,patch | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |

## Single-provider review

When only Codex remains, run a degraded two-seat council on Astra and Sol only if both are eligible non-author models. If either authored the diff, stop with fewer than two independent models. Claude Code has only one allowed review model, so Claude-only review stops; Antigravity-only and OpenCode-only review also stop. Never add excluded models or waive the self-review ban to recover a seat.

| provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- |
| codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |

## Supported driver setups

The `driver` row stays advisory; the installer validates it when present, never requires it, and never renders it. Two setups are supported:

1. **Standalone host (without T3 Code):** OpenCode, Codex, Antigravity (Gemini session; Claude sessions use `--profile antigravity`), or Claude Code runs same-provider rungs natively via Dispatch Adapter Path 2/Path 3 (falling back to matching `## Backup ladder` rows when primary rungs sit on other providers; single-provider users can also bind `--profile opencode-go|codex|antigravity|claude`). Under every shipped profile on OpenCode, `implementer`, `implementer-deep`, and the council seats have no `opencode` ladder rung and install unpinned (never using Path 2).
2. **Any T3 Code provider session:** `./install.sh --target all` populates standalone roots and any T3 Antigravity instances (`skills/_harness/`), dispatching across all connected providers via `delegate_task` with child-enforced permissions.

## Privacy

The `ok` marks for Claude Code (`claudeAgent`), Antigravity (`antigravity`), and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. The Deepseek Flash OpenCode Go rows use the non-training privacy class (`ok`).
