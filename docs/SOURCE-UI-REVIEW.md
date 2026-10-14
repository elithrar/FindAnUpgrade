# QuestBrief 0.1.3 source comparison and correction

The user's accepted confidence standard is rigorous construction/lifecycle comparison with working source. Live testing is supplementary confirmation, not an implementation gate. This audit inspected installed XPIsland 0.6.3, AsTheCrowFlies, EllesmereUI/options/skins and Questie 12.1.0 read-only, plus byte-exact official Forever 1.60.1.70374 contracts at `735496de78ebd30ce816a0637982c556987f258c`. Source identities, line evidence and material differences are recorded in the three independent audits:

- [Options](SOURCE-OPTIONS-AUDIT.md): sixteen construction and lifecycle areas.
- [Tooltips](SOURCE-TOOLTIP-AUDIT.md): eighteen tooltip/reward/layout areas.
- [Native contracts and test fidelity](SOURCE-CONTRACT-AUDIT.md): actual template/mixin/menu behavior and stricter event/geometry coverage.

## Concrete repairs

| Finding in 0.1.2 | Corrected construction/behavior | Evidence |
| --- | --- | --- |
| New/Modified fill only increases red/green while native blue remains dominant at every supported strength | Shared `Model.AccentFill` blends all channels toward explicit orange/green targets; unchanged/unknown/disabled accents retain their base | Numeric hue checks at default/max strength and disabled/unknown cases |
| Reward quantities inherit body font, with an ignored numeric argument in hover | Both views inherit `NumberFontNormalSmall`, without modifying shared fonts | Native quest/embedded reward count templates and owned count tests |
| `suppressAutomaticCompareItem` also gates the user's always-compare CVar | Private comparison manager reads native `alwaysCompareItems` and `IsModifiedClick("COMPAREITEMS")` separately; automatic global manager remains suppressed | Exact pinned `TooltipUtil.ShouldDoItemComparison` distinguishes native unsuppressed behavior from the private guard |
| Vertical sliders inherit horizontal NineSlice/thumb artwork | Shared `UI:VerticalBar` follows installed Questie/AceGUI bare slider/backdrop/native vertical asset pattern | Source XML/defaults and asset assertions |
| Private comparison labels omit native plate, dimensions, offset and gold | Same native initial100x22 header, -1 seam offset, comparison atlas, ARTWORK native text and gold color; header stays below its tip | Pinned `ShoppingTooltipTemplate` and resolved header geometry |
| Private tooltip level is below nested cards/icons when screen clamping overlaps them | Private tips are above the inspector's own card/button hierarchy; comparison headers remain one level below | Native-inherited-level overlap regression |
| Native comparison header extends outside body interaction rect | Visible owned header counts as inspection geometry; hidden parent rejects it | Header-only pointer counterexample |
| Escape/close invokes focus-loss range commit and leaves a cancelled draft | Finder ranges apply on Enter; Escape and close restore both accepted texts and clear focus | Real focus-loss event sequence, accepted state plus displayed text checks |
| Repeated options failures retain new permanent content/control trees | One content parent and deterministic frame/text slots reuse the constructor high-water mark; cleanup/recovery stay atomic | Thirty early/late failed attempts, recovery and cached toggles; independent failures at six actual constructor positions |
| Finder/copy dialog shells use tooltip border instead of established dialog chrome | Options/finder/copy call shared `UI:Dialog`, exactly matching XPIsland/ATCF shell assets/colors/insets | Same shell checks across three windows |

## Differences retained for function

QuestBrief has one small settings page rather than unrelated profile/tracking pages, with a shorter shell and the existing validated settings owner. Its dropdown entries and numeric ranges are quest-specific. Native menu pooling, radio semantics, compositor font setter, keyboard/dismissal behavior and text/arrow allocation are retained. Its interactive cards require owned frames, icons and a scroll child; `TooltipBorderedFrameTemplate` reuses native NineSlice/fonts rather than pretending an interactive card is a plain text GameTooltip. Private SharedTooltip data handlers/comparison managers preserve exact native item lines without replacing the NPC/Questie tooltip or mutating global comparison state. Plain reward buttons avoid inherited item use, selection, drag and quest-acceptance behaviors. Compact card spacing, explicit guaranteed/choice groups, bounded scrolling and sticky transit serve the requested quest inspection feature. Finder result rows retain their data-grid allocations and context actions; their full window uses the established dialog shell.

These are explained adaptations, not substitute addon frameworks. No runtime dependency on Ellesmere, XPIsland or ATCF is introduced. No unrelated addon/configuration, shared font, comparison manager, existing Blizzard visibility/layout or CVar is written.

## Verification

The candidate passes **279 Lua 5.1 scenarios**, including 20 new independent/reference widget scenarios, and the required 69 Python tests (5 classification,22 catalog,11 package,31 release). The full verifier, exact-commit rebuild, main CI and installation receipts bind the final bytes independently. Existing delayed-data, stale-generation, native callback reentry, mixed-choice identity, fixed-deadline and comparison lifecycle checks remain required.

The stricter independent fixture resolves relative/local-scale anchors and SetAllPoints, models parent visibility and descendant show/hide, actual focus events, native slider clamping and relevant inherited control defaults. It executes actual pinned backdrop and native SetupMenu methods. Earlier manually positioned transit fixtures still protect session/grace/viewport intersection, but do not establish engine scroll-offset rectangle resolution. The new fixture does not claim glyph rasterization or scroll-offset modeling. Supplementary client confirmation is limited to those engine/physical-input details, live timing/coexistence of later hooks and combat/taint behavior; it is not a blanket claim that construction is unknowable from source.

## Skill provenance

Local mirror: `C:\Users\matt\Documents\Codex\2026-10-14\task\dotfiles\.agents\skills\wow-addon-development`. Its clean repository HEAD during this audit was `9a123671a6927f8c087eac09b548f4efadb8a29a`; last skill-changing commit was `4b38887ec969bbc1c97c1434732fac97ea7ff0dd` (2026-10-04). Current root SHA256: `950b6219b56234c1f1abb30bb876d704bd5fa58c9e79b09a11e532425e5df7c0`. Current reference hashes are recorded in `dist/wow-skill-source-audit.json`. This pass read the current root and UI/layout/validation/ownership guidance; earlier source work also read clients/packaging from this mirror. Prior tool records establish the earlier path/read, but did not save a contemporaneous hash receipt, so these current hashes are not retroactive certification of historical loaded bytes. The skill was not modified.
