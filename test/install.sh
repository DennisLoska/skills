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

passed=0
pass() { passed=$((passed + 1)); printf 'ok: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

mkdir -p "$TMPROOT"
HOME_DIR="$TMPROOT/home"
DEST="$HOME_DIR/.config/opencode"
MANIFEST="$DEST/.harness-manifest"

# Frozen historical pins and positions, independent of current source layout.
mkdir -p "$TMPROOT/legacy-agents"
while IFS="$(printf '\t')" read -r seat line model; do
  [ -f "$ROOT/agents/$seat.md" ] || continue
  MODEL_LINE="$model" awk -v line="$line" '
    NR == line { print ENVIRON["MODEL_LINE"] }
    { print }
  ' "$ROOT/agents/$seat.md" >"$TMPROOT/legacy-agents/$seat.md"
done <"$ROOT/test/fixtures/legacy-pins.txt"

# Default render expectations are independent of the routing-table parser.
mkdir -p "$TMPROOT/tri-agents"
while read -r seat pin; do
  [ -f "$ROOT/agents/$seat.md" ] || continue
  awk -v pin="$pin" '
    /^model: / { next }
    { print }
    /^mode: subagent$/ && pin != "-" { print "model: " pin }
  ' "$ROOT/agents/$seat.md" >"$TMPROOT/tri-agents/$seat.md"
done <<'PINS'
scout opencode-go/mimo-v2.6-flash
implementer opencode-go/gemini-4-argon#high
implementer-deep -
patch opencode-go/deepseek-v4.1-flash#high
tester opencode-go/deepseek-v4.1-flash#high
reviewer-a opencode-go/kimi-k3.1-pro#high
reviewer-b opencode-go/claude-haiku-5-5#high
reviewer-c opencode-go/gpt-6-luna#high
reviewer-esc opencode-go/deepseek-v4-pro
PINS

# 1. clean install into an empty HOME
rc1=0
HOME="$HOME_DIR" "$INSTALL" >"$TMPROOT/case1.out" 2>&1 || rc1=$?
[ "$rc1" -eq 0 ] || { cat "$TMPROOT/case1.out" >&2; fail "clean install exits 0"; }
[ -f "$DEST/skills/oneshot/SKILL.md" ] || fail "clean install writes skills/oneshot/SKILL.md"
pass "clean install into empty HOME"

# 2. copied agent is byte-identical to the source
cmp -s "$TMPROOT/legacy-agents/scout.md" "$DEST/agents/scout.md" || fail "copied agent is byte-identical"
pass "copied agent is byte-identical"

# 3. HARNESS.md is the repo's AGENTS.md, byte for byte
cmp -s "$ROOT/AGENTS.md" "$DEST/HARNESS.md" || fail "HARNESS.md is byte-identical to AGENTS.md"
pass "HARNESS.md is byte-identical to AGENTS.md"

# 4. manifest records exactly the installed set, no more and no less
[ -f "$MANIFEST" ] || fail "install writes .harness-manifest"
(cd "$ROOT" && find agents skills -type f -print | sort >"$TMPROOT/case4.expected")
printf 'HARNESS.md\nNOTICE\nLICENSE\nPROVIDERS.md\n' >>"$TMPROOT/case4.expected"
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
cmp -s "$TMPROOT/legacy-agents/scout.md" "$DEST/agents/scout.md" || fail "--force restores tampered file content"
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
HOME="$HOME_DIR" "$INSTALL" --force --prune --profile tri >"$TMPROOT/case12.out" 2>&1 || rc12=$?
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
cmp -s "$TMPROOT/legacy-agents/scout.md" "$DEST/agents/scout.md" || fail "symlink target replaced with source content"
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
HOME="$TMPROOT/home21" OPENCODE_CONFIG="$LINK_DEST" "$INSTALL" >"$TMPROOT/case21.out" 2>&1 || rc21=$?
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
  elif [ "$mrel" = "PROVIDERS.md" ]; then
    src="$ROOT/providers/tri.md"
  elif [[ "$mrel" == agents/*.md ]]; then
    # Compare against the independent default pin fixture.
    src="$TMPROOT/tri-agents/${mrel#agents/}"
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

# 27. an empty or whitespace-only OPENCODE_CONFIG is refused and creates nothing
EMPTY_SCRATCH="$TMPROOT/empty-scratch"
EMPTY_HOME="$TMPROOT/home-empty-dest"
mkdir -p "$EMPTY_SCRATCH"
empty_idx=0
for empty_val in "" "   " "	"; do
  empty_idx=$((empty_idx + 1))
  rc27=0
  ( cd "$EMPTY_SCRATCH" && HOME="$EMPTY_HOME" OPENCODE_CONFIG="$empty_val" "$INSTALL" ) >"$TMPROOT/case27.$empty_idx.out" 2>&1 || rc27=$?
  [ "$rc27" -eq 1 ] || { cat "$TMPROOT/case27.$empty_idx.out" >&2; fail "empty destination value $empty_idx exits 1"; }
  grep -q 'install.sh: refusing unsafe destination' "$TMPROOT/case27.$empty_idx.out" || fail "empty destination value $empty_idx is named"
  [ -z "$(ls -A "$EMPTY_SCRATCH")" ] || fail "empty destination value $empty_idx creates nothing in the working directory"
  [ ! -e "$EMPTY_HOME" ] || fail "empty destination value $empty_idx creates nothing in HOME"
done
pass "empty and whitespace OPENCODE_CONFIG values exit 1 and create nothing"

# 28. hostile and degenerate destinations are refused before any write
SRC_CK_BEFORE="$(cksum <"$ROOT/skills/oneshot/SKILL.md")"
UNSAFE_SCRATCH="$TMPROOT/unsafe-cwd"
UNSAFE_HOME="$TMPROOT/home-unsafe"
mkdir -p "$UNSAFE_SCRATCH" "$UNSAFE_HOME"
ln -sfn "$ROOT" "$TMPROOT/repo-link"
check_unsafe() {
  local label="$1" cwd="$2" val="$3" home="$4"
  shift 4
  local rc=0 out="$TMPROOT/case28.$label.out"
  ( cd "$cwd" && HOME="$home" OPENCODE_CONFIG="$val" "$INSTALL" "$@" ) >"$out" 2>&1 || rc=$?
  [ "$rc" -eq 1 ] || { cat "$out" >&2; fail "unsafe destination ($label) exits 1"; }
  grep -q 'install.sh: refusing unsafe destination' "$out" || { cat "$out" >&2; fail "unsafe destination ($label) is named"; }
}
check_unsafe slash "$UNSAFE_SCRATCH" "/" "$UNSAFE_HOME"
check_unsafe dot "$ROOT" "." "$UNSAFE_HOME" --force
UNSAFE_PARENT="$TMPROOT/unsafe-parent"
mkdir -p "$UNSAFE_PARENT/child"
check_unsafe dotdot "$UNSAFE_PARENT/child" ".." "$UNSAFE_HOME"
check_unsafe home "$UNSAFE_SCRATCH" "$UNSAFE_HOME" "$UNSAFE_HOME"
check_unsafe home-slash "$UNSAFE_SCRATCH" "$UNSAFE_HOME/" "$UNSAFE_HOME"
check_unsafe repo-root "$UNSAFE_SCRATCH" "$ROOT" "$UNSAFE_HOME" --force
check_unsafe repo-link "$UNSAFE_SCRATCH" "$TMPROOT/repo-link" "$UNSAFE_HOME"
[ -z "$(ls -A "$UNSAFE_SCRATCH")" ] || fail "unsafe destinations create nothing in the working directory"
[ "$SRC_CK_BEFORE" = "$(cksum <"$ROOT/skills/oneshot/SKILL.md")" ] || fail "unsafe destinations leave the source tree untouched"
[ -f "$ROOT/agents/scout.md" ] || fail "unsafe destinations leave the source agents intact"
pass "absolute, dotted, HOME, and repo-root destinations exit 1 and leave sources untouched"

# 29. a destination that exists as a regular file is refused
FILE_DEST="$TMPROOT/dest-file"
printf 'not-a-dir\n' >"$FILE_DEST"
rc29=0
HOME="$TMPROOT/home-filedest" OPENCODE_CONFIG="$FILE_DEST" "$INSTALL" >"$TMPROOT/case29.out" 2>&1 || rc29=$?
[ "$rc29" -eq 1 ] || { cat "$TMPROOT/case29.out" >&2; fail "file destination exits 1"; }
grep -q 'install.sh: destination is not a directory' "$TMPROOT/case29.out" || fail "file destination is named"
[ -f "$FILE_DEST" ] || fail "file destination is left in place"
[ "$(cat "$FILE_DEST")" = "not-a-dir" ] || fail "file destination content is untouched"
pass "destination pointing at a regular file exits 1"

# 30. a ./-prefixed manifest entry still counts as owned and is not pruned
[ -f "$DEST/skills/oneshot/SKILL.md" ] || fail "case30 starts from an installed SKILL.md"
printf './skills/oneshot/SKILL.md\n' >>"$MANIFEST"
rc30=0
HOME="$HOME_DIR" "$INSTALL" --force --prune >"$TMPROOT/case30.out" 2>&1 || rc30=$?
[ "$rc30" -eq 0 ] || { cat "$TMPROOT/case30.out" >&2; fail "prune with a ./-prefixed entry exits 0"; }
[ -f "$DEST/skills/oneshot/SKILL.md" ] || fail "./-prefixed manifest entry does not prune the just-installed file"
cmp -s "$ROOT/skills/oneshot/SKILL.md" "$DEST/skills/oneshot/SKILL.md" || fail "./-prefixed manifest entry leaves the installed file byte-identical"
grep -q 'pruned 0 stale file(s)' "$TMPROOT/case30.out" || fail "./-prefixed manifest entry prunes nothing"
# drop the appended line so the cases that follow see a clean manifest
CLEAN_MANIFEST="$TMPROOT/case30.manifest.clean"
grep -vxF -- './skills/oneshot/SKILL.md' "$MANIFEST" >"$CLEAN_MANIFEST" || :
cat "$CLEAN_MANIFEST" >"$MANIFEST"
if grep -qxF -- './skills/oneshot/SKILL.md' "$MANIFEST"; then
  fail "./-prefixed manifest line is removed after the case"
fi
[ -f "$DEST/skills/oneshot/SKILL.md" ] || fail "prune leaves the just-installed file in place"
pass "a ./-prefixed manifest entry does not prune the file this run installs"

# 31. NOTICE and LICENSE are installed with their own names preserved
[ -f "$DEST/NOTICE" ] || fail "NOTICE is installed"
[ -f "$DEST/LICENSE" ] || fail "LICENSE is installed"
cmp -s "$ROOT/NOTICE" "$DEST/NOTICE" || fail "NOTICE is byte-identical to the source"
cmp -s "$ROOT/LICENSE" "$DEST/LICENSE" || fail "LICENSE is byte-identical to the source"
grep -qx 'NOTICE' "$MANIFEST" || fail "manifest records NOTICE"
grep -qx 'LICENSE' "$MANIFEST" || fail "manifest records LICENSE"
pass "NOTICE and LICENSE are installed alongside the harness"

# 32. destinations nested inside the source checkout are refused and leave the
# source tree untouched, with or without --force
NESTED_SRC_BEFORE="$(find "$ROOT/agents" "$ROOT/skills" -type f -exec cksum {} + | sort)"
NESTED_SCRATCH="$TMPROOT/nested-dest-cwd"
NESTED_HOME="$TMPROOT/home-nested-dest"
mkdir -p "$NESTED_SCRATCH" "$NESTED_HOME"
check_unsafe nested-agents "$NESTED_SCRATCH" "$ROOT/agents" "$NESTED_HOME"
check_unsafe nested-skill "$NESTED_SCRATCH" "$ROOT/skills/oneshot" "$NESTED_HOME"
check_unsafe nested-agents-force "$NESTED_SCRATCH" "$ROOT/agents" "$NESTED_HOME" --force
grep -q 'inside the source checkout' "$TMPROOT/case28.nested-agents.out" || fail "source-nested destination names the reason"
grep -q 'inside the source checkout' "$TMPROOT/case28.nested-skill.out" || fail "skill-nested destination names the reason"
grep -q 'inside the source checkout' "$TMPROOT/case28.nested-agents-force.out" || fail "source-nested destination with --force names the reason"
NESTED_SRC_AFTER="$(find "$ROOT/agents" "$ROOT/skills" -type f -exec cksum {} + | sort)"
[ "$NESTED_SRC_BEFORE" = "$NESTED_SRC_AFTER" ] || fail "source-nested destinations leave the source tree untouched"
[ -z "$(ls -A "$NESTED_SCRATCH")" ] || fail "source-nested destinations create nothing in the working directory"
[ -z "$(ls -A "$NESTED_HOME")" ] || fail "source-nested destinations create nothing in HOME"
pass "destinations nested inside the source checkout exit 1 and leave sources untouched"

# 33. root aliases such as // and /. are refused before anything is created
ROOT_SCRATCH="$TMPROOT/root-alias-cwd"
ROOT_HOME="$TMPROOT/home-root-alias"
mkdir -p "$ROOT_SCRATCH" "$ROOT_HOME"
check_unsafe root-slashes "$ROOT_SCRATCH" "//" "$ROOT_HOME"
check_unsafe root-dot "$ROOT_SCRATCH" "/." "$ROOT_HOME"
check_unsafe root-dot-slash "$ROOT_SCRATCH" "/./" "$ROOT_HOME"
grep -q 'the filesystem root' "$TMPROOT/case28.root-dot.out" || fail "/. destination names the filesystem root"
grep -q 'the filesystem root' "$TMPROOT/case28.root-dot-slash.out" || fail "/./ destination names the filesystem root"
[ -z "$(ls -A "$ROOT_SCRATCH")" ] || fail "root alias destinations create nothing in the working directory"
[ -z "$(ls -A "$ROOT_HOME")" ] || fail "root alias destinations create nothing in HOME"
pass "root alias destinations // and /. exit 1 and create nothing"

# 34. a dangling destination symlink is refused before any mkdir
DANGLE_DIR="$TMPROOT/dangle"
DANGLE_TARGET="$DANGLE_DIR/missing-target"
DANGLE_LINK="$DANGLE_DIR/opencode"
DANGLE_HOME="$TMPROOT/home-dangle"
mkdir -p "$DANGLE_DIR" "$DANGLE_HOME"
ln -s "$DANGLE_TARGET" "$DANGLE_LINK"
[ -L "$DANGLE_LINK" ] || fail "dangling case starts from a symlink"
rc34=0
HOME="$DANGLE_HOME" OPENCODE_CONFIG="$DANGLE_LINK" "$INSTALL" >"$TMPROOT/case34.out" 2>&1 || rc34=$?
[ "$rc34" -eq 1 ] || { cat "$TMPROOT/case34.out" >&2; fail "dangling destination symlink exits 1"; }
grep -q 'install.sh: destination symlink is dangling' "$TMPROOT/case34.out" || fail "dangling destination symlink is named"
[ -L "$DANGLE_LINK" ] || fail "dangling destination symlink is left in place"
[ ! -e "$DANGLE_TARGET" ] || fail "dangling destination symlink target is not created"
[ -z "$(ls -A "$DANGLE_HOME")" ] || fail "dangling destination symlink creates nothing in HOME"
pass "a dangling destination symlink exits 1 before any mkdir"

# 35. a destination containing a .. path component is refused before resolution
DOTDOT_HOME="$TMPROOT/home-dotdot"
mkdir -p "$DOTDOT_HOME"
rc35=0
HOME="$DOTDOT_HOME" OPENCODE_CONFIG="$TMPROOT/missing/../evil" "$INSTALL" >"$TMPROOT/case35.out" 2>&1 || rc35=$?
[ "$rc35" -eq 1 ] || { cat "$TMPROOT/case35.out" >&2; fail "dotdot destination exits 1"; }
grep -q 'install.sh: refusing unsafe destination:' "$TMPROOT/case35.out" || fail "dotdot destination is named"
[ ! -e "$TMPROOT/missing" ] || fail "dotdot destination does not create missing parent"
[ ! -e "$TMPROOT/evil" ] || fail "dotdot destination does not create target directory"
[ -z "$(ls -A "$DOTDOT_HOME")" ] || fail "dotdot destination creates nothing in HOME"
pass "a destination containing a .. component exits 1 and creates nothing"

# 36. a non-regular-file .harness-manifest (e.g. a directory) is refused before copying anything
rm -f "$MANIFEST"
mkdir -p "$MANIFEST"
printf 'keep\n' >"$MANIFEST/inside.md"
rm -f "$DEST/skills/oneshot/SKILL.md"
find "$DEST" -type f -exec cksum {} + | sort >"$TMPROOT/case36.snap"
rc36=0
HOME="$HOME_DIR" "$INSTALL" --force >"$TMPROOT/case36.out" 2>&1 || rc36=$?
[ "$rc36" -eq 1 ] || { cat "$TMPROOT/case36.out" >&2; fail "directory at .harness-manifest with --force exits 1"; }
grep -q 'install.sh: manifest path is not a regular file:' "$TMPROOT/case36.out" || fail "non-regular manifest path is named"
[ -d "$MANIFEST" ] || fail "manifest directory is left in place"
[ ! -e "$DEST/skills/oneshot/SKILL.md" ] || fail "non-regular manifest run copies nothing before aborting"
find "$DEST" -type f -exec cksum {} + | sort >"$TMPROOT/case36.after"
cmp -s "$TMPROOT/case36.snap" "$TMPROOT/case36.after" || fail "non-regular manifest run leaves destination files untouched"
rm -f "$MANIFEST/inside.md"
rmdir "$MANIFEST"
rc36b=0
HOME="$HOME_DIR" "$INSTALL" --force --profile tri >"$TMPROOT/case36b.out" 2>&1 || rc36b=$?
[ "$rc36b" -eq 0 ] || { cat "$TMPROOT/case36b.out" >&2; fail "restore after manifest directory case exits 0"; }
pass "a directory at .harness-manifest exits 1 before copying anything"

# 37. ./, .///, and <symlink-to-src>/missing/./sub are refused with exit 1 and create nothing
DOT_SCRATCH="$TMPROOT/dot-scratch"
DOT_HOME="$TMPROOT/home-dot"
mkdir -p "$DOT_SCRATCH" "$DOT_HOME"
ln -sfn "$ROOT" "$TMPROOT/src-link"
check_unsafe dot-slash "$DOT_SCRATCH" "./" "$DOT_HOME"
check_unsafe dot-multislash "$DOT_SCRATCH" ".///" "$DOT_HOME"
check_unsafe link-interior-dot "$DOT_SCRATCH" "$TMPROOT/src-link/missing/./sub" "$DOT_HOME"
grep -q 'inside the source checkout' "$TMPROOT/case28.link-interior-dot.out" || fail "symlinked source path with interior /./ names inside the source checkout"
[ ! -e "$ROOT/missing" ] || fail "symlinked source path with interior /./ creates nothing in source checkout"
[ -z "$(ls -A "$DOT_SCRATCH")" ] || fail "./ and interior /./ destinations create nothing in the working directory"
[ -z "$(ls -A "$DOT_HOME")" ] || fail "./ and interior /./ destinations create nothing in HOME"
pass "./ and <symlink-to-src>/missing/./sub exit 1 and create nothing"

# 38. default tri binding and native pins
cmp -s "$ROOT/providers/tri.md" "$DEST/PROVIDERS.md" || fail "default selects tri"
grep -qx 'PROVIDERS.md' "$MANIFEST" || fail "manifest owns PROVIDERS.md"
[ "$(sed -n '2p' "$MANIFEST")" = '# profile tri' ] || fail "manifest line 2 names tri"
if grep -q '^model:' "$DEST/agents/implementer-deep.md"; then
  fail "tri implementer-deep has no native pin"
fi
grep -qxF 'note: implementer-deep has no opencode rung; dispatch it through delegate_task only' "$TMPROOT/case1.out" || fail "tri reports delegate-only seat"
grep -qxF 'model: opencode-go/gemini-4-argon#high' "$DEST/agents/implementer.md" || fail "tri implementer uses its OpenCode fallback"
pass "default tri profile, manifest metadata, native pin and delegate-only note"

# 39. legacy profile preserves historical pin values and line positions
LEGACY_DEST="$TMPROOT/legacy-install"
OPENCODE_CONFIG="$LEGACY_DEST" "$INSTALL" --profile opencode-go >"$TMPROOT/legacy.out"
while IFS="$(printf '\t')" read -r seat line model; do
  installed="$LEGACY_DEST/agents/$seat.md"
  [ "$(sed -n "${line}p" "$installed")" = "$model" ] || fail "historical pin position: $seat"
  [ "$(grep -c '^model: ' "$installed")" -eq 1 ] || fail "one model line: $seat"
  awk -v line="$line" 'NR != line' "$installed" >"$TMPROOT/without-pin"
  cmp -s "$ROOT/agents/$seat.md" "$TMPROOT/without-pin" || fail "current source body: $seat"
done <"$ROOT/test/fixtures/legacy-pins.txt"
cmp -s "$ROOT/providers/opencode-go.md" "$LEGACY_DEST/PROVIDERS.md" || fail "legacy profile is byte copied"
[ "$(sed -n '2p' "$LEGACY_DEST/.harness-manifest")" = '# profile opencode-go' ] || fail "legacy metadata"
pass "opencode-go preserves all nine historical pins and current source bodies"

# 40. both flag forms bind the same profile
OPENCODE_CONFIG="$LEGACY_DEST" "$INSTALL" --force --profile=opencode-go >"$TMPROOT/equals.out"
cmp -s "$ROOT/providers/opencode-go.md" "$LEGACY_DEST/PROVIDERS.md" || fail "equals flag binds legacy profile"
pass "--profile=NAME is accepted"

# 41. unknown and malformed names fail before any write, even with force/prune
for profile in missing ../tri Tri 'tri/name' '-tri' 'tri.bad'; do
  rc=0
  OPENCODE_CONFIG="$TMPROOT/unknown-dest" "$INSTALL" --force --prune --profile="$profile" >"$TMPROOT/unknown.out" 2>"$TMPROOT/unknown.err" || rc=$?
  [ "$rc" -eq 2 ] || fail "unknown profile exits 2: $profile"
  grep -qF "install.sh: unknown profile: $profile (available: opencode-go tri)" "$TMPROOT/unknown.err" || fail "unknown profile diagnostic: $profile"
  [ ! -e "$TMPROOT/unknown-dest" ] || fail "unknown profile creates nothing"
done
pass "unknown and malformed profiles exit 2 and write nothing"

# 42. isolated installer fixture exercises validation without mutating the repo
FIXTURE="$TMPROOT/profile-fixture"
mkdir -p "$FIXTURE/providers"
cp "$INSTALL" "$FIXTURE/install.sh"
for defect in missing-primary invalid-rung; do
  if [ "$defect" = missing-primary ]; then
    awk '!/^[|] implementer-deep [|] primary [|]/' "$ROOT/providers/tri.md" >"$FIXTURE/providers/broken.md"
  else
    sed 's/| implementer-deep | fallback |/| implementer-deep | bogus |/' "$ROOT/providers/tri.md" >"$FIXTURE/providers/broken.md"
  fi
  rc=0
  OPENCODE_CONFIG="$TMPROOT/incomplete-dest" "$FIXTURE/install.sh" --force --prune --profile broken >"$TMPROOT/incomplete.out" 2>"$TMPROOT/incomplete.err" || rc=$?
  [ "$rc" -eq 1 ] || fail "incomplete profile exits 1: $defect"
  if [ "$defect" = missing-primary ]; then
    diagnostic='install.sh: profile broken incomplete: implementer-deep'
  else
    diagnostic='install.sh: profile broken invalid row: implementer-deep bogus: invalid rung'
  fi
  grep -qxF "$diagnostic" "$TMPROOT/incomplete.err" || fail "incomplete diagnostic: $defect"
  [ ! -e "$TMPROOT/incomplete-dest" ] || fail "incomplete profile writes nothing"
done
pass "missing primary and invalid rung exit 1 before any write"

# 43. PROVIDERS.md follows normal collision, force, symlink and prune rules
PROFILE_DEST="$TMPROOT/profile-dest"
mkdir -p "$PROFILE_DEST"
printf 'keep\n' >"$PROFILE_DEST/PROVIDERS.md"
rc=0
OPENCODE_CONFIG="$PROFILE_DEST" "$INSTALL" >"$TMPROOT/profile-collision.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || fail "profile collision exits 1"
[ ! -e "$PROFILE_DEST/agents" ] || fail "profile collision aborts before copying"
[ "$(cat "$PROFILE_DEST/PROVIDERS.md")" = keep ] || fail "profile collision preserves content"
rm -f "$PROFILE_DEST/PROVIDERS.md"
printf 'outside\n' >"$TMPROOT/outside-profile.md"
ln -s "$TMPROOT/outside-profile.md" "$PROFILE_DEST/PROVIDERS.md"
OPENCODE_CONFIG="$PROFILE_DEST" "$INSTALL" --force >"$TMPROOT/profile-force.out"
[ "$(cat "$TMPROOT/outside-profile.md")" = outside ] || fail "profile force preserves symlink target"
[ ! -L "$PROFILE_DEST/PROVIDERS.md" ] || fail "profile force unlinks symlink"
OPENCODE_CONFIG="$PROFILE_DEST" "$INSTALL" --force --prune --profile opencode-go >"$TMPROOT/profile-prune.out"
cmp -s "$ROOT/providers/opencode-go.md" "$PROFILE_DEST/PROVIDERS.md" || fail "profile switch survives prune"
[ ! -e "$PROFILE_DEST/providers" ] || fail "profiles directory is not installed"
pass "PROVIDERS.md respects collision, force, symlink and prune rules"

# 44. every required role is validated (including the ad-hoc task reviewer)
for role in scout implementer implementer-deep patch tester reviewer-a reviewer-b reviewer-c reviewer-esc task-reviewer; do
  awk -F '|' -v role="$role" '!($2 == " " role " " && $3 == " primary ")' "$ROOT/providers/tri.md" >"$FIXTURE/providers/broken.md"
  rc=0
  OPENCODE_CONFIG="$TMPROOT/incomplete-dest" "$FIXTURE/install.sh" --profile broken >"$TMPROOT/role.out" 2>"$TMPROOT/role.err" || rc=$?
  [ "$rc" -eq 1 ] || fail "missing primary for $role exits 1"
  grep -qxF "install.sh: profile broken incomplete: $role" "$TMPROOT/role.err" || fail "missing primary names $role"
  [ ! -e "$TMPROOT/incomplete-dest" ] || fail "missing $role creates nothing"
done
pass "all ten required roles must have a primary rung"

# 45. table order cannot override ladder order; unrelated rows are ignored
cp -R "$ROOT/agents" "$FIXTURE/agents"
mkdir -p "$FIXTURE/skills"
cp "$ROOT/NOTICE" "$ROOT/LICENSE" "$FIXTURE/"
printf 'fixture harness\n' >"$FIXTURE/AGENTS.md"
awk '
  /^[|] (scout|implementer|implementer-deep|patch|tester|reviewer-a|reviewer-b|reviewer-c|reviewer-esc|task-reviewer) [|]/ { rows[++n] = $0; next }
  { print }
  END { for (i = n; i >= 1; i--) print rows[i] }
' "$ROOT/providers/opencode-go.md" >"$FIXTURE/providers/reordered.md"
printf '| unknown-role | bogus | ignored |\n' >>"$FIXTURE/providers/reordered.md"
OPENCODE_CONFIG="$TMPROOT/reordered-dest" "$FIXTURE/install.sh" --profile reordered >"$TMPROOT/reordered.out"
for expected in "$TMPROOT/legacy-agents/"*.md; do
  cmp -s "$expected" "$TMPROOT/reordered-dest/agents/${expected##*/}" || fail "reordered ladder: ${expected##*/}"
done
pass "native pins follow ladder order and parser ignores unknown roles"

# Hostile rows are added to a temporary source tree, never the checkout.
snapshot() { find "$1" -type f -exec cksum {} + | LC_ALL=C sort; }
REJECT_DEST="$TMPROOT/reject-dest"
mkdir -p "$REJECT_DEST"
printf 'sentinel\n' >"$REJECT_DEST/keep"
reject_unchanged() {
  local expected_rc="$1" diagnostic="$2" rc=0
  shift 2
  snapshot "$REJECT_DEST" >"$TMPROOT/reject.before"
  find "$REJECT_DEST" -print | LC_ALL=C sort >"$TMPROOT/reject.paths.before"
  OPENCODE_CONFIG="$REJECT_DEST" "$FIXTURE/install.sh" --force --prune "$@" >"$TMPROOT/reject.out" 2>"$TMPROOT/reject.err" || rc=$?
  [ "$rc" -eq "$expected_rc" ] || { cat "$TMPROOT/reject.err" >&2; fail "rejection status: $diagnostic"; }
  case "$diagnostic" in
    'install.sh: profile '*)
      grep -qxF "$diagnostic" "$TMPROOT/reject.err" || { cat "$TMPROOT/reject.err" >&2; fail "rejection diagnostic: $diagnostic"; } ;;
    *) grep -qF "$diagnostic" "$TMPROOT/reject.err" || { cat "$TMPROOT/reject.err" >&2; fail "rejection diagnostic: $diagnostic"; } ;;
  esac
  snapshot "$REJECT_DEST" >"$TMPROOT/reject.after"
  find "$REJECT_DEST" -print | LC_ALL=C sort >"$TMPROOT/reject.paths.after"
  cmp -s "$TMPROOT/reject.before" "$TMPROOT/reject.after" || fail "rejection changed files"
  cmp -s "$TMPROOT/reject.paths.before" "$TMPROOT/reject.paths.after" || fail "rejection changed paths"
}
while IFS=';' read -r label row reason; do
  cp "$ROOT/providers/opencode-go.md" "$FIXTURE/providers/evil.md"
  printf '%s\n' "$row" >>"$FIXTURE/providers/evil.md"
  reject_unchanged 1 "install.sh: profile evil invalid row: scout fallback: $reason" --profile evil
  pass "hostile profile rejected without writes: $label"
done <"$ROOT/test/fixtures/hostile-profile-rows.txt"
cp "$ROOT/providers/opencode-go.md" "$FIXTURE/providers/evil.md"
printf '| scout | primary | opencode | valid | - | google | ok |\n' >>"$FIXTURE/providers/evil.md"
reject_unchanged 1 'install.sh: profile evil invalid row: scout primary: duplicate rung' --profile evil
pass "duplicate primary is rejected without writes"
cp "$ROOT/providers/opencode-go.md" "$FIXTURE/providers/evil.md"
printf '| reviewer-a | last-resort | opencode | valid | - | - | ok |\n' >>"$FIXTURE/providers/evil.md"
reject_unchanged 1 'install.sh: profile evil invalid row: reviewer-a last-resort: invalid family' --profile evil
pass "council seat rejects placeholder family without writes"
cp "$ROOT/providers/opencode-go.md" "$FIXTURE/providers/evil.md"
printf '| driver | fallback | - | host-default | - | - | typo |\n' >>"$FIXTURE/providers/evil.md"
reject_unchanged 1 'install.sh: profile evil invalid row: driver fallback: invalid privacy' --profile evil
pass "advisory rows are validated without writes"
# Fenced examples must not participate, including duplicates and malformed rows.
cp "$ROOT/providers/opencode-go.md" "$FIXTURE/providers/fenced.md"
cat >>"$FIXTURE/providers/fenced.md" <<'FENCE'
```markdown
| scout | primary | opencode | x\n--- | - | google | ok |
| driver | bogus | ignored |
```
FENCE
OPENCODE_CONFIG="$TMPROOT/fenced-dest" "$FIXTURE/install.sh" --profile fenced >"$TMPROOT/fenced.out"
pass "fenced routing examples are ignored"

cp "$ROOT/providers/opencode-go.md" "$FIXTURE/providers/evil.md"
# Body text cannot supply a missing frontmatter insertion point.
sed '/^mode: subagent$/d' "$ROOT/agents/scout.md" >"$FIXTURE/agents/scout.md"
printf '\nmode: subagent\n' >>"$FIXTURE/agents/scout.md"
reject_unchanged 1 'install.sh: cannot insert native pin: scout' --profile evil
cp "$ROOT/agents/scout.md" "$FIXTURE/agents/scout.md"
pass "missing frontmatter mode refuses before writes despite a body match"
# Only the first frontmatter mode gets a pin; later blocks/body remain intact.
printf '\n---\nmode: subagent\n---\nmode: subagent\n' >>"$FIXTURE/agents/scout.md"
OPENCODE_CONFIG="$TMPROOT/frontmatter-dest" "$FIXTURE/install.sh" --profile evil >"$TMPROOT/frontmatter.out"
[ "$(grep -c '^model: ' "$TMPROOT/frontmatter-dest/agents/scout.md")" -eq 1 ] || fail "frontmatter pin inserted only once"
cp "$ROOT/agents/scout.md" "$FIXTURE/agents/scout.md"
pass "pin insertion is confined to first frontmatter block"

reject_unchanged 2 'usage: install.sh' --profile
reject_unchanged 2 'usage: install.sh' --profile ''
reject_unchanged 2 'usage: install.sh' --profile=
pass "missing and empty profile arguments show usage without writes"

OPENCODE_CONFIG="$LEGACY_DEST" "$INSTALL" --force >"$TMPROOT/reuse.out"
cmp -s "$ROOT/providers/opencode-go.md" "$LEGACY_DEST/PROVIDERS.md" || fail "implicit reuse retains opencode-go"
pass "implicit profile reuses previous manifest binding"
OPENCODE_CONFIG="$LEGACY_DEST" "$INSTALL" --force --profile tri >"$TMPROOT/change.out"
grep -qxF 'profile changed: opencode-go -> tri' "$TMPROOT/change.out" || fail "explicit profile change announced"
pass "explicit profile change is announced"
printf '# profile removed\n' >"$REJECT_DEST/.harness-manifest"
reject_unchanged 2 'install.sh: unknown profile: removed'
pass "removed implicit profile refuses without writes"

# A pre-profile manifest is the historical opencode-go binding, not a fresh install.
for selection in implicit explicit; do
  PREPROFILE_DEST="$TMPROOT/preprofile-$selection"
  mkdir -p "$PREPROFILE_DEST"
  printf '# harness old-revision\nagents/scout.md\n' >"$PREPROFILE_DEST/.harness-manifest"
  if [ "$selection" = implicit ]; then
    OPENCODE_CONFIG="$PREPROFILE_DEST" "$INSTALL" --force >"$TMPROOT/preprofile.out"
    expected_profile=opencode-go
    expected_message='profile: opencode-go (previous install predates profiles)'
  else
    OPENCODE_CONFIG="$PREPROFILE_DEST" "$INSTALL" --force --profile tri >"$TMPROOT/preprofile.out"
    expected_profile=tri
    expected_message='profile changed: opencode-go -> tri'
  fi
  cmp -s "$ROOT/providers/$expected_profile.md" "$PREPROFILE_DEST/PROVIDERS.md" || fail "pre-profile $selection binding"
  grep -qxF "# profile $expected_profile" "$PREPROFILE_DEST/.harness-manifest" || fail "pre-profile $selection metadata"
  grep -qxF "$expected_message" "$TMPROOT/preprofile.out" || fail "pre-profile $selection announcement"
  pass "pre-profile manifest respects $selection selection"
done

# Older installs may have a headerless manifest or no manifest at all.
for legacy_kind in headerless premanifest; do
  OLD_DEST="$TMPROOT/old-$legacy_kind"
  mkdir -p "$OLD_DEST"
  if [ "$legacy_kind" = headerless ]; then
    printf 'agents/scout.md\n' >"$OLD_DEST/.harness-manifest"
  else
    printf 'old harness\n' >"$OLD_DEST/HARNESS.md"
  fi
  OPENCODE_CONFIG="$OLD_DEST" "$INSTALL" --force >"$TMPROOT/old.out"
  [ "$(sed -n '2p' "$OLD_DEST/.harness-manifest")" = '# profile opencode-go' ] || fail "$legacy_kind metadata"
  grep -qxF 'model: opencode-go/muse-spark-1.3-contributor#xhigh' "$OLD_DEST/agents/reviewer-a.md" || fail "$legacy_kind pin"
  grep -qxF 'profile: opencode-go (previous install predates profiles)' "$TMPROOT/old.out" || fail "$legacy_kind announcement"
  pass "$legacy_kind preserves historical profile"
done

# Advisory placeholders are valid when present and do not affect native pins.
awk '!/^[|] (driver|compaction) [|]/' "$ROOT/providers/opencode-go.md" >"$FIXTURE/providers/advisory.md"
printf '| driver | primary | - | - | - | - | ok |\n| compaction | primary | - | - | - | - | ok |\n' >>"$FIXTURE/providers/advisory.md"
OPENCODE_CONFIG="$TMPROOT/advisory-dest" "$FIXTURE/install.sh" --profile advisory >"$TMPROOT/advisory.out"
for expected in "$TMPROOT/legacy-agents/"*.md; do
  cmp -s "$expected" "$TMPROOT/advisory-dest/agents/${expected##*/}" || fail "advisory placeholders affect pin: ${expected##*/}"
done
pass "advisory placeholders are accepted without rendering"
awk '!/^[|] (driver|compaction) [|]/' "$ROOT/providers/opencode-go.md" >"$FIXTURE/providers/no-advisory.md"
OPENCODE_CONFIG="$TMPROOT/no-advisory-dest" "$FIXTURE/install.sh" --profile no-advisory >"$TMPROOT/no-advisory.out"
pass "advisory rows remain optional"

# 46. tester is a required role, validated like every other seat
awk '!/^[|] tester [|] primary [|]/' "$ROOT/providers/tri.md" >"$FIXTURE/providers/broken.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/tester-required-dest" "$FIXTURE/install.sh" --profile broken >"$TMPROOT/tester-required.out" 2>"$TMPROOT/tester-required.err" || rc=$?
[ "$rc" -eq 1 ] || fail "a profile without a tester primary exits 1"
grep -qxF 'install.sh: profile broken incomplete: tester' "$TMPROOT/tester-required.err" || fail "missing tester primary is named"
[ ! -e "$TMPROOT/tester-required-dest" ] || fail "missing tester primary writes nothing"
pass "tester is a required role"

# 47. implementer-b is gone and its rows are optional
REBAL_DEST="$TMPROOT/rebalance-default"
rc=0
OPENCODE_CONFIG="$REBAL_DEST" "$INSTALL" >"$TMPROOT/rebalance-default.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/rebalance-default.out" >&2; fail "default tri install exits 0"; }
[ ! -e "$REBAL_DEST/agents/implementer-b.md" ] || fail "no implementer-b agent is installed"
if grep -qxF 'agents/implementer-b.md' "$REBAL_DEST/.harness-manifest"; then
  fail "the manifest does not record implementer-b"
