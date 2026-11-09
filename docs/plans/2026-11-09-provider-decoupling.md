# Plan: provider decoupling

Spec: `docs/specs/2026-11-09-provider-decoupling-design.md`. Branch `feat/provider-decoupling`. Base for "pre-change" content: commit `578cc27`.

Two independent tasks with disjoint file sets, dispatched in parallel (Parallel mode: implementers leave changes uncommitted; the controller commits serially).

## Task 1: provider layer + installer binding (implementer-deep)

Files: `providers/tri.md` (new), `providers/opencode-go.md` (new), `agents/*.md` (delete the `model:` line only), `install.sh`, `test/install.sh`.

1. `providers/opencode-go.md`: profile header, the Model Tank table from `git show 578cc27:AGENTS.md` converted into the spec routing-table format (role, rung, provider=opencode, model, effort=variant=<v> or `-`, family, privacy), plus the prose that is provider-specific: quotas (req/5h), effort notes, off-peak note, Privacy Footnotes, the "Go-only" statement scoped to this profile. Rows for all ten required roles plus `driver` (advisory: host default, effort `-`) and `compaction`.
2. `providers/tri.md`: the spec `tri` table in routing-table format, the distribution rationale, privacy notes.
3. Delete line `model: ...` from each of the nine `agents/*.md`. Nothing else in those files changes.
4. `install.sh`: `--profile <name>` / `--profile=<name>`, default `tri`; validation (exit 2 unknown, exit 1 incomplete) before any write; PROVIDERS.md copy; agent native-pin rendering; manifest line 2 `# profile <name>`; usage text; notes for seats with no opencode rung.
5. `test/install.sh`: update byte-identity assertions for agents to compare against the rendered expectation; add the spec's new cases.
6. Verify: `bash test/install.sh` green; `bash -n install.sh`; shellcheck if available.

## Task 2: harness layer rewrite (implementer-b)

Files: `AGENTS.md`, `skills/**`, `README.md`.

1. `AGENTS.md`: remove the Model Tank table, quotas, Go-only rules, and Privacy Footnotes table (they move to profiles in Task 1). Add "Provider Profiles" (where the active table lives, role vocabulary, columns meaning in one paragraph), "Dispatch Adapter" (spec section, verbatim in substance), and provider-neutral routing rules (ladder, family independence incl. within-family demotion, author independence for task-reviewer, privacy gate on `privacy: trains`, budget guard, degraded council). Keep permissions, review contracts, council contract, naming map, reworded where they mention Go or pinned Go models.
2. Skills: replace every provider/model mention and every "AGENTS.md Model Tank / ladder" reference with "the active provider profile (`PROVIDERS.md`)" and the AGENTS.md routing rules; dispatch through "the dispatch adapter in AGENTS.md" instead of only the `subagent` tool. Host worktree tooling worded host-neutral with OpenCode and T3 Code as examples. No loop, cap, or gate changes.
3. `README.md`: tagline, badges, overview, flow diagram labels, Model Tank section -> "Provider layer" with the `tri` table and rationale and a note on the legacy profile, structure block (`providers/`), install section (`--profile`, PROVIDERS.md, manifest line 2), verification snippet.
4. Verify: `grep -rnE 'opencode-go/|req/5h|#(low|medium|high|xhigh|max)\b|OpenCode Go|Go famil' AGENTS.md skills` returns nothing.

## Then

Controller: commit each task, run the full suite, council (Google, Anthropic, OpenAI seats on the `tri` profile), fix rounds, land decision with the user.
