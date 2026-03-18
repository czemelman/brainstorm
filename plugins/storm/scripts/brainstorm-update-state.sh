#!/usr/bin/env bash
# brainstorm-update-state.sh — All session.json bookkeeping in one place.
# Usage: bash brainstorm-update-state.sh <session_dir> <action> [args...]
#
# Actions:
#   setup-complete
#   round-complete <round_num> <total_rounds>
#   checkpoint <cp_name> <waiting|skipped>
#   eval-complete
#   synthesis-complete
#   redteam-complete
#   arbiter-complete
#   phase <phase_name>

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "ERROR: Missing arguments." >&2
  echo "Usage: $0 <session_dir> <action> [args...]" >&2
  exit 1
fi

SD="$1"
ACTION="$2"
SF="$SD/session.json"

if [ ! -f "$SF" ]; then
  echo "ERROR: $SF not found" >&2
  exit 1
fi

jq_update() {
  local expr="$1"
  local tmp
  tmp=$(mktemp "$SD/.state_tmp.XXXXXX.json")
  jq "$expr" "$SF" > "$tmp" && mv "$tmp" "$SF" || { rm -f "$tmp"; return 1; }
}

case "$ACTION" in
  setup-complete)
    jq_update '.phase = "round1" | .phase_status.setup.status = "complete"'
    echo "State: setup → complete, phase → round1"
    ;;

  round-complete)
    [ $# -ge 4 ] || { echo "ERROR: round-complete requires <round_num> <total_rounds>" >&2; exit 1; }
    ROUND_NUM="$3"
    TOTAL_ROUNDS="$4"
    [[ "$ROUND_NUM" =~ ^[0-9]+$ ]] || { echo "ERROR: round_num must be integer, got '$ROUND_NUM'" >&2; exit 1; }
    [[ "$TOTAL_ROUNDS" =~ ^[0-9]+$ ]] || { echo "ERROR: total_rounds must be integer, got '$TOTAL_ROUNDS'" >&2; exit 1; }

    # Build list of agents with output files
    AGENTS_WITH_OUTPUT=""
    while IFS= read -r agent; do
      if test -s "$SD/round${ROUND_NUM}/${agent}.md"; then
        AGENTS_WITH_OUTPUT="$AGENTS_WITH_OUTPUT $agent"
      fi
    done < <(jq -r '.agents[].name' "$SF")

    # Update rounds_completed and rounds_pending for all agents in one pass
    jq --arg agents "$AGENTS_WITH_OUTPUT" --argjson rn "$ROUND_NUM" \
      '.agents = [.agents[] |
        if (.name as $n | $agents | split(" ") | map(select(. != "")) | index($n))
        then .rounds_completed = (.rounds_completed + [$rn] | unique)
           | .rounds_pending = [.rounds_pending[] | select(. != $rn)]
        else . end
      ] | .phase_status.ideation.status = "in_progress"' \
      "$SF" > "$SD/.state_tmp_rc.json" && mv "$SD/.state_tmp_rc.json" "$SF" || {
      # Fallback: simpler update without rounds tracking
      echo "WARN: Per-agent round tracking failed for round ${ROUND_NUM}, falling back to phase-only update" >&2
      jq_update '.phase_status.ideation.status = "in_progress"'
    }

    # Advance phase (atomic — single write, with idempotency guard)
    if [ "$ROUND_NUM" -lt "$TOTAL_ROUNDS" ]; then
      NEXT=$((ROUND_NUM + 1))
      CURRENT_PHASE=$(jq -r '.phase' "$SF")
      # Guard: only advance if not already past this round
      if [ "$CURRENT_PHASE" = "round${ROUND_NUM}" ] || [ "$CURRENT_PHASE" = "setup" ]; then
        jq --arg p "round${NEXT}" '.phase = $p' "$SF" > "$SD/.state_tmp_rc.json" && mv "$SD/.state_tmp_rc.json" "$SF"
      fi
      echo "State: round${ROUND_NUM} → complete, phase → round${NEXT}"
    else
      jq_update '.phase = "evaluation" | .phase_status.ideation.status = "complete"'
      echo "State: round${ROUND_NUM} → complete, phase → evaluation"
    fi
    ;;

  checkpoint)
    [ $# -ge 4 ] || { echo "ERROR: checkpoint requires <cp_name> <status>" >&2; exit 1; }
    CP_NAME="$3"
    CP_STATUS="$4"
    jq --arg name "$CP_NAME" --arg status "$CP_STATUS" \
      '.checkpoints[$name].status = $status' "$SF" > "$SD/.state_tmp_cp.json" && mv "$SD/.state_tmp_cp.json" "$SF"
    echo "State: checkpoint ${CP_NAME} → ${CP_STATUS}"
    ;;

  eval-complete)
    jq_update '.phase = "synthesis" | .phase_status.clustering.status = "complete" | .phase_status.scoring.status = "complete"'
    echo "State: evaluation → complete, phase → synthesis"
    ;;

  synthesis-complete)
    jq_update '.phase = "redteam" | .phase_status.synthesis.status = "complete"'
    echo "State: synthesis → complete, phase → redteam"
    ;;

  redteam-complete)
    jq_update '.phase = "arbiter" | .phase_status.redteam.status = "complete"'
    echo "State: redteam → complete, phase → arbiter"
    ;;

  arbiter-complete)
    jq_update '.phase = "complete" | .phase_status.arbiter.status = "complete"'
    echo "State: arbiter → complete, phase → complete"
    ;;

  phase)
    [ $# -ge 3 ] || { echo "ERROR: phase requires <phase_name>" >&2; exit 1; }
    PHASE="$3"
    jq --arg p "$PHASE" '.phase = $p' "$SF" > "$SD/.state_tmp_ph.json" && mv "$SD/.state_tmp_ph.json" "$SF"
    echo "State: phase → ${PHASE}"
    ;;

  *)
    echo "ERROR: Unknown action: $ACTION" >&2
    echo "Usage: $0 <session_dir> <action> [args...]" >&2
    exit 1
    ;;
esac
