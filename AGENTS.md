# Cybernetic SDLC Harness

Instructions for the `oneshot` cybernetic control system. Skills and ad-hoc dispatches never hardcode model IDs, providers, or effort values; the active provider profile (`PROVIDERS.md`) owns which model runs each role, and this file owns the routing rules, dispatch adapter, and contracts.

## Context Hygiene and Subagent Routing

- Code searches touching >1 file or 50+ lines go to `scout` (read-only locator returning compressed `path:line` tables), never inline main-session search loops.
- Failing-test authoring (TDD red step) and verification/CI script runs go to `tester` (writes uncommitted failing tests without production code; runs suites/scripts/CI logs and returns compressed pass/fail excerpts).
- The main session orchestrates and never writes implementation code inline; dispatch a fresh subagent per task (`tester` first when testable behaviour changes, then `implementer` or `implementer-deep`) via `dispatch`.
- `patch` handles 1-2 file edits needing no test run (micro-loops, typos, mechanical renames). Council/CI fixers that run tests use implementation seats (`implementer`, or `implementer-deep` for hard clusters).

## Provider Profiles

This file is provider-neutral: it names roles, never concrete models. The active provider profile maps roles to provider instances, models, and effort.

- **Where it lives:** `PROVIDERS.md` next to `HARNESS.md` in `<dest>`; repo source `providers/<profile>.md` (or external `--profile-file <path>`), bound by `install.sh --profile <name>` or `--profile-file <path>`. Skills say "the active provider profile (`PROVIDERS.md`)", never a provider name.
- **Role vocabulary:** seat roles (`agents/*.md`): `scout`, `tester`, `implementer`, `implementer-deep`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`. Ad-hoc role (no agent file; brief carries contract): `task-reviewer` (stage-1 spec, stage-2 quality). Design alternatives (`codebase-design`, design-it-twice) borrow distinct-family implementation rungs with a read-only brief and delegate role `design`. Advisory roles (validated when present, never required or rendered): `driver` (main session) and `compaction`. Every profile defines a `primary` rung for all ten dispatched roles (nine seats + `task-reviewer`).
- **Columns:** `role | rung | provider | model | effort | family | privacy`. `rung`: `primary`, `fallback`, `last-resort` (ladder order). `provider`: T3 Code provider instance id (`^[A-Za-z0-9][A-Za-z0-9-]*$`, camelCase like `claudeAgent` allowed; standalone hosts dispatch only their matching provider). `model`: catalog id (`^[A-Za-z0-9][A-Za-z0-9._/-]*$`). `effort`: `<option-id>=<value>` in the provider's vocabulary, or `-` for default (`-` allowed only in `effort` on dispatched rows; on advisory rows also in `provider`, `model`, `family`, never in `rung` or `privacy`). `family`: lowercase model family (`^[a-z0-9][a-z0-9-]*$`) for independence (same family across providers is one family). `privacy`: `ok` or `trains` (skipped by the privacy gate on confidential work).
- **Optional additive sections (`## Quota pools` and `## Backup ladder`):** valid when omitted (each rung defaults to pool `<provider>/<model>`, nothing reserved, no backup ladder):
  - `## Quota pools`: `pool | provider | models | window | soft-cap | reserve`. `pool` (`^[a-z0-9][a-z0-9-]*$`, unique) names the bucket; `models` (`^[A-Za-z0-9*][A-Za-z0-9._/*-]*$`) globs `model` for `provider` (first match wins; else `<provider>/<model>`); `window` (`^[1-9][0-9]*(h|d|w|mo)$`, e.g. `5h`, `1d`) is the fallback cooldown; `soft-cap` (`-` or positive integer) caps run dispatches before reserving the pool for `reserve` (`-` or comma-separated known roles).
  - `## Backup ladder`: `order | roles | provider | model | effort | family | privacy`. `order` is a unique positive integer (`1`, `2`, ...); `roles` is `*` or comma-separated dispatched roles; remaining columns match dispatched rows.
- **Validation (installer):** outside fenced `` ``` `` blocks, `## Quota pools` and `## Backup ladder` enter pool/backup table modes (`## <anything else>` returns to role mode). Non-fenced known-role rows in role mode must be valid 7-cell rows; defects exit 1 on stderr before any write: `install.sh: profile NAME incomplete: ROLE` (missing required primary) and `install.sh: profile NAME invalid row: ROLE RUNG: REASON`. Non-header pool rows must be valid 6-cell rows (`install.sh: profile NAME invalid pool row: POOL: REASON`, exit 1); non-header backup rows must be valid 7-cell rows (`install.sh: profile NAME invalid backup row: ORDER: REASON`, exit 1). `install.sh` creates `<dest>/state/` unmanaged by `.harness-manifest` so `--prune` preserves `<dest>/state/quota-ledger.tsv`. `--profile` and `--profile-file` conflict (exit 2). Refreshes without flags reuse recorded `# profile` or `# profile-file <abs path>` (`install.sh: profile file not found: <path>`, exit 2 if missing); pre-profile installs (manifest without `# profile*` or `HARNESS.md` without manifest) keep `opencode-go` and print `profile: opencode-go (previous install predates profiles)`.

