# Cybernetic SDLC Harness

Instructions for the `oneshot` cybernetic control system. Skills and ad-hoc dispatches never hardcode model IDs, providers, or effort values; the active provider profile (`PROVIDERS.md`) is the single source for which model runs each role, and this file is the single source for the routing rules, the dispatch adapter, and the contracts.

## Context Hygiene and Subagent Routing

- Any code search touching more than one file or 50+ lines goes to `scout` (read-only locator, compressed `path:line` tables) instead of inline search loops in the main session.
- The main session orchestrates and never writes implementation code inline; dispatch a fresh subagent per task (`implementer`, `implementer-b`, or `implementer-deep`) via `dispatch`.
- `patch` handles 1 to 2 file edits that need no test run (micro-loops, typo fixes, mechanical renames). Council and CI fixers that must run tests are implementation seats.

## Provider Profiles

This file is provider-neutral: it names roles, never concrete models. Which provider instance, model, and effort runs each role lives in the active provider profile.

- **Where it lives:** the active routing table is `PROVIDERS.md` next to `HARNESS.md` in the install directory; in this repo its source is `providers/<profile>.md`, bound to an install by `install.sh --profile <name>`. Skills say "the active provider profile (`PROVIDERS.md`)", never a provider name.
- **Role vocabulary:** seat roles (each has an agent contract file in `agents/`): `scout`, `implementer`, `implementer-b`, `implementer-deep`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`. Ad-hoc role (no agent file; the dispatch brief carries the contract): `task-reviewer`, the dispatch stage-1 spec and stage-2 quality reviewers. Advisory roles (documented host setup only, never validated or rendered by the installer): `driver` (the main session running oneshot) and `compaction`. Every profile defines a `primary` rung for all ten dispatched roles (nine seats plus `task-reviewer`).
- **Columns:** the routing table has one row per role and rung with columns `role | rung | provider | model | effort | family | privacy`. `rung` is `primary`, `fallback`, or `last-resort` (ladder order is that order). `provider` is the provider instance serving the model (`opencode` is the only value an OpenCode host can dispatch natively). `model` is the id exactly as that provider's catalog names it. `effort` is `<option-id>=<value>` in the provider's own vocabulary, or `-` for the provider default. `family` is the model family used by the independence rules (the same family on two providers is the same family). `privacy` is `ok` or `trains` (trains on request data; the privacy gate skips it on confidential work). Quotas, privacy notes, and other provider facts are prose in the profile, not harness rules.

## Dispatch Adapter

How the controller turns a role into a running subagent. For each rung, in this order of preference:

1. **Host pins the rung natively.** On an OpenCode host, a rung with `provider: opencode` dispatches through the `subagent` tool (some builds register it as `task`; use whichever the session exposes) with the seat agent id. A native pin is rendered into the installed seat agent file at install time from the profile: the first `opencode` rung of the seat's ladder, plus `#<value>` when its effort id is `variant`. Non-pinned rungs pass an explicit `model` (`<model>#<variant>`).
2. **T3 Code orchestration tools are available.** Use `delegate_task` with `target.providerInstanceId` = `provider`, `target.model` = `model`, `target.options` = `{<option-id>: <value>}` (omit for `-`), `isolation: shared`, and `mode: async` for parallel fan-out. Pass `role` = `research` for `scout`, `implementation` for implementers and `patch`, `review` for reviewers. The `task` text starts with the role contract line `Role contract: read <harness-dir>/agents/<seat>.md; follow its body; its permissions block is your policy and you enforce it yourself.` followed by the normal brief; `<harness-dir>` is the directory holding `HARNESS.md`. `task-reviewer` briefs come from `dispatch/*-reviewer-prompt.md` and need no contract line.
3. **Neither works.** The rung is unreachable on this host: skip it like an exhausted rung and announce `seat <seat>: <provider>/<model> unreachable on this host, demoted to <next>`.

Off OpenCode, permissions are self-enforced by the child: T3 runtime modes pause for approval and are not read-only sandboxes. The "best-effort guardrails, not a sandbox" wording under Permission rules extends to this.

Never let a subagent inherit the driver's model by omission: every dispatch names a rung.

## Routing Rules

- **Ladder:** on a usage-limit, allowance, quota, or 429-style error, or when a rung is unreachable (Dispatch Adapter step 3), re-dispatch the same role on the next rung of its ladder in the active profile and announce the demotion.
- **Family independence (council):** a seat may demote within its own family; it never takes a rung whose family is active on another council seat anywhere in this PR. This holds across the whole PR, not just one round: when two seats demote in the same round, each skips any rung whose family is already active on another seat. Escalation (`reviewer-esc`) only runs on a family no seat used this PR.
- **Author independence (task loop):** a `task-reviewer` rung whose family equals the implementing rung's family is skipped for that task.
- **Privacy gate:** any rung marked `privacy: trains` auto-skips when the task or diff carries a confidential flag; demote to the next privacy-safe rung and announce. Compaction and summary never route to a `trains` rung.
- **Council budget guard:** at most 14 reviewer dispatches per PR including escalation (9 seat, 3 seat demotion, 1 escalation, 1 escalation demotion); a seat that demoted once holds its new rung for the rest of the day.
- **Degraded council:** never run the council with fewer than 2 independent reviewer families. If fewer than 2 independent reviewer families are healthy, stop with `yellow: degraded council`. Never continue on one reviewer. The canonical statement lives under Review contracts.
- **Rounds:** the council runs at most 3 rounds per PR.
- **Action-name aliases:** some OpenCode builds register permission actions as `bash`/`task`, some as `shell`/`subagent`; agent files carry both spellings so denies never go inert.

