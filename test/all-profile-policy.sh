#!/usr/bin/env bash
# Regression: policy enforcement across all oneshot profiles.
# Audits 6 shipped profiles (providers/*.md) and installer output for all
# 15 nonempty dynamic --providers combinations rendered into scratch config roots.
# Enforces exact named primary policy, strict review allowlist, and ceiling rules.
set -euo pipefail
unset OPENCODE_CONFIG CODEX_HOME ANTIGRAVITY_CONFIG CLAUDE_CONFIG_DIR T3_USERDATA_DIR

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'find "$scratch" -depth -delete' EXIT

python3 - "$ROOT" "$scratch" <<'PY'
import itertools
import os
from pathlib import Path
import subprocess
import sys

root, scratch = map(Path, sys.argv[1:])
install_sh = root / 'install.sh'

ALLOWED_REVIEW_MODELS = {'claude-opus-5-5', 'gpt-6.2-sol', 'gemini-4-neon'}
TASK_MODELS = {'claude-fable-5-2', 'gpt-6.2-astra', 'gpt-6.2-sol'}
CODEX_MODELS = {'gpt-6.2-sol', 'gpt-6.2-astra', 'gpt-6-luna'}
REVIEW_ROLES = {'reviewer-a', 'reviewer-b', 'reviewer-c'}
VALID_EFFORT_LEVELS = {'none', 'minimal', 'low', 'medium', 'high'}

def parse_markdown_tables(text):
    """
    Structural parser for profile markdown files.
    Tracks sections and parses markdown tables, ignoring prose, headings,
    header lines, and column dividers.
    """
    section = 'roles'
    roles_table = []
    backup_ladder = []
    single_provider_review = []
    all_rows = []

    for line in text.splitlines():
        line_str = line.strip()
        if line_str.startswith('## '):
            section = line_str[3:].strip()
            continue
        if not line_str.startswith('|') or not line_str.endswith('|'):
            continue
        cells = [c.strip() for c in line_str.split('|')[1:-1]]
        if not cells:
            continue
        # Skip header rows and markdown table divider rows
        if cells[0] in ('role', 'provider', 'pool', 'order', '---') or all(c.startswith('---') or c == '' for c in cells):
            continue

        if (section in ('Role distribution', 'roles') or section.lower().startswith('role') or
            (len(cells) == 7 and cells[1] in ('primary', 'fallback', 'last-resort'))) and cells[0] not in ('order', 'pool'):
            if len(cells) >= 7:
                row = {
                    'role': cells[0],
                    'rung': cells[1],
                    'provider': cells[2],
                    'model': cells[3],
                    'base_model': cells[3].split('/')[-1],
                    'effort': cells[4],
                    'family': cells[5],
                    'privacy': cells[6],
                    'section': section,
                    'line': line_str,
                }
                roles_table.append(row)
                all_rows.append(row)
        elif section == 'Backup ladder' or (len(cells) == 7 and cells[0].isdigit()):
            row = {
                'order': cells[0],
                'roles': [x.strip() for x in cells[1].split(',')],
                'roles_raw': cells[1],
                'provider': cells[2],
                'model': cells[3],
                'base_model': cells[3].split('/')[-1],
                'effort': cells[4],
                'family': cells[5],
                'privacy': cells[6],
                'section': section,
                'line': line_str,
            }
            backup_ladder.append(row)
            all_rows.append(row)
        elif section == 'Single-provider review' or (len(cells) == 5 and section.lower().startswith('single-provider')):
            row = {
                'provider': cells[0],
                'model': cells[1],
                'base_model': cells[1].split('/')[-1],
                'effort': cells[2],
                'family': cells[3],
                'privacy': cells[4],
                'section': section,
                'line': line_str,
            }
            single_provider_review.append(row)
            all_rows.append(row)

    return {
        'roles_table': roles_table,
        'backup_ladder': backup_ladder,
        'single_provider_review': single_provider_review,
        'all_rows': all_rows,
    }

