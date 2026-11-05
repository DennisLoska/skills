# GLOSSARY.md Format

## Structure

```md
# {Context Name}

{One or two sentences: what this context is and why it exists.}

## Language

**Order**:
{One or two sentence definition of the term.}
_Avoid_: Purchase, transaction
_Considered_: {Optional: rejected alternatives considered when the term was chosen}

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request
```

## Rules

- **Be opinionated.** One term per concept. List rejected synonyms under `_Avoid_`, and rejected alternatives considered when the term was chosen under `_Considered_`.
- **Keep definitions tight.** One or two sentences. Say what it IS, not what it does.
- **No general programming concepts.** Timeouts, error types, utility patterns do not belong, however heavily used. Ask: is this unique to this context? Only then include it.
- **Group under subheadings** when clusters emerge. Flat list is fine for one cohesive area.

## Single versus multi-context

- **Single context:** one `GLOSSARY.md` at the repo root.
- **Multiple contexts:** root `GLOSSARY-MAP.md` lists each context, where its glossary lives, and how contexts relate (events emitted, shared IDs). Infer the active context from the map; if unclear, ask (auto-approve: choose and record).
- **Neither exists:** create root `GLOSSARY.md` lazily at the first resolved term.

Adapted from mattpocock/skills (MIT).
