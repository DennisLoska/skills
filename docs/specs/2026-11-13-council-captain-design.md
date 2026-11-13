# Council Captain, Anthropic Implementers & Single-Provider Review - Design

Status: approved (2026-11-13, user decisions recorded below).

## Goal

1. Every profile defaults `implementer` to Claude Opus 5.5 (`high`) and `implementer-deep` to Claude Fable 5.2 (`high`), with `gemini-4-carbon` and `gpt-6.1-sol` as fallbacks everywhere.
2. Replace the escalation reviewer (`reviewer-esc`) with a **review captain**: one of the three council seats who reviews like any other seat and then rules on every finding. The captain may approve over two FAIL votes when the blocking findings are unrelated, overengineering, not relevant, or out of scope. Those findings become backlog tickets.
3. Council seats: Seat A = captain on `claude-fable-5-2`, Seat B = `gpt-6-astra`, Seat C = `gemini-4-carbon`. Review runs only on Anthropic, OpenAI and Google models. Fallbacks are balanced dynamically across those three providers based on quota.
4. **Single-provider review:** when only one provider has budget, review runs on that provider's models at `high` effort (or the provider's equivalent). This is a fallback condition, never a standing restriction.
5. **Anthropic effort cap:** no `anthropic`-family dispatch ever uses an effort above `high`.
6. **Project-management setting:** the installer exposes a backlog tracker (`github` via `gh`, `linear` or `jira` via MCP, `auto`, `none`) that the harness uses to file deferred findings as tickets.

## User decisions (2026-11-13)

- Captain = Seat A (`reviewer-a`) on Fable 5.2. Seat B = `gpt-6-astra`, Seat C = `gemini-4-carbon`. No OpenCode models in review ladders.
- Fallbacks for reviewer seats can come from any of the three review providers, chosen dynamically by remaining limits to balance load.
- When only one provider is left, review uses that provider's models at high effort. Review is not limited to one provider merely because it is the only one with budget at the moment.
- Backlog tracker is an install-time setting: `gh` CLI for GitHub issues, MCP for Linear or Jira. `auto` derives it from the user's context. The maintainer's reinstall uses `linear`.
- All profiles: implementer Opus 5.5 high, implementer-deep Fable 5.2 high, fallbacks `gemini-4-carbon` and `gpt-6.1-sol`.
- No Anthropic agent ever runs above `high` effort.

## 1. Implementer ladders (all six profiles + `--providers` generator)

| role | rung | provider | model | effort | family |
| --- | --- | --- | --- | --- | --- |
| implementer | primary | antigravity (`claude` profile: claudeAgent) | claude-opus-5-5 | thinking_level=high (claudeAgent: effort=high) | anthropic |
| implementer | fallback | antigravity | gemini-4-carbon | thinking_level=high | google |
| implementer | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai |
| implementer-deep | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic |
| implementer-deep | fallback | antigravity | gemini-4-carbon | thinking_level=high | google |
| implementer-deep | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai |

