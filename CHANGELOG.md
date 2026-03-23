# Changelog

All notable changes to Storm will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-16

### Added
- 14-agent brainstorming pipeline: research, setup, 6 personas, pre-mortem, reframe, dedup, diversity, scorer, ranker, clusterer, synthesizer, red team, arbiter
- Three complexity levels: light (1 round), standard (2 rounds), deep (3 rounds)
- Interactive mode with 3 checkpoints for user steering
- Yolo mode for fully automated sessions
- HTML digest generation with per-round stats and agent performance
- Session state persistence with content-aware resume
- Near-duplicate detection with two-layer extraction/fallback
- Context pressure monitoring to avoid mid-session failures
- Web research phase with source tiering (Tier 0-5)

### Fixed
- Null display names normalized in session builder
- Flexible heading patterns in digest for varied LLM output formats
- Red team item regression in digest rendering
- Variable shadowing in digest script
- Explicit model parameter enforcement in all Agent tool calls
