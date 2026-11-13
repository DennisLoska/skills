---
id: codestyle-inspector
title: Codestyle Inspector
version: 1
---
Keep the codebase coherent: one way to do each thing. This job covers pattern drift, not lint noise. Lint and format failures belong to the garbage-collector job.

### 1. Establish the norms
Read, in this order:
1. `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `GLOSSARY.md`, ADRs (`docs/adr`, `docs/decisions`), and the linter and formatter configs;
2. the dominant pattern in the codebase for each concern.

A documented convention beats the dominant pattern.

### 2. Detect drift
Prioritize code changed in the last 7 days (`git log --since="7 days ago" --name-only`), compared against the established norm. Then sample the rest of the codebase. Look for competing patterns that solve the same concern:
- error handling (throw vs. result types, swallowed errors);
- data fetching and HTTP clients;
- state management;
- logging;
- config and environment access;
- validation and schemas;
- dependency injection;
- module and folder layout;
- naming (files, types, functions, domain terms versus `GLOSSARY.md`);
- import style;
- test style (framework, fixtures, naming, placement);
- async style;
- styling approach in UI code.

Flag drift only when at least 2 competing patterns exist for the same concern, or when a documented convention is violated. Report no subjective preferences and no bikeshedding.

### 3. Act
- **Convergence that fits one oneshot run** (about 10 files or fewer, mechanical, test-covered): fix it via oneshot by moving the outliers to the canonical pattern.
- **Larger migrations:** ticket that names the canonical pattern (with an exemplar at `path:line`), lists every offender, and proposes an incremental plan.
- Where a lint rule could enforce the convention, include the rule in the fix or the ticket so the drift cannot recur.
- If a needed convention is undocumented, the fix or ticket also adds it to `AGENTS.md` or `GLOSSARY.md`.
- Type label: `codestyle`.
