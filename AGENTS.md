# Cybernetic SDLC Harness

`oneshot` harness. `PROVIDERS.md` selects all dispatch models/options; this file owns contracts.

## Context Hygiene and Subagent Routing

- Searches >1 file or 50+ lines use `scout` (read-only, compressed `path:line` tables), never inline loops.
- TDD red and CI use `tester` (uncommitted failing tests, never production code; suites/scripts/CI logs return compressed excerpts).
- Main orchestrates; never writes implementation inline. `dispatch` sends fresh agents per task (`tester` first for changed tests, then `implementer`/`implementer-deep`).
- `patch` handles 1-2 file edits needing no test run. Council/CI test-running fixers use `implementer`/`implementer-deep`.

## Provider Profiles

- **Location:** `PROVIDERS.md` beside `HARNESS.md` in `<dest>`, bound from `providers/<profile>.md` via `install.sh --profile <name>`, `--profile-file <path>`, or `--providers <list>`. Skills reference the active provider profile (`PROVIDERS.md`).
- **Role vocabulary:** seat roles (`agents/*.md`): `scout`, `tester`, `implementer`, `implementer-deep`, `patch`, `reviewer-a` (review captain), `reviewer-b`, `reviewer-c`. Ad-hoc: `task-reviewer` (spec/quality), captain ruling; optional `designer`/`planner` require primary iff mentioned. Alternatives use delegate role `design`. Advisory roles (validated, optional, never rendered): `driver` (main session) and `compaction`. Every profile requires nine dispatched primaries (eight seats + `task-reviewer`).
- **Columns:** `role | rung | provider | model | effort | family | privacy`. `rung`: `primary`, `fallback`, `last-resort` (ladder order). `provider`: T3 Code provider instance id (standalone hosts dispatch only their own). `model`: catalog id (`^[A-Za-z0-9][A-Za-z0-9._/-]*$`). `effort`: `<option-id>=<value>` in the provider's vocabulary at most `high`, or `-` for a verified default at most `high` (council reviewer-a/b/c may use `xhigh`; `-` allowed only in `effort` on dispatched rows; on advisory rows also in `provider`, `model`, `family`, never in `rung` or `privacy`). `family`: lowercase model family (`^[a-z0-9][a-z0-9-]*$`; one family across providers). `privacy`: `ok` or `trains` (privacy gate).
- **Optional sections** (default: pool `<provider>/<model>` per rung, nothing reserved):
  - `## Quota pools`: `pool | provider | models | window | soft-cap | reserve`. `pool` (`^[a-z0-9][a-z0-9-]*$`, unique) names the bucket; `models` (`^[A-Za-z0-9*][A-Za-z0-9._/*-]*$`) globs `model` for `provider`; `window` (`^[1-9][0-9]*(h|d|w|mo)$`, e.g. `5h`) is the fallback cooldown; `soft-cap` (`-` or positive integer) caps run dispatches before reserving the pool for `reserve` (`-` or comma-separated roles).
  - `## Backup ladder`: `order | roles | provider | model | effort | family | privacy`; unique positive `order`, `roles` `*` or comma-separated dispatched roles, other cells as dispatched rows.
  - `## Single-provider review`: `provider | model | effort | family | privacy` (cells as dispatched rows): council-only per-provider distinct review models at verified effort <= `xhigh`; fewer than two non-author models means stop outside the single exception below, never widen the profile review allowlist.
