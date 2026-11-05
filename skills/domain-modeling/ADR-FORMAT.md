# ADR Format

ADRs live in `docs/adr/`, numbered sequentially: `0001-slug.md`, `0002-slug.md`. Create the directory lazily, only when the first ADR is needed.

## Template

```md
# {Short title of the decision}

{One to three sentences: context, decision, reason.}
```

One paragraph can be a complete ADR. Record THAT a decision was made and WHY, not sections.

## Optional sections

Add only when they carry value. Most ADRs need none of these:

- **Status:** `proposed | accepted | deprecated | superseded by ADR-NNNN`, when decisions get revisited.
- **Considered Options:** when rejected alternatives are worth remembering.
- **Consequences:** when non-obvious downstream effects need calling out.

## Numbering

Scan `docs/adr/` for the highest number, increment by one.

## What qualifies

All three must hold: hard to reverse, surprising without context, a real trade-off. Then the topic is usually one of:

- **Architectural shape:** monorepo, event-sourced write model with projected reads.
- **Integration patterns:** contexts talk via domain events, not sync HTTP.
- **Lock-in technology choices:** database, bus, auth, deploy target. Not every library, only what takes a quarter to swap.
- **Boundary and scope:** who owns what, by ID reference only. Explicit no-s matter as much as yes-s.
- **Deliberate deviations:** where a reasonable reader would assume the opposite, so nobody "fixes" it later.
- **Invisible constraints:** compliance bans, latency contracts the code cannot show.
- **Non-obvious rejections:** alternatives that will be re-suggested in six months if unrecorded.

Adapted from mattpocock/skills (MIT).
