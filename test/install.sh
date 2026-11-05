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

# 4. manifest records exactly the installed set, no more and no less
[ -f "$MANIFEST" ] || fail "install writes .harness-manifest"
(cd "$ROOT" && find agents skills -type f -print | sort >"$TMPROOT/case4.expected")
printf 'HARNESS.md\n' >>"$TMPROOT/case4.expected"
sort -o "$TMPROOT/case4.expected" "$TMPROOT/case4.expected"
sort "$MANIFEST" >"$TMPROOT/case4.actual"
cmp -s "$TMPROOT/case4.expected" "$TMPROOT/case4.actual" || fail "manifest matches the installed file set exactly"
pass "manifest matches the installed file set exactly"

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
find "$DEST" -type f -exec cksum {} + | sort >"$TMPROOT/case8.snap"
if HOME="$HOME_DIR" "$INSTALL" >"$TMPROOT/case8.out" 2>&1; then
  fail "install without --force exits 1 when a target exists"
fi
[ ! -e "$DEST/skills/oneshot/SKILL.md" ] || fail "aborted run copies nothing (missing file stays missing)"
find "$DEST" -type f -exec cksum {} + | sort >"$TMPROOT/case8.after"
cmp -s "$TMPROOT/case8.snap" "$TMPROOT/case8.after" || fail "aborted run leaves every file byte-identical"
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

# 15. a symlinked parent directory refuses without --force and is repaired with --force
PHOME="$TMPROOT/parent-home"
PDEST="$PHOME/.config/opencode"
if ! HOME="$PHOME" "$INSTALL" >"$TMPROOT/case15a.out" 2>&1; then
  cat "$TMPROOT/case15a.out" >&2
  fail "fresh parent-case install exits 0"
fi
POUTSIDE="$TMPROOT/parent-outside"
mkdir -p "$POUTSIDE"
printf 'marker\n' >"$POUTSIDE/marker.md"
find "$POUTSIDE" -type f -exec cksum {} + | sort >"$TMPROOT/case15.snap"
find "$PDEST/skills" -depth -delete
ln -s "$POUTSIDE" "$PDEST/skills"
rc=0
HOME="$PHOME" "$INSTALL" >"$TMPROOT/case15b.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || fail "parent symlink run without --force exits 1"
grep -q 'parent symlink under destination' "$TMPROOT/case15b.out" || fail "parent symlink run names the offending path"
[ -L "$PDEST/skills" ] || fail "refused run leaves the parent symlink in place"
[ "$(cat "$POUTSIDE/marker.md")" = "marker" ] || fail "refused run preserves the outside marker file"
find "$POUTSIDE" -type f -exec cksum {} + | sort >"$TMPROOT/case15b.after"
cmp -s "$TMPROOT/case15.snap" "$TMPROOT/case15b.after" || fail "refused run adds no files outside the destination"
pass "parent symlink refuses without --force and writes nothing outside"
if ! HOME="$PHOME" "$INSTALL" --force >"$TMPROOT/case15c.out" 2>&1; then
  cat "$TMPROOT/case15c.out" >&2
  fail "parent symlink repair install exits 0"
fi
[ -d "$PDEST/skills" ] && [ ! -L "$PDEST/skills" ] || fail "--force restores the parent as a real directory"
cmp -s "$ROOT/skills/oneshot/SKILL.md" "$PDEST/skills/oneshot/SKILL.md" || fail "repaired parent receives installed files"
[ "$(cat "$POUTSIDE/marker.md")" = "marker" ] || fail "--force preserves the outside marker file"
find "$POUTSIDE" -type f -exec cksum {} + | sort >"$TMPROOT/case15c.after"
cmp -s "$TMPROOT/case15.snap" "$TMPROOT/case15c.after" || fail "--force leaves the outside directory unchanged"
pass "--force repairs a symlinked parent without touching the outside"