fi
awk '!/^[|] implementer-b [|]/' "$ROOT/providers/tri.md" >"$TMPROOT/no-implementer-b.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/no-implementer-b-dest" "$INSTALL" --profile-file "$TMPROOT/no-implementer-b.md" >"$TMPROOT/no-implementer-b.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || fail "a profile without implementer-b rows is valid"
pass "implementer-b is neither installed nor required"

# 48. --profile-file binds an external file and records its absolute path
PF_DIR="$TMPROOT/profile-file"
mkdir -p "$PF_DIR"
{ cat "$ROOT/providers/tri.md"; printf '\n# user-local copy\n'; } >"$PF_DIR/custom.md"
PF_ABS="$(cd "$PF_DIR" && pwd -P)/custom.md"
PF_DEST="$TMPROOT/profile-file-dest"
rc=0
OPENCODE_CONFIG="$PF_DEST" "$INSTALL" --profile-file "$PF_ABS" >"$TMPROOT/profile-file.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/profile-file.out" >&2; fail "--profile-file install exits 0"; }
cmp -s "$PF_ABS" "$PF_DEST/PROVIDERS.md" || fail "PROVIDERS.md is a byte copy of the profile file"
[ "$(sed -n '2p' "$PF_DEST/.harness-manifest")" = "# profile-file $PF_ABS" ] || fail "manifest line 2 records the profile file path"
PF_REL_DEST="$TMPROOT/profile-file-rel-dest"
rc=0
( cd "$PF_DIR" && OPENCODE_CONFIG="$PF_REL_DEST" "$INSTALL" --profile-file custom.md ) >"$TMPROOT/profile-file-rel.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/profile-file-rel.out" >&2; fail "relative --profile-file install exits 0"; }
cmp -s "$PF_ABS" "$PF_REL_DEST/PROVIDERS.md" || fail "relative profile file is byte copied"
[ "$(sed -n '2p' "$PF_REL_DEST/.harness-manifest")" = "# profile-file $PF_ABS" ] || fail "relative profile file is recorded as absolute"
pass "--profile-file binds, copies and records an absolute path"

