#!/usr/bin/env bash
# Regression: optional ad-hoc routed roles designer and planner.
# Verifies quad profile rendering, absence of native agent files,
# legacy profile compatibility, validator rejection before writes
# (above-high effort, duplicate rung, missing primary), and
# backup ladder / reserve pool eligibility.
# All tests use scratch directories with explicit OPENCODE_CONFIG and CODEX_HOME.
set -euo pipefail
unset OPENCODE_CONFIG CODEX_HOME ANTIGRAVITY_CONFIG CLAUDE_CONFIG_DIR T3_USERDATA_DIR

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'find "$scratch" -depth -delete' EXIT

python3 - "$ROOT" "$scratch" <<'PY'
import os
from pathlib import Path
import re
import subprocess
import sys

root, scratch = map(Path, sys.argv[1:])
install_sh = root / 'install.sh'
quad_profile_path = root / 'providers/quad.md'
base_quad = quad_profile_path.read_text()

count = 0

def run_install(profile_text=None, profile_file=None, profile_name=None, target='codex', extra_args=None):
    global count
    count += 1
    home = scratch / f'home-{count}'
    opencode_dir = scratch / f'opencode-{count}'
    codex_dir = scratch / f'codex-{count}'
    home.mkdir(parents=True, exist_ok=True)

    cmd = ['bash', str(install_sh), '--target', target, '--pm', 'none']
    if profile_file is not None:
        cmd += ['--profile-file', str(profile_file)]
    elif profile_name is not None:
        cmd += ['--profile', profile_name]
    elif profile_text is not None:
        p = scratch / f'profile-{count}.md'
        p.write_text(profile_text)
        cmd += ['--profile-file', str(p)]
    else:
        raise ValueError('Must specify profile_text, profile_file, or profile_name')

    if extra_args:
        cmd += extra_args

    env = os.environ.copy()
    for key in ('OPENCODE_CONFIG', 'CODEX_HOME', 'ANTIGRAVITY_CONFIG', 'CLAUDE_CONFIG_DIR', 'T3_USERDATA_DIR'):
        env.pop(key, None)
    env['HOME'] = str(home)
    env['OPENCODE_CONFIG'] = str(opencode_dir)
    env['CODEX_HOME'] = str(codex_dir)

    res = subprocess.run(cmd, env=env, capture_output=True, text=True)
    return res, opencode_dir, codex_dir, home

# ---------------------------------------------------------------------------
# 1. Test quad profile rows rendering and no native agent files
# ---------------------------------------------------------------------------
print("Checking quad profile rendering for designer and planner...")
res, opencode_dir, codex_dir, _ = run_install(profile_name='quad', target='opencode')
assert res.returncode == 0, f"Quad install failed: {res.stderr}"

rendered_providers = (opencode_dir / 'PROVIDERS.md').read_text()

# Required quad roles for designer and planner:
# Both roles: primary claudeAgent/claude-fable-5-2 effort=high, fallback codex/gpt-6.2-sol reasoningEffort=high, and last-resort antigravity/gemini-4-neon thinking_level=high.
quad_rows = [
    r'\|\s*designer\s*\|\s*primary\s*\|\s*claudeAgent\s*\|\s*claude-fable-5-2\s*\|\s*effort=high\s*\|\s*anthropic\s*\|\s*ok\s*\|',
    r'\|\s*designer\s*\|\s*fallback\s*\|\s*codex\s*\|\s*gpt-6\.2-sol\s*\|\s*reasoningEffort=high\s*\|\s*openai\s*\|\s*ok\s*\|',
    r'\|\s*designer\s*\|\s*last-resort\s*\|\s*antigravity\s*\|\s*gemini-4-neon\s*\|\s*thinking_level=high\s*\|\s*google\s*\|\s*ok\s*\|',
    r'\|\s*planner\s*\|\s*primary\s*\|\s*claudeAgent\s*\|\s*claude-fable-5-2\s*\|\s*effort=high\s*\|\s*anthropic\s*\|\s*ok\s*\|',
    r'\|\s*planner\s*\|\s*fallback\s*\|\s*codex\s*\|\s*gpt-6\.2-sol\s*\|\s*reasoningEffort=high\s*\|\s*openai\s*\|\s*ok\s*\|',
    r'\|\s*planner\s*\|\s*last-resort\s*\|\s*antigravity\s*\|\s*gemini-4-neon\s*\|\s*thinking_level=high\s*\|\s*google\s*\|\s*ok\s*\|',
]
for pattern in quad_rows:
    assert re.search(pattern, rendered_providers), f"Missing quad row matching pattern: {pattern}"

