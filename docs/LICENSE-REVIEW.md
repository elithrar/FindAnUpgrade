# Licensing review

Reviewed 2026-10-14 against the local QuestBrief payload, the pinned XPIsland/AsTheCrowFlies references in [PROVENANCE.md](PROVENANCE.md), and the [OSI BSD-3-Clause text](https://opensource.org/license/bsd-3-clause).

## Findings and fixes

| Finding | Fix | Verification |
| --- | --- | --- |
| QuestBrief had no original-code license. | Added root `LICENSE` and shipped `QuestBrief/LICENSE`, copyright 2026 Matt Silverlock, BSD-3-Clause. | Both files must be byte-identical and contain all three conditions and the complete disclaimer. |
| The prototype notice reserved original-code rights unless separately granted, contradicting the requested BSD-3-Clause grant. | Replaced that statement with the original-code grant and an explicit third-party scope boundary. | Reviewed `QuestBrief/NOTICES.md` for contradictory claims. |
| Reused font/settings patterns needed a clear attribution scope. | Named XPIsland, retained its complete `XPISLAND-LICENSE.txt`, and identified the owner-authorized ATCF conventions without claiming a license for its whole repository. | XPIsland notice text matches the reference license after newline normalization. |
| Optional fonts/providers and game assets could be mistaken for bundled BSD components. | Named runtime dependencies, stated that their code/data/assets are not bundled, and limited the classification notice to the exact-ID factual extract. | Inspected addon inventory, TOC and package allowlist; no font, media, native source, library or provider database payload present. |

## Scope and provenance

- The root license covers original QuestBrief implementation, tests, tooling and documentation; the shipped copy keeps the grant with the installable addon.
- `QuestBrief/XPISLAND-LICENSE.txt` preserves XPIsland's original copyright, redistribution conditions and disclaimer. XPIsland remains BSD-3-Clause. Release helpers (`tools/release.py`, `tools/publish_github.py`, `tools/publish_curseforge.py`), `tests/release_test.py` and `.github/workflows/check.yml`/`release.yml` follow its release conventions with fresh implementation; the attribution covers these conventions too.
- ATCF was supplied by the same owner for convention reuse. Its font readback/fallback behavior and native UI conventions informed QuestBrief. That authorization does not establish an open-source redistribution license for ATCF; its repository, runtime payload, assets and derived flight data are excluded.
- QuestBrief references Blizzard APIs/templates/textures/fonts and optionally installed Expressway, LibSharedMedia, LibStub, Questie and QuestieDB. It bundles none of their source, font, artwork or database payloads.
- The classification payload is a normalized factual ID/status extract from user-approved evidence. Its source identity/version and exact mapping remain recorded. No broader license or rights in the original evidence or game content are asserted.
- Ignored development-only references and `.work/` may contain third-party sources or Lupa. They are excluded from source/installable archives and retain their own licenses.

## Integration validation

The package allowlist must include `QuestBrief/LICENSE`; the source archive must include the root `LICENSE`. Packaging should reject mismatched root/shipped licenses and missing XPIsland attribution. Rebuild and inspect both archives after those checks are integrated. This review does not authorize an upstream release or bundle additional third-party files.

Independent second review checked both license copies, the complete XPIsland license against its reference and the OSI text, the notice scope, and the actual payload inventory. It found no remaining contradictory grant or attribution defect.

After packaging integration, `python tests/package_test.py` passed all 6 tests and `python tools/package.py` succeeded. Archive inspection verified that both ZIPs contain `QuestBrief/LICENSE`, `QuestBrief/NOTICES.md` and `QuestBrief/XPISLAND-LICENSE.txt` byte-for-byte; the source ZIP also contains the root `LICENSE` and provenance document. The root/shipped grant SHA-256 is `b03f4b5dbfddcbc8bbc636cc238ccc7934dc34c0c60eccc055b1265f10487e5f`. The separate reviewer repeated the integrated archive checks and found no new licensing defect. Neither archive contains ignored reference/dependency directories, font files, native artwork or compiled libraries. A final rebuild is needed after concurrent implementation changes finish.

The independent history reviewer repeated the licensing review on 2026-10-14 after runtime changes. Root/shipped grants remain byte-identical and match the pinned XPIsland BSD-3-Clause text after newline normalization; the retained XPIsland notice also matches. A Python inspection of both current ZIPs confirmed all three shipped grant/notice files against their current source bytes, the root grant in the source ZIP, and exclusion of reference/dependency directories, fonts, artwork and compiled libraries. `NOTICES.md` distinguishes original-code rights, user-authorized convention reuse, optional providers, native resources and factual classification provenance. No new contradictory grant or missing attribution was found. This review makes no broader claim about rights in unbundled third-party datasets or resources.
