# Cybernetic SDLC Harness

Instructions for `oneshot`. Skills and ad-hoc dispatches never hardcode model IDs, providers, or effort values; `PROVIDERS.md` owns which model runs each role, and this file owns routing rules, dispatch adapter, and contracts.

## Context Hygiene and Subagent Routing

- Searches touching >1 file or 50+ lines go to `scout` (read-only locator returning compressed `path:line` tables), never inline search loops.
- Failing-test authoring (TDD red step) and CI runs go to `tester` (writes uncommitted failing tests without production code; runs suites/scripts/CI logs and returns compressed excerpts).
- Main session orchestrates and never writes implementation code inline; dispatch a fresh subagent per task (`tester` first when tests change, then `implementer` or `implementer-deep`) via `dispatch`.
- `patch` handles 1-2 file edits needing no test run. Council/CI fixers running tests use implementation seats (`implementer`, or `implementer-deep`).

## Provider Profiles

Provider-neutral: names roles, never concrete models. The active provider profile maps roles to providers, models, and effort.

- **Where it lives:** `PROVIDERS.md` next to `HARNESS.md` in `<dest>`; repo source `providers/<profile>.md` (or `--profile-file <path>` / `--providers <list>`), bound by `install.sh --profile <name>`, `--profile-file <path>`, or `--providers <list>`. Skills say "the active provider profile (`PROVIDERS.md`)", never a provider name.
- **Role vocabulary:** seat roles (`agents/*.md`): `scout`, `tester`, `implementer`, `implementer-deep`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`. Ad-hoc role (no agent file; brief carries contract): `task-reviewer` (stage-1 spec, stage-2 quality). Design alternatives (`codebase-design`, design-it-twice) borrow distinct-family implementation rungs with a read-only brief and delegate role `design`. Advisory roles (validated when present, never required or rendered): `driver` (main session) and `compaction`. Every profile defines a `primary` rung for all ten dispatched roles (nine seats + `task-reviewer`; `reviewer-c` is optional in profiles with fewer than 3 model families).
- **Columns:** `role | rung | provider | model | effort | family | privacy`. `rung`: `primary`, `fallback`, `last-resort` (ladder order). `provider`: T3 Code provider instance id (`^[A-Za-z0-9][A-Za-z0-9-]*$`, camelCase like `claudeAgent` allowed; standalone hosts dispatch only their matching provider). `model`: catalog id (`^[A-Za-z0-9][A-Za-z0-9._/-]*$`). `effort`: `<option-id>=<value>` in the provider's vocabulary, or `-` for default (`-` allowed only in `effort` on dispatched rows; on advisory rows also in `provider`, `model`, `family`, never in `rung` or `privacy`). `family`: lowercase model family (`^[a-z0-9][a-z0-9-]*$`) for independence (same family across providers is one family). `privacy`: `ok` or `trains` (skipped by the privacy gate on confidential work).
- **Optional additive sections (`## Quota pools` and `## Backup ladder`):** valid when omitted (each rung defaults to pool `<provider>/<model>`, nothing reserved, no backup ladder):
  - `## Quota pools`: `pool | provider | models | window | soft-cap | reserve`. `pool` (`^[a-z0-9][a-z0-9-]*$`, unique) names the bucket; `models` (`^[A-Za-z0-9*][A-Za-z0-9._/*-]*$`) globs `model` for `provider` (first match wins; else `<provider>/<model>`); `window` (`^[1-9][0-9]*(h|d|w|mo)$`, e.g. `5h`, `1d`) is the fallback cooldown; `soft-cap` (`-` or positive integer) caps run dispatches before reserving the pool for `reserve` (`-` or comma-separated known roles).
  - `## Backup ladder`: `order | roles | provider | model | effort | family | privacy`. `order` is a unique positive integer (`1`, `2`, ...); `roles` is `*` or comma-separated dispatched roles; remaining columns match dispatched rows.
- **Validation (installer):** outside fenced `` ``` `` blocks, `## Quota pools` and `## Backup ladder` enter pool/backup table modes (`## <anything else>` returns to role mode). Non-fenced known-role rows in role mode must be valid 7-cell rows; defects exit 1 on stderr before any write: `install.sh: profile NAME incomplete: ROLE` (missing primary; `reviewer-c` only with >= 3 families), `install.sh: profile NAME invariant violated: SEAT1 and SEAT2 share primary family FAMILY` (pairwise-distinct council primary families), and `install.sh: profile NAME invalid row: ROLE RUNG: REASON`. Pool/backup rows must be valid 6/7-cell rows (`install.sh: profile NAME invalid pool row: POOL: REASON` / `... invalid backup row: ORDER: REASON`, exit 1). `install.sh` creates `<dest>/state/` unmanaged by `.harness-manifest` so `--prune` preserves `<dest>/state/quota-ledger.tsv`. `--profile`, `--profile-file`, and `--providers` conflict (exit 2). Refreshes without flags reuse recorded `# profile`, `# profile-file <abs path>` (`install.sh: profile file not found: <path>`, exit 2 if missing), or `# providers <list>`; pre-profile installs (manifest without `# profile*` or `# providers`, or `HARNESS.md` without manifest) keep `opencode-go` and print `profile: opencode-go (previous install predates profiles)`.

