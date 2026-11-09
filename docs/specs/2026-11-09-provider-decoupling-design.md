# Provider decoupling design

Date: 2026-11-09. Branch: `feat/provider-decoupling`.

## Problem

The oneshot harness hard-wires one provider (OpenCode Go) into every layer:

- `AGENTS.md` (installed as `HARNESS.md`) mixes provider-neutral control rules (loops, caps, council contract, permissions) with a provider-specific Model Tank (`opencode-go/*` IDs, req/5h quotas, per-model privacy) and the rule "Only `opencode-go/*` models are permitted".
- Each of the nine `agents/*.md` seat files pins `model: opencode-go/...#variant`, so a role contract cannot be reused on another provider without editing it.
- Skills and README speak of "Go families", OpenCode Go quotas, and route only through the OpenCode `subagent` tool, so models on other providers (Antigravity, Codex) cannot be reached at all.

Swapping or mixing providers therefore means editing the harness. The provider layer has to be a separate, swappable input.

## Layers

| Layer | Owns | Files |
| --- | --- | --- |
| Harness (provider-neutral) | pipeline, loops, caps, gates, council contract, permission policy, role contracts, the dispatch adapter, the routing *rules* (ladder walk, family independence, privacy gate, budget guard) | `skills/**`, `agents/*.md` (no `model:` line), `AGENTS.md` |
| Provider (swappable) | which provider instance, model, and effort runs each role; fallback ladders; model families; privacy class; quotas and provider notes | `providers/<profile>.md` |
| Install (binding) | binds one profile to one install: copies it as `<dest>/PROVIDERS.md`, renders each agent's native pin | `install.sh --profile <name>` |

Rule: no file in the harness layer names a concrete model ID, provider quota, or provider-specific effort value. `grep -rnE 'opencode-go/|req/5h|#(low|medium|high|xhigh|max)\b' AGENTS.md skills agents` returns nothing.

## Role vocabulary (harness layer)

Seat roles (each has an agent contract file): `scout`, `implementer`, `implementer-b`, `implementer-deep`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`.
Ad-hoc roles (no agent file, brief carries the contract): `task-reviewer` (dispatch stage-1 spec and stage-2 quality reviews).
Advisory roles (the installer never validates or renders them; they document the recommended host setup): `driver` (the main session running oneshot), `compaction`.

Every profile MUST define a `primary` rung for all ten required roles (nine seats + `task-reviewer`).

## Profile format (provider layer)

`providers/<name>.md`, where `<name>` matches `[a-z0-9][a-z0-9-]*`. Free markdown prose (quotas, privacy notes, rationale) plus exactly one routing table. The installer parses only table rows whose first cell is a known role name, so prose and other tables are free-form.

```
| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| scout | primary | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
```

Columns:

- `role`: role name from the vocabulary above.
- `rung`: `primary`, `fallback`, or `last-resort` (ladder order is this order).
- `provider`: the provider instance that serves the model. Values are T3 Code provider instance ids (`antigravity`, `codex`, `opencode`, ...). `opencode` is the only value an OpenCode host can dispatch natively.
- `model`: the model id exactly as that provider's catalog names it (`opencode` models keep their `opencode-go/` prefix).
- `effort`: `<option-id>=<value>` in the provider's native option vocabulary (`thinking_level=high`, `reasoningEffort=medium`, `variant=max`), or `-` for the provider default.
- `family`: model family for the independence rule (`google`, `anthropic`, `openai`, `deepseek`, `meta`, `zhipu`, `moonshot`, `xiaomi`, ...). Same family on two providers is the same family.
- `privacy`: `ok` or `trains` (trains on request data; the privacy gate skips it on confidential work).

## Native pin (install binding)

OpenCode agent files need a `model:` line so a natively dispatched seat never inherits the main session model. The pin is now derived, not authored:

- Source `agents/<seat>.md` carries no `model:` line.
- At install, the seat's native pin = the first rung (in ladder order) whose `provider` is `opencode`. The installer writes `model: <model>` plus `#<value>` when the effort id is `variant` (`model: opencode-go/deepseek-v4.1-flash#high`), inserted directly after the `mode: subagent` frontmatter line. That reproduces today's layout exactly, so `--profile opencode-go` installs the same `model:` line in the same place as the pre-change `agents/*.md`.
- A seat with no `opencode` rung is installed with no `model:` line, and the installer prints `note: <seat> has no opencode rung; dispatch it through delegate_task only`.