## Dispatch Adapter

Walk each role's rungs in ladder order (`primary -> fallback -> last-resort`, then sibling hand-off and `## Backup ladder` per Routing Rules). Define `<contract-path>` for seat dispatches across paths 2 and 3: when `provider` is `antigravity`, pass `<contract-path>` literally as `` `<skills-dir>/_harness/agents/<seat>.md` (`<skills-dir>` = grandparent of `oneshot/SKILL.md`, i.e. parent of `oneshot/`, in your `<skills>` list; never substituting the driver's path) `` so the child resolves `<skills-dir>` to `.../skills` from its own `<skills>` list; for all other providers, the driver substitutes `<harness-dir>/agents/<seat>.md` (`<harness-dir>` holds `HARNESS.md`). On hosts not auto-loading seat files (paths 2 and 3), seat briefs start with `Role contract: read <contract-path>; follow its body; its permissions block is your policy and you enforce it yourself. Rung: <provider>/<model> (<effort>), privacy: <ok|trains>.` (`task-reviewer` and `design` carry `Rung:` only; missing `Rung:` = unknown privacy). For the CURRENT rung, take the first matching path:

1. **Native pin (OpenCode host).** First `opencode` ladder rung (rendered into the installed seat file, plus `#<value>` when effort id is `variant`) on OpenCode: dispatch the seat via `subagent`/`task` with no model override, keeping `Rung:`. Seats with no `opencode` ladder rung install unpinned on OpenCode and never use path 1.
2. **T3 Code orchestration tools available.** Call `orchestrator_capabilities` once before first dispatch; unlisted provider/model/option, disabled provider, or `delegate_task` rejection hits path 4. Else `delegate_task` for any provider (including non-pinned `opencode` rungs): `target.providerInstanceId` = `provider`, `target.model` = `model`, `isolation: shared`, `mode: async` for parallel fan-out; effort `-` sets `target.options = {}`, else `{<option-id>: <value>}` plus same-provider driver defaults (e.g. `serviceTier=default`). Role mapping: `research` (`scout`), `test` (`tester`), `implementation` (`implementer`, `implementer-deep`, `patch`), `review` (`reviewer-*`, `task-reviewer`), `design` (`codebase-design` alternatives).
3. **Standalone same-provider native dispatch (no T3 tools, `provider` matches active host).** Announce the standalone native rung with `Rung:` (and `Role contract:` where seat files are not auto-loaded): `opencode`: `subagent`/`task` with explicit `model` `<model>` (plus `#<value>` for `variant`; `type general` for `task-reviewer`/`design`); `codex`: `spawn_agent` + `wait` with explicit `model` `<model>` and `reasoning_effort` (from `reasoningEffort=<value>`); `claudeAgent`: `Agent` (`run_in_background: false`, seat subagent or general-purpose for `task-reviewer`/`design`) with explicit `model` `<model>`; `antigravity`: `invoke_subagent` `self` for all seats (`scout`, `tester`, `implementer*`, `patch`, `reviewer-*`) and `task-reviewer` with self-enforced `<contract-path>`/read-only policy (`research` has no shell for `git diff`/`log`/`show` and may be used only for shell-free `design`), passing `Model: inherit` only when `<model>` equals the active session model, or `Model: flash` only for a flash-tier `google` rung on a `google` session (all other rungs, including cross-family rungs, hit path 4 `unreachable` so `Rung:`, family independence, and quota-pool accounting stay exact).
4. **None applies.** Rung is `unreachable`: skip it and announce `seat <seat>: <provider>/<model> unreachable on this host, demoted to <next>`.

`task-reviewer` and **design alternatives** (`codebase-design`, design-it-twice) have no agent file: use path 2 (`review`/`design`) in T3 Code, or path 3 natively (general-purpose subagent, or `antigravity` `self` for `task-reviewer` and `research`/`self` for shell-free `design`; never `implementer-deep`). Design candidates walk `implementer-deep` then `implementer` rungs across distinct families (privacy gate applies; fewer reachable families -> run available ones and announce `degraded design: N families`). Off OpenCode, children self-enforce permissions. Never let a subagent inherit the driver's model by omission.

