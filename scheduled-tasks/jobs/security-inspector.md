---
id: security-inspector
title: Security Vulnerability Inspector
version: 1
---
Find exploitable weaknesses before attackers do. Three scan areas. Run dependencies and workflows in full every run. Review critical code in full on Mondays, and on other days review what changed in the last 26 hours (`git log --since="26 hours ago"`) plus any auth code touched in that window.

### 1. Dependencies (including newly disclosed vulnerabilities)
- Detect every ecosystem in the repo (lockfiles for npm, pnpm, bun, yarn, Cargo, Go, uv, pip, Poetry, Bundler, and so on).
- Run the native audit for each one (`npm audit` / `pnpm audit` / `bun audit`, `cargo audit`, `govulncheck ./...`, `pip-audit`). Also run `osv-scanner -r .` when it is installed.
- Read open Dependabot alerts: `gh api repos/{{REPO}}/dependabot/alerts?state=open`. Ignore a 403 or 404 error.
- To catch newly disclosed vulnerabilities, cross-check direct and critical transitive dependencies against advisories published in the last 7 days (GitHub Advisory DB: `gh api "/advisories?published=>=<date-7d>&per_page=100"`; OSV). Flag any advisory that matches a version we actually resolve, even when no patched version exists yet. In that case, ticket the exposure and the mitigation.

### 2. GitHub workflows (`.github/workflows/*`, composite actions)
- Run `zizmor` and `actionlint` when they are installed. Also review by hand for:
  - `pull_request_target` or `workflow_run` jobs that check out or run PR head code;
  - script injection through `${{ github.event.* }}` / `head_ref` interpolated into `run:`;
  - third-party actions not pinned to a full commit SHA;
  - missing or overly broad `permissions:` (the token defaults to write);
  - secrets reachable from fork PRs;
  - self-hosted runners on public repos;
  - cache or artifact poisoning;
  - unpinned `curl | sh` installers.

### 3. Critical code (authentication, authorization, trust boundaries)
- Scout to locate auth and session code, middleware, route and handler registration, permission checks, crypto, and input parsing at trust boundaries.
- Look for:
  - missing or bypassable authorization on routes and handlers (IDOR, tenant isolation);
  - weak session or token handling (JWT `alg` / `exp` / `aud` checks, token storage, rotation, logout invalidation);
  - password hashing that is not argon2, bcrypt, or scrypt;
  - CSRF gaps; CORS `*` together with credentials;
  - SQL, command, path, or template injection; SSRF; open redirects;
  - unsafe deserialization;
  - secrets committed to the repo (`gitleaks detect` if installed; report location only, never the value).

### Severity and action
- **Critical or high** with a safe fix (patch or minor version bump, pin an action SHA, tighten `permissions:`, add a missing authorization check that tests cover): fix it today via oneshot.
- **Critical or high** without a safe fix: ticket with Urgent or High priority, including the mitigation.
- **Medium:** ticket.
- **Low:** list in the report only, unless it is the only finding.
- Disclosure hygiene: keep PR titles and bodies neutral (for example, `fix(deps): bump <pkg> to <ver>` or `ci: pin actions to SHAs`). Exploit details go only in the Linear ticket.
- Type label: `security`.