## Dispatch Adapter

Walk each role's rungs in ladder order (`primary -> fallback -> last-resort`, then sibling hand-off and `## Backup ladder` per Routing Rules). For seat dispatches on paths 1 and 3, `<contract-path>` is: when `provider` is `antigravity`, literally `` `<skills-dir>/_harness/agents/<seat>.md` (`<skills-dir>` = grandparent of `oneshot/SKILL.md`, i.e. parent of `oneshot/`, in your `<skills>` list; never substituting the driver's path) `` (resolved by the child from its `<skills>` list); for other providers, driver-substituted `<harness-dir>/agents/<seat>.md` (`<harness-dir>` holds `HARNESS.md`). On paths 1 and 3 (seats not auto-loaded), seat briefs start with `Role contract: read <contract-path>; follow its body; its permissions block is your policy and you enforce it yourself. Rung: <provider>/<model> (<effort>), privacy: <ok|trains>.` (`task-reviewer` and `design` carry `Rung:` only; missing `Rung:` = unknown privacy). For the CURRENT rung, take the first matching path:

1. **T3 Code orchestration tools available.** Check eager, deferred/tool-search, ACP, and `<mcp_servers>` tools (for lazy `t3-code` schemas such as `<appDataDir>/brain/<conversation-id>/mcp/t3-code/{orchestrator_capabilities,delegate_task}.json`, read once and invoke via `call_mcp_tool`). While `t3-code` (`delegate_task`) is present, NEVER use Path 2/3 native tools (`invoke_subagent`, `spawn_agent`, `Agent`, `subagent`/`task`). Call `orchestrator_capabilities` once before first dispatch: missing/disabled `provider` (`canRunChildTask: false`) or an option invalid on a listed model hits Path 4; models omitted from preview (`omittedModels`/catalog IDs) are still tried via `delegate_task` (Path 4 only if rejected). Dispatch all providers (including `opencode`) via `delegate_task`: `target.providerInstanceId` = `provider`, `target.model` = `model`, `isolation: shared`, `mode: async` (fan-out) or `wait`; effort `-` -> `target.options = {}`, else `{<option-id>: <value>}` (plus same-provider defaults like `serviceTier=default` only when matching driver). Roles: `research` (`scout`), `test` (`tester`), `implementation` (`implementer`, `implementer-deep`, `patch`), `review` (`reviewer-*`, `task-reviewer`), `design` (`codebase-design` alternatives).
2. **Standalone OpenCode native pin (no T3 tools).** Without `t3-code` on OpenCode, when the rung matches the seat's rendered first `opencode` pin (`agents/<seat>.md`, plus `#<value>` for `variant`): dispatch via `subagent`/`task` with no model override, keeping `Rung:`. Unpinned seats (no `opencode` ladder rung) never use Path 2.
3. **Standalone same-provider native dispatch (no T3 tools, `provider` matches active host).** Only when `t3-code` is absent; announce with `Rung:` (and `Role contract:` when not auto-loaded): `opencode`: `subagent`/`task` with explicit `model` `<model>` (plus `#<value>` for `variant`; `type general` for `task-reviewer`/`design`); `codex`: `spawn_agent` + `wait` with explicit `model` `<model>` and `reasoning_effort` (from `reasoningEffort=<value>`); `claudeAgent`: `Agent` (`run_in_background: false`, seat subagent or general-purpose for `task-reviewer`/`design`) with explicit `model` `<model>`; `antigravity`: `invoke_subagent` `self` for all seats (`scout`, `tester`, `implementer*`, `patch`, `reviewer-*`) and `task-reviewer` with self-enforced `<contract-path>`/read-only policy (`research` has no shell for `git diff`/`log`/`show` and fits only shell-free `design`), passing `Model: inherit` only when `<model>` equals the session model, or `Model: flash` only for a flash-tier `google` rung on a `google` session (all other/cross-family rungs hit Path 4 `unreachable` so `Rung:`, family independence, and quota pools stay exact).
4. **None applies.** Rung is `unreachable`: skip it and announce `seat <seat>: <provider>/<model> unreachable on this host, demoted to <next>`.