## Routing Rules

- **Ladder:** resolve each candidate rung's quota pool from `## Quota pools` in `PROVIDERS.md` (first matching `provider` + `models` glob wins; default `<provider>/<model>`) and check `<dest>/state/quota-ledger.tsv` plus `soft_cap_counts`. Skip rungs whose pool is exhausted (`now < retry_after`) or soft-capped for other roles. On `exhausted`, `unreachable`, or failed `transient` retry, advance (`primary -> fallback -> last-resort`), announce demotion, and continue.
- **Quota pools & ledger (`<dest>/state/quota-ledger.tsv`):** machine-local TSV next to `HARNESS.md`, shared across repos/runs and never committed (`pool  provider  exhausted_at  retry_after  source_role  note`). Read before every ladder walk, pruning expired rows (`retry_after <= now`). On `exhausted`, write/update the rung's `pool` row with `retry_after` from the error (`Retry-After`, "resets at ...") or `exhausted_at + window` (default `5h`). A successful dispatch clears its pool row immediately and increments its per-run counter in `oneshot-state.md`. Lock all ledger updates via `mkdir <dest>/state/quota-ledger.lock` (break stale locks > 60s, remove on exit) around read-merge-write to `<dest>/state/.quota-ledger.$$.tmp` and `mv -f` (retaining the later `retry_after` on concurrent merges).
- **Failure classes:**
  - `exhausted` (HTTP 429, "usage limit", "quota", "rate limit reached", plan-limit messages): record the rung's **pool** in `quota-ledger.tsv` with `retry_after`, announce demotion, and try the next rung (all models in that pool skip until `retry_after`).
  - `unreachable` (unlisted in `orchestrator_capabilities`, disabled provider, `delegate_task` rejection, no adapter path): skip for the session and announce; no ledger row.
  - `transient` (HTTP 5xx, timeout, stream cut): retry the same rung once; on repeat failure, skip that rung for this dispatch only (no ledger row).
  - `task failure` (bad output, failing tests): not a budget event; handle via fix/debug caps.
  - Budget skips (`exhausted`, `unreachable`, `transient`, soft-cap) never consume council rounds, the 14-dispatch council guard, or per-task fix attempts.
- **Soft cap & reserve:** once a pool's `soft_cap_counts` in `oneshot-state.md` reaches its `soft-cap`, only roles in `reserve` may use it for the rest of the run; others skip it with no ledger row.
- **Family independence (council):** a seat may demote within its family; it never takes a family active on another council seat anywhere in this PR. `reviewer-esc` runs only on a family no council seat (`reviewer-a`, `reviewer-b`, `reviewer-c`) used this PR ("seat" = council seats only).
- **Author independence (task loop):** `task-reviewer` skips any rung whose family equals the implementing rung's family (or `tester`'s family when `tester` wrote tests for that task). If skipping the author/`tester` family leaves zero reachable `task-reviewer` rungs **solely** because all non-author families are `unreachable` on a standalone single-family host (never for `exhausted` quota or soft-cap), fall back to the first reachable same-family `task-reviewer` rung and announce `degraded task-review: single-family host (<family>)`.
- **Privacy gate:** `privacy: trains` rungs auto-skip on confidential tasks or diffs; compaction and summary never route to `trains`.
- **Council budget guard:** max 14 real reviewer dispatches per PR including escalation (9 seat, 3 seat demotion, 1 escalation, 1 escalation demotion); a demoted seat keeps its new rung for the day. Budget skips cost 0.
- **Backup ladder walk & zero reachable rungs:** when a role's 3 rungs are all exhausted, unreachable, or reserved: (a) implementation seats first try sibling hand-off (`implementer-deep <-> implementer`, never revisiting an exhausted seat); (b) walk `## Backup ladder` in ascending `order` for rows matching `*` or the role (or either implementation seat after hand-off), enforcing pool/ledger, soft-cap/reserve, family independence (not active on another council seat or `reviewer-esc`, and for `reviewer-esc` not used by any council seat or author family when supplying the non-author PASS vote), author-family, privacy gate, and never-on-driver rules, announcing `backup: <role> -> <provider>/<model>`; (c) reviewer seats with none left follow the degraded-council rule; `implementer`, `implementer-deep`, `scout`, `tester`, `patch`, and `task-reviewer` stop via **Budget stop & resume** below, never running on the driver model.
- **Budget stop & resume:** when no eligible rung remains for a required role (or < 2 independent council families remain healthy due to quota exhaustion), stop and report:
  ```text
  budget stop: <role>
    exhausted: <pool> (until <HH:MM or ISO timestamp>), ...
    earliest resume: <timestamp>  -> rerun `oneshot` to resume from state
  ```
  Record `earliest_resume` and `soft_cap_counts` in `oneshot-state.md`. On resume, re-read `quota-ledger.tsv` without reopening closed rounds. Include a **Budget** summary block in the PR body and final report.
