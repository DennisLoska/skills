#!/usr/bin/env bash
# install.sh - install agents/, skills/, and HARNESS.md into ~/.config/opencode/
set -euo pipefail

DEST="${OPENCODE_CONFIG:-$HOME/.config/opencode}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$DEST"

files=()
while IFS= read -r -d '' f; do
  files+=("$f")
done < <(cd "$SRC" && find agents skills -type f -print0)

installed=0
for f in "${files[@]}"; do
  mkdir -p "$DEST/$(dirname "$f")"
  cp "$SRC/$f" "$DEST/$f"
  installed=$((installed + 1))
done

cp "$SRC/AGENTS.md" "$DEST/HARNESS.md"
installed=$((installed + 1))

echo "installed $installed files into $DEST (harness instructions at $DEST/HARNESS.md)"
