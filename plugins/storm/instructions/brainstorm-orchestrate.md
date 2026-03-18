# Brainstorm Orchestration — Main-Session Phase Runner

You are the orchestrator. Follow these phases in order. LLMs do the thinking
(via Agent tool), shell does the bookkeeping (via Bash tool).

## Conventions

- **$SD** = the session directory (e.g. `~/brainstorm-sessions/{session_id}`)
- All Agent calls use `run_in_background: true` for parallel dispatch within a round
- All state updates go through `bash $STORM_ROOT/scripts/brainstorm-update-state.sh`
- All dedup application goes through `bash $STORM_ROOT/scripts/brainstorm-apply-dedup.sh`
- When an Agent completes, you receive a notification — do NOT poll or sleep

## Agent Path Convention

Agent system prompts (in `$STORM_ROOT/agents/brainstorm-*.md`) reference `input/` paths
from an older sandbox model. **Always override these in your user prompt** by specifying
the actual `$SD/`-based file paths. The agent will follow your user prompt paths.

Example: Even though the scorer's system prompt says "Read `input/cluster.md`", your
prompt should say "Read `$SD/evaluation/cluster_1_input.md`".

## Context Pressure Check (run before every phase)

```bash
CTX_FILE=$(ls -t "${TMPDIR:-/tmp}"/claude-ctx-*.json 2>/dev/null | head -1)
if [ -n "$CTX_FILE" ]; then
  PRESSURE=$(jq -r '.status // "UNKNOWN"' "$CTX_FILE" 2>/dev/null)
  echo "Context pressure: $PRESSURE"
fi
```

- **GREEN/YELLOW/UNKNOWN**: Continue.
- **ORANGE**: Warn user: "Context pressure is ORANGE. Consider starting a fresh session after the current phase."
- **RED**: Stop immediately. Tell the user to run `/storm:continue` in a fresh session.

## Hardened Bash Patterns (reference — used by scripts and inline)

### Content-Aware File Checks
```bash
is_valid_board() { test -s "$1" && [ $(grep -cE '\[[0-9]+\]' "$1" 2>/dev/null || echo 0) -gt 2 ]; }
is_valid_agent_output() { test -s "$1" && [ $(grep -cE '^[0-9]+\.' "$1" 2>/dev/null || echo 0) -gt 0 ]; }
is_valid_eval() { test -s "$1" && [ $(wc -c < "$1" 2>/dev/null || echo 0) -gt 200 ]; }
```

---

## Phase 0: Research

### Prerequisites
- `$SD/session.json` exists with seed fields
- `$SD/topic.txt` exists

### Actions

1. Create feed directory: `mkdir -p "$SD/feed"`

2. Launch research agent (Agent tool, **foreground** — must complete before setup):
   - System prompt: read `$STORM_ROOT/agents/brainstorm-research.md`
   - Model: opus
   - Prompt: "You are the brainstorm research agent. The session directory is `$SD`. Read `$SD/topic.txt` and `$SD/session.json` for topic and complexity. Execute all phases (0 → 0b → 1 → 2 → 3 → 4) from your instructions. Write state files to `$SD/feed/phase_N_state.json` and final output to `$SD/feed/research_base.md`. IMPORTANT: Ignore any `input/` path references in your system prompt — use `$SD/` paths for all files."
   - Tools available: Read, Write, Glob, Grep, WebSearch, WebFetch

3. **Validation Gate** (Bash):
   ```bash
   SD="<session_dir>"
   test -s "$SD/feed/research_base.md" && [ $(wc -c < "$SD/feed/research_base.md") -gt 200 ] && echo "OK: research_base.md" || echo "FAIL: research_base.md missing or too short"
   ```
   On failure: Retry research agent once. If still fails, continue to setup
   (setup agent has a fallback for missing research).

---

## Phase 1: Setup

### Prerequisites
- `$SD/session.json` exists with seed fields
- `$SD/topic.txt` exists
- `$SD/feed/research_base.md` exists (from Phase 0)

### Actions

1. Backup seed: `cp "$SD/session.json" "$SD/session.json.seed_backup"`

