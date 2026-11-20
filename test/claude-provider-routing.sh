#!/usr/bin/env bash
# Regression: Claude provider routing, operational ladders, backup ladder pruning,
# and terminal last-resort contract semantics.
# Audits:
#  - 6 shipped profiles (providers/*.md)
#  - 15 generated dynamic --providers combinations rendered via install.sh
#  - Real provider-neutral instruction contracts (AGENTS.md) and rendered host payloads
set -euo pipefail
unset OPENCODE_CONFIG CODEX_HOME ANTIGRAVITY_CONFIG CLAUDE_CONFIG_DIR T3_USERDATA_DIR

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'find "$scratch" -depth -delete' EXIT

python3 - "$ROOT" "$scratch" <<'PY'
import itertools
import os
from pathlib import Path
import re
import subprocess
import sys

root, scratch = map(Path, sys.argv[1:])
install_sh = root / 'install.sh'

OPERATIONAL_ROLES = {'implementer', 'implementer-deep', 'scout', 'tester', 'patch'}
REVIEW_ROLES = {'reviewer-a', 'reviewer-b', 'reviewer-c'}
ALLOWED_REVIEW_MODELS = {'claude-opus-5-5', 'gpt-6.2-sol', 'gemini-4-neon'}
TASK_MODELS = {'claude-fable-5-2', 'gpt-6.2-astra', 'gpt-6.2-sol'}
VALID_EFFORT_LEVELS = {'none', 'minimal', 'low', 'medium', 'high'}
FORBIDDEN_MODELS = {'gemini-4-carbon', 'gemini-4-hydrogen'}

def parse_markdown_tables(text):
    """
    Parse profile markdown tables into structured dicts:
    roles_table, pools_table, backup_ladder, single_provider_review, all_rows.
    """
    section = 'roles'
    roles_table = []
    pools_table = []
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
        if cells[0] in ('role', 'provider', 'pool', 'order', '---') or all(c.startswith('---') or c == '' for c in cells):
            continue

        if section in ('Role distribution', 'roles') or section.lower().startswith('role') or (len(cells) == 7 and cells[1] in ('primary', 'fallback', 'last-resort')):
            if len(cells) >= 7 and cells[0] not in ('order', 'pool'):
                row = {
                    'role': cells[0],
                    'rung': cells[1],
                    'provider': cells[2],
                    'model': cells[3],
                    'base_model': cells[3].split('/')[-1],
                    'effort': cells[4],
                    'family': cells[5],
                    'privacy': cells[6],
                    'section': 'roles',
                    'line': line_str,
                }
                roles_table.append(row)
                all_rows.append(row)
        elif section in ('Quota pools', 'pools') or (len(cells) == 6 and cells[0] not in ('order', 'role') and cells[3].endswith(('h', 'd', 'w', 'mo'))):
            row = {
                'pool': cells[0],
                'provider': cells[1],
                'models': cells[2],
                'window': cells[3],
                'soft_cap': cells[4],
                'reserve': cells[5],
                'section': 'pools',
                'line': line_str,
            }
            pools_table.append(row)
        elif section in ('Backup ladder', 'backups') or (len(cells) == 7 and cells[0].isdigit()):
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
                'section': 'backups',
                'line': line_str,
            }
            backup_ladder.append(row)
            all_rows.append(row)
        elif section in ('Single-provider review', 'single') or (len(cells) == 5 and section.lower().startswith('single')):
            row = {
                'provider': cells[0],
                'model': cells[1],
                'base_model': cells[1].split('/')[-1],
                'effort': cells[2],
                'family': cells[3],
                'privacy': cells[4],
                'section': 'single',
                'line': line_str,
            }
            single_provider_review.append(row)
            all_rows.append(row)

    return {
        'roles_table': roles_table,
        'pools_table': pools_table,
        'backup_ladder': backup_ladder,
        'single_provider_review': single_provider_review,
        'all_rows': all_rows,
    }

