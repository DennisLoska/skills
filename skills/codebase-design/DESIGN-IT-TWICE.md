# Design It Twice

First ideas are rarely best. Draft several interfaces in parallel, then compare and pick. Uses the [SKILL.md](./SKILL.md) vocabulary plus the project `GLOSSARY.md` for naming.

## 1. Frame the problem space

Write a user-facing brief first: constraints any interface must satisfy, dependency categories per [DEEPENING.md](./DEEPENING.md), and one rough sketch to make constraints concrete (a sketch, not a proposal). Show it, then proceed while the user reads.

## 2. Spawn 3+ fresh subagents in parallel

Dispatch each alternative through the AGENTS.md Dispatch Adapter (Design alternatives: general-purpose subagent with an explicit `model` natively, never the `implementer-deep` seat agent; delegate role `design`) on distinct-family rungs from the active provider profile (`PROVIDERS.md`): `implementer-deep` rungs first, then `implementer` rungs, privacy gate applying (never an inherited main-session model). With fewer distinct reachable families than alternatives, run what is available and announce `degraded design: N families`. The brief is read-only (no edits, no commits). Give each one technical brief (paths, coupling, dependency category, what hides behind the seam), one differing design constraint each:

- Agent 1: minimize the interface, 1 to 3 entry points max, max leverage each.
- Agent 2: maximize flexibility, many use cases and extension.
- Agent 3: optimize for the most common caller, trivial default case.
- Agent 4 (if cross-seam deps): design around ports and adapters.

Each returns: interface (types, methods, params, invariants, errors), a caller usage example, what hides behind the seam, dependency strategy and adapters, and where leverage is high or thin.

## 3. Compare and recommend

Present designs sequentially, then contrast by **depth** (leverage at the interface), **locality** (where change concentrates), and **seam placement**. End with an opinionated recommendation, hybrids allowed. Give a read, not a menu.

Adapted from mattpocock/skills (MIT).