## Installer contract changes

- New flag `--profile <name>` (also `--profile=<name>`). Default profile: `tri`.
- Unknown profile (no `providers/<name>.md`, or name fails the pattern): exit 2, message `install.sh: unknown profile: <name> (available: <space-separated list>)` on stderr, nothing written.
- Incomplete profile (a required role lacks a `primary` row, or a row has an invalid `rung`): exit 1, message `install.sh: profile <name> incomplete: <role>` on stderr, checked before any write.
- `<dest>/PROVIDERS.md` is a byte copy of the selected profile and is recorded in the manifest like any other installed file (collision, `--force`, `--prune` rules unchanged).
- The manifest keeps `# harness <sha>` as line 1 and adds `# profile <name>` as line 2. Prune skips every `#` line (already true).
- `providers/` itself is not installed; only the selected profile is, as `PROVIDERS.md`.
- All existing destination, symlink, collision, and prune guards stay exactly as they are.
- Usage text documents `--profile` and lists available profiles.

## Dispatch adapter (harness layer, in AGENTS.md)

How the controller turns a role into a running subagent, in this order of preference for each rung:

1. Host can pin this rung natively: on an OpenCode host, a rung with `provider: opencode` dispatches through the `subagent` tool (some builds name it `task`) with the seat agent id; non-pinned rungs pass an explicit `model` (`<model>#<variant>`).
2. T3 Code orchestration tools are available: `delegate_task` with `target.providerInstanceId = provider`, `target.model = model`, `target.options = {<option-id>: <value>}` (omit for `-`), `isolation: shared`, `mode: async` for parallel fan-out, `role` = `research` (scout), `implementation` (implementers, patch), `review` (reviewers). The `task` text starts with the role contract line: `Role contract: read <harness-dir>/agents/<seat>.md; follow its body; its permissions block is your policy and you enforce it yourself.` followed by the normal brief. `<harness-dir>` is the directory holding `HARNESS.md`. `task-reviewer` briefs come from `dispatch/*-reviewer-prompt.md` and need no contract line.
3. Neither works: the rung is unreachable on this host; skip it like an exhausted rung and announce `seat <seat>: <provider>/<model> unreachable on this host, demoted to <next>`.

Off OpenCode, permissions are self-enforced by the child (T3 runtime modes pause for approval; they are not read-only sandboxes). The existing "best-effort guardrails, not a sandbox" wording extends to this.

Never let a subagent inherit the driver's model by omission: every dispatch names a rung.

## Routing rules (harness layer, unchanged in substance, reworded provider-neutral)

- Ladder: on a usage-limit, allowance, quota, or 429-style error, or an unreachable rung, re-dispatch the same role on the next rung and announce the demotion.
- Family independence (council): a seat may demote within its own family; it never takes a rung whose family is active on another council seat anywhere in this PR. Escalation (`reviewer-esc`) only runs on a family no seat used this PR.
- Author independence (task loop): a `task-reviewer` rung whose family equals the implementing rung's family is skipped for that task.
- Degraded council, round caps, 14-dispatch budget guard, no-tests rule, privacy gate (skip `privacy: trains` rungs on confidential work), fixer seat routing: unchanged.
- The active routing table is `PROVIDERS.md` next to `HARNESS.md` (in this repo: `providers/<profile>.md`). Skills say "the active provider profile", never a provider name.

## Default profile `tri`

Three subscriptions: Antigravity (Google + Anthropic models), Codex (OpenAI models), OpenCode Go (open-weight long tail, cheap high-allowance quota). Distribution principle, token-output efficiency: spend frontier output tokens only where each token carries the most judgment, and push volume to the cheapest model that is still reliable for it.

