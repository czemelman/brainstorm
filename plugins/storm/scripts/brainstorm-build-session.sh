#!/usr/bin/env bash
# brainstorm-build-session.sh — Deterministically construct session.json from
# seed + personas.json + complexity. Replaces LLM-written session.json.
#
# Usage: bash brainstorm-build-session.sh <session_dir>
#
# Reads:
#   $SD/session.json         — seed fields (session_id, topic, mode, etc.)
#   $SD/feed/personas.json   — agent array from setup agent
#
# Writes:
#   $SD/session.json         — complete, validated session config

set -euo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <session_dir>" >&2
  exit 1
fi

SD="$1"
SF="$SD/session.json"
PERSONAS="$SD/feed/personas.json"

if [ ! -f "$SF" ]; then
  echo "ERROR: $SF not found" >&2
  exit 1
fi

if [ ! -f "$PERSONAS" ]; then
  echo "ERROR: $PERSONAS not found" >&2
  exit 1
fi

# ── Read seed fields ─────────────────────────────────────────────────────────
# These MUST be preserved exactly as the user set them
SEED_SESSION_ID=$(jq -r '.session_id' "$SF")
SEED_TOPIC=$(jq -r '.topic' "$SF")
SEED_CREATED=$(jq -r '.created_at' "$SF")
SEED_MODE=$(jq -r '.mode' "$SF")
SEED_COMPLEXITY_OVERRIDE=$(jq -r '.complexity_override // "null"' "$SF")
SEED_ROUNDS_OVERRIDE=$(jq -r '.rounds_override // "null"' "$SF")
SEED_SESSION_DIR=$(jq -r '.session_dir' "$SF")
SEED_OUTPUT_COPY_DIR=$(jq -r '.output_copy_dir // "null"' "$SF")

# ── Read complexity from personas.json ───────────────────────────────────────
COMPLEXITY=$(jq -r '.complexity' "$PERSONAS")
if [ -z "$COMPLEXITY" ] || [ "$COMPLEXITY" = "null" ]; then
  # Infer from agent count
  AGENT_COUNT=$(jq '.agents | length' "$PERSONAS")
  if [ "$AGENT_COUNT" -le 4 ]; then
    COMPLEXITY="light"
  elif [ "$AGENT_COUNT" -le 6 ]; then
    COMPLEXITY="standard"
  else
    COMPLEXITY="deep"
  fi
fi

# ── Override complexity if seed says so ──────────────────────────────────────
if [ "$SEED_COMPLEXITY_OVERRIDE" != "null" ]; then
  COMPLEXITY="$SEED_COMPLEXITY_OVERRIDE"
fi

# ── Derive config from complexity ────────────────────────────────────────────
case "$COMPLEXITY" in
  light)
    TOTAL_ROUNDS=1
    ROUNDS_PENDING="[1]"
    ;;
  standard)
    TOTAL_ROUNDS=2
    ROUNDS_PENDING="[1, 2]"
    ;;
  deep)
    TOTAL_ROUNDS=3
    ROUNDS_PENDING="[1, 2, 3]"
    ;;
  *)
    echo "ERROR: Unknown complexity '$COMPLEXITY'" >&2
    exit 1
    ;;
esac

# Override rounds if seed specifies
if [ "$SEED_ROUNDS_OVERRIDE" != "null" ]; then
  TOTAL_ROUNDS="$SEED_ROUNDS_OVERRIDE"
  ROUNDS_PENDING="["
  for ((r=1; r<=TOTAL_ROUNDS; r++)); do
    [ "$r" -gt 1 ] && ROUNDS_PENDING="$ROUNDS_PENDING, "
    ROUNDS_PENDING="$ROUNDS_PENDING$r"
  done
  ROUNDS_PENDING="$ROUNDS_PENDING]"
fi

# ── Build agents array with rounds tracking ──────────────────────────────────
# Normalize fields: setup agents may use archetype/perspective instead of
# display_name/persona_prompt. Derive display_name from name if missing.
AGENTS=$(jq --argjson rp "$ROUNDS_PENDING" \
  '[.agents[] | . + {
    display_name: (if (.display_name // null) != null and (.display_name | length) > 0 then .display_name else (.name | split("_") | map((.[0:1] | ascii_upcase) + .[1:]) | join(" ")) end),
    persona_prompt: (.persona_prompt // .perspective // .archetype // .cognitive_role // ""),
    rounds_completed: [],
    rounds_pending: $rp,
    briefing_file: ("feed/" + .name + "_briefing.md")
  }]' "$PERSONAS")

# ── Build checkpoints ───────────────────────────────────────────────────────
CHECKPOINTS='{}'
for ((r=1; r<=TOTAL_ROUNDS; r++)); do
  CHECKPOINTS=$(echo "$CHECKPOINTS" | jq --argjson r "$r" \
    '. + { ("cp" + ($r | tostring)): { after_round: $r, status: "pending" } }')
done

# ── Construct final session.json ─────────────────────────────────────────────
jq -n \
  --arg session_id "$SEED_SESSION_ID" \
  --arg topic "$SEED_TOPIC" \
  --arg created_at "$SEED_CREATED" \
  --arg mode "$SEED_MODE" \
  --arg complexity_override "$SEED_COMPLEXITY_OVERRIDE" \
  --arg rounds_override "$SEED_ROUNDS_OVERRIDE" \
  --arg session_dir "$SEED_SESSION_DIR" \
  --arg output_copy_dir "$SEED_OUTPUT_COPY_DIR" \
  --arg complexity "$COMPLEXITY" \
  --argjson total_rounds "$TOTAL_ROUNDS" \
  --argjson agents "$AGENTS" \
  --argjson checkpoints "$CHECKPOINTS" \
  '{
    session_id: $session_id,
    topic: $topic,
    created_at: $created_at,
    mode: $mode,
    complexity_override: (if $complexity_override == "null" then null else $complexity_override end),
    rounds_override: (if $rounds_override == "null" then null else ($rounds_override | tonumber) end),
    phase: "setup",
    session_dir: $session_dir,
    output_copy_dir: (if $output_copy_dir == "null" then null else $output_copy_dir end),
    complexity: $complexity,
    config: {
      total_rounds: $total_rounds,
      ideas_per_agent_round1: 8,
      ideas_per_agent_round2: 5,
      ideas_per_agent_round3: 3,
      diversity_threshold: 6.0
    },
    agents: $agents,
    utility_agents: {
      diversity_checker: "haiku",
      checkpoint_summarizer: "haiku",
      dedup: "haiku",
      clusterer: "opus",
      scorer: "sonnet",
      ranker: "opus",
      synthesizer: "opus",
      reframe: "opus",
      redteam: "opus"
    },
    checkpoints: $checkpoints,
    phase_status: {
      setup: { status: "complete" },
      ideation: { status: "pending" },
      clustering: { status: "pending" },
      scoring: { status: "pending" },
      synthesis: { status: "pending" }
    }
  }' > "$SD/.session_build_tmp.json" && mv "$SD/.session_build_tmp.json" "$SF"

echo "Session built: $COMPLEXITY mode, $TOTAL_ROUNDS rounds, $(jq '.agents | length' "$SF") agents"