- Profiles with `claudeAgent` (quad, claude) add a `## Backup ladder` row for `implementer` on `claudeAgent claude-opus-5-5 effort=high` (the same-model alternate below makes it the first stop when Antigravity's Claude pool is exhausted).
- Single-provider profiles keep their provider's own implementation rows in `## Backup ladder` so standalone hosts still work. Cross-provider rungs are `unreachable` there and demote per the Dispatch Adapter.
- **Same-model alternate (new routing rule):** before advancing past an ineligible rung, the driver uses a `## Backup ladder` row that matches the role and carries the identical `model` on another eligible pool. Example: Antigravity's `claude-opus-5-5` is exhausted, so the driver uses `claudeAgent` `claude-opus-5-5` before falling to `gemini-4-carbon`.
- quad `## Quota pools`: `antigravity-claude` loses its `reviewer-b` reserve (`soft-cap -`, `reserve -`), because Seat B no longer runs on Antigravity Claude.

## 2. Council seats (all profiles)

| role | rung | provider | model | effort | family |
| --- | --- | --- | --- | --- | --- |
| reviewer-a (captain) | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic |
| reviewer-a | fallback | codex | gpt-6.1-terra | reasoningEffort=high | openai |
| reviewer-a | last-resort | antigravity | gemini-4-argon | thinking_level=high | google |
| reviewer-b | primary | codex | gpt-6-astra | reasoningEffort=high | openai |
| reviewer-b | fallback | antigravity | gemini-4-argon | thinking_level=high | google |
| reviewer-b | last-resort | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic |
| reviewer-c | primary | antigravity | gemini-4-carbon | thinking_level=high | google |
| reviewer-c | fallback | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic |
| reviewer-c | last-resort | codex | gpt-6.1-terra | reasoningEffort=high | openai |

- No reviewer ladder rung, and no `## Backup ladder` row whose `roles` covers a `reviewer-*` seat (including `*` rows), may use the `opencode` provider. Backup rows that serve other roles via `*` are rewritten to explicit role lists when they are on `opencode`. Reviewer backup rows use Anthropic, OpenAI or Google models at high effort.
- **Balanced seat fallback (new routing rule):** when a council seat's primary is ineligible, the seat picks, from its remaining eligible ladder rungs and matching backup rows, the rung whose quota pool has the **fewest dispatches this run** (`soft_cap_counts` in `oneshot-state.md`; the counter now tracks every pool, not only soft-capped ones). Ties break by ladder order. Every candidate still passes pool/ledger, privacy, author-model and seat-distinctness checks.
- **Seat distinctness replaces council family independence:** council seats always run on pairwise-distinct models, and the installer still enforces pairwise-distinct primary families. A demotion may cross families for balance, but never onto a model already active on another seat or listed in `author_models`.
- `reviewer-c` is required in every profile (all profiles now carry three review families).

## 3. Review captain (replaces `reviewer-esc`)

- **Who:** `reviewer-a` holds the captaincy. If Seat A has no eligible rung, captaincy passes to the first healthy seat in order `reviewer-b`, `reviewer-c`. State records `captain: <seat> <provider>/<model>`. The captain must, like every seat, run on a model not in `author_models`.
- **Review:** the captain reviews the same scope with the same instruction block as the other seats (verdict + findings), in parallel with them.
- **Ruling:** after all seat verdicts are in, if any seat voted FAIL or any red/yellow finding exists, the driver dispatches a **captain ruling**: a fresh subagent on the captain's rung that receives the merged, deduplicated finding list (with seat attribution), the diff, the spec and the plan. For each finding it outputs one line:
  `<finding-id>: accept | defer | reject: <one-line reason>`
  - `accept`: must be fixed in this PR.
  - `defer`: valid but unrelated, overengineering, not relevant, or out of scope for this change. It becomes a backlog ticket.
  - `reject`: wrong, with evidence (`path:line`).
  - Final line: `Captain verdict: PASS | FAIL`.
- **Limits on the captain:** a red finding that the driver confirms against real code as an in-scope correctness, security or data-loss bug introduced by this diff can never be deferred or rejected. The driver overrides such a ruling to `accept` and records `captain overruled: <finding-id>`. Green tests are always required.
- **Receiving rigor:** the driver still verifies every `accept`ed red against the code before dispatching fixers. Fixers address only `accept`ed findings.
- **Backlog:** every `defer` produces a `backlog: <finding line> (<reason>)` line in `oneshot-state.md`, a `## Backlog` section in the PR body, and a ticket filed by `land` per the project-management setting (section 6).

### Verdict modes

| mode | PASS condition |
| --- | --- |
| `nominal` | >= 2/3 seats PASS, zero accepted unresolved red findings, green tests (or the `no-tests` exception) |
| `degraded` | 2/2 healthy seats PASS (one seat lost), zero accepted unresolved red findings, green tests |
| `captain` | captain verdict PASS overriding FAIL votes: every finding behind a FAIL vote is `defer`red or `reject`ed, zero accepted unresolved red findings, green tests (no `no-tests` exception) |

- State line: `council_verdict: PASS|FAIL round=<1..3> mode=<nominal|degraded|captain> head=<sha>`. `mode=escalation` and `round=esc` are retired. `land` accepts `nominal`, `degraded` and `captain`.
- Captain mode is available in any round, and with 2 or 3 healthy seats.
- Round loop: max 3 rounds. If round 3 ends FAIL (no nominal or degraded PASS and no captain PASS), the council writes `council_verdict: FAIL round=3 ...` and STOPs to the user with findings and test output. No escalation seat.
- Council budget guard: max **15** real reviewer dispatches per PR (9 seat, 3 captain rulings, 3 demotions). Budget skips cost 0. A captain ruling is skipped (costs 0) when all seats PASS with no red/yellow findings.
- Author vote rule unchanged: PASS needs >= 1 PASS vote from a non-author family or model-level independence. In captain mode, the captain's PASS counts as that vote, since the captain is always on a non-author model.

## 4. Single-provider review

- New optional profile section `## Single-provider review` with columns `provider | model | effort | family | privacy`. It lists, per provider in the profile, the review models usable at `high` effort or the provider's equivalent (`effort=high`, `reasoningEffort=high`, `thinking_level=high`, `variant=high`). Every profile that has a provider lists at least 2 distinct models for it (3 where available).
- **Trigger:** at council start (and on each seat demotion), the driver checks whether exactly **one** provider in the profile still has an eligible pool (all others exhausted per the ledger or unreachable per `orchestrator_capabilities`/host). If so, the driver announces `single-provider review: <provider>` and all seats draw from that provider's rows: pairwise-distinct models, none in `author_models`, captain first (Seat A gets the first eligible row). This includes `opencode` when it is the last provider.
- Model-level independence satisfies the author vote. With fewer than 2 distinct non-author models the council stops with `yellow: degraded council` as before.
- The mode ends as soon as a second provider becomes eligible again. It never changes profile rows and is re-evaluated each council round.

## 5. Anthropic effort cap

- Rule (HARNESS): no `anthropic`-family dispatch may use effort above `high`. That covers `effort`/`thinking_level`/`variant` values outside `low|medium|high`, and `ultracode`/`ultrathink`/`xhigh`/`max`. Applies to ladder rows, backup rows, single-provider rows, the `--providers` generator, and ad-hoc dispatches.
- Installer: any role, backup or single-provider row with `family` `anthropic` whose effort value (after `=`) is not `low`, `medium` or `high` exits 1 before writing:
  - `install.sh: profile NAME invalid row: ROLE RUNG: anthropic effort above high`
  - `install.sh: profile NAME invalid backup row: ORDER: anthropic effort above high`
  - `install.sh: profile NAME invalid single-provider row: PROVIDER MODEL: anthropic effort above high`
  - `-` (provider default) is allowed.

## 6. Project-management (backlog tracker) setting

- `install.sh --pm <auto|github|linear|jira|none>` (default `auto`). An invalid value exits 2: `install.sh: unknown --pm value: X (expected auto|github|linear|jira|none)`.
- Recorded in `.harness-manifest` as `# pm <value>` and reused on refresh when `--pm` is omitted. When stdin is a TTY, no `--pm` is given and no `# pm` is recorded, the installer prompts once (`Backlog tracker [auto/github/linear/jira/none] (auto):`). Non-interactive runs default to `auto`.
- Rendered as a trailing section in the installed `PROVIDERS.md` (and therefore in combined instruction files):
  ```
  ## Project management

  backlog_tracker: <value>
  ```
  The profile validator treats `## Project management` as a non-table section.
- Semantics (`land`, filing deferred findings after merge):
  - `github`: `gh issue create --title "<short>" --body "<finding + reason + PR link>" --label backlog`, retrying without `--label` if the label is missing.
  - `linear` / `jira`: create one issue per deferred finding through the user's connected Linear/Jira MCP tools (team/project inferred from context or asked once).
  - `auto`: Linear MCP tools present -> `linear`; else Jira MCP tools present -> `jira`; else a GitHub remote with `gh` authenticated and issues enabled -> `github`; else `none`.
  - `none` (or any filing failure): keep the `## Backlog` list in the PR body and report it.

## 7. Retiring `reviewer-esc`

- Delete `agents/reviewer-esc.md`. Drop `reviewer-esc` from `REQUIRED_ROLES`, the seat vocabulary, docs, skills and tests.
- A profile row whose role is `reviewer-esc` is ignored with a stderr warning `install.sh: profile NAME: reviewer-esc rows ignored (role retired; captain replaces escalation)` (exit 0), so custom profile files keep installing.
- Install removes a manifest-owned `agents/reviewer-esc.md` (and `_harness/agents/reviewer-esc.md` in T3 Antigravity roots) even without `--prune`, and drops it from the new manifest.

## Out of scope

- Renaming seat files (Seat A stays `reviewer-a`).
- Changing `scout`, `tester`, `patch`, `task-reviewer`, `driver` or `compaction` ladders, except that Anthropic rows must respect the effort cap and `*` OpenCode backup rows become explicit non-reviewer role lists.