- **Validation (installer):** Outside fenced blocks, optional headings select their tables; `## Project management` is skipped; other `## ` headings select roles. Invalid profiles fail before writes (exit 1): missing primary, duplicate primary council model, invalid role/pool/backup/single-provider rows (7/6/7/5 cells). Effort above high reports `effort above high` except `xhigh` on reviewer-a/b/c rows, exclusively council backup rows (no wildcard or mixed roles), and council-only single-provider rows; higher levels are rejected everywhere; `-` requires runtime verification. Retired roles warn and are ignored. `--prune` preserves unmanaged `<dest>/state/`. `--profile`, `--profile-file`, `--providers` conflict (exit 2). Refresh reuses recorded `# profile`, `# profile-file <abs path>`, `# providers <list>`, `# pm <value>`; missing profile-file exits 2 (`install.sh: profile file not found: <path>`); pre-profile installs keep `opencode-go`.
- **Project management:** `install.sh --pm <auto|github|linear|jira|none>` (default `auto`, invalid exits 2; without flag or `# pm`, TTY prompts once) renders `backlog_tracker: <value>` as the installed `PROVIDERS.md`'s trailing `## Project management` section.

## Dispatch Adapter

Before each path check: council seats/rulings <= `xhigh`, all other work <= `high`, including driver, native pins, advisory roles and inherited settings. Unsafe defaults need explicit safe options or an unreachable rung.

Walk each role's rungs in ladder order (`primary -> fallback -> last-resort`; Routing Rules terminal boundary applies). Paths 1/3 seat `<contract-path>`: `antigravity`: literally `` `<skills-dir>/_harness/agents/<seat>.md` (`<skills-dir>` = grandparent of `oneshot/SKILL.md`, parent of `oneshot/` in `<skills>`; never the driver's path) ``; for other providers, driver-substituted `<harness-dir>/agents/<seat>.md` (`<harness-dir>` holds `HARNESS.md`). Paths 1/3 seat briefs start with `Role contract: read <contract-path>; follow its body; its permissions block is your policy and you enforce it yourself. Rung: <provider>/<model> (<effort>), privacy: <ok|trains>.` (`task-reviewer`, `designer`, `planner` and `design` carry `Rung:` only; missing `Rung:` = unknown privacy; the captain ruling uses `reviewer-a`'s contract on the captain's rung). Use the first matching path:

1. **T3 Code orchestration tools available.** Check eager, deferred/tool-search, ACP, and `<mcp_servers>` tools (lazy `t3-code` schemas such as `<appDataDir>/brain/<conversation-id>/mcp/t3-code/{orchestrator_capabilities,delegate_task}.json`: read once, invoke via `call_mcp_tool`). While `t3-code` (`delegate_task`) is present, NEVER use Path 2/3 native tools (`invoke_subagent`, `spawn_agent`, `Agent`, `subagent`/`task`). Call `orchestrator_capabilities` once before the first dispatch: a missing/disabled `provider` (`canRunChildTask: false`) or an option invalid on a listed model hits Path 4; models omitted from preview (`omittedModels`/catalog IDs) are still tried (Path 4 only if rejected). Dispatch every provider (including `opencode`) via `delegate_task`: `target.providerInstanceId` = `provider`, `target.model` = `model`, `isolation: shared`, `mode: async` (fan-out) or `wait`; effort `-` -> `target.options = {}` only after verifying the effective default is at most the context ceiling; otherwise use an explicit safe option or mark unreachable; explicit effort -> `{<option-id>: <value>}` with a value within the context ceiling (plus same-provider defaults like `serviceTier=default` only when matching driver). Roles: `research` (`scout`), `test` (`tester`), `implementation` (`implementer*`, `patch`), `review` (`reviewer-*`, captain ruling, `task-reviewer`), `design` (`designer`, `planner`, alternatives).
2. **Standalone OpenCode native pin (no T3 tools).** Without `t3-code` on OpenCode, when the rung matches the seat's rendered first `opencode` pin (`agents/<seat>.md`, plus `#<value>` for `variant`): dispatch via `subagent`/`task` with no model override, keeping `Rung:`. Unpinned seats never use Path 2.
3. **Standalone same-provider native dispatch (no T3 tools, `provider` matches active host).** Announce with `Rung:` (and `Role contract:` when not auto-loaded): `opencode`: `subagent`/`task` with explicit `model` `<model>` (plus `#<value>` for `variant`; `type general` for `task-reviewer`/`designer`/`planner`/`design`); `codex`: `spawn_agent` + `wait` with explicit `model` `<model>` and `reasoning_effort` (from `reasoningEffort=<value>`); `claudeAgent`: `Agent` (`run_in_background: false`, seat subagent or general-purpose for `task-reviewer`/`designer`/`planner`/`design`) with explicit `model` `<model>`; `antigravity`: `invoke_subagent` `self` for every seat and `task-reviewer` with self-enforced `<contract-path>`/read-only policy (`research` has no shell for `git diff`/`log`/`show` and fits only shell-free `design`), passing `Model: inherit` only when `<model>` equals the session model, or `Model: flash` only for a flash-tier `google` rung on a `google` session (other rungs hit Path 4 `unreachable`, keeping `Rung:` and pools exact).
4. **None applies.** `unreachable`: stop at operational terminal; otherwise announce `seat <seat>: <provider>/<model> unreachable on this host, demoted to <next>`.

