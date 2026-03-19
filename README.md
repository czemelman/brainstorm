<div align="center">
<br>

# Storm

**Multi-agent brainstorming for Claude Code**

Turn a prompt into a researched, debated, red-teamed execution plan.

<br>

[![Install](https://img.shields.io/badge/Install-Claude_Code_Plugin-18181b?style=flat-square)](#install)
&nbsp;&nbsp;
[![v1.0.0](https://img.shields.io/badge/v1.0.0-18181b?style=flat-square)](#)
&nbsp;&nbsp;
[![MIT](https://img.shields.io/badge/MIT-18181b?style=flat-square)](#license)

<br>
</div>

Storm orchestrates 14 AI agents across a structured pipeline — research, three rounds of ideation, scoring, synthesis, adversarial review, and a hardened execution plan. It generates 60-90 ideas, eliminates duplicates, ranks globally, and stress-tests the result before delivering a plan you can act on.

<br>

## Pipeline

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '14px', 'primaryColor': '#f4f4f5', 'primaryTextColor': '#18181b', 'lineColor': '#a1a1aa', 'primaryBorderColor': '#d4d4d8'}}}%%

graph TD
    R["Research"] --> S["Setup"]

    S --> R1["Round 1 · Independent"]
    R1 --> PM{"Pre-Mortem"}
    PM -->|constraints + blind spots| R2["Round 2 · Orthogonal"]
    PM -.->|systemic flaws| RF{"Reframe"}
    R2 --> RF
    RF --> R3["Round 3 · Wild Card"]

    R3 --> SC["Score → Rank → Cluster"]

    SC --> SY["Synthesis"]
    SY --> RT{"Red Team"}
    RT -->|failure modes| AR["Arbiter → Execution Plan"]

    subgraph " "
        direction TB
        R1
        PM
        R2
        RF
        R3
    end

    style R fill:#e0e7ff,stroke:#6366f1,color:#312e81
    style S fill:#e0e7ff,stroke:#6366f1,color:#312e81
    style R1 fill:#ede9fe,stroke:#8b5cf6,color:#3b0764
    style R2 fill:#ede9fe,stroke:#8b5cf6,color:#3b0764
    style R3 fill:#ede9fe,stroke:#8b5cf6,color:#3b0764
    style PM fill:#fef3c7,stroke:#d97706,color:#78350f
    style RF fill:#fef3c7,stroke:#d97706,color:#78350f
    style SC fill:#d1fae5,stroke:#059669,color:#064e3b
    style SY fill:#e0f2fe,stroke:#0284c7,color:#0c4a6e
    style RT fill:#fee2e2,stroke:#dc2626,color:#7f1d1d
    style AR fill:#f0fdf4,stroke:#16a34a,color:#14532d
```

<br>

## Install

```shell
/plugin marketplace add czemelman/brainstorm
/plugin install storm@czemelman-tools
```

<br>

## Usage

```shell
/storm:start                                    # Interactive setup
/storm:start What pricing model for our SaaS?   # Direct topic
/storm:start --yolo --deep                      # Full auto, 3 rounds
```

| Command | Purpose |
|:--------|:--------|
| `/storm:start` | New session or resume existing |
| `/storm:continue` | Resume paused interactive session |
| `/storm:status` | Session progress |
| `/storm:reset` | Delete a session |

<br>

## How It Works

<table>
<tr><td width="33%" valign="top">

**Research & Setup**

10-20 web searches grounded in current reality. Findings are tiered by source quality and routed to 6 personas — each gets a differentiated briefing so agents argue from evidence.

</td><td width="33%" valign="top">

**Three-Round Ideation**

Round 1: independent thinking. Pre-mortem finds blind spots. Round 2: forced orthogonality — convergence traps are banned, inversions are mandatory. Reframe generates inverting questions. Round 3: wild cards.

</td><td width="33%" valign="top">

**Evaluate & Harden**

All ideas scored globally, ranked, and clustered. Synthesis extracts the top 10 + moonshots. Red team runs a pre-mortem. Arbiter resolves every contradiction into a hardened execution plan.

</td></tr>
</table>

<br>

## Complexity

| Level | Rounds | Agents | Use case |
|:------|:------:|:------:|:---------|
| Light | 1 | 3–4 | Naming, simple choices |
| Standard | 2 | 5 | Feature ideation, process design |
| Deep | 3 | 5–6 | Architecture, strategy, cross-domain |

Auto-detected from topic. Override with `--light` or `--deep`.

<br>

## Output

```
synthesis.md                  Full synthesis with top 10 + moonshots + combinations
red_team_memo.md              Pre-mortem failure analysis
hardened_execution_plan.md    Final plan reconciling synthesis with red team
digest.html                   Visual HTML digest
```

Sessions stored in `~/brainstorm-sessions/`. Outputs copied to your working directory.

<br>

## Modes

**Interactive** — pauses at 3 checkpoints for steering. Good when you want to guide direction.

**Yolo** (`--yolo`) — runs end-to-end. Good for background or overnight sessions.

<br>

<details>
<summary><b>Agent Roster</b></summary>
<br>

| Agent | Role | When |
|:------|:-----|:-----|
| Research | Web search, source tiering, gap analysis | Phase 0 |
| Setup | Problem framing, persona generation | Phase 1 |
| 6× Persona | Ideation from differentiated perspectives | Each round |
| Pre-Mortem | Blind spots and convergence traps | After Round 1 |
| Reframe | Inverting questions for Round 3 | After Round 2 |
| Dedup | Near-duplicate removal | Every round |
| Diversity | Thematic spread assessment | Round 1 |
| Scorer | Standard + delusional rubrics | Evaluation |
| Ranker | Global ranking, moonshots, combinations | Evaluation |
| Clusterer | Thematic grouping | Evaluation |
| Synthesizer | Final document | Synthesis |
| Red Team | Failure analysis | Hardening |
| Arbiter | Contradiction resolution | Final |

</details>

<br>

## Requirements

- Claude Code 1.0.33+
- `jq` (`brew install jq`)

## License

MIT

<div align="center">
<sub>Built with Claude Code</sub>
</div>
