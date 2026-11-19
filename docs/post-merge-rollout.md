# This PR: post-merge harness rollout

This checklist applies only to this repository's role-policy PR and the user's request to update Flux and MacBook. It does not change the generic landing workflow. No installation may use the unmerged branch. Opening the PR does not authorize bypassing council or automatically merging it.

## Merge and source gate (each host)

- [ ] Confirm the PR is merged and record its URL and merge SHA from the remote service.
- [ ] Discover the checkout, remote and default branch. On Flux the checkout is `/home/dennis/work/skills`; discover the MacBook path through the linked T3 environment, never guess it.
- [ ] Require a clean checkout, including untracked files. If user work exists, stop that host's rollout; never reset or stash it.
- [ ] Fetch the remote, check out the default branch, and update with fast-forward only. Confirm the fetched default branch and local checkout contain the merge SHA (`git merge-base --is-ancestor <merge-sha> HEAD`) and record the exact revision. Stop on divergence or a missing merge.

## Discover and preserve installation bindings

- [ ] Flux currently has five installed roots bound to `quad` and Linear. Discover all five manifest paths and confirm the recorded profile/PM metadata before proceeding; include the T3 Antigravity instance root. Use actual environment overrides and recorded paths, not assumed defaults.
- [ ] MacBook's T3 connection card has already been requested and is pending. Resume through the linked environment when connected; do not request another card. Discover its checkout, installed targets, environment overrides, manifests, profile bindings, and tracker remotely. Never infer them from Flux.
- [ ] Record every root's manifest revision and binding (`# profile`, `# profile-file`, or `# providers`, plus `# pm`), custom files and state paths. Resolve the shared quota ledger and record its SHA-256 hash without changing its contents.
- [ ] Run installer verification/doctor against the discovered installed targets before refresh. Resolve failures without removing user work or changing bindings.

## Refresh and verify

- [ ] From the confirmed merged default-branch revision, run the installer with `--force` against the recorded installed target set and actual overrides. Omit profile/provider/PM overrides so each root reuses its recorded binding. Do not add new targets, prune custom content, use sudo, request secrets, or replace a custom profile with a shipped one.
- [ ] Run `--verify` and `--doctor` for those same roots. Verify host instruction limits, generated model tables, native pins and delegate-only seats, designer/planner Fable→Sol→Carbon ladders, closed review routes, at-most-high effort, and the absence of retired routes (with Carbon allowed only on `designer`/`planner` `last-resort`).
- [ ] Confirm all recorded profile/provider/PM bindings and custom state/files survived. Confirm the resolved quota ledger SHA-256 hash is unchanged, including on shared/symlinked state paths.
- [ ] Record the source revision and installed manifest revision per host/root, merge SHA, verification results, ledger hash comparison and any blocked host. Do not claim MacBook updated until remote evidence confirms it.

## Rollout receipt

| Host | Checkout / installed roots | Merge SHA | Installed revision | Binding / PM preserved | Verify / doctor | Ledger hash unchanged |
| --- | --- | --- | --- | --- | --- | --- |
| Flux | `/home/dennis/work/skills`; discover five recorded roots | pending merge | pending | quad / Linear, confirm per root | pending | pending |
| MacBook | pending T3 link; discover remotely | pending merge | pending | discover remotely | pending | pending |