`designer`/`planner`: read-only drafts (text + decisions); no edits, commits, execution or delegation. Draft without invoking the skill. Driver invokes shape/plan once; owns conversation, approvals, canonical docs/commits and phases. Absent roles use legacy driver drafting. Present roles use profile rungs and explicitly named backups only (not `*`), never inherited driver or implementation fallback; exhaustion stops. Apply quota/privacy/effort rules. Draft-only authorship is not code authorship.

`task-reviewer` and **design alternatives** have no agent file. Alternatives use `designer` rungs when present, else `implementer-deep` then `implementer` rungs across distinct families (fewer reachable -> `degraded design: N families`); never dispatch an implementation seat. Children self-enforce policy; never inherit the driver model or unsafe effort.

## Routing Rules

- **Operational terminal boundary:** `scout`/`tester`/`patch`/`implementer`/`implementer-deep`: explicit last-resort is terminal; ineligibility/routing failure stops the original role: `budget stop: <role>`, without terminal same-model alternates, sibling hand-off, wildcard or explicit backups. Primary/fallback keep same-model alternates. Retry transient once; task failures keep fix/debug caps, never budget events. Roles without explicit last-resort retain legacy sibling/backup routing. Review/designer/planner unchanged.

- **Ladder:** resolve each rung's pool (first matching `## Quota pools` row, else `<provider>/<model>`), check the ledger and `soft_cap_counts`, and skip rungs whose pool is exhausted (`now < retry_after`) or soft-capped for other roles; `reviewer-*` seats also skip rungs whose `model` is in `author_models` (`demote: <seat> -> <provider>/<model> (author model conflict)`). On `exhausted`, `unreachable` or failed transient retry, announce and advance; stop at the operational terminal boundary.
- **Same-model alternate:** except at an operational terminal rung, before advancing past an ineligible rung, use a `## Backup ladder` row matching the role with the identical `model` on another eligible pool (`backup: <role> -> <provider>/<model>`).
- **Balanced seat fallback:** with no eligible primary or same-model alternate, a council seat takes, from its remaining ladder rungs and matching backup rows, the one whose pool has the fewest dispatches this run (`soft_cap_counts`), ties by ladder order then `order`, under all eligibility checks.
- **Quota ledger (`<dest>/state/quota-ledger.tsv`):** machine-local, never committed (`pool  provider  exhausted_at  retry_after  source_role  note`). Read before every ladder walk, pruning rows with `retry_after <= now`. On `exhausted`, write the rung's `pool` with `retry_after` from the error (`Retry-After`, "resets at ...") or `exhausted_at + window` (default `5h`). Success clears its pool row and increments `soft_cap_counts` in `oneshot-state.md`. Update under `mkdir <dest>/state/quota-ledger.lock` (break locks > 60s, remove on exit): read-merge-write `<dest>/state/.quota-ledger.$$.tmp`, `mv -f`, keep the later `retry_after`.
- **Failure classes:**
  - `exhausted` (HTTP 429, "weekly usage limit", "usage limit reached", "plan limit", "quota", "rate limit reached"): record the pool (provider-wide limits: every pool of that provider, same `retry_after`), demote.
  - `unreachable` (unlisted in `orchestrator_capabilities`, disabled provider, `delegate_task` rejection, no adapter path): skip for the session, announce, no ledger row.
  - `transient` (HTTP 5xx, timeout, stream cut): retry once, then skip that rung for this dispatch (no ledger row).
  - `task failure` (bad output, failing tests): not a budget event; fix/debug caps apply.
  - Budget/eligibility skips never consume council rounds, the council budget guard, or fix attempts.
