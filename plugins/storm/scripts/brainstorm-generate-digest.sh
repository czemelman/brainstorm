#!/usr/bin/env bash
# brainstorm-generate-digest.sh — Generate a visual HTML digest of a brainstorm session.
# Usage: bash brainstorm-generate-digest.sh <session_dir>
# Output: $SD/output/digest.html

set -uo pipefail
# Note: -e (errexit) deliberately omitted. The digest generation uses many
# grep/sed pipelines that legitimately return non-zero on no-match. Rather
# than wrapping every grep in { ... || true; }, we accept non-zero exits
# and rely on the final "Digest generated" echo + file existence as the
# success indicator.

SD="$1"
SF="$SD/session.json"
OUT="$SD/output/digest.html"

# ── Helpers ──────────────────────────────────────────────────────────────────
html_escape() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }

# ── Arg validation ───────────────────────────────────────────────────────────
if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <session_dir>" >&2
  exit 1
fi
[ -d "$SD" ] || { echo "ERROR: $SD is not a directory" >&2; exit 1; }

# ── Extract Session Metadata ────────────────────────────────────────────────
SESSION_ID=$(jq -r '.session_id' "$SF" | html_escape)
TOPIC=$(jq -r '.topic' "$SF" | html_escape)
CREATED=$(jq -r '.created_at' "$SF" | html_escape)
COMPLEXITY=$(jq -r '.complexity' "$SF" | html_escape)
MODE=$(jq -r '.mode' "$SF" | html_escape)
PHASE=$(jq -r '.phase' "$SF")
TOTAL_ROUNDS=$(jq -r '.config.total_rounds // 0' "$SF")
[[ "$TOTAL_ROUNDS" =~ ^[0-9]+$ ]] || TOTAL_ROUNDS=0
NUM_AGENTS=$(jq '.agents | length' "$SF")
COLORS=("#6366f1" "#ec4899" "#f59e0b" "#10b981" "#3b82f6" "#8b5cf6" "#ef4444" "#14b8a6" "#f97316" "#84cc16")

# ── Per-Round Stats ──────────────────────────────────────────────────────────
declare -a ROUND_RAW_COUNTS=()
declare -a ROUND_DEDUP_COUNTS=()
declare -a ROUND_REMOVED=()
TOTAL_RAW=0
TOTAL_DEDUP_REMOVED=0

for ((r=1; r<=TOTAL_ROUNDS; r++)); do
  PRE="$SD/board/round${r}_compiled_pre_dedup.md"
  POST="$SD/board/round${r}_compiled.md"
  if [ -f "$PRE" ]; then
    RAW=$(grep -cE '^\[[A-Za-z0-9_-]+\]' "$PRE" 2>/dev/null || true)
  elif [ -f "$POST" ]; then
    RAW=$(grep -cE '^\[[A-Za-z0-9_-]+\]' "$POST" 2>/dev/null || true)
  else
    RAW=0
  fi
  ROUND_RAW_COUNTS+=("$RAW")
  TOTAL_RAW=$((TOTAL_RAW + RAW))

  DEDUP_FILE="$SD/board/round${r}_dedup.md"
  if [ -f "$DEDUP_FILE" ]; then
    REMOVED=$(grep -oE 'DUPLICATES_FOUND:[[:space:]]*[0-9]+' "$DEDUP_FILE" 2>/dev/null | grep -oE '[0-9]+' || true)
    REMOVED=${REMOVED:-0}
  else
    REMOVED=0
  fi
  ROUND_REMOVED+=("$REMOVED")
  TOTAL_DEDUP_REMOVED=$((TOTAL_DEDUP_REMOVED + REMOVED))

  if [ -f "$POST" ]; then
    AFTER=$(grep -cE '^\[[A-Za-z0-9_-]+\]' "$POST" 2>/dev/null || true)
  else
    AFTER=$((RAW - REMOVED))
  fi
  ROUND_DEDUP_COUNTS+=("$AFTER")
done

ALL_COMPILED="$SD/board/all_compiled.md"
TOTAL_FINAL=0
[ -f "$ALL_COMPILED" ] && TOTAL_FINAL=$(grep -cE '^\[[A-Za-z0-9_-]+\]' "$ALL_COMPILED" 2>/dev/null || true)

# ── Complexity Badge Color ───────────────────────────────────────────────────
case "$COMPLEXITY" in
  light) COMPLEXITY_COLOR="#10b981" ;;
  standard) COMPLEXITY_COLOR="#f59e0b" ;;
  deep) COMPLEXITY_COLOR="#ef4444" ;;
  *) COMPLEXITY_COLOR="#6b7280" ;;
esac

# ═══════════════════════════════════════════════════════════════════════════
# HTML OUTPUT
# ═══════════════════════════════════════════════════════════════════════════

