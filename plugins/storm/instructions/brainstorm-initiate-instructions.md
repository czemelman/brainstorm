# Brainstorm — New Session Instructions

## Step 1: Gather Topic and Options

**If arguments include a topic string**, parse them:
- `topic` (string): everything that is not a flag
- `--yolo` (boolean flag): if present, mode = "yolo", else mode = "interactive"
- `--light` (boolean flag): force complexity = "light"
- `--deep` (boolean flag): force complexity = "deep"
- `--rounds N` (integer): override total_rounds (1-3)

**If no topic was provided**, enter interactive setup. Use AskUserQuestion:

1. Ask for the topic: "What would you like to brainstorm about?" (free text — no predefined options, just ask directly and wait for the response)

2. Ask for complexity level:
   - "Auto-detect (Recommended)" — let the setup agent decide based on the topic
   - "Light" — quick session: 1 round, 3 agents (naming, simple choices)
   - "Standard" — balanced: 2 rounds, 5 agents (feature ideation, process improvement)
   - "Deep" — thorough: 3 rounds, 5-6 agents (architecture, strategy, cross-domain)

3. Ask for mode:
   - "Interactive (Recommended)" — pauses at 3 checkpoints so you can review and steer
   - "Yolo" — runs end-to-end without stopping

4. Ask where to save the final document:
   - "Current directory (Recommended)" — saves to the current working directory (where Claude was launched)
   - "Session directory only" — keeps the output only inside `~/brainstorm-sessions/{session_id}/output/`
   - "Custom path" — let the user specify a directory

## Step 2: Check for Similar Sessions

Check `~/brainstorm-sessions/` for any sessions with a similar topic (read topic.txt in each session directory). If a matching or similar session exists that is NOT in "complete" phase, warn the user:

```
Found an existing in-progress session on a similar topic:
  Session: {session_id}
  Phase:   {phase}
  Created: {created_at}

Would you like to continue that session instead, or start a new one?
```

If the user wants to continue, switch to the continue flow for that session (read `$STORM_ROOT/instructions/storm:continue-instructions.md`).

## Step 3: Create Session

1. Generate a `session_id`: `brainstorm-{slugified_topic_first_40_chars}-{YYYYMMDD-HHMMSS}`
   - Slugify: lowercase, replace spaces/special chars with hyphens, collapse multiple hyphens, trim trailing hyphens

2. Create the full directory tree under `~/brainstorm-sessions/{session_id}/`:
   ```
   feed/
   prompts/
   round1/
   round2/
   round3/
   board/
   evaluation/
   checkpoints/
   sandbox/
   output/
   ```

3. Write `topic.txt` containing the raw topic string.

4. Write `session.json` with:
   ```json
   {
     "session_id": "{session_id}",
     "topic": "{topic}",
     "created_at": "{ISO timestamp}",
     "mode": "interactive|yolo",
     "complexity_override": "light|deep|null",
     "rounds_override": null|N,
     "phase": "setup",
     "session_dir": "{absolute path to session dir}",
     "output_copy_dir": "{absolute path to copy final doc, or null if session-only}"
   }
   ```

   For `output_copy_dir`:
   - If "Current directory": set to the current working directory (use `pwd`)
   - If "Session directory only": set to `null`
   - If "Custom path": set to the user-specified absolute path
   - If arguments were passed (non-interactive mode): default to the current working directory

## Context Pressure Awareness

Before launching, check the context pressure temp file to assess whether the current session has enough room to run the orchestrator:

```bash
CTX_FILE=$(ls -t "${TMPDIR:-/tmp}"/claude-ctx-*.json 2>/dev/null | head -1)
if [ -n "$CTX_FILE" ]; then
  jq -r '.status' "$CTX_FILE" 2>/dev/null
fi
```

- **GREEN/YELLOW/UNKNOWN**: Proceed normally.
- **ORANGE**: Warn the user: "Context pressure is ORANGE. The brainstorm workflow checks pressure between phases and will stop on RED, but for best results consider starting a fresh Claude session first. Continue anyway?"
- **RED**: Tell the user: "Context pressure is RED. Please start a fresh Claude session and re-run /storm:start. Your brainstorm session state is fully preserved and will resume from where it left off."

Context pressure is checked before every phase. On RED, all state is saved and the user can resume with `/storm:continue` in a fresh session.

## Step 4: Confirm and Launch

Display a brief summary:

```
Starting brainstorm session:
  Topic:      {topic}
  Mode:       {interactive|yolo}
  Complexity: {auto|light|standard|deep}
  Session:    {session_id}
```

Read `$STORM_ROOT/instructions/brainstorm-orchestrate.md` and follow **Phase 1: Setup**.
The session directory (`$SD`) is `~/brainstorm-sessions/{session_id}`.

After setup completes, continue executing phases from the orchestration instructions
sequentially (Phase 2, 3, 4, etc.) unless a checkpoint pauses for user input.