`task-reviewer` and **design alternatives** (`codebase-design`, design-it-twice; walk `implementer-deep` then `implementer` rungs across distinct families, privacy gate applies, fewer reachable -> `degraded design: N families`) have no agent file (never dispatch via `implementer-deep` seat). Off Path 2, children self-enforce permissions; never inherit the driver's model by omission.

## Routing Rules

- **Ladder:** resolve each rung's quota pool from `## Quota pools` in `PROVIDERS.md` (first matching `provider` + `models` glob wins; default `<provider>/<model>`) and check `<dest>/state/quota-ledger.tsv` plus `soft_cap_counts`. Skip rungs whose pool is exhausted (`now < retry_after`) or soft-capped for other roles; `reviewer-*` seats also skip any rung whose `model` matches a recorded author model (`author_models` in `oneshot-state.md`), demoting along ladder/backup ladder and announcing `demote: <seat> -> <provider>/<model> (author model conflict)`. On `exhausted`, `unreachable`, or failed `transient` retry, advance (`primary -> fallback -> last-resort`), announce demotion, and continue.
- **Quota pools & ledger (`<dest>/state/quota-ledger.tsv`):** machine-local TSV next to `HARNESS.md`, shared across repos/runs and never committed (`pool  provider  exhausted_at  retry_after  source_role  note`). Read before every ladder walk, pruning expired rows (`retry_after <= now`). On `exhausted`, write/update the rung's `pool` row with `retry_after` from the error (`Retry-After`, "resets at ...") or `exhausted_at + window` (default `5h`). A successful dispatch clears its pool row and increments its counter in `oneshot-state.md`. Lock all ledger updates via `mkdir <dest>/state/quota-ledger.lock` (break stale locks > 60s, remove on exit) around read-merge-write to `<dest>/state/.quota-ledger.$$.tmp` and `mv -f` (keeping later `retry_after` on merge).
- **Failure classes:**
  - `exhausted` (HTTP 429, "weekly usage limit", "usage limit reached", "plan limit", "quota", "rate limit reached"): record the rung's **pool** (on provider-wide plan/weekly limits, write one row per configured pool of that provider with the same `retry_after`) in `quota-ledger.tsv` with `retry_after`, announce demotion, and try next rung (all models in that pool skip until `retry_after`).
  - `unreachable` (unlisted in `orchestrator_capabilities`, disabled provider, `delegate_task` rejection, no adapter path): skip for the session and announce; no ledger row.
  - `transient` (HTTP 5xx, timeout, stream cut): retry the same rung once; on repeat failure, skip that rung for this dispatch only (no ledger row).
  - `task failure` (bad output, failing tests): not a budget event; handle via fix/debug caps.
  - Budget/eligibility skips (`exhausted`, `unreachable`, `transient`, soft-cap, privacy, author-model) never consume council rounds, the 14-dispatch council guard, or per-task fix attempts.
- **Soft cap & reserve:** once a pool's `soft_cap_counts` in `oneshot-state.md` reaches its `soft-cap`, only `reserve` roles may use it for this run; others skip it (no ledger row).
- **Family independence (council):** a seat may demote within its family; it never takes a family active on another council seat anywhere in this PR. `reviewer-esc` runs only on a family no council seat (`reviewer-a`, `reviewer-b`, `reviewer-c`) used this PR ("seat" = council seats only; `--providers` enforces this whenever an unused family exists).
- **Author independence (task loop):** `task-reviewer` skips any rung whose family equals the authoring family (`implementer*`/`tester`). If zero rungs remain on a standalone single-family host, announce `degraded task-review: single-family host (<family>)`; if non-author families are exhausted or unreachable, degrade to a rung with a model distinct from `author_models` and announce `degraded task-review: non-author families exhausted/unreachable (reviewed by <model>)`. Never review on the identical author model.
- **Privacy gate:** `privacy: trains` rungs auto-skip on confidential tasks or diffs; compaction and summary never route to `trains`.
- **Council budget guard:** max 14 real reviewer dispatches per PR including escalation (9 seat, 3 seat demotion, 1 escalation, 1 escalation demotion); a demoted seat keeps its new rung for the day. Budget skips cost 0.
- **Backup ladder walk & zero reachable rungs:** when a role's 3 rungs are all exhausted, unreachable, reserved, or skipped (privacy/author-model): (a) implementation seats first try sibling hand-off (`implementer-deep <-> implementer`, never revisiting an exhausted seat); (b) walk `## Backup ladder` in ascending `order` for rows matching `*` or the role (or either implementation seat after hand-off), enforcing pool/ledger, soft-cap/reserve, family independence (not active on another council seat or `reviewer-esc`, and for `reviewer-esc` neither a council-seat nor an author family), author-model skip (`reviewer-*`), author-family, privacy gate, and never-on-driver rules, announcing `backup: <role> -> <provider>/<model>` (or `demote: <seat> -> <provider>/<model> (author model conflict)` when advancing past an author model); (c) reviewer seats with none left follow the degraded-council rule; `implementer*`, `scout`, `tester`, `patch`, and `task-reviewer` stop via **Budget stop & resume** below, never running on the driver model.
- **Budget stop & resume:** when no eligible rung remains for a required role (or < 2 independent council families remain healthy due to quota exhaustion), stop and report:
  ```text
  budget stop: <role>
    exhausted: <pool> (until <HH:MM or ISO timestamp>), ...
    earliest resume: <timestamp>  -> rerun `oneshot` to resume from state
  ```
  Record `earliest_resume` and `soft_cap_counts` in `oneshot-state.md`. On resume, re-read `quota-ledger.tsv` without reopening closed rounds. Include a **Budget** summary block in the PR body and final report.
