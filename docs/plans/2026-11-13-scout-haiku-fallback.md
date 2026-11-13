# Scout Haiku Fallback Implementation Plan

Spec: `docs/specs/2026-11-13-scout-haiku-fallback-design.md`. Branch: `feat/scout-haiku-fallback` (stacked on `feat/gemini-hydrogen-and-readme-screenshot`).

## Task 1: Profile, generator, tests (tester first, then implementer)

Files: `test/install.sh`, `providers/quad.md`, `install.sh`.

1. `tester`: add assertions in `test/install.sh` that `providers/quad.md` has `| scout | fallback | claudeAgent | claude-haiku-5-5 | effort=low | anthropic | ok |` and `| scout | last-resort | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |`, and that the quad composition generator emits the same scout rows. Run, confirm red.
2. `implementer`: edit `providers/quad.md` scout fallback row and the two prose bullets; in `install.sh` scout candidate block (~line 1634) gate the `claude-haiku-5-5` `add_cand` line on OpenCode Go: `if (has_oc) add_cand(haiku)` before `gemini-3.8-flash`, and `if (!has_oc) add_cand(haiku)` at its original position after `gpt-6-luna`, so compositions without OpenCode Go keep their previous scout order. Run `./test/install.sh`, commit.

## Task 2: Docs

File: `README.md` (quad section, ~line 298): one bullet noting `scout` falls back to Claude Code `claude-haiku-5-5`, then Antigravity `gemini-3.8-flash`. Commit.

## Task 3: Verify

`./test/install.sh`; `./install.sh --force --target all && ./install.sh --verify --target all`; leak grep from the spec.
