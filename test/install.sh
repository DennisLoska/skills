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
rc1=0
HOME="$HOME_DIR" "$INSTALL" >"$TMPROOT/case1.out" 2>&1 || rc1=$?
[ "$rc1" -eq 0 ] || { cat "$TMPROOT/case1.out" >&2; fail "clean install exits 0"; }
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
grep -v '^#' "$MANIFEST" | sort >"$TMPROOT/case4.actual"
cmp -s "$TMPROOT/case4.expected" "$TMPROOT/case4.actual" || fail "manifest matches the installed file set exactly"
pass "manifest matches the installed file set exactly"

# 5. second run without --force refuses with a collision line
find "$DEST" -type f -exec cksum {} + | sort >"$TMPROOT/case5.snap"
rc5=0
HOME="$HOME_DIR" "$INSTALL" >"$TMPROOT/case5.out" 2>&1 || rc5=$?
[ "$rc5" -eq 1 ] || fail "second run without --force exits 1"
grep -q 'collision:' "$TMPROOT/case5.out" || fail "second run prints a collision line"
pass "second run refuses with a collision line"

# 6. the refused run left every installed file untouched
find "$DEST" -type f -exec cksum {} + | sort >"$TMPROOT/case6.after"
cmp -s "$TMPROOT/case5.snap" "$TMPROOT/case6.after" || fail "refused run leaves every installed file unchanged"
pass "refused run leaves destination unchanged"

# 7. --force overwrites cleanly
rc7=0
HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case7.out" 2>&1 || rc7=$?
[ "$rc7" -eq 0 ] || { cat "$TMPROOT/case7.out" >&2; fail "--force install exits 0"; }
pass "--force install exits 0"

# 8. preflight aborts before copying anything: a missing destination file stays missing
rm -f "$DEST/skills/oneshot/SKILL.md"
find "$DEST" -type f -exec cksum {} + | sort >"$TMPROOT/case8.snap"
rc8=0
HOME="$HOME_DIR" "$INSTALL" >"$TMPROOT/case8.out" 2>&1 || rc8=$?
[ "$rc8" -eq 1 ] || fail "install without --force exits 1 when a target exists"
[ ! -e "$DEST/skills/oneshot/SKILL.md" ] || fail "aborted run copies nothing (missing file stays missing)"
find "$DEST" -type f -exec cksum {} + | sort >"$TMPROOT/case8.after"
cmp -s "$TMPROOT/case8.snap" "$TMPROOT/case8.after" || fail "aborted run leaves every file byte-identical"
pass "preflight aborts before copying anything"

# restore the destination for the cases that follow
rc8b=0
HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case8b.out" 2>&1 || rc8b=$?
[ "$rc8b" -eq 0 ] || { cat "$TMPROOT/case8b.out" >&2; fail "restore install exits 0"; }

# 9. --force replaces a tampered destination file with the source content
printf 'junk\n' >"$DEST/agents/scout.md"
rc9=0
HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case9.out" 2>&1 || rc9=$?
[ "$rc9" -eq 0 ] || { cat "$TMPROOT/case9.out" >&2; fail "--force repair install exits 0"; }
cmp -s "$ROOT/agents/scout.md" "$DEST/agents/scout.md" || fail "--force restores tampered file content"
pass "--force restores tampered file content"

# 10. foreign files survive --force --prune
mkdir -p "$DEST/skills/personal"
printf 'mine\n' >"$DEST/skills/personal/SKILL.md"
rc10=0
HOME="$HOME_DIR" "$INSTALL" --force --prune >"$TMPROOT/case10.out" 2>&1 || rc10=$?
[ "$rc10" -eq 0 ] || { cat "$TMPROOT/case10.out" >&2; fail "--force --prune install exits 0"; }
[ -f "$DEST/skills/personal/SKILL.md" ] || fail "--prune never removes a file it did not install"
pass "--prune never removes a file it did not install"

# 11. --prune removes a file the previous manifest claimed but this run no longer produces
printf 'stale\n' >"$DEST/skills/oneshot/OLD.md"
printf 'skills/oneshot/OLD.md\n' >>"$MANIFEST"
rc11=0
HOME="$HOME_DIR" "$INSTALL" --force --prune >"$TMPROOT/case11.out" 2>&1 || rc11=$?
[ "$rc11" -eq 0 ] || { cat "$TMPROOT/case11.out" >&2; fail "prune of an owned stale file exits 0"; }
[ ! -e "$DEST/skills/oneshot/OLD.md" ] || fail "--prune removes a file recorded in the previous manifest"
[ -f "$DEST/skills/oneshot/SKILL.md" ] || fail "--prune keeps files this run still produces"
[ -f "$DEST/skills/personal/SKILL.md" ] || fail "--prune still keeps foreign files"
grep -q 'pruned 1 stale file(s)' "$TMPROOT/case11.out" || fail "--prune reports the pruned count"
pass "--prune removes only files recorded in the previous manifest"