# Ensure no other rungs exist for designer or planner (primary, fallback, and last-resort)
for role in ('designer', 'planner'):
    role_rows = [l for l in rendered_providers.splitlines() if re.match(rf'^\s*\|\s*{role}\s*\|', l)]
    assert len(role_rows) == 3, f"Expected exactly 3 rows for {role} (primary, fallback, and last-resort), got {len(role_rows)}: {role_rows}"

# Quad cannot pick up generic/cheap backup choices for these logical roles.
section = 'roles'
for line in base_quad.splitlines():
    if line.startswith('## '): section = line[3:]
    cells = [c.strip() for c in line.split('|')[1:-1]]
    if section == 'Backup ladder' and cells and cells[0].isdigit():
        assert cells[1] != '*' and not {'designer', 'planner'}.intersection(cells[1].split(',')), line
for role in ('designer', 'planner'):
    assert not (root / f'agents/{role}.md').exists()

# Ensure no native agent files are created for designer or planner
assert not (opencode_dir / 'agents/designer.md').exists(), "designer native agent file should not exist"
assert not (opencode_dir / 'agents/planner.md').exists(), "planner native agent file should not exist"
print("ok: quad profile renders designer and planner rows without native agent files")

# ---------------------------------------------------------------------------
# 2. Test legacy profiles lacking both designer and planner install unchanged
# ---------------------------------------------------------------------------
print("Checking legacy profile lacking designer and planner installs unchanged...")
res, opencode_dir, _, _ = run_install(profile_text='\n'.join(l for l in base_quad.splitlines() if not re.match(r'^\| (designer|planner) \|', l)), target='opencode')
assert res.returncode == 0, f"Legacy profile install failed: {res.stderr}"

required_9_roles = [
    'scout', 'implementer', 'implementer-deep', 'patch', 'tester',
    'reviewer-a', 'reviewer-b', 'reviewer-c', 'task-reviewer'
]
tri_providers = (opencode_dir / 'PROVIDERS.md').read_text()
for role in required_9_roles:
    assert re.search(rf'\|\s*{role}\s*\|\s*primary\s*\|', tri_providers), f"Missing required role {role} in legacy profile install"

assert not re.search(r'\|\s*designer\s*\|', tri_providers), "Legacy profile should not have designer role"
assert not re.search(r'\|\s*planner\s*\|', tri_providers), "Legacy profile should not have planner role"
print("ok: legacy profiles lacking designer and planner install unchanged with 9 required roles")

# ---------------------------------------------------------------------------
# 3. Test generic validator rejections before writes (above-high, duplicate, missing-primary)
# ---------------------------------------------------------------------------
print("Checking validator rejection before writes for designer and planner...")
# Derive clean scratch profile from quad, removing any designer/planner lines
clean_quad_lines = [
    l for l in base_quad.splitlines()
    if not re.search(r'\|\s*(designer|planner)\s*\|', l)
]
clean_quad = '\n'.join(clean_quad_lines)

