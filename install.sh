#!/usr/bin/env bash
# install.sh - install agents/, skills/, and HARNESS.md into ${OPENCODE_CONFIG:-$HOME/.config/opencode}
# Collision-safe: preflights every target path and refuses to overwrite without --force.
# Prune is manifest-scoped: it only removes files this installer recorded writing,
# so personal agents and skills sharing the destination are never touched.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

available_profiles() {
  local file name
  for file in "$SRC"/providers/*.md; do
    [ -f "$file" ] || continue
    name="${file##*/}"
    name="${name%.md}"
    case "$name" in
      ''|[!a-z0-9]*|*[!a-z0-9-]*) continue ;;
    esac
    printf '%s\n' "$name"
  done | LC_ALL=C sort | paste -sd ' ' -
}

usage() {
  cat <<'EOF'
usage: install.sh [--force] [--prune] [--profile NAME | --profile-file PATH]

Installs agents/, skills/, AGENTS.md (as HARNESS.md), PROVIDERS.md, NOTICE, and LICENSE into
${OPENCODE_CONFIG:-$HOME/.config/opencode}, and records every installed
path in <dest>/.harness-manifest.

options:
  --profile NAME       bind providers/NAME.md (also --profile=NAME; default: previous binding, else tri)
  --profile-file PATH  bind an external profile file (also --profile-file=PATH; mutually exclusive with --profile)
  --force              overwrite files that already exist in the destination
  --prune              remove files recorded in a previous .harness-manifest that
                       this run no longer produces; files the installer never wrote
                       are never touched
  -h, --help           show this help and exit

Without --force, any existing target file aborts the install with exit 1
before anything is copied.
EOF
  printf '\navailable profiles: %s\n' "$(available_profiles)"
}

force=0
prune=0
profile=tri
profile_given=0
profile_file_arg=""
profile_file_given=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --force) force=1 ;;
    --prune) prune=1 ;;
    --profile)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then usage >&2; exit 2; fi
      profile_given=1
      profile="$2"
      shift
      ;;
    --profile=*)
      profile="${1#--profile=}"
      [ -n "$profile" ] || { usage >&2; exit 2; }
      profile_given=1
      ;;
    --profile-file)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then usage >&2; exit 2; fi
      profile_file_given=1
      profile_file_arg="$2"
      shift
      ;;
    --profile-file=*)
      profile_file_arg="${1#--profile-file=}"
      [ -n "$profile_file_arg" ] || { usage >&2; exit 2; }
      profile_file_given=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$profile_given" -eq 1 ] && [ "$profile_file_given" -eq 1 ]; then
  usage >&2
  exit 2
fi

# Destination validation. Runs before any path is created or removed, and
# before the trailing slash is stripped, so a hostile or degenerate
# OPENCODE_CONFIG never reaches the install or prune loops: a value made only
# of whitespace and slashes names no directory at all, "/" and "//" are the
# filesystem root, "." under --force can unlink files out of the source tree,
# a destination inside the source checkout can overwrite it, and a whitespace
# value silently installs into a relative directory. Only an unset variable
# falls back to the default, so an explicitly empty value is caught instead of
# being replaced.
DEST_RAW="${OPENCODE_CONFIG-$HOME/.config/opencode}"

# Degenerate values: strip whitespace and slashes; nothing left means there is
# no directory component to install into (empty, " ", "/", "//", "/ /").
DEST_COMPACT="${DEST_RAW//[[:space:]]/}"
DEST_COMPACT="${DEST_COMPACT//\//}"
if [ -z "$DEST_COMPACT" ]; then
  printf 'install.sh: refusing unsafe destination: %s\n' "$DEST_RAW" >&2
  exit 1
fi

# One refusal message per unsafe case; the reason is named on the same line.
refuse_dest() {
  printf 'install.sh: refusing unsafe destination: %s (%s)\n' "$DEST_RAW" "$1" >&2
  exit 1
}

DEST_STRIPPED="$DEST_RAW"
while [ "${DEST_STRIPPED%/}" != "$DEST_STRIPPED" ]; do
  DEST_STRIPPED="${DEST_STRIPPED%/}"
done
[ -n "$DEST_STRIPPED" ] || DEST_STRIPPED="/"

