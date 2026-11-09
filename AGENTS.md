# Cybernetic SDLC Harness

Instructions for the `oneshot` cybernetic control system. Skills and ad-hoc dispatches never hardcode model IDs, providers, or effort values; the active provider profile (`PROVIDERS.md`) is the single source for which model runs each role, and this file is the single source for the routing rules, the dispatch adapter, and the contracts.

## Context Hygiene and Subagent Routing

- Any code search touching more than one file or 50+ lines goes to `scout` (read-only locator, compressed `path:line` tables) instead of inline search loops in the main session.
- Failing-test authoring (TDD red step) and verification/CI script runs go to `tester` (writes failing tests without production code or commits; runs suites/scripts/CI logs and returns compressed pass/fail excerpts instead of raw logs in the main session).
- The main session orchestrates and never writes implementation code inline; dispatch a fresh subagent per task (`tester` for red tests when the task has behaviour to test, then `implementer` or `implementer-deep`) via `dispatch`.
- `patch` handles 1 to 2 file edits that need no test run (micro-loops, typo fixes, mechanical renames). Council and CI fixers that must run tests are implementation seats (`implementer`, or `implementer-deep` for hard clusters).

## Provider Profiles

This file is provider-neutral: it names roles, never concrete models. Which provider instance, model, and effort runs each role lives in the active provider profile.

- **Where it lives:** the active routing table is `PROVIDERS.md` next to `HARNESS.md` in the install directory; in this repo its source is `providers/<profile>.md` (or an external file via `--profile-file <path>`), bound by `install.sh --profile <name>` or `install.sh --profile-file <path>`. Skills say "the active provider profile (`PROVIDERS.md`)", never a provider name.
- **Role vocabulary:** seat roles (each has an agent file in `agents/`): `scout`, `tester`, `implementer`, `implementer-deep`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`. Ad-hoc role (no agent file; brief carries the contract): `task-reviewer` (dispatch stage-1 spec and stage-2 quality reviewers). Design alternatives (`codebase-design`, design-it-twice) are not a profile role: each runs on a distinct-family rung borrowed from the implementation ladders with a read-only brief and delegate role `design` (see Dispatch Adapter). Advisory roles (validated when present, never required or rendered): `driver` (main session) and `compaction`. Every profile defines a `primary` rung for all ten dispatched roles (nine seats plus `task-reviewer`).
- **Columns:** one row per role and rung: `role | rung | provider | model | effort | family | privacy`. `rung` is `primary`, `fallback`, or `last-resort` (ladder order). `provider` is the T3 Code provider instance id (`^[A-Za-z0-9][A-Za-z0-9-]*$`, camelCase such as `claudeAgent` allowed; `opencode` is the only value an OpenCode host dispatches natively). `model` is the catalog id (`^[A-Za-z0-9][A-Za-z0-9._/-]*$`). `effort` is `<option-id>=<value>` in the provider's vocabulary, or `-` for default (`-` is allowed only in `effort` for dispatched roles; on advisory rows also in `provider`, `model`, `family`, never in `rung` or `privacy`). `family` is the lowercase model family (`^[a-z0-9][a-z0-9-]*$`) for independence rules (same family across providers is the same family). `privacy` is `ok` or `trains` (skipped by the privacy gate on confidential work).
- **Optional additive sections (`## Quota pools` and `## Backup ladder`):** a profile without them remains valid (each rung is its own `<provider>/<model>` pool, nothing is reserved, and there is no backup ladder):
  - `## Quota pools` has columns `pool | provider | models | window | soft-cap | reserve`. `pool` (`^[a-z0-9][a-z0-9-]*$`, unique) names the shared bucket. `models` (`^[A-Za-z0-9*][A-Za-z0-9._/*-]*$`) is a glob matched against `model` for that `provider` (first matching row wins; unmatched rungs default to `<provider>/<model>`). `window` (`^[1-9][0-9]*(h|d|w|mo)$`, e.g. `5h`, `1d`) is the cooldown when an error lacks a reset timestamp. `soft-cap` (`-` or positive integer) is the max dispatches per run before the pool is reserved for roles in `reserve` (`-` or comma-separated known roles).
  - `## Backup ladder` has columns `order | roles | provider | model | effort | family | privacy`. `order` is a unique positive integer (`1`, `2`, ...). `roles` is `*` or comma-separated dispatched roles; remaining columns match dispatched routing rows.
