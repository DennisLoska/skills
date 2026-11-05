#!/usr/bin/env bash
# install.sh - install agents/, skills/, and HARNESS.md into ${OPENCODE_CONFIG:-$HOME/.config/opencode}
# Collision-safe: preflights every target path and refuses to overwrite without --force.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${OPENCODE_CONFIG:-$HOME/.config/opencode}"

usage() {
  cat <<'EOF'
usage: install.sh [--force] [--prune]

Installs agents/, skills/, and AGENTS.md (as HARNESS.md) into
${OPENCODE_CONFIG:-$HOME/.config/opencode}.

options:
  --force      overwrite files that already exist in the destination
  --prune      after copying, remove files under <dest>/agents and
               <dest>/skills that no longer exist in this repository
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

if [ ! -d "$SRC/agents" ] || [ ! -d "$SRC/skills" ]; then
  printf 'install.sh: expected agents/ and skills/ under %s\n' "$SRC" >&2
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

installed=0
for i in "${!rels[@]}"; do
  target="$DEST/${rels[$i]}"
  mkdir -p "$(dirname "$target")"
  cp -p "${srcs[$i]}" "$target"
  installed=$((installed + 1))
done

if [ "$prune" -eq 1 ]; then
  pruned=0
  for sub in agents skills; do
    subdir="$DEST/$sub"
    [ -d "$subdir" ] || continue
    while IFS= read -r -d '' target; do
      rel="${target#"$DEST"/}"
      case "$rel" in
        agents/*|skills/*) ;;
        *) continue ;;
      esac
      if [ ! -f "$SRC/$rel" ]; then
        rm -- "$target"
        pruned=$((pruned + 1))
      fi
    done < <(find "$subdir" -type f -print0)
  done
  printf 'pruned %d stale file(s)\n' "$pruned"
fi

printf 'installed %d files into %s (harness instructions at %s)\n' "$installed" "$DEST" "$DEST/HARNESS.md"
