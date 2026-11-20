# Opencode-Go provider profile

All six shipped profiles and every `--providers` combination share the same model policy. Profile/provider selection records the connection preference, not an exclusive provider allowlist. Cross-provider roles remain portable: unavailable rungs are marked unreachable; design/planning stops when its exact ladder is unavailable, and review never substitutes an excluded model. A standalone host may therefore stop at an unreachable terminal operational rung while unavailable review members are skipped. Refresh migrates existing shipped installs to this policy; custom profile files retain their own ladders and legacy emergency routing when no explicit operational last-resort exists.

## Role distribution

- **Driver:** Antigravity `gemini-4-neon` at `high`, falling back to Codex `gpt-6.2-sol` at `high`, then Claude Fable 5.2 at `high` as last resort. Invoking a skill does not switch the driver.
- **Design and planning drafts:** `designer` (`shape`, `domain-modeling`, `codebase-design`) and `planner` (`plan`) delegate read-only drafts to Claude Fable 5.2 at `high`, falling back to Sol at `high`, then Gemini 4 Neon at `high`. The driver owns conversation, approvals, canonical artifacts and phase advancement.
- **Discovery, testing, patching:** OpenCode Go Deepseek V4.1 Flash at `variant=high`, then GPT Luna and Gemini 4 Hydrogen at `low` for discovery or `medium` for testing and patching.
- **Implementation:** Antigravity Gemini 4 Neon primary at `high` (falling back to Claude Code Opus 5.5 at `high`, then terminal Codex Sol at `high`), and Claude Code Fable 5.2 deep at `high` (falling back to Codex Sol at `high`, then terminal Antigravity Gemini 4 Neon at `high`).
- **Per-task review:** GPT Sol, then GPT Astra, then Claude Fable 5.2, all at `high`; self-review is allowed.
- **Council:** Opus 5.5 is preferred captain (A) at `effort=xhigh`, Sol is Seat B at `reasoningEffort=xhigh`, and Gemini 4 Neon is Seat C at `thinking_level=xhigh`. Council fallbacks, backups and captain rulings use only these models and efforts. Simultaneously active models stay distinct; self-review is allowed and unavailable members are skipped.
- **Compaction:** Gemini 4 Hydrogen at `low`, then GPT Luna at `low`.

## Budget facts and provider load split

Antigravity carries only Gemini routes, including Gemini 4 Neon for driver primary, primary implementation, deep implementation last-resort, designer/planner last-resort, and council Seat C, plus Gemini 4 Hydrogen for operational last-resort and compaction. Claude Code carries Opus implementation fallback, Fable deep implementation, designer/planner primary, driver last-resort, and the review captain. Codex carries driver/designer/planner/deep fallbacks, operational fallbacks/last-resort, Sol council review, and Sol/Astra task review. OpenCode Go carries only Deepseek Flash for cheap non-review work. Non-council effort is at most `high`; only council seats and captain rulings permit `xhigh`. Defaults require context-scoped runtime verification; max/ultra/ultrathink/ultracode are forbidden everywhere.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | antigravity | gemini-4-neon | thinking_level=high | google | ok |
| driver | fallback | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
| driver | last-resort | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| designer | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| designer | fallback | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
| designer | last-resort | antigravity | gemini-4-neon | thinking_level=high | google | ok |
| planner | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| planner | fallback | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
| planner | last-resort | antigravity | gemini-4-neon | thinking_level=high | google | ok |
| scout | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| scout | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |
| scout | last-resort | antigravity | gemini-4-hydrogen | thinking_level=low | google | ok |
| implementer | primary | antigravity | gemini-4-neon | thinking_level=high | google | ok |
| implementer | fallback | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| implementer | last-resort | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
| implementer-deep | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| implementer-deep | fallback | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
| implementer-deep | last-resort | antigravity | gemini-4-neon | thinking_level=high | google | ok |
| tester | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| tester | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| tester | last-resort | antigravity | gemini-4-hydrogen | thinking_level=medium | google | ok |
| patch | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| patch | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| patch | last-resort | antigravity | gemini-4-hydrogen | thinking_level=medium | google | ok |
| task-reviewer | primary | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
| task-reviewer | fallback | codex | gpt-6.2-astra | reasoningEffort=high | openai | ok |
| task-reviewer | last-resort | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| reviewer-a | primary | claudeAgent | claude-opus-5-5 | effort=xhigh | anthropic | ok |
| reviewer-a | fallback | codex | gpt-6.2-sol | reasoningEffort=xhigh | openai | ok |
| reviewer-a | last-resort | antigravity | gemini-4-neon | thinking_level=xhigh | google | ok |
| reviewer-b | primary | codex | gpt-6.2-sol | reasoningEffort=xhigh | openai | ok |
| reviewer-b | fallback | antigravity | gemini-4-neon | thinking_level=xhigh | google | ok |
| reviewer-b | last-resort | claudeAgent | claude-opus-5-5 | effort=xhigh | anthropic | ok |
| reviewer-c | primary | antigravity | gemini-4-neon | thinking_level=xhigh | google | ok |
| reviewer-c | fallback | claudeAgent | claude-opus-5-5 | effort=xhigh | anthropic | ok |
| reviewer-c | last-resort | codex | gpt-6.2-sol | reasoningEffort=xhigh | openai | ok |
| compaction | primary | antigravity | gemini-4-hydrogen | thinking_level=low | google | ok |
| compaction | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| opencode-go | opencode | * | 5h | - | - |
| claude-fable | claudeAgent | claude-fable* | 5h | - | - |
| claude-code | claudeAgent | * | 5h | - | - |
| antigravity-gemini | antigravity | gemini-* | 5h | - | - |
| codex | codex | * | 5h | - | - |

