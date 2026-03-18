#!/usr/bin/env bash
# brainstorm-apply-dedup.sh — Extract and apply dedup results to compiled board.
# Usage: bash brainstorm-apply-dedup.sh <session_dir> <round_num>
#
# Reads: $SD/board/round${N}_dedup.md
# Updates: $SD/board/round${N}_compiled.md
# Creates: $SD/board/round${N}_compiled_pre_dedup.md (backup)

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <session_dir> <round_num>" >&2
  exit 1
fi

SD="$1"
N="$2"
DEDUP_FILE="$SD/board/round${N}_dedup.md"
COMPILED="$SD/board/round${N}_compiled.md"
BACKUP="$SD/board/round${N}_compiled_pre_dedup.md"

if [ ! -f "$DEDUP_FILE" ]; then
  echo "No dedup report found for round $N — skipping"
  exit 0
fi

# Step 1: Extract dedup count
DEDUP_COUNT=$(grep -oE 'DUPLICATES_FOUND:[[:space:]]*[0-9]+' "$DEDUP_FILE" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "0")
DEDUP_COUNT=${DEDUP_COUNT:-0}
echo "Duplicates found in round $N: $DEDUP_COUNT"

if [ "$DEDUP_COUNT" -eq 0 ]; then
  echo "No duplicates — board unchanged"
  exit 0
fi

# Step 2: Backup original
cp "$COMPILED" "$BACKUP"

# Extract REMOVED_IDS once (reused in steps 4 and 5)
REMOVED_IDS=$(grep -oE 'REMOVED_IDS:[[:space:]].+' "$DEDUP_FILE" 2>/dev/null | sed 's/REMOVED_IDS:[[:space:]]*//' | tr -d '[]' || true)

# Step 3: Try to extract deduplicated board section
# Tolerant regex: ## Deduplicated Board, ## De-Duplicated Board, ## Dedup Board, etc.
# Stop at next ## heading to avoid capturing trailing content
DEDUP_BOARD=$(sed -n '/^## [Dd]e[-]*[Dd]uplic/,/^## /{/^## [Dd]e[-]*[Dd]uplic/d; /^## /d; p;}' "$DEDUP_FILE" || true)

if [ -n "$DEDUP_BOARD" ]; then
  printf '%s\n' "$DEDUP_BOARD" > "$COMPILED"
  NEW_COUNT=$(grep -cE '^\[?[[:space:]]*[0-9]+' "$COMPILED" 2>/dev/null || true)
  NEW_COUNT=${NEW_COUNT:-0}
  if [ "$NEW_COUNT" -gt 0 ]; then
    echo "Board updated: $NEW_COUNT ideas (removed $DEDUP_COUNT duplicates)"
  else
    echo "WARNING: Extracted board has 0 ideas — restoring backup"
    mv "$BACKUP" "$COMPILED"
    # Fall through to REMOVED_IDS fallback
    DEDUP_BOARD=""
  fi
fi

# Step 4: Fallback — filter by REMOVED_IDS if extraction failed
if [ -z "$DEDUP_BOARD" ]; then
  if [ -n "$REMOVED_IDS" ]; then
    echo "Fallback: filtering by REMOVED_IDS: $REMOVED_IDS"
    [ ! -f "$BACKUP" ] && cp "$COMPILED" "$BACKUP"
    set -f  # disable globbing for safety
    for id in $(echo "$REMOVED_IDS" | tr ',' ' '); do
      id=$(echo "$id" | tr -d ' ')
      [ -n "$id" ] && { grep -Fv "[$id]" "$COMPILED" > "$COMPILED.tmp" && mv "$COMPILED.tmp" "$COMPILED" || true; }
    done
    set +f
    NEW_COUNT=$(grep -cE '^\[?[[:space:]]*[0-9]+' "$COMPILED" 2>/dev/null || true)
    NEW_COUNT=${NEW_COUNT:-0}
    echo "Board updated via fallback: $NEW_COUNT ideas"
  else
    echo "ERROR: No deduplicated board section AND no REMOVED_IDS found — board unchanged"
    [ -f "$BACKUP" ] && mv "$BACKUP" "$COMPILED"
    exit 1
  fi
fi

# Step 5: Verify removed IDs are gone
if [ -n "$REMOVED_IDS" ]; then
  LEAKED=0
  set -f
  for id in $(echo "$REMOVED_IDS" | tr ',' ' '); do
    id=$(echo "$id" | tr -d ' ')
    [ -n "$id" ] && grep -Fq "[$id]" "$COMPILED" 2>/dev/null && { echo "LEAK: [$id] still present!"; LEAKED=$((LEAKED + 1)); }
  done
  set +f
  if [ "$LEAKED" -eq 0 ]; then
    echo "Verification passed: all removed IDs confirmed absent"
  else
    echo "WARNING: $LEAKED removed ID(s) still present in board"
  fi
fi
