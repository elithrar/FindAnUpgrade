# Shortlist implementation review

Independent adversarial implementation/data review of the approved next-feature patch. Reviewed on 2026-10-15 against official Forever interface 16001, with current source contracts pinned to Gethe/wow-ui-source `735496de78ebd30ce816a0637982c556987f258c` (1.60.1.70374). This review changed only this report.

## Result

No unresolved P1 or P2 implementation findings remain in the reviewed files. This is source inspection and offline execution, not a live-client rendering, clipboard, combat/taint, or performance certification. The final repository verification, CI, archive identity and installation checks belong to the release workflow.

## Findings and resolution

1. **P2, fixed: optional breadcrumb shown as mandatory.** The original imported fallback for quest 2519 instructed completion of 98391 while also marking the same exact quest optional; 99047/99046 and 99159/99158 had the same issue. `tools/quest_chains.py:133` now gives exact verified optional relations precedence over weaker ATT mandatory links. Eleven fallback groups were overridden. Every overridden original group and exact ID remains in evidence. Mixed all-groups retain unaffected members; affected any/count groups retain other links as unverified related facts without inventing a new threshold. `FindAnUpgrade/Chains.lua:116` also prevents disclosure of an ancestor as its own dependency or relation. Actual shipped-data popup regressions for all three examples now contain optional entries, no mandatory group, and no current-owner return row.

2. **P2, fixed: selected-subrange copy did not dismiss.** The initial copy code admitted only its original all-text selection, so mouse-selected subranges copied natively but stayed open. `FindAnUpgrade/Copy.lua:25` now accepts a recognized focused platform copy gesture independently of how selection was made. Generation, revision, owner, visibility, focus and exact text guards remain. Changes after the copy intent cancel the pending dismissal. The native key handlers remain additive hooks; no clipboard writer, input swallowing, keyboard binding or success acknowledgement is introduced. Windows Ctrl+C and Mac Command+C partial selections and select-all transitions pass the modeled lifecycle checks.

3. **P2, fixed: Windows newline-dependent receipts.** The new chain tool initially wrote JSON through platform-translating text output, so CRLF-to-LF Git normalization could invalidate the frozen input hashes on CI. Its owned JSON outputs now use explicit UTF-8 byte writes. Re-review confirmed LF-only tool/data/generated Lua bytes, all frozen input receipts, the ATT metadata receipt, exact chain rebuilding, complete source/reconciliation regeneration, and exact generated Lua bytes.

Related fixes inspected during re-review: single-alternative prerequisite groups require a listed completion rather than borrowing exclusive paths; grouped prerequisites retain the provider's documented substitution semantics and literal negative-ID exception. Timed-out comparisons reject incomplete button/row ownership before dereference. Unrelated item-load events do not restart a warm comparison or extend cold retry deadlines.

## Checks performed

- Five focused Lua 5.1 suites passed: quest chains 15, copy runtime 13, equipped comparisons 11, shortlist persistence 13, shortlist UI 10; 62 scenarios total. Re-ran the comparison suite after its final early-return guard change.
- All 11 Python chain importer tests passed.
- Independently rebuilt the chain document from the pinned owned cache and compared it exactly with tracked `data/catalog-chain-records.json` after regeneration. After the canonical-write fix, verified every frozen input receipt, the referenced ATT metadata receipt, LF-only owned outputs, regenerated complete source/reconciliation, and byte-exact generated `Data/Catalog.lua`.
- Independently exercised mixed optional/all and optional/count fixtures. Original evidence survived, unaffected mandatory members remained, and invalidated thresholds were not replaced with guessed numbers.
- Exercised actual generated catalog popups for 2519, 99047 and 99159. The optional/mandatory contradiction and owner-cycle repetition are absent.
- Exercised every one of the 247 verified prerequisite rows with all required quests explicitly incomplete: all correctly returned blocked. No cycle exists in the current verified prerequisite graph. All current verified group and relation targets are published exact catalog IDs.
- Compared the complete catalog with HEAD after removing only the new `chain` field: existing facts were unchanged. The primary classification authority was unchanged from HEAD.
- Reviewed all/any/count, optional breadcrumbs, exclusivity, supersession, parent-active and quest-window semantics; native current log/gossip precedence; unknown completion/repeatability; future saved schema protection; malformed and oversized shortlist recovery; source receipts; cache acquisition; staged sync replacement; and absence of a Questie runtime dependency for bundled chain data.