# 12. --prune without a previous manifest prunes nothing and says so
rm -f "$MANIFEST"
mkdir -p "$DEST/skills/ghost"
printf 'ghost\n' >"$DEST/skills/ghost/SKILL.md"
rc12=0
HOME="$HOME_DIR" "$INSTALL" --force --prune >"$TMPROOT/case12.out" 2>&1 || rc12=$?
[ "$rc12" -eq 0 ] || { cat "$TMPROOT/case12.out" >&2; fail "--prune without a manifest exits 0"; }
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
rc13=0
HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case13.out" 2>&1 || rc13=$?
[ "$rc13" -eq 0 ] || { cat "$TMPROOT/case13.out" >&2; fail "install over a destination symlink exits 0"; }
[ "$(cat "$OUTSIDE/scout-target.md")" = "outside-content" ] || fail "--force never writes through a symlink"
[ -f "$DEST/agents/scout.md" ] && [ ! -L "$DEST/agents/scout.md" ] || fail "symlink is replaced by a regular file"
cmp -s "$ROOT/agents/scout.md" "$DEST/agents/scout.md" || fail "symlink target replaced with source content"
pass "--force replaces a destination symlink instead of writing through it"

# 14. OPENCODE_CONFIG overrides the destination
HOME2="$TMPROOT/home2"
CUSTOM="$TMPROOT/custom"
rc14=0
HOME="$HOME2" OPENCODE_CONFIG="$CUSTOM" "$INSTALL" >"$TMPROOT/case14.out" 2>&1 || rc14=$?
[ "$rc14" -eq 0 ] || { cat "$TMPROOT/case14.out" >&2; fail "OPENCODE_CONFIG install exits 0"; }
[ -f "$CUSTOM/skills/oneshot/SKILL.md" ] || fail "OPENCODE_CONFIG destination receives files"
[ ! -e "$HOME2/.config/opencode/skills/oneshot/SKILL.md" ] || fail "OPENCODE_CONFIG run leaves HOME untouched"
[ -f "$CUSTOM/.harness-manifest" ] || fail "OPENCODE_CONFIG destination receives the manifest"
pass "OPENCODE_CONFIG override is honored"

# 15. a symlinked parent directory refuses without --force and is repaired with --force
PHOME="$TMPROOT/parent-home"
PDEST="$PHOME/.config/opencode"
rc15a=0
HOME="$PHOME" "$INSTALL" >"$TMPROOT/case15a.out" 2>&1 || rc15a=$?
[ "$rc15a" -eq 0 ] || { cat "$TMPROOT/case15a.out" >&2; fail "fresh parent-case install exits 0"; }
POUTSIDE="$TMPROOT/parent-outside"
mkdir -p "$POUTSIDE"
printf 'marker\n' >"$POUTSIDE/marker.md"
find "$POUTSIDE" -type f -exec cksum {} + | sort >"$TMPROOT/case15.snap"
find "$PDEST/skills" -depth -delete
ln -s "$POUTSIDE" "$PDEST/skills"
rc15b=0
HOME="$PHOME" "$INSTALL" >"$TMPROOT/case15b.out" 2>&1 || rc15b=$?
[ "$rc15b" -eq 1 ] || fail "parent symlink run without --force exits 1"
grep -q 'parent symlink under destination' "$TMPROOT/case15b.out" || fail "parent symlink run names the offending path"
[ -L "$PDEST/skills" ] || fail "refused run leaves the parent symlink in place"
[ "$(cat "$POUTSIDE/marker.md")" = "marker" ] || fail "refused run preserves the outside marker file"
find "$POUTSIDE" -type f -exec cksum {} + | sort >"$TMPROOT/case15b.after"
cmp -s "$TMPROOT/case15.snap" "$TMPROOT/case15b.after" || fail "refused run adds no files outside the destination"
pass "parent symlink refuses without --force and writes nothing outside"
rc15c=0
HOME="$PHOME" "$INSTALL" --force >"$TMPROOT/case15c.out" 2>&1 || rc15c=$?
[ "$rc15c" -eq 0 ] || { cat "$TMPROOT/case15c.out" >&2; fail "parent symlink repair install exits 0"; }
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
rc18b=0
HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case18b.out" 2>&1 || rc18b=$?
[ "$rc18b" -eq 0 ] || { cat "$TMPROOT/case18b.out" >&2; fail "restore after directory case exits 0"; }