2. Launch setup agent (Agent tool, **foreground** — must complete before continuing):
   - System prompt: read `$STORM_ROOT/agents/brainstorm-setup.md`
   - Model: opus
   - Prompt: "You are the brainstorm setup agent. The session directory is `$SD`. Read `$SD/topic.txt`, `$SD/session.json`, and `$SD/feed/research_base.md` (the pre-built research base). Execute all steps from your instructions. For Step 6, integrate findings from research_base.md into persona briefings — do NOT re-do web research. Write output files (problem.md, feed/personas.json, feed/*_briefing.md) to `$SD`. Do NOT write session.json — the orchestrator handles that. IMPORTANT: Ignore any `input/` path references in your system prompt — use `$SD/` paths for all files."
   - Tools available: Read, Write, Glob

3. **Build session.json** (Bash — deterministic, never fails on schema):
   ```bash
   bash $STORM_ROOT/scripts/brainstorm-build-session.sh "<session_dir>"
   ```

4. **Validation Gate** (Bash):
   ```bash
   SD="<session_dir>"
   jq -e '.config.total_rounds and .agents[0].name' "$SD/session.json" > /dev/null
   test -s "$SD/problem.md" && [ $(wc -c < "$SD/problem.md") -gt 50 ]
   for name in $(jq -r '.agents[].name' "$SD/session.json"); do
     test -s "$SD/feed/${name}_briefing.md" && echo "OK: $name" || echo "MISSING: $name"
   done
   ```
   On failure: Retry setup agent once. If still fails, stop and report.

5. **State Update** — run this Bash command:
   ```bash
   bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" setup-complete
   ```

6. **Checkpoint cp1** — run this Bash command:
   - **Interactive mode**:
     ```bash
     bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" checkpoint cp1 waiting
     ```
     Then run the checkpoint agent (see Checkpoint Construction below), display summary, STOP.
   - **Yolo mode**:
     ```bash
     bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" checkpoint cp1 skipped
     ```

---

## Phase 2: Ideation Round N

Repeat this phase for each round (1 through `total_rounds` from session.json).

### Pre-Round: Adversarial Front-Load (after Round 1, before Round 2)

Launch pre-mortem agent (Agent tool, **foreground**):
- System prompt: read `$STORM_ROOT/agents/brainstorm-pre-mortem.md`
- Model: opus
- Prompt: "Read `$SD/board/round1_compiled.md` and `$SD/problem.md`. Analyze Round 1 for assumed constraints, happy-path biases, missing domains, and convergence traps. Write output to `$SD/board/r1_systemic_flaws.md`. Ignore `input/` paths in your system prompt."
- Validate: `test -s "$SD/board/r1_systemic_flaws.md"`

This output feeds directly into Round 2 as a constraint document.

### Pre-Round: Reframe (Round 3 only)

Launch reframe agent (Agent tool, **foreground**):
- System prompt: read `$STORM_ROOT/agents/brainstorm-reframe.md`
- Model: opus
- Prompt: "Read `$SD/problem.md`, `$SD/board/round1_index.md`, `$SD/board/round2_compiled.md`, `$SD/board/round1_diversity.md`, and `$SD/board/r1_systemic_flaws.md`. Generate inverting questions for Round 3 that target any gaps still unfilled after Round 2. Write output to `$SD/round3/reframe.md`. Ignore any `input/` path references in your system prompt."
- Validate: `test -s "$SD/round3/reframe.md"`

### Build Persona Prompts

For each agent in session.json, construct a prompt by reading `$STORM_ROOT/agents/brainstorm-persona.md` as a template and substituting:
- `{display_name}` → agent's display_name
- `{persona_prompt}` → agent's persona_prompt
- `{round_number}` → current round N
- `{persona_name}` → agent's name
- `{idea_count}` → from config (`ideas_per_agent_round{N}`)
- `{round_specific_instructions}` → round-appropriate instructions (see below)

**Round 1 instructions:**
> This is the INDEPENDENT IDEATION round. Generate ideas based solely on your briefing and the problem statement. You have NOT seen other agents' ideas. Think from your unique perspective. Prioritize breadth and diversity.

