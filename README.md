# Storm — Multi-Agent Brainstorming for Claude Code

A Claude Code plugin that runs structured, multi-agent brainstorming sessions with research, ideation, evaluation, red team analysis, and hardened execution planning.

## Install

```shell
/plugin marketplace add https://github.com/czemelman/brainstorm.git
/plugin install storm@czemelman-tools
```

## Commands

| Command | Description |
|---------|-------------|
| `/storm:start` | Start a new brainstorm or resume an existing one |
| `/storm:continue` | Resume a paused interactive session |
| `/storm:status` | Show current session state |
| `/storm:reset` | Delete a session |

## How It Works

Each brainstorm runs through 7 phases:

1. **Research** — Web research grounded in current reality
2. **Setup** — Problem framing, persona generation, differentiated briefings
3. **Ideation** — 3 rounds (independent → forced orthogonality → wild card) with 5-6 AI agents
4. **Evaluation** — Score → Rank → Cluster pipeline
5. **Synthesis** — Final document with top ideas, moonshots, and combinations
6. **Red Team** — Pre-mortem failure analysis
7. **Arbiter** — Reconciles synthesis with red team into a hardened execution plan

## Modes

- **Interactive** — Pauses at 3 checkpoints for user steering
- **Yolo** — Runs end-to-end without stopping

## Complexity Levels

- **Light** — 1 round, 3 agents (naming, simple choices)
- **Standard** — 2 rounds, 5 agents (feature ideation, process improvement)
- **Deep** — 3 rounds, 5-6 agents (architecture, strategy, cross-domain)

## Output

Sessions are stored in `~/brainstorm-sessions/`. Final outputs include:
- `synthesis.md` — Full brainstorm synthesis
- `hardened_execution_plan.md` — Arbiter-reconciled execution plan
- `red_team_memo.md` — Pre-mortem failure analysis
- `digest.html` — Visual HTML digest

## Requirements

- Claude Code 1.0.33+
- `jq` installed (`brew install jq`)
