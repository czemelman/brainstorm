# Brainstorm — Continue Session Instructions

## Step 1: Discover Available Sessions

If a specific session directory was already selected (passed from the router), skip to Step 3.

Otherwise, list all session directories under `~/brainstorm-sessions/`. For each one, read its `session.json` and collect:
- session_id
- topic
- phase (current phase)
- mode (interactive/yolo)
- created_at

Filter to only sessions that are NOT in "complete" phase. Sort by modification time (most recent first).

## Step 2: Select a Session

**If arguments contain a session_id:** Use that session directly. Skip to Step 3.

**If there are no resumable sessions:** Inform the user: "No in-progress brainstorm sessions found. Start one with /brainstorm."

**If there is exactly 1 resumable session:** Show its details and proceed:
```
Found 1 active session:
  Session: {session_id}
  Topic:   {topic}
  Phase:   {phase}
  Mode:    {mode}
  Created: {created_at}
```

**If there are multiple resumable sessions:** Present them using AskUserQuestion so the user can pick:
- Label: "{topic}" (truncated to ~40 chars if needed)
- Description: "Phase: {phase} | Mode: {mode} | Created: {created_at}"

## Step 3: Handle Arguments

Read `session.json` from the selected session directory.

If the user provided `--inject "text"` in the arguments, write the text to `checkpoints/cp{N}_input.md` where N corresponds to the current checkpoint (determine from session.json checkpoint statuses — find the one with status "waiting").

If the user provided `--modify-personas`, set `phase` back to `setup` in session.json and clear all downstream files (delete contents of round1/, round2/, round3/, board/, evaluation/, output/).

## Context Pressure Awareness

Before resuming, check context pressure:

```bash
CTX_FILE=$(ls -t "${TMPDIR:-/tmp}"/claude-ctx-*.json 2>/dev/null | head -1)
if [ -n "$CTX_FILE" ]; then
  jq -r '.status' "$CTX_FILE" 2>/dev/null
fi
```

- **GREEN/YELLOW/UNKNOWN**: Proceed normally.
- **ORANGE**: Warn the user: "Context pressure is ORANGE. The orchestrator will auto-pause if it reaches RED, but for best results consider starting a fresh Claude session first. Continue anyway?"
- **RED**: Tell the user: "Context pressure is RED. Please start a fresh Claude session and re-run /storm:continue. Your session state is fully preserved at phase: {phase}."

Context pressure is checked before every phase. On RED, all state is saved and you can resume in a fresh session.

## Step 4: Update Checkpoint and Resume

Update the current checkpoint status from `waiting` to `cleared` in `session.json`.

Show a brief status before resuming:
```
Resuming session: {session_id}
  Topic: {topic}
  Phase: {phase}
```

Read `$STORM_ROOT/instructions/brainstorm-orchestrate.md`. Execute **Phase 7: Resume Logic**
to detect the current state from file contents, then continue from the detected phase.
The session directory (`$SD`) is `~/brainstorm-sessions/{session_id}`.
