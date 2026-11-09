# Cybernetic SDLC Harness

Instructions for the `oneshot` cybernetic control system. Skills and ad-hoc dispatches never hardcode model IDs, providers, or effort values; the active provider profile (`PROVIDERS.md`) is the single source for which model runs each role, and this file is the single source for the routing rules, the dispatch adapter, and the contracts.

## Context Hygiene and Subagent Routing

- Any code search touching more than one file or 50+ lines goes to `scout` (read-only locator, compressed `path:line` tables) instead of inline search loops in the main session.
- The main session orchestrates and never writes implementation code inline; dispatch a fresh subagent per task (`implementer`, `implementer-b`, or `implementer-deep`) via `dispatch`.
- `patch` handles 1 to 2 file edits that need no test run (micro-loops, typo fixes, mechanical renames). Council and CI fixers that must run tests are implementation seats.

## Provider Profiles

This file is provider-neutral: it names roles, never concrete models. Which provider instance, model, and effort runs each role lives in the active provider profile.

- **Where it lives:** the active routing table is `PROVIDERS.md` next to `HARNESS.md` in the install directory; in this repo its source is `providers/<profile>.md`, bound to an install by `install.sh --profile <name>`. Skills say "the active provider profile (`PROVIDERS.md`)", never a provider name.
- **Role vocabulary:** seat roles (each has an agent contract file in `agents/`): `scout`, `implementer`, `implementer-b`, `implementer-deep`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`. Ad-hoc role (no agent file; the dispatch brief carries the contract): `task-reviewer`, the dispatch stage-1 spec and stage-2 quality reviewers. Design alternatives (`codebase-design`, design-it-twice) are not a profile role: each runs on a distinct-family rung borrowed from the implementation ladders with a read-only brief and delegate role `design` (see Dispatch Adapter, Design alternatives). Advisory roles (documented host setup; validated when present, never required, never rendered by the installer): `driver` (the main session running oneshot) and `compaction`. Every profile defines a `primary` rung for all ten dispatched roles (nine seats plus `task-reviewer`).
- **Columns:** the routing table has one row per role and rung with columns `role | rung | provider | model | effort | family | privacy`. `rung` is `primary`, `fallback`, or `last-resort` (ladder order is that order). `provider` is the provider instance serving the model (`opencode` is the only value an OpenCode host can dispatch natively). `model` is the id exactly as that provider's catalog names it (starts alphanumeric, only `[A-Za-z0-9._/-]`). `effort` is `<option-id>=<value>` in the provider's own vocabulary, or `-` for the provider default (`-` is allowed only in `effort` for dispatched roles; on advisory rows it is also allowed in `provider`, `model`, and `family`, never in `rung` or `privacy`). `family` is the model family used by the independence rules (the same family on two providers is the same family). `privacy` is `ok` or `trains` (trains on request data; the privacy gate skips it on confidential work). Quotas, privacy notes, and other provider facts are prose in the profile, not harness rules.
- **Validation (installer):** any non-fenced table row whose first cell is a role name must be a valid 7-cell routing row (exactly 7 non-empty cells, valid `rung` and `privacy`, no duplicate role+rung, charset checks on `model`, `effort`, `family`); rows inside fenced blocks are ignored. Each dispatched role needs a `primary` row. Advisory rows are validated when present, never required, never rendered. Diagnostics, both on stderr with exit 1 and nothing written: `install.sh: profile NAME incomplete: ROLE` (a dispatched role lacks its required primary) and `install.sh: profile NAME invalid row: ROLE RUNG: REASON` (malformed row). A previous install that predates profiles (a manifest with entries but no `# profile` line, or `HARNESS.md` with no manifest) keeps `opencode-go` and prints `profile: opencode-go (previous install predates profiles)`.

## Dispatch Adapter

How the controller turns a role into a running subagent. The controller walks each role's rungs strictly in ladder order (`primary`, then `fallback`, then `last-resort`). For the CURRENT rung, take the first path that applies:

1. **Native pin (OpenCode host).** The rung is the seat's native pin (the first `opencode` rung of the seat's ladder, rendered into the installed seat agent file at install, plus `#<value>` when its effort id is `variant`) and the host is OpenCode: dispatch the seat agent through the `subagent` tool (some builds register it as `task`; use whichever the session exposes) with the seat agent id and no model override. The brief still carries the `Rung:` line described under path 2.
2. **T3 Code orchestration tools are available.** Before the first dispatch in a session, call `orchestrator_capabilities` once. A provider, model, or option it does not list, a disabled provider, or a `delegate_task` rejection makes that rung unreachable (path 4, demote). Otherwise use `delegate_task` for the rung, whatever its provider (non-pinned `opencode` rungs included): `target.providerInstanceId` = `provider`, `target.model` = `model`, `isolation: shared`, and `mode: async` for parallel fan-out. Options: for effort `-` pass `target.options = {}` (this explicitly clears options inherited from the parent); otherwise pass the rung's option, `target.options = {<option-id>: <value>}`, and for a child on the same provider as the driver also pass that provider's default for every other option the driver session set (for example `serviceTier=default`), because given values only override inherited ones. Role mapping: `research` for `scout`, `implementation` for implementers and `patch`, `review` for reviewers and `task-reviewer`, `design` for design-it-twice alternatives (`codebase-design`). The `task` text for a seat starts with the role contract line `Role contract: read <harness-dir>/agents/<seat>.md; follow its body; its permissions block is your policy and you enforce it yourself. Rung: <provider>/<model> (<effort>), privacy: <ok|trains>.` followed by the normal brief; `<effort>` is the rung's effort cell (`-` for default), and `<harness-dir>` is the directory holding `HARNESS.md`. The `Rung:` part is how a seat learns its privacy class for its confidentiality guard (a brief without it means privacy unknown). Native briefs (paths 1 and 3) carry the same line. `task-reviewer` and `design` briefs carry no contract line (`task-reviewer` briefs come from `dispatch/*-reviewer-prompt.md`).
3. **OpenCode host, `opencode` rung, no T3 tools.** Dispatch natively with an explicit `model` override `<model>#<variant>` (the `#<variant>` part only when the effort id is `variant`) and announce it. If the build ignores model overrides, this path is best-effort.
4. **None applies.** The rung is unreachable on this host: skip it like an exhausted rung and announce `seat <seat>: <provider>/<model> unreachable on this host, demoted to <next>`.

`task-reviewer` has no agent file, so path 1 never applies to it. Its native path is path 3 with a general-purpose subagent (`type general`) and an explicit `model`; its delegate path is path 2 with role `review` and no contract line.

**Design alternatives** (`codebase-design`, design-it-twice) have no agent file either: the native path is path 3 with a general-purpose subagent and an explicit `model` (like `task-reviewer`), never the `implementer-deep` seat agent; the delegate path is path 2 with delegate role `design`. Candidates, in order: the `implementer-deep` rungs, then the `implementer` and `implementer-b` rungs; choose distinct families, the privacy gate applies. When fewer distinct reachable families exist than alternatives, run the available ones and announce `degraded design: N families` (design is advisory, not a gate).

