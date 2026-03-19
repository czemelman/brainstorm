<div align="center">

# Storm

### Multi-Agent Brainstorming for Claude Code

**Turn a single prompt into a researched, debated, red-teamed execution plan.**

[![Claude Code Plugin](https://img.shields.io/badge/Claude_Code-Plugin-7c3aed?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjIiPjxwYXRoIGQ9Ik0xMiAyTDIgN2wxMCA1IDEwLTV6Ii8+PHBhdGggZD0iTTIgMTdsMTAgNSAxMC01Ii8+PHBhdGggZD0iTTIgMTJsMTAgNSAxMC01Ii8+PC9zdmc+)](https://github.com/czemelman/brainstorm)
[![Version](https://img.shields.io/badge/version-1.0.0-blue?style=for-the-badge)](https://github.com/czemelman/brainstorm/releases)
[![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)](LICENSE)

<br>

Storm orchestrates **14 specialized AI agents** across a structured 7-phase pipeline to brainstorm any topic — from product strategy to architecture decisions to naming. It researches, ideates in parallel, eliminates duplicates, scores, ranks, stress-tests with a red team, and delivers a hardened plan you can execute tomorrow.

</div>

---

## The Pipeline

```mermaid
graph TD
    A["🔍 Research\n10+ web searches"] --> B["🧩 Setup\n6 personas + briefings"]

    subgraph IDEATION ["💡 Ideation Engine"]
        direction TB
        C["Round 1\nIndependent"] --> D{"Pre-Mortem\nBlind spots"}
        D -->|"banned traps\n+ missing domains"| E["Round 2\nForced Orthogonality"]
        D -.->|"systemic flaws"| F{"Reframe\nInverting questions"}
        E --> F
        F --> G["Round 3\nWild Card"]
    end

    subgraph EVAL ["⚖️ Evaluation"]
        direction TB
        H["Score\n5 parallel batches"] --> I["Rank\nTop 10 + moonshots"]
        I --> J["Cluster\nThematic groups"]
    end

    subgraph HARDEN ["🛡️ Hardening"]
        direction TB
        K["Synthesis\nFinal document"] --> L["Red Team\nFailure analysis"]
        L -->|"failure modes"| M["Arbiter\nHardened plan"]
    end

    B --> IDEATION
    IDEATION --> EVAL
    EVAL --> HARDEN

    style A fill:#4f46e5,stroke:#4f46e5,color:#fff
    style B fill:#4f46e5,stroke:#4f46e5,color:#fff
    style C fill:#7c3aed,stroke:#7c3aed,color:#fff
    style D fill:#f59e0b,stroke:#f59e0b,color:#fff
    style E fill:#7c3aed,stroke:#7c3aed,color:#fff
    style F fill:#f59e0b,stroke:#f59e0b,color:#fff
    style G fill:#7c3aed,stroke:#7c3aed,color:#fff
    style H fill:#059669,stroke:#059669,color:#fff
    style I fill:#059669,stroke:#059669,color:#fff
    style J fill:#059669,stroke:#059669,color:#fff
    style K fill:#0891b2,stroke:#0891b2,color:#fff
    style L fill:#dc2626,stroke:#dc2626,color:#fff
    style M fill:#0891b2,stroke:#0891b2,color:#fff

    style IDEATION fill:#1e1b4b,stroke:#7c3aed,color:#c7d2fe,stroke-width:2px
    style EVAL fill:#052e16,stroke:#059669,color:#bbf7d0,stroke-width:2px
    style HARDEN fill:#1c1917,stroke:#dc2626,color:#fca5a5,stroke-width:2px
```

<br>

## Quick Start

```shell
# Add the marketplace
/plugin marketplace add czemelman/brainstorm

# Install the plugin
/plugin install storm@czemelman-tools

# Run your first brainstorm
/storm:start What pricing model should we use for our SaaS product?
```

That's it. Storm handles the rest.

<br>

## What Makes This Different

<table>
<tr>
<td width="50%" valign="top">

### Structured Divergence
Three ideation rounds force genuinely different thinking:
- **Round 1** — Independent ideation (no groupthink)
- **Round 2** — Forced orthogonality (banned convergence traps, mandatory inversions)
- **Round 3** — Wild card (reframing questions that break assumptions)

</td>
<td width="50%" valign="top">

### Built-In Adversarial Review
Every brainstorm gets stress-tested:
- **Pre-mortem agent** identifies blind spots between rounds
- **Red team** performs failure analysis on the final synthesis
- **Executive arbiter** resolves contradictions into a hardened plan

</td>
</tr>
<tr>
<td width="50%" valign="top">

### Parallel Agent Orchestration
Up to 6 persona agents run simultaneously per round, each with differentiated domain briefings. The system generates **60-90+ ideas** across 3 rounds, deduplicates, scores, and ranks globally.

</td>
<td width="50%" valign="top">

### Research-Grounded
Every session starts with 10-20 web searches across the topic domain. Findings are tiered by source quality and routed to specific personas — so agents argue from evidence, not hallucination.

</td>
</tr>
</table>

<br>

## Commands

| Command | Description |
|:--------|:------------|
| `/storm:start` | Start a new brainstorm or resume an existing one |
| `/storm:start --yolo` | Run end-to-end without checkpoints |
| `/storm:start --deep` | Force deep complexity (3 rounds, 6 agents) |
| `/storm:continue` | Resume a paused interactive session |
| `/storm:status` | Show current session state and progress |
| `/storm:reset` | Delete a session after confirmation |

<br>

## Session Modes

<table>
<tr>
<td align="center" width="50%">

### Interactive

Pauses at **3 checkpoints** for user review and steering. Best when you want to guide the direction.

`/storm:start`

</td>
<td align="center" width="50%">

### Yolo

Runs the full pipeline **end-to-end** without stopping. Best for overnight or background runs.

`/storm:start --yolo`

</td>
</tr>
</table>

<br>

## Complexity Levels

| Level | Rounds | Agents | Best For |
|:------|:------:|:------:|:---------|
| **Light** | 1 | 3-4 | Naming, simple choices, quick ideation |
| **Standard** | 2 | 5 | Feature ideation, process improvement |
| **Deep** | 3 | 5-6 | Architecture, strategy, cross-domain problems |

Complexity is auto-detected from your topic, or override with `--light`, `--deep`.

<br>

## Output

Every completed session produces:

```
~/brainstorm-sessions/{session-id}/output/
  synthesis.md                 # Full brainstorm synthesis with top 10 ideas + moonshots
  red_team_memo.md             # Pre-mortem failure analysis
  hardened_execution_plan.md   # Final plan reconciling synthesis with red team
  digest.html                  # Visual HTML digest — open in browser
```

Output is also copied to your current working directory for convenience.

<br>

## Architecture

```
storm/
  commands/          4 slash commands (start, continue, status, reset)
  agents/           14 specialized agents
  instructions/      3 orchestration documents
  scripts/           5 bash scripts for deterministic bookkeeping
```

<details>
<summary><b>Agent Roster (14 agents)</b></summary>
<br>

| Agent | Role | Phase |
|:------|:-----|:------|
| Research | Web research, source tiering, gap analysis | Phase 0 |
| Setup | Problem framing, persona generation, briefings | Phase 1 |
| Persona (x6) | Domain-specific ideation with differentiated briefings | Rounds 1-3 |
| Pre-Mortem | Identifies blind spots and convergence traps | Between R1 and R2 |
| Reframe | Generates inverting questions for wild card round | Before R3 |
| Dedup | Near-duplicate detection on compiled boards | Every round |
| Diversity | Thematic spread assessment and gap identification | Round 1 |
| Scorer | Scores ideas (standard + delusional rubrics) | Evaluation |
| Ranker | Global ranking, moonshot extraction, combinations | Evaluation |
| Clusterer | Groups survivors into thematic clusters | Evaluation |
| Synthesizer | Produces final brainstorm document | Synthesis |
| Red Team | Pre-mortem failure analysis | Red Team |
| Arbiter | Reconciles synthesis with red team findings | Final |
| Checkpoint | Generates summaries at interactive pauses | Checkpoints |

</details>

<br>

## Requirements

- **Claude Code** 1.0.33+ with a plan that supports the Agent tool
- **jq** — `brew install jq` (macOS) or `apt install jq` (Linux)

<br>

## License

MIT

<div align="center">
<br>
<sub>Built with Claude Code</sub>
</div>
