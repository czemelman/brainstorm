# Contributing to Storm

Thanks for your interest in contributing to Storm.

## Development Setup

1. Clone the repository
2. Ensure you have `jq` and `bash` 4+ installed
3. Install [ShellCheck](https://www.shellcheck.net/) for linting bash scripts

## Project Structure

```
plugins/storm/
  agents/       14 agent specification files (markdown with YAML frontmatter)
  commands/     CLI command entry points
  instructions/ Orchestration logic
  scripts/      Bash utility scripts
```

## Guidelines

- **Shell scripts**: Follow existing patterns — `set -euo pipefail`, atomic writes via temp files, input validation at the top of every script.
- **Agent specs**: Use YAML frontmatter (`name`, `description`, `model`). Define output format precisely so downstream parsing works.
- **Orchestration**: Changes to `brainstorm-orchestrate.md` affect the entire pipeline. Test with all three complexity levels (light, standard, deep) before submitting.

## Linting

Run ShellCheck on all scripts before submitting:

```bash
shellcheck plugins/storm/scripts/*.sh
```

## Testing

Run a full brainstorm session end-to-end after making changes:

```bash
# Light mode (fastest)
/storm:start "Test topic" --light --yolo

# Verify outputs exist
ls ~/brainstorm-sessions/*/output/
```

## Pull Requests

- One feature or fix per PR
- Include a description of what changed and why
- If modifying agent specs, note which downstream agents are affected