- **Validation (installer):** outside fenced ` ``` ` blocks, `## Quota pools` and `## Backup ladder` switch the parser into pool-table and backup-table mode (`## <anything else>` returns to role-table mode). In role-table mode, any non-fenced table row whose first cell is a known role must be a valid 7-cell row; diagnostics exit 1 on stderr with nothing written: `install.sh: profile NAME incomplete: ROLE` (missing required primary) and `install.sh: profile NAME invalid row: ROLE RUNG: REASON`. In `## Quota pools`, non-header rows must be valid 6-cell rows (`install.sh: profile NAME invalid pool row: POOL: REASON`, exit 1). In `## Backup ladder`, non-header rows must be valid 7-cell rows (`install.sh: profile NAME invalid backup row: ORDER: REASON`, exit 1). `install.sh` also creates `<dest>/state/` without listing `state` in `.harness-manifest`, so `--prune` never touches `<dest>/state/quota-ledger.tsv`. `--profile` and `--profile-file` are mutually exclusive (exit 2). On refresh without flags, recorded `# profile` or `# profile-file <abs path>` is reused (exiting 2 with `install.sh: profile file not found: <path>` if missing). A legacy install (manifest without `# profile*` or `HARNESS.md` without manifest) keeps `opencode-go` and prints `profile: opencode-go (previous install predates profiles)`.

## Dispatch Adapter

The controller walks each role's rungs in ladder order (`primary -> fallback -> last-resort`, then sibling hand-off and `## Backup ladder` per Routing Rules). For the CURRENT rung, take the first path that applies:

1. **Native pin (OpenCode host).** The rung is the seat's native pin (first `opencode` ladder rung, rendered into the installed seat file at install, plus `#<value>` when effort id is `variant`) and the host is OpenCode: dispatch the seat agent through `subagent` (or `task`) with no model override. The brief still carries the `Rung:` line from path 2.
2. **T3 Code orchestration tools are available.** Call `orchestrator_capabilities` once before the first dispatch in a session. An unlisted provider/model/option, disabled provider, or `delegate_task` rejection makes the rung unreachable (path 4). Otherwise call `delegate_task` for any provider (including non-pinned `opencode` rungs): `target.providerInstanceId` = `provider`, `target.model` = `model`, `isolation: shared`, `mode: async` for parallel fan-out. For effort `-` pass `target.options = {}` (clears inherited options); else pass `target.options = {<option-id>: <value>}`, plus same-provider defaults for any other option set on the driver (e.g. `serviceTier=default`). Role mapping: `research` (`scout`), `test` (`tester`), `implementation` (`implementer`, `implementer-deep`, `patch`), `review` (`reviewer-*`, `task-reviewer`), `design` (`codebase-design` alternatives). A seat's `task` starts with `Role contract: read <harness-dir>/agents/<seat>.md; follow its body; its permissions block is your policy and you enforce it yourself. Rung: <provider>/<model> (<effort>), privacy: <ok|trains>.` followed by the brief (`<harness-dir>` holds `HARNESS.md`). Native briefs (paths 1 and 3) carry the same `Rung:` line so seats learn their privacy class (missing `Rung:` = unknown). `task-reviewer` and `design` briefs carry no contract line.
3. **OpenCode host, `opencode` rung, no T3 tools.** Dispatch natively with explicit `model` override `<model>#<variant>` (`#<variant>` only when effort id is `variant`) and announce it.
4. **None applies.** Rung is unreachable: skip it and announce `seat <seat>: <provider>/<model> unreachable on this host, demoted to <next>`.

`task-reviewer` and **design alternatives** (`codebase-design`, design-it-twice) have no agent file: natively they use path 3 with a general-purpose subagent (`type general`) and an explicit `model` (never `implementer-deep`); via T3 they use path 2 (`review` or `design`). Design candidates walk `implementer-deep` rungs then `implementer` rungs across distinct families (privacy gate applies; if fewer families are reachable than alternatives, run available ones and announce `degraded design: N families`).

Seats with no `opencode` rung on their 3-rung ladder install with no `model:` line and never use path 1: reach their non-`opencode` rungs via path 2 (`delegate_task`), and reach any `opencode` backup rung via path 2 or path 3 (explicit `model` override, never omitting `model`), else path 4. Off OpenCode, permissions are self-enforced by the child. Never let a subagent inherit the driver's model by omission.

## Routing Rules