The final chain import contains 3,694 records across 5,672 catalog quests, 247 verified prerequisite groups, 767 verified relations, and three explicit malformed/self-reference omissions. The other relationships remain unverified disclosure. These are pinned source facts, not a complete server dependency graph or live availability proof.

## Remaining live checks

- Windows physical Ctrl+C and Mac physical Command+C must copy the native selected text before deferred dismissal; Lua/native-source fixtures cannot establish C++ event order or OS clipboard success.
- Native equipped pair selection, hand legality, headers and stat deltas are owned by the engine. Tests execute the pinned comparison manager against synthetic native responses; they do not observe a player's current gear.
- Verify actual client typography, atlas outlines, row/tooltip geometry, clipping, pointer transit and fractional scale. The same outline layer and target are reused for both star states; layer-size checks do not prove pixel-identical native contours.
- Confirm combat/taint safety and coexistence with other addons in the actual supported client. No game session was launched by this review.

## Reviewed file identity

SHA-256 below is computed over each file's UTF-8 bytes with CRLF normalized to LF, matching Git's repository normalization. Changes to these files after this review require checking the affected conclusion again.

| File | SHA-256 (LF) |
| --- | --- |
| `FindAnUpgrade/Chains.lua` | `66fe21448a65ffc6de283307fa732a16ab9e048a5acf807d8fed1d9909b1e437` |
| `FindAnUpgrade/Copy.lua` | `8095ecada6ec448c6a385f5e464aa6d324c88feecc9925a5e3c7fb939ece3911` |
| `FindAnUpgrade/Providers.lua` | `62610a2c9f36bb52c1140e1a41ddb43bafe10dd7d264ecead66784b23ccff1cc` |
| `FindAnUpgrade/Shortlist.lua` | `122951b59e298f37c38e47f6bf0336e5c6908bb1c63f775524af9d7b2ecc869d` |
| `FindAnUpgrade/SearchViews.lua` | `755d0fb0cbe0160e41992eadf8e56eb7974b9b2b6d8cd5e2cdf388f0459437a0` |
| `FindAnUpgrade/Search.lua` | `e7258058fc0ad4b2bda8a97550cb2ea6e1b4ae145c6ce84eea286542dd4a8bfe` |
| `FindAnUpgrade/Stack.lua` | `085ada29b14998c4af315c92399c54bc925d20450be1eb49dca3a7029aee6a14` |
| `FindAnUpgrade/UI.lua` | `457256c2d2733a7e9a1eaff14018608ac8375297519414779893a538f85812a2` |
| `tools/quest_chains.py` | `2a494042c3ba360a86054b11e8c4fc012b3464b071043b4debfe114b6eabf398` |
| `tools/questie_metadata.py` | `d893462ae3e3f60eb5b7572986371e551ca50392fa36309908c3cb709ebf88e5` |
| `tools/complete_catalog.py` | `218761dd4c6bf87efa28c05503fda3c8e042d6014e074d1f793346ea67c94938` |
| `tools/import_complete_catalog.py` | `b193948d6712653ce4328ae24b0b6f78a48436e9f16d8d2228e43bfec5ae2909` |
| `tools/sync_catalog.py` | `c239087c7685cd895addcdad0dfaa0b1d5a6ed47405b4747a0fa1c60001120bc` |
| `data/catalog-chain-records.json` | `d6d5140c60b2d8e28dbb34c1ef8428403005e7b6ae41d36af48dd18ac92b0df6` |
| `FindAnUpgrade/Data/Catalog.lua` | `147fde8ef8d7881b5f53d069db15c9f1d25adb40d574a03ae4ddc3c77cff3a1f` |