def audit_profile_policy(name, text):
    """
    Enforce requested policy on a profile markdown:
    1. implementer: antigravity/gemini-4-neon thinking_level=high -> claudeAgent/claude-opus-5-5 effort=high -> codex/gpt-6.2-sol reasoningEffort=high
    2. deep: claudeAgent/claude-fable-5-2 high -> Sol high -> Neon high
    3. scout/tester/patch: DeepSeek high -> codex/Luna (low scout, medium tester+patch) -> antigravity/Gemini3.8Flash (low scout, medium tester+patch)
    4. Antigravity purity: no Anthropic-family or Claude model routes or Claude quota pools through Antigravity
    5. Backup ladder: no operational rows (scout/tester/patch/implementer/deep or wildcard); retain review-only rows
    6. Exact unchanged policy: council models Opus/Sol/Neon, designer+planner Fable->Sol, non-council effort <= high, council-only xhigh, no Carbon/Hydrogen
    """
    tables = parse_markdown_tables(text)
    roles = tables['roles_table']
    pools = tables['pools_table']
    backups = tables['backup_ladder']
    single_reviews = tables['single_provider_review']
    all_rows = tables['all_rows']

    errors = []
    def check(cond, msg):
        if not cond:
            errors.append(msg)

    def get_role_rung(role_name, rung_name):
        matches = [r for r in roles if r['role'] == role_name and r['rung'] == rung_name]
        if not matches:
            errors.append(f"[{name}] missing {role_name} {rung_name} row")
            return None
        return matches[0]

    # 1. Implementer ladder: antigravity/Neon -> claudeAgent/Opus 5.5 -> codex/Sol
    imp_primary = get_role_rung('implementer', 'primary')
    if imp_primary:
        check(imp_primary['provider'] == 'antigravity', f"[{name}] implementer primary provider must be antigravity, got {imp_primary['provider']}")
        check(imp_primary['base_model'] == 'gemini-4-neon', f"[{name}] implementer primary model must be gemini-4-neon, got {imp_primary['model']}")
        check(imp_primary['effort'] == 'thinking_level=high', f"[{name}] implementer primary effort must be high, got {imp_primary['effort']}")
        check(imp_primary['family'] == 'google', f"[{name}] implementer primary family must be google, got {imp_primary['family']}")

    imp_fallback = get_role_rung('implementer', 'fallback')
    if imp_fallback:
        check(imp_fallback['provider'] == 'claudeAgent', f"[{name}] implementer fallback provider must be claudeAgent, got {imp_fallback['provider']}")
        check(imp_fallback['base_model'] == 'claude-opus-5-5', f"[{name}] implementer fallback model must be claude-opus-5-5, got {imp_fallback['model']}")
        check(imp_fallback['effort'] == 'effort=high', f"[{name}] implementer fallback effort must be high, got {imp_fallback['effort']}")
        check(imp_fallback['family'] == 'anthropic', f"[{name}] implementer fallback family must be anthropic, got {imp_fallback['family']}")

    imp_last = get_role_rung('implementer', 'last-resort')
    if imp_last:
        check(imp_last['provider'] == 'codex', f"[{name}] implementer last-resort provider must be codex, got {imp_last['provider']}")
        check(imp_last['base_model'] == 'gpt-6.2-sol', f"[{name}] implementer last-resort model must be gpt-6.2-sol, got {imp_last['model']}")
        check(imp_last['effort'] == 'reasoningEffort=high', f"[{name}] implementer last-resort effort must be high, got {imp_last['effort']}")
        check(imp_last['family'] == 'openai', f"[{name}] implementer last-resort family must be openai, got {imp_last['family']}")

    # 2. Implementer-deep ladder: claudeAgent/Fable 5.2 -> codex/Sol -> antigravity/Neon
    deep_primary = get_role_rung('implementer-deep', 'primary')
    if deep_primary:
        check(deep_primary['provider'] == 'claudeAgent', f"[{name}] implementer-deep primary provider must be claudeAgent, got {deep_primary['provider']}")
        check(deep_primary['base_model'] == 'claude-fable-5-2', f"[{name}] implementer-deep primary model must be claude-fable-5-2, got {deep_primary['model']}")
        check(deep_primary['effort'] == 'effort=high', f"[{name}] implementer-deep primary effort must be high, got {deep_primary['effort']}")
        check(deep_primary['family'] == 'anthropic', f"[{name}] implementer-deep primary family must be anthropic, got {deep_primary['family']}")

    deep_fallback = get_role_rung('implementer-deep', 'fallback')
    if deep_fallback:
        check(deep_fallback['provider'] == 'codex', f"[{name}] implementer-deep fallback provider must be codex, got {deep_fallback['provider']}")
        check(deep_fallback['base_model'] == 'gpt-6.2-sol', f"[{name}] implementer-deep fallback model must be gpt-6.2-sol, got {deep_fallback['model']}")
        check(deep_fallback['effort'] == 'reasoningEffort=high', f"[{name}] implementer-deep fallback effort must be high, got {deep_fallback['effort']}")
        check(deep_fallback['family'] == 'openai', f"[{name}] implementer-deep fallback family must be openai, got {deep_fallback['family']}")

    deep_last = get_role_rung('implementer-deep', 'last-resort')
    if deep_last:
        check(deep_last['provider'] == 'antigravity', f"[{name}] implementer-deep last-resort provider must be antigravity, got {deep_last['provider']}")
        check(deep_last['base_model'] == 'gemini-4-neon', f"[{name}] implementer-deep last-resort model must be gemini-4-neon, got {deep_last['model']}")
        check(deep_last['effort'] == 'thinking_level=high', f"[{name}] implementer-deep last-resort effort must be high, got {deep_last['effort']}")
        check(deep_last['family'] == 'google', f"[{name}] implementer-deep last-resort family must be google, got {deep_last['family']}")

    # 3. Scout / tester / patch ladders: DeepSeek high -> codex/Luna -> antigravity/Gemini Flash
    for role in ('scout', 'tester', 'patch'):
        p = get_role_rung(role, 'primary')
        if p:
            check(p['provider'] == 'opencode', f"[{name}] {role} primary provider must be opencode, got {p['provider']}")
            check('deepseek-v4.1-flash' in p['base_model'], f"[{name}] {role} primary model must be deepseek-v4.1-flash, got {p['model']}")
            check(p['effort'] == 'variant=high', f"[{name}] {role} primary effort must be high, got {p['effort']}")
            check(p['family'] == 'deepseek', f"[{name}] {role} primary family must be deepseek, got {p['family']}")

        fb = get_role_rung(role, 'fallback')
        if fb:
            check(fb['provider'] == 'codex', f"[{name}] {role} fallback provider must be codex, got {fb['provider']}")
            check(fb['base_model'] == 'gpt-6-luna', f"[{name}] {role} fallback model must be gpt-6-luna, got {fb['model']}")
            exp_fb_effort = 'reasoningEffort=low' if role == 'scout' else 'reasoningEffort=medium'
            check(fb['effort'] == exp_fb_effort, f"[{name}] {role} fallback effort must be {exp_fb_effort}, got {fb['effort']}")
            check(fb['family'] == 'openai', f"[{name}] {role} fallback family must be openai, got {fb['family']}")

        lr = get_role_rung(role, 'last-resort')
        if lr:
            check(lr['provider'] == 'antigravity', f"[{name}] {role} last-resort provider must be antigravity, got {lr['provider']}")
            check(lr['base_model'] == 'gemini-3.8-flash', f"[{name}] {role} last-resort model must be gemini-3.8-flash, got {lr['model']}")
            exp_lr_effort = 'thinking_level=low' if role == 'scout' else 'thinking_level=medium'
            check(lr['effort'] == exp_lr_effort, f"[{name}] {role} last-resort effort must be {exp_lr_effort}, got {lr['effort']}")
            check(lr['family'] == 'google', f"[{name}] {role} last-resort family must be google, got {lr['family']}")

    # 4. Antigravity purity: NO Anthropic family/model routes or Claude quota pools through Antigravity
    for r in all_rows:
        if r['provider'] == 'antigravity':
            check(r['family'] != 'anthropic', f"[{name}] antigravity route has forbidden anthropic family: {r['line']}")
            check('claude' not in r['base_model'].lower() and 'claude' not in r['model'].lower(),
                  f"[{name}] antigravity route has forbidden claude model: {r['line']}")
    for pool in pools:
        if pool['provider'] == 'antigravity':
            check('claude' not in pool['pool'].lower(), f"[{name}] antigravity has claude quota pool: {pool['line']}")
            check('claude' not in pool['models'].lower(), f"[{name}] antigravity quota pool carries claude models: {pool['line']}")

    # 5. Backup ladder operational rows: NO operational roles (scout/tester/patch/implementer/deep or wildcard)
    check(len(backups) > 0, f"[{name}] backup ladder must retain review-only rows, got empty ladder")
    for b in backups:
        check('*' not in b['roles'], f"[{name}] backup ladder row must not contain wildcard: {b['line']}")
        for role in b['roles']:
            check(role not in OPERATIONAL_ROLES, f"[{name}] operational backup ladder row forbidden for role '{role}': {b['line']}")
            check(role in REVIEW_ROLES or role == 'task-reviewer', f"[{name}] non-review backup ladder row forbidden for role '{role}': {b['line']}")
        check(b['base_model'] in (TASK_MODELS if b['roles'] == ['task-reviewer'] else ALLOWED_REVIEW_MODELS), f"[{name}] backup ladder review model must be in {ALLOWED_REVIEW_MODELS}, got {b['model']}")

    # 6. Exact model policy unchanged
    rev_a = get_role_rung('reviewer-a', 'primary')
    rev_b = get_role_rung('reviewer-b', 'primary')
    rev_c = get_role_rung('reviewer-c', 'primary')
    task_rev = get_role_rung('task-reviewer', 'primary')

    if rev_a: check(rev_a['base_model'] == 'claude-opus-5-5', f"[{name}] reviewer-a primary must be claude-opus-5-5, got {rev_a['model']}")
    if rev_b: check(rev_b['base_model'] == 'gpt-6.2-sol', f"[{name}] reviewer-b primary must be gpt-6.2-sol, got {rev_b['model']}")
    if rev_c: check(rev_c['base_model'] == 'gemini-4-neon', f"[{name}] reviewer-c primary must be gemini-4-neon, got {rev_c['model']}")
    if task_rev: check(task_rev['base_model'] == 'gpt-6.2-sol', f"[{name}] task-reviewer primary must be gpt-6.2-sol, got {task_rev['model']}")
    if rev_a and rev_b and rev_c:
        check(len({rev_a['base_model'], rev_b['base_model'], rev_c['base_model']}) == 3, f"[{name}] council models must be distinct")

    for r in roles:
        if r['role'] == 'task-reviewer': check(r['base_model'] in TASK_MODELS, r['line'])
        if r['role'] in REVIEW_ROLES:
            check(r['base_model'] in ALLOWED_REVIEW_MODELS, f"[{name}] review role {r['role']} (rung {r['rung']}) has disallowed model: {r['model']}")
    for sr in single_reviews:
        check(sr['base_model'] in ALLOWED_REVIEW_MODELS, f"[{name}] single-provider review has disallowed model: {sr['model']}")

    for draft_role in ('designer', 'planner'):
        dp = get_role_rung(draft_role, 'primary')
        dfb = get_role_rung(draft_role, 'fallback')
        dlr = get_role_rung(draft_role, 'last-resort')
        if dp: check(dp['base_model'] == 'claude-fable-5-2', f"[{name}] {draft_role} primary must be claude-fable-5-2, got {dp['model']}")
        if dfb: check(dfb['base_model'] == 'gpt-6.2-sol', f"[{name}] {draft_role} fallback must be gpt-6.2-sol, got {dfb['model']}")
        if dlr:
            check(dlr['provider'] == 'antigravity', f"[{name}] {draft_role} last-resort provider must be antigravity, got {dlr['provider']}")
            check(dlr['base_model'] == 'gemini-4-carbon', f"[{name}] {draft_role} last-resort must be gemini-4-carbon, got {dlr['model']}")
            check(dlr['effort'] == 'thinking_level=high', f"[{name}] {draft_role} last-resort effort must be thinking_level=high, got {dlr['effort']}")
            check(dlr['family'] == 'google', f"[{name}] {draft_role} last-resort family must be google, got {dlr['family']}")

    for r in all_rows:
        for fmod in FORBIDDEN_MODELS:
            if fmod == 'gemini-4-carbon' and r.get('role') in ('designer', 'planner') and r.get('rung') == 'last-resort':
                continue
            check(fmod not in r['model'] and r['base_model'] != fmod, f"[{name}] forbidden model {fmod} found in: {r['line']}")
        eff = r['effort']
        if eff != '-':
            val = eff.split('=', 1)[-1] if '=' in eff else eff
            council = (r.get('role') in REVIEW_ROLES or (r.get('roles') and set(r['roles']) <= REVIEW_ROLES) or r['section'] in ('Single-provider review', 'single'))
            if council:
                check((r['provider'], r['base_model'], eff) in {('claudeAgent', 'claude-opus-5-5', 'effort=xhigh'), ('codex', 'gpt-6.2-sol', 'reasoningEffort=xhigh'), ('antigravity', 'gemini-4-neon', 'thinking_level=high')}, r['line'])
            check(council or val in VALID_EFFORT_LEVELS, f"[{name}] invalid effort level '{val}' in: {r['line']}")

    if errors:
        raise AssertionError("\n   - ".join(["policy violations:"] + errors))

