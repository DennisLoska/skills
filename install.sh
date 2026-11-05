#!/usr/bin/env bash
# install.sh - install agents/, skills/, and HARNESS.md into ${OPENCODE_CONFIG:-$HOME/.config/opencode}
# Collision-safe: preflights every target path and refuses to overwrite without --force.
# Prune is manifest-scoped: it only removes files this installer recorded writing,
# so personal agents and skills sharing the destination are never touched.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${OPENCODE_CONFIG:-$HOME/.config/opencode}"
MANIFEST="$DEST/.harness-manifest"
TMP_MANIFEST="$DEST/.harness-manifest.$$.tmp"
trap 'rm -f -- "$TMP_MANIFEST"' EXIT HUP INT TERM

usage() {
  cat <<'EOF'
usage: install.sh [--force] [--prune]

Installs agents/, skills/, and AGENTS.md (as HARNESS.md) into
${OPENCODE_CONFIG:-$HOME/.config/opencode}, and records every installed
path in <dest>/.harness-manifest.

options:
  --force      overwrite files that already exist in the destination
  --prune      remove files recorded in a previous .harness-manifest that
               this run no longer produces; files the installer never wrote
               are never touched
  -h, --help   show this help and exit

Without --force, any existing target file aborts the install with exit 1
before anything is copied.
EOF
}

force=0
prune=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --force) force=1 ;;
    --prune) prune=1 ;;
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

if [ ! -d "$SRC/agents" ] || [ ! -d "$SRC/skills" ] || [ ! -f "$SRC/AGENTS.md" ]; then
  printf 'install.sh: expected agents/, skills/, and AGENTS.md under %s\n' "$SRC" >&2
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

# Preflight: collect every target that already exists, before any mkdir or copy.
collisions=()
for i in "${!rels[@]}"; do
  target="$DEST/${rels[$i]}"
  if [ -e "$target" ] || [ -L "$target" ]; then
    collisions+=("$target")
  fi
done

if [ "${#collisions[@]}" -gt 0 ] && [ "$force" -eq 0 ]; then
  for c in "${collisions[@]}"; do
    printf 'collision: %s\n' "$c"
  done
  printf 'refusing to overwrite; rerun with --force\n'
  exit 1
fi

# owned <rel>: true when this run installs <rel>.
owned() {
  local want="$1"
  local r
  for r in "${rels[@]}"; do
    if [ "$r" = "$want" ]; then
      return 0
    fi
  done
  return 1
}

installed=0
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
        /*|..|../*|*/..|*/../*)
          printf 'install.sh: ignoring unsafe manifest entry: %s\n' "$rel" >&2
          continue
          ;;
      esac
      owned "$rel" && continue
      target="$DEST/$rel"
      if [ -e "$target" ] || [ -L "$target" ]; then
        rm -f -- "$target"
        pruned=$((pruned + 1))
      fi
    done <"$MANIFEST"
    printf 'pruned %d stale file(s)\n' "$pruned"
  fi
fi

: >"$TMP_MANIFEST"
for rel in "${rels[@]}"; do
  printf '%s\n' "$rel" >>"$TMP_MANIFEST"
done
mv -f -- "$TMP_MANIFEST" "$MANIFEST"

printf 'installed %d files into %s (harness instructions at %s)\n' "$installed" "$DEST" "$DEST/HARNESS.md"
