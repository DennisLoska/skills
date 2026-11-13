#!/usr/bin/env bash
# test/install.sh - contract tests for install.sh
# Uses a throwaway HOME under a scratch dir; never touches the real config.
set -euo pipefail
export LC_ALL=C
unset OPENCODE_CONFIG CODEX_HOME ANTIGRAVITY_CONFIG CLAUDE_CONFIG_DIR T3_USERDATA_DIR

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
implementer -
implementer-deep -
patch opencode-go/deepseek-v4.1-flash#high
tester opencode-go/deepseek-v4.1-flash#high
reviewer-a -
reviewer-b -
reviewer-c -
PINS

# expected_profile <source> [tracker]: path of the PROVIDERS.md an install of
# <source> renders: the source without trailing blank lines, then a trailing
# "## Project management" section naming the backlog tracker (default auto).
expected_profile() {
  local src="$1" pm="${2:-auto}" out
  out="$TMPROOT/expected-profile.$(printf '%s|%s' "$src" "$pm" | cksum | cut -d' ' -f1).md"
  awk '
    { line[NR] = $0; if ($0 !~ /^[[:space:]]*$/) last = NR }
    END { for (i = 1; i <= last; i++) print line[i] }
  ' "$src" >"$out"
  printf '\n## Project management\n\nbacklog_tracker: %s\n' "$pm" >>"$out"
  printf '%s' "$out"
}

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
    src="$(expected_profile "$ROOT/providers/tri.md")"
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
cmp -s "$(expected_profile "$ROOT/providers/tri.md")" "$DEST/PROVIDERS.md" || fail "default selects tri"
grep -qx 'PROVIDERS.md' "$MANIFEST" || fail "manifest owns PROVIDERS.md"
[ "$(sed -n '2p' "$MANIFEST")" = '# profile tri' ] || fail "manifest line 2 names tri"
grep -qxF 'model: opencode-go/mimo-v2.6-flash' "$DEST/agents/scout.md" || fail "tri scout pin"
grep -qxF 'model: opencode-go/deepseek-v4.1-flash#high' "$DEST/agents/tester.md" || fail "tri tester pin"
grep -qxF 'model: opencode-go/deepseek-v4.1-flash#high' "$DEST/agents/patch.md" || fail "tri patch pin"
[ ! -e "$DEST/agents/reviewer-esc.md" ] || fail "tri installs no retired reviewer-esc seat"
for seat in implementer implementer-deep reviewer-a reviewer-b reviewer-c; do
  if grep -q '^model:' "$DEST/agents/$seat.md"; then
    fail "tri $seat has no native pin"
  fi
  grep -qxF "note: $seat has no opencode rung; dispatch it through delegate_task only" "$TMPROOT/case1.out" || fail "tri reports the $seat delegate-only seat"
done
pass "default tri profile, manifest metadata, Revision 3 native pins and delegate-only notes"

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
cmp -s "$(expected_profile "$ROOT/providers/opencode-go.md")" "$LEGACY_DEST/PROVIDERS.md" || fail "legacy profile is byte copied"
[ "$(sed -n '2p' "$LEGACY_DEST/.harness-manifest")" = '# profile opencode-go' ] || fail "legacy metadata"
for seat in implementer implementer-deep reviewer-a reviewer-b reviewer-c; do
  cmp -s "$ROOT/agents/$seat.md" "$LEGACY_DEST/agents/$seat.md" || fail "opencode-go leaves the delegate-only $seat seat unpinned"
done
[ ! -e "$LEGACY_DEST/agents/reviewer-esc.md" ] || fail "opencode-go installs no retired reviewer-esc seat"
pass "opencode-go preserves the scout, tester and patch pins and leaves delegate-only seats unpinned"

# 40. both flag forms bind the same profile
OPENCODE_CONFIG="$LEGACY_DEST" "$INSTALL" --force --profile=opencode-go >"$TMPROOT/equals.out"
cmp -s "$(expected_profile "$ROOT/providers/opencode-go.md")" "$LEGACY_DEST/PROVIDERS.md" || fail "equals flag binds legacy profile"
pass "--profile=NAME is accepted"

# 41. unknown and malformed names fail before any write, even with force/prune
for profile in missing ../tri Tri 'tri/name' '-tri' 'tri.bad'; do
  rc=0
  OPENCODE_CONFIG="$TMPROOT/unknown-dest" "$INSTALL" --force --prune --profile="$profile" >"$TMPROOT/unknown.out" 2>"$TMPROOT/unknown.err" || rc=$?
  [ "$rc" -eq 2 ] || fail "unknown profile exits 2: $profile"
  grep -qF "install.sh: unknown profile: $profile (available: antigravity claude codex opencode-go quad tri)" "$TMPROOT/unknown.err" || fail "unknown profile diagnostic: $profile"
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
cmp -s "$(expected_profile "$ROOT/providers/opencode-go.md")" "$PROFILE_DEST/PROVIDERS.md" || fail "profile switch survives prune"
[ ! -e "$PROFILE_DEST/providers" ] || fail "profiles directory is not installed"
pass "PROVIDERS.md respects collision, force, symlink and prune rules"

# 44. every required role is validated (including the ad-hoc task reviewer)
for role in scout implementer implementer-deep patch tester reviewer-a reviewer-b reviewer-c task-reviewer; do
  awk -F '|' -v role="$role" '!($2 == " " role " " && $3 == " primary ")' "$ROOT/providers/tri.md" >"$FIXTURE/providers/broken.md"
  rc=0
  OPENCODE_CONFIG="$TMPROOT/incomplete-dest" "$FIXTURE/install.sh" --profile broken >"$TMPROOT/role.out" 2>"$TMPROOT/role.err" || rc=$?
  [ "$rc" -eq 1 ] || fail "missing primary for $role exits 1"
  grep -qxF "install.sh: profile broken incomplete: $role" "$TMPROOT/role.err" || fail "missing primary names $role"
  [ ! -e "$TMPROOT/incomplete-dest" ] || fail "missing $role creates nothing"
done
pass "all nine required roles (reviewer-c included) must have a primary rung"

# 45. table order cannot override ladder order; unrelated rows are ignored
cp -R "$ROOT/agents" "$FIXTURE/agents"
mkdir -p "$FIXTURE/skills"
cp "$ROOT/NOTICE" "$ROOT/LICENSE" "$FIXTURE/"
printf 'fixture harness\n' >"$FIXTURE/AGENTS.md"
awk '
  /^[|] (scout|implementer|implementer-deep|patch|tester|reviewer-a|reviewer-b|reviewer-c|task-reviewer) [|]/ { rows[++n] = $0; next }
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
cmp -s "$(expected_profile "$ROOT/providers/opencode-go.md")" "$LEGACY_DEST/PROVIDERS.md" || fail "implicit reuse retains opencode-go"
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
  cmp -s "$(expected_profile "$ROOT/providers/$expected_profile.md")" "$PREPROFILE_DEST/PROVIDERS.md" || fail "pre-profile $selection binding"
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
  grep -qxF 'model: opencode-go/mimo-v2.6-flash' "$OLD_DEST/agents/scout.md" || fail "$legacy_kind scout pin"
  grep -qxF 'model: opencode-go/deepseek-v4.1-flash#high' "$OLD_DEST/agents/tester.md" || fail "$legacy_kind tester pin"
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
cmp -s "$(expected_profile "$PF_ABS")" "$PF_DEST/PROVIDERS.md" || fail "PROVIDERS.md is a byte copy of the profile file"
[ "$(sed -n '2p' "$PF_DEST/.harness-manifest")" = "# profile-file $PF_ABS" ] || fail "manifest line 2 records the profile file path"
PF_REL_DEST="$TMPROOT/profile-file-rel-dest"
rc=0
( cd "$PF_DIR" && OPENCODE_CONFIG="$PF_REL_DEST" "$INSTALL" --profile-file custom.md ) >"$TMPROOT/profile-file-rel.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/profile-file-rel.out" >&2; fail "relative --profile-file install exits 0"; }
cmp -s "$(expected_profile "$PF_ABS")" "$PF_REL_DEST/PROVIDERS.md" || fail "relative profile file is byte copied"
[ "$(sed -n '2p' "$PF_REL_DEST/.harness-manifest")" = "# profile-file $PF_ABS" ] || fail "relative profile file is recorded as absolute"
pass "--profile-file binds, copies and records an absolute path"

# 49. refresh reuses a recorded profile file; a missing file is fatal
rc=0
OPENCODE_CONFIG="$PF_DEST" "$INSTALL" --force >"$TMPROOT/profile-reuse.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/profile-reuse.out" >&2; fail "refresh with a recorded profile file exits 0"; }
cmp -s "$(expected_profile "$PF_ABS")" "$PF_DEST/PROVIDERS.md" || fail "refresh without flags reuses the recorded profile file"
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

# 51. the default tri profile renders the Revision 3 native pins
PINS_DEST="$TMPROOT/rebalance-pins"
rc=0
OPENCODE_CONFIG="$PINS_DEST" "$INSTALL" >"$TMPROOT/pins.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/pins.out" >&2; fail "fresh tri install exits 0"; }
grep -qxF 'model: opencode-go/mimo-v2.6-flash' "$PINS_DEST/agents/scout.md" || fail "tri scout pin"
grep -qxF 'model: opencode-go/deepseek-v4.1-flash#high' "$PINS_DEST/agents/tester.md" || fail "tri tester pin"
grep -qxF 'model: opencode-go/deepseek-v4.1-flash#high' "$PINS_DEST/agents/patch.md" || fail "tri patch pin"
[ ! -e "$PINS_DEST/agents/reviewer-esc.md" ] || fail "tri installs no retired reviewer-esc seat"
for seat in implementer implementer-deep reviewer-a reviewer-b reviewer-c; do
  if grep -q '^model:' "$PINS_DEST/agents/$seat.md"; then
    fail "tri $seat has no native pin"
  fi
  grep -qxF "note: $seat has no opencode rung; dispatch it through delegate_task only" "$TMPROOT/pins.out" || fail "tri reports the $seat delegate-only seat"
done
pass "default tri renders the Revision 3 native pins"

# 52. quad installs cleanly with the camelCase Claude Code provider id
QUAD_DEST="$TMPROOT/quad-install"
[ -f "$ROOT/providers/quad.md" ] || fail "providers/quad.md is missing; quad cannot install (expected red)"
rc=0
OPENCODE_CONFIG="$QUAD_DEST" "$INSTALL" --profile quad >"$TMPROOT/quad.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/quad.out" >&2; fail "quad install exits 0 (claudeAgent provider id accepted)"; }
cmp -s "$(expected_profile "$ROOT/providers/quad.md")" "$QUAD_DEST/PROVIDERS.md" || fail "quad PROVIDERS.md is a byte copy of providers/quad.md"
grep -qxF 'model: opencode-go/mimo-v2.6-flash' "$QUAD_DEST/agents/scout.md" || fail "quad scout pin"
grep -qxF 'model: opencode-go/deepseek-v4.1-flash#high' "$QUAD_DEST/agents/tester.md" || fail "quad tester pin"
[ ! -e "$QUAD_DEST/agents/reviewer-esc.md" ] || fail "quad installs no retired reviewer-esc seat"
for seat in implementer implementer-deep reviewer-a reviewer-b reviewer-c; do
  if grep -q '^model:' "$QUAD_DEST/agents/$seat.md"; then
    fail "quad $seat has no native pin"
  fi
  grep -qxF "note: $seat has no opencode rung; dispatch it through delegate_task only" "$TMPROOT/quad.out" || fail "quad reports the $seat delegate-only seat"
done
if grep -nE '^\| .* \| opencode \| opencode-go/(kimi|qwen3.8-max|deepseek-v4-pro|mimo-v2.6-pro|minimax-m3)' "$ROOT/providers/quad.md" >"$TMPROOT/quad-expensive.out" 2>&1; then
  cat "$TMPROOT/quad-expensive.out" >&2
  fail "quad profile contains no expensive or purged opencode models in ladder"
fi
grep -qF '| task-reviewer | fallback | claudeAgent | claude-sonnet-5-5 | effort=high | anthropic | ok |' "$QUAD_DEST/PROVIDERS.md" || fail "quad task-reviewer fallback is claudeAgent sonnet"
pass "quad installs cleanly and leaves its delegate-only seats unpinned"

# 53. provider ids accept camelCase but reject underscores and a leading hyphen
CHARSET_BASE="$TMPROOT/charset.md"
grep -v '^| driver | fallback |' "$ROOT/providers/tri.md" >"$CHARSET_BASE"
printf '| driver | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |\n' >>"$CHARSET_BASE"
cp "$CHARSET_BASE" "$FIXTURE/providers/charset.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/charset-valid-dest" "$FIXTURE/install.sh" --profile charset >"$TMPROOT/charset-valid.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/charset-valid.out" >&2; fail "camelCase provider id claudeAgent is accepted"; }
for bad_provider in bad_id -x; do
  cp "$CHARSET_BASE" "$FIXTURE/providers/charset.md"
  printf '| compaction | last-resort | %s | valid | - | google | ok |\n' "$bad_provider" >>"$FIXTURE/providers/charset.md"
  rc=0
  OPENCODE_CONFIG="$TMPROOT/charset-bad-dest" "$FIXTURE/install.sh" --profile charset >"$TMPROOT/charset-bad.out" 2>"$TMPROOT/charset-bad.err" || rc=$?
  [ "$rc" -eq 1 ] || { cat "$TMPROOT/charset-bad.err" >&2; fail "provider id $bad_provider exits 1"; }
  grep -qF 'install.sh: profile charset invalid row: compaction last-resort: ' "$TMPROOT/charset-bad.err" || { cat "$TMPROOT/charset-bad.err" >&2; fail "provider id $bad_provider is reported as an invalid row"; }
  [ ! -e "$TMPROOT/charset-bad-dest" ] || fail "provider id $bad_provider writes nothing"
done
pass "provider ids accept camelCase and reject underscore and leading-hyphen ids"

# 54. tri and quad carry no OpenAI or Google model through OpenCode Go
[ -f "$ROOT/providers/quad.md" ] || fail "providers/quad.md is missing; cannot check opencode-go/gpt or opencode-go/gemini rows (expected red)"
if grep -nE 'opencode-go/(gpt|gemini)' "$ROOT/providers/tri.md" "$ROOT/providers/quad.md" >"$TMPROOT/opencode-gpt.out" 2>&1; then
  cat "$TMPROOT/opencode-gpt.out" >&2
  fail "tri and quad contain no opencode-go/gpt or opencode-go/gemini rows"
fi
pass "tri and quad carry no OpenAI or Google model through OpenCode Go"

# 55. --profile-file may point at the installed PROVIDERS.md (directly or via a
# symlink) without deleting or corrupting the file it is reading.
SELF_DEST="$TMPROOT/self-bind"
rc=0
OPENCODE_CONFIG="$SELF_DEST" "$INSTALL" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] || fail "self-bind fixture install exits 0"
rc=0
OPENCODE_CONFIG="$SELF_DEST" "$INSTALL" --force --profile-file "$SELF_DEST/PROVIDERS.md" >"$TMPROOT/self-bind.out" 2>"$TMPROOT/self-bind.err" || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/self-bind.err" >&2; fail "--profile-file pointing at installed PROVIDERS.md exits 0"; }
[ -e "$SELF_DEST/PROVIDERS.md" ] || fail "self-bound PROVIDERS.md still exists"
[ -s "$SELF_DEST/PROVIDERS.md" ] || fail "self-bound PROVIDERS.md is non-empty"
cmp -s "$(expected_profile "$ROOT/providers/tri.md")" "$SELF_DEST/PROVIDERS.md" || fail "self-bound PROVIDERS.md is byte-identical to providers/tri.md"
ln -s "$SELF_DEST/PROVIDERS.md" "$TMPROOT/providers-link.md"
rc=0
OPENCODE_CONFIG="$SELF_DEST" "$INSTALL" --force --profile-file "$TMPROOT/providers-link.md" >"$TMPROOT/self-bind-link.out" 2>"$TMPROOT/self-bind-link.err" || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/self-bind-link.err" >&2; fail "--profile-file symlinked to installed PROVIDERS.md exits 0"; }
cmp -s "$(expected_profile "$ROOT/providers/tri.md")" "$SELF_DEST/PROVIDERS.md" || fail "symlink-bound PROVIDERS.md stays byte-identical to providers/tri.md"
pass "--profile-file pointing to installed PROVIDERS.md preserves the file"

# 56. --profile-file rejects a path containing a newline before writing anything.
NL_DIR="$TMPROOT/nl"$'\n'"dir"
mkdir -p "$NL_DIR"
cp "$ROOT/providers/tri.md" "$NL_DIR/custom.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/nl-dest" "$INSTALL" --profile-file "$NL_DIR/custom.md" >"$TMPROOT/nl.out" 2>"$TMPROOT/nl.err" || rc=$?
[ "$rc" -eq 2 ] || { cat "$TMPROOT/nl.err" >&2; fail "--profile-file with a newline in the path exits 2 (got $rc)"; }
[ ! -e "$TMPROOT/nl-dest" ] || fail "--profile-file with a newline in the path writes nothing"
grep -q 'install.sh: invalid profile file path:' "$TMPROOT/nl.err" || { cat "$TMPROOT/nl.err" >&2; fail "--profile-file with a newline reports invalid profile file path"; }
pass "--profile-file rejects newline in path without writing"

# 57. quota pools and backup ladder are optional; shipped profiles carry both
cat >"$TMPROOT/no-pools-or-backups.md" <<'MINIMAL'
# Minimal profile without quota pools or a backup ladder

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| scout | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| implementer | primary | opencode | opencode-go/gemini-4-argon | variant=high | google | ok |
| implementer-deep | primary | opencode | opencode-go/gemini-4-argon | variant=high | google | ok |
| patch | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| tester | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| reviewer-a | primary | opencode | opencode-go/muse-spark-1.3-contributor | variant=xhigh | meta | trains |
| reviewer-b | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=max | deepseek | ok |
| reviewer-c | primary | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| reviewer-esc | primary | opencode | opencode-go/kimi-k3.1-pro | variant=high | moonshot | ok |
| task-reviewer | primary | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
MINIMAL
rc=0
OPENCODE_CONFIG="$TMPROOT/no-pools-dest" "$INSTALL" --profile-file "$TMPROOT/no-pools-or-backups.md" >"$TMPROOT/no-pools.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/no-pools.out" >&2; fail "a profile without quota pools or backup ladder installs cleanly"; }
[ -f "$TMPROOT/no-pools-dest/PROVIDERS.md" ] || fail "a profile without quota pools or backup ladder renders PROVIDERS.md"
grep -qxF "install.sh: profile $(cd "$TMPROOT" && pwd -P)/no-pools-or-backups.md: reviewer-esc rows ignored (role retired; captain replaces escalation)" "$TMPROOT/no-pools.out" || { cat "$TMPROOT/no-pools.out" >&2; fail "a retired reviewer-esc row is ignored with a warning"; }
for shipped in tri quad opencode-go; do
  grep -qxF '## Quota pools' "$ROOT/providers/$shipped.md" || fail "providers/$shipped.md carries a ## Quota pools section"
  grep -qxF '## Backup ladder' "$ROOT/providers/$shipped.md" || fail "providers/$shipped.md carries a ## Backup ladder section"
done
grep -qxF '## Quota pools' "$DEST/PROVIDERS.md" || fail "default tri PROVIDERS.md renders ## Quota pools"
grep -qxF '## Backup ladder' "$DEST/PROVIDERS.md" || fail "default tri PROVIDERS.md renders ## Backup ladder"
pass "quota pools and backup ladder sections are optional for custom profiles and present in shipped profiles"

# strip_profile_section <file> <heading text>: drop one optional section so a
# test controls the exact rows that follow it.
strip_profile_section() {
  awk -v section="$2" '
    $0 == "## " section { skip = 1; next }
    skip && /^## / { skip = 0 }
    !skip { print }
  ' "$1"
}

# 58. ## Quota pools validation rejects malformed rows before any write
strip_profile_section "$ROOT/providers/opencode-go.md" 'Quota pools' >"$TMPROOT/pools-base.md"
while IFS=';' read -r label row diagnostic; do
  cp "$TMPROOT/pools-base.md" "$TMPROOT/bad-pool.md"
  printf '\n## Quota pools\n\n| pool | provider | models | window | soft-cap | reserve |\n| --- | --- | --- | --- | --- | --- |\n%s\n' "$row" >>"$TMPROOT/bad-pool.md"
  rc=0
  OPENCODE_CONFIG="$TMPROOT/bad-pool-dest" "$INSTALL" --profile-file "$TMPROOT/bad-pool.md" >"$TMPROOT/bad-pool.out" 2>"$TMPROOT/bad-pool.err" || rc=$?
  [ "$rc" -eq 1 ] || { cat "$TMPROOT/bad-pool.err" >&2; fail "quota pool $label exits 1"; }
  [ ! -e "$TMPROOT/bad-pool-dest" ] || fail "quota pool $label writes nothing"
  grep -qF "$diagnostic" "$TMPROOT/bad-pool.err" || { cat "$TMPROOT/bad-pool.err" >&2; fail "quota pool $label diagnostic"; }
done <<'POOLROWS'
bad window;| p1 | opencode | * | 5hours | - | - |;invalid pool row: p1: invalid window
bad soft-cap;| p1 | opencode | * | 5h | zero | - |;invalid pool row: p1: invalid soft-cap
unknown reserve role;| p1 | opencode | * | 5h | 6 | unknown-role |;invalid pool row: p1: invalid reserve
POOLROWS
cp "$TMPROOT/pools-base.md" "$TMPROOT/bad-pool.md"
printf '\n## Quota pools\n\n| pool | provider | models | window | soft-cap | reserve |\n| --- | --- | --- | --- | --- | --- |\n| p1 | opencode | * | 5h | - | - |\n| p1 | opencode | * | 5h | - | - |\n' >>"$TMPROOT/bad-pool.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/bad-pool-dest" "$INSTALL" --profile-file "$TMPROOT/bad-pool.md" >"$TMPROOT/bad-pool.out" 2>"$TMPROOT/bad-pool.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/bad-pool.err" >&2; fail "duplicate pool name exits 1"; }
[ ! -e "$TMPROOT/bad-pool-dest" ] || fail "duplicate pool name writes nothing"
grep -qF 'invalid pool row: p1: duplicate pool' "$TMPROOT/bad-pool.err" || { cat "$TMPROOT/bad-pool.err" >&2; fail "duplicate pool name diagnostic"; }
pass "quota pools validation rejects bad window, soft-cap, reserve role, and duplicate pool"

# 59. ## Backup ladder validation rejects malformed rows before any write
strip_profile_section "$ROOT/providers/opencode-go.md" 'Backup ladder' >"$TMPROOT/backup-base.md"
while IFS=';' read -r label row diagnostic; do
  cp "$TMPROOT/backup-base.md" "$TMPROOT/bad-backup.md"
  printf '\n## Backup ladder\n\n| order | roles | provider | model | effort | family | privacy |\n| --- | --- | --- | --- | --- | --- | --- |\n%s\n' "$row" >>"$TMPROOT/bad-backup.md"
  rc=0
  OPENCODE_CONFIG="$TMPROOT/bad-backup-dest" "$INSTALL" --profile-file "$TMPROOT/bad-backup.md" >"$TMPROOT/bad-backup.out" 2>"$TMPROOT/bad-backup.err" || rc=$?
  [ "$rc" -eq 1 ] || { cat "$TMPROOT/bad-backup.err" >&2; fail "backup row $label exits 1"; }
  [ ! -e "$TMPROOT/bad-backup-dest" ] || fail "backup row $label writes nothing"
  grep -qF "$diagnostic" "$TMPROOT/bad-backup.err" || { cat "$TMPROOT/bad-backup.err" >&2; fail "backup row $label diagnostic"; }
done <<'BACKUPROWS'
unknown role;| 1 | implementer,bogus-role | opencode | opencode-go/minimax-m3 | - | minimax | ok |;invalid backup row: 1: invalid roles
non-integer order;| zero | * | opencode | opencode-go/minimax-m3 | - | minimax | ok |;invalid backup row: zero: invalid order
invalid privacy;| 1 | * | opencode | opencode-go/minimax-m3 | - | minimax | maybe |;invalid backup row: 1: invalid privacy
BACKUPROWS
cp "$TMPROOT/backup-base.md" "$TMPROOT/bad-backup.md"
printf '\n## Backup ladder\n\n| order | roles | provider | model | effort | family | privacy |\n| --- | --- | --- | --- | --- | --- | --- |\n| 1 | * | opencode | opencode-go/minimax-m3 | - | minimax | ok |\n| 1 | * | opencode | opencode-go/minimax-m3 | - | minimax | ok |\n' >>"$TMPROOT/bad-backup.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/bad-backup-dest" "$INSTALL" --profile-file "$TMPROOT/bad-backup.md" >"$TMPROOT/bad-backup.out" 2>"$TMPROOT/bad-backup.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/bad-backup.err" >&2; fail "duplicate backup order exits 1"; }
[ ! -e "$TMPROOT/bad-backup-dest" ] || fail "duplicate backup order writes nothing"
grep -qF 'invalid backup row: 1: duplicate order' "$TMPROOT/bad-backup.err" || { cat "$TMPROOT/bad-backup.err" >&2; fail "duplicate backup order diagnostic"; }
pass "backup ladder validation rejects bad order, unknown role, duplicate order, and invalid privacy"

# 60. state/ is created, unmanaged by the manifest, and the ledger survives prune
STATE_DEST="$TMPROOT/state-dest"
rc=0
OPENCODE_CONFIG="$STATE_DEST" "$INSTALL" >"$TMPROOT/state.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/state.out" >&2; fail "state fixture install exits 0"; }
[ -d "$STATE_DEST/state" ] || fail "install creates <dest>/state/"
if grep -q '^state' "$STATE_DEST/.harness-manifest"; then
  fail "the manifest does not record state/"
fi
ledger_line="$(printf 'antigravity-claude\tantigravity\t2026-11-09T14:00:00Z\t2026-11-09T19:00:00Z\treviewer-b\t429')"
printf '%s\n' "$ledger_line" >"$STATE_DEST/state/quota-ledger.tsv"
rc=0
OPENCODE_CONFIG="$STATE_DEST" "$INSTALL" --force --prune >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] || fail "--force --prune over an existing state directory exits 0"
[ -f "$STATE_DEST/state/quota-ledger.tsv" ] || fail "quota-ledger.tsv survives --force --prune"
[ "$(cat "$STATE_DEST/state/quota-ledger.tsv")" = "$ledger_line" ] || fail "quota-ledger.tsv is unchanged by --force --prune"
pass "state directory is created, unmanaged by manifest, and quota-ledger.tsv survives --force --prune"