# 16. tampering then running without --force aborts and preserves the junk
printf 'junk-tamper\n' >"$DEST/agents/scout.md"
rc16=0
HOME="$HOME_DIR" "$INSTALL" >"$TMPROOT/case16.out" 2>&1 || rc16=$?
[ "$rc16" -eq 1 ] || fail "tampered run without --force exits 1"
[ "$(cat "$DEST/agents/scout.md")" = "junk-tamper" ] || fail "aborted run leaves the tampered file untouched"
pass "tampered run without --force aborts and keeps junk"

# 17. prune never escapes DEST through unsafe manifest entries
EVIL_OUTSIDE="$TMPROOT/evil-outside"
mkdir -p "$EVIL_OUTSIDE"
printf 'evil-keep\n' >"$EVIL_OUTSIDE/stale.md"
printf 'escape-keep\n' >"$HOME_DIR/.config/escape.md"
printf 'tmp-keep\n' >"$TMPROOT/tmp-escape.md"
ln -s "$EVIL_OUTSIDE" "$DEST/skills/linkevil"
printf '../escape.md\n%s\nskills/linkevil/stale.md\n' "$TMPROOT/tmp-escape.md" >>"$MANIFEST"
rc17=0
HOME="$HOME_DIR" "$INSTALL" --force --prune >"$TMPROOT/case17.out" 2>&1 || rc17=$?
[ "$rc17" -eq 0 ] || { cat "$TMPROOT/case17.out" >&2; fail "prune with unsafe entries exits 0"; }
[ "$(cat "$EVIL_OUTSIDE/stale.md")" = "evil-keep" ] || fail "prune through a symlinked parent removes nothing outside"
[ "$(cat "$HOME_DIR/.config/escape.md")" = "escape-keep" ] || fail "prune ignores ../ manifest entries"
[ "$(cat "$TMPROOT/tmp-escape.md")" = "tmp-keep" ] || fail "prune ignores absolute manifest entries"
grep -q 'ignoring unsafe manifest entry' "$TMPROOT/case17.out" || fail "prune reports unsafe manifest entries"
grep -q 'refusing to prune through symlink' "$TMPROOT/case17.out" || fail "prune reports the symlinked parent skip"
rm -f -- "$DEST/skills/linkevil" "$HOME_DIR/.config/escape.md"
pass "prune with hostile manifest entries stays inside DEST"

# 18. --force refuses when a directory blocks a target path
rm -f "$DEST/agents/scout.md"
mkdir -p "$DEST/agents/scout.md"
printf 'dir-marker\n' >"$DEST/agents/scout.md/marker.md"
rm -f "$DEST/skills/oneshot/SKILL.md"
MANIFEST_CKSUM="$(cksum <"$MANIFEST")"
rc18=0
HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case18.out" 2>&1 || rc18=$?
[ "$rc18" -eq 1 ] || fail "directory collision with --force exits 1"
grep -q 'directory at target cannot be replaced' "$TMPROOT/case18.out" || fail "directory collision names the blocking path"
[ -d "$DEST/agents/scout.md" ] && [ ! -L "$DEST/agents/scout.md" ] || fail "directory collision leaves the directory in place"
[ "$(cat "$DEST/agents/scout.md/marker.md")" = "dir-marker" ] || fail "directory collision leaves the directory untouched"
[ ! -e "$DEST/skills/oneshot/SKILL.md" ] || fail "aborted directory run copies nothing after the blockage"
[ "$MANIFEST_CKSUM" = "$(cksum <"$MANIFEST")" ] || fail "aborted directory run leaves the manifest intact"
pass "--force refuses a directory at a target path before copying anything"
rm -f "$DEST/agents/scout.md/marker.md"
rmdir "$DEST/agents/scout.md"
if ! HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case18b.out" 2>&1; then
  cat "$TMPROOT/case18b.out" >&2
  fail "restore after directory case exits 0"
fi

printf 'all install tests passed\n'
