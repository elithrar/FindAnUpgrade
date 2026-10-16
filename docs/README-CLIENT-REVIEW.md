# README and Forever 70425 review

Independent source and offline review on 2026-10-16 of the 0.1.14 candidate's README rewrite, current client contracts and exact local-update build guard. Read the current AGENTS.md and installed wow-addon-development client/source, packaging and validation guidance. This review changed only this report and ran no installer or write outside the workspace.

## Result

No unresolved P1 or P2 finding remains in the reviewed change. The README follows the inspected current XPIsland download-first structure and concise tone, both README copies match, and the exact 70425 source/installer transition is internally consistent. This is not evidence of native in-game acceptance or public release availability.

## README comparison and resolved finding

Compared the actual supplied current XPIsland README bytes, Git blob `fe131a5a25e23659435fb6cf1d8617aeaa509958`, rather than reconstructing its style from memory. The revised FindAnUpgrade README has a download link directly below the title, a one-sentence description, five short feature bullets, then Installation, Contributing, Development and License. Usage and essential settings are short paragraphs under Installation, matching the reference's organization. The reference's screenshot gallery is omitted; no new screenshot assets were requested or fabricated. Version text, migration history, release-state prose and implementation caveats are absent. Commands, shortlist, native item comparisons, Shift inspection, alternate keys and Questie's minimap role agree with the implementation.

The download destination is exactly the user-specified `https://www.curseforge.com/wow/addons/findanupgrade`. Its availability is assumed under the user's instruction; this review did not verify or claim that a public file exists.

**Small documentation finding, fixed:** the initial identical README copies used three relative `docs/...` development links. Those worked in the repository root but broke in the addon-subfolder view and shipped payload, which contains no docs subtree. Both copies now use the same absolute repository URLs for DEVELOPMENT.md, DATABASE-SYNC.md and VALIDATION.md. Rechecked their exact targets and local source-file existence. The local LICENSE link resolves in both locations, and third-party attribution points to the repository NOTICES file.

Both README files are byte-identical. TOC and runtime version are both 0.1.14; interface 16001 and the existing saved-data identifiers, including the legacy QuestBriefDB migration name, are preserved.

## Client contract comparison

- Independently read only the installed WowB.exe FileVersion and the selected `.build.info` product/version fields. Both report `wow_classic_beta` / 1.60.1.70425. These are installed metadata observations, not a running GetBuildInfo result.
- Verified SHA-256 and Git blob SHA-1 identities for all 17 owned 70425 source files against the private acquisition receipt. Verified every corresponding old-file SHA and each changed/unchanged flag. The current cache's 13 snapshot members exactly match `docs/client-contracts.json`.
- The recorded current revision is `b401e0332adfbf0460d319b06d8ea29279a941f1`; its owned version.txt is exactly 1.60.1.70425. The previous-current snapshot is identical to the pre-change 70374 snapshot in HEAD. The baseline 70338 revision and its complete file list are unchanged.
- Within the current 13-file snapshot, only version.txt, DropdownButton.lua and GameTooltip.xml changed. Inspected the actual diffs: DropdownButton adds HasOnlyRadioDescriptions, leaving the used menu/input constructors unchanged; GameTooltip.xml adds an update script to BuffFrameTooltip, outside this addon's private tooltip templates. Quest-log/reward/currency documentation, map providers, comparison manager and shared tooltip handler/templates/utilities retain their exact prior bytes.
- Inspected the four additional source diffs. QuestFrame changes gamepad footer refresh and cursor ordering, while the detail renderer hooks remain unchanged. QuestFrameTemplates.xml is byte-identical. Auction-house shared templates add sample-link tooltip handling; the favorite atlas-state swap used by the addon is unchanged. Input documentation adds cursor-center and visibility getters, without changing the modifier/copy-key contracts used here.

Receipt checks establish owned source-byte identity. The matching source acquisition was performed by the delivery worker; this review did not independently fetch a new remote snapshot. The historical 70338 detail-renderer integration remains an explicit baseline, not a claim that its whole QuestFrame implementation is the current client.

## Installer guard review

Parsed tools/update_local.ps1 through the PowerShell AST parser without executing it. The script parses successfully, and its only diff from HEAD is the exact accepted FileVersion changing from 1.60.1.70374 to 1.60.1.70425. It still rejects every other build. The closed-client check and build check precede the first filesystem mutation, Expand-Archive at line 43. Existing resolved-path bounds, verified prior payload, exact-source/package receipts, increasing addon version, staging, backup, rollback and unrelated addon/settings preservation checks are unchanged. The historical one-time migration installer was not modified or invoked by this review. A successful source review does not establish that a later installation completed.

## Fresh offline checks

Ran six suites in fresh Lua 5.1 runtimes through the locked uv environment on Python 3.15.0, using the new current fixtures:

| Suite | Scenarios |
| --- | ---: |
| native_contract_test.lua | 2 |
| reference_ui_test.lua | 13 |
| reference_widgets_test.lua | 8 |
| native_tooltip_test.lua | 35 |
| copy_runtime_test.lua | 13 |
| shortlist_ui_test.lua | 10 |
| Total | 81 |

Also checked all source receipt hashes, preserved snapshot/baseline identity, actual installed build metadata, exact installer-only diff and AST parse, README equality/section order/link targets, matching version/interface and preserved saved-data declarations. git diff --check passed. Full lint/data/package/release verification and final exact-build delivery belong to the root workflow.

## Remaining live limits

No game was launched. Native rendering, physical keyboard/mouse/gamepad event ordering, clipboard completion, combat/taint and addon coexistence remain unobserved. The source comparisons and offline fixtures do not establish these outcomes. No installer, CurseForge/GitHub release operation, remote setting change or secret-value read occurred in this review. Public CurseForge availability remains the user's stated assumption.

## Reviewed file identity

SHA-256 uses bytes with CRLF normalized to LF, matching repository normalization. Changes after this review require checking the affected conclusions again.

| File | SHA-256 (LF) |
| --- | --- |
| `README.md` | `dfdba8bb3355a2bd71c276064e23b13502a63a34491038b0673ba0c18eb8db78` |
| `FindAnUpgrade/README.md` | `dfdba8bb3355a2bd71c276064e23b13502a63a34491038b0673ba0c18eb8db78` |
| `FindAnUpgrade/Core.lua` | `f0ff2da201b64f160b8ca66bba35480566f163c671e1328a1883474a05dda575` |
| `FindAnUpgrade/FindAnUpgrade.toc` | `b4649bb7f172620814d3048ed51bcd3d8fdbeda0c1021f754873390ed8ca9f48` |
| `docs/client-contracts.json` | `8acfd450e8be464ca7deca8c807296a9333268fc4bbd114d4936ed0a2af4453e` |
| `docs/CLIENT-70425-REVIEW.md` | `9a0217b687e1a4a783e80dd3111c08e1a785b8c552dfa07619a1242205de7326` |
| `tools/update_local.ps1` | `cc984a78fe872b2f5b17dad7ebcc0ad97d05d82519d118aa7efbf8984a6331f1` |
