# Scout Fallbacks: Claude Haiku 5.5 and Gemini 3.8 Flash - Design

Status: pending approval (2026-11-13).
Goal: Give `scout` a Claude Code `claude-haiku-5-5` fallback and keep Antigravity `gemini-3.8-flash` as its last-resort rung wherever those providers are present.

## 1. Problem

`scout` (read-only locator) runs on OpenCode Go flash models. When OpenCode Go is exhausted (it hits its cap first in practice), the next rung in `quad` is `deepseek-v4.1-flash` on the same exhausted pool, then Antigravity. Anthropic's cheapest model, `claude-haiku-5-5`, is a fast, cheap fit for locating code and sits on the otherwise idle Claude Code pool.

## 2. Design

- `providers/quad.md`: `scout` ladder becomes primary `opencode-go/mimo-v2.6-flash`, fallback `claudeAgent` `claude-haiku-5-5` (`effort=low`, `anthropic`), last-resort `antigravity` `gemini-3.8-flash` (`thinking_level=low`, unchanged). `deepseek-v4.1-flash` stays reachable via `## Backup ladder` rows 2/7. Update the `Discovery` bullet and the Claude Code load-split bullet.
- `install.sh` `--providers` generator: in the `scout` candidate list, move `claudeAgent` `claude-haiku-5-5` ahead of `antigravity` `gemini-3.8-flash`, so compositions containing Claude Code get `mimo -> haiku -> gemini-3.8-flash`; compositions without Claude Code are unchanged.
- `tri`, `opencode-go`, `codex`, `claude`, `antigravity` profiles are unchanged: none can serve Haiku next to Gemini Flash on a scout ladder (`claude` already has Haiku as primary; `antigravity` has no Claude Code).
- `README.md`: mention the scout ladder in the `quad` section. `docs/assets/architecture.svg` is not touched.
- `test/install.sh`: assert the new `quad.md` scout rows and the generated quad composition parity.
- Anthropic effort cap holds (`low`).

## 3. Out of scope

Other roles (`tester`, `patch`) already carry Haiku/Gemini Flash in the generator and stay as is. No change to quota pools.

## 4. Success criteria

- `./test/install.sh` all green; generated quad scout rows equal `providers/quad.md`.
- `./install.sh --force --target all && ./install.sh --verify --target all` exit 0.
- No hardcoded model IDs leak into `AGENTS.md`, `skills`, `agents`.