## Backup ladder

Only review backup rows ship; operational last-resort rungs are terminal. Resolve quota, privacy, effort and distinct active models before selecting any row.

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 3 | task-reviewer | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
| 4 | task-reviewer | codex | gpt-6.2-astra | reasoningEffort=high | openai | ok |
| 5 | task-reviewer | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| 6 | reviewer-a,reviewer-b,reviewer-c | claudeAgent | claude-opus-5-5 | effort=xhigh | anthropic | ok |
| 7 | reviewer-a,reviewer-b,reviewer-c | codex | gpt-6.2-sol | reasoningEffort=xhigh | openai | ok |
| 8 | reviewer-a,reviewer-b,reviewer-c | antigravity | gemini-4-neon | thinking_level=xhigh | google | ok |

## Single-provider review

Council tries configured seats and fallbacks, skipping unavailable/exhausted members without widening the allowlist. One available reviewer may PASS regardless of provider count, inside or outside oneshot, with a real same-head final vote, zero unresolved accepted findings and green actual checks. Self-review is allowed; authorship is audit-only. Zero reviewers records `council_verdict: SKIPPED round=<n> mode=unavailable head=<sha>` with all configured attempt/skip reasons, never PASS. Land may proceed with matching HEAD and green actual verification; no no-tests waiver for single/unavailable. Actual review FAIL and unresolved accepted findings still block.

| provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- |
| claudeAgent | claude-opus-5-5 | effort=xhigh | anthropic | ok |
| codex | gpt-6.2-sol | reasoningEffort=xhigh | openai | ok |
| antigravity | gemini-4-neon | thinking_level=xhigh | google | ok |

## Supported driver setups

The `driver` row stays advisory; the installer validates it when present, never requires it, and never renders it. Two setups are supported:

1. **Standalone host (without T3 Code):** OpenCode, Codex, Antigravity (Gemini session), or Claude Code runs same-provider rungs natively via Dispatch Adapter Path 2/Path 3 (respecting terminal operational rungs; single-provider users can also bind `--profile opencode-go|codex|antigravity|claude`). Under every shipped profile on OpenCode, `implementer`, `implementer-deep`, and the council seats have no `opencode` ladder rung and install unpinned (never using Path 2).
2. **Any T3 Code provider session:** `./install.sh --target all` populates standalone roots and any T3 Antigravity instances (`skills/_harness/`), dispatching across all connected providers via `delegate_task` with child-enforced permissions.

## Privacy

The `ok` marks for Claude Code (`claudeAgent`), Antigravity (`antigravity`), and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. The Deepseek Flash OpenCode Go rows use the non-training privacy class (`ok`).