- **Ladder:** before dispatching a role, resolve each candidate rung's quota pool from `## Quota pools` in `PROVIDERS.md` (first matching `provider` + `models` glob wins; default `<provider>/<model>`) and check `<dest>/state/quota-ledger.tsv` plus per-run `soft_cap_counts`. Skip any rung whose pool is exhausted (`now < retry_after`) or soft-capped and reserved for other roles. On `exhausted`, `unreachable`, or a failed `transient` retry, move to the next eligible rung (`primary -> fallback -> last-resort`), announce the demotion, and continue.
- **Quota pools & ledger (`<dest>/state/quota-ledger.tsv`):** machine-local TSV next to `HARNESS.md`, shared across repos/runs and never committed. Columns: `pool  provider  exhausted_at  retry_after  source_role  note`. Read before every ladder walk; expired rows (`retry_after <= now`) are pruned. On an `exhausted` error, write/update the rung's `pool` row with `retry_after` from the error (`Retry-After`, "resets at ...") or `exhausted_at + window` (default `5h`). A successful dispatch on a pool clears its row immediately and increments its per-run counter in `oneshot-state.md`. All ledger updates acquire an exclusive lock directory (`mkdir <dest>/state/quota-ledger.lock`, breaking stale locks > 60s, removed on exit) around read-merge-write-to-`<dest>/state/.quota-ledger.$$.tmp`-and-`mv -f` (keeping the later `retry_after` on concurrent merges).
- **Failure classes:**
  - `exhausted` (HTTP 429, "usage limit", "quota", "rate limit reached", plan-limit messages): record the rung's **pool** in `quota-ledger.tsv` with `retry_after`, announce demotion, and try the next rung (all models in that pool skip immediately until `retry_after`).
  - `unreachable` (unlisted in `orchestrator_capabilities`, disabled provider, `delegate_task` rejection, no adapter path): skip for the session and announce; no ledger row.
  - `transient` (HTTP 5xx, timeout, stream cut): retry the same rung once; if the retry fails, skip that rung for this dispatch only (no ledger row).
  - `task failure` (bad output, failing tests): not a budget event; handle via fix/debug caps.
  - Budget skips (`exhausted`, `unreachable`, `transient`, soft-cap skips) never consume council rounds, the 14-dispatch council budget guard, or per-task fix attempts.
- **Soft cap & reserve:** when a pool's dispatch count in `oneshot-state.md` (`soft_cap_counts`) reaches its numerical `soft-cap`, only roles in its `reserve` column may use it for the rest of the run; other roles skip it without writing a ledger row.
- **Family independence (council):** a seat may demote within its own family; it never takes a rung whose family is active on another council seat anywhere in this PR. Escalation (`reviewer-esc`) only runs on a family no council seat (`reviewer-a`, `reviewer-b`, `reviewer-c`) used this PR ("seat" means council seats only).
- **Author independence (task loop):** `task-reviewer` skips any rung whose family equals the implementing rung's family (or `tester`'s family when `tester` wrote tests for that task).
- **Privacy gate:** any `privacy: trains` rung auto-skips when the task or diff is confidential; compaction and summary never route to `trains`.
- **Council budget guard:** at most 14 real reviewer dispatches per PR including escalation (9 seat, 3 seat demotion, 1 escalation, 1 escalation demotion); a demoted seat holds its new rung for the rest of the day. Unreachable, ledger-exhausted, or soft-cap skips cost no budget.
- **Backup ladder walk & zero reachable rungs:** when a role's 3 rungs are all exhausted, unreachable, or reserved:
  - Implementation seats first try sibling hand-off (`implementer-deep <-> implementer`, never revisiting an exhausted seat).
  - Next, walk `## Backup ladder` in ascending `order` for rows matching `*` or the role (or either implementation seat after hand-off), enforcing pool/ledger, soft-cap/reserve, family independence (including not active on another council seat or `reviewer-esc`, and for `reviewer-esc` not used by any council seat or author family when supplying the non-author PASS vote), author-family, privacy gate, and never-on-driver rules. Announce `backup: <role> -> <provider>/<model>`.
  - Reviewer seats with no eligible rung left follow the degraded-council rule; `implementer`, `implementer-deep`, `scout`, `tester`, `patch`, and `task-reviewer` stop via **Budget stop & resume** below, never running on the driver model.
- **Budget stop & resume:** when no eligible rung remains for a required role (or < 2 independent council families remain healthy due to quota exhaustion), stop and report:
  ```text
  budget stop: <role>
    exhausted: <pool> (until <HH:MM or ISO timestamp>), ...
    earliest resume: <timestamp>  -> rerun `oneshot` to resume from state
  ```
  Record `earliest_resume` and `soft_cap_counts` in `oneshot-state.md`. On resume, re-read `quota-ledger.tsv` and continue without reopening closed rounds. Include a **Budget** summary block in the PR body and final report.
- **Degraded council:** never run the council with fewer than 2 independent reviewer families; stop with `yellow: degraded council`.
- **Rounds:** the council runs at most 3 rounds per PR.
- **Action-name aliases:** agent files carry both `bash`/`task` and `shell`/`subagent` spellings so denies never go inert.

### Permission rules

