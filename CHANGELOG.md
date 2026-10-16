# Changelog

## 0.1.15

- Tighten options spacing, including compact level-range rows, consistent section gaps and a shorter window that preserves readable controls and scrolling.
- Run repository-local supporting tools through `uv run --locked python -m fau_tools`; retain locked dependencies without building or installing a Python distribution.
- Keep validation active under optimized Python and restrict source archives/import stages to reviewed files; preserve deterministic quest facts and provenance.
- Remove obsolete plans, local installers, mock renderers and historical receipts; retain brief contributor guidance in AGENTS.md and only the native source pins exercised by tests. Generate diagnostic reports under ignored dist paths.

This iteration changes repository tooling and options spacing. It does not establish new live-client verification.