# A bare self reference or any parent-traversal component is refused before
# resolution, so relative paths such as nonexistent/../evil cannot slip past
# canonical_dest when the leading component does not exist yet.
case "$DEST_STRIPPED" in
  .|..|../*|*/..|*/../*) refuse_dest "a relative self or parent reference" ;;
esac

SRC_PHYS="$(cd "$SRC" && pwd -P)"
HOME_PHYS="${HOME:-}"
if [ -n "$HOME_PHYS" ] && [ -d "$HOME_PHYS" ]; then
  HOME_PHYS="$(cd "$HOME_PHYS" && pwd -P)"
fi

# A dangling destination symlink cannot hold anything: mkdir -p follows it and
# creates the link target, so refuse before any directory is made.
if [ -L "$DEST_STRIPPED" ] && [ ! -e "$DEST_STRIPPED" ]; then
  printf 'install.sh: destination symlink is dangling: %s\n' "$DEST_RAW" >&2
  exit 1
fi

if [ -e "$DEST_STRIPPED" ] && [ ! -d "$DEST_STRIPPED" ]; then
  printf 'install.sh: destination is not a directory: %s\n' "$DEST_RAW" >&2
  exit 1
fi

# canonical_dest <path>: physical form of the path. An existing directory is
# resolved with pwd -P so every symlink is followed; a path that does not exist
# yet is resolved through its deepest existing ancestor with the remaining
# components appended, so "$PWD/agents" and a relative "../skills" compare
# against $SRC_PHYS before they exist. Interior "." segments are stripped while
# walking up; a ".." component is returned as-is and handled by the literal
# checks above.
canonical_dest() {
  local p="$1"
  local suffix=""
  local base
  local out
  while [ ! -d "$p" ]; do
    base="$(basename -- "$p")"
    case "$base" in
      .) p="$(dirname -- "$p")"; continue ;;
      ''|..|/) printf '%s%s' "$p" "$suffix"; return 0 ;;
    esac
    suffix="/$base$suffix"
    p="$(dirname -- "$p")"
  done
  out="$(cd "$p" && pwd -P)$suffix"
  case "$out" in
    //*) out="/${out#//}" ;;
  esac
  printf '%s' "$out"
}

DEST_CANON="$(canonical_dest "$DEST_STRIPPED")"
if [ -z "$DEST_CANON" ]; then
  refuse_dest "an unresolvable path"
fi

# The filesystem root, reached directly ("/", already refused above) or
# through an alias such as "/." or "/./".
if [ "$DEST_CANON" = "/" ]; then
  refuse_dest "the filesystem root"
fi

# The source checkout itself, or anything nested inside it: --force would
# rewrite the harness sources in place.
if [ "$DEST_CANON" = "$SRC_PHYS" ] || [ "$DEST_CANON" = "$SRC" ] ||
   [ "$DEST_STRIPPED" = "$SRC" ] || [ "$DEST_STRIPPED" = "$SRC_PHYS" ]; then
  refuse_dest "the source checkout"
fi
case "$DEST_CANON" in
  "$SRC_PHYS"/*|"$SRC"/*) refuse_dest "inside the source checkout" ;;
esac

# HOME itself would scatter HARNESS.md and agents over the home directory.
if [ "$DEST_CANON" = "$HOME_PHYS" ] ||
   { [ -n "${HOME:-}" ] && { [ "$DEST_RAW" = "$HOME" ] || [ "$DEST_STRIPPED" = "$HOME" ]; }; }; then
  refuse_dest "the HOME directory"
fi

DEST="$DEST_CANON"
MANIFEST="$DEST/.harness-manifest"
if [ -L "$MANIFEST" ] || { [ -e "$MANIFEST" ] && [ ! -f "$MANIFEST" ]; }; then
  printf 'install.sh: manifest path is not a regular file: %s\n' "$MANIFEST" >&2
  exit 1
fi
prev_profile=""
prev_profile_present=0
prev_profile_file=""
prev_profile_file_present=0
prev_entry_present=0
prev_profile_legacy=0
if [ -f "$MANIFEST" ]; then
  while IFS= read -r mline || [ -n "$mline" ]; do
    case "$mline" in
      '# profile '*) prev_profile="${mline#'# profile '}"; prev_profile_present=1; break ;;
      '# profile-file '*) prev_profile_file="${mline#'# profile-file '}"; prev_profile_file_present=1; break ;;
      *)
        entry="${mline#"${mline%%[![:space:]]*}"}"
        case "$entry" in ''|\#*) ;; *) prev_entry_present=1 ;; esac
        ;;
    esac
  done <"$MANIFEST"
fi
if [ "$prev_profile_present" -eq 0 ] && [ "$prev_profile_file_present" -eq 0 ] &&
   { [ "$prev_entry_present" -eq 1 ] || { [ ! -f "$MANIFEST" ] && [ -f "$DEST/HARNESS.md" ]; }; }; then
  prev_profile=opencode-go
  prev_profile_present=1
  prev_profile_legacy=1
fi
use_profile_file=0
if [ "$profile_file_given" -eq 1 ]; then
  use_profile_file=1
elif [ "$profile_given" -eq 0 ]; then
  if [ "$prev_profile_file_present" -eq 1 ]; then
    use_profile_file=1
    profile_file_arg="$prev_profile_file"
  elif [ "$prev_profile_present" -eq 1 ]; then
    profile="$prev_profile"
  fi
fi

# Validate the binding before creating anything, including temporary files.
unknown_profile() {
  printf 'install.sh: unknown profile: %s (available: %s)\n' "$profile" "$(available_profiles)" >&2
  exit 2
}
if [ "$use_profile_file" -eq 1 ]; then
  if [ ! -f "$profile_file_arg" ]; then
    printf 'install.sh: profile file not found: %s\n' "$profile_file_arg" >&2
    exit 2
  fi
  PROFILE_FILE="$(cd "$(dirname -- "$profile_file_arg")" && pwd -P)/$(basename -- "$profile_file_arg")"
  PROFILE_LABEL="$PROFILE_FILE"
else
  case "$profile" in
    ''|[!a-z0-9]*|*[!a-z0-9-]*) unknown_profile ;;
  esac
  PROFILE_FILE="$SRC/providers/$profile.md"
  [ -f "$PROFILE_FILE" ] || unknown_profile
  PROFILE_LABEL="$profile"
fi
REQUIRED_ROLES='scout implementer implementer-deep patch tester reviewer-a reviewer-b reviewer-c reviewer-esc task-reviewer'
# Recognized required and advisory rows are validated; fenced examples are prose.
PROFILE_ROWS="$(PROFILE_NAME="$PROFILE_LABEL" REQUIRED_ROLES="$REQUIRED_ROLES" awk -F '|' '
  BEGIN {
    profile = ENVIRON["PROFILE_NAME"]
    n = split(ENVIRON["REQUIRED_ROLES"], ordered, " ")
    for (i = 1; i <= n; i++) known[ordered[i]] = 1
    known["driver"] = known["compaction"] = 1
  }
  function invalid(reason) {
    printf "install.sh: profile %s invalid row: %s %s: %s\n", profile, $2, $3, reason > "/dev/stderr"
    failed = 1
    exit 1
  }
  /^[[:space:]]*```/ { fenced = !fenced; next }
  fenced { next }
  /^[[:space:]]*[|]/ {
    for (i = 1; i <= NF; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
    role = $2
    if (!(role in known)) next
    if (NF != 9 || $NF != "") invalid("expected 7 cells")
    for (i = 2; i <= 8; i++) if ($i == "") invalid("empty cell")
    if ($3 != "primary" && $3 != "fallback" && $3 != "last-resort") invalid("invalid rung")
    if ($8 != "ok" && $8 != "trains") invalid("invalid privacy")
    advisory = (role == "driver" || role == "compaction")
    if (!(advisory && $4 == "-") && $4 !~ /^[A-Za-z0-9][A-Za-z0-9-]*$/) invalid("invalid provider")
    if (!(advisory && $5 == "-") && $5 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) invalid("invalid model")
    if ($6 !~ /^(-|[A-Za-z_]+=[A-Za-z0-9][A-Za-z0-9._-]*)$/) invalid("invalid effort")
    if (!(advisory && $7 == "-") && $7 !~ /^[a-z0-9][a-z0-9-]*$/) invalid("invalid family")
    key = role SUBSEP $3
    if (key in seen) invalid("duplicate rung")
    seen[key] = 1
    if ($3 == "primary") primary[role] = 1
    print $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" $7 "|" $8
  }
  END {
    if (failed) exit 1
    for (i = 1; i <= n; i++) {
      role = ordered[i]
      if (!(role in primary)) {
        printf "install.sh: profile %s incomplete: %s\n", profile, role > "/dev/stderr"
        exit 1
      }
    }
  }
' "$PROFILE_FILE")" || exit 1

# Select by ladder order, even if the table rows were written out of order.
native_pin() {
  awk -F '|' -v seat="$1" '
    BEGIN { rank["primary"] = 1; rank["fallback"] = 2; rank["last-resort"] = 3 }
    $1 == seat && $3 == "opencode" {
      if (!best || rank[$2] < best) {
        best = rank[$2]
        pin = $4
        if ($5 ~ /^variant=/) pin = pin "#" substr($5, 9)
      }
    }
    END { if (best) print pin }
  ' <<<"$PROFILE_ROWS"
}

TMP_MANIFEST="$DEST/.harness-manifest.$$.tmp"
rendered_agents=()
cleanup() {
  rm -f -- "$TMP_MANIFEST"
  if [ "${#rendered_agents[@]}" -gt 0 ]; then
    rm -f -- "${rendered_agents[@]}"
  fi
}
trap cleanup EXIT

if [ ! -d "$SRC/agents" ] || [ ! -d "$SRC/skills" ] || [ ! -f "$SRC/AGENTS.md" ] ||
   [ ! -f "$SRC/NOTICE" ] || [ ! -f "$SRC/LICENSE" ]; then
  printf 'install.sh: expected agents/, skills/, AGENTS.md, NOTICE, and LICENSE under %s\n' "$SRC" >&2
  exit 1
fi

srcs=()
rels=()
while IFS= read -r -d '' f; do
  srcs+=("$f")
  rels+=("${f#"$SRC"/}")
done < <(find "$SRC/agents" "$SRC/skills" -type f -print0)
srcs+=("$SRC/AGENTS.md")
rels+=("HARNESS.md")
srcs+=("$SRC/NOTICE")
rels+=("NOTICE")
srcs+=("$SRC/LICENSE")
rels+=("LICENSE")
srcs+=("$PROFILE_FILE")
rels+=("PROVIDERS.md")

# Render every agent before any destination mutation, including --force repairs.
for i in "${!rels[@]}"; do
  case "${rels[$i]}" in
    agents/*.md)
      seat="${rels[$i]#agents/}"
      seat="${seat%.md}"
      pin="$(native_pin "$seat")"
      if [ -z "$pin" ]; then
        printf 'note: %s has no opencode rung; dispatch it through delegate_task only\n' "$seat"
      fi
      rendered="$(mktemp "${TMPDIR:-/tmp}/harness-agent.XXXXXXXX")"
      rendered_agents+=("$rendered")
      cp -p "${srcs[$i]}" "$rendered"
      if ! NATIVE_PIN="$pin" awk '
        BEGIN { pin = ENVIRON["NATIVE_PIN"] }
        NR == 1 { frontmatter = ($0 == "---") }
        NR > 1 && frontmatter && $0 == "---" { frontmatter = 0 }
        { print }
        frontmatter && !inserted && /^mode: subagent$/ && pin != "" {
          print "model: " pin
          inserted = 1
        }
        END { if (pin != "" && !inserted) exit 1 }
      ' "${srcs[$i]}" >"$rendered"; then
        printf 'install.sh: cannot insert native pin: %s\n' "$seat" >&2
        exit 1
      fi
      srcs[$i]="$rendered"
      ;;
  esac
done

# Preflight: collect every target that already exists, before any mkdir or copy.
collisions=()
for i in "${!rels[@]}"; do
  target="$DEST/${rels[$i]}"
  if [ -e "$target" ] || [ -L "$target" ]; then
    collisions+=("$target")
  fi
done

# Preflight: walk every parent component of each target between $DEST and the
# file. mkdir -p follows a symlinked parent under $DEST, so a copy could land
# outside $DEST. Refuse (or repair under --force) before anything is copied.
# A parent component that exists as a regular file (not a directory, not a
# symlink) can never contain a target; refuse before anything is copied.
parent_links=()
parent_blocks=()
for i in "${!rels[@]}"; do
  target="$DEST/${rels[$i]}"
  parent="$(dirname "$target")"
  walk=0
  while [ "$parent" != "$DEST" ]; do
    walk=$((walk + 1))
    if [ "$walk" -gt 64 ]; then
      printf 'install.sh: parent walk did not converge: %s\n' "$parent" >&2
      exit 1
    fi
    case "$parent" in
      "$DEST"/*) ;;
      *) break ;;
    esac
    if [ -L "$parent" ]; then
      dup=0
      if [ "${#parent_links[@]}" -gt 0 ]; then
        for p in "${parent_links[@]}"; do
          if [ "$p" = "$parent" ]; then
            dup=1
            break
          fi
        done
      fi
      if [ "$dup" -eq 0 ]; then
        parent_links+=("$parent")
      fi
    elif [ -e "$parent" ] && [ ! -d "$parent" ]; then
      dup=0
      if [ "${#parent_blocks[@]}" -gt 0 ]; then
        for p in "${parent_blocks[@]}"; do
          if [ "$p" = "$parent" ]; then
            dup=1
            break
          fi
        done
      fi
      if [ "$dup" -eq 0 ]; then
        parent_blocks+=("$parent")
      fi
    fi
    parent="$(dirname "$parent")"
  done
done

if [ "${#parent_blocks[@]}" -gt 0 ]; then
  for pb in "${parent_blocks[@]}"; do
    printf 'install.sh: parent path is not a directory: %s\n' "$pb" >&2
  done
  exit 1
fi

if [ "${#parent_links[@]}" -gt 0 ] && [ "$force" -eq 0 ]; then
  for pl in "${parent_links[@]}"; do
    printf 'install.sh: parent symlink under destination: %s\n' "$pl" >&2
  done
  exit 1
fi

if [ "${#collisions[@]}" -gt 0 ] && [ "$force" -eq 0 ]; then
  for c in "${collisions[@]}"; do
    printf 'collision: %s\n' "$c"
  done
  printf 'refusing to overwrite; rerun with --force\n'
  exit 1
fi

# Preflight: a target blocked by a directory can never be replaced by a file.
# Without --force this already aborts as a collision above; with --force
# refuse before anything is copied, leaving the manifest intact.
dir_targets=()
for i in "${!rels[@]}"; do
  target="$DEST/${rels[$i]}"
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    dir_targets+=("$target")
  fi
done
if [ "${#dir_targets[@]}" -gt 0 ] && [ "$force" -eq 1 ]; then
  for dt in "${dir_targets[@]}"; do
    printf 'install.sh: directory at target cannot be replaced: %s\n' "$dt" >&2
  done
  exit 1
fi

# normalize_rel <entry>: canonical relative form used for both the ownership
# comparison and the unsafe-entry check. Strips a leading "./", collapses
# repeated slashes, and strips trailing slashes so that a manifest entry such
# as "./skills/oneshot/SKILL.md" is recognised as the file this run writes.
normalize_rel() {
  local r="$1"
  while case "$r" in ./*) true ;; *) false ;; esac; do
    r="${r#./}"
  done
  while case "$r" in *//*) true ;; *) false ;; esac; do
    r="${r//\/\//\/}"
  done
  while case "$r" in */) true ;; *) false ;; esac; do
    r="${r%/}"
  done
  printf '%s' "$r"
}