- **Soft cap & reserve:** once a pool's `soft_cap_counts` reaches its `soft-cap`, only `reserve` roles may use it this run.
- **Seat distinctness (council):** seats run on pairwise-distinct models, none in `author_models`; a demotion may cross families for balance, never onto a model active on another seat.

**Single-reviewer council (oneshot only):** Optional `mode=single` at 1 or 2 eligible provider instances, even with more review models. >2 requires normal 2+ review; 0/unknown providers or zero independent allowed reviewers stop. Count unique profile provider instance IDs with an eligible pool across ALL roles via quota/soft-cap/privacy/reachability, not models/families/pools; one healthy pool preserves its provider.

At council start, demotion/round and freshly before merge audit `council_providers: ids=<sorted,unique ids> count=<n> head=<sha>` plus per-pool eligibility reasons, `council_reviewer: <provider/model> head=<sha>` and `captain: <seat> <provider>/<model> head=<sha>`. Missing/unknown/stale evidence cannot unlock single; recovery >2 requires normal re-review. Sole reviewer is captain; rulings are fresh on that captain. Require its final real `reviewer_vote: PASS reviewer=<provider/model> head=<sha>`, zero unresolved accepted findings and green actual checks (no no-tests exception), all matching local/remote HEAD. Retain author exclusion, allowlist, context-scoped ceiling and budgets.

Additional verdict: `council_verdict: PASS|FAIL round=<n> mode=single providers=<1|2> reviewer=<provider/model> head=<sha>`; normal formats unchanged.

- **Single-provider review:** at council start and each seat demotion, if exactly one profile provider still has an eligible pool (others exhausted or unreachable), announce `single-provider review: <provider>` and seat selected reviewers from its `## Single-provider review` rows: pairwise-distinct models outside `author_models`, Seat A first; `opencode` included. Re-check each round; two providers permit optional single; never edit profile rows.
- **Context-scoped effort ceiling:** Only runtime council seats and captain rulings may use profile-configured `xhigh`; council is the only skill permitting above high (maximum xhigh). Driver, defaults, advisory/design, task-reviewer, fixing and testing remain <= `high`, even with shared reviewer contracts. `max`, `ultra`, `ultrathink`, `ultracode` and equivalents are forbidden everywhere. Verify capabilities; Argon explicitly uses `thinking_level=high` (no xhigh). Defaults need safe options or an unreachable rung; skills never switch the driver.
- **Author independence (task loop):** `task-reviewer` skips the authoring family (`implementer*`/`tester`): none left on a standalone single-family host -> `degraded task-review: single-family host (<family>)`; non-author families exhausted or unreachable -> a model outside `author_models`, announcing `degraded task-review: non-author families exhausted/unreachable (reviewed by <model>)`. Never the author model.
- **Privacy gate:** `privacy: trains` rungs auto-skip on confidential tasks or diffs; compaction and summary never route to `trains`.
- **Council budget guard:** max 15 real reviewer dispatches per PR (9 seat, 3 captain rulings, 3 demotions); skips and skipped rulings cost 0; a demoted seat keeps its rung for the day.
- **Backup ladder walk:** outside the operational terminal boundary, once rungs/alternates are ineligible: (a) implementation seats try sibling hand-off (`implementer-deep <-> implementer`, never back to an exhausted seat); (b) walk `## Backup ladder` rows matching `*` or the role (ascending `order`; council seats by balanced fallback) under all eligibility rules (`backup: <role> -> <provider>/<model>`); (c) a reviewer seat with none left is lost (degraded council); other roles budget-stop, never running on the driver model.
- **Budget stop & resume:** when no eligible rung remains for a required role (or review quorum is unavailable under the single exception), stop and report:
  ```text
  budget stop: <role>
    exhausted: <pool> (until <HH:MM or ISO timestamp>), ...
    earliest resume: <timestamp>  -> rerun `oneshot` to resume from state
  ```
  Record `earliest_resume` and `soft_cap_counts` in `oneshot-state.md`; on resume re-read the ledger without reopening closed rounds. Put a **Budget** block in the PR body and final report.
