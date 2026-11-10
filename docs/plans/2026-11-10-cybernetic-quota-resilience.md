# Cybernetic Quota Resilience & Majority-Provider Outage Tolerance - Implementation Plan

Status: in-progress.
Spec: [docs/specs/2026-11-10-cybernetic-quota-resilience-design.md](../specs/2026-11-10-cybernetic-quota-resilience-design.md)

## Tasks

- [x] Task 1: Update `AGENTS.md` and skill instructions (`skills/council/SKILL.md`, `skills/dispatch/SKILL.md`)
  - Add `opencode-go` pool convention and provider-wide limit pattern recognition
  - Enhance task-reviewer author-independence fallback when non-author families are exhausted
  - Formalize adaptive dual-family council consensus (2/2 unanimous PASS) and model-level author independence when all healthy families are in the author set
- [x] Task 2: Update provider profiles (`providers/tri.md`, `providers/quad.md`, `providers/opencode-go.md`)
  - Add `opencode-go` quota pool to `tri.md` and `quad.md`
  - Enhance `## Backup ladder` in `tri.md` and `quad.md` with balanced Google and Anthropic representation
- [x] Task 3: Update `install.sh` profile generator (`generate_dynamic_profile`)
  - Emit `opencode-go` quota pool whenever `opencode` is enabled
  - Enforce cross-family partitioning for council seats in 2-provider profiles (e.g. `antigravity,claude`)
  - Populate backup ladder with comprehensive provider coverage
- [x] Task 4: Test suite verification
  - Add tests in `test/install.sh` for `opencode-go` pool, dynamic profile seat family independence, and backup coverage
  - Execute `./test/install.sh` and ensure 100% pass rate
- [/] Task 5: Live baseline council review
  - Run the Review Council on `feat/cybernetic-quota-resilience` with Codex and OpenCode down
  - Confirm graceful degradation and consensus PASS
- [ ] Task 6: Merge to master, pull master, and install
  - Push branch, merge PR to master, pull latest master
  - Install locally on flux (`./install.sh --force --target all`) and verify health