# owned <rel>: true when this run installs <rel>. Comparison uses normalized
# relative paths (./ and // stripped) and exact case matching so case-variant
# stale files are still pruned on case-sensitive filesystems.
norm_rels=()
for r in "${rels[@]}"; do
  norm_rels+=("$(normalize_rel "$r")")
done
owned() {
  local want r
  want="$(normalize_rel "$1")"
  for r in "${norm_rels[@]}"; do
    if [ "$r" = "$want" ]; then
      return 0
    fi
  done
  return 1
}

installed=0
if [ "${#parent_links[@]}" -gt 0 ]; then
  # Repair shallowest-first: discovery order can list a nested parent before
  # its outer parent, and repairing the inner path first would act through
  # the outer symlink onto the outside tree. Sorting by depth ascending
  # repairs each outer parent first; the inner check then re-tests the
  # repaired tree and skips paths that no longer resolve to a symlink.
  sorted_parents="$(printf '%s\n' "${parent_links[@]}" | awk -F/ '{ print NF " " $0 }' | sort -n | cut -d' ' -f2-)"
  while IFS= read -r pl || [ -n "$pl" ]; do
    [ -n "$pl" ] || continue
    if [ -L "$pl" ]; then
      rm -f -- "$pl"
      mkdir -p "$pl"
    fi
  done <<<"$sorted_parents"