# 19. unknown flag exits 2, prints usage to stderr, and touches nothing
find "$DEST" -type f -exec cksum {} + | sort >"$TMPROOT/case19.snap"
MANIFEST19_CKSUM="$(cksum <"$MANIFEST")"
rc19=0
HOME="$HOME_DIR" "$INSTALL" --bogus >"$TMPROOT/case19.out" 2>"$TMPROOT/case19.err" || rc19=$?
[ "$rc19" -eq 2 ] || fail "unknown flag exits 2"
grep -q 'usage:' "$TMPROOT/case19.err" || fail "unknown flag prints usage to stderr"
find "$DEST" -type f -exec cksum {} + | sort >"$TMPROOT/case19.after"
cmp -s "$TMPROOT/case19.snap" "$TMPROOT/case19.after" || fail "unknown flag leaves destination untouched"
[ "$MANIFEST19_CKSUM" = "$(cksum <"$MANIFEST")" ] || fail "unknown flag leaves the manifest untouched"
pass "unknown flag exits 2 with usage and touches nothing"

# 20. --help exits 0, prints usage, and copies nothing
HELP_HOME="$TMPROOT/help-home"
HELP_DEST="$HELP_HOME/.config/opencode"
rc20=0
HOME="$HELP_HOME" "$INSTALL" --help >"$TMPROOT/case20.out" 2>"$TMPROOT/case20.err" || rc20=$?
[ "$rc20" -eq 0 ] || fail "--help exits 0"
grep -q 'usage:' "$TMPROOT/case20.out" || fail "--help prints usage"
[ ! -e "$HELP_DEST" ] || fail "--help copies nothing"
pass "--help exits 0 with usage and copies nothing"

# 21. OPENCODE_CONFIG pointing at a symlink installs into the real directory
REAL_DEST="$TMPROOT/real-dest"
mkdir -p "$REAL_DEST"
LINK_DEST="$TMPROOT/link-dest"
ln -s "$REAL_DEST" "$LINK_DEST"
rc21=0
OPENCODE_CONFIG="$LINK_DEST" "$INSTALL" >"$TMPROOT/case21.out" 2>&1 || rc21=$?
[ "$rc21" -eq 0 ] || { cat "$TMPROOT/case21.out" >&2; fail "symlinked OPENCODE_CONFIG install exits 0"; }
[ -f "$REAL_DEST/skills/oneshot/SKILL.md" ] || fail "symlinked destination lands in the real directory"
cmp -s "$ROOT/skills/oneshot/SKILL.md" "$REAL_DEST/skills/oneshot/SKILL.md" || fail "symlinked destination content is byte-identical"
[ -L "$LINK_DEST" ] || fail "symlinked destination is still a symlink afterwards"
pass "symlinked OPENCODE_CONFIG installs into the real directory"

# 22. prune skips a manifest-listed directory instead of aborting
STALE_DIR="$DEST/skills/oneshot/OLDDIR.md"
rm -rf "$STALE_DIR"
mkdir -p "$STALE_DIR"
printf 'inner\n' >"$STALE_DIR/inner.md"
printf 'skills/oneshot/OLDDIR.md\n' >>"$MANIFEST"
rc22=0
HOME="$HOME_DIR" "$INSTALL" --force --prune >"$TMPROOT/case22.out" 2>"$TMPROOT/case22.err" || rc22=$?
[ "$rc22" -eq 0 ] || { cat "$TMPROOT/case22.out" "$TMPROOT/case22.err" >&2; fail "prune with a directory target exits 0"; }
[ -d "$STALE_DIR" ] || fail "prune skips a directory target instead of removing it"
[ -f "$STALE_DIR/inner.md" ] || fail "prune leaves the skipped directory contents untouched"
grep -q 'skipping non-file prune target' "$TMPROOT/case22.err" || fail "prune reports the skipped directory target"
rm -rf "$STALE_DIR"
rc22b=0
HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case22b.out" 2>&1 || rc22b=$?
[ "$rc22b" -eq 0 ] || { cat "$TMPROOT/case22b.out" >&2; fail "restore after directory prune case exits 0"; }
pass "prune skips a manifest-listed directory instead of aborting"