- **Degraded council (dual-family & model regime):** when a seat is lost or families overlap, council shall not block if >= 2 distinct members can review and differ from the implementer model. As long as >= 2 distinct reviewer models differ from `author_models`, continue with active seats (recording `degraded council author vote: model-level independence (<model1>, <model2>)`). PASS requires unanimous 2/2 healthy PASS, 0 confirmed red findings, and green tests; if < 2 distinct non-author reviewer models remain healthy, stop with `yellow: degraded council (< 2 independent review models)`.
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

- Under oneshot, land PR merge parses the effective last `council_verdict:` line in `$(git rev-parse --git-dir)/info/oneshot-state.md`, requiring `council_verdict: PASS` with `mode=nominal`, `mode=degraded`, or `mode=escalation` and `head=<sha>` matching local `HEAD` and remote PR head (`--match-head-commit <sha>`).
- A `no-tests` review pass is labelled `provisional: no-tests` and satisfies no green-tests gate except in `mode=nominal` on a repo with no test suite when build and lint are green and `no-tests decision: proceed` is recorded in state.
- A degraded council (< 2 independent families) stops with `yellow: degraded council`; `mode=degraded` and `mode=escalation` never report a provisional `no-tests` PASS.
- Any fixer running tests uses `implementer` (or `implementer-deep` for hard clusters), never `patch`.

## Council Contract

- Seats (`agents/*.md`, rungs in `PROVIDERS.md`): `implementer`, `implementer-deep`, `tester`, `scout`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`.
- When `GLOSSARY.md` exists, task briefs carry the required terms; spec review flags new undefined terms.
- Three reviewers, three independent model families, fresh subagent each. Round N+1 review re-dispatches all active council seats together; single-seat re-dispatch across rounds is forbidden.
- One line per finding: `path:line: emoji severity: problem. fix.`
- Severity only: red bug, yellow risk, blue nit (nits only on request).
- No praise, no scope creep, no "looks good".
- PASS modes: `mode=nominal` (>= 2/3 PASS), `mode=degraded` (unanimous 2/2 PASS), or post-round-3 `mode=escalation` (`round=esc`, single `reviewer-esc` seat PASS on a non-author model distinct from active council seats); all require zero unresolved confirmed red findings and green tests (or the `mode=nominal` `no-tests` exception under Review contracts).
- Council non-blocking rule & author vote: Council shall not block if >= 2 distinct members can review and differ from the implementer model. PASS in `mode=nominal`/`mode=degraded` requires >= 1 PASS vote from a non-author family or model-level independence (distinct models differing from `author_models`). Author families (`author_families`) and models (`author_models`) are implementation, `tester` (if tests committed), and fixer rungs (`implementer*`, `tester`, `patch`, CI/council fixers) producing branch commits recorded in state. If all active seats share an author family, model-level independence satisfies the author vote (recording `degraded council author vote: model-level independence (<model1>, <model2>)`) and council proceeds without blocking.
- Reviewer never fixes, fixer never reviews. No council seat may review code authored by the identical model.
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

Every dispatch names an explicit rung, never inheriting the driver model. After `<dest>/state/quota-ledger.tsv` and `soft_cap_counts` checks, any `exhausted`, `unreachable`, or failed `transient` rung re-dispatches the SAME role on the next eligible rung in `PROVIDERS.md` (then sibling hand-off and `## Backup ladder`, skipping active council-seat families and `author_models` for `reviewer-*`), announcing demotion or `backup: <role> -> <provider>/<model>`, or stopping via Budget stop & resume (`yellow: degraded council` for council) when none remain.