fi
for i in "${!rels[@]}"; do
  target="$DEST/${rels[$i]}"
  mkdir -p "$(dirname "$target")"
  # cp -p follows a destination symlink and would write outside DEST; unlink first.
  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -f -- "$target"
  fi
  cp -p "${srcs[$i]}" "$target"
  installed=$((installed + 1))
done

if [ "$prune" -eq 1 ]; then
  if [ ! -f "$MANIFEST" ]; then
    printf 'no previous manifest; prune skipped\n'
  else
    pruned=0
    while IFS= read -r rel || [ -n "$rel" ]; do
      [ -n "$rel" ] || continue
      case "$rel" in
        '#'*) continue ;;
      esac
      rel="$(normalize_rel "$rel")"
      [ -n "$rel" ] || continue
      case "$rel" in
        /*|..|../*|*/..|*/../*)
          printf 'install.sh: ignoring unsafe manifest entry: %s\n' "$rel" >&2
          continue
          ;;
      esac
      owned "$rel" && continue
      target="$DEST/$rel"
      # Prune confinement: refuse to unlink through a symlinked parent, which
      # would delete a file outside $DEST. Skip the entry instead.
      prune_parent="$(dirname "$target")"
      prune_unsafe=""
      while [ "$prune_parent" != "$DEST" ]; do
        case "$prune_parent" in
          "$DEST"/*) ;;
          *) prune_unsafe="$prune_parent"; break ;;
        esac
        if [ -L "$prune_parent" ]; then
          prune_unsafe="$prune_parent"
          break
        fi
        prune_parent="$(dirname "$prune_parent")"
      done
      if [ -n "$prune_unsafe" ]; then
        printf 'install.sh: refusing to prune through symlink: %s\n' "$target" >&2
        continue
      fi
      if [ -e "$target" ] || [ -L "$target" ]; then
        if [ ! -f "$target" ] && [ ! -L "$target" ]; then
          printf 'install.sh: skipping non-file prune target: %s\n' "$target" >&2
          continue
        fi
        rm -f -- "$target"
        pruned=$((pruned + 1))
      fi
    done <"$MANIFEST"
    printf 'pruned %d stale file(s)\n' "$pruned"
  fi
fi

if harness_sha="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"; then
  :
else
  harness_sha="unknown"
fi
prev_sha=""
prev_manifest_present=0
if [ -f "$MANIFEST" ]; then
  prev_manifest_present=1
  while IFS= read -r mline || [ -n "$mline" ]; do
    case "$mline" in
      '# harness '*) prev_sha="${mline#'# harness '}"; break ;;
    esac
  done <"$MANIFEST"
  if [ -z "$prev_sha" ]; then
    prev_sha="unknown"
  fi
fi

: >"$TMP_MANIFEST"
printf '# harness %s\n' "$harness_sha" >>"$TMP_MANIFEST"
if [ "$use_profile_file" -eq 1 ]; then
  printf '# profile-file %s\n' "$PROFILE_FILE" >>"$TMP_MANIFEST"
else
  printf '# profile %s\n' "$profile" >>"$TMP_MANIFEST"
fi
for rel in "${rels[@]}"; do
  printf '%s\n' "$rel" >>"$TMP_MANIFEST"
done
mv -f -- "$TMP_MANIFEST" "$MANIFEST"

if [ "$prev_manifest_present" -eq 1 ] && [ "$prev_sha" != "$harness_sha" ]; then
  printf 'harness updated: %s -> %s\n' "$prev_sha" "$harness_sha"
fi

if [ "$profile_given" -eq 0 ] && [ "$profile_file_given" -eq 0 ] && [ "$prev_profile_legacy" -eq 1 ]; then
  printf 'profile: opencode-go (previous install predates profiles)\n'
fi

prev_binding="${prev_profile:-$prev_profile_file}"
if [ "$use_profile_file" -eq 1 ]; then
  cur_binding="$PROFILE_FILE"
else
  cur_binding="$profile"
fi
if { [ "$profile_given" -eq 1 ] || [ "$profile_file_given" -eq 1 ]; } &&
   [ -n "$prev_binding" ] && [ "$prev_binding" != "$cur_binding" ]; then
  printf 'profile changed: %s -> %s\n' "$prev_binding" "$cur_binding"
fi

printf 'installed %d files into %s (harness instructions at %s)\n' "$installed" "$DEST" "$DEST/HARNESS.md"