# 49. refresh reuses a recorded profile file; a missing file is fatal
rc=0
OPENCODE_CONFIG="$PF_DEST" "$INSTALL" --force >"$TMPROOT/profile-reuse.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/profile-reuse.out" >&2; fail "refresh with a recorded profile file exits 0"; }
cmp -s "$PF_ABS" "$PF_DEST/PROVIDERS.md" || fail "refresh without flags reuses the recorded profile file"
[ "$(sed -n '2p' "$PF_DEST/.harness-manifest")" = "# profile-file $PF_ABS" ] || fail "refresh keeps the profile file binding"
find "$PF_DEST" -type f -exec cksum {} + | sort >"$TMPROOT/profile-missing.snap"
rm -f -- "$PF_ABS"
rc=0
OPENCODE_CONFIG="$PF_DEST" "$INSTALL" --force >"$TMPROOT/profile-missing.out" 2>"$TMPROOT/profile-missing.err" || rc=$?
[ "$rc" -eq 2 ] || { cat "$TMPROOT/profile-missing.err" >&2; fail "a deleted profile file exits 2"; }
grep -qxF "install.sh: profile file not found: $PF_ABS" "$TMPROOT/profile-missing.err" || fail "a deleted profile file is named"
find "$PF_DEST" -type f -exec cksum {} + | sort >"$TMPROOT/profile-missing.after"
cmp -s "$TMPROOT/profile-missing.snap" "$TMPROOT/profile-missing.after" || fail "a deleted profile file writes nothing"
pass "refresh reuses the binding and a missing profile file is fatal"

