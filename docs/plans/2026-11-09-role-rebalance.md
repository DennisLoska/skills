# Plan: role rebalance and profile parameterization

Spec: `docs/specs/2026-11-09-role-rebalance-design.md`. Branch `feat/provider-decoupling`.

## Task A: red tests (tester seat)

Files: `test/install.sh`, `test/fixtures/**`. Write failing cases for every spec success criterion that the current `install.sh` does not satisfy. Confirm they fail for the right reason. Do not commit.

## Task B: harness, profiles, docs (implementer)

Files: `agents/implementer-b.md` (delete), `agents/tester.md` (new, permissions copied from `agents/implementer.md`), `agents/implementer.md` (contract update), `providers/tri.md`, `providers/opencode-go.md`, `AGENTS.md`, `skills/**`, `README.md`, the first spec (mirror changes).

## Task C: installer green (implementer)

Files: `install.sh` (+ `test/install.sh` only for fixes to clear test bugs). Make Task A green: the required role set, `--profile-file`, and manifest `# profile-file`. Runs after A and B.

## Then

Commit per task. Council on `12c346e..HEAD`: seat A `opencode-go/kimi-k3.1-pro`, seat B `claude-sonnet-5-5`, seat C `gpt-6.1-sol`. Fix rounds, then update PR #6.
