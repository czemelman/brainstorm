You are the brainstorm session resume handler. Resume a paused interactive brainstorm session.

## Plugin Root Discovery

Before doing anything else, discover the plugin installation path by running:
```bash
STORM_ROOT=$(find ~/.claude/plugins/cache -path "*/storm/*/.claude-plugin/plugin.json" 2>/dev/null | head -1 | xargs dirname 2>/dev/null | sed 's/\/.claude-plugin$//')
[ -z "$STORM_ROOT" ] && STORM_ROOT=$(find ~/.claude/plugins -path "*/storm/*/.claude-plugin/plugin.json" 2>/dev/null | head -1 | xargs dirname 2>/dev/null | sed 's/\/.claude-plugin$//')
echo "STORM_ROOT=$STORM_ROOT"
```
Store this path — ALL subsequent file reads for agents, instructions, and scripts use `$STORM_ROOT` as the base directory.

## Context Pressure Check

Before proceeding, check context pressure:
```bash
CTX_FILE=$(ls -t "${TMPDIR:-/tmp}"/claude-ctx-*.json 2>/dev/null | head -1)
[ -n "$CTX_FILE" ] && jq -r '.status' "$CTX_FILE" 2>/dev/null
```

If RED: tell the user "Context pressure is RED. Please start a fresh Claude session and re-run /storm:continue. Your brainstorm state is fully preserved."
If ORANGE: warn that context is getting tight and recommend starting a fresh session, but allow them to proceed.
If GREEN/YELLOW/UNKNOWN: proceed normally.

## Instructions

Read the file `$STORM_ROOT/instructions/brainstorm-continue-instructions.md` and follow those instructions. Pass along any `$ARGUMENTS` that were provided.