- **Degraded council:** a lost seat or overlapping families never block while >= 2 distinct healthy reviewer models are outside `author_models` (on overlap record `degraded council author vote: model-level independence (<model1>, <model2>)`); else use the audited single exception or stop with `yellow: degraded council`.
- **Rounds:** max 3 council rounds per PR; a round-3 FAIL stops to the user.
- **Action-name aliases:** agent files carry both `bash`/`task` and `shell`/`subagent` spellings so denies never go inert.

### Permission rules

- Agent `permissions:` lists evaluate last-match-wins (order is policy).
- Read-only seats deny `bash`/`shell` broadly first, then allow narrow git only: `scout` allows `git log`; `reviewer-a`, `reviewer-b`, `reviewer-c` allow `git diff`, `git log`, `git show`.
- `implementer`, `implementer-deep`, and `tester` allow `bash`/`shell` broadly, then deny destructive patterns (`rm -r*`, `git clean`, `git push`, `pkill`, `killall`) and secret readers (`<cmd> *<secret>*` for `cat`, `head`, `tail`, `less`, `strings`, `xxd`, `sed`, `awk`, `base64`, `od`, `paste`, `printenv`, `env`).
- `patch` denies `bash` and `shell` broadly and edits files only.
- All seats deny reads of `.env`, `.env.*`, `.zshrc`, `.zsh_history`, and `.ssh/*` (bare and nested) after its broad read allow.
- No seat commits or pushes on `main`/`master`: `implementer*` and `tester` check `git branch --show-current` at Step 0 and refuse there (`tester` never commits); fixers that run tests, commit, or push use `implementer*`.
- Shell/git denies are best-effort, not a sandbox.

### Review contracts

- Under oneshot, land merges only when the effective last verdict line in `$(git rev-parse --git-dir)/info/oneshot-state.md` is `council_verdict: PASS` with `mode=nominal`, `mode=degraded`, `mode=captain`, or audited `mode=single` and `head=<sha>` matching local `HEAD` and the remote PR head (`--match-head-commit <sha>`). Single requires the audit/vote/checks contract above, freshly re-audited before merge.
- `no-tests` is `provisional: no-tests`, never green tests except nominal mode with no suite, green build/lint and state `no-tests decision: proceed`.
- Fixers running tests use `implementer` (or `implementer-deep` for hard clusters), never `patch`.

## Council Contract

**Profile review allowlist:** Council uses reviewer-a/b/c ladders, council backups and single-provider rows; task reviews use task-reviewer ladders/backups. Never cross these sets or widen either for lost seats. Except single mode, <2 eligible independent council models stop. If the preferred captain authored the diff, exclude that model and pass captaincy to the first healthy eligible seat; another provider cannot restore author-model independence.

