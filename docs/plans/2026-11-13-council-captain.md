# Council Captain, Anthropic Implementers & Single-Provider Review - Implementation Plan

> **For agentic workers:** execute via the dispatch skill, one fresh subagent per task. Spec: `docs/specs/2026-11-13-council-captain-design.md` (the source of truth; read it in full).

**Goal:** Ship the spec. Tasks 1 and 2 own disjoint files and may run in parallel on branch `feat/council-captain`. Each task commits only its own files (`git add <paths>`; on an `index.lock` collision, wait and retry).

**Tech stack:** Bash, awk, Markdown.

---

### Task 1: Installer, profiles, tests (implementer-deep)

**Files (owned):** `install.sh`, `test/install.sh`, `test/fixtures/*`, `providers/*.md`, `agents/reviewer-esc.md` (delete).

- [ ] Red: update/add tests in `test/install.sh` first:
  - reviewer-esc retired: no `agents/reviewer-esc.md` rendered; stale manifest-owned `agents/reviewer-esc.md` removed on refresh without `--prune`; a custom profile with `reviewer-esc` rows installs with the stderr warning.
  - Anthropic effort cap: role/backup/single-provider rows with `family anthropic` and `effort=xhigh|max|ultrathink`, `thinking_level=max` etc. exit 1 with the exact spec messages; `-`/low/medium/high pass.
  - `## Single-provider review` validation (5 cells, same cell regexes as dispatched rows, effort cap), and `## Project management` is ignored by the validator.
  - `--pm`: valid values recorded as `# pm <v>` and rendered as `backlog_tracker: <v>` in installed `PROVIDERS.md`; refresh reuses it; invalid value exits 2 with the exact message; default `auto`.
  - Every shipped profile and every `--providers` composition: implementer primary `claude-opus-5-5`, implementer-deep primary `claude-fable-5-2` when the composition has an Anthropic provider (generator falls back sensibly when it does not); reviewer-a/b/c primaries are `claude-fable-5-2`/`gpt-6-astra`/`gemini-4-carbon` when the providers exist; no reviewer rung or reviewer-covering backup row on `opencode` unless the composition has no other provider; no anthropic row above high.
  - Replace all reviewer-esc assertions (pins, families, compositions) with the new expectations.
- [ ] Green: implement in `install.sh` (REQUIRED_ROLES, validator modes, generator `generate_dynamic_profile`, `--pm` flag + manifest + render + TTY prompt + usage text, retired-file removal), and rewrite all six `providers/*.md` per spec sections 1, 2, 4 (prose + tables + quota pools + backup ladders + single-provider review tables).
- [ ] `bash test/install.sh` fully green; `bash -n install.sh`; `shellcheck install.sh` if available.
- [ ] Commit.

### Task 2: Harness contracts, skills, agents, docs (implementer-deep)

**Files (owned):** `AGENTS.md`, `skills/**`, `agents/reviewer-a.md`, `agents/reviewer-b.md`, `agents/reviewer-c.md`, other `agents/*.md` prose mentioning esc/escalation, `README.md`, `docs/assets/architecture.svg`.

- [ ] `AGENTS.md`: remove reviewer-esc everywhere (role vocabulary, family independence, budget guard, backup walk, degraded council, PASS modes, review contracts, unit map, fallback mechanics); add same-model alternate, balanced seat fallback, seat distinctness, single-provider review, Anthropic effort cap, review captain and verdict modes, project-management setting, and the 15-dispatch guard, per the spec.
- [ ] `skills/council/SKILL.md`: captain flow (parallel review, ruling dispatch + output format, limits, backlog lines), modes table, round loop without escalation, single-provider review, balanced fallback.
- [ ] `skills/oneshot/SKILL.md`, `skills/land/SKILL.md` (accept `mode=captain`; file backlog tickets per `backlog_tracker`), `skills/dispatch/**`, `skills/make-ci-green/SKILL.md`: align.
- [ ] `agents/reviewer-a.md`: captain contract (ruling output format, limits). `reviewer-b/c.md`: drop esc references.
- [ ] `README.md` and `docs/assets/architecture.svg`: reflect captain council, new seats and implementers, `--pm`.
- [ ] `command grep -rn -iE 'reviewer-esc|escalation review|mode=escalation|round=esc' AGENTS.md skills agents README.md docs/assets` returns nothing (historical `docs/specs`/`docs/plans` are untouched).
- [ ] Commit.