# 61. a pool literally named "pool" is validated (not skipped as a header), and
# GFM alignment separators (:---, ---:) are accepted as the separator row.
strip_profile_section "$ROOT/providers/opencode-go.md" 'Quota pools' >"$TMPROOT/pool-named-pool.md"
printf '\n## Quota pools\n\n| pool | provider | models | window | soft-cap | reserve |\n| :---: | :--- | --- | ---: | :---: | --- |\n| pool | codex | * | nonsense | zero | unknown-role |\n' >>"$TMPROOT/pool-named-pool.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/pool-named-pool-dest" "$INSTALL" --profile-file "$TMPROOT/pool-named-pool.md" >"$TMPROOT/pool-named-pool.out" 2>"$TMPROOT/pool-named-pool.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/pool-named-pool.err" >&2; fail "a pool literally named pool with a bad window exits 1 (got $rc)"; }
[ ! -e "$TMPROOT/pool-named-pool-dest" ] || fail "a pool literally named pool with a bad window writes nothing"
grep -qF 'invalid pool row: pool: invalid window' "$TMPROOT/pool-named-pool.err" || { cat "$TMPROOT/pool-named-pool.err" >&2; fail "a pool literally named pool reports invalid pool row: pool: invalid window"; }
awk '{ if ($0 == "| pool | codex | * | nonsense | zero | unknown-role |") print "| pool | codex | * | 5h | - | - |"; else print }' \
  "$TMPROOT/pool-named-pool.md" >"$TMPROOT/pool-named-pool-fixed.md"
mv "$TMPROOT/pool-named-pool-fixed.md" "$TMPROOT/pool-named-pool.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/pool-named-pool-ok" "$INSTALL" --profile-file "$TMPROOT/pool-named-pool.md" >"$TMPROOT/pool-named-pool-ok.out" 2>"$TMPROOT/pool-named-pool-ok.err" || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/pool-named-pool-ok.err" >&2; fail "a valid pool literally named pool under GFM alignment separators exits 0 (got $rc)"; }
pass "a pool literally named pool is validated and GFM alignment separators are accepted"

# 62. --target codex installs into ${CODEX_HOME:-$HOME/.codex}
rc=0
CODEX_HOME="$TMPROOT/codex-dest" "$INSTALL" --target codex >"$TMPROOT/codex.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/codex.out" >&2; fail "--target codex install exits 0"; }
[ -f "$TMPROOT/codex-dest/skills/oneshot/SKILL.md" ] || fail "codex target writes skills/oneshot/SKILL.md"
[ -f "$TMPROOT/codex-dest/agents/implementer.md" ] || fail "codex target writes agents/implementer.md"
[ -f "$TMPROOT/codex-dest/HARNESS.md" ] || fail "codex target writes HARNESS.md"
[ -f "$TMPROOT/codex-dest/PROVIDERS.md" ] || fail "codex target writes PROVIDERS.md"
[ -f "$TMPROOT/codex-dest/AGENTS.md" ] || fail "codex target writes AGENTS.md"
[ -d "$TMPROOT/codex-dest/state" ] || fail "codex target writes state/"
[ -f "$TMPROOT/codex-dest/.harness-manifest" ] || fail "codex target writes .harness-manifest"
grep -qxF '## Dispatch Adapter' "$TMPROOT/codex-dest/AGENTS.md" || fail "codex AGENTS.md carries the harness rules"
grep -qxF '## Quota pools' "$TMPROOT/codex-dest/AGENTS.md" || fail "codex AGENTS.md carries the active profile"
pass "--target codex installs skills, agents, HARNESS.md, PROVIDERS.md, and combined AGENTS.md"

# 63. --target antigravity installs the flat layout under
# ${ANTIGRAVITY_CONFIG:-$HOME/.gemini/config} with an allowlisted skills/_harness/
# bundle; the legacy plugins/oneshot-harness plugin is dropped.
rc=0
OPENCODE_CONFIG="$TMPROOT/agy-oc-63" ANTIGRAVITY_CONFIG="$TMPROOT/agy-config" "$INSTALL" --target antigravity >"$TMPROOT/agy.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/agy.out" >&2; fail "--target antigravity install exits 0"; }
AGY_DEST="$TMPROOT/agy-config"
[ ! -e "$AGY_DEST/plugin.json" ] || fail "antigravity target drops plugin.json"
[ ! -e "$AGY_DEST/plugins/oneshot-harness" ] || fail "antigravity target drops plugins/oneshot-harness"
[ -f "$AGY_DEST/skills/oneshot/SKILL.md" ] && [ ! -L "$AGY_DEST/skills/oneshot/SKILL.md" ] || fail "antigravity target writes real skills/oneshot/SKILL.md"
[ -f "$AGY_DEST/skills/_harness/HARNESS.md" ] || fail "antigravity target writes skills/_harness/HARNESS.md"
[ -f "$AGY_DEST/skills/_harness/PROVIDERS.md" ] || fail "antigravity target writes skills/_harness/PROVIDERS.md"
[ -f "$AGY_DEST/skills/_harness/NOTICE" ] || fail "antigravity target writes skills/_harness/NOTICE"
[ -f "$AGY_DEST/skills/_harness/LICENSE" ] || fail "antigravity target writes skills/_harness/LICENSE"
[ -f "$AGY_DEST/skills/_harness/agents/implementer.md" ] || fail "antigravity target writes skills/_harness/agents/implementer.md"
[ ! -e "$AGY_DEST/skills/_harness/SKILL.md" ] || fail "skills/_harness has no SKILL.md"
[ -f "$AGY_DEST/agents/implementer.md" ] || fail "antigravity target writes agents/implementer.md"
cmp -s "$AGY_DEST/agents/implementer.md" "$AGY_DEST/skills/_harness/agents/implementer.md" || fail "skills/_harness/agents matches rendered agents"
[ -f "$AGY_DEST/rules/HARNESS.md" ] || fail "antigravity target writes rules/HARNESS.md"
[ -f "$AGY_DEST/rules/PROVIDERS.md" ] || fail "antigravity target writes rules/PROVIDERS.md"
[ -f "$AGY_DEST/HARNESS.md" ] || fail "antigravity target writes root HARNESS.md"
[ -f "$AGY_DEST/PROVIDERS.md" ] || fail "antigravity target writes root PROVIDERS.md"
[ -d "$AGY_DEST/state" ] || fail "antigravity target writes state/"
[ -f "$AGY_DEST/.harness-manifest" ] || fail "antigravity target writes .harness-manifest"
grep -qxF 'trigger: always_on' "$AGY_DEST/rules/HARNESS.md" || fail "antigravity rules/HARNESS.md is always_on"
grep -qxF 'trigger: always_on' "$AGY_DEST/rules/PROVIDERS.md" || fail "antigravity rules/PROVIDERS.md is always_on"
[ "$(wc -c <"$AGY_DEST/rules/HARNESS.md")" -lt 24000 ] || fail "antigravity rules/HARNESS.md is under 24KB"
[ "$(wc -c <"$AGY_DEST/rules/PROVIDERS.md")" -lt 24000 ] || fail "antigravity rules/PROVIDERS.md is under 24KB"
grep -qxF 'subagent: true' "$AGY_DEST/skills/_harness/agents/implementer.md" || fail "antigravity implementer is a subagent"
grep -qxF 'mainAgent: false' "$AGY_DEST/skills/_harness/agents/implementer.md" || fail "antigravity implementer is not a main agent"
grep -q '^tools:' "$AGY_DEST/skills/_harness/agents/implementer.md" || fail "antigravity implementer carries a tools frontmatter line"
grep -qxF 'permissions:' "$AGY_DEST/skills/_harness/agents/implementer.md" || fail "antigravity implementer preserves the permissions policy block"
grep -qxF 'permissions:' "$AGY_DEST/skills/_harness/agents/reviewer-a.md" || fail "antigravity reviewer-a preserves the permissions policy block"
grep -qF 'Antigravity cannot narrow run_command in frontmatter' "$AGY_DEST/skills/_harness/agents/reviewer-a.md" || fail "antigravity reviewer-a documents the read-only run_command constraint"
pass "--target antigravity installs flat skills, allowlisted skills/_harness bundle, always_on rules (<24KB), and Antigravity subagent contracts"

# 64. --target claude installs into ${CLAUDE_CONFIG_DIR:-$HOME/.claude}
rc=0
CLAUDE_CONFIG_DIR="$TMPROOT/claude-dest" "$INSTALL" --target claude >"$TMPROOT/claude.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/claude.out" >&2; fail "--target claude install exits 0"; }
[ -f "$TMPROOT/claude-dest/skills/oneshot/SKILL.md" ] || fail "claude target writes skills/oneshot/SKILL.md"
[ -f "$TMPROOT/claude-dest/agents/implementer.md" ] || fail "claude target writes agents/implementer.md"
[ -f "$TMPROOT/claude-dest/HARNESS.md" ] || fail "claude target writes HARNESS.md"
[ -f "$TMPROOT/claude-dest/PROVIDERS.md" ] || fail "claude target writes PROVIDERS.md"
[ -f "$TMPROOT/claude-dest/CLAUDE.md" ] || fail "claude target writes CLAUDE.md"
[ -d "$TMPROOT/claude-dest/state" ] || fail "claude target writes state/"
[ -f "$TMPROOT/claude-dest/.harness-manifest" ] || fail "claude target writes .harness-manifest"
grep -qxF 'name: implementer' "$TMPROOT/claude-dest/agents/implementer.md" || fail "claude implementer carries a name frontmatter line"
grep -q '^tools:' "$TMPROOT/claude-dest/agents/implementer.md" || fail "claude implementer carries a tools frontmatter line"
grep -qxF 'permissions:' "$TMPROOT/claude-dest/agents/implementer.md" || fail "claude implementer preserves the permissions policy block"
grep -qxF 'permissions:' "$TMPROOT/claude-dest/agents/reviewer-a.md" || fail "claude reviewer-a preserves the permissions policy block"
pass "--target claude installs skills, Claude subagent frontmatter, the permissions policy, and combined CLAUDE.md"

# 65. --target all installs all four targets and --force --prune works across targets
rc=0
OPENCODE_CONFIG="$TMPROOT/all-oc" CODEX_HOME="$TMPROOT/all-codex" ANTIGRAVITY_CONFIG="$TMPROOT/all-agy" CLAUDE_CONFIG_DIR="$TMPROOT/all-claude" \
  "$INSTALL" --target all >"$TMPROOT/all.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/all.out" >&2; fail "--target all install exits 0"; }
for manifest in "$TMPROOT/all-oc/.harness-manifest" "$TMPROOT/all-codex/.harness-manifest" "$TMPROOT/all-agy/.harness-manifest" "$TMPROOT/all-claude/.harness-manifest"; do
  [ -f "$manifest" ] || fail "--target all writes $manifest"
done
rc=0
OPENCODE_CONFIG="$TMPROOT/all-oc" CODEX_HOME="$TMPROOT/all-codex" ANTIGRAVITY_CONFIG="$TMPROOT/all-agy" CLAUDE_CONFIG_DIR="$TMPROOT/all-claude" \
  "$INSTALL" --target all --force --prune >"$TMPROOT/all-refresh.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/all-refresh.out" >&2; fail "--target all --force --prune exits 0"; }
pass "--target all installs and refreshes all four provider targets"

# 66. unknown --target value exits 2 without writing
rc=0
OPENCODE_CONFIG="$TMPROOT/bad-target-dest" "$INSTALL" --target bogus >"$TMPROOT/bad-target.out" 2>"$TMPROOT/bad-target.err" || rc=$?
[ "$rc" -eq 2 ] || { cat "$TMPROOT/bad-target.err" >&2; fail "unknown --target exits 2 (got $rc)"; }
[ ! -e "$TMPROOT/bad-target-dest" ] || fail "unknown --target writes nothing"
grep -qF 'install.sh: unknown target: bogus' "$TMPROOT/bad-target.err" || { cat "$TMPROOT/bad-target.err" >&2; fail "unknown --target diagnostic"; }
pass "unknown --target exits 2 without writing"

# 67. Multi-target install works through a relative `bash install.sh` invocation,
# and every selected target is preflighted before any target is written.
rc=0
( cd "$ROOT" && OPENCODE_CONFIG="$TMPROOT/rel-oc" CODEX_HOME="$TMPROOT/rel-codex" ANTIGRAVITY_CONFIG="$TMPROOT/rel-agy" CLAUDE_CONFIG_DIR="$TMPROOT/rel-claude" bash install.sh --target all ) >"$TMPROOT/rel-all.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/rel-all.out" >&2; fail "relative bash install.sh --target all exits 0 (got $rc)"; }
for manifest in "$TMPROOT/rel-oc/.harness-manifest" "$TMPROOT/rel-codex/.harness-manifest" "$TMPROOT/rel-agy/.harness-manifest" "$TMPROOT/rel-claude/.harness-manifest"; do
  [ -f "$manifest" ] || fail "relative bash install.sh --target all writes $manifest"
done
# A collision in the second target must abort before the first target is written.
mkdir -p "$TMPROOT/atomic-codex"
printf 'existing\n' >"$TMPROOT/atomic-codex/AGENTS.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/atomic-oc" CODEX_HOME="$TMPROOT/atomic-codex" "$INSTALL" --target opencode,codex >"$TMPROOT/atomic.out" 2>"$TMPROOT/atomic.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/atomic.err" >&2; fail "multi-target preflight collision exits 1 (got $rc)"; }
[ ! -e "$TMPROOT/atomic-oc" ] || fail "multi-target preflight writes nothing to an earlier target when a later target collides"
pass "multi-target install works via bash install.sh and preflights all targets atomically before writing"

# 68. Every target shares one machine-wide state/quota-ledger.tsv, symlinked to
# $OPENCODE_CONFIG/state, and --force --prune never trims it.
rc=0
OPENCODE_CONFIG="$TMPROOT/shared-oc" CODEX_HOME="$TMPROOT/shared-codex" ANTIGRAVITY_CONFIG="$TMPROOT/shared-agy" CLAUDE_CONFIG_DIR="$TMPROOT/shared-claude" "$INSTALL" --target all >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] || fail "--target all install for the shared ledger exits 0 (got $rc)"
SHARED_LEDGER_OC="$TMPROOT/shared-oc/state/quota-ledger.tsv"
SHARED_LEDGER_CODEX="$TMPROOT/shared-codex/state/quota-ledger.tsv"
SHARED_LEDGER_AGY="$TMPROOT/shared-agy/state/quota-ledger.tsv"
SHARED_LEDGER_CLAUDE="$TMPROOT/shared-claude/state/quota-ledger.tsv"
printf 'shared-pool\topencode\t2026-11-09T14:00:00Z\t2026-11-09T19:00:00Z\treviewer-a\tshared\n' >"$SHARED_LEDGER_CODEX"
[ -f "$SHARED_LEDGER_OC" ] || fail "opencode state/quota-ledger.tsv receives the ledger written through codex state/"
cmp -s "$SHARED_LEDGER_OC" "$SHARED_LEDGER_CODEX" || fail "opencode and codex share the same quota-ledger.tsv"
cmp -s "$SHARED_LEDGER_OC" "$SHARED_LEDGER_AGY" || fail "opencode and antigravity share the same quota-ledger.tsv"
cmp -s "$SHARED_LEDGER_OC" "$SHARED_LEDGER_CLAUDE" || fail "opencode and claude share the same quota-ledger.tsv"
ledger_before="$(cat "$SHARED_LEDGER_OC")"
rc=0
OPENCODE_CONFIG="$TMPROOT/shared-oc" CODEX_HOME="$TMPROOT/shared-codex" ANTIGRAVITY_CONFIG="$TMPROOT/shared-agy" CLAUDE_CONFIG_DIR="$TMPROOT/shared-claude" "$INSTALL" --force --prune --target all >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] || fail "--force --prune --target all with a shared ledger exits 0 (got $rc)"
for ledger in "$SHARED_LEDGER_OC" "$SHARED_LEDGER_CODEX" "$SHARED_LEDGER_AGY" "$SHARED_LEDGER_CLAUDE"; do
  [ -f "$ledger" ] || fail "shared quota-ledger.tsv survives --force --prune: $ledger"
  [ "$(cat "$ledger")" = "$ledger_before" ] || fail "shared quota-ledger.tsv is unchanged by --force --prune: $ledger"
done
pass "all targets share a single machine-wide state/quota-ledger.tsv that survives --force --prune"