# 50. --profile-file conflicts with --profile and is validated like a named profile
PF_X="$PF_DIR/mutex.md"
cp "$ROOT/providers/tri.md" "$PF_X"
rc=0
OPENCODE_CONFIG="$TMPROOT/profile-mutex-dest" "$INSTALL" --profile tri --profile-file "$PF_X" >"$TMPROOT/profile-mutex.out" 2>"$TMPROOT/profile-mutex.err" || rc=$?
[ "$rc" -eq 2 ] || { cat "$TMPROOT/profile-mutex.err" >&2; fail "--profile with --profile-file exits 2"; }
[ ! -e "$TMPROOT/profile-mutex-dest" ] || fail "--profile with --profile-file writes nothing"
PF_BAD="$PF_DIR/invalid.md"
cp "$ROOT/providers/tri.md" "$PF_BAD"
printf '| scout | last-resort | opencode | valid | - | google | typo |\n' >>"$PF_BAD"
rc=0
OPENCODE_CONFIG="$TMPROOT/profile-invalid-dest" "$INSTALL" --profile-file "$PF_BAD" >"$TMPROOT/profile-invalid.out" 2>"$TMPROOT/profile-invalid.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/profile-invalid.err" >&2; fail "an invalid profile file exits 1"; }
grep -q 'invalid row: scout last-resort: invalid privacy' "$TMPROOT/profile-invalid.err" || fail "an invalid profile file gets the named-profile diagnostic"
[ ! -e "$TMPROOT/profile-invalid-dest" ] || fail "an invalid profile file writes nothing"
pass "--profile-file conflicts with --profile and shares named-profile validation"