# A. Reject effort above high
for role in ('designer', 'planner'):
    for effort in ('effort=xhigh', 'reasoningEffort=ultra', 'effort=max'):
        fixture = clean_quad + f"\n| {role} | primary | claudeAgent | claude-fable-5-2 | {effort} | anthropic | ok |\n"
        res, opencode_dir, codex_dir, _ = run_install(profile_text=fixture, target='codex')
        assert res.returncode != 0, f"Expected failure for {role} with {effort}, but succeeded"
        assert 'effort above high' in res.stderr, f"Expected 'effort above high' in stderr for {role} {effort}, got: {res.stderr}"
        assert not codex_dir.exists(), f"Destination directory {codex_dir} should not exist before writes"

# B. Reject duplicate rung
for role in ('designer', 'planner'):
    fixture = clean_quad + f"""
| {role} | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| {role} | primary | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
"""
    res, opencode_dir, codex_dir, _ = run_install(profile_text=fixture, target='codex')
    assert res.returncode != 0, f"Expected failure for {role} with duplicate primary rung, but succeeded"
    assert 'duplicate rung' in res.stderr, f"Expected 'duplicate rung' in stderr for {role}, got: {res.stderr}"
    assert not codex_dir.exists(), f"Destination directory {codex_dir} should not exist before writes"

# C. Reject missing primary (fallback without primary)
for role in ('designer', 'planner'):
    fixture = clean_quad + f"""
| {role} | fallback | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
"""
    res, opencode_dir, codex_dir, _ = run_install(profile_text=fixture, target='codex')
    assert res.returncode != 0, f"Expected failure for {role} missing primary, but succeeded"
    assert ('incomplete' in res.stderr or 'missing primary' in res.stderr or 'invalid' in res.stderr), \
        f"Expected missing primary diagnostic in stderr for {role}, got: {res.stderr}"
    assert not codex_dir.exists(), f"Destination directory {codex_dir} should not exist before writes"

print("ok: generic validator rejects above-high, duplicate-rung, and missing-primary before writes")

# ---------------------------------------------------------------------------
# 4. Test reserve and backup ladder role eligibility
# ---------------------------------------------------------------------------
print("Checking reserve and backup ladder role eligibility for designer and planner...")
valid_roles_fixture = clean_quad + """
| designer | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| designer | fallback | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
| planner | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
| planner | fallback | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
"""

# Backup ladder accepting narrow references to designer,planner
backup_fixture = valid_roles_fixture + """
## Backup ladder

| 9 | designer,planner | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
"""
res, opencode_dir, codex_dir, _ = run_install(profile_text=backup_fixture, target='codex')
assert res.returncode == 0, f"Expected backup ladder with designer,planner to be accepted, failed with: {res.stderr}"

# Quota pool reserve accepting narrow references to designer,planner
pool_fixture = valid_roles_fixture.replace(
    '## Quota pools\n',
    '## Quota pools\n\n| design-pool | claudeAgent | * | 5h | - | designer,planner |\n'
)
res, opencode_dir, codex_dir, _ = run_install(profile_text=pool_fixture, target='codex')
assert res.returncode == 0, f"Expected pool reserve with designer,planner to be accepted, failed with: {res.stderr}"

print("ok: backup ladder and reserve pool accept narrow designer,planner references")
# An optional role is normally validated, never treated as an advisory row.
for role in ('designer', 'planner'):
    fixture = clean_quad + f"\n| {role} | primary | - | - | - | - | ok |\n"
    result, _, dest, _ = run_install(profile_text=fixture)
    assert result.returncode == 1 and 'invalid provider' in result.stderr, result.stderr
    assert not dest.exists()
# The static four-provider selection must carry the same optional assignments.
# Use --providers instead of --profile, avoiding conflicting selection flags.
home = scratch / 'combo-home'
home.mkdir()
env = os.environ.copy()
for key in ('OPENCODE_CONFIG', 'CODEX_HOME', 'ANTIGRAVITY_CONFIG', 'CLAUDE_CONFIG_DIR', 'T3_USERDATA_DIR'):
    env.pop(key, None)