**Round 2 instructions:**
> This is the FORCED ORTHOGONALITY round. Read `$SD/board/r1_systemic_flaws.md` — it contains assumed constraints, convergence traps, and missing domains identified in Round 1. You are FORBIDDEN from generating ideas that fall into any convergence trap listed there. You MUST address at least one missing domain. For each idea, apply one of: INVERSION (flip an assumption), SUBTRACTION (remove a component everyone takes for granted), or CROSS-DOMAIN TRANSLATION (borrow a solution pattern from an unrelated field). Read `$SD/board/round1_index.md` for context on what Round 1 already covered. If `$SD/board/round1_diversity_gaps.md` exists, at least 2 ideas MUST target those gaps. If `$SD/checkpoints/cp2_input.md` exists, read it for additional guidance.

**Round 3 instructions:**
> This is the WILD CARD round. Read `$SD/round3/reframe.md` for inverting questions. Pick at least one and generate ideas exploring the territory it opens. Each idea should explore a DIFFERENT direction. Previous boards for reference: `$SD/board/round1_index.md`, `$SD/board/round2_compiled.md`.

### Dispatch Persona Agents

Launch ALL persona agents in a **single message** using the Agent tool with `run_in_background: true` for each:
- Model: agent's model from session.json (typically sonnet)
- Prompt: the constructed persona prompt (with `$SD/` paths, NOT `input/` paths)
- Each agent writes to `$SD/round{N}/{persona_name}.md`

Wait for all completion notifications.

### Validate Agent Outputs (Bash)
```bash
SD="<session_dir>"; N=<round>
for agent in $(jq -r '.agents[].name' "$SD/session.json"); do
  if test -s "$SD/round${N}/${agent}.md" && [ $(grep -cE '^[0-9]+\.' "$SD/round${N}/${agent}.md" 2>/dev/null || echo 0) -gt 0 ]; then
    echo "OK: $agent"
  else
    echo "MISSING/EMPTY: $agent"
  fi
done
```
On failure: Log warning for missing agents, continue with successful ones. Fatal only if 0 agents produced output.

### Compile Board with Truncation (INLINE — main session does this)

This is a mechanical merge. Do NOT launch an agent for this.

1. Get the idea limit per agent for this round:
   ```bash
   SD="<session_dir>"; N=<round>
   LIMIT=$(jq -r ".config.ideas_per_agent_round${N}" "$SD/session.json")
   echo "Idea limit per agent: $LIMIT"
   ```

2. Determine starting ID:
   ```bash
   LAST_ID=$(grep -oE '^\[?[[:space:]]*[Ii]?d?e?a?[[:space:]]*([0-9]+)' "$SD/board/round$((N-1))_compiled.md" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
   LAST_ID=${LAST_ID:-0}
   START=$((LAST_ID + 1))
   echo "Starting ID: $START"
   ```

3. Read each agent's output file from `$SD/round{N}/`. For each file:
   - Extract the agent name from the filename (strip `.md`)
   - Read numbered ideas (lines matching `^[0-9]+\.` OR `^[0-9]+)` OR `^- [0-9]+`)
   - **Take only the first $LIMIT ideas per agent** (truncate excess)
   - Reformat as: `[{global_id}] ({agent_name}) {idea_text}`
   - Increment global_id for each idea

4. Write the compiled board to `$SD/board/round{N}_compiled.md` with format:
   ```
   [1] (pragmatist) First idea text
   [2] (pragmatist) Second idea text
   [3] (contrarian) First contrarian idea
   ...
   ---
   Total: N ideas from M agents
   ```

5. **Validate compilation** (Bash):
   ```bash
   IDEA_COUNT=$(grep -cE '^\[?[[:space:]]*[0-9]+' "$SD/board/round${N}_compiled.md" 2>/dev/null || echo "0")
   echo "Round $N: $IDEA_COUNT ideas compiled"
   [ "$IDEA_COUNT" -gt 0 ] || echo "FATAL: 0 ideas compiled"
   ```

### Build Index (INLINE — main session does this)

Read `$SD/board/round{N}_compiled.md`. For each idea, produce a compressed one-liner:
```
1. (agent_name) 8-word-max summary of the idea
```
Write to `$SD/board/round{N}_index.md`. Preserve original idea numbers exactly.