# 69. shared-state safety: a relative OPENCODE_CONFIG resolves to an absolute
# shared state path, an existing per-target ledger is merged (never removed)
# under --force, a non-ledger file in state/ is refused even with --force, and
# a same-directory CODEX_HOME/OPENCODE_CONFIG alias keeps state/ a real dir.
rc=0
( cd "$TMPROOT" && OPENCODE_CONFIG="rel-oc-69" CODEX_HOME="$TMPROOT/rel-cx-69" "$INSTALL" --target codex ) >"$TMPROOT/rel-state-69.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/rel-state-69.out" >&2; fail "relative OPENCODE_CONFIG install exits 0 (got $rc)"; }
[ -L "$TMPROOT/rel-cx-69/state" ] && [ -d "$TMPROOT/rel-cx-69/state" ] || fail "relative OPENCODE_CONFIG links state/ to a directory"
case "$(readlink "$TMPROOT/rel-cx-69/state")" in
  /*) true ;;
  *) fail "relative OPENCODE_CONFIG state symlink is absolute: $(readlink "$TMPROOT/rel-cx-69/state")" ;;
esac

mkdir -p "$TMPROOT/m-oc-69/state" "$TMPROOT/m-cx-69/state"
printf 'antigravity-argon\tantigravity\t2026-11-09T10:00:00Z\t2026-11-09T15:00:00Z\timplementer\t429\n' >"$TMPROOT/m-oc-69/state/quota-ledger.tsv"
printf 'codex-spark\tcodex\t2026-11-09T12:00:00Z\t2026-11-09T17:00:00Z\ttask-reviewer\t429\n' >>"$TMPROOT/m-oc-69/state/quota-ledger.tsv"
printf 'codex-spark\tcodex\t2026-11-09T13:00:00Z\t2026-11-09T18:00:00Z\treviewer-a\t429\n' >"$TMPROOT/m-cx-69/state/quota-ledger.tsv"
printf 'opencode-pro\topencode\t2026-11-09T11:00:00Z\t2026-11-09T16:00:00Z\treviewer-c\t429\n' >>"$TMPROOT/m-cx-69/state/quota-ledger.tsv"

rc=0
OPENCODE_CONFIG="$TMPROOT/m-oc-69" CODEX_HOME="$TMPROOT/m-cx-69" "$INSTALL" --target codex >"$TMPROOT/merge-noforce-69.out" 2>"$TMPROOT/merge-noforce-69.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/merge-noforce-69.err" >&2; fail "pre-existing per-target ledger refuses without --force (got $rc)"; }
[ -f "$TMPROOT/m-cx-69/state/quota-ledger.tsv" ] && [ ! -L "$TMPROOT/m-cx-69/state" ] || fail "refused install leaves the pre-existing state ledger in place"

rc=0
OPENCODE_CONFIG="$TMPROOT/m-oc-69" CODEX_HOME="$TMPROOT/m-cx-69" "$INSTALL" --force --target codex >"$TMPROOT/merge-force-69.out" 2>"$TMPROOT/merge-force-69.err" || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/merge-force-69.err" >&2; fail "pre-existing per-target ledger merges under --force (got $rc)"; }
[ -L "$TMPROOT/m-cx-69/state" ] || fail "merged install links state/ to the shared state dir"
grep -qxF "$(printf 'antigravity-argon\tantigravity\t2026-11-09T10:00:00Z\t2026-11-09T15:00:00Z\timplementer\t429')" "$TMPROOT/m-oc-69/state/quota-ledger.tsv" || fail "merge keeps the shared ledger row"
grep -qxF "$(printf 'opencode-pro\topencode\t2026-11-09T11:00:00Z\t2026-11-09T16:00:00Z\treviewer-c\t429')" "$TMPROOT/m-oc-69/state/quota-ledger.tsv" || fail "merge keeps the per-target ledger row"
grep -qxF "$(printf 'codex-spark\tcodex\t2026-11-09T13:00:00Z\t2026-11-09T18:00:00Z\treviewer-a\t429')" "$TMPROOT/m-oc-69/state/quota-ledger.tsv" || fail "merge retains the later retry_after per pool"
! grep -q '2026-11-09T17:00:00Z' "$TMPROOT/m-oc-69/state/quota-ledger.tsv" || fail "merge supersedes the earlier retry_after"
! grep -q 'window_start' "$TMPROOT/m-oc-69/state/quota-ledger.tsv" || fail "merge does not write a foreign ledger header"

mkdir -p "$TMPROOT/nl-cx-69/state"
printf 'not a ledger\n' >"$TMPROOT/nl-cx-69/state/host.sqlite"
rc=0
OPENCODE_CONFIG="$TMPROOT/m-oc-69" CODEX_HOME="$TMPROOT/nl-cx-69" "$INSTALL" --force --target codex >"$TMPROOT/nonledger-69.out" 2>"$TMPROOT/nonledger-69.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/nonledger-69.err" >&2; fail "non-ledger file in state/ refuses even with --force (got $rc)"; }
[ -f "$TMPROOT/nl-cx-69/state/host.sqlite" ] || fail "non-ledger file in state/ survives the refused install"

rc=0
OPENCODE_CONFIG="$TMPROOT/m-oc-69" CODEX_HOME="$TMPROOT/m-oc-69" "$INSTALL" --force --target codex >"$TMPROOT/same-dir-69.out" 2>"$TMPROOT/same-dir-69.err" || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/same-dir-69.err" >&2; fail "same-dir CODEX_HOME/OPENCODE_CONFIG install exits 0 (got $rc)"; }
[ -d "$TMPROOT/m-oc-69/state" ] && [ ! -L "$TMPROOT/m-oc-69/state" ] && [ -f "$TMPROOT/m-oc-69/state/quota-ledger.tsv" ] || fail "same-dir alias preserves state/ as a real directory with its ledger"
pass "shared-state safety handles relative OPENCODE_CONFIG, merges existing ledger under --force, refuses non-ledger files, and preserves same-dir state"

# 70. size-cap guards: a prose-heavy profile compacts with a note for codex, an
# oversized Antigravity rule refuses at 24000 bytes, and a profile whose
# headings survive compaction refuses at 32768 bytes instead of shipping.
{
  cat "$ROOT/providers/tri.md"
  awk 'BEGIN { for (i = 0; i < 150; i++) printf "prose filler line %04d ......................................................................\n", i }'
} >"$TMPROOT/prose-big-70.md"
rc=0
CODEX_HOME="$TMPROOT/cap-cx-ok-70" OPENCODE_CONFIG="$TMPROOT/cap-oc-70" "$INSTALL" --profile-file "$TMPROOT/prose-big-70.md" --target codex >"$TMPROOT/cap-ok-70.out" 2>"$TMPROOT/cap-ok-70.err" || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/cap-ok-70.err" >&2; fail "oversized codex prose compacts and installs (got $rc)"; }
grep -qF 'note: compacting codex profile prose to fit 32768-byte host instruction limit' "$TMPROOT/cap-ok-70.out" || fail "compaction prints the 32768-byte host instruction note"
[ "$(wc -c <"$TMPROOT/cap-cx-ok-70/AGENTS.md")" -lt 32768 ] || fail "compacted codex AGENTS.md is under 32768 bytes"

rc=0
ANTIGRAVITY_CONFIG="$TMPROOT/cap-agy-bad-70" OPENCODE_CONFIG="$TMPROOT/cap-oc-70" "$INSTALL" --profile-file "$TMPROOT/prose-big-70.md" --target antigravity >"$TMPROOT/cap-agy-70.out" 2>"$TMPROOT/cap-agy-70.err" || rc=$?
[ "$rc" -eq 2 ] || { cat "$TMPROOT/cap-agy-70.err" >&2; fail "oversized antigravity rule exits 2 (got $rc)"; }
grep -qF 'exceeds 24000 bytes' "$TMPROOT/cap-agy-70.err" || fail "oversized antigravity rule reports the 24000-byte limit"
[ ! -e "$TMPROOT/cap-agy-bad-70/.harness-manifest" ] || fail "refused antigravity install writes no manifest"

{
  cat "$ROOT/providers/tri.md"
  awk 'BEGIN { for (i = 0; i < 400; i++) printf "# comment heading %04d ..............................\n", i }'
} >"$TMPROOT/table-big-70.md"
rc=0
CODEX_HOME="$TMPROOT/cap-cx-bad-70" OPENCODE_CONFIG="$TMPROOT/cap-oc-70" "$INSTALL" --profile-file "$TMPROOT/table-big-70.md" --target codex >"$TMPROOT/cap-bad-70.out" 2>"$TMPROOT/cap-bad-70.err" || rc=$?
[ "$rc" -eq 2 ] || { cat "$TMPROOT/cap-bad-70.err" >&2; fail "post-compaction oversize profile exits 2 (got $rc)"; }
grep -qF 'exceeds 32768 bytes' "$TMPROOT/cap-bad-70.err" || fail "post-compaction oversize profile reports the 32768-byte limit"
[ ! -e "$TMPROOT/cap-cx-bad-70/.harness-manifest" ] || fail "refused codex install writes no manifest"
pass "size-cap guards compact prose with a note and refuse oversized Antigravity and post-compaction Codex/Claude files with exit 2"

# 71. Directory locks and ambient preflight variables must not prevent safe installs.
mkdir -p "$TMPROOT/lk-oc-71/state/quota-ledger.lock" "$TMPROOT/lk-cx-71/state/quota-ledger.lock"
touch -t 202001010000 "$TMPROOT/lk-oc-71/state/quota-ledger.lock" "$TMPROOT/lk-cx-71/state/quota-ledger.lock"
printf 'agy-opus\tantigravity\t2026-11-09T10:00:00Z\t2026-11-09T15:00:00Z\treviewer-b\t429\n' >"$TMPROOT/lk-cx-71/state/quota-ledger.tsv"
rc=0
OPENCODE_CONFIG="$TMPROOT/lk-oc-71" CODEX_HOME="$TMPROOT/lk-cx-71" "$INSTALL" --force --target codex >"$TMPROOT/lk-71.out" 2>"$TMPROOT/lk-71.err" || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/lk-71.err" >&2; fail "stale ledger directory locks are broken (got $rc)"; }
[ -L "$TMPROOT/lk-cx-71/state" ] || fail "stale lock migration links target state"
[ ! -e "$TMPROOT/lk-oc-71/state/quota-ledger.lock" ] || fail "shared ledger lock is released"
grep -q "$(printf '^agy-opus\t')" "$TMPROOT/lk-oc-71/state/quota-ledger.tsv" || fail "stale lock migration preserves ledger row"

mkdir -p "$TMPROOT/act-oc-71/state" "$TMPROOT/act-cx-71/state/quota-ledger.lock"
printf 'agy-opus\tantigravity\t2026-11-09T10:00:00Z\t2026-11-09T15:00:00Z\treviewer-b\t429\n' >"$TMPROOT/act-cx-71/state/quota-ledger.tsv"
rc=0
OPENCODE_CONFIG="$TMPROOT/act-oc-71" CODEX_HOME="$TMPROOT/act-cx-71" "$INSTALL" --force --target codex >"$TMPROOT/act-71.out" 2>"$TMPROOT/act-71.err" || rc=$?
[ "$rc" -eq 1 ] || fail "active ledger directory lock refuses installation (got $rc)"
[ -f "$TMPROOT/act-cx-71/state/quota-ledger.tsv" ] || fail "active lock refusal preserves source ledger"
[ ! -L "$TMPROOT/act-cx-71/state" ] || fail "active lock refusal leaves source state unlinked"

rc=0
HARNESS_INTERNAL_PREFLIGHT=1 OPENCODE_CONFIG="$TMPROOT/amb1-71" "$INSTALL" >"$TMPROOT/amb1-71.out" 2>"$TMPROOT/amb1-71.err" || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/amb1-71.err" >&2; fail "ambient preflight=1 install exits 0 (got $rc)"; }
[ -f "$TMPROOT/amb1-71/.harness-manifest" ] || fail "ambient preflight=1 installs manifest"
[ ! -s "$TMPROOT/amb1-71.err" ] || fail "ambient preflight=1 emits no errors"
rc=0
HARNESS_INTERNAL_PREFLIGHT=yes OPENCODE_CONFIG="$TMPROOT/amb2-71" "$INSTALL" >"$TMPROOT/amb2-71.out" 2>"$TMPROOT/amb2-71.err" || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/amb2-71.err" >&2; fail "ambient preflight=yes install exits 0 (got $rc)"; }
[ -f "$TMPROOT/amb2-71/.harness-manifest" ] || fail "ambient preflight=yes installs manifest"
[ ! -s "$TMPROOT/amb2-71.err" ] || fail "ambient preflight=yes emits no errors"

mkdir -p "$TMPROOT/race-oc-71/state" "$TMPROOT/race-cx-71/state/quota-ledger.lock"
printf 'agy-opus\tantigravity\t2026-11-09T10:00:00Z\t2026-11-09T15:00:00Z\treviewer-b\t429\n' >"$TMPROOT/race-cx-71/state/quota-ledger.tsv"
touch -t 202001010000 "$TMPROOT/race-cx-71/state/quota-ledger.lock"
(
  for ((attempt = 0; attempt < 5000; attempt++)); do
    if mkdir "$TMPROOT/race-cx-71/state/quota-ledger.lock" 2>/dev/null; then
      ledger="$TMPROOT/race-cx-71/state/quota-ledger.tsv"
      { [ ! -f "$ledger" ] || cat "$ledger"; printf 'codex-race\tcodex\t2026-11-09T14:00:00Z\t2026-11-09T19:00:00Z\treviewer-a\t429\n'; } >"$ledger.writer-tmp"
      mv -f "$ledger.writer-tmp" "$ledger"
      rmdir "$TMPROOT/race-cx-71/state/quota-ledger.lock"
      exit 0
    fi
  done
  exit 1
) &
writer_pid=$!
rc=0
OPENCODE_CONFIG="$TMPROOT/race-oc-71" CODEX_HOME="$TMPROOT/race-cx-71" "$INSTALL" --force --target codex >"$TMPROOT/race-71.out" 2>"$TMPROOT/race-71.err" || rc=$?
writer_rc=0
wait "$writer_pid" || writer_rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/race-71.err" >&2; fail "concurrent ledger migration exits 0 (got $rc)"; }
[ "$writer_rc" -eq 0 ] || fail "concurrent ledger writer acquires lock"
[ -L "$TMPROOT/race-cx-71/state" ] || fail "concurrent ledger migration links target state"
grep -q "$(printf '^agy-opus\t')" "$TMPROOT/race-oc-71/state/quota-ledger.tsv" || fail "concurrent ledger migration preserves source row"
grep -q "$(printf '^codex-race\t')" "$TMPROOT/race-oc-71/state/quota-ledger.tsv" || fail "concurrent ledger migration preserves writer row"
[ ! -e "$TMPROOT/race-oc-71/state/quota-ledger.lock" ] || fail "concurrent ledger migration releases shared lock"
pass "ledger directory locks (stale break, active refusal, release) and ambient preflight env immunity"

# 72. Flat Antigravity layout safety: a symlinked skills/oneshot refuses without
# --force and is repaired without touching the outside tree; a legacy
# plugins/oneshot-harness install migrates into the flat layout under
# --force --prune while preserving sibling plugins; and a non-ledger file in the
# legacy state/ refuses during preflight.
AGY_SYM="$TMPROOT/agy-sym-72"
SYM_OC="$TMPROOT/sym-oc-72"
OUTSIDE_SKILL="$TMPROOT/outside-skill"
mkdir -p "$AGY_SYM/skills" "$OUTSIDE_SKILL"
printf 'OUTSIDE\n' >"$OUTSIDE_SKILL/SKILL.md"
ln -s "$OUTSIDE_SKILL" "$AGY_SYM/skills/oneshot"
rc=0
ANTIGRAVITY_CONFIG="$AGY_SYM" OPENCODE_CONFIG="$SYM_OC" "$INSTALL" --target antigravity >"$TMPROOT/sym-72.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/sym-72.out" >&2; fail "symlinked skills/oneshot refuses without --force (got $rc)"; }
grep -q 'parent symlink under destination' "$TMPROOT/sym-72.out" || fail "symlinked skills/oneshot names the parent symlink"
[ -L "$AGY_SYM/skills/oneshot" ] || fail "refused symlinked skills/oneshot run leaves the symlink in place"
[ "$(cat "$OUTSIDE_SKILL/SKILL.md")" = "OUTSIDE" ] || fail "refused symlinked skills/oneshot run preserves the outside sentinel"
rc=0
ANTIGRAVITY_CONFIG="$AGY_SYM" OPENCODE_CONFIG="$SYM_OC" "$INSTALL" --force --target antigravity >"$TMPROOT/sym-force-72.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/sym-force-72.out" >&2; fail "symlinked skills/oneshot repair install exits 0 (got $rc)"; }
[ -d "$AGY_SYM/skills/oneshot" ] && [ ! -L "$AGY_SYM/skills/oneshot" ] || fail "--force replaces the symlinked skills/oneshot with a real directory"
[ -f "$AGY_SYM/skills/oneshot/SKILL.md" ] && [ ! -L "$AGY_SYM/skills/oneshot/SKILL.md" ] || fail "--force writes a real skills/oneshot/SKILL.md"
cmp -s "$ROOT/skills/oneshot/SKILL.md" "$AGY_SYM/skills/oneshot/SKILL.md" || fail "--force repairs skills/oneshot with source content"
[ -f "$AGY_SYM/skills/_harness/HARNESS.md" ] || fail "repaired antigravity destination carries skills/_harness/HARNESS.md"
[ "$(cat "$OUTSIDE_SKILL/SKILL.md")" = "OUTSIDE" ] || fail "--force repair never modifies the outside skill tree"
pass "--target antigravity refuses a symlinked skills/oneshot without --force and repairs it under --force without touching the outside tree"

AGY_MIG="$TMPROOT/agy-mig-72"
MIG_OC="$TMPROOT/mig-oc"
MIG_LEGACY="$AGY_MIG/plugins/oneshot-harness"
mkdir -p "$MIG_LEGACY/rules" "$MIG_LEGACY/skills/oneshot" "$MIG_LEGACY/agents" "$AGY_MIG/plugins/user-plugin" "$MIG_OC/state"
printf '# harness deadbee\n# profile quad\nplugin.json\nrules/HARNESS.md\nskills/oneshot/SKILL.md\nagents/implementer.md\n' >"$MIG_LEGACY/.harness-manifest"
printf '{"name":"oneshot-harness"}\n' >"$MIG_LEGACY/plugin.json"
printf 'trigger: always_on\nlegacy\n' >"$MIG_LEGACY/rules/HARNESS.md"
printf 'legacy skill\n' >"$MIG_LEGACY/skills/oneshot/SKILL.md"
printf 'legacy agent\n' >"$MIG_LEGACY/agents/implementer.md"
ln -s "$MIG_OC/state" "$MIG_LEGACY/state"
printf 'keep\n' >"$AGY_MIG/plugins/user-plugin/keep.json"
rc=0
ANTIGRAVITY_CONFIG="$AGY_MIG" OPENCODE_CONFIG="$MIG_OC" "$INSTALL" --force --prune --target antigravity >"$TMPROOT/mig-72.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/mig-72.out" >&2; fail "legacy antigravity plugin migration exits 0 (got $rc)"; }
grep -qxF '# profile quad' "$AGY_MIG/.harness-manifest" || fail "legacy migration inherits # profile quad"
grep -qF 'pruned 4 stale file(s)' "$TMPROOT/mig-72.out" || { cat "$TMPROOT/mig-72.out" >&2; fail "legacy migration prunes the four stale plugin files"; }
grep -q "harness updated: deadbee -> $CUR_SHA" "$TMPROOT/mig-72.out" || { cat "$TMPROOT/mig-72.out" >&2; fail "legacy migration reports harness sha update"; }
[ ! -e "$MIG_LEGACY" ] || fail "legacy plugins/oneshot-harness and empty nested dirs are removed"
[ -f "$AGY_MIG/plugins/user-plugin/keep.json" ] || fail "legacy migration preserves a sibling user plugin"
[ -f "$AGY_MIG/skills/oneshot/SKILL.md" ] || fail "legacy migration installs the flat skills layout"

AGY_MIG_KEEP="$TMPROOT/agy-mig-keep-72"
MIG_KEEP_LEGACY="$AGY_MIG_KEEP/plugins/oneshot-harness"
mkdir -p "$MIG_KEEP_LEGACY/skills/oneshot" "$MIG_KEEP_LEGACY/agents" "$MIG_KEEP_LEGACY/nested"
printf '# harness deadbee\n# profile quad\nplugin.json\nskills/oneshot/SKILL.md\nagents/implementer.md\n' >"$MIG_KEEP_LEGACY/.harness-manifest"
printf '{"name":"oneshot-harness"}\n' >"$MIG_KEEP_LEGACY/plugin.json"
printf 'legacy skill\n' >"$MIG_KEEP_LEGACY/skills/oneshot/SKILL.md"
printf 'legacy agent\n' >"$MIG_KEEP_LEGACY/agents/implementer.md"
printf 'user note\n' >"$MIG_KEEP_LEGACY/nested/user-keep.txt"
rc=0
ANTIGRAVITY_CONFIG="$AGY_MIG_KEEP" OPENCODE_CONFIG="$MIG_OC" "$INSTALL" --force --prune --target antigravity >"$TMPROOT/mig-keep-72.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/mig-keep-72.out" >&2; fail "legacy migration with unowned nested file exits 0 (got $rc)"; }
[ -f "$MIG_KEEP_LEGACY/nested/user-keep.txt" ] && [ "$(cat "$MIG_KEEP_LEGACY/nested/user-keep.txt")" = "user note" ] || fail "unowned plugins/oneshot-harness/nested/user-keep.txt survives --prune"
[ ! -e "$MIG_KEEP_LEGACY/plugin.json" ] || fail "managed plugin.json is pruned when unowned file remains"
[ ! -e "$MIG_KEEP_LEGACY/skills" ] || fail "empty managed skills/ dir is removed when unowned file remains"
[ ! -e "$MIG_KEEP_LEGACY/agents" ] || fail "empty managed agents/ dir is removed when unowned file remains"
[ ! -e "$MIG_KEEP_LEGACY/.harness-manifest" ] || fail "legacy .harness-manifest is removed when unowned file remains"
pass "legacy plugins/oneshot-harness migrates to the flat layout, prunes nested entries, and preserves sibling plugins and unowned files"

AGY_BAD="$TMPROOT/agy-bad-72"
BAD_OC="$TMPROOT/bad-oc-72"
BAD_LEGACY="$AGY_BAD/plugins/oneshot-harness"
mkdir -p "$BAD_LEGACY/state"
printf '# harness deadbee\n# profile quad\nplugin.json\n' >"$BAD_LEGACY/.harness-manifest"
printf '{"name":"oneshot-harness"}\n' >"$BAD_LEGACY/plugin.json"
printf 'not a ledger\n' >"$BAD_LEGACY/state/foreign.db"
rc=0
ANTIGRAVITY_CONFIG="$AGY_BAD" OPENCODE_CONFIG="$BAD_OC" "$INSTALL" --force --prune --target antigravity >"$TMPROOT/bad-72.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/bad-72.out" >&2; fail "legacy state non-ledger file refuses even with --force --prune (got $rc)"; }
[ ! -e "$AGY_BAD/.harness-manifest" ] || fail "refused legacy migration writes no root manifest"
[ -f "$BAD_LEGACY/state/foreign.db" ] || fail "refused legacy migration preserves the foreign state file"
pass "a non-ledger file in a legacy state/ refuses during preflight and writes no root manifest"

AGY_LSTATE="$TMPROOT/agy-lstate-72"
LSTATE_OC="$TMPROOT/lstate-oc-72"
mkdir -p "$AGY_LSTATE/plugins/oneshot-harness/state" "$LSTATE_OC/state"
printf '# harness deadbee\n# profile tri\nplugin.json\nstate/quota-ledger.tsv\n' >"$AGY_LSTATE/plugins/oneshot-harness/.harness-manifest"
printf '{"name":"oneshot-harness"}\n' >"$AGY_LSTATE/plugins/oneshot-harness/plugin.json"
printf 'agy-pool\tantigravity\t2026-11-09T12:00:00Z\t2026-11-09T17:00:00Z\timplementer\t429\n' >"$AGY_LSTATE/plugins/oneshot-harness/state/quota-ledger.tsv"
rc=0
ANTIGRAVITY_CONFIG="$AGY_LSTATE" OPENCODE_CONFIG="$LSTATE_OC" "$INSTALL" --force --prune --target antigravity >"$TMPROOT/lstate-72.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/lstate-72.out" >&2; fail "legacy real state/ ledger migration exits 0 (got $rc)"; }
grep -q "$(printf '^agy-pool\t')" "$LSTATE_OC/state/quota-ledger.tsv" || fail "legacy real state/ ledger merges into shared state"
grep -qF 'pruned 1 stale file(s)' "$TMPROOT/lstate-72.out" || { cat "$TMPROOT/lstate-72.out" >&2; fail "legacy state/quota-ledger.tsv is migrated rather than pruned"; }
[ ! -e "$AGY_LSTATE/plugins" ] || fail "empty legacy plugins/ directory is removed when no sibling plugins exist"

AGY_NOMANI="$TMPROOT/agy-nomani-72"
NOMANI_OC="$TMPROOT/nomani-oc-72"
mkdir -p "$AGY_NOMANI/plugins/oneshot-harness/state"
printf 'nomani-pool\tantigravity\t2026-11-09T13:00:00Z\t2026-11-09T18:00:00Z\timplementer\t429\n' >"$AGY_NOMANI/plugins/oneshot-harness/state/quota-ledger.tsv"
rc=0
ANTIGRAVITY_CONFIG="$AGY_NOMANI" OPENCODE_CONFIG="$NOMANI_OC" "$INSTALL" --force --prune --target antigravity >"$TMPROOT/nomani-72.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/nomani-72.out" >&2; fail "manifestless legacy directory under --prune exits 0 (got $rc)"; }
grep -qF 'no previous manifest; prune skipped' "$TMPROOT/nomani-72.out" || { cat "$TMPROOT/nomani-72.out" >&2; fail "manifestless plugins/oneshot-harness prints no previous manifest; prune skipped"; }
[ -f "$AGY_NOMANI/plugins/oneshot-harness/state/quota-ledger.tsv" ] && grep -q "$(printf '^nomani-pool\t')" "$AGY_NOMANI/plugins/oneshot-harness/state/quota-ledger.tsv" || fail "manifestless plugins/oneshot-harness/state/quota-ledger.tsv is left untouched"
if [ -f "$NOMANI_OC/state/quota-ledger.tsv" ] && grep -q "$(printf '^nomani-pool\t')" "$NOMANI_OC/state/quota-ledger.tsv"; then
  fail "manifestless plugins/oneshot-harness ledger must not merge into shared state"
fi
mkdir -p "$AGY_NOMANI/plugins/oneshot-harness/state/quota-ledger.lock" "$AGY_NOMANI/plugins/oneshot-harness/empty-sub"
printf 'foreign\n' >"$AGY_NOMANI/plugins/oneshot-harness/state/foreign.db"
rc=0
ANTIGRAVITY_CONFIG="$AGY_NOMANI" OPENCODE_CONFIG="$NOMANI_OC" "$INSTALL" --force --prune --target antigravity >"$TMPROOT/nomani-72b.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/nomani-72b.out" >&2; fail "repeat --prune ignores locks and non-ledger files under manifestless plugins/oneshot-harness (got $rc)"; }
[ -d "$AGY_NOMANI/plugins/oneshot-harness/empty-sub" ] || fail "repeat --prune never rmdirs under manifestless plugins/oneshot-harness"
[ -f "$AGY_NOMANI/plugins/oneshot-harness/state/quota-ledger.tsv" ] || fail "repeat --prune leaves manifestless plugins/oneshot-harness/state/quota-ledger.tsv untouched"
[ -f "$AGY_NOMANI/plugins/oneshot-harness/state/foreign.db" ] || fail "repeat --prune leaves manifestless plugins/oneshot-harness/state/foreign.db untouched"
pass "manifestless plugins/oneshot-harness and its state/ are left untouched under --prune"

printf 'state\n./state/quota-ledger.tsv\n' >>"$AGY_LSTATE/.harness-manifest"
rc=0
ANTIGRAVITY_CONFIG="$AGY_LSTATE" OPENCODE_CONFIG="$LSTATE_OC" "$INSTALL" --force --prune --target antigravity >"$TMPROOT/lstate-root-agy-72.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/lstate-root-agy-72.out" >&2; fail "root manifest with state entries exits 0 on antigravity (got $rc)"; }
[ -L "$AGY_LSTATE/state" ] || fail "root manifest prune never unlinks state symlink"
grep -qF 'pruned 0 stale file(s)' "$TMPROOT/lstate-root-agy-72.out" || { cat "$TMPROOT/lstate-root-agy-72.out" >&2; fail "root manifest skips state and state/* entries on antigravity"; }
OPENCODE_CONFIG="$LSTATE_OC" "$INSTALL" --force --target opencode >/dev/null
printf 'state\nstate/quota-ledger.tsv\n' >>"$LSTATE_OC/.harness-manifest"
rc=0
OPENCODE_CONFIG="$LSTATE_OC" "$INSTALL" --force --prune --target opencode >"$TMPROOT/lstate-root-oc-72.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/lstate-root-oc-72.out" >&2; fail "root manifest with state entries exits 0 on opencode (got $rc)"; }
grep -q "$(printf '^agy-pool\t')" "$LSTATE_OC/state/quota-ledger.tsv" || fail "root manifest prune never unlinks state/quota-ledger.tsv"
grep -qF 'pruned 0 stale file(s)' "$TMPROOT/lstate-root-oc-72.out" || { cat "$TMPROOT/lstate-root-oc-72.out" >&2; fail "root manifest skips state and state/* entries on opencode"; }
pass "prune_manifest_entries excludes state and state/* on root and legacy manifests"

AGY_LSYM="$TMPROOT/agy-lsym-72"
mkdir -p "$AGY_LSYM/plugins" "$TMPROOT/outside-plugin-72"
ln -s "$TMPROOT/outside-plugin-72" "$AGY_LSYM/plugins/oneshot-harness"
rc=0
ANTIGRAVITY_CONFIG="$AGY_LSYM" OPENCODE_CONFIG="$LSTATE_OC" "$INSTALL" --force --prune --target antigravity >"$TMPROOT/lsym-72.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/lsym-72.out" >&2; fail "symlinked legacy plugins/oneshot-harness refuses under --prune (got $rc)"; }
grep -qF 'refusing to prune through symlink' "$TMPROOT/lsym-72.out" || fail "symlinked legacy plugin refusal diagnostic"
[ ! -e "$AGY_LSYM/.harness-manifest" ] || fail "symlinked legacy plugin refusal writes no root manifest"
pass "legacy real state/ ledger merges cleanly, empty plugins/ is removed, and symlinked legacy plugin refuses under --prune"

# 73. T3 Code Antigravity instances: without a .t3 tree the standalone root
# installs and no .t3 is created; each hash-<id> instance under the T3 userdata
# tree gets a real flat layout sharing one state root; an explicit
# ANTIGRAVITY_CONFIG wins unless T3_USERDATA_DIR opts the instances back in; a
# collision in any discovered root aborts every root before anything is written;
# and unsafe T3 userdata roots, provider paths, and instance symlinks refuse.
state_phys() { ( cd "$1/state" 2>/dev/null && pwd -P ); }

T3_NO_HOME="$TMPROOT/no-t3-home"
rc=0
HOME="$T3_NO_HOME" "$INSTALL" --target antigravity >"$TMPROOT/t3-not3-agy-73.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/t3-not3-agy-73.out" >&2; fail "antigravity install without T3 Code exits 0 (got $rc)"; }
[ -f "$T3_NO_HOME/.gemini/config/skills/_harness/HARNESS.md" ] || fail "standalone antigravity root carries skills/_harness/HARNESS.md"
[ ! -e "$T3_NO_HOME/.t3" ] || fail "an install with no T3 Code never creates a .t3 tree"
rc=0
HOME="$T3_NO_HOME" "$INSTALL" --force --target all >"$TMPROOT/t3-not3-all-73.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/t3-not3-all-73.out" >&2; fail "--target all without T3 Code exits 0 (got $rc)"; }
[ -f "$T3_NO_HOME/.gemini/config/skills/_harness/HARNESS.md" ] || fail "--target all without T3 Code keeps the standalone antigravity root"
[ ! -e "$T3_NO_HOME/.t3" ] || fail "--target all without T3 Code never creates a .t3 tree"
pass "antigravity installs without T3 Code and never creates a .t3 tree"

T3_HOME="$TMPROOT/with-t3-home"
T3_PROV="$T3_HOME/.t3/userdata/providers/antigravity"
mkdir -p "$T3_PROV/hash-one" "$T3_PROV/hash-two"
printf '{}\n' >"$T3_PROV/metadata.json"
rc=0
HOME="$T3_HOME" "$INSTALL" --target antigravity >"$TMPROOT/t3-multi-73.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/t3-multi-73.out" >&2; fail "T3 multi-instance antigravity install exits 0 (got $rc)"; }
for t3_root in "$T3_HOME/.gemini/config" "$T3_PROV/hash-one/config" "$T3_PROV/hash-two/config"; do
  [ -f "$t3_root/skills/oneshot/SKILL.md" ] && [ ! -L "$t3_root/skills/oneshot/SKILL.md" ] || fail "T3 discovery writes a real skills/oneshot/SKILL.md under $t3_root"
  [ -f "$t3_root/skills/_harness/agents/implementer.md" ] || fail "T3 discovery writes skills/_harness/agents/implementer.md under $t3_root"
  [ -f "$t3_root/.harness-manifest" ] || fail "T3 discovery writes .harness-manifest under $t3_root"
  [ -L "$t3_root/state" ] || fail "T3 discovery links state under $t3_root"
  [ "$(state_phys "$t3_root")" = "$(state_phys "$T3_HOME/.config/opencode")" ] || fail "T3 discovery state under $t3_root resolves to the shared opencode state"
done
[ ! -e "$T3_PROV/metadata.json/config" ] || fail "a stray T3 provider file is never treated as an instance"
mkdir -p "$T3_PROV/hash-three"
rc=0
HOME="$T3_HOME" "$INSTALL" --force --target all >"$TMPROOT/t3-multi-all-73.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/t3-multi-all-73.out" >&2; fail "T3 multi-instance --target all exits 0 (got $rc)"; }
[ -f "$T3_PROV/hash-three/config/.harness-manifest" ] || fail "a newly minted T3 instance is discovered on the next install"
[ -f "$T3_PROV/hash-three/config/skills/oneshot/SKILL.md" ] && [ ! -L "$T3_PROV/hash-three/config/skills/oneshot/SKILL.md" ] || fail "a newly minted T3 instance gets real skill files"
pass "T3 Code Antigravity instances are discovered, installed, and share one state root"

ISO_HOME="$TMPROOT/iso-home"
ISO_AGY="$TMPROOT/iso-custom"
ISO_OC="$TMPROOT/iso-oc"
ISO_INST="$ISO_HOME/.t3/userdata/providers/antigravity/hash-untouched"
mkdir -p "$ISO_INST"
rc=0
HOME="$ISO_HOME" ANTIGRAVITY_CONFIG="$ISO_AGY" OPENCODE_CONFIG="$ISO_OC" "$INSTALL" --target antigravity >"$TMPROOT/iso-73a.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/iso-73a.out" >&2; fail "explicit ANTIGRAVITY_CONFIG install exits 0 (got $rc)"; }
[ -f "$ISO_AGY/.harness-manifest" ] || fail "explicit ANTIGRAVITY_CONFIG installs the standalone root"
[ -L "$ISO_AGY/state" ] || fail "explicit ANTIGRAVITY_CONFIG root links shared state"
[ "$(state_phys "$ISO_AGY")" = "$(state_phys "$ISO_OC")" ] || fail "explicit ANTIGRAVITY_CONFIG root state resolves to OPENCODE_CONFIG/state"
[ ! -e "$ISO_INST/config" ] || fail "an explicit ANTIGRAVITY_CONFIG does not force T3 instance discovery"
rc=0
HOME="$ISO_HOME" ANTIGRAVITY_CONFIG="$ISO_AGY" T3_USERDATA_DIR="$ISO_HOME/.t3/userdata" OPENCODE_CONFIG="$ISO_OC" "$INSTALL" --force --target antigravity >"$TMPROOT/iso-73b.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/iso-73b.out" >&2; fail "ANTIGRAVITY_CONFIG with T3_USERDATA_DIR exits 0 (got $rc)"; }
[ -f "$ISO_AGY/.harness-manifest" ] || fail "ANTIGRAVITY_CONFIG with T3_USERDATA_DIR keeps the standalone root"
[ -f "$ISO_INST/config/.harness-manifest" ] || fail "an explicit T3_USERDATA_DIR opts T3 instances back in"
[ -f "$ISO_INST/config/skills/_harness/agents/implementer.md" ] || fail "an opted-in T3 instance gets skills/_harness/agents/implementer.md"
pass "ANTIGRAVITY_CONFIG isolates the standalone root and T3_USERDATA_DIR opts T3 instances back in"

ATOMIC_HOME="$TMPROOT/atomic-t3-home"
ATOMIC_PROV="$ATOMIC_HOME/.t3/userdata/providers/antigravity"
mkdir -p "$ATOMIC_PROV/hash-a" "$ATOMIC_PROV/hash-b/config"
printf 'PRE-EXISTING\n' >"$ATOMIC_PROV/hash-b/config/HARNESS.md"
rc=0
HOME="$ATOMIC_HOME" "$INSTALL" --target all >"$TMPROOT/atomic-73a.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/atomic-73a.out" >&2; fail "a collision in a T3 instance aborts --target all (got $rc)"; }
grep -q 'collision:' "$TMPROOT/atomic-73a.out" || fail "a collision in a T3 instance reports a collision line under --target all"
for atomic_root in "$ATOMIC_HOME/.config/opencode" "$ATOMIC_HOME/.gemini/config" "$ATOMIC_PROV/hash-a/config"; do
  [ ! -e "$atomic_root/.harness-manifest" ] || fail "atomic preflight writes no manifest under $atomic_root"
  [ ! -e "$atomic_root/HARNESS.md" ] || fail "atomic preflight writes no HARNESS.md under $atomic_root"
done
[ "$(cat "$ATOMIC_PROV/hash-b/config/HARNESS.md")" = "PRE-EXISTING" ] || fail "atomic preflight preserves the colliding instance file"
rc=0
HOME="$ATOMIC_HOME" "$INSTALL" --target antigravity >"$TMPROOT/atomic-73b.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/atomic-73b.out" >&2; fail "a collision in a T3 instance aborts --target antigravity (got $rc)"; }
grep -q 'collision:' "$TMPROOT/atomic-73b.out" || fail "a collision in a T3 instance reports a collision line under --target antigravity"
[ ! -e "$ATOMIC_HOME/.gemini/config/.harness-manifest" ] || fail "antigravity-only atomic preflight writes no standalone manifest"
[ ! -e "$ATOMIC_HOME/.gemini/config/HARNESS.md" ] || fail "antigravity-only atomic preflight writes no standalone HARNESS.md"
[ ! -e "$ATOMIC_PROV/hash-a/config/.harness-manifest" ] || fail "antigravity-only atomic preflight writes no clean-instance manifest"
pass "a collision in any discovered root aborts every root before anything is written"

UNSAFE_HOME="$TMPROOT/unsafe-home"
UNSAFE_AGY="$TMPROOT/unsafe-agy"
mkdir -p "$UNSAFE_HOME"
unsafe_idx=0
for unsafe_t3 in "" "/" "$UNSAFE_HOME" "$ROOT"; do
  unsafe_idx=$((unsafe_idx + 1))
  rc=0
  HOME="$UNSAFE_HOME" T3_USERDATA_DIR="$unsafe_t3" ANTIGRAVITY_CONFIG="$UNSAFE_AGY" "$INSTALL" --target antigravity >"$TMPROOT/unsafe-73-$unsafe_idx.out" 2>"$TMPROOT/unsafe-73-$unsafe_idx.err" || rc=$?
  [ "$rc" -eq 1 ] || { cat "$TMPROOT/unsafe-73-$unsafe_idx.err" >&2; fail "unsafe T3_USERDATA_DIR '$unsafe_t3' exits 1 (got $rc)"; }
  grep -qF 'install.sh: refusing unsafe T3 userdata directory:' "$TMPROOT/unsafe-73-$unsafe_idx.err" || { cat "$TMPROOT/unsafe-73-$unsafe_idx.err" >&2; fail "unsafe T3_USERDATA_DIR '$unsafe_t3' refuses with the userdata diagnostic"; }
  [ ! -e "$UNSAFE_AGY/.harness-manifest" ] || fail "unsafe T3_USERDATA_DIR '$unsafe_t3' writes nothing"
done

SYM_T3_HOME="$TMPROOT/sym-t3-home"
SYM_T3_OUT="$TMPROOT/sym-t3-outside"
mkdir -p "$SYM_T3_HOME/.t3/userdata" "$SYM_T3_OUT"
ln -s "$SYM_T3_OUT" "$SYM_T3_HOME/.t3/userdata/providers"
rc=0
HOME="$SYM_T3_HOME" "$INSTALL" --target antigravity >"$TMPROOT/sym-t3-a.out" 2>"$TMPROOT/sym-t3-a.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/sym-t3-a.err" >&2; fail "a symlinked T3 providers directory refuses (got $rc)"; }
grep -qF 'install.sh: refusing unsafe T3 provider path:' "$TMPROOT/sym-t3-a.err" || { cat "$TMPROOT/sym-t3-a.err" >&2; fail "a symlinked T3 providers directory refuses with the provider path diagnostic"; }
[ ! -e "$SYM_T3_HOME/.gemini/config/.harness-manifest" ] || fail "a symlinked T3 providers directory writes nothing"
[ -z "$(ls -A "$SYM_T3_OUT")" ] || fail "a symlinked T3 providers directory never writes into the outside tree"

SYM_T3_HOME2="$TMPROOT/sym-t3-home-2"
SYM_T3_OUT2="$TMPROOT/sym-t3-outside-2"
mkdir -p "$SYM_T3_HOME2/.t3/userdata/providers" "$SYM_T3_OUT2"
ln -s "$SYM_T3_OUT2" "$SYM_T3_HOME2/.t3/userdata/providers/antigravity"
rc=0
HOME="$SYM_T3_HOME2" "$INSTALL" --target antigravity >"$TMPROOT/sym-t3-b.out" 2>"$TMPROOT/sym-t3-b.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/sym-t3-b.err" >&2; fail "a symlinked T3 antigravity provider directory refuses (got $rc)"; }
grep -qF 'install.sh: refusing unsafe T3 provider path:' "$TMPROOT/sym-t3-b.err" || { cat "$TMPROOT/sym-t3-b.err" >&2; fail "a symlinked T3 antigravity provider directory refuses with the provider path diagnostic"; }
[ ! -e "$SYM_T3_HOME2/.gemini/config/.harness-manifest" ] || fail "a symlinked T3 antigravity provider directory writes nothing"
[ -z "$(ls -A "$SYM_T3_OUT2")" ] || fail "a symlinked T3 antigravity provider directory never writes into the outside tree"

LINK_T3_HOME="$TMPROOT/sym-t3-home-link"
LINK_T3_OUT="$TMPROOT/outside-t3"
mkdir -p "$LINK_T3_HOME/.t3/userdata/providers/antigravity" "$LINK_T3_OUT"
ln -s "$LINK_T3_OUT" "$LINK_T3_HOME/.t3/userdata/providers/antigravity/hash-link"
rc=0
HOME="$LINK_T3_HOME" "$INSTALL" --target antigravity >"$TMPROOT/sym-t3-c.out" 2>"$TMPROOT/sym-t3-c.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/sym-t3-c.err" >&2; fail "a symlinked T3 provider instance refuses (got $rc)"; }
grep -qF 'install.sh: refusing symlinked T3 provider instance:' "$TMPROOT/sym-t3-c.err" || { cat "$TMPROOT/sym-t3-c.err" >&2; fail "a symlinked T3 provider instance refuses with the instance diagnostic"; }
[ ! -e "$LINK_T3_HOME/.gemini/config/.harness-manifest" ] || fail "a symlinked T3 provider instance writes nothing"
[ -z "$(ls -A "$LINK_T3_OUT")" ] || fail "a symlinked T3 provider instance never writes into the outside tree"
pass "unsafe T3 userdata roots and symlinked provider paths and instances refuse before writing anything"

SPOOF_HOME="$TMPROOT/spoof-t3-home"
SPOOF_PROV="$SPOOF_HOME/.t3/userdata/providers/antigravity"
mkdir -p "$SPOOF_PROV/hash-spoof" "$SPOOF_PROV/.hidden-dir"
printf '' >"$SPOOF_PROV/.DS_Store"
rc=0
HOME="$SPOOF_HOME" HARNESS_AGY_SINGLE_ROOT=1 ANTIGRAVITY_CONFIG="$SPOOF_PROV/hash-spoof/config" T3_USERDATA_DIR="$SPOOF_HOME/.t3/userdata" \
  "$INSTALL" --target antigravity >"$TMPROOT/spoof-73.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/spoof-73.out" >&2; fail "ambient HARNESS_AGY_SINGLE_ROOT=1 and deduplicated ANTIGRAVITY_CONFIG install exits 0 (got $rc)"; }
[ -f "$SPOOF_PROV/hash-spoof/config/.harness-manifest" ] || fail "deduplicated T3 instance config installs cleanly without --force"
[ ! -e "$SPOOF_PROV/.hidden-dir/config" ] || fail "dotfiles under providers/antigravity are ignored"
mkdir -p "$SPOOF_PROV/hash-spoof-2"
rc=0
HOME="$SPOOF_HOME" HARNESS_AGY_SINGLE_ROOT=1 "$INSTALL" --force --target antigravity >"$TMPROOT/spoof-73b.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/spoof-73b.out" >&2; fail "ambient HARNESS_AGY_SINGLE_ROOT=1 does not suppress T3 discovery (got $rc)"; }
[ -f "$SPOOF_PROV/hash-spoof-2/config/.harness-manifest" ] || fail "ambient HARNESS_AGY_SINGLE_ROOT=1 still discovers hash-spoof-2"

T3_FILE_BAD="$TMPROOT/t3-is-file"
printf 'file\n' >"$T3_FILE_BAD"
ln -s "$TMPROOT/t3-missing-target" "$TMPROOT/t3-dangling"
for extra_unsafe_t3 in "$T3_FILE_BAD" "$TMPROOT/t3-dangling" "$TMPROOT/a/../b" "$ROOT/skills"; do
  rc=0
  HOME="$UNSAFE_HOME" T3_USERDATA_DIR="$extra_unsafe_t3" ANTIGRAVITY_CONFIG="$UNSAFE_AGY" "$INSTALL" --target antigravity >"$TMPROOT/unsafe-extra.out" 2>"$TMPROOT/unsafe-extra.err" || rc=$?
  [ "$rc" -eq 1 ] || { cat "$TMPROOT/unsafe-extra.err" >&2; fail "unsafe T3_USERDATA_DIR '$extra_unsafe_t3' exits 1 (got $rc)"; }
  grep -qF 'install.sh: refusing unsafe T3 userdata directory:' "$TMPROOT/unsafe-extra.err" || { cat "$TMPROOT/unsafe-extra.err" >&2; fail "unsafe T3_USERDATA_DIR '$extra_unsafe_t3' diagnostic"; }
  [ ! -e "$UNSAFE_AGY/.harness-manifest" ] || fail "unsafe T3_USERDATA_DIR '$extra_unsafe_t3' writes nothing"
done
pass "ambient single-root env spoofing is ignored, duplicate roots deduplicate cleanly, and file/dangling/dotdot/source-nested T3 roots refuse"

CFG_SYM_HOME="$TMPROOT/cfg-sym-home"
CFG_SYM_OUT="$TMPROOT/cfg-sym-outside"
mkdir -p "$CFG_SYM_HOME/.t3/userdata/providers/antigravity/hash-cfg-sym" "$CFG_SYM_OUT"
ln -s "$CFG_SYM_OUT" "$CFG_SYM_HOME/.t3/userdata/providers/antigravity/hash-cfg-sym/config"
rc=0
HOME="$CFG_SYM_HOME" "$INSTALL" --target antigravity >"$TMPROOT/cfg-sym.out" 2>"$TMPROOT/cfg-sym.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/cfg-sym.err" >&2; fail "a symlinked T3 instance <id>/config refuses (got $rc)"; }
grep -qF 'install.sh: refusing symlinked T3 provider instance:' "$TMPROOT/cfg-sym.err" || { cat "$TMPROOT/cfg-sym.err" >&2; fail "a symlinked T3 instance <id>/config emits the refusal diagnostic"; }
[ ! -e "$CFG_SYM_HOME/.gemini/config/.harness-manifest" ] || fail "a symlinked T3 instance <id>/config writes no standalone manifest"
[ -z "$(ls -A "$CFG_SYM_OUT")" ] || fail "a symlinked T3 instance <id>/config leaves the outside target empty"

CFG_FILE_HOME="$TMPROOT/cfg-file-home"
mkdir -p "$CFG_FILE_HOME/.t3/userdata/providers/antigravity/hash-cfg-file"
printf 'not-a-dir\n' >"$CFG_FILE_HOME/.t3/userdata/providers/antigravity/hash-cfg-file/config"
rc=0
HOME="$CFG_FILE_HOME" "$INSTALL" --target antigravity >"$TMPROOT/cfg-file.out" 2>"$TMPROOT/cfg-file.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/cfg-file.err" >&2; fail "a non-directory T3 instance <id>/config refuses (got $rc)"; }
grep -qF 'install.sh: refusing symlinked T3 provider instance:' "$TMPROOT/cfg-file.err" || { cat "$TMPROOT/cfg-file.err" >&2; fail "a non-directory T3 instance <id>/config emits the refusal diagnostic"; }
[ ! -e "$CFG_FILE_HOME/.gemini/config/.harness-manifest" ] || fail "a non-directory T3 instance <id>/config writes no standalone manifest"
pass "a symlinked or non-directory T3 <id>/config refuses with exit 1 before writing anything"

UNSET_T3_HOME1="$TMPROOT/unset-t3-file-home"
UNSET_T3_HOME2="$TMPROOT/unset-t3-dangle-home"
mkdir -p "$UNSET_T3_HOME1/.t3" "$UNSET_T3_HOME2/.t3"
printf 'regular-file\n' >"$UNSET_T3_HOME1/.t3/userdata"
ln -s "$TMPROOT/unset-t3-missing-target" "$UNSET_T3_HOME2/.t3/userdata"
rc=0
( unset T3_USERDATA_DIR; HOME="$UNSET_T3_HOME1" "$INSTALL" --target antigravity ) >"$TMPROOT/unset-t3-1.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/unset-t3-1.out" >&2; fail "unset T3_USERDATA_DIR ignores a regular file at ~/.t3/userdata (got $rc)"; }
[ -f "$UNSET_T3_HOME1/.gemini/config/.harness-manifest" ] || fail "unset T3_USERDATA_DIR with file ~/.t3/userdata installs ~/.gemini/config"
[ -f "$UNSET_T3_HOME1/.t3/userdata" ] && [ ! -d "$UNSET_T3_HOME1/.t3/userdata" ] || fail "unset T3_USERDATA_DIR leaves file ~/.t3/userdata untouched"
rc=0
( unset T3_USERDATA_DIR; HOME="$UNSET_T3_HOME2" "$INSTALL" --target antigravity ) >"$TMPROOT/unset-t3-2.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/unset-t3-2.out" >&2; fail "unset T3_USERDATA_DIR ignores a dangling symlink at ~/.t3/userdata (got $rc)"; }
[ -f "$UNSET_T3_HOME2/.gemini/config/.harness-manifest" ] || fail "unset T3_USERDATA_DIR with dangling ~/.t3/userdata installs ~/.gemini/config"
[ -L "$UNSET_T3_HOME2/.t3/userdata" ] && [ ! -e "$TMPROOT/unset-t3-missing-target" ] || fail "unset T3_USERDATA_DIR leaves dangling ~/.t3/userdata untouched without creating target"
pass "unset T3_USERDATA_DIR treats non-directory ~/.t3/userdata as no T3 Code"

INH_HOME="$TMPROOT/inh-t3-home"
INH_PROV="$INH_HOME/.t3/userdata/providers/antigravity"
mkdir -p "$INH_HOME/.gemini/config/plugins/oneshot-harness" "$INH_PROV/hash-x" "$INH_PROV/hash-y/config"
printf '# harness deadbee\n# profile quad\nplugin.json\n' >"$INH_HOME/.gemini/config/plugins/oneshot-harness/.harness-manifest"
printf '{"name":"oneshot-harness"}\n' >"$INH_HOME/.gemini/config/plugins/oneshot-harness/plugin.json"
printf '# harness deadbee\n# profile opencode-go\nHARNESS.md\n' >"$INH_PROV/hash-y/config/.harness-manifest"
printf 'old\n' >"$INH_PROV/hash-y/config/HARNESS.md"
rc=0
HOME="$INH_HOME" "$INSTALL" --force --prune --target antigravity >"$TMPROOT/inh-t3-a.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/inh-t3-a.out" >&2; fail "multi-root antigravity profile inheritance exits 0 (got $rc)"; }
for inh_root in "$INH_HOME/.gemini/config" "$INH_PROV/hash-x/config" "$INH_PROV/hash-y/config"; do
  grep -qxF '# profile quad' "$inh_root/.harness-manifest" || fail "multi-root antigravity inheritance writes '# profile quad' into $inh_root/.harness-manifest"
  cmp -s "$(expected_profile "$ROOT/providers/quad.md")" "$inh_root/PROVIDERS.md" || fail "multi-root antigravity inheritance writes quad PROVIDERS.md into $inh_root"
done
cmp -s "$INH_HOME/.gemini/config/PROVIDERS.md" "$INH_PROV/hash-x/config/PROVIDERS.md" || fail "standalone and hash-x PROVIDERS.md are byte-identical"
cmp -s "$INH_HOME/.gemini/config/PROVIDERS.md" "$INH_PROV/hash-y/config/PROVIDERS.md" || fail "standalone and hash-y PROVIDERS.md are byte-identical"

INH_CUSTOM_PROF="$TMPROOT/inh-custom-profile.md"
{ cat "$ROOT/providers/tri.md"; printf '\n# custom-t3-inherited-marker\n'; } >"$INH_CUSTOM_PROF"
rc=0
HOME="$INH_HOME" "$INSTALL" --force --profile-file "$INH_CUSTOM_PROF" --target antigravity >"$TMPROOT/inh-t3-pf1.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/inh-t3-pf1.out" >&2; fail "--profile-file multi-root antigravity install exits 0 (got $rc)"; }
HOME="$INH_HOME" "$INSTALL" --profile opencode-go --target opencode >"$TMPROOT/inh-t3-oc.out" 2>&1
mkdir -p "$INH_PROV/hash-z"
rc=0
HOME="$INH_HOME" "$INSTALL" --force --target all >"$TMPROOT/inh-t3-pf2.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/inh-t3-pf2.out" >&2; fail "refresh without flags inherits --profile-file into new T3 instance hash-z (got $rc)"; }
expected_pf_line="$(sed -n '2p' "$INH_HOME/.gemini/config/.harness-manifest")"
case "$expected_pf_line" in
  '# profile-file '*) ;;
  *) fail "standalone manifest carries # profile-file line (got: $expected_pf_line)" ;;
esac
[ "$(sed -n '2p' "$INH_PROV/hash-z/config/.harness-manifest")" = "$expected_pf_line" ] || fail "hash-z inherits # profile-file from standalone antigravity manifest"
cmp -s "$(expected_profile "$INH_CUSTOM_PROF")" "$INH_PROV/hash-z/config/PROVIDERS.md" || fail "hash-z receives the inherited external profile file"
grep -qxF '# profile opencode-go' "$INH_HOME/.config/opencode/.harness-manifest" || fail "non-antigravity target preserves its own manifest profile under --target all"

INH_LEG_HOME="$TMPROOT/inh-leg-home"
mkdir -p "$INH_LEG_HOME/.gemini/config" "$INH_LEG_HOME/.t3/userdata/providers/antigravity/hash-leg"
printf 'legacy harness\n' >"$INH_LEG_HOME/.gemini/config/HARNESS.md"
rc=0
HOME="$INH_LEG_HOME" "$INSTALL" --force --target antigravity >"$TMPROOT/inh-leg.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/inh-leg.out" >&2; fail "pre-profiles antigravity multi-root inheritance exits 0 (got $rc)"; }
grep -qF 'profile: opencode-go (previous install predates profiles)' "$TMPROOT/inh-leg.out" || fail "standalone antigravity preserves pre-profiles diagnostic"
grep -qxF '# profile opencode-go' "$INH_LEG_HOME/.gemini/config/.harness-manifest" || fail "standalone pre-profiles root records opencode-go"
grep -qxF '# profile opencode-go' "$INH_LEG_HOME/.t3/userdata/providers/antigravity/hash-leg/config/.harness-manifest" || fail "T3 child inherits opencode-go from pre-profiles standalone root"
pass "multi-root antigravity installs propagate standalone profile, profile-file, and legacy bindings to all T3 instances"

REAL_AGY="$TMPROOT/real-agy-sym"
SYM_INH_HOME="$TMPROOT/sym-inh-home"
SYM_INH_PROV="$SYM_INH_HOME/.t3/userdata/providers/antigravity"
mkdir -p "$REAL_AGY" "$SYM_INH_HOME/.gemini" "$SYM_INH_PROV/hash-sym-inh"
HOME="$SYM_INH_HOME" ANTIGRAVITY_CONFIG="$REAL_AGY" "$INSTALL" --profile quad --target antigravity >"$TMPROOT/sym-inh-seed.out" 2>&1
ln -s "$REAL_AGY" "$SYM_INH_HOME/.gemini/config"
rc=0
HOME="$SYM_INH_HOME" "$INSTALL" --force --target antigravity >"$TMPROOT/sym-inh-a.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/sym-inh-a.out" >&2; fail "symlinked ~/.gemini/config multi-root refresh exits 0 (got $rc)"; }
[ -L "$SYM_INH_HOME/.gemini/config" ] || fail "symlinked ~/.gemini/config remains a symlink after refresh"
for sym_root in "$SYM_INH_HOME/.gemini/config" "$REAL_AGY" "$SYM_INH_PROV/hash-sym-inh/config"; do
  grep -qxF '# profile quad' "$sym_root/.harness-manifest" || fail "symlinked ~/.gemini/config refresh writes '# profile quad' into $sym_root/.harness-manifest"
  cmp -s "$(expected_profile "$ROOT/providers/quad.md")" "$sym_root/PROVIDERS.md" || fail "symlinked ~/.gemini/config refresh writes quad PROVIDERS.md into $sym_root"
done
cmp -s "$SYM_INH_HOME/.gemini/config/PROVIDERS.md" "$SYM_INH_PROV/hash-sym-inh/config/PROVIDERS.md" || fail "symlinked standalone and T3 PROVIDERS.md are byte-identical"

REAL_AGY_LEG="$TMPROOT/real-agy-sym-leg"
SYM_AGY_CFG="$TMPROOT/sym-antigravity-config"
SYM_ENV_HOME="$TMPROOT/sym-env-home"
SYM_ENV_PROV="$SYM_ENV_HOME/.t3/userdata/providers/antigravity"
mkdir -p "$REAL_AGY_LEG/plugins/oneshot-harness" "$SYM_ENV_PROV/hash-sym-env"
printf '# harness deadbee\n# profile quad\nplugin.json\n' >"$REAL_AGY_LEG/plugins/oneshot-harness/.harness-manifest"
printf '{"name":"oneshot-harness"}\n' >"$REAL_AGY_LEG/plugins/oneshot-harness/plugin.json"
ln -s "$REAL_AGY_LEG" "$SYM_AGY_CFG"
rc=0
HOME="$SYM_ENV_HOME" ANTIGRAVITY_CONFIG="$SYM_AGY_CFG" T3_USERDATA_DIR="$SYM_ENV_HOME/.t3/userdata" \
  "$INSTALL" --force --prune --target antigravity >"$TMPROOT/sym-inh-b.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/sym-inh-b.out" >&2; fail "symlinked ANTIGRAVITY_CONFIG legacy multi-root refresh exits 0 (got $rc)"; }
[ -L "$SYM_AGY_CFG" ] || fail "symlinked ANTIGRAVITY_CONFIG remains a symlink after refresh"
for sym_env_root in "$SYM_AGY_CFG" "$REAL_AGY_LEG" "$SYM_ENV_PROV/hash-sym-env/config"; do
  grep -qxF '# profile quad' "$sym_env_root/.harness-manifest" || fail "symlinked ANTIGRAVITY_CONFIG refresh writes '# profile quad' into $sym_env_root/.harness-manifest"
  cmp -s "$(expected_profile "$ROOT/providers/quad.md")" "$sym_env_root/PROVIDERS.md" || fail "symlinked ANTIGRAVITY_CONFIG refresh writes quad PROVIDERS.md into $sym_env_root"
done
cmp -s "$SYM_AGY_CFG/PROVIDERS.md" "$SYM_ENV_PROV/hash-sym-env/config/PROVIDERS.md" || fail "symlinked ANTIGRAVITY_CONFIG and T3 PROVIDERS.md are byte-identical"

INH_SYM_HARN_HOME="$TMPROOT/inh-sym-harn-home"
mkdir -p "$INH_SYM_HARN_HOME/.gemini/config" "$INH_SYM_HARN_HOME/.t3/userdata/providers/antigravity/hash-sym-harn"
printf 'legacy target\n' >"$TMPROOT/legacy-harness-target.md"
ln -s "$TMPROOT/legacy-harness-target.md" "$INH_SYM_HARN_HOME/.gemini/config/HARNESS.md"
rc=0
HOME="$INH_SYM_HARN_HOME" "$INSTALL" --force --target antigravity >"$TMPROOT/inh-sym-harn.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/inh-sym-harn.out" >&2; fail "symlinked legacy HARNESS.md multi-root refresh exits 0 (got $rc)"; }
grep -qxF '# profile opencode-go' "$INH_SYM_HARN_HOME/.gemini/config/.harness-manifest" || fail "standalone symlinked HARNESS.md fallback records opencode-go"
grep -qxF '# profile opencode-go' "$INH_SYM_HARN_HOME/.t3/userdata/providers/antigravity/hash-sym-harn/config/.harness-manifest" || fail "T3 child shares symlinked HARNESS.md fallback opencode-go"

BAD_MAN_HOME="$TMPROOT/bad-man-inh-home"
mkdir -p "$BAD_MAN_HOME/.gemini/config/.harness-manifest" "$BAD_MAN_HOME/.t3/userdata/providers/antigravity/hash-bad-man"
rc=0
HOME="$BAD_MAN_HOME" "$INSTALL" --force --target antigravity >"$TMPROOT/bad-man-inh.out" 2>"$TMPROOT/bad-man-inh.err" || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/bad-man-inh.err" >&2; fail "directory at standalone .harness-manifest exits 1 in multi-root run (got $rc)"; }
grep -qF 'install.sh: manifest path is not a regular file:' "$TMPROOT/bad-man-inh.err" || fail "multi-root bad standalone manifest emits regular-file diagnostic"
[ ! -e "$BAD_MAN_HOME/.t3/userdata/providers/antigravity/hash-bad-man/config/.harness-manifest" ] || fail "multi-root bad standalone manifest writes nothing to T3 instance"

FRESH_SA_HOME="$TMPROOT/fresh-sa-home"
FRESH_SA_PROV="$FRESH_SA_HOME/.t3/userdata/providers/antigravity"
mkdir -p "$FRESH_SA_PROV/hash-a-fresh" "$FRESH_SA_PROV/hash-existing/config"
printf '# harness deadbee\n# profile quad\nHARNESS.md\n' >"$FRESH_SA_PROV/hash-existing/config/.harness-manifest"
printf 'old\n' >"$FRESH_SA_PROV/hash-existing/config/HARNESS.md"
rc=0
HOME="$FRESH_SA_HOME" "$INSTALL" --force --target antigravity >"$TMPROOT/fresh-sa.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/fresh-sa.out" >&2; fail "fresh standalone with existing T3 binding exits 0 (got $rc)"; }
for fsa_root in "$FRESH_SA_HOME/.gemini/config" "$FRESH_SA_PROV/hash-a-fresh/config" "$FRESH_SA_PROV/hash-existing/config"; do
  grep -qxF '# profile quad' "$fsa_root/.harness-manifest" || fail "fresh standalone + existing T3 converges $fsa_root to '# profile quad'"
  cmp -s "$(expected_profile "$ROOT/providers/quad.md")" "$fsa_root/PROVIDERS.md" || fail "fresh standalone + existing T3 writes quad PROVIDERS.md into $fsa_root"
done
cmp -s "$FRESH_SA_HOME/.gemini/config/PROVIDERS.md" "$FRESH_SA_PROV/hash-existing/config/PROVIDERS.md" || fail "fresh standalone and hash-existing PROVIDERS.md are byte-identical"

FRESH_ALL_HOME="$TMPROOT/fresh-all-home"
FRESH_ALL_PROV="$FRESH_ALL_HOME/.t3/userdata/providers/antigravity"
HOME="$FRESH_ALL_HOME" "$INSTALL" --profile opencode-go --target opencode >"$TMPROOT/fresh-all-oc.out" 2>&1
mkdir -p "$FRESH_ALL_PROV/hash-existing/config"
printf '# harness deadbee\n# profile quad\nHARNESS.md\n' >"$FRESH_ALL_PROV/hash-existing/config/.harness-manifest"
printf 'old\n' >"$FRESH_ALL_PROV/hash-existing/config/HARNESS.md"
rc=0
HOME="$FRESH_ALL_HOME" "$INSTALL" --force --target all >"$TMPROOT/fresh-all.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/fresh-all.out" >&2; fail "fresh standalone + existing T3 under --target all exits 0 (got $rc)"; }
grep -qxF '# profile quad' "$FRESH_ALL_HOME/.gemini/config/.harness-manifest" || fail "--target all converges fresh standalone antigravity root to T3 quad binding"
grep -qxF '# profile quad' "$FRESH_ALL_PROV/hash-existing/config/.harness-manifest" || fail "--target all keeps T3 hash-existing on quad"
grep -qxF '# profile opencode-go' "$FRESH_ALL_HOME/.config/opencode/.harness-manifest" || fail "--target all leaves opencode binding untouched when inheriting from T3"
grep -qxF '# profile tri' "$FRESH_ALL_HOME/.codex/.harness-manifest" || fail "--target all leaves fresh codex target on default tri"
pass "symlinked standalone antigravity roots and fresh-standalone T3 roots converge on a single shared profile binding"

BIG_T3_HOME="$TMPROOT/big-t3-home"
BIG_T3_PROV="$BIG_T3_HOME/.t3/userdata/providers/antigravity"
mkdir -p "$BIG_T3_PROV/hash-big"
BIG_T3_PROF="$TMPROOT/prose-big-t3.md"
{
  cat "$ROOT/providers/tri.md"
  awk 'BEGIN { for (i = 0; i < 180; i++) printf "prose filler line %04d ......................................................................\n", i }'
} >"$BIG_T3_PROF"
[ "$(wc -c <"$BIG_T3_PROF")" -gt 24000 ] || fail "oversized test profile fixture exceeds 24000 bytes"
rc=0
HOME="$BIG_T3_HOME" "$INSTALL" --profile-file "$BIG_T3_PROF" --target antigravity >"$TMPROOT/big-t3-agy.out" 2>"$TMPROOT/big-t3-agy.err" || rc=$?
[ "$rc" -eq 2 ] || { cat "$TMPROOT/big-t3-agy.err" >&2; fail "multi-root oversized antigravity rule exits 2 (got $rc)"; }
grep -qF 'antigravity rule file exceeds 24000 bytes' "$TMPROOT/big-t3-agy.err" || fail "multi-root oversized antigravity rule reports 24000-byte diagnostic"
[ ! -e "$BIG_T3_HOME/.gemini/config/.harness-manifest" ] || fail "multi-root oversized rule writes no standalone .harness-manifest"
[ ! -e "$BIG_T3_PROV/hash-big/config/.harness-manifest" ] || fail "multi-root oversized rule writes no T3 instance .harness-manifest"
rc=0
HOME="$BIG_T3_HOME" "$INSTALL" --profile-file "$BIG_T3_PROF" --target all >"$TMPROOT/big-t3-all.out" 2>"$TMPROOT/big-t3-all.err" || rc=$?
[ "$rc" -eq 2 ] || { cat "$TMPROOT/big-t3-all.err" >&2; fail "multi-target oversized antigravity rule exits 2 under --target all (got $rc)"; }
grep -qF 'antigravity rule file exceeds 24000 bytes' "$TMPROOT/big-t3-all.err" || fail "multi-target oversized antigravity rule reports 24000-byte diagnostic"
[ ! -e "$BIG_T3_HOME/.config/opencode/.harness-manifest" ] || fail "atomic preflight on exit 2 writes no opencode .harness-manifest"
[ ! -e "$BIG_T3_HOME/.gemini/config/.harness-manifest" ] || fail "atomic preflight on exit 2 writes no standalone antigravity .harness-manifest"
[ ! -e "$BIG_T3_PROV/hash-big/config/.harness-manifest" ] || fail "atomic preflight on exit 2 writes no T3 antigravity .harness-manifest"
pass "oversized antigravity rule file exits 2 atomically before writing any standalone, T3, or sibling host manifest"

for oneshot_skill in \
  "$T3_HOME/.gemini/config/skills/oneshot/SKILL.md" \
  "$T3_PROV/hash-one/config/skills/oneshot/SKILL.md"; do
  skills_dir="$(dirname "$(dirname "$oneshot_skill")")"
  [ -f "$skills_dir/_harness/agents/implementer.md" ] && [ ! -L "$skills_dir/_harness/agents/implementer.md" ] || fail "grandparent <skills-dir> resolves real _harness/agents/implementer.md from $oneshot_skill"
done
pass "<skills-dir> grandparent resolution finds real _harness/agents/implementer.md across standalone and T3 roots"

# 74. standalone single-provider profiles, multi-provider backup ladders,
# multi-host native dispatch, and strict 3-way decoupling of skills/agents,
# providers/, and the T3 Code host.
rc=0
"$INSTALL" --help >"$TMPROOT/help-74.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/help-74.out" >&2; fail "--help exits 0 (got $rc)"; }
grep -qF 'available profiles: antigravity claude codex opencode-go quad tri' "$TMPROOT/help-74.out" || {
  cat "$TMPROOT/help-74.out" >&2
  fail "--help lists all six built-in profiles"
}
tr '\n' ' ' <"$TMPROOT/help-74.out" | tr -s ' ' | grep -qF "sharing the standalone root's profile binding on refresh" || {
  cat "$TMPROOT/help-74.out" >&2
  fail "--help notes Antigravity standalone and T3 roots share the standalone root's profile binding on refresh"
}

for profile in tri quad opencode-go codex antigravity claude; do
  rc=0
  HOME="$TMPROOT/prof-home-$profile" "$INSTALL" --profile "$profile" --target all >"$TMPROOT/prof-$profile.out" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { cat "$TMPROOT/prof-$profile.out" >&2; fail "--profile $profile --target all exits 0 (got $rc)"; }
  if grep -q 'compacting .* profile prose' "$TMPROOT/prof-$profile.out"; then
    cat "$TMPROOT/prof-$profile.out" >&2
    fail "--profile $profile --target all ships profile prose uncompacted under the 32768-byte limit"
  fi
done

for profile in codex antigravity claude; do
  prof_home="$TMPROOT/prof-home-$profile"
  for manifest in \
    "$prof_home/.config/opencode/.harness-manifest" \
    "$prof_home/.codex/.harness-manifest" \
    "$prof_home/.gemini/config/.harness-manifest" \
    "$prof_home/.claude/.harness-manifest"; do
    [ -f "$manifest" ] || fail "--profile $profile --target all writes $manifest"
    grep -qxF "# profile $profile" "$manifest" || fail "--profile $profile records '# profile $profile' in $manifest"
  done
done

for profile in tri quad opencode-go codex antigravity claude; do
  prof_home="$TMPROOT/prof-home-$profile"
  [ "$(wc -c <"$prof_home/.gemini/config/rules/HARNESS.md")" -lt 24000 ] || fail "$profile profile rules/HARNESS.md is under 24000 bytes"
  [ "$(wc -c <"$prof_home/.gemini/config/rules/PROVIDERS.md")" -lt 24000 ] || fail "$profile profile rules/PROVIDERS.md is under 24000 bytes"
  [ "$(wc -c <"$prof_home/.codex/AGENTS.md")" -lt 32768 ] || fail "$profile profile AGENTS.md is under 32768 bytes"
  [ "$(wc -c <"$prof_home/.claude/CLAUDE.md")" -lt 32768 ] || fail "$profile profile CLAUDE.md is under 32768 bytes"
done

backup_ladder() {
  awk '/^## Backup ladder/ { found = 1; next } found && /^## / { exit } found' "$1"
}
NONREVIEW_ROLES='scout,implementer,implementer-deep,tester,patch,task-reviewer'
backup_ladder "$ROOT/providers/tri.md" >"$TMPROOT/tri-backup-74.txt"
grep -qF "| $NONREVIEW_ROLES | codex |" "$TMPROOT/tri-backup-74.txt" || fail "tri backup ladder carries an explicit non-reviewer codex fallback rung"
grep -qF "| $NONREVIEW_ROLES | antigravity |" "$TMPROOT/tri-backup-74.txt" || fail "tri backup ladder carries an explicit non-reviewer antigravity fallback rung"
grep -qF '| reviewer-a,reviewer-b,reviewer-c | codex |' "$TMPROOT/tri-backup-74.txt" || fail "tri backup ladder carries a codex reviewer rung"
backup_ladder "$ROOT/providers/quad.md" >"$TMPROOT/quad-backup-74.txt"
grep -qF "| $NONREVIEW_ROLES | codex |" "$TMPROOT/quad-backup-74.txt" || fail "quad backup ladder carries an explicit non-reviewer codex fallback rung"
grep -qF "| $NONREVIEW_ROLES | antigravity |" "$TMPROOT/quad-backup-74.txt" || fail "quad backup ladder carries an explicit non-reviewer antigravity fallback rung"
grep -qF "| $NONREVIEW_ROLES | claudeAgent |" "$TMPROOT/quad-backup-74.txt" || fail "quad backup ladder carries an explicit non-reviewer claudeAgent fallback rung"
for rv_prov in codex antigravity claudeAgent; do
  grep -qF "| reviewer-a,reviewer-b,reviewer-c | $rv_prov |" "$TMPROOT/quad-backup-74.txt" || fail "quad backup ladder carries a $rv_prov reviewer rung"
done

for needle in '<skills-dir>/_harness/agents/<seat>.md' spawn_agent invoke_subagent 'degraded task-review: single-family host'; do
  grep -qF "$needle" "$ROOT/AGENTS.md" || fail "AGENTS.md documents the standalone dispatch adapter via $needle"
done
grep -qF 'grandparent of `oneshot/SKILL.md`' "$ROOT/AGENTS.md" || fail "AGENTS.md documents <skills-dir> as grandparent of oneshot/SKILL.md"
grep -qF 'in your `<skills>` list' "$ROOT/AGENTS.md" || fail "AGENTS.md passes literal <skills-dir> instruction to antigravity children"
grep -qE 'never substitut(e|ing) the driver'\''s path' "$ROOT/AGENTS.md" || fail "AGENTS.md forbids substituting the driver's path for antigravity <contract-path>"
[ "$(wc -c <"$ROOT/AGENTS.md")" -lt 21500 ] || fail "AGENTS.md stays under 21500 bytes"
[ $(( $(wc -c <"$ROOT/AGENTS.md") + 2 + $(wc -c <"$ROOT/providers/tri.md") )) -le 32150 ] || fail "combined AGENTS.md + providers/tri.md stays within 32150 bytes"

if grep -rnE 'opencode-go/|req/5h|#(low|medium|high|xhigh|max)\b|gpt-[0-9]|gemini-[0-9]|claude-(opus|sonnet|haiku|fable)' "$ROOT/AGENTS.md" "$ROOT/skills" "$ROOT/agents" >"$TMPROOT/leak-74.out" 2>&1; then
  cat "$TMPROOT/leak-74.out" >&2
  fail "AGENTS.md, skills/ and agents/ carry no model ids or host quota strings"
fi
if grep -rnEi 'opencode|antigravity|codex|claude|t3[-_ ]code|delegate_task|orchestrator_capabilities' "$ROOT/skills" "$ROOT/agents" >"$TMPROOT/host-74.out" 2>&1; then
  cat "$TMPROOT/host-74.out" >&2
  fail "skills/ and agents/ name no providers, hosts, or T3 tools"
fi
for skill_doc in \
  skills/oneshot/SKILL.md \
  skills/dispatch/SKILL.md \
  skills/council/SKILL.md \
  skills/codebase-design/DESIGN-IT-TWICE.md; do
  grep -qF '../_harness/HARNESS.md' "$ROOT/$skill_doc" || fail "$skill_doc carries the host-neutral _harness fallback"
done
for dispatch_doc in \
  skills/dispatch/SKILL.md \
  skills/dispatch/spec-reviewer-prompt.md \
  skills/dispatch/quality-reviewer-prompt.md; do
  grep -qF 'degraded task-review: single-family host' "$ROOT/$dispatch_doc" || fail "$dispatch_doc documents the single-family host fallback for task-reviewer"
done

# 75. Multi-provider T3 Code dispatch priority, lazy MCP discovery, omittedModels, and Step 0 bootstrap gates
p1_line=$(grep -n '^1\. \*\*T3 Code orchestration' "$ROOT/AGENTS.md" | cut -d: -f1 || true)
p2_line=$(grep -n '^2\. \*\*Standalone OpenCode native pin' "$ROOT/AGENTS.md" | cut -d: -f1 || true)
p3_line=$(grep -n '^3\. \*\*Standalone same-provider native dispatch' "$ROOT/AGENTS.md" | cut -d: -f1 || true)
[ -n "$p1_line" ] && [ -n "$p2_line" ] && [ -n "$p3_line" ] || fail "AGENTS.md defines Path 1 T3 Code, Path 2 standalone OpenCode pin, and Path 3 standalone native dispatch"
[ "$p1_line" -lt "$p2_line" ] && [ "$p2_line" -lt "$p3_line" ] || fail "AGENTS.md orders T3 Code orchestration (Path 1) before standalone OpenCode pin (Path 2) and standalone native dispatch (Path 3)"
for ag_needle in \
  '<mcp_servers>' \
  '<appDataDir>/brain/<conversation-id>/mcp/t3-code/{orchestrator_capabilities,delegate_task}.json' \
  'call_mcp_tool' \
  'deferred/tool-search' \
  'NEVER use Path 2/3 native tools' \
  'omittedModels' \
  'Path 4 only if rejected'; do
  grep -qF "$ag_needle" "$ROOT/AGENTS.md" || fail "AGENTS.md documents $ag_needle in Dispatch Adapter"
done
for gate_skill in \
  skills/oneshot/SKILL.md \
  skills/dispatch/SKILL.md \
  skills/council/SKILL.md; do
  grep -qF '## Step 0: Routing Bootstrap' "$ROOT/$gate_skill" || fail "$gate_skill defines ## Step 0: Routing Bootstrap"
  grep -qF '<HARD-GATE>' "$ROOT/$gate_skill" || fail "$gate_skill enforces <HARD-GATE> around Step 0"
done
grep -qF 'carry `Rung:` only' "$ROOT/skills/oneshot/SKILL.md" || fail "oneshot Step 0 documents ad-hoc roles carrying Rung: only"
grep -qF 'carry `Rung:` only' "$ROOT/skills/dispatch/SKILL.md" || fail "dispatch Step 0 documents ad-hoc roles carrying Rung: only"
if sed -n '/^## Step 0: Routing Bootstrap/,/^## /p' "$ROOT/skills/oneshot/SKILL.md" | grep -qF 'oneshot-state.md'; then
  fail "oneshot Step 0 does not write oneshot-state.md before Phase 1 activates the feature branch/worktree"
fi
sed -n '/^## Phase 1: SHAPE/,/^---$/p' "$ROOT/skills/oneshot/SKILL.md" | grep -qF 'oneshot-state.md' || fail "oneshot Phase 1 records active Dispatch Adapter path and primary rungs in oneshot-state.md"
sed -n '/^## State Artifact/,/^## /p' "$ROOT/skills/oneshot/SKILL.md" | grep -qF 'Dispatch Adapter' || fail "oneshot State Artifact records active Dispatch Adapter path and primary rungs"
grep -qF '>= 2' "$ROOT/skills/council/SKILL.md" || fail "council Step 0 enforces >= 2 healthy independent families"
if sed -n '/^## Step 0: Routing Bootstrap/,/^## /p' "$ROOT/skills/council/SKILL.md" | grep -qF 'MUST run on three independent model families'; then
  fail "council Step 0 allows the 2-healthy-family minimum rather than requiring 3 families unconditionally"
fi
if grep -rnE 'never uses Path 1|never using Path 1|Path 1/Path 3' "$ROOT/README.md" "$ROOT/providers" >"$TMPROOT/path1-75.out" 2>&1; then
  cat "$TMPROOT/path1-75.out" >&2
  fail "README.md and providers/ contain no stale Path 1 references where Path 2 is meant"
fi
grep -qF 'spec-reviewer-prompt.md' "$ROOT/skills/oneshot/SKILL.md" || fail "oneshot Phase 3 requires Stage 1 spec-reviewer-prompt.md via task-reviewer"
grep -qF 'quality-reviewer-prompt.md' "$ROOT/skills/oneshot/SKILL.md" || fail "oneshot Phase 3 requires Stage 2 quality-reviewer-prompt.md via task-reviewer"
pass "standalone profiles, multi-provider backup ladders, multi-host dispatch adapter, and strict 3-way decoupling"

# 76. --verify re-checks an installed target without rewriting it, and --doctor
# reports install health without touching the target.
VERIFY_HOME="$TMPROOT/verify-home"
VERIFY_DEST="$VERIFY_HOME/.config/opencode"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" >"$TMPROOT/verify-install.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/verify-install.out" >&2; fail "--verify fixture install exits 0 (got $rc)"; }

find "$VERIFY_DEST" -type f -exec cksum {} + | sort >"$TMPROOT/verify-before.snap"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-ok.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/verify-ok.out" >&2; fail "--verify exits 0 on a freshly installed opencode target (got $rc)"; }
find "$VERIFY_DEST" -type f -exec cksum {} + | sort >"$TMPROOT/verify-after.snap"
cmp -s "$TMPROOT/verify-before.snap" "$TMPROOT/verify-after.snap" || fail "--verify is 100% non-destructive on an existing install"
grep -qF 'opencode.json' "$TMPROOT/verify-ok.out" || fail "--verify warns with opencode.json remediation when opencode.json is absent"

printf '{"instructions": ["%s/HARNESS.md", "%s/PROVIDERS.md"]}\n' "$VERIFY_DEST" "$VERIFY_DEST" >"$VERIFY_DEST/opencode.json"
find "$VERIFY_DEST" -type f -exec cksum {} + | sort >"$TMPROOT/verify-wired-before.snap"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-wired.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/verify-wired.out" >&2; fail "--verify exits 0 when opencode.json wires HARNESS.md and PROVIDERS.md (got $rc)"; }
find "$VERIFY_DEST" -type f -exec cksum {} + | sort >"$TMPROOT/verify-wired-after.snap"
cmp -s "$TMPROOT/verify-wired-before.snap" "$TMPROOT/verify-wired-after.snap" || fail "--verify is 100% non-destructive when opencode.json is wired"
grep -qF '[OK] opencode.json includes HARNESS.md and PROVIDERS.md' "$TMPROOT/verify-wired.out" || fail "--verify reports [OK] when opencode.json includes HARNESS.md and PROVIDERS.md"

rc=0
HOME="$VERIFY_HOME" "$INSTALL" --doctor >"$TMPROOT/doctor-ok.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/doctor-ok.out" >&2; fail "--doctor exits 0 on a valid install (got $rc)"; }
find "$VERIFY_DEST" -type f -exec cksum {} + | sort >"$TMPROOT/doctor-after.snap"
cmp -s "$TMPROOT/verify-wired-before.snap" "$TMPROOT/doctor-after.snap" || fail "--doctor is 100% non-destructive on an existing install"

rc=0
HOME="$TMPROOT/verify-empty-home" "$INSTALL" --verify >"$TMPROOT/verify-uninstalled.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/verify-uninstalled.out" >&2; fail "--verify exits 1 on an uninstalled opencode target (got $rc)"; }

rm "$VERIFY_DEST/HARNESS.md"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-missing.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/verify-missing.out" >&2; fail "--verify exits 1 when an installed required file is missing (got $rc)"; }
grep -qF '[FAIL] required file missing: HARNESS.md' "$TMPROOT/verify-missing.out" || {
  cat "$TMPROOT/verify-missing.out" >&2
  fail "--verify names the missing required file (HARNESS.md)"
}

VERIFY_ALL_HOME="$TMPROOT/verify-all-home"
mkdir -p "$VERIFY_ALL_HOME/.t3/userdata"
rc=0
HOME="$VERIFY_ALL_HOME" "$INSTALL" >"$TMPROOT/verify-t3-tip.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/verify-t3-tip.out" >&2; fail "default install with ~/.t3/userdata exits 0 (got $rc)"; }
grep -qF "tip: T3 Code detected; pass '--target all' to install across all T3-connected providers (Antigravity, Codex, OpenCode, Claude)." "$TMPROOT/verify-t3-tip.out" || {
  cat "$TMPROOT/verify-t3-tip.out" >&2
  fail "default install prints T3 Code detection tip when ~/.t3/userdata exists"
}

rc=0
HOME="$VERIFY_ALL_HOME" "$INSTALL" --force --target all >"$TMPROOT/verify-all-install.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/verify-all-install.out" >&2; fail "--force --target all exits 0 (got $rc)"; }
if grep -qF "tip: T3 Code detected" "$TMPROOT/verify-all-install.out"; then
  fail "explicit --target suppresses T3 Code tip"
fi

rc=0
HOME="$VERIFY_ALL_HOME" "$INSTALL" --verify >"$TMPROOT/verify-discovered.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/verify-discovered.out" >&2; fail "--verify auto-discovers and verifies all 4 installed targets (got $rc)"; }
for tgt_name in "verifying opencode" "verifying codex" "verifying antigravity" "verifying claude"; do
  grep -qF "$tgt_name" "$TMPROOT/verify-discovered.out" || fail "--verify auto-discovery checks $tgt_name"
done

"$INSTALL" --help >"$TMPROOT/verify-help.out" 2>&1
grep -qF -- '--verify' "$TMPROOT/verify-help.out" || fail "--help documents --verify"
grep -qF -- '--doctor' "$TMPROOT/verify-help.out" || fail "--help documents --doctor"

# 76b. Tightened --verify checks: opencode.json JSON/instructions array validation,
# AGENTS.md / CLAUDE.md harness & provider content validation, Antigravity always_on
# frontmatter validation, shared state canonical path validation, manifest-deleted
# target discovery, and existing T3_USERDATA_DIR check for T3 tip.
printf 'not valid json HARNESS.md PROVIDERS.md\n' >"$VERIFY_DEST/opencode.json"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --force >"$TMPROOT/verify-reinstall.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || fail "--force reinstall on verify-home exits 0"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-bad-json.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || fail "--verify exits 0 with WARN on invalid opencode.json (got $rc)"
if grep -qF '[OK] opencode.json' "$TMPROOT/verify-bad-json.out"; then
  cat "$TMPROOT/verify-bad-json.out" >&2
  fail "--verify does not report [OK] when opencode.json is invalid JSON"
fi
grep -qF '[WARN] opencode.json' "$TMPROOT/verify-bad-json.out" || fail "--verify warns when opencode.json is invalid JSON"

printf '{"other": ["%s/HARNESS.md", "%s/PROVIDERS.md"], "instructions": []}\n' "$VERIFY_DEST" "$VERIFY_DEST" >"$VERIFY_DEST/opencode.json"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-outside-inst.out" 2>&1 || rc=$?
if grep -qF '[OK] opencode.json' "$TMPROOT/verify-outside-inst.out"; then
  cat "$TMPROOT/verify-outside-inst.out" >&2
  fail "--verify does not report [OK] when HARNESS.md/PROVIDERS.md appear outside instructions array"
fi
grep -qF '[WARN] opencode.json' "$TMPROOT/verify-outside-inst.out" || fail "--verify warns when instructions array is empty"

# Codex / Claude empty or unrelated instruction files fail --verify
printf 'unrelated instructions\n' >"$VERIFY_ALL_HOME/.codex/AGENTS.md"
rc=0
HOME="$VERIFY_ALL_HOME" "$INSTALL" --verify --target codex >"$TMPROOT/verify-bad-codex.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/verify-bad-codex.out" >&2; fail "--verify fails when codex AGENTS.md has unrelated content (got $rc)"; }
HOME="$VERIFY_ALL_HOME" "$INSTALL" --force --target codex >"$TMPROOT/verify-fix-codex.out" 2>&1

: >"$VERIFY_ALL_HOME/.claude/CLAUDE.md"
rc=0
HOME="$VERIFY_ALL_HOME" "$INSTALL" --verify --target claude >"$TMPROOT/verify-bad-claude.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/verify-bad-claude.out" >&2; fail "--verify fails when claude CLAUDE.md is empty (got $rc)"; }
HOME="$VERIFY_ALL_HOME" "$INSTALL" --force --target claude >"$TMPROOT/verify-fix-claude.out" 2>&1

# Antigravity rules without trigger: always_on fail --verify
printf '# rule without frontmatter\n' >"$VERIFY_ALL_HOME/.gemini/config/rules/HARNESS.md"
rc=0
HOME="$VERIFY_ALL_HOME" "$INSTALL" --verify --target antigravity >"$TMPROOT/verify-bad-agy.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/verify-bad-agy.out" >&2; fail "--verify fails when antigravity rule lacks trigger: always_on (got $rc)"; }
HOME="$VERIFY_ALL_HOME" "$INSTALL" --force --target antigravity >"$TMPROOT/verify-fix-agy.out" 2>&1

# Non-OpenCode target with independent state directory fails --verify
rm -f "$VERIFY_ALL_HOME/.codex/state"
mkdir -p "$VERIFY_ALL_HOME/.codex/state"
rc=0
HOME="$VERIFY_ALL_HOME" "$INSTALL" --verify --target codex >"$TMPROOT/verify-indep-state.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/verify-indep-state.out" >&2; fail "--verify fails when codex has an independent state directory instead of shared state (got $rc)"; }
HOME="$VERIFY_ALL_HOME" "$INSTALL" --force --target codex >"$TMPROOT/verify-fix-codex-state.out" 2>&1

# Automatic discovery includes installed target whose manifest was deleted and fails on missing manifest
rm -f "$VERIFY_ALL_HOME/.claude/.harness-manifest"
rc=0
HOME="$VERIFY_ALL_HOME" "$INSTALL" --verify >"$TMPROOT/verify-del-manifest.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/verify-del-manifest.out" >&2; fail "--verify auto-discovers target with deleted manifest and exits 1 (got $rc)"; }
grep -qF "verifying claude" "$TMPROOT/verify-del-manifest.out" || fail "--verify auto-discovers claude even when .harness-manifest was deleted"
grep -qF "manifest missing" "$TMPROOT/verify-del-manifest.out" || fail "--verify reports missing manifest for discovered claude target"
HOME="$VERIFY_ALL_HOME" "$INSTALL" --force --target claude >"$TMPROOT/verify-restore-claude.out" 2>&1

# T3_USERDATA_DIR pointing to non-existent directory does not print T3 Code detected tip
NO_T3_HOME="$TMPROOT/no-t3-dir-home"
rc=0
HOME="$NO_T3_HOME" T3_USERDATA_DIR="$TMPROOT/nonexistent-t3-userdata" "$INSTALL" >"$TMPROOT/no-t3-tip.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/no-t3-tip.out" >&2; fail "install with non-existent T3_USERDATA_DIR exits 0 (got $rc)"; }
if grep -qF "tip: T3 Code detected" "$TMPROOT/no-t3-tip.out"; then
  cat "$TMPROOT/no-t3-tip.out" >&2
  fail "non-existent T3_USERDATA_DIR does not trigger T3 Code detected tip"
fi

# 76c. Spec compliance: exact target path matching in opencode.json, top-level instructions key only,
# and harness-specific artifact discovery (ignoring generic skills/ directories).
printf '{"instructions": ["/some/other/dir/HARNESS.md", "/some/other/dir/PROVIDERS.md"]}\n' >"$VERIFY_DEST/opencode.json"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-wrong-path.out" 2>&1 || rc=$?
if grep -qF '[OK] opencode.json' "$TMPROOT/verify-wrong-path.out"; then
  cat "$TMPROOT/verify-wrong-path.out" >&2
  fail "--verify does not report [OK] when opencode.json points to HARNESS.md/PROVIDERS.md in another directory"
fi
grep -qF '[WARN] opencode.json' "$TMPROOT/verify-wrong-path.out" || fail "--verify warns when opencode.json points to wrong directory"

printf '{"nested": {"instructions": ["%s/HARNESS.md", "%s/PROVIDERS.md"]}}\n' "$VERIFY_DEST" "$VERIFY_DEST" >"$VERIFY_DEST/opencode.json"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-nested-inst.out" 2>&1 || rc=$?
if grep -qF '[OK] opencode.json' "$TMPROOT/verify-nested-inst.out"; then
  cat "$TMPROOT/verify-nested-inst.out" >&2
  fail "--verify does not report [OK] when instructions key is nested inside another object"
fi
grep -qF '[WARN] opencode.json' "$TMPROOT/verify-nested-inst.out" || fail "--verify warns when top-level instructions key is missing"

printf '{"instructions": ["~/.config/opencode/HARNESS.md", "~/.config/opencode/PROVIDERS.md"]}\n' >"$VERIFY_DEST/opencode.json"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-tilde-inst.out" 2>&1 || rc=$?
grep -qF '[OK] opencode.json includes HARNESS.md and PROVIDERS.md' "$TMPROOT/verify-tilde-inst.out" || {
  cat "$TMPROOT/verify-tilde-inst.out" >&2
  fail "--verify accepts tilde-prefixed target paths in opencode.json"
}

printf '{"instructions": ["%s/HARNESS.md", "%s/PROVIDERS.md"], "instructions": []}\n' "$VERIFY_DEST" "$VERIFY_DEST" >"$VERIFY_DEST/opencode.json"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-dup-inst.out" 2>&1 || rc=$?
if grep -qF '[OK] opencode.json' "$TMPROOT/verify-dup-inst.out"; then
  cat "$TMPROOT/verify-dup-inst.out" >&2
  fail "--verify does not report [OK] when last duplicate top-level instructions key omits harness files"
fi
grep -qF '[WARN] opencode.json' "$TMPROOT/verify-dup-inst.out" || fail "--verify warns when last duplicate top-level instructions key omits harness files"

# 76d. Validate string escapes and use the last top-level instructions value.
json_regression_failures=0
for invalid_escape in '\q' '\u123' '\u12xz'; do
  printf '{"other": "%s", "instructions": ["HARNESS.md", "PROVIDERS.md"]}\n' "$invalid_escape" >"$VERIFY_DEST/opencode.json"
  rc=0
  HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-invalid-escape.out" 2>&1 || rc=$?
  if grep -qF '[OK] opencode.json' "$TMPROOT/verify-invalid-escape.out" ||
     ! grep -qF '[WARN] opencode.json' "$TMPROOT/verify-invalid-escape.out"; then
    printf 'regression: --verify must reject JSON escape %s\n' "$invalid_escape" >&2
    json_regression_failures=$((json_regression_failures + 1))
  fi
done

printf '%s\n' '{"instructions": "none", "instructions": ["HARNESS.md", "PROVIDERS.md"]}' >"$VERIFY_DEST/opencode.json"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-dup-nonarray.out" 2>&1 || rc=$?
if ! grep -qF '[OK] opencode.json includes HARNESS.md and PROVIDERS.md' "$TMPROOT/verify-dup-nonarray.out"; then
  printf 'regression: --verify must accept a valid instructions array after a non-array duplicate\n' >&2
  json_regression_failures=$((json_regression_failures + 1))
fi
[ "$json_regression_failures" -eq 0 ] || fail "JSON parser regressions ($json_regression_failures failures)"
pass "--verify rejects invalid JSON string escapes and accepts the effective last instructions array"

printf '%s\n' '{"other": "\"\\\/\b\f\n\r\t\u00aF", "instructions": ["HARNESS.md", "PROVIDERS.md"]}' >"$VERIFY_DEST/opencode.json"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-valid-escapes.out" 2>&1 || rc=$?
grep -qF '[OK] opencode.json includes HARNESS.md and PROVIDERS.md' "$TMPROOT/verify-valid-escapes.out" || fail "--verify accepts all valid JSON string escapes"
pass "--verify accepts all valid JSON string escapes"

printf '%s\n' '{"instructions": ["HARNESS.md", "PROVIDERS.md"], "instructions": "none"}' >"$VERIFY_DEST/opencode.json"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify >"$TMPROOT/verify-last-nonarray.out" 2>&1 || rc=$?
if grep -qF '[OK] opencode.json' "$TMPROOT/verify-last-nonarray.out"; then
  fail "--verify rejects a final non-array instructions value"
fi
grep -qF '[WARN] opencode.json' "$TMPROOT/verify-last-nonarray.out" || fail "--verify warns about a final non-array instructions value"
pass "--verify rejects a final non-array instructions value"

GENERIC_SKILLS_HOME="$TMPROOT/generic-skills-home"
HOME="$GENERIC_SKILLS_HOME" "$INSTALL" --target opencode >"$TMPROOT/generic-skills-install.out" 2>&1
mkdir -p "$GENERIC_SKILLS_HOME/.codex/skills/unrelated-skill" "$GENERIC_SKILLS_HOME/.claude/skills"
rc=0
HOME="$GENERIC_SKILLS_HOME" "$INSTALL" --verify >"$TMPROOT/generic-skills-verify.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/generic-skills-verify.out" >&2; fail "--verify ignores targets that only have a generic skills/ directory (got $rc)"; }
if grep -qE 'verifying (codex|claude)' "$TMPROOT/generic-skills-verify.out"; then
  cat "$TMPROOT/generic-skills-verify.out" >&2
  fail "--verify does not auto-discover targets with only generic skills/ directories"
fi

# Damaged standalone Antigravity root with remaining harness files is not skipped when T3 instances exist
DAMAGED_AGY_HOME="$TMPROOT/damaged-agy-home"
mkdir -p "$DAMAGED_AGY_HOME/.t3/userdata/providers/antigravity/hash-ok"
HOME="$DAMAGED_AGY_HOME" "$INSTALL" --target antigravity >"$TMPROOT/damaged-agy-install.out" 2>&1
rm -f \
  "$DAMAGED_AGY_HOME/.gemini/config/.harness-manifest" \
  "$DAMAGED_AGY_HOME/.gemini/config/HARNESS.md" \
  "$DAMAGED_AGY_HOME/.gemini/config/skills/oneshot/SKILL.md"
rc=0
HOME="$DAMAGED_AGY_HOME" "$INSTALL" --verify --target antigravity >"$TMPROOT/damaged-agy-verify.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/damaged-agy-verify.out" >&2; fail "--verify fails when standalone antigravity root is damaged alongside valid T3 instance (got $rc)"; }
DAMAGED_AGY_CANON="$(cd "$DAMAGED_AGY_HOME/.gemini/config" && pwd -P)"
grep -qF "verifying antigravity ($DAMAGED_AGY_CANON)" "$TMPROOT/damaged-agy-verify.out" || fail "--verify schedules damaged standalone antigravity root when remaining harness artifacts exist"

# 76e. Deleting an installed file recorded in the manifest causes --verify to print
# [FAIL] manifest file missing: <file> and exit 1.
t_dir="$VERIFY_DEST"
rm "$t_dir/agents/implementer.md"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify --target opencode >"$TMPROOT/verify-76e.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/verify-76e.out" >&2; fail "76e: --verify exits 1 when manifest file agents/implementer.md is missing (got $rc)"; }
grep -qF '[FAIL] manifest file missing: agents/implementer.md' "$TMPROOT/verify-76e.out" || {
  cat "$TMPROOT/verify-76e.out" >&2
  fail "76e: --verify prints [FAIL] manifest file missing: agents/implementer.md"
}
HOME="$VERIFY_HOME" "$INSTALL" --force --target opencode >"$TMPROOT/verify-76e-restore.out" 2>&1
pass "--verify detects missing manifest-recorded file"

# 76f. Tampering with the manifest profile binding causes --verify to fail with exit 1.
sed 's/^# profile tri$/# profile non_existent_profile_xyz/' "$t_dir/.harness-manifest" >"$t_dir/.harness-manifest.tmp"
mv -f "$t_dir/.harness-manifest.tmp" "$t_dir/.harness-manifest"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify --target opencode >"$TMPROOT/verify-76f.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/verify-76f.out" >&2; fail "76f: --verify exits 1 when manifest profile binding is tampered (got $rc)"; }
grep -qF '[FAIL] profile binding' "$TMPROOT/verify-76f.out" || {
  cat "$TMPROOT/verify-76f.out" >&2
  fail "76f: --verify reports [FAIL] profile binding when manifest profile is non_existent_profile_xyz"
}
HOME="$VERIFY_HOME" "$INSTALL" --force --profile tri --target opencode >"$TMPROOT/verify-76f-restore.out" 2>&1
pass "--verify detects tampered manifest profile binding"

# 76g. Dangling symlink on a manifest-recorded file and symlinked quota-ledger.tsv fail --verify.
rm -f "$t_dir/agents/implementer.md"
ln -s "$TMPROOT/nonexistent-manifest-target" "$t_dir/agents/implementer.md"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify --target opencode >"$TMPROOT/verify-76g-dangling.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/verify-76g-dangling.out" >&2; fail "76g: --verify exits 1 when manifest file is a dangling symlink (got $rc)"; }
grep -qF '[FAIL] manifest file missing: agents/implementer.md' "$TMPROOT/verify-76g-dangling.out" || {
  cat "$TMPROOT/verify-76g-dangling.out" >&2
  fail "76g: --verify reports [FAIL] manifest file missing: agents/implementer.md on dangling symlink"
}
rm -f "$t_dir/agents/implementer.md"
HOME="$VERIFY_HOME" "$INSTALL" --force --profile tri --target opencode >"$TMPROOT/verify-76g-restore1.out" 2>&1

printf 'ok\n' >"$TMPROOT/real-ledger.tsv"
rm -f "$t_dir/state/quota-ledger.tsv"
ln -s "$TMPROOT/real-ledger.tsv" "$t_dir/state/quota-ledger.tsv"
rc=0
HOME="$VERIFY_HOME" "$INSTALL" --verify --target opencode >"$TMPROOT/verify-76g-ledger-sym.out" 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { cat "$TMPROOT/verify-76g-ledger-sym.out" >&2; fail "76g: --verify exits 1 when quota-ledger.tsv is a symlink (got $rc)"; }
can_ledger="$(cd "$t_dir/state" && pwd -P)/quota-ledger.tsv"
grep -qF "[FAIL] quota-ledger.tsv cannot be a symlink: $can_ledger" "$TMPROOT/verify-76g-ledger-sym.out" || {
  cat "$TMPROOT/verify-76g-ledger-sym.out" >&2
  fail "76g: --verify reports [FAIL] quota-ledger.tsv cannot be a symlink"
}
rm -f "$t_dir/state/quota-ledger.tsv"
pass "--verify rejects dangling manifest symlinks and symlinked quota-ledger.tsv"

pass "--verify gates installed and uninstalled targets and --doctor accepts a valid install"

# 77. --providers composes a dynamic profile from the exact provider set, records
# the binding, verifies cleanly, and enforces official-provider boundaries and
# the Pro-model purge. Seat C stays on muse-spark-1.3-contributor with the
# deepseek-v4.1-flash fallback for every composition that includes opencode.
prov_reviewer_c_row() {
  awk -F '|' -v want="$2" '
    $2 == " reviewer-c " && $3 == " " want " " {
      p = $4; gsub(/^ +| +$/, "", p)
      m = $5; gsub(/^ +| +$/, "", m)
      print p " " m
    }
  ' "$1"
}

prov_opencode_violations() {
  awk -F '|' 'NF > 7 && $4 == " opencode " && $5 ~ /(claude-|gemini-|gpt-)/ {
    m = $5; gsub(/^ +| +$/, "", m)
    print FILENAME ":" NR ": " m
  }' "$1"
}

prov_purged_models() {
  for prov_pro in deepseek-v4-pro kimi-k3.1-pro mimo-v2.6-pro minimax-m3 qwen3.8-max; do
    grep -nF "$prov_pro" "$1" || true
  done
}

prov_pool_independence() {
  awk -F '|' -v check_lr="$2" '
    function pool_of(prov, model) {
      if (prov == "antigravity") {
        if (model ~ /^claude-/) return "antigravity-claude"
        return "antigravity-gemini"
      }
      if (prov == "codex") return "codex"
      if (prov == "claudeAgent") return "claude-code"
      return "opencode:" model
    }
    /^##[[:space:]]+Quota pools/ { exit }
    NF > 7 && $2 !~ /^ *role *$/ && $2 !~ /^ *:?-+:? *$/ {
      role = $2; gsub(/^ +| +$/, "", role)
      rung = $3; gsub(/^ +| +$/, "", rung)
      prov = $4; gsub(/^ +| +$/, "", prov)
      model = $5; gsub(/^ +| +$/, "", model)
      if (prov == "-") next
      pool = pool_of(prov, model)
      rpool[role, rung] = pool
      roles[role] = 1
    }
    END {
      for (r in roles) {
        if ((r, "primary") in rpool && (r, "fallback") in rpool) {
          if (rpool[r, "fallback"] == rpool[r, "primary"]) {
            print r ": fallback pool (" rpool[r, "fallback"] ") == primary pool (" rpool[r, "primary"] ")"
          }
        }
        if (check_lr == "1" && (r, "last-resort") in rpool) {
          if (rpool[r, "last-resort"] == rpool[r, "primary"] || rpool[r, "last-resort"] == rpool[r, "fallback"]) {
            print r ": last-resort pool (" rpool[r, "last-resort"] ") reuses primary (" rpool[r, "primary"] ") or fallback (" rpool[r, "fallback"] ")"
          }
        }
      }
    }
  ' "$1"
}

prov_role_rung_pool() {
  awk -F '|' -v want_role="$2" -v want_rung="$3" '
    function pool_of(prov, model) {
      if (prov == "antigravity") {
        if (model ~ /^claude-/) return "antigravity-claude"
        return "antigravity-gemini"
      }
      if (prov == "codex") return "codex"
      if (prov == "claudeAgent") return "claude-code"
      return "opencode:" model
    }
    /^##[[:space:]]+Quota pools/ { exit }
    $2 == " " want_role " " && $3 == " " want_rung " " {
      p = $4; gsub(/^ +| +$/, "", p)
      m = $5; gsub(/^ +| +$/, "", m)
      print pool_of(p, m)
    }
  ' "$1"
}

prov_case=0
for prov_combo in antigravity,codex,opencode antigravity,claude,codex,opencode codex,opencode antigravity,opencode opencode; do
  prov_case=$((prov_case + 1))
  prov_home="$TMPROOT/prov-home-$prov_case"
  prov_md="$prov_home/.config/opencode/PROVIDERS.md"
  rc=0
  HOME="$prov_home" "$INSTALL" --providers "$prov_combo" >"$TMPROOT/prov-install-$prov_case.out" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { cat "$TMPROOT/prov-install-$prov_case.out" >&2; fail "--providers $prov_combo exits 0 (got $rc)"; }
  [ -f "$prov_md" ] || fail "--providers $prov_combo installs PROVIDERS.md"
  grep -qxF "# providers $prov_combo" "$prov_home/.config/opencode/.harness-manifest" || fail "--providers $prov_combo records '# providers $prov_combo' in .harness-manifest"
  case "$prov_combo" in
    *antigravity*) [ "$(prov_reviewer_c_row "$prov_md" primary)" = "antigravity gemini-4-carbon" ] || fail "--providers $prov_combo puts Seat C primary on gemini-4-carbon" ;;
  esac
  if awk -F '|' '$2 ~ /^ reviewer-[abc] $/ && $4 == " opencode "' "$prov_md" | grep -q .; then
    fail "--providers $prov_combo puts no reviewer rung on opencode"
  fi
  prov_purged_models "$prov_md" >"$TMPROOT/prov-purged-$prov_case.out"
  if [ -s "$TMPROOT/prov-purged-$prov_case.out" ]; then
    cat "$TMPROOT/prov-purged-$prov_case.out" >&2
    fail "--providers $prov_combo carries no purged Pro models"
  fi
  prov_opencode_violations "$prov_md" >"$TMPROOT/prov-boundary-$prov_case.out"
  if [ -s "$TMPROOT/prov-boundary-$prov_case.out" ]; then
    cat "$TMPROOT/prov-boundary-$prov_case.out" >&2
    fail "--providers $prov_combo routes no Claude, Gemini, or GPT model through opencode"
  fi
  if grep -qF '| opencode-go | opencode | opencode-go/*' "$prov_md"; then
    fail "--providers $prov_combo does not emit wildcard opencode-go/* quota pool row"
  fi
  case "$prov_combo" in
    *,*)
      prov_pool_independence "$prov_md" 1 >"$TMPROOT/prov-pools-$prov_case.out"
      if [ -s "$TMPROOT/prov-pools-$prov_case.out" ]; then
        cat "$TMPROOT/prov-pools-$prov_case.out" >&2
        fail "--providers $prov_combo enforces pool independence across rungs"
      fi
      ;;
  esac
  if [ "$prov_combo" = "codex,opencode" ]; then
    [ "$(prov_role_rung_pool "$prov_md" implementer-deep last-resort)" != "codex" ] || fail "--providers codex,opencode implementer-deep last-resort does not reuse codex pool when opencode pools are available"
  fi
  rc=0
  HOME="$prov_home" "$INSTALL" --verify >"$TMPROOT/prov-verify-$prov_case.out" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { cat "$TMPROOT/prov-verify-$prov_case.out" >&2; fail "--verify accepts the --providers $prov_combo install (got $rc)"; }
  if grep -qF '[FAIL]' "$TMPROOT/prov-verify-$prov_case.out"; then
    cat "$TMPROOT/prov-verify-$prov_case.out" >&2
    fail "--verify reports no [FAIL] for --providers $prov_combo"
  fi
  pass "--providers $prov_combo composes, records, verifies, and keeps the council off opencode"
done

# Non-opencode compositions and the claude alias (canonicalizing to claudeAgent
# in PROVIDERS.md and claude in .harness-manifest) compose and verify cleanly.
for non_oc_combo in antigravity,codex antigravity,claude claude,codex; do
  prov_case=$((prov_case + 1))
  prov_home="$TMPROOT/prov-home-$prov_case"
  prov_md="$prov_home/.config/opencode/PROVIDERS.md"
  rc=0
  HOME="$prov_home" "$INSTALL" --providers "$non_oc_combo" >"$TMPROOT/prov-install-$prov_case.out" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { cat "$TMPROOT/prov-install-$prov_case.out" >&2; fail "--providers $non_oc_combo exits 0 (got $rc)"; }
  [ -f "$prov_md" ] || fail "--providers $non_oc_combo installs PROVIDERS.md"
  grep -qxF "# providers $non_oc_combo" "$prov_home/.config/opencode/.harness-manifest" || fail "--providers $non_oc_combo records '# providers $non_oc_combo' in .harness-manifest"
  if grep -q '| opencode |' "$prov_md"; then
    fail "--providers $non_oc_combo emits no opencode rows"
  fi
  prov_pool_independence "$prov_md" 0 >"$TMPROOT/prov-pools-$prov_case.out"
  if [ -s "$TMPROOT/prov-pools-$prov_case.out" ]; then
    cat "$TMPROOT/prov-pools-$prov_case.out" >&2
    fail "--providers $non_oc_combo enforces fallback pool != primary pool"
  fi
  case "$non_oc_combo" in
    antigravity,*)
      prov_pool_independence "$prov_md" 1 >"$TMPROOT/prov-pools-lr-$prov_case.out"
      if [ -s "$TMPROOT/prov-pools-lr-$prov_case.out" ]; then
        cat "$TMPROOT/prov-pools-lr-$prov_case.out" >&2
        fail "--providers $non_oc_combo enforces pool independence across all 3 rungs"
      fi
      ;;
  esac
  if [ "$non_oc_combo" = "antigravity,claude" ]; then
    [ "$(prov_role_rung_pool "$prov_md" implementer primary)" = "antigravity-claude" ] || fail "--providers antigravity,claude orders antigravity Claude Opus before claudeAgent in implementer"
    [ "$(prov_role_rung_pool "$prov_md" implementer fallback)" = "antigravity-gemini" ] || fail "--providers antigravity,claude implementer fallback is gemini-4-carbon"
    [ "$(prov_role_rung_pool "$prov_md" implementer-deep primary)" = "claude-code" ] || fail "--providers antigravity,claude implementer-deep primary is claudeAgent Fable"
    grep -qF '| implementer | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |' "$prov_md" || fail "--providers antigravity,claude carries the claudeAgent Opus same-model backup row"
  fi
  case "$non_oc_combo" in
    *claude*)
      grep -q '| claudeAgent |' "$prov_md" || fail "--providers $non_oc_combo canonicalizes claude alias to claudeAgent in PROVIDERS.md"
      grep -qF '| claude-code | claudeAgent | * | 5h | - | - |' "$prov_md" || fail "--providers $non_oc_combo emits claudeAgent quota pool"
      ;;
  esac
  rc=0
  HOME="$prov_home" "$INSTALL" --verify >"$TMPROOT/prov-verify-$prov_case.out" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { cat "$TMPROOT/prov-verify-$prov_case.out" >&2; fail "--verify accepts the --providers $non_oc_combo install (got $rc)"; }
  pass "--providers $non_oc_combo composes without opencode and canonicalizes claude to claudeAgent"
done
pass "--providers enforces pool independence across rungs and orders antigravity Claude Opus before claudeAgent"

# Single-provider alias claude (and claudeAgent) canonicalizes to claudeAgent in PROVIDERS.md.
for cld_alias in claude claudeAgent; do
  prov_case=$((prov_case + 1))
  prov_home="$TMPROOT/prov-home-$prov_case"
  prov_md="$prov_home/.config/opencode/PROVIDERS.md"
  rc=0
  HOME="$prov_home" "$INSTALL" --providers "$cld_alias" >"$TMPROOT/prov-install-$prov_case.out" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { cat "$TMPROOT/prov-install-$prov_case.out" >&2; fail "--providers $cld_alias exits 0 (got $rc)"; }
  grep -qxF '# providers claude' "$prov_home/.config/opencode/.harness-manifest" || fail "--providers $cld_alias records '# providers claude' in .harness-manifest"
  grep -q '| claudeAgent |' "$prov_md" || fail "--providers $cld_alias canonicalizes to claudeAgent in PROVIDERS.md"
  rc=0
  HOME="$prov_home" "$INSTALL" --verify >"$TMPROOT/prov-verify-$prov_case.out" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { cat "$TMPROOT/prov-verify-$prov_case.out" >&2; fail "--verify accepts the --providers $cld_alias install (got $rc)"; }
done
pass "--providers claude and claudeAgent canonicalize to claudeAgent in PROVIDERS.md"

# Provider order normalizes to the canonical antigravity,claude,codex,opencode
# order, and a plain refresh reuses the recorded --providers binding.
PROV_REFRESH_HOME="$TMPROOT/prov-refresh-home"
rc=0
HOME="$PROV_REFRESH_HOME" "$INSTALL" --providers opencode,codex >"$TMPROOT/prov-order.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/prov-order.out" >&2; fail "--providers opencode,codex exits 0 (got $rc)"; }
grep -qxF '# providers codex,opencode' "$PROV_REFRESH_HOME/.config/opencode/.harness-manifest" || fail "--providers normalizes provider order to codex,opencode"
rc=0
HOME="$PROV_REFRESH_HOME" "$INSTALL" --force >"$TMPROOT/prov-refresh.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/prov-refresh.out" >&2; fail "refresh without flags reuses the --providers binding (got $rc)"; }
grep -qxF '# providers codex,opencode' "$PROV_REFRESH_HOME/.config/opencode/.harness-manifest" || fail "refresh keeps '# providers codex,opencode'"
rc=0
HOME="$PROV_REFRESH_HOME" "$INSTALL" --verify >"$TMPROOT/prov-refresh-verify.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/prov-refresh-verify.out" >&2; fail "refresh keeps the install verifiable (got $rc)"; }
pass "--providers normalizes provider order and refresh reuses the recorded binding"

# Invalid provider names exit 2 before any write, even with force and prune.
for bad_prov in badprovider antigravity,openai; do
  prov_bad_dest="$TMPROOT/prov-bad-$(printf '%s' "$bad_prov" | tr ',' '-')"
  rc=0
  OPENCODE_CONFIG="$prov_bad_dest" "$INSTALL" --force --prune --providers "$bad_prov" >"$TMPROOT/prov-bad.out" 2>"$TMPROOT/prov-bad.err" || rc=$?
  [ "$rc" -eq 2 ] || fail "invalid --providers exits 2: $bad_prov (got $rc)"
  grep -qF 'install.sh: unknown provider in --providers:' "$TMPROOT/prov-bad.err" || fail "invalid --providers names the offending provider: $bad_prov"
  if [ "$bad_prov" = badprovider ]; then
    grep -qxF 'install.sh: unknown provider in --providers: badprovider (available: antigravity codex claude opencode)' "$TMPROOT/prov-bad.err" || fail "invalid --providers prints the available provider list"
  else
    grep -qxF 'install.sh: unknown provider in --providers: openai (available: antigravity codex claude opencode)' "$TMPROOT/prov-bad.err" || fail "invalid --providers names the offending provider inside a list"
  fi
  [ ! -e "$prov_bad_dest" ] || fail "invalid --providers writes nothing: $bad_prov"
done
pass "invalid --providers names exit 2 and write nothing"

# --providers conflicts with --profile and --profile-file in either order.
for prov_conflict in profile profile-file profile-order; do
  prov_conflict_dest="$TMPROOT/prov-conflict-$prov_conflict"
  rc=0
  case "$prov_conflict" in
    profile)
      OPENCODE_CONFIG="$prov_conflict_dest" "$INSTALL" --providers antigravity,codex --profile tri >"$TMPROOT/prov-conflict.out" 2>"$TMPROOT/prov-conflict.err" || rc=$?
      ;;
    profile-file)
      OPENCODE_CONFIG="$prov_conflict_dest" "$INSTALL" --providers antigravity,codex --profile-file "$ROOT/providers/tri.md" >"$TMPROOT/prov-conflict.out" 2>"$TMPROOT/prov-conflict.err" || rc=$?
      ;;
    profile-order)
      OPENCODE_CONFIG="$prov_conflict_dest" "$INSTALL" --profile tri --providers antigravity,codex >"$TMPROOT/prov-conflict.out" 2>"$TMPROOT/prov-conflict.err" || rc=$?
      ;;
  esac
  [ "$rc" -eq 2 ] || { cat "$TMPROOT/prov-conflict.err" >&2; fail "--providers conflicts with $prov_conflict and exits 2 (got $rc)"; }
  grep -qF 'usage: install.sh' "$TMPROOT/prov-conflict.err" || fail "conflict with $prov_conflict prints usage"
  [ ! -e "$prov_conflict_dest" ] || fail "conflicting flags write nothing: $prov_conflict"
done
pass "--providers conflicts with --profile and --profile-file, exit 2, no writes"

# Shipped multi-provider tables obey the same purge and boundary invariants.
for shipped_providers in "$ROOT/providers/tri.md" "$ROOT/providers/quad.md"; do
  prov_purged_models "$shipped_providers" >"$TMPROOT/shipped-purged.out"
  if [ -s "$TMPROOT/shipped-purged.out" ]; then
    cat "$TMPROOT/shipped-purged.out" >&2
    fail "$(basename "$shipped_providers") carries no purged Pro models"
  fi
  prov_opencode_violations "$shipped_providers" >"$TMPROOT/shipped-boundary.out"
  if [ -s "$TMPROOT/shipped-boundary.out" ]; then
    cat "$TMPROOT/shipped-boundary.out" >&2
    fail "$(basename "$shipped_providers") routes no Claude, Gemini, or GPT model through opencode"
  fi
done
pass "shipped tri and quad tables carry no Pro models and no third-party models on opencode"

# 78. Cybernetic quota resilience: opencode-go pool presence, multi-provider backup diversity,
# and distinct primary families for council seats under 2-provider profiles.
grep -qF '| opencode-go | opencode | * | 5h | - | - |' "$ROOT/providers/tri.md" || fail "tri carries opencode-go pool row"
grep -qF '| opencode-go | opencode | * | 5h | - | - |' "$ROOT/providers/quad.md" || fail "quad carries opencode-go pool row"
grep -qF '| opencode-go | opencode | * | 5h | - | - |' "$ROOT/providers/opencode-go.md" || fail "opencode-go carries opencode-go pool row"
grep -qF '| 8 | scout,implementer,implementer-deep,tester,patch,task-reviewer | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |' "$ROOT/providers/tri.md" || fail "tri backup ladder carries an antigravity Claude fallback rung"
grep -qF '| 11 | scout,implementer,implementer-deep,tester,patch,task-reviewer | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |' "$ROOT/providers/quad.md" || fail "quad backup ladder carries an antigravity Claude fallback rung"
# opencode-go: backup row 1 (variant=high) excludes implementer-deep, so the
# first opencode backup row matching implementer-deep is the variant=max one.
grep -qF '| 1 | implementer,tester,patch | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |' "$ROOT/providers/opencode-go.md" || fail "opencode-go backup row 1 omits implementer-deep"
oc_deep_first="$(awk -F '|' '
  /^## / { inb = ($0 ~ /^## Backup ladder[[:space:]]*$/); next }
  inb && /^[|] *[0-9]+ *[|]/ {
    roles = $3; prov = $4; eff = $6
    gsub(/^ +| +$/, "", roles); gsub(/^ +| +$/, "", prov); gsub(/^ +| +$/, "", eff)
    if (prov != "opencode") next
    if (roles == "*" || ("," roles ",") ~ /,implementer-deep,/) { print eff; exit }
  }
' "$ROOT/providers/opencode-go.md")"
[ "$oc_deep_first" = "variant=max" ] || fail "opencode-go implementer-deep first opencode backup row is variant=max (got '$oc_deep_first')"

seat_cell() {
  awk -F '|' -v seat="$2" -v col="$3" '$2 == " " seat " " && $3 == " primary " { v = $col; gsub(/^ +| +$/, "", v); print v }' "$1"
}

# Under --providers antigravity,claude the captain takes Fable on claudeAgent,
# Seat C takes gemini-4-carbon, and Seat B takes the remaining distinct family.
prov_test_home="$TMPROOT/prov-dual-home"
HOME="$prov_test_home" "$INSTALL" --providers antigravity,claude >/dev/null 2>&1
dual_md="$prov_test_home/.config/opencode/PROVIDERS.md"
[ "$(seat_cell "$dual_md" reviewer-a 5)" = "claude-fable-5-2" ] || fail "--providers antigravity,claude seat A (captain) primary is claude-fable-5-2"
[ "$(seat_cell "$dual_md" reviewer-a 4)" = "claudeAgent" ] || fail "--providers antigravity,claude seat A runs on claudeAgent"
[ "$(seat_cell "$dual_md" reviewer-b 7)" = "google" ] || fail "--providers antigravity,claude seat B primary family differs from seat A"
[ "$(seat_cell "$dual_md" reviewer-c 5)" = "gemini-4-carbon" ] || fail "--providers antigravity,claude seat C primary is gemini-4-carbon"
[ "$(seat_cell "$dual_md" implementer 5)" = "claude-opus-5-5" ] || fail "--providers antigravity,claude implementer primary is claude-opus-5-5"
[ "$(seat_cell "$dual_md" implementer-deep 5)" = "claude-fable-5-2" ] || fail "--providers antigravity,claude implementer-deep primary is claude-fable-5-2"

# Under --providers claude,opencode the council stays on Claude Code with
# pairwise-distinct models (OpenCode never reviews while another provider exists).
prov_oc_home="$TMPROOT/prov-oc-home"
HOME="$prov_oc_home" "$INSTALL" --providers claude,opencode >/dev/null 2>&1
oc_md="$prov_oc_home/.config/opencode/PROVIDERS.md"
oc_seat_a="$(seat_cell "$oc_md" reviewer-a 5)"
oc_seat_b="$(seat_cell "$oc_md" reviewer-b 5)"
oc_seat_c="$(seat_cell "$oc_md" reviewer-c 5)"
[ -n "$oc_seat_a" ] && [ -n "$oc_seat_b" ] && [ -n "$oc_seat_c" ] || fail "claude,opencode seats A, B, and C all exist"
[ "$oc_seat_a" = "claude-fable-5-2" ] || fail "claude,opencode seat A (captain) primary is claude-fable-5-2"
[ "$oc_seat_a" != "$oc_seat_b" ] && [ "$oc_seat_a" != "$oc_seat_c" ] && [ "$oc_seat_b" != "$oc_seat_c" ] || fail "claude,opencode council seats run on pairwise-distinct models"
for oc_seat in reviewer-a reviewer-b reviewer-c; do
  [ "$(seat_cell "$oc_md" "$oc_seat" 4)" = "claudeAgent" ] || fail "claude,opencode $oc_seat stays off opencode"
done

awk -F '|' '
  /^[|] (driver|scout|implementer|implementer-deep|tester|patch|task-reviewer|reviewer-a|reviewer-b|reviewer-c|compaction) [|]/ {
    role = $2; gsub(/^ +| +$/, "", role)
    prov = $4; gsub(/^ +| +$/, "", prov)
    model = $5; gsub(/^ +| +$/, "", model)
    pool = (prov == "antigravity" ? (model ~ /^claude-/ ? "antigravity-claude" : "antigravity-gemini") : (prov == "codex" ? "codex" : (prov == "claudeAgent" ? "claude-code" : "opencode-go")))
    if ((role SUBSEP pool) in seen) {
      exit 1
    }
    seen[role SUBSEP pool] = 1
  }
' "$oc_md" || fail "claude,opencode violates per-role pool distinctness"

awk '/^## Backup ladder/,0' "$oc_md" | grep -qF '| opencode |' || fail "dynamic backup ladder carries opencode"
awk '/^## Backup ladder/,0' "$oc_md" | grep -qF '| claudeAgent |' || fail "dynamic backup ladder carries claudeAgent"

grep -qF '| opencode-go | opencode | * | 5h | - | - |' "$prov_oc_home/.config/opencode/PROVIDERS.md" || fail "dynamic profile with opencode carries opencode-go pool row"
pass "cybernetic quota resilience: opencode-go pools, backup diversity, and dual-provider council seats"

# 79. Harness compliance and council integrity invariants:
# - dispatch forbids manual execution (case-insensitive), has 4 bootstrap checks + driver inline HARD-GATE
# - plan header template does not allow inline execution under dispatch
# - council forbids identical-model self-review (not provider instance),
#   reads author_models/author_families from oneshot-state.md in Step 6 and skips matching author models,
#   enforces all-seats round N+1 reruns, and binds head=<sha> to git rev-parse HEAD
# - land parses effective last council_verdict: PASS and head=<sha> matching
#   local git rev-parse HEAD and remote PR head via gh pr merge --squash --match-head-commit <sha> (plus standalone rule)
# - oneshot records <provider>/<model> in author logs, author_models: + author_families: in state,
#   effective last council_verdict in Phase 7, and recognizes "use the oneshot harness"
# - AGENTS.md routing rules demote reviewer-* on author model conflict, review & council contracts recognize mode=nominal|degraded,
#   carry oneshot-state.md council_verdict + explicit author-family rungs recorded in state, and stay <=21250 bytes
grep -qF 'verify all four bootstrap checks' "$ROOT/skills/dispatch/SKILL.md" || fail "dispatch SKILL.md Step 0 verifies all four bootstrap checks"
grep -qF 'Forbid driver inline execution' "$ROOT/skills/dispatch/SKILL.md" || fail "dispatch SKILL.md carries driver inline execution hard-gate"
if grep -qiF 'manual execution' "$ROOT/skills/dispatch/SKILL.md"; then
  fail "dispatch SKILL.md must not offer manual execution anywhere (case-insensitive)"
fi
if grep -qF 'inline execution with batch checkpoints is also allowed' "$ROOT/skills/plan/SKILL.md"; then
  fail "plan SKILL.md header template must not allow inline execution under dispatch"
fi
grep -qF 'Forbid same-model council seats and author self-review' "$ROOT/skills/council/SKILL.md" || fail "council SKILL.md carries author self-review hard-gate"
if grep -qF 'or provider instance' "$ROOT/skills/council/SKILL.md"; then
  fail "council SKILL.md Step 0 bans identical model only, not provider instance"
fi
sed -n '/^6\. /,/## Fallback mechanics/p' "$ROOT/skills/council/SKILL.md" | grep -qF 'oneshot-state.md' || fail "council SKILL.md Step 6 reads author models and families from oneshot-state.md"
sed -n '/^6\. /,/## Fallback mechanics/p' "$ROOT/skills/council/SKILL.md" | grep -qF 'author_models' || fail "council SKILL.md Step 6 references author_models"
sed -n '/^6\. /,/## Fallback mechanics/p' "$ROOT/skills/council/SKILL.md" | grep -qF 'author_families' || fail "council SKILL.md Step 6 references author_families"
grep -qF 'demote: <seat> -> <provider>/<model> (author model conflict)' "$ROOT/skills/council/SKILL.md" || fail "council SKILL.md announces author model conflict demotion"
grep -qF 'round N+1 review = all active fresh reviewer seats' "$ROOT/skills/council/SKILL.md" || fail "council SKILL.md round loop specifies all active seats"
grep -qF 'git rev-parse HEAD' "$ROOT/skills/council/SKILL.md" || fail "council SKILL.md binds head=<sha> to git rev-parse HEAD"
grep -qF 'council_verdict: PASS' "$ROOT/skills/land/SKILL.md" || fail "land SKILL.md checks council_verdict: PASS in oneshot-state.md"
grep -qiF 'effective last' "$ROOT/skills/land/SKILL.md" || fail "land SKILL.md parses effective last council_verdict from oneshot-state.md"
grep -qF 'head=<sha>' "$ROOT/skills/land/SKILL.md" || fail "land SKILL.md checks head=<sha> in oneshot-state.md"
grep -qF 'git rev-parse HEAD' "$ROOT/skills/land/SKILL.md" || fail "land SKILL.md verifies head=<sha> matches git rev-parse HEAD"
grep -qF 'gh pr merge --squash --match-head-commit <sha>' "$ROOT/skills/land/SKILL.md" || fail "land SKILL.md enforces remote PR head match via gh pr merge --squash --match-head-commit <sha>"
grep -qiF 'standalone' "$ROOT/skills/land/SKILL.md" || fail "land SKILL.md documents standalone consensus PASS outside oneshot"
grep -qF 'Never merge without verified Council consensus PASS' "$ROOT/skills/land/SKILL.md" || fail "land SKILL.md requires verified council consensus PASS before merge"
grep -qF 'use the oneshot harness' "$ROOT/skills/oneshot/SKILL.md" || fail "oneshot SKILL.md description recognizes use the oneshot harness trigger"
sed -n '/^## Phase 3: DISPATCH/,/^---$/p' "$ROOT/skills/oneshot/SKILL.md" | grep -qF '<provider>/<model>' || fail "oneshot SKILL.md Phase 3 step 7 records <provider>/<model> alongside family"
sed -n '/^## Phase 6: COUNCIL/,/^---$/p' "$ROOT/skills/oneshot/SKILL.md" | grep -qF 'council_verdict: PASS round=<n> mode=<nominal|degraded> head=<sha>' || fail "oneshot SKILL.md Phase 6 records council_verdict with head=<sha>"
grep -qF 'Phase 6 Council consensus PASS is recorded' "$ROOT/skills/oneshot/SKILL.md" || fail "oneshot SKILL.md Phase 7 requires council consensus in state artifact"
sed -n '/^## Phase 7: FINISH/,/^---$/p' "$ROOT/skills/oneshot/SKILL.md" | grep -qiF 'effective last' || fail "oneshot SKILL.md Phase 7 checks effective last council_verdict line"
sed -n '/^## Phase 7: FINISH/,/^---$/p' "$ROOT/skills/oneshot/SKILL.md" | grep -qF 'git rev-parse HEAD' || fail "oneshot SKILL.md Phase 7 requires head=<sha> match against git rev-parse HEAD"
sed -n '/^## State Artifact/,/^## /p' "$ROOT/skills/oneshot/SKILL.md" | grep -qF 'author_models:' || fail "oneshot SKILL.md State Artifact includes author_models:"
sed -n '/^## State Artifact/,/^## /p' "$ROOT/skills/oneshot/SKILL.md" | grep -qF 'author_families:' || fail "oneshot SKILL.md State Artifact includes author_families:"
sed -n '/^## Routing Rules/,/^### /p' "$ROOT/AGENTS.md" | grep -qF 'demote: <seat> -> <provider>/<model> (author model conflict)' || fail "AGENTS.md Routing Rules specify author model conflict skip and demotion announcement"
sed -n '/^### Review contracts/,/^## /p' "$ROOT/AGENTS.md" | grep -qF 'oneshot-state.md' || fail "AGENTS.md Review contracts require consensus PASS in oneshot-state.md"
sed -n '/^### Review contracts/,/^## /p' "$ROOT/AGENTS.md" | grep -qF 'council_verdict: PASS' || fail "AGENTS.md Review contracts reference council_verdict: PASS"
sed -n '/^### Review contracts/,/^## Unit Naming Map/p' "$ROOT/AGENTS.md" | grep -qF 'mode=nominal' || fail "AGENTS.md recognizes mode=nominal"
sed -n '/^### Review contracts/,/^## Unit Naming Map/p' "$ROOT/AGENTS.md" | grep -qF 'mode=degraded' || fail "AGENTS.md recognizes mode=degraded"
grep -qF '(`implementer*`, `tester`, `patch`, CI/council fixers)' "$ROOT/AGENTS.md" || fail "AGENTS.md restores explicit author-family rung list"
grep -qF 'producing branch commits recorded in state' "$ROOT/AGENTS.md" || fail "AGENTS.md specifies author-family commits are recorded in state"
grep -qF 'single-seat re-dispatch across rounds is forbidden' "$ROOT/AGENTS.md" || fail "AGENTS.md Council Contract forbids single-seat re-dispatch across rounds"
grep -qF 'No council seat may review code authored by the identical model.' "$ROOT/AGENTS.md" || fail "AGENTS.md Council Contract forbids identical-model self-review"
[ "$(wc -c <"$ROOT/AGENTS.md")" -le 21250 ] || fail "AGENTS.md stays within 21250 byte limit"
pass "harness compliance: context hygiene hard-gate, council integrity, and land pre-merge gate"

# 80. Council captain: reviewer-esc retirement, the Anthropic effort cap,
# ## Single-provider review validation, the --pm backlog tracker, and the
# implementer/council shape of every shipped profile and --providers composition.

# 80a. reviewer-esc is retired: never rendered, removed from stale manifest-owned
# installs without --prune (including skills/_harness on Antigravity), user-owned
# copies survive, and custom profiles that still carry reviewer-esc rows install
# with a warning.
ESC_DEST="$TMPROOT/esc-retire"
OPENCODE_CONFIG="$ESC_DEST" "$INSTALL" </dev/null >"$TMPROOT/esc-retire.out" 2>&1 || { cat "$TMPROOT/esc-retire.out" >&2; fail "80a: fresh install exits 0"; }
[ ! -e "$ESC_DEST/agents/reviewer-esc.md" ] || fail "80a: no agents/reviewer-esc.md is rendered"
if grep -qxF 'agents/reviewer-esc.md' "$ESC_DEST/.harness-manifest"; then fail "80a: manifest does not record reviewer-esc"; fi
printf 'stale escalation seat\n' >"$ESC_DEST/agents/reviewer-esc.md"
printf 'agents/reviewer-esc.md\n' >>"$ESC_DEST/.harness-manifest"
OPENCODE_CONFIG="$ESC_DEST" "$INSTALL" --force </dev/null >"$TMPROOT/esc-retire-refresh.out" 2>&1 || { cat "$TMPROOT/esc-retire-refresh.out" >&2; fail "80a: refresh exits 0"; }
[ ! -e "$ESC_DEST/agents/reviewer-esc.md" ] || fail "80a: refresh without --prune removes the manifest-owned reviewer-esc.md"
grep -qxF 'removed retired file: agents/reviewer-esc.md' "$TMPROOT/esc-retire-refresh.out" || fail "80a: refresh announces the retired file removal"
if grep -qxF 'agents/reviewer-esc.md' "$ESC_DEST/.harness-manifest"; then fail "80a: refresh drops reviewer-esc from the manifest"; fi
printf 'user-owned escalation notes\n' >"$ESC_DEST/agents/reviewer-esc.md"
OPENCODE_CONFIG="$ESC_DEST" "$INSTALL" --force </dev/null >"$TMPROOT/esc-retire-user.out" 2>&1 || fail "80a: refresh with a user-owned reviewer-esc.md exits 0"
[ "$(cat "$ESC_DEST/agents/reviewer-esc.md")" = "user-owned escalation notes" ] || fail "80a: a reviewer-esc.md the installer never recorded is left alone"
ESC_AGY="$TMPROOT/esc-retire-agy"
OPENCODE_CONFIG="$TMPROOT/esc-retire-agy-oc" ANTIGRAVITY_CONFIG="$ESC_AGY" "$INSTALL" --target antigravity </dev/null >"$TMPROOT/esc-agy.out" 2>&1 || { cat "$TMPROOT/esc-agy.out" >&2; fail "80a: antigravity install exits 0"; }
printf 'stale\n' >"$ESC_AGY/agents/reviewer-esc.md"
printf 'stale\n' >"$ESC_AGY/skills/_harness/agents/reviewer-esc.md"
printf 'agents/reviewer-esc.md\nskills/_harness/agents/reviewer-esc.md\n' >>"$ESC_AGY/.harness-manifest"
OPENCODE_CONFIG="$TMPROOT/esc-retire-agy-oc" ANTIGRAVITY_CONFIG="$ESC_AGY" "$INSTALL" --target antigravity --force </dev/null >"$TMPROOT/esc-agy-refresh.out" 2>&1 || { cat "$TMPROOT/esc-agy-refresh.out" >&2; fail "80a: antigravity refresh exits 0"; }
[ ! -e "$ESC_AGY/agents/reviewer-esc.md" ] || fail "80a: antigravity refresh removes agents/reviewer-esc.md"
[ ! -e "$ESC_AGY/skills/_harness/agents/reviewer-esc.md" ] || fail "80a: antigravity refresh removes skills/_harness/agents/reviewer-esc.md"
{ cat "$ROOT/providers/tri.md"
  printf '| reviewer-esc | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |\n'
  printf '| reviewer-esc | fallback | claudeAgent | claude-opus-5-5 | effort=max | anthropic | ok |\n'
} >"$TMPROOT/esc-custom.md"
ESC_CUSTOM_ABS="$(cd "$TMPROOT" && pwd -P)/esc-custom.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/esc-custom-dest" "$INSTALL" --profile-file "$ESC_CUSTOM_ABS" </dev/null >"$TMPROOT/esc-custom.out" 2>"$TMPROOT/esc-custom.err" || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/esc-custom.err" >&2; fail "80a: a custom profile with reviewer-esc rows still installs (got $rc)"; }
grep -qxF "install.sh: profile $ESC_CUSTOM_ABS: reviewer-esc rows ignored (role retired; captain replaces escalation)" "$TMPROOT/esc-custom.err" || { cat "$TMPROOT/esc-custom.err" >&2; fail "80a: reviewer-esc rows trigger the exact retirement warning"; }
[ "$(grep -c 'reviewer-esc rows ignored' "$TMPROOT/esc-custom.err")" -eq 1 ] || fail "80a: the retirement warning prints once"
pass "reviewer-esc is retired: not rendered, stale manifest-owned copies removed without --prune, custom rows ignored with a warning"

# 80b. Anthropic effort cap on role, backup and single-provider rows.
CAP_BASE="$TMPROOT/cap-base.md"
cp "$ROOT/providers/quad.md" "$CAP_BASE"
cap_reject() {
  local label="$1" diagnostic="$2" rc=0
  OPENCODE_CONFIG="$TMPROOT/cap-dest" "$INSTALL" --profile-file "$TMPROOT/cap.md" </dev/null >"$TMPROOT/cap.out" 2>"$TMPROOT/cap.err" || rc=$?
  [ "$rc" -eq 1 ] || { cat "$TMPROOT/cap.err" >&2; fail "80b: $label exits 1 (got $rc)"; }
  grep -qxF "$diagnostic" "$TMPROOT/cap.err" || { cat "$TMPROOT/cap.err" >&2; fail "80b: $label diagnostic"; }
  [ ! -e "$TMPROOT/cap-dest" ] || fail "80b: $label writes nothing"
}
CAP_ABS="$(cd "$TMPROOT" && pwd -P)/cap.md"
for cap_effort in effort=xhigh effort=max effort=ultrathink effort=ultracode thinking_level=max variant=xhigh; do
  awk -v e="$cap_effort" '{ if ($0 == "| driver | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |") print "| driver | fallback | claudeAgent | claude-sonnet-5-5 | " e " | anthropic | ok |"; else print }' "$CAP_BASE" >"$TMPROOT/cap.md"
  cap_reject "role row $cap_effort" "install.sh: profile $CAP_ABS invalid row: driver fallback: anthropic effort above high"
done
awk '{ if ($0 == "| 1 | implementer | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |") print "| 1 | implementer | claudeAgent | claude-opus-5-5 | effort=max | anthropic | ok |"; else print }' "$CAP_BASE" >"$TMPROOT/cap.md"
cap_reject "backup row effort=max" "install.sh: profile $CAP_ABS invalid backup row: 1: anthropic effort above high"
awk '{ if ($0 == "| antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |") print "| antigravity | claude-opus-5-5 | thinking_level=xhigh | anthropic | ok |"; else print }' "$CAP_BASE" >"$TMPROOT/cap.md"
cap_reject "single-provider row thinking_level=xhigh" "install.sh: profile $CAP_ABS invalid single-provider row: antigravity claude-opus-5-5: anthropic effort above high"
for cap_ok in - effort=low effort=medium effort=high; do
  awk -v e="$cap_ok" '{ if ($0 == "| driver | fallback | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |") print "| driver | fallback | claudeAgent | claude-sonnet-5-5 | " e " | anthropic | ok |"; else print }' "$CAP_BASE" >"$TMPROOT/cap.md"
  rm -rf "$TMPROOT/cap-ok-dest"
  rc=0
  OPENCODE_CONFIG="$TMPROOT/cap-ok-dest" "$INSTALL" --profile-file "$TMPROOT/cap.md" </dev/null >"$TMPROOT/cap-ok.out" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { cat "$TMPROOT/cap-ok.out" >&2; fail "80b: anthropic effort $cap_ok is accepted"; }
done
pass "anthropic effort cap rejects role, backup and single-provider rows above high and accepts -, low, medium, high"

# 80c. ## Single-provider review rows are validated like dispatched rows;
# ## Project management is prose the validator ignores.
SP_BASE="$TMPROOT/sp-base.md"
strip_profile_section "$ROOT/providers/codex.md" 'Single-provider review' >"$SP_BASE"
SP_ABS="$(cd "$TMPROOT" && pwd -P)/sp.md"
while IFS=';' read -r label row diagnostic; do
  { cat "$SP_BASE"; printf '\n## Single-provider review\n\n| provider | model | effort | family | privacy |\n| --- | --- | --- | --- | --- |\n%s\n' "$row"; } >"$TMPROOT/sp.md"
  rc=0
  OPENCODE_CONFIG="$TMPROOT/sp-dest" "$INSTALL" --profile-file "$TMPROOT/sp.md" </dev/null >"$TMPROOT/sp.out" 2>"$TMPROOT/sp.err" || rc=$?
  [ "$rc" -eq 1 ] || { cat "$TMPROOT/sp.err" >&2; fail "80c: single-provider $label exits 1 (got $rc)"; }
  grep -qxF "install.sh: profile $SP_ABS invalid single-provider row: $diagnostic" "$TMPROOT/sp.err" || { cat "$TMPROOT/sp.err" >&2; fail "80c: single-provider $label diagnostic"; }
  [ ! -e "$TMPROOT/sp-dest" ] || fail "80c: single-provider $label writes nothing"
done <<'SPROWS'
four cells;| codex | gpt-6-astra | reasoningEffort=high | openai |;codex gpt-6-astra: expected 5 cells
empty model;| codex |  | reasoningEffort=high | openai | ok |;codex : empty cell
bad provider;| bad_id | gpt-6-astra | reasoningEffort=high | openai | ok |;bad_id gpt-6-astra: invalid provider
bad model;| codex | x: | reasoningEffort=high | openai | ok |;codex x:: invalid model
bad effort;| codex | gpt-6-astra | high | openai | ok |;codex gpt-6-astra: invalid effort
bad family;| codex | gpt-6-astra | reasoningEffort=high | OpenAI | ok |;codex gpt-6-astra: invalid family
bad privacy;| codex | gpt-6-astra | reasoningEffort=high | openai | maybe |;codex gpt-6-astra: invalid privacy
SPROWS
{ cat "$SP_BASE"; printf '\n## Project management\n\nbacklog_tracker: linear\n\n| not | a | validated | table |\n| scout | primary | bogus |\n'; } >"$TMPROOT/sp.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/sp-pm-dest" "$INSTALL" --profile-file "$TMPROOT/sp.md" </dev/null >"$TMPROOT/sp-pm.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || { cat "$TMPROOT/sp-pm.out" >&2; fail "80c: ## Project management content is ignored by the validator"; }
[ "$(grep -c '^## Project management$' "$TMPROOT/sp-pm-dest/PROVIDERS.md")" -eq 1 ] || fail "80c: an embedded ## Project management section is replaced, not duplicated"
grep -qxF 'backlog_tracker: auto' "$TMPROOT/sp-pm-dest/PROVIDERS.md" || fail "80c: the rendered tracker comes from the install, not the source file"
pass "single-provider review rows are validated and ## Project management is ignored by the validator"

# 80d. --pm records, renders and reuses the backlog tracker.
for pm_val in auto github linear jira none; do
  pm_dest="$TMPROOT/pm-$pm_val"
  OPENCODE_CONFIG="$pm_dest" "$INSTALL" --pm "$pm_val" </dev/null >"$TMPROOT/pm.out" 2>&1 || { cat "$TMPROOT/pm.out" >&2; fail "80d: --pm $pm_val exits 0"; }
  [ "$(sed -n '3p' "$pm_dest/.harness-manifest")" = "# pm $pm_val" ] || fail "80d: manifest line 3 records # pm $pm_val"
  cmp -s "$(expected_profile "$ROOT/providers/tri.md" "$pm_val")" "$pm_dest/PROVIDERS.md" || fail "80d: PROVIDERS.md ends with backlog_tracker: $pm_val"
done
OPENCODE_CONFIG="$TMPROOT/pm-linear" "$INSTALL" --force </dev/null >"$TMPROOT/pm-refresh.out" 2>&1 || fail "80d: refresh exits 0"
grep -qxF '# pm linear' "$TMPROOT/pm-linear/.harness-manifest" || fail "80d: refresh without --pm reuses the recorded tracker"
grep -qxF 'backlog_tracker: linear' "$TMPROOT/pm-linear/PROVIDERS.md" || fail "80d: refresh re-renders the recorded tracker"
OPENCODE_CONFIG="$TMPROOT/pm-linear" "$INSTALL" --force --pm=github </dev/null >"$TMPROOT/pm-switch.out" 2>&1 || fail "80d: --pm=github refresh exits 0"
grep -qxF '# pm github' "$TMPROOT/pm-linear/.harness-manifest" || fail "80d: an explicit --pm replaces the recorded tracker"
[ "$(grep -c '^## Project management$' "$TMPROOT/pm-linear/PROVIDERS.md")" -eq 1 ] || fail "80d: refresh renders exactly one ## Project management section"
OPENCODE_CONFIG="$TMPROOT/pm-default" "$INSTALL" </dev/null >"$TMPROOT/pm-default.out" 2>&1 || fail "80d: default install exits 0"
grep -qxF '# pm auto' "$TMPROOT/pm-default/.harness-manifest" || fail "80d: non-interactive installs default to auto"
if grep -qF 'Backlog tracker [' "$TMPROOT/pm-default.out"; then fail "80d: non-interactive installs never prompt"; fi
for pm_bad in trello GitHub ''; do
  rc=0
  OPENCODE_CONFIG="$TMPROOT/pm-bad-dest" "$INSTALL" --force --prune --pm "$pm_bad" </dev/null >"$TMPROOT/pm-bad.out" 2>"$TMPROOT/pm-bad.err" || rc=$?
  [ "$rc" -eq 2 ] || fail "80d: --pm '$pm_bad' exits 2 (got $rc)"
  grep -qxF "install.sh: unknown --pm value: $pm_bad (expected auto|github|linear|jira|none)" "$TMPROOT/pm-bad.err" || { cat "$TMPROOT/pm-bad.err" >&2; fail "80d: --pm '$pm_bad' diagnostic"; }
  [ ! -e "$TMPROOT/pm-bad-dest" ] || fail "80d: --pm '$pm_bad' writes nothing"
done
rc=0
OPENCODE_CONFIG="$TMPROOT/pm-bad-dest" "$INSTALL" --pm=bogus </dev/null >/dev/null 2>"$TMPROOT/pm-bad.err" || rc=$?
[ "$rc" -eq 2 ] && grep -qxF 'install.sh: unknown --pm value: bogus (expected auto|github|linear|jira|none)' "$TMPROOT/pm-bad.err" || fail "80d: --pm=bogus exits 2 with the diagnostic"
"$INSTALL" --help >"$TMPROOT/pm-help.out" 2>&1
grep -qF -- '--pm TRACKER' "$TMPROOT/pm-help.out" || fail "80d: --help documents --pm"
PM_ALL_HOME="$TMPROOT/pm-all-home"
HOME="$PM_ALL_HOME" "$INSTALL" --target all --pm jira </dev/null >"$TMPROOT/pm-all.out" 2>&1 || { cat "$TMPROOT/pm-all.out" >&2; fail "80d: --target all --pm jira exits 0"; }
for pm_root in .config/opencode .codex .gemini/config .claude; do
  grep -qxF '# pm jira' "$PM_ALL_HOME/$pm_root/.harness-manifest" || fail "80d: --target all forwards --pm to $pm_root"
  grep -qxF 'backlog_tracker: jira' "$PM_ALL_HOME/$pm_root/PROVIDERS.md" || fail "80d: $pm_root/PROVIDERS.md renders the tracker"
done
grep -qxF 'backlog_tracker: jira' "$PM_ALL_HOME/.codex/AGENTS.md" || fail "80d: codex AGENTS.md carries backlog_tracker"
grep -qxF 'backlog_tracker: jira' "$PM_ALL_HOME/.claude/CLAUDE.md" || fail "80d: claude CLAUDE.md carries backlog_tracker"
grep -qxF 'backlog_tracker: jira' "$PM_ALL_HOME/.gemini/config/rules/PROVIDERS.md" || fail "80d: antigravity rules/PROVIDERS.md carries backlog_tracker"
HOME="$PM_ALL_HOME" "$INSTALL" --verify </dev/null >"$TMPROOT/pm-all-verify.out" 2>&1 || { cat "$TMPROOT/pm-all-verify.out" >&2; fail "80d: --verify accepts installs carrying ## Project management"; }
if script -qec true /dev/null >/dev/null 2>&1; then
  PM_TTY_DEST="$TMPROOT/pm-tty"
  printf 'linear\n' | OPENCODE_CONFIG="$PM_TTY_DEST" script -qec "$INSTALL" /dev/null >"$TMPROOT/pm-tty.out" 2>&1 || true
  grep -qF 'Backlog tracker [auto/github/linear/jira/none] (auto):' "$TMPROOT/pm-tty.out" || { cat "$TMPROOT/pm-tty.out" >&2; fail "80d: an interactive install prompts once for the backlog tracker"; }
  grep -qxF '# pm linear' "$PM_TTY_DEST/.harness-manifest" || fail "80d: the prompt answer is recorded"
  printf 'github\n' | OPENCODE_CONFIG="$PM_TTY_DEST" script -qec "$INSTALL --force" /dev/null >"$TMPROOT/pm-tty2.out" 2>&1 || true
  if grep -qF 'Backlog tracker [' "$TMPROOT/pm-tty2.out"; then fail "80d: a recorded tracker suppresses the prompt"; fi
  grep -qxF '# pm linear' "$PM_TTY_DEST/.harness-manifest" || fail "80d: an interactive refresh keeps the recorded tracker"
  pass "--pm prompts once on a TTY when no tracker is recorded"
  # Mixed-state multi-target TTY run: the prompt answer is only a default for
  # roots without a recorded tracker; a recorded tracker is never overwritten.
  PM_MIX_OC="$TMPROOT/pm-mix-tty-oc"
  PM_MIX_CX="$TMPROOT/pm-mix-tty-codex"
  OPENCODE_CONFIG="$PM_MIX_OC" "$INSTALL" --pm linear </dev/null >"$TMPROOT/pm-mix-seed.out" 2>&1 || { cat "$TMPROOT/pm-mix-seed.out" >&2; fail "80d: seeding a linear root exits 0"; }
  printf 'github\n' | OPENCODE_CONFIG="$PM_MIX_OC" CODEX_HOME="$PM_MIX_CX" script -qec "$INSTALL --force --target opencode,codex" /dev/null >"$TMPROOT/pm-mix-tty.out" 2>&1 || true
  [ "$(grep -c 'Backlog tracker \[' "$TMPROOT/pm-mix-tty.out")" -eq 1 ] || { cat "$TMPROOT/pm-mix-tty.out" >&2; fail "80d: a mixed-state multi-target TTY run prompts exactly once"; }
  grep -qxF '# pm linear' "$PM_MIX_OC/.harness-manifest" || fail "80d: a multi-target prompt keeps a root's recorded tracker"
  grep -qxF 'backlog_tracker: linear' "$PM_MIX_OC/PROVIDERS.md" || fail "80d: a multi-target prompt keeps the recorded root's rendered tracker"
  # The answer differs from the child default (auto), so this pins the
  # parent-to-child hand-off of the prompt answer.
  grep -qxF '# pm github' "$PM_MIX_CX/.harness-manifest" || fail "80d: a multi-target prompt answer is handed to the unrecorded root"
  grep -qxF 'backlog_tracker: github' "$PM_MIX_CX/PROVIDERS.md" || fail "80d: a multi-target prompt answer renders on the unrecorded root"
  pass "a multi-target TTY prompt only defaults unrecorded roots and keeps recorded trackers"
fi
# The parent-to-child default hand-off (HARNESS_PM_DEFAULT) never overrides a
# recorded tracker, fills an unrecorded root, and yields to an explicit --pm.
PM_HO_OC="$TMPROOT/pm-handoff-oc"
PM_HO_CX="$TMPROOT/pm-handoff-codex"
OPENCODE_CONFIG="$PM_HO_OC" "$INSTALL" --pm linear </dev/null >"$TMPROOT/pm-handoff-seed.out" 2>&1 || { cat "$TMPROOT/pm-handoff-seed.out" >&2; fail "80d: seeding a linear root exits 0"; }
HARNESS_PM_DEFAULT=github OPENCODE_CONFIG="$PM_HO_OC" CODEX_HOME="$PM_HO_CX" "$INSTALL" --force --target opencode,codex </dev/null >"$TMPROOT/pm-handoff.out" 2>&1 || { cat "$TMPROOT/pm-handoff.out" >&2; fail "80d: a mixed-state multi-target refresh exits 0"; }
grep -qxF '# pm linear' "$PM_HO_OC/.harness-manifest" || fail "80d: the default hand-off keeps a recorded tracker"
grep -qxF '# pm github' "$PM_HO_CX/.harness-manifest" || fail "80d: the default hand-off fills an unrecorded root"
grep -qxF 'backlog_tracker: github' "$PM_HO_CX/PROVIDERS.md" || fail "80d: the default hand-off renders on the unrecorded root"
HARNESS_PM_DEFAULT=github OPENCODE_CONFIG="$PM_HO_OC" CODEX_HOME="$PM_HO_CX" "$INSTALL" --force --target opencode,codex --pm none </dev/null >"$TMPROOT/pm-handoff2.out" 2>&1 || { cat "$TMPROOT/pm-handoff2.out" >&2; fail "80d: an explicit multi-target --pm exits 0"; }
grep -qxF '# pm none' "$PM_HO_OC/.harness-manifest" && grep -qxF '# pm none' "$PM_HO_CX/.harness-manifest" || fail "80d: an explicit --pm overrides every root"
pass "the multi-target default hand-off fills only unrecorded roots and yields to an explicit --pm"
pass "--pm records # pm, renders backlog_tracker:, reuses it on refresh, forwards it across targets, and rejects unknown values"

# 80e. Every shipped profile: Opus/Fable implementers with carbon/sol
# fallbacks, Fable/astra/carbon council primaries, no OpenCode in review,
# no Anthropic effort above high, and a single-provider table covering each
# provider in the profile with >= 2 distinct high-effort models.
profile_rows() {
  awk -F '|' -v section="$2" '
    /^##[[:space:]]+/ { cur = $0; sub(/^##[[:space:]]+/, "", cur); next }
    (section == "roles" ? (cur !~ /^(Quota pools|Backup ladder|Single-provider review|Project management)$/) : (cur == section)) && /^[|]/ {
      line = ""
      for (i = 2; i < NF; i++) { c = $i; gsub(/^ +| +$/, "", c); line = line (i > 2 ? "|" : "") c }
      print line
    }
  ' "$1"
}
check_council_profile() {
  local md="$1" label="$2" has_cld="$3" has_cdx="$4" has_agy="$5" has_oc="$6" bad=""
  profile_rows "$md" roles >"$TMPROOT/cp-roles.txt"
  profile_rows "$md" "Backup ladder" >"$TMPROOT/cp-backup.txt"
  profile_rows "$md" "Single-provider review" >"$TMPROOT/cp-single.txt"
  awk -F '|' '$1 ~ /^reviewer-/ && $3 == "opencode" { print "opencode reviewer rung: " $0 }
              $1 == "reviewer-esc" { print "reviewer-esc row: " $0 }
              $6 == "anthropic" && $5 != "-" && $5 !~ /=(low|medium|high)$/ { print "anthropic above high: " $0 }' "$TMPROOT/cp-roles.txt" >"$TMPROOT/cp-bad.txt"
  awk -F '|' '($2 == "*" || $2 ~ /reviewer-/) && $3 == "opencode" { print "opencode reviewer backup: " $0 }
              $2 ~ /reviewer-/ && $5 !~ /=high$/ { print "reviewer backup below high: " $0 }
              $2 == "*" { print "wildcard backup row: " $0 }
              $6 == "anthropic" && $5 != "-" && $5 !~ /=(low|medium|high)$/ { print "anthropic above high: " $0 }' "$TMPROOT/cp-backup.txt" >>"$TMPROOT/cp-bad.txt"
  awk -F '|' '$4 == "anthropic" && $3 != "-" && $3 !~ /=(low|medium|high)$/ { print "anthropic above high: " $0 }' "$TMPROOT/cp-single.txt" >>"$TMPROOT/cp-bad.txt"
  if [ "$has_oc" -eq 1 ] && [ $((has_cld + has_cdx + has_agy)) -eq 0 ]; then :; fi
  awk -F '|' 'NR == FNR { if ($1 ~ /^(scout|implementer|implementer-deep|tester|patch|task-reviewer|reviewer-a|reviewer-b|reviewer-c)$/ && $2 != "rung") provs[$3] = 1; next }
              { models[$1, $2] = 1 }
              END {
                for (p in provs) {
                  n = 0
                  for (k in models) { split(k, kk, SUBSEP); if (kk[1] == p) n++ }
                  if (n < 2) print "single-provider review lists " n " model(s) for " p
                }
              }' "$TMPROOT/cp-roles.txt" "$TMPROOT/cp-single.txt" >>"$TMPROOT/cp-bad.txt"
  if [ -s "$TMPROOT/cp-bad.txt" ]; then cat "$TMPROOT/cp-bad.txt" >&2; fail "80e: $label council/effort invariants"; fi
  [ "$(seat_cell "$md" reviewer-a 5)" != "" ] && [ "$(seat_cell "$md" reviewer-b 5)" != "" ] && [ "$(seat_cell "$md" reviewer-c 5)" != "" ] || fail "80e: $label carries all three council seats"
  [ "$(seat_cell "$md" reviewer-a 5)" != "$(seat_cell "$md" reviewer-b 5)" ] && [ "$(seat_cell "$md" reviewer-a 5)" != "$(seat_cell "$md" reviewer-c 5)" ] && [ "$(seat_cell "$md" reviewer-b 5)" != "$(seat_cell "$md" reviewer-c 5)" ] || fail "80e: $label council primaries are pairwise-distinct models"
  if [ "$has_cld" -eq 1 ]; then
    [ "$(seat_cell "$md" reviewer-a 5)" = "claude-fable-5-2" ] || fail "80e: $label captain (reviewer-a) primary is claude-fable-5-2"
    [ "$(seat_cell "$md" implementer-deep 5)" = "claude-fable-5-2" ] || fail "80e: $label implementer-deep primary is claude-fable-5-2"
  elif [ "$has_agy" -eq 1 ]; then
    [ "$(seat_cell "$md" implementer-deep 5)" = "claude-opus-5-5" ] || fail "80e: $label implementer-deep falls back to Antigravity claude-opus-5-5"
  fi
  if [ "$has_cld" -eq 1 ] || [ "$has_agy" -eq 1 ]; then
    [ "$(seat_cell "$md" implementer 5)" = "claude-opus-5-5" ] || fail "80e: $label implementer primary is claude-opus-5-5"
  fi
  if [ "$has_cdx" -eq 1 ]; then
    [ "$(seat_cell "$md" reviewer-b 5)" = "gpt-6-astra" ] || fail "80e: $label reviewer-b primary is gpt-6-astra"
  fi
  if [ "$has_agy" -eq 1 ]; then
    [ "$(seat_cell "$md" reviewer-c 5)" = "gemini-4-carbon" ] || fail "80e: $label reviewer-c primary is gemini-4-carbon"
  fi
  return 0
}
for shipped in quad tri opencode-go codex antigravity claude; do
  shipped_md="$ROOT/providers/$shipped.md"
  check_council_profile "$shipped_md" "providers/$shipped.md" 1 1 1 1
  for spec_row in \
    'implementer|fallback|antigravity|gemini-4-carbon|thinking_level=high|google|ok' \
    'implementer|last-resort|codex|gpt-6.1-sol|reasoningEffort=high|openai|ok' \
    'implementer-deep|primary|claudeAgent|claude-fable-5-2|effort=high|anthropic|ok' \
    'implementer-deep|fallback|antigravity|gemini-4-carbon|thinking_level=high|google|ok' \
    'implementer-deep|last-resort|codex|gpt-6.1-sol|reasoningEffort=high|openai|ok' \
    'reviewer-a|primary|claudeAgent|claude-fable-5-2|effort=high|anthropic|ok' \
    'reviewer-a|fallback|codex|gpt-6.1-terra|reasoningEffort=high|openai|ok' \
    'reviewer-a|last-resort|antigravity|gemini-4-argon|thinking_level=high|google|ok' \
    'reviewer-b|primary|codex|gpt-6-astra|reasoningEffort=high|openai|ok' \
    'reviewer-b|fallback|antigravity|gemini-4-argon|thinking_level=high|google|ok' \
    'reviewer-b|last-resort|claudeAgent|claude-sonnet-5-5|effort=high|anthropic|ok' \
    'reviewer-c|primary|antigravity|gemini-4-carbon|thinking_level=high|google|ok' \
    'reviewer-c|fallback|antigravity|claude-sonnet-5-5|thinking_level=high|anthropic|ok' \
    'reviewer-c|last-resort|codex|gpt-6.1-terra|reasoningEffort=high|openai|ok'; do
    profile_rows "$shipped_md" roles | grep -qxF "$spec_row" || fail "80e: providers/$shipped.md carries spec row $spec_row"
  done
  if [ "$shipped" = claude ]; then
    impl_row='implementer|primary|claudeAgent|claude-opus-5-5|effort=high|anthropic|ok'
  else
    impl_row='implementer|primary|antigravity|claude-opus-5-5|thinking_level=high|anthropic|ok'
  fi
  profile_rows "$shipped_md" roles | grep -qxF "$impl_row" || fail "80e: providers/$shipped.md implementer primary is Opus 5.5 high"
done
for alt_profile in quad claude; do
  profile_rows "$ROOT/providers/$alt_profile.md" "Backup ladder" | grep -qE '^[0-9]+\|implementer\|claudeAgent\|claude-opus-5-5\|effort=high\|anthropic\|ok$' || fail "80e: providers/$alt_profile.md carries the claudeAgent Opus implementer backup row"
done
profile_rows "$ROOT/providers/quad.md" "Quota pools" | grep -qxF 'antigravity-claude|antigravity|claude-*|5h|-|-' || fail "80e: quad antigravity-claude pool carries no reviewer-b reserve"
for own in antigravity:antigravity codex:codex claude:claudeAgent opencode-go:opencode; do
  own_profile="${own%%:*}"
  own_provider="${own#*:}"
  profile_rows "$ROOT/providers/$own_profile.md" "Backup ladder" | awk -F '|' -v p="$own_provider" '$2 ~ /(^|,)implementer(,|$)/ && $2 ~ /implementer-deep/ && $3 == p { found = 1 } END { exit found ? 0 : 1 }' || fail "80e: providers/$own_profile.md keeps $own_provider implementation rows in its backup ladder"
done
pass "shipped profiles carry Opus/Fable implementers, the captain council, no OpenCode review, the Anthropic effort cap and single-provider review tables"

# 80f. Every --providers composition follows the same shape, preferring spec
# models whenever their provider is selected.
for pv_combo in antigravity claude codex opencode antigravity,claude antigravity,codex antigravity,opencode claude,codex claude,opencode codex,opencode antigravity,claude,codex antigravity,claude,opencode antigravity,codex,opencode claude,codex,opencode antigravity,claude,codex,opencode; do
  pv_home="$TMPROOT/pv-$(printf '%s' "$pv_combo" | tr ',' '-')"
  rc=0
  HOME="$pv_home" "$INSTALL" --providers "$pv_combo" </dev/null >"$TMPROOT/pv.out" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { cat "$TMPROOT/pv.out" >&2; fail "80f: --providers $pv_combo exits 0 (got $rc)"; }
  pv_md="$pv_home/.config/opencode/PROVIDERS.md"
  case "$pv_combo" in
    antigravity|claude|codex|opencode|antigravity,codex,opencode|antigravity,claude,codex,opencode)
      # Fixed compositions reuse the shipped profile, which carries every provider.
      check_council_profile "$pv_md" "--providers $pv_combo" 1 1 1 1 ;;
    *)
      pv_cld=0; pv_cdx=0; pv_agy=0; pv_oc=0
      case ",$pv_combo," in *,claude,*) pv_cld=1 ;; esac
      case ",$pv_combo," in *,codex,*) pv_cdx=1 ;; esac
      case ",$pv_combo," in *,antigravity,*) pv_agy=1 ;; esac
      case ",$pv_combo," in *,opencode,*) pv_oc=1 ;; esac
      check_council_profile "$pv_md" "--providers $pv_combo" "$pv_cld" "$pv_cdx" "$pv_agy" "$pv_oc"
      if [ "$pv_cld" -eq 0 ] && [ "$pv_agy" -eq 0 ]; then
        [ "$(seat_cell "$pv_md" implementer 5)" = "gpt-6.1-sol" ] || fail "80f: --providers $pv_combo implementer falls back to gpt-6.1-sol"
      fi
      if [ "$pv_agy" -eq 1 ] && [ "$pv_cld" -eq 1 ]; then
        profile_rows "$pv_md" "Backup ladder" | grep -qE '^[0-9]+\|implementer\|claudeAgent\|claude-opus-5-5\|effort=high\|anthropic\|ok$' || fail "80f: --providers $pv_combo carries the same-model Opus backup row"
      fi
      if profile_rows "$pv_md" "Quota pools" | grep -qE '\|[0-9]+\|reviewer-b$'; then fail "80f: --providers $pv_combo reserves no pool for reviewer-b"; fi
      ;;
  esac
  HOME="$pv_home" "$INSTALL" --verify </dev/null >"$TMPROOT/pv-verify.out" 2>&1 || { cat "$TMPROOT/pv-verify.out" >&2; fail "80f: --verify accepts --providers $pv_combo"; }
done
pass "every --providers composition prefers spec implementer and council models, keeps review off opencode, and caps Anthropic effort"

# 80g. Council primaries must take distinct families when the review ladders allow it.
{ awk '!/^[|] reviewer-b [|] primary [|]/' "$ROOT/providers/quad.md"
  printf '| reviewer-b | primary | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |\n'
} >"$TMPROOT/same-fam.md"
rc=0
OPENCODE_CONFIG="$TMPROOT/same-fam-dest" "$INSTALL" --profile-file "$TMPROOT/same-fam.md" </dev/null >/dev/null 2>"$TMPROOT/same-fam.err" || rc=$?
[ "$rc" -eq 1 ] || fail "80g: reviewer-a and reviewer-b sharing a primary family exits 1 (got $rc)"
grep -qF 'invariant violated: reviewer-a and reviewer-b share primary family anthropic' "$TMPROOT/same-fam.err" || { cat "$TMPROOT/same-fam.err" >&2; fail "80g: shared primary family diagnostic"; }
[ ! -e "$TMPROOT/same-fam-dest" ] || fail "80g: shared primary family writes nothing"
pass "council primaries keep pairwise-distinct families when the review ladders span them"

printf 'all install tests passed (%d passed, 0 failed)\n' "$passed"

