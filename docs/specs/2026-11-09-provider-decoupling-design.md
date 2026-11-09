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
Design alternatives (`codebase-design`, design-it-twice) are not a profile role: each runs on a distinct-family rung borrowed from the implementation ladders (the `implementer-deep` rungs first, then the `implementer` and `implementer-b` rungs; privacy gate applies) with a read-only brief and delegate role `design`. Natively it is a general-purpose subagent with an explicit `model` (like `task-reviewer`), never the `implementer-deep` seat agent. With fewer distinct reachable families than alternatives, run what is available and announce `degraded design: N families` (design is advisory, not a gate).
Advisory roles (the installer validates them when present, never requires them, and never renders them; they document the recommended host setup): `driver` (the main session running oneshot), `compaction`.

Every profile MUST define a `primary` rung for all ten required roles (nine seats + `task-reviewer`).

## Profile format (provider layer)

`providers/<name>.md`, where `<name>` matches `[a-z0-9][a-z0-9-]*`. Free markdown prose (quotas, privacy notes, rationale) plus exactly one routing table. The installer parses table rows whose first cell is a known role name, so prose and other tables are free-form; any non-fenced table row whose first cell is a role name must be a valid 7-cell routing row.

```
| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| scout | primary | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
```

Columns:

- `role`: role name from the vocabulary above.
- `rung`: `primary`, `fallback`, or `last-resort` (ladder order is this order).
- `provider`: the provider instance that serves the model. Values are T3 Code provider instance ids (`antigravity`, `codex`, `opencode`, ...). `opencode` is the only value an OpenCode host can dispatch natively.
- `model`: the model id exactly as that provider's catalog names it (`opencode` models keep their `opencode-go/` prefix). It starts alphanumeric and uses only `[A-Za-z0-9._/-]`.
- `effort`: `<option-id>=<value>` in the provider's native option vocabulary (`thinking_level=high`, `reasoningEffort=medium`, `variant=max`), or `-` for the provider default. `-` is allowed only in `effort` for dispatched roles; on advisory rows it is also allowed in `provider`, `model`, and `family`, never in `rung` or `privacy`.
- `family`: model family for the independence rule (`google`, `anthropic`, `openai`, `deepseek`, `meta`, `zhipu`, `moonshot`, `xiaomi`, ...). Same family on two providers is the same family.
- `privacy`: `ok` or `trains` (trains on request data; the privacy gate skips it on confidential work).

## Native pin (install binding)

OpenCode agent files need a `model:` line so a natively dispatched seat never inherits the main session model. The pin is now derived, not authored:

- Source `agents/<seat>.md` carries no `model:` line.
- At install, the seat's native pin = the first rung (in ladder order) whose `provider` is `opencode`. The installer writes `model: <model>` plus `#<value>` when the effort id is `variant` (`model: opencode-go/deepseek-v4.1-flash#high`), inserted directly after the `mode: subagent` frontmatter line. That reproduces today's layout exactly, so `--profile opencode-go` installs the same `model:` line in the same place as the pre-change `agents/*.md`.
- A seat with no `opencode` rung is installed with no `model:` line, and the installer prints `note: <seat> has no opencode rung; dispatch it through delegate_task only`.

## Installer contract changes

- New flag `--profile <name>` (also `--profile=<name>`). Default profile: `tri` on a fresh install (see profile reuse below).
- Unknown profile (no `providers/<name>.md`, or name fails the pattern): exit 2, message `install.sh: unknown profile: <name> (available: <space-separated list>)` on stderr, nothing written.
- Incomplete profile (a required role lacks a `primary` row): exit 1, message `install.sh: profile <name> incomplete: <role>` on stderr, checked before any write. Malformed row (invalid `rung`, cell count, charset, duplicate, ...): exit 1, message `install.sh: profile <name> invalid row: <role> <rung>: <reason>` on stderr, also before any write.
- `<dest>/PROVIDERS.md` is a byte copy of the selected profile and is recorded in the manifest like any other installed file (collision, `--force`, `--prune` rules unchanged).
- The manifest keeps `# harness <sha>` as line 1 and adds `# profile <name>` as line 2. Prune skips every `#` line (already true).
- `providers/` itself is not installed; only the selected profile is, as `PROVIDERS.md`.
- Strict row validation: exactly 7 non-empty cells, `privacy` is `ok` or `trains`, no duplicate role+rung, charset checks on `model`, `effort`, `family`; rows inside fenced ``` blocks are ignored. Advisory rows (`driver`, `compaction`) are validated when present, never required, never rendered. Failure is one of the two diagnostics above.
- The pin is passed to the frontmatter rewrite safely (no escape interpretation) and inserted only in the first frontmatter block.
- Without `--profile`, the previous manifest's `# profile` is reused (else `tri`); an explicit change prints `profile changed: X -> Y`. A legacy install (a manifest with entries but no `# profile` line, or `HARNESS.md` present with no manifest) is treated as profile `opencode-go` (a pre-profiles install was the OpenCode Go harness) and prints `profile: opencode-go (previous install predates profiles)`.
- All existing destination, symlink, collision, and prune guards stay exactly as they are.
- Usage text documents `--profile` and lists available profiles.