cat > "$OUT" << 'CSSEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Brainstorm Digest</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; background: #0f172a; color: #e2e8f0; line-height: 1.6; padding: 2rem; max-width: 1100px; margin: 0 auto; }
  h1 { font-size: 1.8rem; font-weight: 700; margin-bottom: 0.25rem; }
  h2 { font-size: 1.1rem; font-weight: 600; color: #94a3b8; margin-bottom: 1rem; text-transform: uppercase; letter-spacing: 0.05em; }
  .topic { font-size: 1rem; color: #94a3b8; margin-bottom: 1rem; }
  .meta-row { display: flex; gap: 0.75rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
  .meta-badge { padding: 0.25rem 0.75rem; border-radius: 9999px; font-size: 0.8rem; font-weight: 600; }
  .section { background: #1e293b; border-radius: 12px; padding: 1.5rem; margin-bottom: 1.5rem; }
  .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; }
  .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1rem; }
  .grid-4 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; }
  @media (max-width: 768px) { .grid-2, .grid-3, .grid-4 { grid-template-columns: 1fr; } }

  .stat-card { background: #1e293b; border-radius: 12px; padding: 1.25rem; text-align: center; }
  .stat-num { font-size: 2.5rem; font-weight: 800; line-height: 1; }
  .stat-label { font-size: 0.75rem; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; margin-top: 0.25rem; }

  .pipeline { display: flex; align-items: center; gap: 0; margin-bottom: 1.5rem; flex-wrap: wrap; }
  .pipe-step { padding: 0.5rem 1rem; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; }
  .pipe-step.done { background: #166534; color: #bbf7d0; }
  .pipe-step.active { background: #854d0e; color: #fef08a; }
  .pipe-step.pending { background: #334155; color: #64748b; }
  .pipe-step:first-child { border-radius: 8px 0 0 8px; }
  .pipe-step:last-child { border-radius: 0 8px 8px 0; }

  .agent-card { background: #0f172a; border-radius: 8px; padding: 0.75rem 1rem; margin-bottom: 0.5rem; }
  .agent-name { font-weight: 600; font-size: 0.9rem; }
  .agent-meta { font-size: 0.75rem; color: #64748b; }

  .round-bar { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.5rem; }
  .round-label { font-weight: 700; font-size: 0.85rem; color: #94a3b8; min-width: 2rem; }
  .bar-track { flex: 1; height: 24px; background: #334155; border-radius: 6px; overflow: hidden; }
  .bar-fill { height: 100%; background: linear-gradient(90deg, #6366f1, #8b5cf6); border-radius: 6px; }
  .round-stats { font-size: 0.8rem; color: #94a3b8; min-width: 140px; text-align: right; }
  .dedup-badge { background: #7f1d1d; color: #fca5a5; padding: 0.1rem 0.4rem; border-radius: 4px; font-size: 0.7rem; }

  .cluster-chip { display: inline-block; background: #312e81; color: #c7d2fe; padding: 0.3rem 0.75rem; border-radius: 6px; font-size: 0.8rem; margin: 0.25rem; }

  .idea-row { display: flex; align-items: baseline; gap: 0.75rem; padding: 0.5rem 0; border-bottom: 1px solid #334155; }
  .idea-row:last-child { border-bottom: none; }
  .rank { font-weight: 800; font-size: 1.1rem; color: #fbbf24; min-width: 2.5rem; }
  .idea-text { font-size: 0.9rem; }

  .moonshot-chip { display: inline-block; background: #713f12; color: #fef08a; padding: 0.3rem 0.75rem; border-radius: 6px; font-size: 0.8rem; margin: 0.25rem; }

  .redteam-item { padding: 0.5rem 0; border-bottom: 1px solid #334155; font-size: 0.85rem; }
  .redteam-item:last-child { border-bottom: none; }
  .warn-icon { color: #fbbf24; margin-right: 0.5rem; }

  .verdict-box { background: #14532d; border: 1px solid #166534; border-radius: 8px; padding: 1rem; margin-bottom: 1rem; font-size: 0.95rem; font-weight: 600; }
  .killed-item { padding: 0.35rem 0; font-size: 0.85rem; color: #fca5a5; }
  .kept-item { padding: 0.35rem 0; font-size: 0.85rem; color: #bbf7d0; }
  .one-thing { background: #1e1b4b; border: 1px solid #312e81; border-radius: 8px; padding: 1rem; margin-top: 1rem; font-style: italic; color: #c7d2fe; }

  /* Drill-down details */
  details { margin-bottom: 0.5rem; }
  details summary { cursor: pointer; padding: 0.5rem 0; font-weight: 600; font-size: 0.9rem; color: #94a3b8; list-style: none; display: flex; align-items: center; gap: 0.5rem; }
  details summary::before { content: "▶"; font-size: 0.65rem; transition: transform 0.2s; color: #64748b; }
  details[open] summary::before { transform: rotate(90deg); }
  details summary:hover { color: #e2e8f0; }
  .detail-body { padding: 0.75rem 0 0.75rem 1.25rem; border-left: 2px solid #334155; margin-left: 0.3rem; }

  .idea-line { padding: 0.3rem 0; font-size: 0.82rem; color: #cbd5e1; border-bottom: 1px solid #1e293b; }
  .idea-line:last-child { border-bottom: none; }
  .idea-id { color: #8b5cf6; font-weight: 700; margin-right: 0.3rem; }
  .idea-agent { color: #64748b; font-size: 0.75rem; }

  .dedup-merge { padding: 0.4rem 0; font-size: 0.82rem; border-bottom: 1px solid #1e293b; }
  .dedup-keep { color: #bbf7d0; }
  .dedup-remove { color: #fca5a5; }

  .rt-detail { padding: 0.5rem 0; border-bottom: 1px solid #334155; }
  .rt-detail:last-child { border-bottom: none; }
  .rt-field { font-size: 0.78rem; color: #94a3b8; margin-top: 0.2rem; }
  .rt-field strong { color: #cbd5e1; }

  .cluster-detail { margin-bottom: 0.75rem; }
  .cluster-name { font-weight: 600; color: #c7d2fe; margin-bottom: 0.25rem; }
  .cluster-ideas { font-size: 0.8rem; color: #64748b; }

  .combo-card { background: #0f172a; border-radius: 8px; padding: 0.75rem; margin-bottom: 0.5rem; }
  .combo-title { font-weight: 600; font-size: 0.9rem; margin-bottom: 0.25rem; }
  .combo-desc { font-size: 0.82rem; color: #94a3b8; }

  .footer { text-align: center; color: #475569; font-size: 0.75rem; margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #1e293b; }
</style>
</head>
<body>
CSSEOF

# ── Header ───────────────────────────────────────────────────────────────────
cat >> "$OUT" << EOF
<div style="margin-bottom: 2rem;">
  <h1>$TOPIC</h1>
  <div class="topic">Session: $SESSION_ID</div>
  <div class="meta-row">
    <span class="meta-badge" style="background:${COMPLEXITY_COLOR}20; color:${COMPLEXITY_COLOR}; border: 1px solid ${COMPLEXITY_COLOR}">$COMPLEXITY</span>
    <span class="meta-badge" style="background:#1e293b; color:#94a3b8; border: 1px solid #334155">$MODE mode</span>
    <span class="meta-badge" style="background:#1e293b; color:#94a3b8; border: 1px solid #334155">$TOTAL_ROUNDS rounds</span>
    <span class="meta-badge" style="background:#1e293b; color:#94a3b8; border: 1px solid #334155">$NUM_AGENTS agents</span>
    <span class="meta-badge" style="background:#1e293b; color:#94a3b8; border: 1px solid #334155">$CREATED</span>
  </div>
</div>
EOF

# ── Pipeline ─────────────────────────────────────────────────────────────────
ARBITER_FILE="$SD/output/hardened_execution_plan.md"
cat >> "$OUT" << EOF
<div class="pipeline">
  <div class="pipe-step $([ -f "$SD/feed/research_base.md" ] && echo done || echo pending)">Research</div>
  <div class="pipe-step done">Setup</div>
  <div class="pipe-step done">Ideation</div>
  <div class="pipe-step done">Evaluation</div>
  <div class="pipe-step done">Synthesis</div>
  <div class="pipe-step done">Red Team</div>
  <div class="pipe-step $([ -f "$ARBITER_FILE" ] && echo done || echo pending)">Arbiter</div>
  <div class="pipe-step $([ "$PHASE" = "complete" ] && echo done || echo active)">Complete</div>
</div>
EOF

# ── Stats ────────────────────────────────────────────────────────────────────
CLUSTERS_FILE="$SD/evaluation/clusters.md"
NUM_CLUSTERS=0
[ -f "$CLUSTERS_FILE" ] && NUM_CLUSTERS=$(grep -cE '^## ' "$CLUSTERS_FILE" 2>/dev/null || true)

cat >> "$OUT" << EOF
<div class="grid-4" style="margin-bottom: 1.5rem;">
  <div class="stat-card"><div class="stat-num" style="color:#8b5cf6">$TOTAL_RAW</div><div class="stat-label">Ideas Generated</div></div>
  <div class="stat-card"><div class="stat-num" style="color:#ef4444">$TOTAL_DEDUP_REMOVED</div><div class="stat-label">Duplicates Removed</div></div>
  <div class="stat-card"><div class="stat-num" style="color:#10b981">$TOTAL_FINAL</div><div class="stat-label">Final Ideas</div></div>
  <div class="stat-card"><div class="stat-num" style="color:#f59e0b">$NUM_CLUSTERS</div><div class="stat-label">Clusters</div></div>
</div>
EOF

# ── Agents ───────────────────────────────────────────────────────────────────
echo '<div class="grid-2">' >> "$OUT"
echo '<div class="section"><h2>Agents</h2>' >> "$OUT"

AGENT_NAMES_ARR=()
while IFS= read -r n; do AGENT_NAMES_ARR+=("$n"); done < <(jq -r '.agents[].name' "$SF")

for ((i=0; i<${#AGENT_NAMES_ARR[@]}; i++)); do
  name="${AGENT_NAMES_ARR[$i]}"
  DNAME=$(jq -r ".agents[$i].display_name" "$SF" | html_escape)
  MODEL=$(jq -r ".agents[$i].model" "$SF" | html_escape)
  COLOR="${COLORS[$((i % ${#COLORS[@]}))]}"
  AGENT_IDEAS=0
  PER_ROUND=""
  for ((rr=1; rr<=TOTAL_ROUNDS; rr++)); do
    F="$SD/round${rr}/${name}.md"
    C=0
    [ -f "$F" ] && C=$(grep -cE '^[0-9]+[.)]' "$F" 2>/dev/null || true)
    AGENT_IDEAS=$((AGENT_IDEAS + C))
    PER_ROUND="$PER_ROUND R$rr:$C"
  done
  cat >> "$OUT" << EOF
  <div class="agent-card" style="border-left: 4px solid $COLOR">
    <div class="agent-name">$DNAME</div>
    <div class="agent-meta">$MODEL &middot; $AGENT_IDEAS ideas ($PER_ROUND)</div>
  </div>
EOF
done
echo '</div>' >> "$OUT"

# ── Idea Flow Bars ───────────────────────────────────────────────────────────
echo '<div class="section"><h2>Idea Flow by Round</h2>' >> "$OUT"
for ((r=0; r<TOTAL_ROUNDS; r++)); do
  RN=$((r + 1))
  RAW="${ROUND_RAW_COUNTS[$r]}"
  REM="${ROUND_REMOVED[$r]}"
  AFTER="${ROUND_DEDUP_COUNTS[$r]}"
  [ "$TOTAL_RAW" -gt 0 ] && PCT=$(( RAW * 100 / TOTAL_RAW )) || PCT=50
  [ "$PCT" -lt 20 ] && PCT=20
  DEDUP_BADGE=""
  [ "$REM" -gt 0 ] && DEDUP_BADGE=" <span class=\"dedup-badge\">&minus;$REM dedup</span>"
  cat >> "$OUT" << EOF
  <div class="round-bar"><div class="round-label">R$RN</div><div class="bar-track"><div class="bar-fill" style="width:${PCT}%"></div></div><div class="round-stats">$RAW ideas$DEDUP_BADGE &rarr; $AFTER</div></div>
EOF
done
cat >> "$OUT" << EOF
  <div style="margin-top:0.75rem; font-size:0.8rem; color:#64748b; text-align:right;">
    $TOTAL_RAW generated &rarr; $TOTAL_DEDUP_REMOVED deduped &rarr; <strong style="color:#10b981">$TOTAL_FINAL final</strong>
  </div>
</div></div>
EOF

# ═══════════════════════════════════════════════════════════════════════════
# ROUND DRILL-DOWNS
# ═══════════════════════════════════════════════════════════════════════════
for ((r=1; r<=TOTAL_ROUNDS; r++)); do
  ROUND_LABEL="Round $r"
  [ "$r" -eq 1 ] && ROUND_LABEL="Round 1 — Independent Ideation"
  [ "$r" -eq 2 ] && ROUND_LABEL="Round 2 — Piggybacking"
  [ "$r" -eq 3 ] && ROUND_LABEL="Round 3 — Wild Card"
  RAW="${ROUND_RAW_COUNTS[$((r-1))]}"
  AFTER="${ROUND_DEDUP_COUNTS[$((r-1))]}"
  REM="${ROUND_REMOVED[$((r-1))]}"

  cat >> "$OUT" << EOF
<div class="section">
  <details>
    <summary><span style="font-size:1rem;">$ROUND_LABEL</span> <span style="font-size:0.8rem; color:#64748b; font-weight:400;">&mdash; $RAW ideas from $NUM_AGENTS agents, $REM deduped &rarr; $AFTER final</span></summary>
    <div class="detail-body">
EOF

  # Per-agent ideas
  for ((i=0; i<${#AGENT_NAMES_ARR[@]}; i++)); do
    name="${AGENT_NAMES_ARR[$i]}"
    DNAME=$(jq -r ".agents[$i].display_name" "$SF" | html_escape)
    COLOR="${COLORS[$((i % ${#COLORS[@]}))]}"
    F="$SD/round${r}/${name}.md"
    if [ -f "$F" ]; then
      IC=$(grep -cE '^[0-9]+[.)]' "$F" 2>/dev/null || true)
      cat >> "$OUT" << EOF
      <details>
        <summary style="color:$COLOR">$DNAME ($IC ideas)</summary>
        <div class="detail-body">
EOF
      # Output each numbered idea
      { grep -E '^[0-9]+\.' "$F" 2>/dev/null || true; } | while IFS= read -r idea; do
        NUM=$(echo "$idea" | grep -oE '^[0-9]+')
        TEXT=$(echo "$idea" | sed 's/^[0-9]*\.[[:space:]]*//' | html_escape); TEXT="${TEXT:0:300}"
        echo "<div class=\"idea-line\"><span class=\"idea-id\">$NUM.</span> $TEXT</div>" >> "$OUT"
      done
      echo '</div></details>' >> "$OUT"
    fi
  done

  # Dedup details for this round
  DEDUP_FILE="$SD/board/round${r}_dedup.md"
  if [ -f "$DEDUP_FILE" ] && [ "$REM" -gt 0 ]; then
    cat >> "$OUT" << EOF
      <details>
        <summary style="color:#fca5a5">Dedup Report ($REM removed)</summary>
        <div class="detail-body">
EOF
    { grep -E '^- (KEEP|REMOVE)' "$DEDUP_FILE" 2>/dev/null || true; } | while IFS= read -r line; do
      if echo "$line" | grep -q 'KEEP'; then
        TEXT=$(echo "$line" | sed 's/^- //' | html_escape)
        echo "<div class=\"dedup-merge\">$TEXT</div>" >> "$OUT"
      fi
    done
    # If no KEEP/REMOVE lines, try the MERGES format
    if ! grep -q '^- KEEP' "$DEDUP_FILE" 2>/dev/null; then
      sed -n '/^MERGES:/,/^$/p' "$DEDUP_FILE" 2>/dev/null | grep '^-' | while IFS= read -r line; do
        TEXT=$(echo "$line" | sed 's/^- //' | html_escape)
        echo "<div class=\"dedup-merge\">$TEXT</div>" >> "$OUT"
      done
    fi
    echo '</div></details>' >> "$OUT"
  fi

  # Diversity (Round 1 only)
  if [ "$r" -eq 1 ] && [ -f "$SD/board/round1_diversity.md" ]; then
    DIVSCORE=$(grep -oE 'DIVERSITY_SCORE:[[:space:]]*[0-9]+' "$SD/board/round1_diversity.md" 2>/dev/null | grep -oE '[0-9]+' || echo "?")
    cat >> "$OUT" << EOF
      <details>
        <summary>Diversity Assessment (Score: $DIVSCORE/10)</summary>
        <div class="detail-body">
EOF
    # Extract key sections
    sed -n '/THEMES_FOUND/,/^$/p' "$SD/board/round1_diversity.md" 2>/dev/null | head -10 | html_escape | while IFS= read -r line; do
      echo "<div class=\"idea-line\">$line</div>" >> "$OUT"
    done
    sed -n '/GAPS/,/^$/p' "$SD/board/round1_diversity.md" 2>/dev/null | head -10 | html_escape | while IFS= read -r line; do
      echo "<div class=\"idea-line\" style=\"color:#fca5a5\">$line</div>" >> "$OUT"
    done
    echo '</div></details>' >> "$OUT"
  fi

  # Compiled board preview
  COMPILED="$SD/board/round${r}_compiled.md"
  if [ -f "$COMPILED" ]; then
    BOARD_COUNT=$(grep -cE '^\[[A-Za-z0-9_-]+\]' "$COMPILED" 2>/dev/null || true)
    BOARD_COUNT=${BOARD_COUNT:-0}
    cat >> "$OUT" << EOF
      <details>
        <summary>Compiled Board ($BOARD_COUNT ideas)</summary>
        <div class="detail-body">
EOF
    { grep -E '^\[' "$COMPILED" 2>/dev/null || true; } | while IFS= read -r line; do
      [ -z "$line" ] && continue
      ID=$(echo "$line" | grep -oE '^\[[A-Za-z0-9_-]+\]' | head -1)
      AGENT=$(echo "$line" | grep -oE '\([a-z_]+\)' | head -1 || true)
      TEXT=$(echo "$line" | sed 's/^\[[^]]*\][[:space:]]*([a-z_]*)[[:space:]]*//' | html_escape); TEXT="${TEXT:0:200}"
      echo "<div class=\"idea-line\"><span class=\"idea-id\">$ID</span> <span class=\"idea-agent\">$AGENT</span> $TEXT</div>" >> "$OUT"
    done
    echo '</div></details>' >> "$OUT"
  fi

  echo '</div></details></div>' >> "$OUT"
done

# ═══════════════════════════════════════════════════════════════════════════
# EVALUATION DRILL-DOWN
# ═══════════════════════════════════════════════════════════════════════════
echo '<div class="section"><details><summary><span style="font-size:1rem;">Evaluation</span> <span style="font-size:0.8rem; color:#64748b; font-weight:400;">&mdash; '$NUM_CLUSTERS' clusters, scored &amp; ranked</span></summary><div class="detail-body">' >> "$OUT"

# Cluster details
if [ -f "$CLUSTERS_FILE" ]; then
  echo '<details><summary>Clusters ('$NUM_CLUSTERS')</summary><div class="detail-body">' >> "$OUT"
  # Parse each cluster — flexible: match any ## heading containing "Cluster" or numbered sections
  { grep -E '^## ' "$CLUSTERS_FILE" 2>/dev/null || true; } | while IFS= read -r header; do
    CNAME=$(echo "$header" | sed 's/^##[[:space:]]*//' | html_escape)
    # Count ideas: look for ID numbers in the section (table rows, comma lists, or [N] references)
    echo "<div class=\"cluster-detail\"><div class=\"cluster-name\"><span class=\"cluster-chip\">$CNAME</span></div></div>" >> "$OUT"
  done
  echo '</div></details>' >> "$OUT"
fi

# Full top 10 ranked ideas
SCORED_FILE="$SD/evaluation/scored.md"
if [ -f "$SCORED_FILE" ]; then
  echo '<details><summary>Top Ranked Ideas</summary><div class="detail-body">' >> "$OUT"
  COUNT=0
  # Read section by section between ### headers
  while IFS= read -r line; do
    [ "$COUNT" -ge 10 ] && break
    COUNT=$((COUNT + 1))
    TITLE=$(echo "$line" | sed 's/^###[[:space:]]*//' | html_escape)
    echo "<div class=\"idea-row\"><span class=\"rank\">#$COUNT</span><span class=\"idea-text\">$TITLE</span></div>" >> "$OUT"
  done < <(grep -E '^### ' "$SCORED_FILE" 2>/dev/null | head -10)
  echo '</div></details>' >> "$OUT"
fi

# Moonshots detail
MOONSHOTS_FILE="$SD/evaluation/moonshots.md"
if [ -f "$MOONSHOTS_FILE" ]; then
  NUM_MOONSHOTS=$(grep -cE '^### ' "$MOONSHOTS_FILE" 2>/dev/null || true)
  echo '<details><summary>Moonshots ('$NUM_MOONSHOTS')</summary><div class="detail-body">' >> "$OUT"
  # Extract each moonshot with its practical kernel
  CURRENT_TITLE=""
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^### '; then
      [ -n "$CURRENT_TITLE" ] && echo '</div>' >> "$OUT"
      CURRENT_TITLE=$(echo "$line" | sed 's/^###[[:space:]]*//' | html_escape)
      echo "<div class=\"combo-card\"><div class=\"combo-title\" style=\"color:#fef08a\">$CURRENT_TITLE</div>" >> "$OUT"
    elif echo "$line" | grep -qiE '^\*\*Practical Kernel|^\*\*Tamed|^\*\*Why'; then
      TEXT=$(echo "$line" | html_escape)
      echo "<div class=\"combo-desc\">$TEXT</div>" >> "$OUT"
    fi
  done < "$MOONSHOTS_FILE"
  [ -n "$CURRENT_TITLE" ] && echo '</div>' >> "$OUT"
  echo '</div></details>' >> "$OUT"
fi

# Combinations detail
COMBOS_FILE="$SD/evaluation/combinations.md"
if [ -f "$COMBOS_FILE" ]; then
  NUM_COMBOS=$(grep -cE '^##+ .*[Cc]ombination' "$COMBOS_FILE" 2>/dev/null || true)
  [ "$NUM_COMBOS" -eq 0 ] && NUM_COMBOS=$(grep -cE '^### ' "$COMBOS_FILE" 2>/dev/null || true)
  echo '<details><summary>Combinations ('$NUM_COMBOS')</summary><div class="detail-body">' >> "$OUT"
  while IFS= read -r line; do
    TITLE=$(echo "$line" | sed 's/^#*[[:space:]]*//' | html_escape)
    echo "<div class=\"combo-card\"><div class=\"combo-title\">$TITLE</div></div>" >> "$OUT"
  done < <({ grep -E '^##+ .*[Cc]ombination' "$COMBOS_FILE" 2>/dev/null || grep -E '^### ' "$COMBOS_FILE" 2>/dev/null || true; } | head -10)
  echo '</div></details>' >> "$OUT"
fi

echo '</div></details></div>' >> "$OUT"

# ═══════════════════════════════════════════════════════════════════════════
# TOP 5 + MOONSHOTS (summary level — always visible)
# ═══════════════════════════════════════════════════════════════════════════
echo '<div class="grid-2">' >> "$OUT"

if [ -f "$SCORED_FILE" ]; then
  echo '<div class="section"><h2>Top Ranked Ideas</h2>' >> "$OUT"
  COUNT=0
  while IFS= read -r line; do
    [ "$COUNT" -ge 5 ] && break
    COUNT=$((COUNT + 1))
    TITLE=$(echo "$line" | sed 's/^###[[:space:]]*//' | html_escape)
    echo "<div class=\"idea-row\"><span class=\"rank\">#$COUNT</span><span class=\"idea-text\">$TITLE</span></div>" >> "$OUT"
  done < <(grep -E '^### ' "$SCORED_FILE" 2>/dev/null | head -5)
  echo '</div>' >> "$OUT"
fi

if [ -f "$MOONSHOTS_FILE" ]; then
  echo '<div class="section"><h2>Moonshots</h2>' >> "$OUT"
  while IFS= read -r line; do
    TITLE=$(echo "$line" | sed 's/^###[[:space:]]*//' | html_escape)
    echo "<div class=\"moonshot-chip\">$TITLE</div>" >> "$OUT"
  done < <(grep -E '^### ' "$MOONSHOTS_FILE" 2>/dev/null | head -5)
  echo '</div>' >> "$OUT"
fi
echo '</div>' >> "$OUT"

# ═══════════════════════════════════════════════════════════════════════════
# RED TEAM (with drill-down)
# ═══════════════════════════════════════════════════════════════════════════
REDTEAM_FILE="$SD/output/red_team_memo.md"
if [ -f "$REDTEAM_FILE" ]; then
  # Match any ## or ### heading that looks like a finding (Vulnerability, Failure, numbered, etc.)
  NUM_FAILURES=$(grep -cE '^##+ .*(Vulnerability|Failure|Finding|Risk|[0-9]+[.):])' "$REDTEAM_FILE" 2>/dev/null || true)
  [ "$NUM_FAILURES" -eq 0 ] && NUM_FAILURES=$(grep -cE '^##+ [^#]' "$REDTEAM_FILE" 2>/dev/null || true)
  echo '<div class="section" style="border-left: 3px solid #fbbf24;">' >> "$OUT"
  echo "<h2>Red Team Findings ($NUM_FAILURES)</h2>" >> "$OUT"

  # Summary items — extract any heading that looks like a specific finding
  { grep -E '^## .*(Vulnerability|Failure|Finding|Risk|[0-9]+[.):])' "$REDTEAM_FILE" 2>/dev/null || grep -E '^### .*[0-9]' "$REDTEAM_FILE" 2>/dev/null || true; } | head -5 | while IFS= read -r line; do
    TITLE=$(echo "$line" | sed 's/^#*[[:space:]]*//' | html_escape)
    echo "<div class=\"redteam-item\"><span class=\"warn-icon\">&#9888;</span> $TITLE</div>" >> "$OUT"
  done

  # Drill-down with full details
  echo '<details><summary>Full Details</summary><div class="detail-body">' >> "$OUT"

  # Extract headings and **bold** fields from the red team memo
  { grep -E '^##+ |^\*\*' "$REDTEAM_FILE" 2>/dev/null || true; } | while IFS= read -r line; do
    if echo "$line" | grep -qE '^##+ '; then
      TITLE=$(echo "$line" | sed 's/^#*[[:space:]]*//' | html_escape)
      echo "<div class=\"rt-detail\"><div style=\"font-weight:600; color:#fbbf24;\">$TITLE</div>" >> "$OUT"
    elif echo "$line" | grep -qE '^\*\*'; then
      TEXT=$(echo "$line" | html_escape)
      echo "<div class=\"rt-field\">$TEXT</div>" >> "$OUT"
    fi
  done

  # Blind spots + contradictions
  BLINDSPOTS=$(sed -n '/^## Blind Spots/,/^##/{/^##/d;p;}' "$REDTEAM_FILE" 2>/dev/null | head -5 | html_escape | tr '\n' ' ')
  [ -n "$BLINDSPOTS" ] && echo "<div class=\"rt-detail\" style=\"margin-top:0.75rem;\"><div style=\"font-weight:600; color:#94a3b8;\">Blind Spots</div><div class=\"rt-field\">$BLINDSPOTS</div></div>" >> "$OUT"

  CONTRADICTIONS=$(sed -n '/^## Contradictions/,/^##/{/^##/d;p;}' "$REDTEAM_FILE" 2>/dev/null | head -5 | html_escape | tr '\n' ' ')
  [ -n "$CONTRADICTIONS" ] && echo "<div class=\"rt-detail\"><div style=\"font-weight:600; color:#94a3b8;\">Contradictions</div><div class=\"rt-field\">$CONTRADICTIONS</div></div>" >> "$OUT"

  SPOF=$(sed -n '/^## Single Points/,/^##/{/^##/d;p;}' "$REDTEAM_FILE" 2>/dev/null | head -5 | html_escape | tr '\n' ' ')
  [ -n "$SPOF" ] && echo "<div class=\"rt-detail\"><div style=\"font-weight:600; color:#94a3b8;\">Single Points of Failure</div><div class=\"rt-field\">$SPOF</div></div>" >> "$OUT"

  echo '</div></details></div>' >> "$OUT"
fi

# ═══════════════════════════════════════════════════════════════════════════
# ARBITER (with drill-down)
# ═══════════════════════════════════════════════════════════════════════════
if [ -f "$ARBITER_FILE" ]; then
  echo '<div class="section" style="border-left: 3px solid #10b981;"><h2>Executive Arbiter</h2>' >> "$OUT"

  ARBITER_VERDICT=$({ grep '^\*\*Arbiter verdict:\*\*' "$ARBITER_FILE" 2>/dev/null || true; } | head -1 | sed 's/\*\*Arbiter verdict:\*\*[[:space:]]*//' | html_escape)
  [ -n "$ARBITER_VERDICT" ] && echo "<div class=\"verdict-box\">$ARBITER_VERDICT</div>" >> "$OUT"

  # Killed vs Kept (summary)
  NUM_KILLED=$(grep -cE '^\- \*\*KILLED:' "$ARBITER_FILE" 2>/dev/null || true)
  NUM_KEPT=$(grep -cE '^### Phase [0-9]+' "$ARBITER_FILE" 2>/dev/null || true)

  echo '<div class="grid-2"><div>' >> "$OUT"
  echo "<div style=\"font-size:0.8rem;color:#ef4444;font-weight:600;margin-bottom:0.5rem;\">KILLED ($NUM_KILLED)</div>" >> "$OUT"
  { grep -E '^\- \*\*KILLED:' "$ARBITER_FILE" 2>/dev/null || true; } | while IFS= read -r line; do
    ITEM=$(echo "$line" | sed 's/^-[[:space:]]*\*\*KILLED:[[:space:]]*//' | sed 's/\*\*.*//' | html_escape)
    echo "<div class=\"killed-item\">&#10060; $ITEM</div>" >> "$OUT"
  done
  echo '</div><div>' >> "$OUT"
  echo "<div style=\"font-size:0.8rem;color:#10b981;font-weight:600;margin-bottom:0.5rem;\">KEPT &amp; SEQUENCED ($NUM_KEPT phases)</div>" >> "$OUT"
  { grep -E '^### Phase [0-9]+' "$ARBITER_FILE" 2>/dev/null || true; } | while IFS= read -r line; do
    TITLE=$(echo "$line" | sed 's/^###[[:space:]]*//' | html_escape)
    echo "<div class=\"kept-item\">&#9989; $TITLE</div>" >> "$OUT"
  done
  echo '</div></div>' >> "$OUT"

  # Drill-down: Red Team Rulings
  echo '<details><summary>Red Team Rulings</summary><div class="detail-body">' >> "$OUT"
  # Extract rulings between ### headers under "## Red Team Rulings"
  IN_RULINGS=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^## Red Team Rulings'; then
      IN_RULINGS=true; continue
    fi
    [ "$IN_RULINGS" = "false" ] && continue
    echo "$line" | grep -qE '^## ' && break
    if echo "$line" | grep -qE '^### '; then
      TITLE=$(echo "$line" | sed 's/^###[[:space:]]*//' | html_escape)
      echo "<div class=\"rt-detail\"><div style=\"font-weight:600;\">$TITLE</div>" >> "$OUT"
    elif echo "$line" | grep -qE '^\*\*Ruling:\*\*'; then
      RULING=$(echo "$line" | sed 's/\*\*Ruling:\*\*[[:space:]]*//' | html_escape)
      RCOLOR="#94a3b8"
      echo "$RULING" | grep -qi 'KILL' && RCOLOR="#fca5a5"
      echo "$RULING" | grep -qi 'MITIGATE' && RCOLOR="#fef08a"
      echo "$RULING" | grep -qi 'ACCEPT' && RCOLOR="#bbf7d0"
      echo "<div class=\"rt-field\" style=\"color:$RCOLOR; font-weight:600;\">$RULING</div>" >> "$OUT"
    elif echo "$line" | grep -qE '^\*\*'; then
      TEXT=$(echo "$line" | html_escape)
      echo "<div class=\"rt-field\">$TEXT</div>" >> "$OUT"
    elif echo "$line" | grep -qE '^$'; then
      echo "</div>" >> "$OUT"
    fi
  done < "$ARBITER_FILE"
  echo '</div></details>' >> "$OUT"

  # Drill-down: Execution Phases detail
  echo '<details><summary>Execution Phases Detail</summary><div class="detail-body">' >> "$OUT"
  IN_KEPT=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^## Ideas Kept'; then
      IN_KEPT=true; continue
    fi
    [ "$IN_KEPT" = "false" ] && continue
    echo "$line" | grep -qE '^## Kill Triggers|^## The One Thing' && break
    if echo "$line" | grep -qE '^### Phase'; then
      TITLE=$(echo "$line" | sed 's/^###[[:space:]]*//' | html_escape)
      echo "<div class=\"combo-card\"><div class=\"combo-title\" style=\"color:#bbf7d0\">$TITLE</div>" >> "$OUT"
    elif echo "$line" | grep -qE '^\*\*'; then
      TEXT=$(echo "$line" | html_escape)
      echo "<div class=\"combo-desc\">$TEXT</div>" >> "$OUT"
    elif echo "$line" | grep -qE '^$' && [ "$IN_KEPT" = "true" ]; then
      echo "</div>" >> "$OUT"
    fi
  done < "$ARBITER_FILE"
  echo '</div></details>' >> "$OUT"

  # Kill Triggers
  KILL_TRIGGERS=""
  IN_TRIGGERS=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^## Kill Triggers'; then
      IN_TRIGGERS=true; continue
    fi
    [ "$IN_TRIGGERS" = "false" ] && continue
    echo "$line" | grep -qE '^## ' && break
    if echo "$line" | grep -qE '^- '; then
      TEXT=$(echo "$line" | sed 's/^- //' | html_escape)
      KILL_TRIGGERS="$KILL_TRIGGERS<div class=\"killed-item\" style=\"color:#fef08a;\">&#9889; $TEXT</div>"
    fi
  done < "$ARBITER_FILE"
  if [ -n "$KILL_TRIGGERS" ]; then
    echo '<details><summary>Kill Triggers</summary><div class="detail-body">' >> "$OUT"
    echo "$KILL_TRIGGERS" >> "$OUT"
    echo '</div></details>' >> "$OUT"
  fi

  # The One Thing
  ONE_THING=$({ sed -n '/^## The One Thing/,/^##/{/^## /d;p;}' "$ARBITER_FILE" 2>/dev/null || true; } | { grep -v '^$' || true; } | head -3 | tr '\n' ' ' | sed 's/^[[:space:]]*//' | html_escape)
  [ -z "$ONE_THING" ] && ONE_THING=$({ sed -n '/The One Thing/,$ p' "$ARBITER_FILE" 2>/dev/null || true; } | tail -n +2 | { grep -v '^$' || true; } | head -2 | tr '\n' ' ' | sed 's/^[[:space:]]*//' | html_escape)
  [ -n "$ONE_THING" ] && echo "<div class=\"one-thing\"><strong>The One Thing:</strong> $ONE_THING</div>" >> "$OUT"

  echo '</div>' >> "$OUT"
fi

# ── Footer ───────────────────────────────────────────────────────────────────
cat >> "$OUT" << EOF
<div class="footer">
  Generated by brainstorm-generate-digest.sh &middot; Session: $SESSION_ID &middot; $(date '+%Y-%m-%d %H:%M')
</div>
</body>
</html>
EOF

echo "Digest generated: $OUT"