### Dedup + Diversity (parallel)

Launch both in a **single message** with `run_in_background: true`:

**Dedup agent** (every round):
- System prompt: read `$STORM_ROOT/agents/brainstorm-dedup.md`
- Model: haiku
- Prompt: "Read `$SD/board/round{N}_compiled.md` as the compiled idea board. Identify near-duplicates. Write output to `$SD/board/round{N}_dedup.md`. Ignore `input/` paths in your system prompt."

**Diversity agent** (Round 1 only):
- System prompt: read `$STORM_ROOT/agents/brainstorm-diversity.md`
- Model: haiku
- Prompt: "Read `$SD/board/round1_compiled.md` as the compiled idea board. Assess idea diversity. Write output to `$SD/board/round1_diversity.md`. Ignore `input/` paths in your system prompt."

After both complete, **apply dedup** — run this Bash command:
```bash
bash $STORM_ROOT/scripts/brainstorm-apply-dedup.sh "<session_dir>" <round>
```

For Round 1 diversity, extract metrics (Bash):
```bash
SD="<session_dir>"
DIVSCORE=$(grep -oE 'DIVERSITY_SCORE:[[:space:]]*[0-9]+' "$SD/board/round1_diversity.md" 2>/dev/null | grep -oE '[0-9]+' || echo "0")
DIVSCORE=${DIVSCORE:-0}
echo "Diversity: $DIVSCORE/10"
```

If diversity < 7: Extract GAPS section and write `$SD/board/round1_diversity_gaps.md`:
```markdown
## Diversity Gap Alert (from Round 1 assessment)
**Score:** {score}/10
**MANDATORY:** At least 2 of your Round 2 ideas MUST address underrepresented areas.
{gaps section from diversity output}
{reframe suggestion from diversity output}
```

### Build Unified Board

After each round, merge ALL per-round compiled boards into `$SD/board/all_compiled.md` — run this Bash command:
```bash
bash $STORM_ROOT/scripts/brainstorm-build-board.sh "<session_dir>"
```

### State Update + Checkpoint

Run this Bash command:
```bash
bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" round-complete <round> <total_rounds>
```

**Checkpoint cp2** (after Round 1 only):
- **Interactive mode**:
  ```bash
  bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" checkpoint cp2 waiting
  ```
  Then run the checkpoint agent (see Checkpoint Construction below), display summary, STOP.
- **Yolo mode**:
  ```bash
  bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" checkpoint cp2 skipped
  ```

---

## Phase 3: Evaluation (Inverted Pipeline: Score → Rank → Cluster)

The evaluation pipeline scores ALL ideas globally first, then ranks and filters
to the top performers, then clusters only the survivors. This prevents excellent
outlier ideas from being buried in dense, mediocre clusters.

### Stage 1: Global Score

Score ALL ideas from `all_compiled.md` in parallel batches. Split the unified
board into batches of ~15-20 ideas each for parallel scoring.

```bash
SD="<session_dir>"
TOTAL=$(grep -cE '\[[0-9]+\]' "$SD/board/all_compiled.md" 2>/dev/null || true)
BATCH_SIZE=20
BATCHES=$(( (TOTAL + BATCH_SIZE - 1) / BATCH_SIZE ))
echo "Scoring $TOTAL ideas in $BATCHES batches"
```

For each batch, create `$SD/evaluation/batch_{N}_input.md` containing that
batch's ideas from `all_compiled.md`.

Launch ALL scorer agents in a **single message** with `run_in_background: true`:
- System prompt: read `$STORM_ROOT/agents/brainstorm-scorer.md`
- Model: sonnet
- One agent per batch
- Prompt: "Read `$SD/evaluation/batch_{N}_input.md` and `$SD/problem.md`. Score each idea using both the standard and delusional rubrics as appropriate. Write output to `$SD/evaluation/batch_{N}_scored.md`. Ignore `input/` paths in your system prompt."

Wait for all completion notifications.

### Stage 2: Rank and Filter