- Seats (`agents/*.md`, rungs in `PROVIDERS.md`): `implementer`, `implementer-deep`, `tester`, `scout`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`. When `GLOSSARY.md` exists, task briefs carry the required terms; spec review flags new undefined terms.
- Normally three fresh reviewers on pairwise-distinct models review the same scope in parallel; round N+1 re-dispatches all active seats together (single-seat re-dispatch across rounds is forbidden outside mode=single). Findings: `path:line: emoji severity: problem. fix.` (red bug, yellow risk, blue nit on request only). No praise or scope creep.
- **Review captain:** `reviewer-a`, else the first healthy of `reviewer-b`, `reviewer-c`; state records `captain: <seat> <provider>/<model>` (never in `author_models`). The captain reviews like any seat; if any seat voted FAIL or any red/yellow finding exists, the driver then dispatches a **captain ruling** (fresh subagent, captain's rung) with the merged, deduplicated findings (ids, seat attribution), diff, spec, and plan, which outputs:
  ```text
  <finding-id>: accept | defer | reject: <one-line reason>
  Captain verdict: PASS | FAIL
  ```
  `accept` (any severity): fixed before PASS in every mode. `defer`: valid but need not block this PR (unrelated, overengineering, out of scope; backlog). `reject`: wrong, with `path:line` evidence. PASS only if every finding is deferred or rejected.
- **Captain limits:** a red the driver confirms in code as an in-scope correctness, security, or data-loss bug introduced by this diff is never deferred or rejected: the driver overrides it to `accept` (`captain overruled: <finding-id>`). Verify accepted reds before fixing; fix only accepted findings; require green tests.
- **Backlog:** each `defer` adds `backlog: <finding line> (<reason>)` to `oneshot-state.md` and the PR body's `## Backlog`; after merge `land` files one ticket each per `backlog_tracker`: `github` (`gh issue create`), `linear`/`jira` (MCP tools), `auto` (Linear MCP, else Jira MCP, else `gh` with issues, else `none`), `none` or failure (PR body list only).
- **Verdict modes** (`council_verdict: PASS|FAIL round=<n> mode=<nominal|degraded|captain> head=<sha>`, `<n>` in `1..3`):

  | mode | PASS condition |
  | --- | --- |
  | `nominal` | >= 2/3 seats PASS, zero unresolved accepted findings, green tests (or the `no-tests` exception) |
  | `degraded` | 2/2 healthy seats PASS (one seat lost), zero unresolved accepted findings, green tests |
  | `single` | 1 independent allowed reviewer PASS, zero unresolved accepted findings, green actual checks; audited 1 or 2 providers, no no-tests exception |
  | `captain` | captain verdict PASS overriding FAIL votes (every finding behind a FAIL vote deferred or rejected), zero unresolved accepted findings, green tests (no `no-tests` exception) |

  Captain mode works in any round with 2 or 3 healthy seats.
- **Author vote:** PASS needs >= 1 PASS from a non-author family or model-level independence (models outside `author_models`); in captain mode the captain's PASS counts; in single mode the sole independent reviewer's final PASS counts. `author_families`/`author_models` are the rungs (`implementer*`, `tester`, `patch`, CI/council fixers) producing branch commits recorded in state.
- Reviewer never fixes; fixer never reviews. No council seat may review code authored by the identical model. Verify findings in code.

## Unit Naming Map

| Trigger | Unit |
| --- | --- |
| oneshot | full pipeline (controller) |
| shape, plan | spec and planning skills |
| domain-modeling, codebase-design | glossary/ADR and deep-module design disciplines |
| dispatch | subagent-driven execution |
| tdd, debug | red-green-refactor and root-cause disciplines |
| verify | evidence-before-assertions completion gate |
| council | consensus review with review captain (skill) |
| land | finish branch, PR options, backlog tickets |
| make-ci-green | CI babysitting loop |
| implementer, implementer-deep, tester, scout, patch | actuation / testing / discovery agents (per `PROVIDERS.md`) |
| reviewer-a (captain), reviewer-b, reviewer-c | council seat agents (per `PROVIDERS.md`) |

## Fallback Mechanics

Dispatch explicit rungs, never the driver model. Ineligible operational terminal rungs stop; otherwise announce and re-dispatch the SAME role per Routing Rules (alternates, ladder, siblings/backups, balanced council seats), else budget stop (`yellow: degraded council` for council).
