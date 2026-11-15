# Quad provider profile

All six shipped profiles and every `--providers` combination share the same model policy. Profile/provider selection records the connection preference, not an exclusive provider allowlist. Cross-provider roles remain portable: unavailable rungs are marked unreachable; design/planning stops when its exact ladder is unavailable, and review never substitutes an excluded model. A standalone host may therefore stop at an unreachable terminal operational rung or lack review quorum. Refresh migrates existing shipped installs to this policy; custom profile files retain their own ladders and legacy emergency routing when no explicit operational last-resort exists.

## Role distribution

- **Driver:** Codex `gpt-6.1-sol` at `medium`, with Claude Sonnet 5.5 at `medium` as fallback. Invoking a skill does not switch the driver.
- **Design and planning drafts:** `designer` (`shape`, `domain-modeling`, `codebase-design`) and `planner` (`plan`) delegate read-only drafts to Claude Fable 5.2 at `high`, falling back only to Sol at `high`. The driver owns conversation, approvals, canonical artifacts and phase advancement.
- **Discovery, testing, patching:** OpenCode Go Deepseek V4.1 Flash at `variant=high`, then GPT Luna and Gemini 3.8 Flash at `low` for discovery or `medium` for testing and patching.
- **Implementation:** Claude Code Opus 5.5 primary and Fable 5.2 deep at `high`; both fall back to Codex Sol at `high`, then terminal Antigravity Gemini Argon at `high`.
- **Per-task review:** GPT Sol, then GPT Astra, then Claude Fable 5.2, all at `high`, with author-family/model exclusions enforced by the harness.
- **Council:** Fable 5.2 is preferred captain (A), GPT Astra is Seat B, and GPT Sol is Seat C, all at `high`. Every fallback, backup and captain ruling stays within this exact three-model allowlist. A model that authored the diff is excluded across all providers. For Fable-authored changes, a healthy GPT seat becomes captain; it cannot receive Fable's author vote.
- **Compaction:** Gemini 3.8 Flash at `low`, then GPT Luna at `low`.

## Budget facts and provider load split

Antigravity carries only Gemini routes. Claude Code carries Opus implementation, Fable deep implementation and the review captain. Codex carries operational fallbacks, the driver and both GPT review models. OpenCode Go carries only Deepseek Flash for cheap non-review work. Every explicit effort is at most `high`; default effort requires runtime verification before dispatch.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| designer | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| designer | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| planner | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| planner | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| scout | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| scout | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |
| scout | last-resort | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| implementer | primary | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| implementer | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| implementer | last-resort | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| implementer-deep | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| implementer-deep | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| implementer-deep | last-resort | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| tester | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| tester | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| tester | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| patch | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| patch | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| patch | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
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
| antigravity-gemini | antigravity | gemini-* | 5h | - | - |
| codex | codex | * | 5h | - | - |

## Backup ladder

Only review backup rows ship; operational last-resort rungs are terminal. Resolve author exclusions and distinct active models before selecting any row.

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 3 | task-reviewer,reviewer-a,reviewer-b,reviewer-c | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| 4 | task-reviewer,reviewer-a,reviewer-b,reviewer-c | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| 5 | task-reviewer,reviewer-a,reviewer-b,reviewer-c | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |

## Single-provider review

In oneshot, optional `mode=single` permits one independent allowed reviewer when 1 or 2 profile provider instances have an eligible pool across all roles (quota, soft-cap, privacy and reachability checked). Codex retains Astra and Sol; Claude Code permits Fable alone if non-author. More than 2 providers retain normal 2+ quorum; zero/unknown providers or zero independent reviewers stop. Audit IDs/count/HEAD and captain/reviewer at council start, demotion and freshly before merge; stale/missing evidence cannot unlock single. Green actual checks and a real same-head PASS with zero unresolved accepted findings are required. Antigravity-only and OpenCode-only review stop. Never widen the allowlist or waive author exclusion. Primary seats remain distinct; this is runtime quorum reduction only.

| provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- |
| claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |

## Supported driver setups

The `driver` row stays advisory; the installer validates it when present, never requires it, and never renders it. Two setups are supported:

1. **Standalone host (without T3 Code):** OpenCode, Codex, Antigravity (Gemini session), or Claude Code runs same-provider rungs natively via Dispatch Adapter Path 2/Path 3 (respecting terminal operational rungs; single-provider users can also bind `--profile opencode-go|codex|antigravity|claude`). Under every shipped profile on OpenCode, `implementer`, `implementer-deep`, and the council seats have no `opencode` ladder rung and install unpinned (never using Path 2).
2. **Any T3 Code provider session:** `./install.sh --target all` populates standalone roots and any T3 Antigravity instances (`skills/_harness/`), dispatching across all connected providers via `delegate_task` with child-enforced permissions.

## Privacy

The `ok` marks for Claude Code (`claudeAgent`), Antigravity (`antigravity`), and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. The Deepseek Flash OpenCode Go rows use the non-training privacy class (`ok`).