Launch ranker agent (Agent tool, **foreground**):
- System prompt: read `$STORM_ROOT/agents/brainstorm-ranker.md`
- Model: opus
- Prompt: "Read all `$SD/evaluation/batch_*_scored.md` files and `$SD/problem.md`. Produce final ranking of ALL ideas scored globally. Write `$SD/evaluation/scored.md` (top 10 actionable), `$SD/evaluation/moonshots.md` (3-5 wild ideas with tamed versions), and `$SD/evaluation/combinations.md` (3-5 multi-idea pairings). Ignore `input/` paths in your system prompt."

### Stage 3: Cluster Survivors

Launch clusterer agent (Agent tool, **foreground**):
- System prompt: read `$STORM_ROOT/agents/brainstorm-clusterer.md`
- Model: opus
- Prompt: "Read `$SD/evaluation/scored.md`, `$SD/evaluation/moonshots.md`, `$SD/evaluation/combinations.md`, and `$SD/problem.md`. Group the top-ranked and moonshot ideas into 4-8 thematic clusters for the synthesis. Write output to `$SD/evaluation/clusters.md`. Ignore `input/` paths in your system prompt."

**Validate**:
```bash
SD="<session_dir>"
is_valid_eval() { test -s "$1" && [ $(wc -c < "$1" 2>/dev/null || echo 0) -gt 200 ]; }
is_valid_eval "$SD/evaluation/scored.md" && echo "OK: scored.md" || echo "MISSING: scored.md"
is_valid_eval "$SD/evaluation/moonshots.md" && echo "OK: moonshots.md" || echo "WARN: moonshots.md"
is_valid_eval "$SD/evaluation/combinations.md" && echo "OK: combinations.md" || echo "WARN: combinations.md"
is_valid_eval "$SD/evaluation/clusters.md" && echo "OK: clusters.md" || echo "WARN: clusters.md"
```
On failure: Retry ranker once.

**State Update** — run this Bash command:
```bash
bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" eval-complete
```

**Checkpoint cp3**:
- **Interactive mode**:
  ```bash
  bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" checkpoint cp3 waiting
  ```
  Then run the checkpoint agent (see Checkpoint Construction below), display summary, STOP.
- **Yolo mode**:
  ```bash
  bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" checkpoint cp3 skipped
  ```

---

## Phase 4: Synthesis

Launch synthesizer agent (Agent tool, **foreground**):
- System prompt: read `$STORM_ROOT/agents/brainstorm-synthesizer.md`
- Model: opus
- Prompt: "Read `$SD/problem.md`, `$SD/evaluation/scored.md`, `$SD/evaluation/moonshots.md`, `$SD/evaluation/combinations.md`, and `$SD/session.json`. If `$SD/checkpoints/cp3_input.md` exists, apply those overrides. Produce the final brainstorm document. Write to `$SD/output/synthesis.md`. Ignore `input/` paths in your system prompt."

**Validate**:
```bash
SD="<session_dir>"
test -s "$SD/output/synthesis.md" && [ $(wc -c < "$SD/output/synthesis.md") -gt 500 ] && echo "OK" || echo "FAIL: synthesis too short or missing"
```
On failure: Retry synthesizer once.

**State Update** — run this Bash command:
```bash
bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" synthesis-complete
```

---

## Phase 5: Red Team

Launch red team agent (Agent tool, **foreground**):
- System prompt: read `$STORM_ROOT/agents/brainstorm-redteam.md`
- Model: opus
- Prompt: "Read `$SD/output/synthesis.md` and `$SD/problem.md`. Perform a pre-mortem failure analysis. Write to `$SD/output/red_team_memo.md`. Ignore `input/` paths in your system prompt."

**Validate**: `test -s "$SD/output/red_team_memo.md"`
On failure: Continue without memo (non-fatal).

If red team memo exists, append it to synthesis.md:
```bash
SD="<session_dir>"
echo -e "\n---\n" >> "$SD/output/synthesis.md"
cat "$SD/output/red_team_memo.md" >> "$SD/output/synthesis.md"
```

**State Update** — run this Bash command:
```bash
bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" redteam-complete
```

---

## Phase 6: Executive Arbiter

