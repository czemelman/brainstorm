You are the brainstorm entry point. You route to either starting a new session or continuing an existing one.

## Plugin Root Discovery

Before doing anything else, discover the plugin installation path by running:
```bash
STORM_ROOT=$(find ~/.claude/plugins/cache -path "*/storm/*/.claude-plugin/plugin.json" 2>/dev/null | head -1 | xargs dirname 2>/dev/null | sed 's/\/.claude-plugin$//')
[ -z "$STORM_ROOT" ] && STORM_ROOT=$(find ~/.claude/plugins -path "*/storm/*/.claude-plugin/plugin.json" 2>/dev/null | head -1 | xargs dirname 2>/dev/null | sed 's/\/.claude-plugin$//')
echo "STORM_ROOT=$STORM_ROOT"
```
Store this path — ALL subsequent file reads for agents, instructions, and scripts use `$STORM_ROOT` as the base directory.

## Routing Logic

### 1. If `$ARGUMENTS` contains a topic string (not just flags)

Skip to step 3 — the user knows what they want.

### 2. If `$ARGUMENTS` is empty or contains only flags

Check `~/brainstorm-sessions/` for in-progress sessions. For each session directory, read its `session.json` and check the `phase` field. Collect any sessions where phase is NOT "complete".

**If in-progress sessions exist:** Ask the user using AskUserQuestion:
- "Start a new brainstorm" — begin a fresh session
- One option per in-progress session: "{topic}" with description "Phase: {phase} | Mode: {mode} | Created: {created_at}"

**If the user picks an existing session:** Read the file `$STORM_ROOT/instructions/brainstorm-continue-instructions.md` and follow those instructions for the selected session directory.

**If the user picks "Start new" or no sessions exist:** Fall through to step 3.

### 3. Start New Session

Read the file `$STORM_ROOT/instructions/brainstorm-initiate-instructions.md` and follow those instructions. Pass along any `$ARGUMENTS` that were provided.

## Context Pressure

Before routing, check context pressure by reading the temp file:
```bash
CTX_FILE=$(ls -t "${TMPDIR:-/tmp}"/claude-ctx-*.json 2>/dev/null | head -1)
[ -n "$CTX_FILE" ] && jq -r '.status' "$CTX_FILE" 2>/dev/null
```

If RED: tell the user to start a fresh Claude session and re-run the command. Their brainstorm state (if any) is preserved.
If ORANGE: warn that context is getting tight and recommend starting fresh, but allow them to proceed if they choose.

IMPORTANT: This command is a thin router. The heavy logic lives in the instruction files — read the appropriate one and follow it. Do NOT attempt to run brainstorming agents inline.
