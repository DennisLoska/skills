# Quad Provider Profile Refactor for Claude Code Integration

Date: 2026-11-10. Branch: `feat/quad-claude-routing`.
Status: Approved.

## Why

Claude Code is now installed and verified on the machine with T3 Code integration (`providerInstanceId: claudeAgent`). With four active subscriptions—Antigravity, Codex, OpenCode Go, and Claude Code—the `quad` provider profile must be refined to:
1. Provide an optimal distribution of Anthropic models across roles (Sonnet 5.5, Opus 5.5, Fable 5.2/5.1, and Haiku 5.5).
2. Exploit separate quota pools accurately: Antigravity's `antigravity-claude` is soft-capped at 6 dispatches per run, reserved for `reviewer-b` (separate from `antigravity-gemini`), so Antigravity Claude models are retained as a secondary reserve, while primary Anthropic workloads route through direct `claudeAgent`.
3. Purge expensive quota-draining OpenCode models (`kimi-k3.1-pro` at ~147 req/5h and `qwen3.8-max` at ~160 req/5h) in favor of high-allowance, cost-effective models (`mimo-v2.6-pro` at ~3,250 req/5h, `minimax-m3` at ~3,200 req/5h, and `glm-5.3-flash` at ~19,000 req/5h).
4. Clarify and enforce the Author Independence invariant in `quad.md` so that `task-reviewer` and Council consensus deterministically avoid self-grading without arbitrary LLM guessing.
5. Update `providers/quad.md`, documentation, and tests to validate the refined quad distribution.

## Quota Facts & Provider Load Split

| Provider / Pool | Available Models | Quota Characteristics | Optimal Roles in Quad |
| :--- | :--- | :--- | :--- |
| **Antigravity (gemini)** | `gemini-4-argon`, `gemini-3.8-flash` | High 5h allowance | Primary `implementer` (`gemini-4-argon`), fast fallback `scout`/`tester` (`gemini-3.8-flash`) |
| **Antigravity (claude)** | `claude-opus-5-5`, `claude-sonnet-5-5` | Tight pool (soft-cap 6 dispatches/run, 5h cooldown) | Reserved fallback for `implementer-deep` (pre-cap) and Council Seat B (`reviewer-b`) |
| **Claude Code (`claudeAgent`)** | `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-fable-5-2`, `claude-haiku-5-5` | Direct Anthropic subscription | Primary `implementer-deep` (`opus`), implementer fallback (`sonnet`), Council Seat B primary (`opus`), advisory design (`fable`), compaction (`haiku`) |
| **Codex (`codex`)** | `gpt-6.1-sol`, `gpt-6-astra`, `gpt-6.1-terra`, `gpt-6-luna` | Rolling 5h subscription window | Primary `driver` (`sol`), `task-reviewer` primary (`terra`), Council Seat A (`astra`) |
| **OpenCode Go (`opencode`)** | `deepseek-v4.1-flash`, `mimo-v2.6-flash`, `deepseek-v4-pro`, `mimo-v2.6-pro`, `minimax-m3`, `glm-5.3-flash` | High request allowances (~3,200 to ~43,000 req/5h) | High-volume `scout`, `tester`, `patch`, Council Seat C (`deepseek-v4-pro`), Council escalation (`reviewer-esc`) |

## Role Allocation & Fallback Ladders

### 1. Claude Model Family Specialization

- **Claude Sonnet 5.5 (`claude-sonnet-5-5`):**
  - Coding & speed workhorse.
  - Serves as the immediate fallback for `implementer` (behind `gemini-4-argon`).
  - Serves as the cross-family `task-reviewer` fallback (when OpenAI models author code).
  - Serves as `driver` fallback behind `gpt-6.1-sol`.
- **Claude Opus 5.5 (`claude-opus-5-5`):**
  - Frontier reasoning.
  - Primary for `implementer-deep` (complex architectural tasks & tough bug escalations).
  - Primary for Council Seat B (`reviewer-b`).
  - Secondary fallback remains Antigravity's `claude-opus-5-5` (pre-soft-cap).
- **Claude Fable (`claude-fable-5-2` / `claude-fable-5-1`):**
  - Nuanced conceptual synthesis, system design, and qualitative critique.
  - Advisory recommendation for Phase 1 Architecture & Design sessions. (Note: Council escalation is barred to Anthropic because Seat B is permanently Anthropic per Council independence rules).
- **Claude Haiku 5.5 (`claude-haiku-5-5`):**
  - Lightweight and high-throughput.
  - Primary for `compaction` (summarizing long histories) on direct Claude subscription.

### 2. Full Ladder Matrix (`providers/quad.md`)

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| scout | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| scout | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=low | deepseek | ok |
| scout | last-resort | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| implementer | primary | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| implementer | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
| implementer | last-resort | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| implementer-deep | primary | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| implementer-deep | fallback | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| implementer-deep | last-resort | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| tester | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| tester | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| tester | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| patch | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| patch | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| patch | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| task-reviewer | primary | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| task-reviewer | fallback | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| task-reviewer | last-resort | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| reviewer-a | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-a | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-a | last-resort | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| reviewer-b | primary | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
| reviewer-b | fallback | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | last-resort | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |
| reviewer-c | primary | opencode | opencode-go/muse-spark-1.3-contributor | variant=xhigh | meta | trains |
| reviewer-c | fallback | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| reviewer-c | last-resort | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| reviewer-esc | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| reviewer-esc | fallback | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| reviewer-esc | last-resort | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| compaction | primary | claudeAgent | claude-haiku-5-5 | effort=low | anthropic | ok |
| compaction | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

### 3. Author Independence Invariant

`quad.md` explicitly documents how author independence operates across rungs:
- `task-reviewer` ladder: primary is OpenAI (`gpt-6.1-terra`), fallback is Anthropic (`claude-sonnet-5-5`), last-resort is Google (`gemini-3.8-flash`). When code is authored by Google (Gemini Argon), primary OpenAI dispatches immediately. When code is authored by OpenAI (`gpt-6.1-sol`), the driver advances to fallback Anthropic (`claude-sonnet-5-5`). Zero self-grading.
- Council Contract: Seat A (`openai`), Seat B (`anthropic`), Seat C (`deepseek`). At least one PASS vote must come from a family that authored zero commits on the branch.
- Escalation Seat: `reviewer-esc` runs on `xiaomi` (`mimo-v2.6-pro`), `minimax` (`minimax-m3`), and `zhipu` (`glm-5.3-flash`), maintaining strict family independence from all three council primary families.

## Test & Verification Plan

1. Verify `providers/quad.md` conforms to the table validation regexes in `test/install.sh`.
2. Run `./test/install.sh` to ensure all tests pass cleanly against the updated profile.
3. Test installation with `./install.sh --profile quad --target all` and `--verify --target all`.