# 51. the default tri profile renders the rebalanced native pins
PINS_DEST="$TMPROOT/rebalance-pins"
rc=0
OPENCODE_CONFIG="$PINS_DEST" "$INSTALL" >"$TMPROOT/pins.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/pins.out" >&2; fail "fresh tri install exits 0"; }
grep -qxF 'model: opencode-go/mimo-v2.6-flash' "$PINS_DEST/agents/scout.md" || fail "tri scout pin"
grep -qxF 'model: opencode-go/gemini-4-argon#high' "$PINS_DEST/agents/implementer.md" || fail "tri implementer pin"
grep -qxF 'model: opencode-go/deepseek-v4.1-flash#high' "$PINS_DEST/agents/tester.md" || fail "tri tester pin"
grep -qxF 'model: opencode-go/kimi-k3.1-pro#high' "$PINS_DEST/agents/reviewer-a.md" || fail "tri reviewer-a pin"
grep -qxF 'model: opencode-go/deepseek-v4-pro' "$PINS_DEST/agents/reviewer-esc.md" || fail "tri reviewer-esc pin"
if grep -q '^model:' "$PINS_DEST/agents/implementer-deep.md"; then
  fail "tri implementer-deep has no native pin"
fi
grep -qxF 'note: implementer-deep has no opencode rung; dispatch it through delegate_task only' "$TMPROOT/pins.out" || fail "tri reports the delegate-only seat"
pass "default tri renders the rebalanced native pins"

printf 'all install tests passed (%d passed, 0 failed)\n' "$passed"