Launch arbiter agent (Agent tool, **foreground**):
- System prompt: read `$STORM_ROOT/agents/brainstorm-arbiter.md`
- Model: opus
- Prompt: "Read `$SD/output/synthesis.md`, `$SD/output/red_team_memo.md`, `$SD/problem.md`, and `$SD/session.json`. You are the Executive Arbiter. Reconcile the synthesis with the red team findings into a hardened execution plan. Resolve every contradiction — you are forbidden from saying 'do both.' Write to `$SD/output/hardened_execution_plan.md`. Ignore `input/` paths in your system prompt."

**Validate**:
```bash
SD="<session_dir>"
test -s "$SD/output/hardened_execution_plan.md" && [ $(wc -c < "$SD/output/hardened_execution_plan.md") -gt 500 ] && echo "OK" || echo "FAIL: hardened execution plan too short or missing"
```
On failure: Retry arbiter once.

**State Update** — run this Bash command:
```bash
bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" arbiter-complete
```

---

## Phase 7: Complete

1. Generate visual digest — run this Bash command:
   ```bash
   bash $STORM_ROOT/scripts/brainstorm-generate-digest.sh "<session_dir>"
   ```

2. Copy ALL outputs (md + html) to `output_copy_dir` if configured — run this Bash command:
   ```bash
   SD="<session_dir>"
   COPY_DIR=$(jq -r '.output_copy_dir // "null"' "$SD/session.json")
   if [ "$COPY_DIR" != "null" ] && [ -d "$COPY_DIR" ]; then
     cp "$SD/output/"*.md "$COPY_DIR/" 2>/dev/null
     cp "$SD/output/"*.html "$COPY_DIR/" 2>/dev/null
     echo "Output copied to $COPY_DIR"
     echo "Digest: $COPY_DIR/digest.html"
   fi
   ```

3. **MANDATORY**: Display completion summary to the user listing every output file. For the digest, output a clickable `file://` URL. Use this Bash command to get the path:
   ```bash
   SD="<session_dir>"
   COPY_DIR=$(jq -r '.output_copy_dir // "null"' "$SD/session.json")
   if [ "$COPY_DIR" != "null" ] && [ -f "$COPY_DIR/digest.html" ]; then
     DIGEST_PATH="$COPY_DIR/digest.html"
   else
     DIGEST_PATH="$SD/output/digest.html"
   fi
   # URL-encode spaces as %20 for a clickable link
   DIGEST_URL="file://$(echo "$DIGEST_PATH" | sed 's/ /%20/g')"
   echo "Digest URL: $DIGEST_URL"
   ```
   Then display to the user as a markdown link:
   ```
   Visual digest: [open in browser](file:///path/to/digest.html)
   ```
   Spaces in the path MUST be encoded as `%20` in the URL.

---

## Checkpoint Construction

When running a checkpoint in interactive mode, construct the checkpoint agent's input:

### cp1 (post-setup):
1. Write `$SD/checkpoints/cp1_context.md` containing:
   - "CHECKPOINT: cp1"
   - Contents of `$SD/problem.md`
   - Session config: `jq '{complexity, config: .config, agents: [.agents[] | {name, display_name, model}]}' "$SD/session.json"`
   - Summary of `$SD/feed/research_base.md` (first 50 lines)
2. Launch checkpoint agent (haiku):
   - System prompt: read `$STORM_ROOT/agents/brainstorm-checkpoint.md`
   - Prompt: "Read `$SD/checkpoints/cp1_context.md`. Produce the cp1 checkpoint summary. Write to `$SD/checkpoints/cp1_summary.md`. Ignore `input/` paths in your system prompt."
3. Read and display `$SD/checkpoints/cp1_summary.md` to the user.

### cp2 (post-round1):
1. Write `$SD/checkpoints/cp2_context.md` containing:
   - "CHECKPOINT: cp2"
   - Contents of `$SD/board/round1_index.md`
   - Contents of `$SD/board/round1_diversity.md`
   - Agent count: `jq '.agents | length' "$SD/session.json"`
2. Launch checkpoint agent (haiku) → `$SD/checkpoints/cp2_summary.md`
3. Display to user.

