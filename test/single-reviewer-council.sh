#!/usr/bin/env bash
# test/single-reviewer-council.sh - regression & contract tests for single-reviewer council mode.
# Validates single-reviewer and unavailable council contracts in all runs:
# state line format, self-review, green-tests gate, provider table policy,
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

# Single review now depends on member availability, not provider counts.
python3 - "$COUNCIL_MD" <<'PYCHECK'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
for phrase in ('One available reviewer may PASS regardless of provider count',
               'inside or outside oneshot', 'Self-review is allowed',
               'reviewer_vote: PASS|FAIL reviewer=<provider/model> head=<sha>',
               'council_verdict: SKIPPED round=<n> mode=unavailable head=<sha>',
               'zero unresolved accepted findings and green actual checks (no no-tests exception)'):
    assert phrase in s, phrase
assert 'council_providers:' not in s
assert 'providers=<1|2>' not in s
PYCHECK
pass "single review and zero-member SKIPPED retain votes, checks and head binding without provider gates"

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

  # 5c. Antigravity retains Neon and Codex retains Sol
  echo "$sp_text" | grep -qE '\|[[:space:]]*antigravity[[:space:]]*\|[[:space:]]*gemini-4-neon[[:space:]]*\|' || \
    fail "providers/$prof.md Single-provider review table missing Antigravity Neon"
  echo "$sp_text" | grep -qE '\|[[:space:]]*codex[[:space:]]*\|[[:space:]]*gpt-6.2-sol[[:space:]]*\|' || \
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
assert primaries == {'reviewer-a': 'claude-opus-5-5', 'reviewer-b': 'gpt-6.2-sol', 'reviewer-c': 'gemini-4-neon'}, primaries
assert len(set(primaries.values())) == 3
PYSEATS
done
pass "all shipped profiles satisfy single-provider review table policy (Opus/Sol/Neon permitted, OpenCode excluded, 3 distinct primary seats preserved)"


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
canonical = 'council_verdict: PASS|FAIL round=<n> mode=single reviewer=<provider/model> head=<sha>'
for rel in ('AGENTS.md', 'skills/council/SKILL.md', 'skills/oneshot/SKILL.md'):
    text = (root / rel).read_text()
    require(text, canonical, 'council_verdict: SKIPPED round=<n> mode=unavailable head=<sha>',
            'council_member:', 'head=<sha>')
    assert 'council_providers:' not in text, rel
    assert 'author model conflict' not in text, rel
# Audit every operative review prompt/profile as well as installed consumers.
operative = [root / 'AGENTS.md', root / 'README.md', root / 'docs/skill-model-routing.md']
operative += list((root / 'skills').rglob('*.md')) + list((root / 'providers').glob('*.md'))
for path in operative:
    text = path.read_text()
    for obsolete in ('author model conflict', 'Exclude every author model',
                     'No council seat may review code authored by the identical model',
                     'degraded task-review: single-family host', 'council_providers:',
                     'providers=<1|2>', 'audited oneshot single',
                     'outside audited oneshot', 'Resolve author exclusions'):
        assert obsolete not in text, (path, obsolete)
land = (root / 'skills/land/SKILL.md').read_text()
require(land, 'effective last', 'council_verdict: PASS', 'council_verdict: SKIPPED',
        'mode=unavailable', 'green actual checks', 'zero unresolved accepted findings',
        'same-head available reviewer votes/rulings', '--match-head-commit <sha>',
        'Actual review FAIL', 'stale/missing evidence', 'unrecognized verdict/mode combinations')
for harness in ('.codex/AGENTS.md', '.claude/CLAUDE.md', '.gemini/config/rules/HARNESS.md',
                '.config/opencode/HARNESS.md'):
    text = (home / harness).read_text()
    require(text, canonical, 'council_member:', 'council_verdict: SKIPPED',
            'green actual verification', 'The same model may author and review.')
    require(text, '| `nominal` |', '| `degraded` |', '| `captain` |', '| `single` |')
# Installer copies actual source skills; inspect every installed copy without assuming host layout.
for skill in ('council', 'oneshot', 'land'):
    copies = list(home.rglob(f'{skill}/SKILL.md'))
    assert len(copies) >= 4, (skill, copies)
    for copy in copies:
        assert copy.read_text() == (root / 'skills' / skill / 'SKILL.md').read_text(), copy
print('ok: source and all installed contracts enforce single boundaries and normal retention')
PYCONTRACT
pass "real installed contracts: availability, self-review, fresh heads, green checks and retained modes"

printf '\nALL SINGLE-REVIEWER COUNCIL TESTS PASSED: %d assertions\n' "$passed"
