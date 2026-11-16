#!/usr/bin/env bash
# test/single-reviewer-council.sh - regression & contract tests for single-reviewer council mode.
# Validates the oneshot harness single-reviewer council contract when 1 or 2 provider instances
# remain eligible: state line format, author exclusion, green-tests gate, provider table policy,
# host payload limits, and retained normal/degraded/captain mode invariants.
set -euo pipefail
export LC_ALL=C
unset OPENCODE_CONFIG CODEX_HOME ANTIGRAVITY_CONFIG CLAUDE_CONFIG_DIR T3_USERDATA_DIR

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$ROOT/install.sh"
TMPROOT="${TMPDIR:-/tmp}/harness-single-council-test.$$"

cleanup() {
  if [ -d "$TMPROOT" ]; then
    find "$TMPROOT" -depth -delete
  fi
}
trap cleanup EXIT
mkdir -p "$TMPROOT"

passed=0
pass() { passed=$((passed + 1)); printf 'ok: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# ==============================================================================
# 1. Council SKILL.md Contract Audits
# ==============================================================================
COUNCIL_MD="$ROOT/skills/council/SKILL.md"

# 1a. Council recognizes mode=single
grep -qE 'mode=<[^>]*single[^>]*>' "$COUNCIL_MD" || grep -qF 'mode=single' "$COUNCIL_MD" || \
  fail "council SKILL.md recognizes mode=single in verdict modes"
pass "council SKILL.md recognizes mode=single"

# 1b. Gating: single reviewer permitted when 1 or 2 providers remain eligible
grep -qE '(1 or 2|one or two|[12]) provider' "$COUNCIL_MD" || \
  fail "council SKILL.md gates single mode on 1 or 2 eligible provider instances"
pass "council SKILL.md gates single mode on 1 or 2 remaining providers"

# 1c. Optional when 2 providers remain (not forced; degraded/nominal still allowed)
grep -qiE 'optional' "$COUNCIL_MD" || \
  fail "council SKILL.md documents that single mode is optional when 2 providers are available"
pass "council SKILL.md documents single mode is optional when 2 providers are eligible"

# 1d. >2 remaining providers must still use normal 2+ independent reviewers
grep -qE '(> ?2|more than 2|more than two).*(normal|2\+|two or more|nominal)' "$COUNCIL_MD" || \
  fail "council SKILL.md enforces normal 2+ independent review when >2 providers remain"
pass "council SKILL.md enforces normal 2+ review when >2 providers remain"

# 1e. 0 or unknown provider availability halts
grep -qE '(0|zero|unknown).*(stop|halt|yellow)' "$COUNCIL_MD" || \
  fail "council SKILL.md stops on 0 or unknown provider availability"
pass "council SKILL.md halts on 0 or unknown provider availability"

# 1f. PASS condition for single mode: 1 independent reviewer PASS, zero accepted unresolved, green tests
grep -qE 'single.*1.*PASS.*zero.*(unresolved|accepted).*green' "$COUNCIL_MD" || \
  grep -qE '`single`.*1 independent.*PASS.*zero unresolved accepted.*green' "$COUNCIL_MD" || \
  fail "council SKILL.md specifies single mode PASS condition (1 reviewer PASS, 0 accepted, green tests)"
pass "council SKILL.md specifies single mode PASS conditions"

# 1g. No no-tests exception for mode=single (green tests required)
grep -qE 'mode=single.*(require|no.*no-tests|green tests)' "$COUNCIL_MD" || \
  grep -qE '(mode=degraded|mode=captain|mode=single).*require.*green tests' "$COUNCIL_MD" || \
  grep -qF 'mode=nominal only' "$COUNCIL_MD" || \
  fail "council SKILL.md forbids no-tests exception for mode=single"
pass "council SKILL.md requires green tests for mode=single (no no-tests exception)"

# 1h. Canonical verdict line format with providers=<1|2> and reviewer=<provider/model>
grep -qE 'council_verdict: (PASS\|FAIL|PASS) round=<n> mode=single providers=<1\|2> reviewer=<provider/model> head=<sha>' "$COUNCIL_MD" || \
  grep -qE 'mode=single providers=<1\|2> reviewer=' "$COUNCIL_MD" || \
  fail "council SKILL.md specifies canonical verdict line for single mode"
pass "council SKILL.md documents canonical single mode verdict line format"

# 1i. No old unconditional "minimum 2 distinct non-author review models or stop" blocking single mode
if grep -qF 'Minimum 2 distinct non-author review models or stop and surface yellow.' "$COUNCIL_MD"; then
  fail "council SKILL.md has old unconditional min-2 statement blocking single mode without qualification"
fi
pass "council SKILL.md qualifies or removes unconditional min-2 review model stop"


# ==============================================================================
# 2. Land SKILL.md Contract Audits
# ==============================================================================
LAND_MD="$ROOT/skills/land/SKILL.md"

# 2a. Land parses effective last council_verdict and accepts mode=single
grep -qE 'nominal\|degraded\|captain\|single|nominal\|degraded\|single\|captain' "$LAND_MD" || \
  grep -qF 'mode=single' "$LAND_MD" || \
  fail "land SKILL.md accepts mode=single in effective last council_verdict pre-merge gate"
pass "land SKILL.md accepts mode=single in pre-merge gate"

# 2b. Land enforces head=<sha> match for single mode
grep -qF 'gh pr merge --squash --match-head-commit <sha>' "$LAND_MD" || \
  fail "land SKILL.md preserves --match-head-commit <sha>"
pass "land SKILL.md preserves match-head-commit enforcement"


# ==============================================================================
# 3. Oneshot SKILL.md Contract Audits
# ==============================================================================
ONESHOT_MD="$ROOT/skills/oneshot/SKILL.md"

# 3a. Phase 6 Council records mode=single
sed -n '/^## Phase 6: COUNCIL/,/^---$/p' "$ONESHOT_MD" | grep -qF 'mode=single' || \
  fail "oneshot SKILL.md Phase 6 recognizes mode=single"
pass "oneshot SKILL.md Phase 6 records mode=single"

# 3b. Phase 7 Finish validates mode in nominal|degraded|captain|single
sed -n '/^## Phase 7: FINISH/,/^---$/p' "$ONESHOT_MD" | grep -qE 'nominal\|degraded\|captain\|single|nominal\|degraded\|single\|captain' || \
  fail "oneshot SKILL.md Phase 7 gate accepts mode=single"
pass "oneshot SKILL.md Phase 7 validates mode=single"

# 3c. State artifact documentation includes mode=single and canonical format
sed -n '/^## State Artifact/,/^## /p' "$ONESHOT_MD" | grep -qF 'mode=single' || \
  fail "oneshot SKILL.md State Artifact documents mode=single"
pass "oneshot SKILL.md State Artifact documents mode=single"


# ==============================================================================
# 4. AGENTS.md / HARNESS.md Review Contracts
# ==============================================================================
AGENTS_MD="$ROOT/AGENTS.md"

# 4a. Review contracts accept mode=single
sed -n '/^### Review contracts/,/^## /p' "$AGENTS_MD" | grep -qE 'mode=single|nominal.*degraded.*captain.*single' || \
  fail "AGENTS.md Review contracts recognize mode=single"
pass "AGENTS.md Review contracts recognize mode=single"

# 4b. Verdict modes table documents mode=single
sed -n '/^## Council Contract/,/^## /p' "$AGENTS_MD" | grep -qE '`single`' || \
  fail "AGENTS.md Council Contract documents mode=single in verdict modes table"
pass "AGENTS.md Council Contract documents mode=single"

# 4c. Retained legacy mode gates: nominal, degraded, captain
sed -n '/^## Council Contract/,/^## /p' "$AGENTS_MD" | grep -qF '`nominal`' || fail "AGENTS.md retains nominal mode"
sed -n '/^## Council Contract/,/^## /p' "$AGENTS_MD" | grep -qF '`degraded`' || fail "AGENTS.md retains degraded mode"
sed -n '/^## Council Contract/,/^## /p' "$AGENTS_MD" | grep -qF '`captain`' || fail "AGENTS.md retains captain mode"
pass "AGENTS.md retains nominal, degraded, and captain mode gates"

# 4d. AGENTS.md stays within size cap
agents_size="$(wc -c <"$AGENTS_MD")"
[ "$agents_size" -lt 24000 ] || fail "AGENTS.md size ($agents_size bytes) exceeds 24000 limit"
pass "AGENTS.md stays within 24000 byte limit ($agents_size bytes)"


# ==============================================================================
# 5. Shipped Profiles & Single-Provider Review Table Policy
# ==============================================================================
shipped_profiles=(quad tri claude codex antigravity opencode-go)

for prof in "${shipped_profiles[@]}"; do
  prof_file="$ROOT/providers/$prof.md"
  [ -f "$prof_file" ] || fail "missing profile file $prof_file"

  # 5a. Profile has ## Single-provider review section
  grep -qF '## Single-provider review' "$prof_file" || fail "providers/$prof.md missing ## Single-provider review"

  # 5b. Single-provider review table permits Claude Code Opus (claudeAgent or claude)
  # Extract single-provider section lines
  sp_text="$(awk '/^## Single-provider review/{flag=1; next} /^## /{flag=0} flag' "$prof_file")"

  # Check if Claude Opus is in Single-provider review table
  echo "$sp_text" | grep -qE '\|[[:space:]]*(claudeAgent|claude)[[:space:]]*\|[[:space:]]*claude-opus-5-5[[:space:]]*\|' || \
    fail "providers/$prof.md Single-provider review table must permit Claude Code Opus"

  # 5c. Antigravity retains Argon and Codex retains Sol
  echo "$sp_text" | grep -qE '\|[[:space:]]*antigravity[[:space:]]*\|[[:space:]]*gemini-4-argon[[:space:]]*\|' || \
    fail "providers/$prof.md Single-provider review table missing Antigravity Argon"
  echo "$sp_text" | grep -qE '\|[[:space:]]*codex[[:space:]]*\|[[:space:]]*gpt-6.1-sol[[:space:]]*\|' || \
    fail "providers/$prof.md Single-provider review table missing Codex Sol"

  # 5d. OpenCode must NOT have review models in Single-provider review
  if echo "$sp_text" | grep -qE '\|[[:space:]]*(opencode)[[:space:]]*\|'; then
    fail "providers/$prof.md Single-provider review table must NOT contain OpenCode review models"
  fi

  # 5e. 3 Primary review seats remain distinct: Opus, Astra, Sol
  python3 - "$prof_file" <<'PYSEATS'
import sys
from pathlib import Path
rows = [[c.strip() for c in line.split('|')[1:-1]] for line in Path(sys.argv[1]).read_text().splitlines() if line.startswith('|')]
primaries = {c[0]: c[3] for c in rows if len(c) == 7 and c[1] == 'primary' and c[0].startswith('reviewer-')}
assert primaries == {'reviewer-a': 'claude-opus-5-5', 'reviewer-b': 'gpt-6.1-sol', 'reviewer-c': 'gemini-4-argon'}, primaries
assert len(set(primaries.values())) == 3
PYSEATS
done
pass "all shipped profiles satisfy single-provider review table policy (Opus/Sol/Argon permitted, OpenCode excluded, 3 distinct primary seats preserved)"


# ==============================================================================
# 6. Multi-Host Installer Target Compilation & Payload Limits
# ==============================================================================
HOST_HOME="$TMPROOT/install-host"
HOME="$HOST_HOME" "$INSTALL" --target all --pm none </dev/null >"$TMPROOT/install.out" 2>&1 || {
  cat "$TMPROOT/install.out" >&2
  fail "install.sh --target all --pm none failed"
}

# 6a. Check compiled payload presence and size limits
for check_tuple in \
  "$HOST_HOME/.codex/AGENTS.md:32768" \
  "$HOST_HOME/.claude/CLAUDE.md:32768" \
  "$HOST_HOME/.gemini/config/rules/HARNESS.md:24000" \
  "$HOST_HOME/.gemini/config/rules/PROVIDERS.md:24000" \
  "$HOST_HOME/.config/opencode/HARNESS.md:24000"; do
  file="${check_tuple%%:*}"
  cap="${check_tuple##*:}"
  [ -f "$file" ] || fail "compiled target file missing: $file"
  size="$(wc -c <"$file")"
  [ "$size" -lt "$cap" ] || fail "compiled file $file size ($size bytes) exceeds cap ($cap bytes)"
done
pass "compiled host payloads exist and stay within instruction size limits"

# 6b. Compiled contracts propagate mode=single
grep -qE 'mode=single' "$HOST_HOME/.codex/AGENTS.md" || fail "compiled .codex/AGENTS.md missing mode=single"
grep -qE 'mode=single' "$HOST_HOME/.claude/CLAUDE.md" || fail "compiled .claude/CLAUDE.md missing mode=single"
grep -qE 'mode=single' "$HOST_HOME/.gemini/config/rules/HARNESS.md" || fail "compiled .gemini/config/rules/HARNESS.md missing mode=single"
pass "compiled host contracts propagate mode=single across all target hosts"


# ==============================================================================
# 7. Canonical State Format & Gate Validation Scenarios
# ==============================================================================
# Audit real source and installed instruction contracts; no test-only verdict engine.
python3 - "$ROOT" "$HOST_HOME" <<'PYCONTRACT'
import sys
from pathlib import Path
root, home = map(Path, sys.argv[1:])
def section(text, heading):
    return text.split(heading, 1)[1].split('\n## ', 1)[0]
def require(text, *phrases):
    for phrase in phrases:
        assert phrase in text, f"missing contract: {phrase}"
canonical = 'council_verdict: PASS|FAIL round=<n> mode=single providers=<1|2> reviewer=<provider/model> head=<sha>'
council = (root / 'skills/council/SKILL.md').read_text()
require(council, canonical, 'optional when 1 or 2', 'even if more review models',
        '>2 providers use normal 2+', '0 or unknown providers', 'zero independent allowed reviewers, stop',
        'unique profile provider instance IDs', 'across ALL roles', 'quota/soft-cap/privacy/reachability',
        'not review models, families or pools', 'whose other pool is healthy', 'pool used only for non-review roles',
        'Missing, unknown or stale evidence cannot unlock single', 'If count recovers >2, rerun normal review',
        'sole reviewer is captain', 'fresh on that same captain', 'reviewer_vote: PASS|FAIL',
        'zero unresolved accepted findings and green actual checks (no no-tests exception)',
        'Exclude every author model even on another provider', 'Never introduce an excluded model',
        'max 15 real reviewer dispatches', 'max 3 review rounds', 'with 2 or 3 healthy seats')
for heading in ('## Phase 6: COUNCIL', '## Phase 7: FINISH', '## State Artifact'):
    require(section((root / 'skills/oneshot/SKILL.md').read_text(), heading), 'mode=single')
land = (root / 'skills/land/SKILL.md').read_text()
# Both active merge consumers must independently retain freshness + negative boundaries.
for block in (section(land, '## Part 2'), section(land, '## Rules')):
    require(block, 'mode=single', 'freshly recompute eligible provider IDs/count across ALL roles',
            'immediately before merge', 'council_providers:', 'council_reviewer:', 'captain:',
            'reviewer_vote: PASS', 'count 1 or 2 agreeing with verdict', 'same-head',
            'Missing, unknown or stale evidence refuses merge', '0/unknown providers',
            'count >2 requires rerun normal 2+', 'author_models exclusion', 'profile review allowlist',
            'zero unresolved accepted findings', 'green actual checks', 'no no-tests exception',
            '--match-head-commit <sha>', 'Standalone session-only evidence never unlocks single')
# Verify installed payloads, including OpenCode, and installed consumer skills.
for harness, skills in [('.codex/AGENTS.md', '.codex/skills'), ('.claude/CLAUDE.md', '.claude/skills'),
                        ('.gemini/config/rules/HARNESS.md', '.gemini/antigravity/skills'),
                        ('.config/opencode/HARNESS.md', '.config/opencode/skills')]:
    text = (home / harness).read_text()
    require(text, canonical, 'council_providers:', 'council_reviewer:',
            'reviewer_vote: PASS', 'freshly before merge', 'no no-tests exception',
            'No council seat may review code authored by the identical model.')
    require(text, '| `nominal` |', '| `degraded` |', '| `captain` |', '| `single` |',
            'Captain mode works in any round with 2 or 3 healthy seats.')
# Installer copies actual source skills; inspect every installed copy without assuming host layout.
for skill in ('council', 'oneshot', 'land'):
    copies = list(home.rglob(f'{skill}/SKILL.md'))
    assert len(copies) >= 4, (skill, copies)
    for copy in copies:
        assert copy.read_text() == (root / 'skills' / skill / 'SKILL.md').read_text(), copy
print('ok: source and all installed contracts enforce single boundaries and normal retention')
PYCONTRACT
pass "real installed contracts: provider boundaries, author exclusion, fresh heads, green checks, normal quorum"

printf '\nALL SINGLE-REVIEWER COUNCIL TESTS PASSED: %d assertions\n' "$passed"
