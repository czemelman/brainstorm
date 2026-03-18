#!/usr/bin/env bash
# brainstorm-build-board.sh — Build unified board from per-round compiled boards.
# Usage: bash brainstorm-build-board.sh <session_dir>
#
# Reads: $SD/board/round*_compiled.md
# Writes: $SD/board/all_compiled.md
#
# Uses grep+awk — no per-line subprocess forks.
# Handles both clean format ([N] ...) and line-numbered format (1→[N] ...).

set -euo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <session_dir>" >&2
  exit 1
fi

SD="$1"
OUTPUT="$SD/board/all_compiled.md"

mkdir -p "$SD/board"

# Collect matching files safely (nullglob avoids pipefail abort on no matches)
shopt -s nullglob
FILES=("$SD"/board/round*_compiled.md)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No round boards found in $SD/board/" >&2
  : > "$OUTPUT"
  echo "" >> "$OUTPUT"
  echo "---" >> "$OUTPUT"
  echo "Total: 0 ideas (unified across all rounds)" >> "$OUTPUT"
  echo "Unified board: 0 ideas"
  exit 0
fi

# Extract all [N] lines from all round boards, renumber sequentially with awk.
# The grep tolerates optional line-number prefixes (e.g., "1→" or "  3→")
# and optional whitespace/numbering before the bracket.
cat "${FILES[@]}" \
  | { grep -E '\[[0-9]+\][[:space:]]*\(' || true; } \
  | awk '{
      # Strip line-number prefix (e.g., "1→" or "  3\t") and [N] prefix
      # Use match() to find the FIRST [N] at start of meaningful content
      match($0, /\[[0-9]+\][[:space:]]*/)
      rest = substr($0, RSTART + RLENGTH)
      # Print with new sequential ID
      printf "[%d] %s\n", NR, rest
    }' > "$OUTPUT"

TOTAL=$(grep -cE '\[[0-9]+\]' "$OUTPUT" 2>/dev/null || true)
TOTAL=${TOTAL:-0}

echo "" >> "$OUTPUT"
echo "---" >> "$OUTPUT"
echo "Total: $TOTAL ideas (unified across all rounds)" >> "$OUTPUT"

echo "Unified board: $TOTAL ideas"
