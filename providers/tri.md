# Tri provider profile

Three subscriptions: Antigravity (Google + Anthropic models), Codex (OpenAI models), OpenCode Go (open-weight long tail, cheap high-allowance quota). Distribution principle, token-output efficiency: spend frontier output tokens only where each token carries the most judgment, and push volume to the cheapest model that is still reliable for it.

- **Driver** emits little (briefs, verdicts, gate decisions) but its mistakes fan out to every child: frontier model, high effort.
- **Discovery** is read-heavy, write-light: a long-context flash model at low effort. Output is a compressed `path:line` table, so the expensive part is input, which flash models price lowest.
- **Implementation** produces the bulk of all output tokens: strong mid-tier coders at medium effort; frontier only for `implementer-deep`.
- **Per-task review** runs once per task, often: a flash model from a family that did not write the code.
- **Council** outputs are short and decide the merge: one frontier model per family (Google, Anthropic, OpenAI) at equal `high` effort so votes are comparable. Each seat demotes inside its own family first (across providers where possible), then out of family.
- **Escalation** is a fourth family none of the seats uses, so its verdict stays independent.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| driver | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| scout | primary | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| scout | fallback | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| scout | last-resort | codex | gpt-6-luna | reasoningEffort=low | openai | ok |
| implementer | primary | codex | gpt-6.1-terra | reasoningEffort=medium | openai | ok |
| implementer | fallback | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |
| implementer | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| implementer-b | primary | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |
| implementer-b | fallback | codex | gpt-6.1-terra | reasoningEffort=medium | openai | ok |
| implementer-b | last-resort | opencode | opencode-go/glm-5.3 | variant=high | zhipu | ok |
| implementer-deep | primary | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| implementer-deep | fallback | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| implementer-deep | last-resort | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| patch | primary | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| patch | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| patch | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| task-reviewer | primary | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| task-reviewer | fallback | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| task-reviewer | last-resort | codex | gpt-6-luna | reasoningEffort=high | openai | ok |
| reviewer-a | primary | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| reviewer-a | fallback | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| reviewer-a | last-resort | opencode | opencode-go/glm-5.3 | variant=high | zhipu | ok |
| reviewer-b | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | fallback | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | last-resort | opencode | opencode-go/claude-haiku-5-5 | variant=high | anthropic | ok |
| reviewer-c | primary | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-c | fallback | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| reviewer-c | last-resort | opencode | opencode-go/gpt-6-luna | variant=high | openai | ok |
| reviewer-esc | primary | opencode | opencode-go/kimi-k3.1-pro | variant=high | moonshot | ok |
| reviewer-esc | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| reviewer-esc | last-resort | opencode | opencode-go/glm-5.3 | variant=high | zhipu | ok |
| compaction | primary | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| compaction | fallback | opencode | opencode-go/claude-haiku-5-5 | variant=low | anthropic | ok |

## Privacy

The `ok` marks for Antigravity (`antigravity`) and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. OpenCode Go rows use the legacy profile’s non-training privacy classes. `muse-spark-*` trains on request data and is excluded from this profile.

Driver and compaction rows are advisory host recommendations; the installer does not validate or render them.
