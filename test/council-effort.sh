#!/usr/bin/env bash
# Regression: xhigh is reserved for council review routing only.
set -euo pipefail
unset OPENCODE_CONFIG CODEX_HOME ANTIGRAVITY_CONFIG CLAUDE_CONFIG_DIR T3_USERDATA_DIR

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'find "$scratch" -depth -delete' EXIT

python3 - "$ROOT" "$scratch" <<'PY'
import os
from pathlib import Path
import subprocess
import sys

root, scratch = map(Path, sys.argv[1:])
install_sh = root / 'install.sh'
quad = (root / 'providers/quad.md').read_text()
count = 0

def run(profile):
    global count
    count += 1
    home = scratch / f'home-{count}'
    opencode = scratch / f'opencode-{count}'
    codex = scratch / f'codex-{count}'
    profile_path = scratch / f'profile-{count}.md'
    profile_path.write_text(profile)
    env = os.environ.copy()
    for key in ('OPENCODE_CONFIG', 'CODEX_HOME', 'ANTIGRAVITY_CONFIG', 'CLAUDE_CONFIG_DIR', 'T3_USERDATA_DIR'):
        env.pop(key, None)
    env.update(HOME=str(home), OPENCODE_CONFIG=str(opencode), CODEX_HOME=str(codex))
    result = subprocess.run(
        ['bash', str(install_sh), '--target', 'codex', '--pm', 'none', '--profile-file', str(profile_path)],
        env=env, capture_output=True, text=True)
    return result, codex

def replace_effort(profile, role, rung, value):
    old = f'| {role} | {rung} |'
    lines = profile.splitlines()
    matches = [i for i, line in enumerate(lines) if line.startswith(old)]
    assert len(matches) == 1, (role, rung, matches)
    i = matches[0]
    cells = [part.strip() for part in lines[i].strip('|').split('|')]
    cells[4] = value
    lines[i] = '| ' + ' | '.join(cells) + ' |'
    return '\n'.join(lines) + '\n'

def expect_ok(profile, label):
    result, _ = run(profile)
    assert result.returncode == 0, f'{label}: expected accepted profile, got {result.stderr}'

def expect_rejected(profile, label):
    result, codex = run(profile)
    assert result.returncode != 0, f'{label}: expected rejection'
    assert 'effort above high' in result.stderr, f'{label}: unexpected diagnostic: {result.stderr}'
    assert not codex.exists(), f'{label}: installer wrote destination before validation'

# Council seat rungs may use xhigh; per-task review remains an ordinary role.
for role in ('reviewer-a', 'reviewer-b', 'reviewer-c'):
    expect_ok(replace_effort(quad, role, 'primary', 'effort=xhigh'), f'{role} primary')

# Exclusively council reviewer backup rows may use xhigh.
review_backup = quad + '\n## Backup ladder\n| 9 | reviewer-a,reviewer-b,reviewer-c | codex | gpt-6.1-sol | reasoningEffort=xhigh | openai | ok |\n'
expect_ok(review_backup, 'reviewer-only backup')

# Single-provider review rows are also council-only.
single_review = quad
assert '| claudeAgent | claude-opus-5-5 | effort=xhigh | anthropic | ok |' in single_review
expect_ok(single_review, 'single-provider review row')

# Ordinary roles, task-reviewer, driver/advisory roles and non-exclusive backups reject xhigh.
for role in ('scout', 'implementer', 'implementer-deep', 'tester', 'patch', 'task-reviewer', 'driver', 'designer', 'planner'):
    if role in ('driver',):
        line = '| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |'
        fixture = quad.replace(line, line.replace('reasoningEffort=medium', 'reasoningEffort=xhigh'), 1)
    elif role in ('designer', 'planner'):
        fixture = replace_effort(quad, role, 'primary', 'effort=xhigh')
    else:
        fixture = replace_effort(quad, role, 'primary', 'effort=xhigh')
    expect_rejected(fixture, f'{role} primary')

for roles in ('*', 'reviewer-a,scout', 'reviewer-a,task-reviewer'):
    fixture = quad + f'\n## Backup ladder\n| 9 | {roles} | codex | gpt-6.1-sol | reasoningEffort=xhigh | openai | ok |\n'
    expect_rejected(fixture, f'{roles} backup')

# Nothing above xhigh is usable in any profile context.
for effort in ('effort=max', 'effort=ultra', 'effort=ultrathink', 'effort=ultracode', 'reasoningEffort=max'):
    for context, fixture in (
        ('council seat', replace_effort(quad, 'reviewer-a', 'primary', effort)),
        ('task reviewer', replace_effort(quad, 'task-reviewer', 'primary', effort)),
        ('review backup', quad + f'\n## Backup ladder\n| 9 | reviewer-a,reviewer-b,reviewer-c | codex | gpt-6.1-sol | {effort} | openai | ok |\n'),
        ('single-provider review', quad.replace(
            '| claudeAgent | claude-opus-5-5 | effort=xhigh | anthropic | ok |',
            f'| claudeAgent | claude-opus-5-5 | {effort} | anthropic | ok |', 1)),
    ):
        expect_rejected(fixture, f'{effort} in {context}')

print('ok: council-only xhigh accepted; ordinary and above-xhigh efforts rejected')
PY