## Dispatch adapter (harness layer, in AGENTS.md)

How the controller turns a role into a running subagent. It walks each role's rungs strictly in ladder order (`primary`, `fallback`, `last-resort`). For the CURRENT rung, the first path that applies:

1. Native pin (OpenCode host): the rung is the seat's native pin (the first `opencode` rung, rendered at install) and the host is OpenCode: dispatch the seat agent through the `subagent` tool (some builds name it `task`) with no model override; the brief still carries the `Rung:` line of path 2.
2. T3 Code orchestration tools are available: before the first dispatch in a session call `orchestrator_capabilities` once; a provider, model, or option it does not list, a disabled provider, or a `delegate_task` rejection makes the rung unreachable (path 4, demote). Otherwise `delegate_task` for any provider (non-pinned `opencode` rungs included) with `target.providerInstanceId = provider`, `target.model = model`, `isolation: shared`, `mode: async` for parallel fan-out. For effort `-` pass `target.options = {}` (explicitly clears inherited options); otherwise pass the rung's option `{<option-id>: <value>}`, and for a same-provider child also pass that provider's default for every other option the driver set (for example `serviceTier=default`), because given values only override inherited ones. `role` = `research` (scout), `implementation` (implementers, patch), `review` (reviewers, `task-reviewer`), `design` (design-it-twice alternatives). A seat's `task` text starts with the role contract line: `Role contract: read <harness-dir>/agents/<seat>.md; follow its body; its permissions block is your policy and you enforce it yourself. Rung: <provider>/<model> (<effort>), privacy: <ok|trains>.` followed by the normal brief; `<harness-dir>` is the directory holding `HARNESS.md`. Native briefs (paths 1 and 3) carry the same line; a seat reads its privacy class from it (no `Rung:` line = unknown, confidential work refused). `task-reviewer` and `design` briefs carry no contract line.
3. OpenCode host, `opencode` rung, no T3 tools: native dispatch with an explicit `model` override `<model>#<variant>`, announced. If the build ignores overrides this is best-effort.
4. None applies: the rung is unreachable on this host; skip it like an exhausted rung and announce `seat <seat>: <provider>/<model> unreachable on this host, demoted to <next>`.

`task-reviewer` has no agent file: its native path is path 3 with a general-purpose subagent (`type general`) and an explicit `model`; its delegate path is path 2 with role `review` and no contract line. `design` follows the same pattern (general-purpose subagent with explicit `model` natively, never the `implementer-deep` seat agent; delegate role `design`).

