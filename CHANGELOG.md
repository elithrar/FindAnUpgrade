# Changelog

## 0.1.15

- Run repository-local supporting tools through `uv run --locked python -m fau_tools`; retain locked dependencies without building or installing a Python distribution.
- Keep validation active under optimized Python and restrict source archives/import stages to reviewed files; preserve deterministic quest facts and provenance.
- Remove obsolete plans, local installers, mock renderers and the docs tree; retain brief contributor guidance in AGENTS.md and machine-readable contracts under data/contracts. Historical files remain recoverable through Git.

This is a repository maintenance iteration. It does not change gameplay behavior or establish new native-client verification.