def audit_terminal_semantics_contract(doc_name, text):
    """
    Assert provider-neutral contract rules and rendered instruction payloads:
    1. Operational terminal boundary: explicit operational last-resort stops (budget-stop / terminal)
       instead of attempting sibling hand-off (implementer <-> implementer-deep), backup ladder rows,
       or same-model alternates.
    2. Legacy emergency path: profiles/roles lacking an explicit last-resort retain the existing emergency path
       (same-model alternates, sibling hand-off, backup ladder walk).
    3. Reviews & drafts unchanged: council seats retain balanced seat fallback / backup ladder / degraded council,
       and draft roles stop on exhaustion.
    """
    errors = []
    def check(cond, msg):
        if not cond:
            errors.append(msg)

    # 1. Operational terminal last-resort boundary
    has_terminal_boundary = bool(
        re.search(r'last-resort\b[^\n.]*?\b(?:stop|terminal)\b[^\n.]*?\b(?:sibling|backup|alternate)', text, re.IGNORECASE) or
        re.search(r'(?:sibling|backup|alternate)[^\n.]*?\b(?:ineligible|skip|bypass|never)\b[^\n.]*?last-resort', text, re.IGNORECASE) or
        re.search(r'explicit\s+(?:operational\s+)?last-resort\s+(?:rung\s+)?(?:stops|is\s+terminal)', text, re.IGNORECASE) or
        re.search(r'operational\s+last-resort[^\n.]*?stops\s+instead\s+of\s+(?:sibling|backup|same-model\s+alternate)', text, re.IGNORECASE)
    )
    check(has_terminal_boundary,
          f"[{doc_name}] contract missing operational last-resort terminal boundary "
          f"(explicit operational last-resort must stop instead of sibling hand-off, backup ladder, or same-model alternates)")

    for role in OPERATIONAL_ROLES:
        check(role in text, f"[{doc_name}] terminal scope missing {role}")
    check(re.search(r'Primary/fallback (?:retain|keep) same-model alternates', text),
          f"[{doc_name}] primary/fallback alternates must remain eligible")
    check(re.search(r'(?:Retry transient once|transient retries once)', text),
          f"[{doc_name}] terminal transient must retain one retry")
    check(re.search(r'[Tt]ask failures (?:keep|retain) fix/debug caps, never budget', text),
          f"[{doc_name}] task failure must not become a budget failure")
    check('wildcard or explicit backups' in text,
          f"[{doc_name}] terminal must forbid wildcard and explicit backups")

    # 2. Legacy emergency path retention
    has_legacy_retention = bool(
        re.search(r'legacy[^\n.]*?(?:emergency|sibling|backup)', text, re.IGNORECASE) or
        re.search(r'(?:without|no|lacking)\s+(?:explicit\s+)?last-resort[^\n.]*?(?:emergency|sibling|backup)', text, re.IGNORECASE)
    )
    check(has_legacy_retention,
          f"[{doc_name}] contract missing legacy emergency path retention "
          f"(profiles/roles without an explicit last-resort must retain emergency sibling/backup path)")

    # 3. Reviews & drafts unchanged
    check('balanced seat fallback' in text.lower() or 'balanced fallback' in text.lower(),
          f"[{doc_name}] review balanced seat fallback contract missing")
    check('degraded council' in text.lower(), f"[{doc_name}] degraded council contract missing")
    check('designer' in text.lower() and 'planner' in text.lower(), f"[{doc_name}] designer/planner draft contract missing")

    if errors:
        raise AssertionError("\n   - ".join(["contract violations:"] + errors))

