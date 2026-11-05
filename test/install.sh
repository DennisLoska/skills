#!/usr/bin/env bash
# test/install.sh - contract tests for install.sh
# Uses a throwaway HOME under a scratch dir; never touches the real config.
set -euo pipefail
unset OPENCODE_CONFIG

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
MANIFEST="$DEST/.harness-manifest"

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

# 3. HARNESS.md is the repo's AGENTS.md, byte for byte
cmp -s "$ROOT/AGENTS.md" "$DEST/HARNESS.md" || fail "HARNESS.md is byte-identical to AGENTS.md"
pass "HARNESS.md is byte-identical to AGENTS.md"

# 4. manifest records every installed path
[ -f "$MANIFEST" ] || fail "install writes .harness-manifest"
grep -qx 'HARNESS.md' "$MANIFEST" || fail "manifest lists HARNESS.md"
grep -qx 'agents/scout.md' "$MANIFEST" || fail "manifest lists agents/scout.md"
grep -qx 'skills/oneshot/SKILL.md' "$MANIFEST" || fail "manifest lists skills/oneshot/SKILL.md"
pass "manifest lists installed files"

# 5. second run without --force refuses with a collision line
before="$(cksum <"$DEST/agents/scout.md")"
if HOME="$HOME_DIR" "$INSTALL" >"$TMPROOT/case5.out" 2>&1; then
  fail "second run without --force exits 1"
fi
grep -q 'collision:' "$TMPROOT/case5.out" || fail "second run prints a collision line"
pass "second run refuses with a collision line"

# 6. the refused run left the destination untouched
after="$(cksum <"$DEST/agents/scout.md")"
[ "$before" = "$after" ] || fail "refused run leaves destination unchanged"
pass "refused run leaves destination unchanged"

# 7. --force overwrites cleanly
if ! HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case7.out" 2>&1; then
  cat "$TMPROOT/case7.out" >&2
  fail "--force install exits 0"
fi
pass "--force install exits 0"

# 8. preflight aborts before copying anything: a missing destination file stays missing
rm -f "$DEST/skills/oneshot/SKILL.md"
if HOME="$HOME_DIR" "$INSTALL" >"$TMPROOT/case8.out" 2>&1; then
  fail "install without --force exits 1 when a target exists"
fi
[ ! -e "$DEST/skills/oneshot/SKILL.md" ] || fail "aborted run copies nothing (missing file stays missing)"
pass "preflight aborts before copying anything"

# restore the destination for the cases that follow
if ! HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case8b.out" 2>&1; then
  cat "$TMPROOT/case8b.out" >&2
  fail "restore install exits 0"
fi

# 9. --force replaces a tampered destination file with the source content
printf 'junk\n' >"$DEST/agents/scout.md"
if ! HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case9.out" 2>&1; then
  cat "$TMPROOT/case9.out" >&2
  fail "--force repair install exits 0"
fi
cmp -s "$ROOT/agents/scout.md" "$DEST/agents/scout.md" || fail "--force restores tampered file content"
pass "--force restores tampered file content"

# 10. foreign files survive --force --prune
mkdir -p "$DEST/skills/personal"
printf 'mine\n' >"$DEST/skills/personal/SKILL.md"
if ! HOME="$HOME_DIR" "$INSTALL" --force --prune >"$TMPROOT/case10.out" 2>&1; then
  cat "$TMPROOT/case10.out" >&2
  fail "--force --prune install exits 0"
fi
[ -f "$DEST/skills/personal/SKILL.md" ] || fail "--prune never removes a file it did not install"
pass "--prune never removes a file it did not install"

# 11. --prune removes a file the previous manifest claimed but this run no longer produces
printf 'stale\n' >"$DEST/skills/oneshot/OLD.md"
printf 'skills/oneshot/OLD.md\n' >>"$MANIFEST"
if ! HOME="$HOME_DIR" "$INSTALL" --force --prune >"$TMPROOT/case11.out" 2>&1; then
  cat "$TMPROOT/case11.out" >&2
  fail "prune of an owned stale file exits 0"
fi
[ ! -e "$DEST/skills/oneshot/OLD.md" ] || fail "--prune removes a file recorded in the previous manifest"
[ -f "$DEST/skills/oneshot/SKILL.md" ] || fail "--prune keeps files this run still produces"
[ -f "$DEST/skills/personal/SKILL.md" ] || fail "--prune still keeps foreign files"
grep -q 'pruned 1 stale file(s)' "$TMPROOT/case11.out" || fail "--prune reports the pruned count"
pass "--prune removes only files recorded in the previous manifest"

# 12. --prune without a previous manifest prunes nothing and says so
rm -f "$MANIFEST"
mkdir -p "$DEST/skills/ghost"
printf 'ghost\n' >"$DEST/skills/ghost/SKILL.md"
if ! HOME="$HOME_DIR" "$INSTALL" --force --prune >"$TMPROOT/case12.out" 2>&1; then
  cat "$TMPROOT/case12.out" >&2
  fail "--prune without a manifest exits 0"
fi
[ -f "$DEST/skills/ghost/SKILL.md" ] || fail "--prune without a manifest removes nothing"
grep -q 'no previous manifest; prune skipped' "$TMPROOT/case12.out" || fail "--prune without a manifest reports the skip"
[ -f "$MANIFEST" ] || fail "install rewrites the manifest after a skipped prune"
pass "--prune without a previous manifest prunes nothing"

# 13. --force does not write through a destination symlink
OUTSIDE="$TMPROOT/outside"
mkdir -p "$OUTSIDE"
printf 'outside-content\n' >"$OUTSIDE/scout-target.md"
rm -f "$DEST/agents/scout.md"
ln -s "$OUTSIDE/scout-target.md" "$DEST/agents/scout.md"
if ! HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case13.out" 2>&1; then
  cat "$TMPROOT/case13.out" >&2
  fail "install over a destination symlink exits 0"
fi
[ "$(cat "$OUTSIDE/scout-target.md")" = "outside-content" ] || fail "--force never writes through a symlink"
[ -f "$DEST/agents/scout.md" ] && [ ! -L "$DEST/agents/scout.md" ] || fail "symlink is replaced by a regular file"
cmp -s "$ROOT/agents/scout.md" "$DEST/agents/scout.md" || fail "symlink target replaced with source content"
pass "--force replaces a destination symlink instead of writing through it"

# 14. OPENCODE_CONFIG overrides the destination
HOME2="$TMPROOT/home2"
CUSTOM="$TMPROOT/custom"
if ! HOME="$HOME2" OPENCODE_CONFIG="$CUSTOM" "$INSTALL" >"$TMPROOT/case14.out" 2>&1; then
  cat "$TMPROOT/case14.out" >&2
  fail "OPENCODE_CONFIG install exits 0"
fi
[ -f "$CUSTOM/skills/oneshot/SKILL.md" ] || fail "OPENCODE_CONFIG destination receives files"
[ ! -e "$HOME2/.config/opencode/skills/oneshot/SKILL.md" ] || fail "OPENCODE_CONFIG run leaves HOME untouched"
[ -f "$CUSTOM/.harness-manifest" ] || fail "OPENCODE_CONFIG destination receives the manifest"
pass "OPENCODE_CONFIG override is honored"

printf 'all install tests passed\n'
