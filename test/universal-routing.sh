#!/usr/bin/env bash
# Regression: universal effort ceiling and quad review eligibility.
# All installs use throwaway HOME/config roots.
set -euo pipefail
unset OPENCODE_CONFIG CODEX_HOME ANTIGRAVITY_CONFIG CLAUDE_CONFIG_DIR T3_USERDATA_DIR
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'find "$scratch" -depth -delete' EXIT
mkdir "$scratch/home"
sed 's/reasoningEffort=high/reasoningEffort=xhigh/g' "$ROOT/providers/codex.md" > "$scratch/unsafe.md"
if HOME="$scratch/home" bash "$ROOT/install.sh" --target codex --profile-file "$scratch/unsafe.md" --pm none >"$scratch/out" 2>"$scratch/err"; then
  echo 'FAIL: unsafe GPT effort accepted' >&2; exit 1
fi
rg -q 'effort above high' "$scratch/err"
[ ! -e "$scratch/home/.codex" ]
echo 'ok: unsafe GPT effort rejected before writes'

# Exercise every validator table, valid lower levels, model independence, and
# generated configurations without using the account's real HOME/config.
python3 - "$ROOT" "$scratch" <<'PY'
import os
from pathlib import Path
import subprocess
import sys
root, scratch = map(Path, sys.argv[1:])
base = (root / 'providers/quad.md').read_text()
count = 0

def invoke(text, expected, diagnostic=''):
    global count
    count += 1
    assert text != base or expected == 0, 'negative fixture did not change its source'
    profile = scratch / f'case-{count}.md'
    home = scratch / f'home-{count}'
    home.mkdir()
    profile.write_text(text)
    env = os.environ.copy()
    for key in ('OPENCODE_CONFIG', 'CODEX_HOME', 'ANTIGRAVITY_CONFIG', 'CLAUDE_CONFIG_DIR', 'T3_USERDATA_DIR'):
        env.pop(key, None)
    env['HOME'] = str(home)
    result = subprocess.run(['bash', str(root / 'install.sh'), '--target', 'codex', '--profile-file', str(profile), '--pm', 'none'], env=env, capture_output=True, text=True)
    assert result.returncode == expected, (count, result.returncode, result.stderr)
    if diagnostic:
        assert diagnostic in result.stderr, (count, result.stderr)
    if expected:
        assert not (home / '.codex').exists(), count

for effort in ('xhigh', 'max', 'ultra', 'ultrathink', 'ultracode', 'unknown'):
    diagnostic = 'invalid effort' if effort == 'unknown' else 'effort above high'
    for role in ('driver', 'compaction', 'tester'):
        lines = base.splitlines()
        for i, line in enumerate(lines):
            if line.startswith(f'| {role} | primary |'):
                cells = [c.strip() for c in line.split('|')[1:-1]]
                cells[4] = 'reasoningEffort=' + effort
                lines[i] = '| ' + ' | '.join(cells) + ' |'
        invoke('\n'.join(lines), 1, diagnostic)
    invoke(base.replace('| 1 | implementer | claudeAgent | claude-opus-5-5 | effort=high |', f'| 1 | implementer | claudeAgent | claude-opus-5-5 | effort={effort} |'), 1, diagnostic)
    invoke(base.replace('| codex | gpt-6-astra | reasoningEffort=high |', f'| codex | gpt-6-astra | reasoningEffort={effort} |'), 1, diagnostic)
for effort in ('-', 'reasoningEffort=none', 'reasoningEffort=minimal', 'reasoningEffort=low', 'reasoningEffort=medium', 'reasoningEffort=high'):
    invoke(base.replace('| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium |', f'| driver | primary | codex | gpt-6.1-sol | {effort} |'), 0)
invoke(base.replace('| reviewer-c | primary | codex | gpt-6.1-sol |', '| reviewer-c | primary | codex | gpt-6-astra |'), 1, 'share primary model gpt-6-astra')
# The preferred captain can be an implementation model in a profile; runtime
# author exclusions must instead choose independent reviewers and a GPT captain.
invoke(base.replace('| implementer | primary | antigravity | claude-opus-5-5 | thinking_level=high |', '| implementer | primary | claudeAgent | claude-fable-5-2 | effort=high |'), 0)
allowed = {'gpt-6.1-sol', 'gpt-6-astra', 'claude-fable-5-2'}
section = 'roles'
for line in base.splitlines():
    if line.startswith('## '): section = line[3:]
    cells = [c.strip() for c in line.split('|')[1:-1]]
    if not cells: continue
    if section == 'Backup ladder' and cells[0].isdigit():
        if cells[1] == '*' or any(r.startswith('reviewer-') or r == 'task-reviewer' for r in cells[1].split(',')):
            assert cells[3] in allowed, line
    elif section == 'Single-provider review' and cells[0] not in ('provider', '---'):
        assert cells[0] == 'codex' and cells[1] in {'gpt-6-astra', 'gpt-6.1-sol'}, line
    elif len(cells) == 7 and cells[0] in ('task-reviewer', 'reviewer-a', 'reviewer-b', 'reviewer-c'):
        assert cells[3] in allowed, line
# Audit configured rows rather than forbidden-level prose or negative fixtures.
profiles = sorted((root / 'providers').glob('*.md'))
for profile in profiles:
    section = 'roles'
    for line in profile.read_text().splitlines():
        if line.startswith('## '): section = line[3:]
        cells = [c.strip() for c in line.split('|')[1:-1]]
        if not cells: continue
        if section == 'Backup ladder' and cells[0].isdigit():
            model, effort = cells[3:5]
        elif section == 'Single-provider review' and cells[0] not in ('provider', '---'):
            model, effort = cells[1:3]
        elif len(cells) == 7 and cells[1] in ('primary', 'fallback', 'last-resort'):
            model, effort = cells[3:5]
        else:
            continue
        assert model != 'gemini-4-carbon' and not model.endswith('/gemini-4-carbon'), (profile, line)
        assert effort == '-' or effort.split('=', 1)[-1] in {'none', 'minimal', 'low', 'medium', 'high'}, (profile, line)
print(f'ok: {count} installer validation cases and quad review route audit')
print(f'ok: {len(profiles)} shipped profiles audited for configured effort and retired models')
PY