# Execution & Test Runner
failures = []
passed_count = 0

def run_test(test_name, fn):
    global passed_count
    try:
        fn()
        passed_count += 1
        print(f"PASS: {test_name}")
    except AssertionError as e:
        raw = str(e)
        lines = [l.strip() for l in raw.split('\n') if l.strip().startswith('-')]
        first_err = lines[0] if lines else raw.split('\n')[0]
        failures.append((test_name, raw))
        print(f"FAIL: {test_name}: {first_err}")
    except Exception as e:
        failures.append((test_name, f"Unexpected error: {type(e).__name__}: {e}"))
        print(f"ERROR: {test_name}: {type(e).__name__}: {e}")

# Test Case 1: 6 Shipped profiles
shipped_profiles = ['quad.md', 'tri.md', 'antigravity.md', 'claude.md', 'codex.md', 'opencode-go.md']
for prof in shipped_profiles:
    p_path = root / 'providers' / prof
    run_test(f"shipped_profile_{prof}", lambda p=prof, path=p_path: audit_profile_policy(p, path.read_text()))

# Test Case 2: 15 Dynamic --providers combinations
base_providers = ['antigravity', 'claude', 'codex', 'opencode']
combos = []
for r in range(1, 5):
    for combo in itertools.combinations(base_providers, r):
        combos.append(','.join(combo))