Seats whose ladder has no `opencode` rung install with no `model:` line and are never dispatched natively (they would inherit the driver's model); they are reached only through `delegate_task`.

Off OpenCode, permissions are self-enforced by the child (T3 runtime modes pause for approval; they are not read-only sandboxes). The existing "best-effort guardrails, not a sandbox" wording extends to this.

Never let a subagent inherit the driver's model by omission: every dispatch names a rung, and a seat without a native pin is never dispatched natively.

### Supported driver setups

The `driver` row stays advisory. (1) OpenCode host: native seats, plus `delegate_task` when running inside T3 Code. (2) Any T3 Code provider session (for example Antigravity `claude-opus-5-5`) told to load `<dest>/HARNESS.md`, `<dest>/PROVIDERS.md`, and skills from `<dest>/skills/`, dispatching only via `delegate_task` (permissions self-enforced).

## Routing rules (harness layer, unchanged in substance, reworded provider-neutral)

- Ladder: on a usage-limit, allowance, quota, or 429-style error, or an unreachable rung, re-dispatch the same role on the next rung and announce the demotion.
- Family independence (council): a seat may demote within its own family; it never takes a rung whose family is active on another council seat anywhere in this PR. Escalation (`reviewer-esc`) only runs on a family no council seat (`reviewer-a`, `reviewer-b`, `reviewer-c`) used this PR; "seat" here means council seats only.
- Author independence (task loop): a `task-reviewer` rung whose family equals the implementing rung's family is skipped for that task.
- Zero reachable rungs: an implementation seat with none hands the task to the next implementation seat and announces (`implementer-deep` -> `implementer` -> `implementer-b`, and `implementer` <-> `implementer-b`; a handoff never revisits an exhausted seat; all exhausted = stop and report, never the driver model); unreachable skips cost no council budget, only real dispatches count toward the 14-dispatch guard; reviewer seats follow the degraded-council rule; `scout` and `patch` with none: the controller stops the dispatch and reports, never running it on the driver model.
- Council PASS additionally requires at least one PASS vote from a council seat whose family is not an author family. Author families = families of the implementation and fixer rungs (`implementer*`, `patch`, CI and council fixers) that produced commits on the branch, recorded per commit in the state artifact from Phase 3 on; driver commits of spec, plan, docs-only state, or serial commits of child work (parallel mode) do not make the driver an author. If every council seat's family is an author family, `reviewer-esc` supplies the non-author vote as one extra dispatch counted against the 14-dispatch budget, on its first rung whose family is neither used by a council seat nor an author family; if that is impossible, stop with `yellow: degraded council`. This is a deliberate council-gate addition (see Non-goals).
- Degraded council, round caps, 14-dispatch budget guard, no-tests rule, privacy gate (skip `privacy: trains` rungs on confidential work), fixer seat routing: unchanged.
- The active routing table is `PROVIDERS.md` next to `HARNESS.md` (in this repo: `providers/<profile>.md`). Skills say "the active provider profile", never a provider name.

## Default profile `tri`

Three subscriptions: Antigravity (Google + Anthropic models), Codex (OpenAI models), OpenCode Go (open-weight long tail, cheap high-allowance quota). Distribution principle, token-output efficiency: spend frontier output tokens only where each token carries the most judgment, and push volume to the cheapest model that is still reliable for it.

- **Driver** emits little (briefs, verdicts, gate decisions) but its mistakes fan out to every child: frontier model, high effort.
- **Discovery** is read-heavy, write-light: a long-context flash model at low effort. Output is a compressed `path:line` table, so the expensive part is input, which flash models price lowest.
- **Implementation** produces the bulk of all output tokens: strong mid-tier coders at medium effort; frontier only for `implementer-deep`.
- **Per-task review** runs once per task, often: a flash model from a family that did not write the code.
- **Council** outputs are short and decide the merge: one frontier model per family (Google, Anthropic, OpenAI) at equal `high` effort so votes are comparable. Each council seat demotes inside its own family first, then out of family; every seat's last resort sits on a different provider than its primary, so one provider outage never empties a seat (the exception is `reviewer-esc`, whose whole ladder is OpenCode Go).
- **Escalation** is a fourth family none of the seats uses, so its verdict stays independent. "Seat" means council seats only (implementation rungs do not block it). It needs a family unused by council seats this PR: `reviewer-a`'s last resort (zhipu) can consume one escalation rung if reached, leaving moonshot and deepseek.

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

Model ids were checked against the T3 Code catalog on 2026-11-09; re-check with `orchestrator_capabilities` after catalog changes (`opencode-go/gpt-6-luna` is carried over from the legacy profile).

## Legacy profile `opencode-go`

`providers/opencode-go.md` carries today's Model Tank unchanged: same models, efforts, ladders, quotas, privacy footnotes, off-peak note, plus `task-reviewer` (today's "task-stage reviewers" row), `driver` (advisory: host default), and `compaction` (today's row). Installing with `--profile opencode-go` reproduces today's install except for the new `PROVIDERS.md` file and the `# profile` manifest line.

## Success criteria

1. Harness-layer grep above returns nothing; no skill names a provider.
2. `bash test/install.sh` green, including new cases: default profile is `tri`; `--profile opencode-go` installs agents whose `model:` lines and layout match `git show 578cc27:agents/<seat>.md` (bodies differ only where provider-specific wording was neutralized); `PROVIDERS.md` byte-identical to the profile and in the manifest; manifest line 2 is `# profile <name>`; unknown profile exits 2 and writes nothing; incomplete profile exits 1 and writes nothing; under `tri`, `implementer-deep` (no opencode rung) installs with no `model:` line and the install prints its `note:` line, while `implementer` installs with `model: opencode-go/deepseek-v4.1-flash#high`.
3. Skills reference roles and "the active provider profile"; council and dispatch describe the dispatch adapter by reference to AGENTS.md, not by restating it.
4. README documents layers, profiles, `--profile`, and the `tri` table with its rationale.

## Non-goals

- Host-runtime decoupling (OpenCode agent-file format, `OPENCODE_CONFIG` destination, OpenCode permission syntax). The adapter makes non-OpenCode providers reachable; moving the harness off OpenCode as a host is a separate change.
- Changing any loop, cap, or review contract, or any gate other than the one deliberate council-gate addition: the author-family PASS rule above (a non-author PASS vote, supplied by `reviewer-esc` when needed).
