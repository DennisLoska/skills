# Design It Twice

**Context-scoped effort ceiling:** Non-council work, including driver sessions, defaults, advisory/design work, task-reviewer, fixing and testing, must never request or inherit effort above `high`. Only runtime council reviewer-a/b/c seats and fresh captain rulings may use profile-configured `xhigh`; council is the only skill permitting above high, with maximum `xhigh`. `max`, `ultra`, `ultrathink`, `ultracode`, and equivalent higher levels are forbidden everywhere. Verify provider capabilities before dispatch; use explicit provider-native options from `PROVIDERS.md`. Argon uses explicit `thinking_level=high` because it has no xhigh support. Unknown/unsafe defaults require an explicit safe option or an unreachable rung; non-council defaults must be verified at most `high`. Shared reviewer contracts do not grant task reviews the council exception. Invoking a skill never changes the driver session or its ceiling.

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