dyn_env = os.environ.copy()
for k in ('OPENCODE_CONFIG', 'CODEX_HOME', 'ANTIGRAVITY_CONFIG', 'CLAUDE_CONFIG_DIR', 'T3_USERDATA_DIR'):
    dyn_env.pop(k, None)

for i, combo in enumerate(combos, 1):
    def test_combo(c=combo, idx=i):
        home = scratch / f'dyn-{idx}'
        opencode_dir = home / 'opencode'
        home.mkdir(parents=True, exist_ok=True)
        env = dyn_env.copy()
        env['HOME'] = str(home)
        env['OPENCODE_CONFIG'] = str(opencode_dir)
        res = subprocess.run(
            ['bash', str(install_sh), '--target', 'opencode', '--providers', c, '--pm', 'none'],
            env=env, capture_output=True, text=True
        )
        assert res.returncode == 0, f"installer failed for --providers {c}: {res.stderr}"
        rendered_providers = (opencode_dir / 'PROVIDERS.md').read_text()
        audit_profile_policy(f"dyn:{c}", rendered_providers)

    run_test(f"generated_providers_{combo}", test_combo)

# Test Case 3: Terminal semantics contract text and rendered payloads
def test_contracts():
    # Check source contract
    agents_md = (root / 'AGENTS.md').read_text()
    audit_terminal_semantics_contract('AGENTS.md', agents_md)
    for skill in ('dispatch', 'oneshot'):
        skill_text = (root / 'skills' / skill / 'SKILL.md').read_text()
        # Skill boundary is provider-neutral; full council contracts live in AGENTS.
        boundary = skill_text.split('**Operational terminal boundary:**', 1)[1].split('\n', 1)[0]
        for role in OPERATIONAL_ROLES:
            assert role in boundary, f'{skill} terminal scope missing {role}'
        assert 'Primary/fallback retain same-model alternates' in boundary
        assert 'transient retries once' in boundary
        assert 'Task failures retain fix/debug caps, never budget failures' in boundary
        assert 'Roles without explicit last-resort retain legacy sibling/backup routing' in boundary
        assert 'review/design/planner are unchanged' in boundary
        assert 'explicit last-resort is terminal' in boundary
        assert 'without terminal same-model alternates, sibling hand-off, wildcard or explicit backups' in boundary


    # Render host payloads across all targets
    target_all_home = scratch / 'payloads'
    target_all_home.mkdir(parents=True, exist_ok=True)
    env = dyn_env.copy()
    env['HOME'] = str(target_all_home)
    res = subprocess.run(
        ['bash', str(install_sh), '--target', 'all', '--pm', 'none'],
        env=env, capture_output=True, text=True
    )
    assert res.returncode == 0, f"target all install failed: {res.stderr}"

    payload_checks = [
        ('rendered_opencode_HARNESS.md', target_all_home / '.config/opencode/HARNESS.md'),
        ('rendered_codex_AGENTS.md', target_all_home / '.codex/AGENTS.md'),
        ('rendered_claude_CLAUDE.md', target_all_home / '.claude/CLAUDE.md'),
        ('rendered_antigravity_rules_HARNESS.md', target_all_home / '.gemini/config/rules/HARNESS.md'),
    ]
    for label, ppath in payload_checks:
        assert ppath.exists(), f"missing rendered payload {ppath}"
        audit_terminal_semantics_contract(label, ppath.read_text())

run_test("terminal_semantics_contract_and_payloads", test_contracts)

# Summary and Exit Status
total = passed_count + len(failures)
print(f"\nSuite Summary: {total} checks run, {passed_count} passed, {len(failures)} failed.")
if failures:
    print("\nFailing Checks:")
    for name, reason in failures:
        # Print concise failure summary
        first_line = reason.split('\n')[0]
        extra_lines = [l for l in reason.split('\n')[1:] if l.strip().startswith('-')]
        count_str = f" ({len(extra_lines)} violations)" if extra_lines else ""
        print(f" - {name}{count_str}: {extra_lines[0] if extra_lines else first_line}")
    sys.exit(1)

print("ALL CHECKS PASSED.")
PY