env['HOME'] = str(home)
combo = subprocess.run(['bash', str(install_sh), '--target', 'codex', '--pm', 'none',
                        '--providers', 'antigravity,codex,opencode,claude'],
                       env=env, capture_output=True, text=True)
assert combo.returncode == 0, combo.stderr
combo_profile = (home / '.codex/PROVIDERS.md').read_text()
for pattern in quad_rows:
    assert re.search(pattern, combo_profile), pattern
# Exercise installed handoffs, not just source prose. Both host layouts receive
# the same canonical adapter and owning skills without native draft seats.
print("Checking installed draft handoffs and legacy required roles...")
res, _, codex_dir, _ = run_install(profile_name='quad', target='codex')
assert res.returncode == 0, res.stderr
for role in ('designer', 'planner'):
    assert not (codex_dir / f'agents/{role}.md').exists()
for skill, role in [('shape', 'designer'), ('plan', 'planner'),
                    ('codebase-design', 'designer'), ('domain-modeling', 'designer')]:
    text = (codex_dir / f'skills/{skill}/SKILL.md').read_text()
    assert '## Profile-driven draft handoff' in text, skill
    assert f'for `{role}` from the active `PROVIDERS.md`' in text, skill
    assert 'Draft Delegation Adapter' in text and '../dispatch/SKILL.md' in text, skill
    assert 'Worker recursion guard' in text and 'read-only draft directly' in text, skill
    assert 'No repository edits, commits, execution, child delegation' in text, skill
    assert 'legacy driver path' in text and 'canonical docs' in text, skill
adapter = (codex_dir / 'skills/dispatch/SKILL.md').read_text()
for required in ('role: design', 'target.providerInstanceId', 'target.model', 'target.options',
                 'Rung: <provider>/<model> (<effort>)', 'no `Role contract:`',
                 'OpenCode general task', 'Claude general-purpose', 'Codex `spawn_agent`',
                 'explicitly name this role', '`*` generic backups',
                 'stop with the role', 'does not enter code `author_models`'):
    assert required in adapter, required
oneshot = (codex_dir / 'skills/oneshot/SKILL.md').read_text()
assert 'Invoke the `shape` skill exactly once' in oneshot
assert 'shape alone delegates' in oneshot and 'Plan alone delegates' in oneshot
assert 'does not separately dispatch a designer' in oneshot
assert 'does not separately dispatch a planner' in oneshot
alternatives = (codex_dir / 'skills/codebase-design/DESIGN-IT-TWICE.md').read_text()
for required in ('When `designer` is configured', 'When `designer` is absent',
                 'never `*` or implementation-role fallback', 'degraded design: N families',
                 'no edits, commits, children or recursive skill invocation'):
    assert required in alternatives, required
source = install_sh.read_text()
required = re.search(r"^REQUIRED_ROLES='([^']+)'", source, re.M).group(1).split()
assert required == required_9_roles, required
# Missing original required roles must still fail even with optional roles.
for role in required_9_roles:
    fixture = '\n'.join(line for line in base_quad.splitlines()
                        if not re.match(rf'^\| {role} \|', line))
    result, _, dest, _ = run_install(profile_text=fixture)
    assert result.returncode == 1 and f'incomplete: {role}' in result.stderr, role
    assert not dest.exists(), role
# Explicit optional references are validated in backup mode (including effort).
for role in ('designer', 'planner'):
    fixture = valid_roles_fixture + f"\n## Backup ladder\n| 9 | {role} | codex | gpt-6.2-sol | reasoningEffort=xhigh | openai | ok |\n"
    result, _, dest, _ = run_install(profile_text=fixture)
    assert result.returncode == 1 and 'effort above high' in result.stderr, result.stderr
    assert not dest.exists()
print("ok: installed handoffs, worker guards, native adapters and unchanged required nine")
print(f"ALL DESIGNER/PLANNER ROUTING TESTS PASSED: {count + 1} installer cases, 5 check groups")
PY