# 23. every manifest entry is byte-identical to its source file
entries=0
while IFS= read -r mrel || [ -n "$mrel" ]; do
  [ -n "$mrel" ] || continue
  case "$mrel" in
    '#'*) continue ;;
  esac
  entries=$((entries + 1))
  if [ "$mrel" = "HARNESS.md" ]; then
    src="$ROOT/AGENTS.md"
  else
    src="$ROOT/$mrel"
  fi
  [ -f "$src" ] || fail "manifest entry has a source file: $mrel"
  [ -f "$DEST/$mrel" ] || fail "manifest entry is installed: $mrel"
  cmp -s "$src" "$DEST/$mrel" || fail "installed file is byte-identical: $mrel"
done <"$MANIFEST"
[ "$entries" -gt 0 ] || fail "manifest lists installed files"
pass "every manifest entry is byte-identical to its source"

# 24. nested parent symlinks repair shallowest-first without touching either outside tree
NHOME="$TMPROOT/nested-home"
NDEST="$NHOME/.config/opencode"
rc24a=0
HOME="$NHOME" "$INSTALL" >"$TMPROOT/case24a.out" 2>&1 || rc24a=$?
[ "$rc24a" -eq 0 ] || { cat "$TMPROOT/case24a.out" >&2; fail "fresh nested-case install exits 0"; }
NOUTSIDE="$TMPROOT/nested-outside"
NOUTSIDE2="$TMPROOT/nested-outside2"
mkdir -p "$NOUTSIDE" "$NOUTSIDE2"
printf 'outer-marker\n' >"$NOUTSIDE/outer-marker.md"
printf 'inner-marker\n' >"$NOUTSIDE2/inner-marker.md"
ln -s "$NOUTSIDE2" "$NOUTSIDE/land"
find "$NOUTSIDE" -type f -exec cksum {} + | sort >"$TMPROOT/case24.outer.snap"
find "$NOUTSIDE2" -type f -exec cksum {} + | sort >"$TMPROOT/case24.inner.snap"
find "$NDEST/skills" -depth -delete
ln -s "$NOUTSIDE" "$NDEST/skills"
rc24b=0
HOME="$NHOME" "$INSTALL" >"$TMPROOT/case24b.out" 2>&1 || rc24b=$?
[ "$rc24b" -eq 1 ] || fail "nested symlink run without --force exits 1"
grep -q 'parent symlink under destination' "$TMPROOT/case24b.out" || fail "nested symlink run names the offending path"
[ -L "$NDEST/skills" ] || fail "refused run leaves the outer parent symlink in place"
[ -L "$NOUTSIDE/land" ] || fail "refused run leaves the inner outside symlink in place"
[ "$(cat "$NOUTSIDE/outer-marker.md")" = "outer-marker" ] || fail "refused run preserves the outer marker file"
[ "$(cat "$NOUTSIDE2/inner-marker.md")" = "inner-marker" ] || fail "refused run preserves the inner marker file"
find "$NOUTSIDE" -type f -exec cksum {} + | sort >"$TMPROOT/case24b.outer.after"
find "$NOUTSIDE2" -type f -exec cksum {} + | sort >"$TMPROOT/case24b.inner.after"
cmp -s "$TMPROOT/case24.outer.snap" "$TMPROOT/case24b.outer.after" || fail "refused run adds no files to the outer tree"
cmp -s "$TMPROOT/case24.inner.snap" "$TMPROOT/case24b.inner.after" || fail "refused run adds no files to the inner tree"
pass "nested symlink refuses without --force and writes nothing outside"
rc24c=0
HOME="$NHOME" "$INSTALL" --force >"$TMPROOT/case24c.out" 2>&1 || rc24c=$?
[ "$rc24c" -eq 0 ] || { cat "$TMPROOT/case24c.out" >&2; fail "nested symlink repair install exits 0"; }
[ -d "$NDEST/skills" ] && [ ! -L "$NDEST/skills" ] || fail "--force restores the outer parent as a real directory"
[ -d "$NDEST/skills/land" ] && [ ! -L "$NDEST/skills/land" ] || fail "--force restores the inner parent as a real directory"
cmp -s "$ROOT/skills/land/SKILL.md" "$NDEST/skills/land/SKILL.md" || fail "repaired nested parent receives installed files"
cmp -s "$ROOT/skills/oneshot/SKILL.md" "$NDEST/skills/oneshot/SKILL.md" || fail "repaired outer parent receives installed files"
[ -L "$NOUTSIDE/land" ] || fail "--force leaves the outside inner symlink untouched"
[ "$(cat "$NOUTSIDE/outer-marker.md")" = "outer-marker" ] || fail "--force preserves the outer marker file"
[ "$(cat "$NOUTSIDE2/inner-marker.md")" = "inner-marker" ] || fail "--force preserves the inner marker file"
find "$NOUTSIDE" -type f -exec cksum {} + | sort >"$TMPROOT/case24c.outer.after"
find "$NOUTSIDE2" -type f -exec cksum {} + | sort >"$TMPROOT/case24c.inner.after"
cmp -s "$TMPROOT/case24.outer.snap" "$TMPROOT/case24c.outer.after" || fail "--force leaves the outer tree unchanged"
cmp -s "$TMPROOT/case24.inner.snap" "$TMPROOT/case24c.inner.after" || fail "--force leaves the inner tree unchanged"
pass "--force repairs nested symlinked parents shallowest-first"