### cp3 (post-evaluation):
1. Write `$SD/checkpoints/cp3_context.md` containing:
   - "CHECKPOINT: cp3"
   - First 80 lines of `$SD/evaluation/scored.md`
   - First 60 lines of `$SD/evaluation/moonshots.md`
   - First 40 lines of `$SD/evaluation/combinations.md`
2. Launch checkpoint agent (haiku) → `$SD/checkpoints/cp3_summary.md`
3. Display to user.

---

## Phase 7: Resume Logic (Content-Aware)

Run this Bash command to detect current state:

```bash
SD="<session_dir>"

is_valid_board() { test -s "$1" && [ $(grep -cE '\[[0-9]+\]' "$1" 2>/dev/null || echo 0) -gt 2 ]; }
is_valid_eval() { test -s "$1" && [ $(wc -c < "$1" 2>/dev/null || echo 0) -gt 200 ]; }

if ! test -s "$SD/feed/research_base.md"; then
  echo "RESUME: research"
elif ! test -s "$SD/problem.md"; then
  echo "RESUME: setup"
elif ! is_valid_board "$SD/board/round1_compiled.md"; then
  DONE=$(ls "$SD/round1/"*.md 2>/dev/null | wc -l | tr -d ' ')
  EXPECTED=$(jq '.agents | length' "$SD/session.json")
  if [ "$DONE" -lt "$EXPECTED" ] 2>/dev/null; then
    echo "RESUME: round1 (agents: $DONE/$EXPECTED done)"
  else
    echo "RESUME: round1 (compile step)"
  fi
elif ! is_valid_board "$SD/board/round2_compiled.md" 2>/dev/null; then
  TOTAL_ROUNDS=$(jq -r '.config.total_rounds' "$SD/session.json")
  [ "$TOTAL_ROUNDS" -ge 2 ] && echo "RESUME: round2" || echo "RESUME: evaluation"
elif ! is_valid_board "$SD/board/round3_compiled.md" 2>/dev/null; then
  TOTAL_ROUNDS=$(jq -r '.config.total_rounds' "$SD/session.json")
  if [ "$TOTAL_ROUNDS" -ge 3 ]; then
    test -s "$SD/round3/reframe.md" && echo "RESUME: round3 (reframe done)" || echo "RESUME: round3 (need reframe)"
  elif ! is_valid_eval "$SD/evaluation/clusters.md"; then
    echo "RESUME: evaluation (cluster)"
  elif ! is_valid_eval "$SD/evaluation/scored.md"; then
    echo "RESUME: evaluation (score/rank)"
  elif ! is_valid_eval "$SD/output/synthesis.md"; then
    echo "RESUME: synthesis"
  elif ! test -s "$SD/output/red_team_memo.md"; then
    echo "RESUME: redteam"
  elif ! test -s "$SD/output/hardened_execution_plan.md"; then
    echo "RESUME: arbiter"
  else
    echo "RESUME: complete"
  fi
elif ! is_valid_eval "$SD/evaluation/clusters.md"; then
  echo "RESUME: evaluation (cluster)"
elif ! is_valid_eval "$SD/evaluation/scored.md"; then
  echo "RESUME: evaluation (score/rank)"
elif ! is_valid_eval "$SD/output/synthesis.md"; then
  echo "RESUME: synthesis"
elif ! test -s "$SD/output/red_team_memo.md"; then
  echo "RESUME: redteam"
elif ! test -s "$SD/output/hardened_execution_plan.md"; then
  echo "RESUME: arbiter"
else
  echo "RESUME: complete"
fi
```

After detecting the resume point, update session.json and execute from that phase:
```bash
bash $STORM_ROOT/scripts/brainstorm-update-state.sh "<session_dir>" phase <detected_phase>
```

**Key rule**: Truncated or empty files are treated as INCOMPLETE, not as evidence the phase finished.

---

## TODO(universal) Extension Points

<!-- TODO(universal): Persona generation — support domain-adaptive archetypes -->
<!-- TODO(universal): Output format — support strategy doc, RFC, naming list -->
<!-- TODO(universal): Idea granularity — support one-sentence vs paragraph-length -->
<!-- TODO(universal): Complexity tiers — support custom configurations beyond light/standard/deep -->