Seats whose ladder has no `opencode` rung install with no `model:` line: never dispatch such a seat natively (it would inherit the driver's model); reach it only through `delegate_task`.

Off OpenCode, permissions are self-enforced by the child: T3 runtime modes pause for approval and are not read-only sandboxes. The "best-effort guardrails, not a sandbox" wording under Permission rules extends to this.

Never let a subagent inherit the driver's model by omission: every dispatch names a rung, and a seat without a native pin is never dispatched natively.

## Routing Rules

- **Ladder:** on a usage-limit, allowance, quota, or 429-style error, or when a rung is unreachable (Dispatch Adapter step 4), re-dispatch the same role on the next rung of its ladder in the active profile and announce the demotion.
- **Family independence (council):** a seat may demote within its own family; it never takes a rung whose family is active on another council seat anywhere in this PR. This holds across the whole PR, not just one round: when two seats demote in the same round, each skips any rung whose family is already active on another seat. Escalation (`reviewer-esc`) only runs on a family no council seat (`reviewer-a`, `reviewer-b`, `reviewer-c`) used this PR; "seat" here means council seats only, so implementation rungs never block it.
- **Author independence (task loop):** a `task-reviewer` rung whose family equals the implementing rung's family is skipped for that task.
- **Privacy gate:** any rung marked `privacy: trains` auto-skips when the task or diff carries a confidential flag; demote to the next privacy-safe rung and announce. Compaction and summary never route to a `trains` rung.
- **Council budget guard:** at most 14 reviewer dispatches per PR including escalation (9 seat, 3 seat demotion, 1 escalation, 1 escalation demotion); a seat that demoted once holds its new rung for the rest of the day. Rungs skipped as unreachable are not dispatches: they cost no council budget, and only real dispatches count toward the 14-dispatch guard.
- **Zero reachable rungs:** an implementation seat (`implementer`, `implementer-b`, `implementer-deep`) with no reachable rung hands the task to the next implementation seat and announces it: `implementer-deep` -> `implementer` -> `implementer-b`, and `implementer` <-> `implementer-b`. A handoff never revisits an exhausted seat; when all three are exhausted, stop and report, never run the work on the driver model. Reviewer seats follow the degraded-council rule below. `scout` and `patch` with none: the controller stops the dispatch and reports; it never runs the work on the driver model.
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

- Seats are named agents: `implementer` and `implementer-b` (default planned tasks), `implementer-deep` (complex tasks / difficult bugs), `scout`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, escalation `reviewer-esc`; the active provider profile names each seat's rungs and the install renders a native pin into each seat file that has an `opencode` rung, so a natively dispatched seat never inherits the main session model (a seat with no `opencode` rung has no pin and is dispatched only through `delegate_task`, see Dispatch Adapter).
- When a GLOSSARY.md exists, the task brief carries the terms the change must honor; spec review flags new undefined terms.
- Three reviewers, three independent model families, fresh subagent each.
- One line per finding: `path:line: emoji severity: problem. fix.`
- Severity only: red bug, yellow risk, blue nit (nits only on request).
- No praise, no scope creep, no "looks good".
- PASS requires: agreed verdict from at least 2 of 3 reviewers + zero unresolved confirmed red findings + green tests (or the no-tests rule under Review contracts).
- PASS additionally requires at least one PASS vote from a council seat whose family is not an author family. Author families are the families of the implementation and fixer rungs (`implementer*`, `patch`, CI and council fixers) that produced commits on the branch, recorded per commit in the state artifact from Phase 3 on. Driver commits of spec, plan, or docs-only state, and the driver's serial commits of child work in parallel mode, do not make the driver an author (the child's rung is). If every council seat's family is an author family, `reviewer-esc` supplies the non-author vote as one extra dispatch counted against the 14-dispatch guard, on its first rung whose family is neither used by a council seat nor an author family; if that is impossible, stop with `yellow: degraded council`. Without such a vote the round is not a PASS.
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

Every dispatch names a rung (the native pin rendered at install from the active profile, or an explicit target through the Dispatch Adapter), so a subagent session never silently runs the main session model; a seat with no `opencode` rung has no pin and is never dispatched natively. When a seat's rung returns a usage-limit, allowance, or 429-style provider error, or is unreachable: re-dispatch the SAME role on the next ladder rung in the active provider profile through the Dispatch Adapter. Announce the demotion. Skip any rung whose family is active on another council seat anywhere in this PR (Routing Rules, family independence). A seat with zero healthy ladder rungs is lost (implementation, scout, and patch seats follow Routing Rules, zero reachable rungs); the council stops at `yellow: degraded council` when fewer than 2 independent families remain healthy.