# 25. a regular file blocking a parent directory refuses before copying anything
FHOME="$TMPROOT/fileblock-home"
FDEST="$FHOME/.config/opencode"
rc25a=0
HOME="$FHOME" "$INSTALL" >"$TMPROOT/case25a.out" 2>&1 || rc25a=$?
[ "$rc25a" -eq 0 ] || { cat "$TMPROOT/case25a.out" >&2; fail "fresh fileblock-case install exits 0"; }
rm -rf "$FDEST/skills"
printf 'i-am-a-file\n' >"$FDEST/skills"
find "$FDEST/agents" -type f -exec cksum {} + | sort >"$TMPROOT/case25.snap"
FMANIFEST_CKSUM="$(cksum <"$FDEST/.harness-manifest")"
rc25b=0
HOME="$FHOME" "$INSTALL" >"$TMPROOT/case25b.out" 2>&1 || rc25b=$?
[ "$rc25b" -eq 1 ] || fail "file blocking a parent directory exits 1"
grep -q 'parent path is not a directory' "$TMPROOT/case25b.out" || fail "fileblock run names the blocking path"
[ -f "$FDEST/skills" ] && [ ! -L "$FDEST/skills" ] || fail "refused run leaves the blocking file in place"
[ ! -e "$FDEST/skills/oneshot/SKILL.md" ] || fail "refused run copies nothing under the blocked parent"
find "$FDEST/agents" -type f -exec cksum {} + | sort >"$TMPROOT/case25b.after"
cmp -s "$TMPROOT/case25.snap" "$TMPROOT/case25b.after" || fail "refused run leaves the rest of the destination untouched"
[ "$FMANIFEST_CKSUM" = "$(cksum <"$FDEST/.harness-manifest")" ] || fail "refused run leaves the manifest intact"
pass "regular file blocking a parent refuses without --force"
rc25c=0
HOME="$FHOME" "$INSTALL" --force >"$TMPROOT/case25c.out" 2>&1 || rc25c=$?
[ "$rc25c" -eq 1 ] || fail "file blocking a parent directory exits 1 even with --force"
grep -q 'parent path is not a directory' "$TMPROOT/case25c.out" || fail "--force fileblock run names the blocking path"
[ "$FMANIFEST_CKSUM" = "$(cksum <"$FDEST/.harness-manifest")" ] || fail "--force fileblock run leaves the manifest intact"
rm -f "$FDEST/skills"
rc25d=0
HOME="$FHOME" "$INSTALL" --force >"$TMPROOT/case25d.out" 2>&1 || rc25d=$?
[ "$rc25d" -eq 0 ] || { cat "$TMPROOT/case25d.out" >&2; fail "restore after fileblock case exits 0"; }
[ -f "$FDEST/skills/oneshot/SKILL.md" ] || fail "restore after fileblock case reinstalls skills"
pass "regular file blocking a parent refuses even with --force"

# 26. manifest carries the harness sha and install reports drift
CUR_SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || true)"
[ -n "$CUR_SHA" ] || CUR_SHA="unknown"
[ "$(head -n 1 "$MANIFEST")" = "# harness $CUR_SHA" ] || fail "manifest first line records the harness sha"
{
  printf '# harness oldsha0\n'
  grep -v '^#' "$MANIFEST"
} >"$TMPROOT/case26.manifest"
cp "$TMPROOT/case26.manifest" "$MANIFEST"
rc26=0
HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case26.out" 2>&1 || rc26=$?
[ "$rc26" -eq 0 ] || { cat "$TMPROOT/case26.out" >&2; fail "install with a drifted harness sha exits 0"; }
grep -q "harness updated: oldsha0 -> $CUR_SHA" "$TMPROOT/case26.out" || fail "install reports the harness drift"
[ "$(head -n 1 "$MANIFEST")" = "# harness $CUR_SHA" ] || fail "install refreshes the harness sha"
pass "manifest records the harness sha and install reports drift"

printf 'all install tests passed\n'