### Permission rules

- Agent `permissions:` lists are evaluated last-match-wins, so order is the policy.
- Read-only seats deny `bash`/`shell` broadly first, then allow only the narrow git commands each seat has: `scout` allows `git log` only; reviewers (`reviewer-a`, `reviewer-b`, `reviewer-c`) and escalation (`reviewer-esc`) allow `git diff`, `git log`, and `git show`.
- Implementation seats (`implementer`, `implementer-b`, `implementer-deep`) allow `bash`/`shell` broadly, then deny specific destructive patterns (`rm -r*`, `git clean`, `git push`, `pkill`, `killall`) and deny reader commands only in the `<cmd> *<secret>*` pattern form, so a bare `cat src/app.ts` is allowed but `cat *.env*` is denied (`cat`, `head`, `tail`, `less`, `strings`, `xxd`, `sed`, `awk`, `base64`, `od`, `paste`, `printenv`, `env`).
- `patch` denies `bash` and `shell` broadly and edits files only.
- In both allow/deny layouts the last matching rule is the policy.
- Every seat denies reads of `.env`, `.env.*`, `.zshrc`, `.zsh_history`, and `.ssh/*` in both bare and nested forms after its broad read allow.
- A seat may not commit or push on `main`/`master`: every implementer seat runs `git branch --show-current` as Step 0 and refuses on `main`/`master`, and council and CI fixer dispatches that run tests, commit, or push must use the implementer seats so the check always applies; `patch` remains valid for a 1-2 file edit with no test run. Shell pattern denies are best-effort guardrails, not a sandbox.
- Shell and git denies are an enumerated blocklist and best-effort guardrails, not a sandbox. Sibling names such as .envrc are not covered. Never treat a shell command as secret-safe.
- The canonical statements of the no-tests rule, the degraded-council rule, and fixer seat routing live in this file under Review contracts; skills reference them and do not restate them in different words.

### Review contracts

- A `no-tests` review pass is provisional and labelled `provisional: no-tests`, and it does not satisfy a gate that requires green tests except through the single exception below.
- A repo with no test suite may proceed only on a `provisional: no-tests` PASS plus build and lint green, with `no-tests decision: proceed` recorded in the state artifact. That is the only exception to the green-tests gate.
- A degraded council stops with `yellow: degraded council` and never reports a provisional PASS.
- A fixer that must run tests is an implementation seat, never `patch`.

## Council Contract

- Seats are named agents: `implementer` and `implementer-b` (default planned tasks), `implementer-deep` (complex tasks / difficult bugs), `scout`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, escalation `reviewer-esc`; the active provider profile names each seat's rung and the install renders a native pin into the seat file, so subagents never inherit the main session model.
- When a GLOSSARY.md exists, the task brief carries the terms the change must honor; spec review flags new undefined terms.
- Three reviewers, three independent model families, fresh subagent each.
- One line per finding: `path:line: emoji severity: problem. fix.`
- Severity only: red bug, yellow risk, blue nit (nits only on request).
- No praise, no scope creep, no "looks good".
- PASS requires: agreed verdict from at least 2 of 3 reviewers + zero unresolved confirmed red findings + green tests (or the no-tests rule under Review contracts).
- Reviewer never fixes, fixer never reviews.
- Receiving-side rigor: verify each finding against real code before acting; no performative agreement with hostile-but-wrong findings.

## Unit Naming Map

| Trigger | Unit |
| --- | --- |
| oneshot | full pipeline (controller) |
| shape, plan | spec and planning skills |
| domain-modeling | domain modeling discipline (glossary and ADRs) |
| codebase-design | deep module and seam vocabulary |
| dispatch | subagent-driven execution |
| tdd | red-green-refactor discipline skill |
| debug | root-cause investigation discipline skill |
| verify | evidence-before-assertions completion gate |
| council | consensus review (skill) |
| land | finish branch, PR options |
| make-ci-green | CI babysitting loop |
| implementer, implementer-b, implementer-deep, scout, patch | actuation / discovery agents (model and effort per the active provider profile) |
| reviewer-a, reviewer-b, reviewer-c, reviewer-esc | council seat agents (model and effort per the active provider profile) |

## Fallback Mechanics

Every dispatch names a rung (native pin rendered at install from the active profile, or an explicit target through the Dispatch Adapter), so a subagent session never silently runs the main session model. When a seat's rung returns a usage-limit, allowance, or 429-style provider error, or is unreachable: re-dispatch the SAME role on the next ladder rung in the active provider profile through the Dispatch Adapter. Announce the demotion. Skip any rung whose family is active on another council seat anywhere in this PR (Routing Rules, family independence). A seat with zero healthy ladder rungs is lost; the council stops at `yellow: degraded council` when fewer than 2 independent families remain healthy.
