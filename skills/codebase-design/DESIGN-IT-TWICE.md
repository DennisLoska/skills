# Design It Twice

**Universal high effort ceiling:** Never request or inherit reasoning above `high` for any model, provider, role, driver session, advisory/design work, review, fallback, or ad-hoc call. No exceptions or effort escalation: `xhigh`, `max`, `ultra`, `ultrathink`, `ultracode`, and equivalent levels are forbidden. Use explicit provider options at `low`, `medium`, or `high`; use `-`/an omitted option only after verifying the effective default is at most `high`. Otherwise set `high` explicitly or mark the rung unreachable. Switching to a deeper seat never raises this ceiling. Models come from the active provider profile (`PROVIDERS.md`); invoking a skill does not switch the driver session.

First ideas are rarely best. Draft several interfaces in parallel, then compare and pick. Uses the [SKILL.md](./SKILL.md) vocabulary plus the project `GLOSSARY.md` for naming.

## 1. Frame the problem space

Write a user-facing brief first: constraints any interface must satisfy, dependency categories per [DEEPENING.md](./DEEPENING.md), and one rough sketch to make constraints concrete (a sketch, not a proposal). Show it, then proceed while the user reads.

## 2. Dispatch distinct design alternatives

**Worker recursion guard:** a designer/planner worker drafts its assigned alternative directly and returns; no edits, commits, children or recursive skill invocation. The driver alone compares and applies results.

Read `../dispatch/SKILL.md` Draft Delegation Adapter and load canonical `HARNESS.md`/`PROVIDERS.md` using its bootstrap paths (`../_harness/HARNESS.md` and `../_harness/PROVIDERS.md`, or `../../HARNESS.md` and `../../PROVIDERS.md`, relative to this skill directory). When `designer` is configured, use only its rungs and explicitly named backups, never `*` or implementation-role fallback. Dispatch alternatives on distinct reachable families through the Dispatch Adapter, logical role `designer`, T3 `role: design`, with `Rung:` only and the read-only draft contract. Do not add a separate generic designer draft before these alternatives. Try 3+ alternatives where distinct families permit; with fewer, run the available distinct-family alternatives and announce `degraded design: N families`. Zero eligible rungs stops; never inherit the driver model.

When `designer` is absent, preserve the legacy path: general-purpose read-only alternatives on `implementer-deep` rungs first, then `implementer` rungs across distinct families, never implementation seat agents. Apply privacy, quota/ladder and universal at-most-high effort rules in both paths. Supply paths, coupling, dependency categories and what hides behind the Seam, plus one differing constraint each:

- Agent 1: minimize the interface, 1 to 3 entry points max, max leverage each.
- Agent 2: maximize flexibility, many use cases and extension.
- Agent 3: optimize for the most common caller, trivial default case.
- Agent 4 (if cross-seam deps): design around ports and adapters.

Each returns: interface (types, methods, params, invariants, errors), a caller usage example, what hides behind the seam, dependency strategy and adapters, and where leverage is high or thin.

## 3. Compare and recommend

Present designs sequentially, then contrast by **depth** (leverage at the interface), **locality** (where change concentrates), and **seam placement**. End with an opinionated recommendation, hybrids allowed. Give a read, not a menu.

Adapted from mattpocock/skills (MIT).
