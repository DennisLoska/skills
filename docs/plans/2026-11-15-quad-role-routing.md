# Shared profile role routing implementation plan

> Superseded routing history: current council policy is Opus/Sol at xhigh and Argon at high; all non-council work remains at most high. See ../skill-model-routing.md and AGENTS.md. Historical rows below are not dispatch guidance.

The user authorized the same policy across all six shipped profiles and all 15 generated provider combinations: Opus 5.5 implements,
Fable 5.2 handles deep implementation and captains review, GPT-6 Astra and
GPT-6.1 Sol complete the panel. Only these three models may review, including
task reviews, backups, and single-provider review. DeepSeek V4.1 Flash scouts.
Routine work prefers Flash models from OpenCode and Gemini.

The user additionally requires removing the retired Gemini model across the entire harness,
including all shipped profiles and dynamic generators. Every model and role has
a hard reasoning ceiling of `high`. Add an explicit global prohibition and
installer validation for role, advisory, backup, and single-provider rows.
Normalize existing above-high settings across all profiles and skill guidance.
Negative tests may name forbidden values solely to demonstrate rejection.

Keep model IDs in provider profiles and their descriptive documentation.
Keep author independence: Fable cannot captain reviews of its own changes;
an eligible GPT reviewer takes over in that case. Provider selection changes connection preference for the same model, never the canonical model policy. Both designer and planner use read-only Fable drafts with Sol fallback only; the driver owns conversation and artifact/phase gates.

- [x] Add installer/profile regression coverage and confirm intended failures.
- [x] Update all shipped/generated role ladders and every review escape path. Preserve the
      existing family checks where compatible; enforce distinct primary models.
- [x] Update affected README descriptions and document all twelve repository
      skills with the roles/models they actually use. Distinguish driver-run
      skills from explicitly dispatched seats and document fallback behavior.
- [x] Run the installer contract suite and shell syntax checks in scratch homes.
- [ ] After confirmed merge, refresh the latest merged harness on Flux and MacBook using [the scoped rollout checklist](../post-merge-rollout.md). Preserve recorded bindings, quota state and tracker settings. MacBook connection is pending; discover its checkout and roots remotely. No install from this unmerged branch.

Execution uses user-authorized Gemini 3.8 Flash for discovery/tests and
GPT-6.1 Sol for implementation while the other subscriptions are exhausted.
These temporary execution choices do not alter the requested saved roles.
