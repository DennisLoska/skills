---
name: domain-modeling
description: Use when discussing codebase terminology, writing or editing GLOSSARY.md, recording or editing an ADR, keeping ubiquitous language consistent, naming a concept, or resolving overloaded terms.
---

# Domain Modeling

**Universal high effort ceiling:** Never request or inherit reasoning above `high` for any model, provider, role, driver session, advisory/design work, review, fallback, or ad-hoc call. No exceptions or effort escalation: `xhigh`, `max`, `ultra`, `ultrathink`, `ultracode`, and equivalent levels are forbidden. Use explicit provider options at `low`, `medium`, or `high`; use `-`/an omitted option only after verifying the effective default is at most `high`. Otherwise set `high` explicitly or mark the rung unreachable. Switching to a deeper seat never raises this ceiling. Models come from the active provider profile (`PROVIDERS.md`); invoking a skill does not switch the driver session.

## Profile-driven draft handoff

**Worker recursion guard:** If already executing a `designer` or `planner` draft brief, perform only the scoped read-only draft directly and return draft text + decisions. No repository edits, commits, execution, child delegation or recursive skill invocation; skip this skill's driver gates and downstream handoffs.

Before substantive domain-model, glossary or ADR drafting, the driver reads `../dispatch/SKILL.md` **Draft Delegation Adapter** and executes its procedure for `designer` from the active `PROVIDERS.md`. This is mandatory delegation when the role exists, not an advisory recommendation or a session switch. Ask the worker for canonical terms, considered alternatives, concrete scenarios, relationships and proposed glossary/ADR text in the referenced formats. Supply the relevant context and constraints; do not delegate conversation or the workflow. When the role is absent, retain this skill's existing legacy driver path.

The driver reads/applies the returned draft against canonical docs and owns conversation, approvals, artifact edits/commits, self-review and phase advancement. Under shape, domain/module guidance can be included in the same designer brief; do not dispatch a second worker for the same draft. A new substantive design question may use a separate scoped draft. In design-it-twice, the alternatives are the design draft dispatches, not an extra duplicate draft.


Actively build and sharpen the project's domain model as you design. Challenge terms, invent edge-case scenarios, and write the glossary and decisions down the moment they crystallize.

**Not this skill:** merely reading `GLOSSARY.md` for vocabulary. Any skill can do that in one line. This skill applies when you are changing the model, not just consuming it.

## File layout

Single context (most repos):

```
/
├── GLOSSARY.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

Multiple contexts: a root `GLOSSARY-MAP.md` points at one `GLOSSARY.md` per context, with context-specific ADRs beside each (`src/ordering/GLOSSARY.md`, `src/ordering/docs/adr/`).

```
/
├── GLOSSARY-MAP.md                 <- contexts and relationships
├── docs/adr/                       <- system-wide decisions
└── src/
    ├── ordering/
    │   ├── GLOSSARY.md
    │   └── docs/adr/               <- context-specific decisions
    └── billing/
        ├── GLOSSARY.md
        └── docs/adr/
```

Create files lazily: no `GLOSSARY.md` yet, create it when the first term is resolved. No `docs/adr/` yet, create it when the first ADR is needed. If `GLOSSARY-MAP.md` exists, read it first to find which context the current topic belongs to; if unclear, ask.

## Auto-approve

When `auto-approve: true` is set, do not ask the user to resolve a term. Pick the strongest term, record the rejected alternatives considered when the term was chosen under `_Considered_` (per [GLOSSARY-FORMAT.md](./GLOSSARY-FORMAT.md)), and note the decision in the spec Assumptions.

## The five in-session moves

1. **Challenge against the glossary.** User language conflicts with `GLOSSARY.md`, call it out now: "Your glossary defines X this way, but you seem to mean Y. Which is it?"
2. **Sharpen fuzzy language.** Vague or overloaded term, propose one canonical term: "You say 'account': do you mean Customer or User? Those differ."
3. **Discuss concrete scenarios.** Stress-test relationships with invented edge cases that force precise boundaries between concepts.
4. **Cross-reference with code.** User claims X, code does Y, surface it: "Code cancels whole Orders, but you said partial cancellation works. Which is right?"
5. **Update the glossary inline.** Term resolved, write it immediately. Never batch. Follow [GLOSSARY-FORMAT.md](./GLOSSARY-FORMAT.md).

## The glossary-only rule

`GLOSSARY.md` is a glossary and nothing else. No implementation details, no spec, no scratch pad, no decision records. Decisions live in ADRs.

Concretely: a term entry holds a definition and rejected synonyms, never behavior, never config, never "we chose X because Y". The moment an entry starts justifying, split the justification into an ADR and leave the definition behind.

## Offer ADRs sparingly

Offer an ADR only when all three hold:

1. **Hard to reverse:** changing your mind later costs real effort.
2. **Surprising without context:** a future reader will ask "why is it done this way?"
3. **A real trade-off:** genuine alternatives existed and you picked one for reasons.

Any one missing, skip the ADR. Format: [ADR-FORMAT.md](./ADR-FORMAT.md).

Adapted from mattpocock/skills (MIT).