def validate_profile_policy(name, text):
    """
    Enforces the universal role routing and model policy across all profiles.
    """
    tables = parse_markdown_tables(text)
    roles_table = tables['roles_table']
    backup_ladder = tables['backup_ladder']
    single_provider_review = tables['single_provider_review']
    all_rows = tables['all_rows']

    def get_role_rows(role_name):
        return [r for r in roles_table if r['role'] == role_name]

    # 0. Advisory driver ladder: Neon high -> Sol high -> Fable high
    driver_rows = get_role_rows('driver')
    assert [r['rung'] for r in driver_rows] == ['primary', 'fallback', 'last-resort'], (
        f"[{name}] driver must have primary, fallback, and last-resort rungs, got {[r['rung'] for r in driver_rows]}"
    )
    assert (driver_rows[0]['provider'], driver_rows[0]['base_model'], driver_rows[0]['effort']) == ('antigravity', 'gemini-4-neon', 'thinking_level=high'), driver_rows[0]['line']
    assert (driver_rows[1]['provider'], driver_rows[1]['base_model'], driver_rows[1]['effort']) == ('codex', 'gpt-6.2-sol', 'reasoningEffort=high'), driver_rows[1]['line']
    assert (driver_rows[2]['provider'], driver_rows[2]['base_model'], driver_rows[2]['effort']) == ('claudeAgent', 'claude-fable-5-2', 'effort=high'), driver_rows[2]['line']

    # 1. Primary implementer: Gemini 4 Neon
    imp_primary = [r for r in get_role_rows('implementer') if r['rung'] == 'primary']
    assert imp_primary, f"[{name}] missing primary implementer row"
    assert imp_primary[0]['provider'] == 'antigravity' and imp_primary[0]['base_model'] == 'gemini-4-neon', (
        f"[{name}] implementer primary must be antigravity/gemini-4-neon, got {imp_primary[0]['provider']}/{imp_primary[0]['model']}"
    )

    # 2. Deep implementer: Fable 5.2
    deep_primary = [r for r in get_role_rows('implementer-deep') if r['rung'] == 'primary']
    assert deep_primary, f"[{name}] missing primary implementer-deep row"
    assert deep_primary[0]['base_model'] == 'claude-fable-5-2', (
        f"[{name}] implementer-deep primary must be claude-fable-5-2, got {deep_primary[0]['model']}"
    )

    # Structural guard: forbid gemini-4-hydrogen across all implementation/direct deep rungs
    for r in roles_table:
        if r['role'] == 'task-reviewer': assert r['base_model'] in TASK_MODELS
        if r['role'] in ('implementer', 'implementer-deep'):
            assert r['base_model'] != 'gemini-4-hydrogen' and 'gemini-4-hydrogen' not in r['model'], (
                f"[{name}] implementation role {r['role']} (rung {r['rung']}) has forbidden model gemini-4-hydrogen: {r['line']}"
            )

    # Explicit deep fallback Sol check and Neon last-resort retention
    deep_fallback = [r for r in get_role_rows('implementer-deep') if r['rung'] == 'fallback']
    assert deep_fallback, f"[{name}] missing fallback implementer-deep row"
    assert deep_fallback[0]['base_model'] == 'gpt-6.2-sol', (
        f"[{name}] implementer-deep fallback must be gpt-6.2-sol, got {deep_fallback[0]['model']}"
    )

    deep_last = [r for r in get_role_rows('implementer-deep') if r['rung'] in ('last-resort', 'final')]
    if deep_last:
        assert deep_last[0]['base_model'] == 'gemini-4-neon', (
            f"[{name}] implementer-deep final must be gemini-4-neon, got {deep_last[0]['model']}"
        )

    imp_fallback = [r for r in get_role_rows('implementer') if r['rung'] == 'fallback']
    if imp_fallback:
        assert imp_fallback[0]['base_model'] == 'claude-opus-5-5', (
            f"[{name}] implementer fallback must be claude-opus-5-5, got {imp_fallback[0]['model']}"
        )

    imp_last = [r for r in get_role_rows('implementer') if r['rung'] in ('last-resort', 'final')]
    if imp_last:
        assert imp_last[0]['base_model'] == 'gpt-6.2-sol', (
            f"[{name}] implementer final must be gpt-6.2-sol, got {imp_last[0]['model']}"
        )

    # 3. Shipped policy requires both draft roles; custom legacy profiles are tested separately.
    # New test script should not assume all profiles lack optional roles.
    for opt_role in ('designer', 'planner'):
        opt_rows = get_role_rows(opt_role)
        assert opt_rows, f"[{name}] missing {opt_role}"
        if opt_rows:
            rungs = [r['rung'] for r in opt_rows]
            assert rungs == ['primary', 'fallback', 'last-resort'], (
                f"[{name}] {opt_role} must have primary, fallback, and last-resort rungs, got {rungs}"
            )
            assert opt_rows[0]['base_model'] == 'claude-fable-5-2', (
                f"[{name}] {opt_role} primary must be claude-fable-5-2, got {opt_rows[0]['model']}"
            )
            assert opt_rows[1]['base_model'] == 'gpt-6.2-sol', (
                f"[{name}] {opt_role} fallback must be gpt-6.2-sol, got {opt_rows[1]['model']}"
            )
            assert opt_rows[2]['base_model'] == 'gemini-4-neon', (
                f"[{name}] {opt_role} last-resort must be gemini-4-neon, got {opt_rows[2]['model']}"
            )
            assert opt_rows[2]['effort'] == 'thinking_level=high', (
                f"[{name}] {opt_role} last-resort effort must be thinking_level=high, got {opt_rows[2]['effort']}"
            )

    # 4. Scout: DeepSeek 4.1 Flash
    scout_primary = [r for r in get_role_rows('scout') if r['rung'] == 'primary']
    assert scout_primary, f"[{name}] missing primary scout row"
    assert 'deepseek-v4.1-flash' in scout_primary[0]['base_model'], (
        f"[{name}] scout primary must be DeepSeek 4.1 Flash, got {scout_primary[0]['model']}"
    )

    # 5. Tester and patch: fast DeepSeek Flash preferred
    for role in ('tester', 'patch'):
        p = [r for r in get_role_rows(role) if r['rung'] == 'primary']
        assert p, f"[{name}] missing primary {role} row"
        assert 'deepseek-v4.1-flash' in p[0]['base_model'], (
            f"[{name}] {role} primary must be DeepSeek 4.1 Flash, got {p[0]['model']}"
        )

    # 6. Council seats: A Opus captain, B Sol, C Neon; each council model distinct
    a_primary = [r for r in get_role_rows('reviewer-a') if r['rung'] == 'primary']
    b_primary = [r for r in get_role_rows('reviewer-b') if r['rung'] == 'primary']
    c_primary = [r for r in get_role_rows('reviewer-c') if r['rung'] == 'primary']
    assert a_primary, f"[{name}] missing primary reviewer-a row"
    assert b_primary, f"[{name}] missing primary reviewer-b row"
    assert c_primary, f"[{name}] missing primary reviewer-c row"

    assert a_primary[0]['base_model'] == 'claude-opus-5-5', (
        f"[{name}] reviewer-a primary captain must be claude-opus-5-5, got {a_primary[0]['model']}"
    )
    assert b_primary[0]['base_model'] == 'gpt-6.2-sol', (
        f"[{name}] reviewer-b primary must be gpt-6.2-sol, got {b_primary[0]['model']}"
    )
    assert c_primary[0]['base_model'] == 'gemini-4-neon', (
        f"[{name}] reviewer-c primary must be gemini-4-neon, got {c_primary[0]['model']}"
    )

    council_models = {
        a_primary[0]['base_model'],
        b_primary[0]['base_model'],
        c_primary[0]['base_model'],
    }
    assert len(council_models) == 3, (
        f"[{name}] council primary models must be distinct, got {council_models}"
    )

    # 7. Task reviewer: Sol primary
    task_rev_primary = [r for r in get_role_rows('task-reviewer') if r['rung'] == 'primary']
    assert task_rev_primary, f"[{name}] missing primary task-reviewer row"
    assert task_rev_primary[0]['base_model'] == 'gpt-6.2-sol', (
        f"[{name}] task-reviewer primary must be gpt-6.2-sol, got {task_rev_primary[0]['model']}"
    )

    # 8. Council rungs/backups/single-provider strictly Opus/Sol/Neon; task review stays separate
    # No wildcard or mixed backups giving excluded review models
    for r in roles_table:
        if r['role'] == 'task-reviewer': assert r['base_model'] in TASK_MODELS
        if r['role'] in REVIEW_ROLES:
            assert r['base_model'] in ALLOWED_REVIEW_MODELS, (
                f"[{name}] review role {r['role']} (rung {r['rung']}) has disallowed model: {r['model']}"
            )

    for row in backup_ladder:
        roles = row['roles']
        if roles == ['task-reviewer']: assert row['base_model'] in TASK_MODELS, row['line']
        has_review = any(r in REVIEW_ROLES for r in roles)
        if '*' in roles:
            assert not has_review, f"[{name}] wildcard backup ladder contains review: {row['line']}"
        if has_review:
            non_review = [r for r in roles if r not in REVIEW_ROLES]
            assert not non_review, (
                f"[{name}] backup ladder mixes review and non-review roles ({non_review}): {row['line']}"
            )
            assert row['base_model'] in ALLOWED_REVIEW_MODELS, (
                f"[{name}] backup ladder review role has disallowed model: {row['line']}"
            )
        # designer/planner must not appear in wildcards or mixed backups
        if '*' in roles or any(r in ('designer', 'planner') for r in roles):
            assert '*' not in roles, f"[{name}] wildcard backup ladder contains designer/planner: {row['line']}"
            if any(r in ('designer', 'planner') for r in roles):
                other = [r for r in roles if r not in ('designer', 'planner')]
                assert not other, (
                    f"[{name}] backup ladder mixes designer/planner with other roles: {row['line']}"
                )

        # Forbid gemini-4-hydrogen in wildcard or implementation-matching backup rows
        if '*' in roles or any(r in ('implementer', 'implementer-deep') for r in roles):
            assert row['base_model'] != 'gemini-4-hydrogen' and 'gemini-4-hydrogen' not in row['model'], (
                f"[{name}] implementation/wildcard backup ladder row has forbidden model gemini-4-hydrogen: {row['line']}"
            )

    # Exact closed recovery set, including the sole Claude reviewer.
    assert {(r['provider'], r['base_model']) for r in single_provider_review} == {
        ('claudeAgent', 'claude-opus-5-5'), ('antigravity', 'gemini-4-neon'),
        ('codex', 'gpt-6.2-sol')}, f"[{name}] incorrect single-provider recovery set"
    compaction = get_role_rows('compaction')
    assert compaction[0]['base_model'] == 'gemini-4-hydrogen' and compaction[0]['effort'].endswith('=low')
    for role in ('scout', 'tester', 'patch'):
        rows = get_role_rows(role)
        assert [r['base_model'] for r in rows] == ['deepseek-v4.1-flash', 'gpt-6-luna', 'gemini-4-hydrogen']
    # 9. Safe efforts <= high everywhere; no Carbon or Gemini 3.8 Flash; council Neon uses xhigh
    for row in all_rows:
        assert row['base_model'] not in ('gemini-4-carbon', 'gemini-3.8-flash'), (
            f"[{name}] retired model {row['base_model']} forbidden in shipped profiles: {row['line']}"
        )
        if row['provider'] == 'codex':
            assert row['base_model'] in CODEX_MODELS, (
                f"[{name}] codex rung must use a current OpenAI model {sorted(CODEX_MODELS)}: {row['line']}"
            )
        eff = row['effort']
        if eff != '-':
            val = eff.split('=', 1)[-1] if '=' in eff else eff
            council = (row.get('role') in REVIEW_ROLES or (row.get('roles') and set(row['roles']) <= REVIEW_ROLES) or row['section'] in ('Single-provider review', 'single'))
            if council:
                assert (row['provider'], row['base_model'], eff) in {('claudeAgent', 'claude-opus-5-5', 'effort=xhigh'), ('codex', 'gpt-6.2-sol', 'reasoningEffort=xhigh'), ('antigravity', 'gemini-4-neon', 'thinking_level=xhigh')}, row['line']
            assert council or val in VALID_EFFORT_LEVELS, (
                f"[{name}] invalid effort level '{val}' in: {row['line']}"
            )

    # 10. All OpenCode routes only fast Flash models
    for row in all_rows:
        if row['provider'] == 'opencode':
            bm = row['base_model'].lower()
            assert 'flash' in bm, (
                f"[{name}] opencode route must be fast flash model, got: {row['line']}"
            )
            assert 'pro' not in bm and '72b' not in bm and 'r1' not in bm and 'spark' not in bm, (
                f"[{name}] opencode route has pro/nonflash/large model: {row['line']}"
            )

