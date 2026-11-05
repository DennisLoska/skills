#!/usr/bin/env bash
# test/install.sh - contract tests for install.sh
# Uses a throwaway HOME under a scratch dir; never touches the real config.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$ROOT/install.sh"
TMPROOT="${TMPDIR:-/tmp}/harness-install-test.$$"

cleanup() {
  if [ -d "$TMPROOT" ]; then
    find "$TMPROOT" -depth -delete
  fi
}
trap cleanup EXIT

pass() { printf 'ok: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

mkdir -p "$TMPROOT"
HOME_DIR="$TMPROOT/home"
DEST="$HOME_DIR/.config/opencode"

# 1. clean install into an empty HOME
if ! HOME="$HOME_DIR" "$INSTALL" >"$TMPROOT/case1.out" 2>&1; then
  cat "$TMPROOT/case1.out" >&2
  fail "clean install exits 0"
fi
[ -f "$DEST/skills/oneshot/SKILL.md" ] || fail "clean install writes skills/oneshot/SKILL.md"
pass "clean install into empty HOME"

# 2. copied agent is byte-identical to the source
cmp -s "$ROOT/agents/scout.md" "$DEST/agents/scout.md" || fail "copied agent is byte-identical"
pass "copied agent is byte-identical"

# 3. second run without --force refuses with a collision line
before="$(cksum <"$DEST/agents/scout.md")"
if HOME="$HOME_DIR" "$INSTALL" >"$TMPROOT/case3.out" 2>&1; then
  fail "second run without --force exits 1"
fi
grep -q 'collision:' "$TMPROOT/case3.out" || fail "second run prints a collision line"
pass "second run refuses with a collision line"

# 4. the refused run left the destination untouched
after="$(cksum <"$DEST/agents/scout.md")"
[ "$before" = "$after" ] || fail "refused run leaves destination unchanged"
pass "refused run leaves destination unchanged"

# 5. --force overwrites cleanly
if ! HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case5.out" 2>&1; then
  cat "$TMPROOT/case5.out" >&2
  fail "--force install exits 0"
fi
pass "--force install exits 0"

# 6. OPENCODE_CONFIG overrides the destination
HOME2="$TMPROOT/home2"
CUSTOM="$TMPROOT/custom"
if ! HOME="$HOME2" OPENCODE_CONFIG="$CUSTOM" "$INSTALL" >"$TMPROOT/case6.out" 2>&1; then
  cat "$TMPROOT/case6.out" >&2
  fail "OPENCODE_CONFIG install exits 0"
fi
[ -f "$CUSTOM/skills/oneshot/SKILL.md" ] || fail "OPENCODE_CONFIG destination receives files"
[ ! -e "$HOME2/.config/opencode/skills/oneshot/SKILL.md" ] || fail "OPENCODE_CONFIG run leaves HOME untouched"
pass "OPENCODE_CONFIG override is honored"

# 7. --prune removes stale destination files and keeps real ones
mkdir -p "$DEST/skills/ghost"
printf 'stale\n' >"$DEST/skills/ghost/SKILL.md"
if ! HOME="$HOME_DIR" "$INSTALL" --force --prune >"$TMPROOT/case7.out" 2>&1; then
  cat "$TMPROOT/case7.out" >&2
  fail "--force --prune install exits 0"
fi
[ ! -e "$DEST/skills/ghost/SKILL.md" ] || fail "--prune removes stale file"
[ -f "$DEST/skills/oneshot/SKILL.md" ] || fail "--prune keeps real skill"
grep -q 'pruned 1 stale file(s)' "$TMPROOT/case7.out" || fail "--prune reports the pruned count"
pass "--prune removes stale files and keeps real ones"

printf 'all install tests passed\n'