- **Driver** emits little (briefs, verdicts, gate decisions) but its mistakes fan out to every child: frontier model, high effort.
- **Discovery** is read-heavy, write-light: a long-context flash model at low effort. Output is a compressed `path:line` table, so the expensive part is input, which flash models price lowest.
- **Implementation** produces the bulk of all output tokens: strong mid-tier coders at medium effort; frontier only for `implementer-deep`.
- **Per-task review** runs once per task, often: a flash model from a family that did not write the code.
- **Council** outputs are short and decide the merge: one frontier model per family (Google, Anthropic, OpenAI) at equal `high` effort so votes are comparable. Each seat demotes inside its own family first (across providers where possible), then out of family.
- **Escalation** is a fourth family none of the seats uses, so its verdict stays independent.

| role | primary | fallback | last-resort |
| --- | --- | --- | --- |
| driver (advisory) | antigravity `claude-opus-5-5` high | codex `gpt-6.1-sol` high | - |
| scout | antigravity `gemini-3.8-flash` low | opencode `mimo-v2.6-flash` | codex `gpt-6-luna` low |
| implementer | codex `gpt-6.1-terra` medium | antigravity `claude-sonnet-5-5` medium | opencode `deepseek-v4.1-flash` high |
| implementer-b | antigravity `claude-sonnet-5-5` medium | codex `gpt-6.1-terra` medium | opencode `glm-5.3` high |
| implementer-deep | codex `gpt-6.1-sol` high | antigravity `gemini-4-argon` high | antigravity `claude-opus-5-5` high |
| patch | codex `gpt-6-luna` medium | opencode `deepseek-v4.1-flash` high | antigravity `gemini-3.8-flash` medium |
| task-reviewer | antigravity `gemini-3.8-flash` high | opencode `glm-5.3-flash` high | codex `gpt-6-luna` high |
| reviewer-a (Google) | antigravity `gemini-4-argon` high | antigravity `gemini-3.8-flash` high | opencode `glm-5.3` high |
| reviewer-b (Anthropic) | antigravity `claude-opus-5-5` high | antigravity `claude-sonnet-5-5` high | opencode `claude-haiku-5-5` high |
| reviewer-c (OpenAI) | codex `gpt-6.1-sol` high | codex `gpt-6-sol` high | opencode `gpt-6-luna` high |
| reviewer-esc | opencode `kimi-k3.1-pro` high | opencode `deepseek-v4.1-flash` max | opencode `glm-5.3` high |
| compaction (advisory) | antigravity `gemini-3.8-flash` low | opencode `claude-haiku-5-5` low | - |

`muse-spark-*` (trains on request data) is dropped from `tri`; it stays in the legacy profile.

## Legacy profile `opencode-go`

`providers/opencode-go.md` carries today's Model Tank unchanged: same models, efforts, ladders, quotas, privacy footnotes, off-peak note, plus `task-reviewer` (today's "task-stage reviewers" row), `driver` (advisory: host default), and `compaction` (today's row). Installing with `--profile opencode-go` reproduces today's install except for the new `PROVIDERS.md` file and the `# profile` manifest line.

## Success criteria

1. Harness-layer grep above returns nothing; no skill names a provider.
2. `bash test/install.sh` green, including new cases: default profile is `tri`; `--profile opencode-go` installs agents whose `model:` lines and layout match `git show 578cc27:agents/<seat>.md` (bodies differ only where provider-specific wording was neutralized); `PROVIDERS.md` byte-identical to the profile and in the manifest; manifest line 2 is `# profile <name>`; unknown profile exits 2 and writes nothing; incomplete profile exits 1 and writes nothing; under `tri`, `implementer-deep` (no opencode rung) installs with no `model:` line and the install prints its `note:` line, while `implementer` installs with `model: opencode-go/deepseek-v4.1-flash#high`.
3. Skills reference roles and "the active provider profile"; council and dispatch describe the dispatch adapter by reference to AGENTS.md, not by restating it.
4. README documents layers, profiles, `--profile`, and the `tri` table with its rationale.

## Non-goals

- Host-runtime decoupling (OpenCode agent-file format, `OPENCODE_CONFIG` destination, OpenCode permission syntax). The adapter makes non-OpenCode providers reachable; moving the harness off OpenCode as a host is a separate change.
- Changing any loop, cap, gate, or review contract.