# Audit every self-contained shipped policy before exercising generated bindings.
shipped_order = ['quad.md', 'tri.md', 'antigravity.md', 'claude.md', 'codex.md', 'opencode-go.md']
for profile_name in shipped_order:
    profile_path = root / 'providers' / profile_name
    print(f"Auditing shipped profile {profile_name}...")
    validate_profile_policy(profile_name, profile_path.read_text())
    print(f"ok: {profile_name} satisfies policy")

# Audit all 15 nonempty --providers combinations
print("Auditing all 15 dynamic --providers combinations in scratch config roots...")
base_providers = ['antigravity', 'claude', 'codex', 'opencode']
combos = []
for r in range(1, 5):
    for combo in itertools.combinations(base_providers, r):
        combos.append(','.join(combo))

dyn_count = 0
for combo in combos:
    dyn_count += 1
    home = scratch / f'dyn-{dyn_count}'
    opencode_dir = home / 'opencode'
    home.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for k in ('OPENCODE_CONFIG', 'CODEX_HOME', 'ANTIGRAVITY_CONFIG', 'CLAUDE_CONFIG_DIR', 'T3_USERDATA_DIR'):
        env.pop(k, None)
    env['HOME'] = str(home)
    env['OPENCODE_CONFIG'] = str(opencode_dir)
    res = subprocess.run(
        ['bash', str(install_sh), '--target', 'all', '--providers', combo, '--pm', 'none'],
        env=env, capture_output=True, text=True
    )
    assert res.returncode == 0, f"Installer failed for --providers {combo}: {res.stderr}"
    rendered_providers = (opencode_dir / 'PROVIDERS.md').read_text()
    validate_profile_policy(f"dyn:{combo}", rendered_providers)
    primary = next(r for r in parse_markdown_tables(rendered_providers)['roles_table']
                   if r['role'] == 'implementer' and r['rung'] == 'primary')
    expected_path = 'antigravity'
    assert primary['provider'] == expected_path, f"selection ignored: {combo}"
    manifest = opencode_dir / '.harness-manifest'
    assert f'# providers {combo}' in manifest.read_text()
    for args in (['--force'], ['--doctor']):
        check = subprocess.run(['bash', str(install_sh), '--target', 'all'] + args,
                               env=env, capture_output=True, text=True)
        assert check.returncode == 0, f"{combo} {args}: {check.stdout} {check.stderr}"
    assert rendered_providers == (opencode_dir / 'PROVIDERS.md').read_text(), f"refresh changed {combo}"
    for path, cap in ((home / '.codex/AGENTS.md', 32768), (home / '.claude/CLAUDE.md', 32768),
                      (home / '.gemini/config/rules/HARNESS.md', 24000),
                      (home / '.gemini/config/rules/PROVIDERS.md', 24000)):
        assert path.stat().st_size < cap, str(path)
    print(f"ok: dynamic profile --providers {combo}: policy, preference, refresh, doctor, host caps")

print("ALL PROFILES SATISFY UNIVERSAL POLICY AUDIT: 6 shipped, 15 generated, 30 all-host install/refresh runs, 15 doctor runs")
PY