- Agent `permissions:` lists are evaluated last-match-wins, so order is the policy.
- Read-only seats deny `bash`/`shell` broadly first, then allow only narrow git commands: `scout` allows `git log` only; reviewers (`reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`) allow `git diff`, `git log`, and `git show`.
- Implementation seats (`implementer`, `implementer-deep`) and `tester` allow `bash`/`shell` broadly, then deny destructive patterns (`rm -r*`, `git clean`, `git push`, `pkill`, `killall`) and secret-reader patterns (`<cmd> *<secret>*` for `cat`, `head`, `tail`, `less`, `strings`, `xxd`, `sed`, `awk`, `base64`, `od`, `paste`, `printenv`, `env`).
- `patch` denies `bash` and `shell` broadly and edits files only.
- Every seat denies reads of `.env`, `.env.*`, `.zshrc`, `.zsh_history`, and `.ssh/*` in bare and nested forms after its broad read allow.
- A seat may not commit or push on `main`/`master`: every implementer seat and `tester` runs `git branch --show-current` as Step 0 and refuses on `main`/`master` (`tester` never commits), and council/CI fixers that run tests, commit, or push must use implementation seats (`implementer`, or `implementer-deep` for hard clusters); `patch` is only for 1-2 file edits with no test run.
- Shell and git denies are an enumerated blocklist and best-effort guardrails, not a sandbox; sibling names like `.envrc` are not covered.
- Canonical statements of the no-tests rule, degraded-council rule, and fixer seat routing live under Review contracts below.

### Review contracts

- A `no-tests` review pass is provisional and labelled `provisional: no-tests`, and it does not satisfy a gate that requires green tests except through the single exception below.
- A repo with no test suite may proceed only on a `provisional: no-tests` PASS plus build and lint green, with `no-tests decision: proceed` recorded in the state artifact. That is the only exception to the green-tests gate.
- A degraded council stops with `yellow: degraded council` and never reports a provisional PASS.
- A fixer that must run tests is an implementation seat (`implementer`, or `implementer-deep` for hard clusters), never `patch`.

## Council Contract

- Seats are named agents: `implementer`, `implementer-deep`, `tester`, `scout`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, escalation `reviewer-esc`; the active provider profile names each seat's rungs and install renders a native pin into each seat file with an `opencode` rung so natively dispatched seats never inherit the main session model (seats without an `opencode` ladder rung have no native pin and never use path 1).
- When a GLOSSARY.md exists, the task brief carries the terms the change must honor; spec review flags new undefined terms.
- Three reviewers, three independent model families, fresh subagent each.
- One line per finding: `path:line: emoji severity: problem. fix.`
- Severity only: red bug, yellow risk, blue nit (nits only on request).
- No praise, no scope creep, no "looks good".
- PASS requires: agreed verdict from at least 2 of 3 reviewers + zero unresolved confirmed red findings + green tests (or the no-tests rule under Review contracts).
- PASS additionally requires at least one PASS vote from a council seat whose family is not an author family. Author families are the families of the implementation, `tester` (when its tests are committed), and fixer rungs (`implementer*`, `tester`, `patch`, CI and council fixers) that produced commits on the branch, recorded per commit in the state artifact from Phase 3 on. Driver commits of spec, plan, or docs-only state, and serial commits of child work in parallel mode, do not make the driver an author. If every council seat's family is an author family, `reviewer-esc` supplies the non-author vote as one extra dispatch counted against the 14-dispatch guard, on its first rung whose family is neither used by a council seat nor an author family; if impossible, stop with `yellow: degraded council`.
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
| implementer, implementer-deep, tester, scout, patch | actuation / testing / discovery agents (model and effort per the active provider profile) |
| reviewer-a, reviewer-b, reviewer-c, reviewer-esc | council seat agents (model and effort per the active provider profile) |

## Fallback Mechanics

Every dispatch names a rung (native pin or explicit Dispatch Adapter target), so a subagent never silently runs the main session model; a seat with no `opencode` ladder rung has no native pin and never uses path 1. Before walking a ladder, the controller checks `<dest>/state/quota-ledger.tsv` and per-run soft-cap counters. When a rung hits an `exhausted` error (written to the quota ledger), is `unreachable`, or fails a `transient` retry: re-dispatch the SAME role on the next eligible ladder rung in `PROVIDERS.md` (followed by sibling implementation hand-off and `## Backup ladder`) through the Dispatch Adapter, announcing the demotion (or `backup: <role> -> <provider>/<model>`). Skip any rung whose family is active on another council seat anywhere in this PR. When no eligible rung remains after the backup ladder, stop and report via Routing Rules, budget stop & resume (or `yellow: degraded council` when fewer than 2 independent council families remain healthy).