- **Degraded council:** never run the council with < 2 independent reviewer families; stop with `yellow: degraded council`.
- **Rounds:** max 3 council rounds per PR.
- **Action-name aliases:** agent files carry both `bash`/`task` and `shell`/`subagent` spellings so denies never go inert.

### Permission rules

- Agent `permissions:` lists evaluate last-match-wins (order is policy).
- Read-only seats deny `bash`/`shell` broadly first, then allow narrow git only: `scout` allows `git log`; `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc` allow `git diff`, `git log`, `git show`.
- `implementer`, `implementer-deep`, and `tester` allow `bash`/`shell` broadly, then deny destructive patterns (`rm -r*`, `git clean`, `git push`, `pkill`, `killall`) and secret readers (`<cmd> *<secret>*` for `cat`, `head`, `tail`, `less`, `strings`, `xxd`, `sed`, `awk`, `base64`, `od`, `paste`, `printenv`, `env`).
- `patch` denies `bash` and `shell` broadly and edits files only.
- Every seat denies reads of `.env`, `.env.*`, `.zshrc`, `.zsh_history`, and `.ssh/*` (bare and nested) after its broad read allow.
- No seat may commit or push on `main`/`master`: `implementer*` and `tester` run `git branch --show-current` as Step 0 and refuse on `main`/`master` (`tester` never commits); fixers that run tests, commit, or push use `implementer*` (`patch` is 1-2 file no-test only).
- Shell/git denies are an enumerated blocklist (best-effort guardrails, not a sandbox; sibling names like `.envrc` are uncovered).

### Review contracts

- A `no-tests` review pass is labelled `provisional: no-tests` and satisfies no green-tests gate except via the single exception below.
- A repo with no test suite may proceed only on a `provisional: no-tests` PASS with build and lint green and `no-tests decision: proceed` recorded in state.
- A degraded council stops with `yellow: degraded council` and never reports a provisional PASS.
- Any fixer that must run tests uses `implementer` (or `implementer-deep` for hard clusters), never `patch`.

## Council Contract

- Seats are named agents: `implementer`, `implementer-deep`, `tester`, `scout`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, escalation `reviewer-esc` (rungs in `PROVIDERS.md`; OpenCode seats with an `opencode` rung render a native pin).
- When `GLOSSARY.md` exists, task briefs carry the required terms; spec review flags new undefined terms.
- Three reviewers, three independent model families, fresh subagent each.
- One line per finding: `path:line: emoji severity: problem. fix.`
- Severity only: red bug, yellow risk, blue nit (nits only on request).
- No praise, no scope creep, no "looks good".
- PASS requires: agreed verdict from >= 2 of 3 reviewers + zero unresolved confirmed red findings + green tests (or the no-tests exception under Review contracts).
- PASS also requires >= 1 PASS vote from a council seat whose family is not an author family. Author families are those of implementation, `tester` (when its tests are committed), and fixer rungs (`implementer*`, `tester`, `patch`, CI/council fixers) that produced branch commits, recorded per commit in state from Phase 3 on (driver spec/plan/docs commits and serial commits of parallel child work do not make the driver an author). If every council seat's family is an author family, `reviewer-esc` supplies the non-author vote as one extra dispatch within the 14-dispatch guard on its first rung whose family is neither used by a council seat nor an author family; else stop with `yellow: degraded council`.
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
| implementer, implementer-deep, tester, scout, patch | actuation / testing / discovery agents (per `PROVIDERS.md`) |
| reviewer-a, reviewer-b, reviewer-c, reviewer-esc | council seat agents (per `PROVIDERS.md`) |

## Fallback Mechanics

Every dispatch names an explicit rung (OpenCode pin or Dispatch Adapter target), never silently inheriting the driver model. After checking `<dest>/state/quota-ledger.tsv` and `soft_cap_counts`, any `exhausted`, `unreachable`, or failed `transient` rung re-dispatches the SAME role on the next eligible rung in `PROVIDERS.md` (then sibling implementation hand-off and `## Backup ladder`, skipping active council-seat families), announcing the demotion or `backup: <role> -> <provider>/<model>`, and stopping via Budget stop & resume (or `yellow: degraded council`) when none remain.
