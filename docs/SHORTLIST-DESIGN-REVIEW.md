# Shortlist and interaction design review

Independent design/interaction review of the 0.1.12 implementation, after correction of the findings below. Target: official WoW Forever interface 16001, native source contract 1.60.1.70374 / `735496de78ebd30ce816a0637982c556987f258c`. This review inspected source and executed offline fixtures; it did not run the game client or establish live visual, clipboard, or taint safety.

## Outcome

No remaining source-identifiable design blocker was found in the reviewed interaction. The corrected implementation preserves the established Options/XPIsland button, backdrop and selected-underline construction; the finder and Options use the same `UI:Tab` helper. Quests and Shortlist retain separate queries and offsets. The shortlist keeps completed, blocked, unknown and missing-source IDs visible instead of applying the quest finder filters to them. The safe slot command changes the slot and opens Quests while preserving its other filters.

The card uses measured title/body/reward extents, a shared title/tag/star reservation and stable reward top baseline. A reconstruction executing the current Lua with real Expressway glyph measurements produced example row heights of approximately 72.3, 86.3, 86.3 and 142.7 logical units. The taller mixed-reward example contains distinct guaranteed and choose-one groups; it does not add an empty fixed-height band. Private inspection artifact: `.work/design-review/current-quests.png`. Its native-art painting is approximate, and it is neither an in-game screenshot nor a pixel-acceptance test. The renderer's historical static proposed tabs were not used as implementation evidence.

Both star states reuse the same outline atlas, dimensions and hit target. The saved state now uses the full-size native gold underlay rather than the earlier deliberately inset mock fill. Identical outline layers do not prove identical final alpha contours: the native paired art has small contour differences and the underlay can add antialias pixels outside the common outline. Exact appearance and atlas UV behavior remain live checks, not an asserted pixel-level pass.

The chain popup distinguishes all-of, any-of and count-of groups, includes a required count and group size, and identifies the quest owning an ancestor group. Optional and unlock relations use their own labels. Uncertainty appears once in the expanded disclosure, without repeated "Recorded" jargon or availability paragraphs in every card. Unknown evidence never establishes a hard rejection. Native current quest/offer state retains priority over static chain gates.

Native comparison code owns equipped item choice, paired-hand legality and stat deltas. Reviewed fixtures cover both equipped ring/trinket items, hand combinations, empty slots, modifier/CVar changes, equipment and late metadata refresh, and pointer transit. They do not establish the current character's engine output or equipment in the live client.

## Findings corrected and rechecked

| Finding | Trigger and consequence before correction | Correction and recheck |
| --- | --- | --- |
| Prerequisite group semantics lost | The original `SearchViews:Chain` flattened entries. Any-of choices, threshold counts and ancestor requirements could look like separate direct prerequisites. | Group headings now show "Complete one of N", "Complete X of N" or all-of; ancestor blocks show their owning quest. A mixed threshold/alternative/ancestor fixture passed, including optional and unlock labels. Long titles cap the panel at 320 logical units and remain wheel-scrollable. |
| Copy dismissal excluded later selections | The original `Copy:KeyDown` required `selectionKnown`, cleared permanently by mouse/cursor edits until focus was reacquired. Partial selection and Ctrl+A then copy stayed open. | A valid focused platform copy chord admits intent for a nonempty field. Initial, partial and native select-all cases now retain native input and dismiss only after matching C-up and a deferred callback. Revision, generation, value, owner and focus guards cancel later changes. Windows/Mac fixture cases passed. No selection getter, direct clipboard writer, success acknowledgement or input suppression was introduced. |
| Copy popup survived navigation to Options | Gear activation left the old Copy popup and edit focus above the new Options dialog. | `Options:Toggle` closes Copy and finder transients for both gear and slash entry points. The regression test confirms the popup hides and edit focus releases. |

## Verification executed independently

Seven relevant suites passed: **99 scenarios**. These were run directly in fresh Lua 5.1/Lupa runtimes against the current checkout. Full verification, packaging and CI remain owned by the implementation workflow.

| Suite | Scenarios | Result |
| --- | ---: | --- |
| `shortlist_test.lua` | 13 | Passed |
| `shortlist_ui_test.lua` | 10 | Passed |
| `quest_chain_test.lua` | 15 | Passed |
| `copy_runtime_test.lua` | 13 | Passed |
| `sidebar_design_test.lua` | 25 | Passed |
| `reference_ui_test.lua` | 12 | Passed |
| `equipped_comparison_test.lua` | 11 | Passed |

A separate executed chain fixture combined a two-of-three group, a one-of-two group, an ancestor group, optional and unlock relations. It checked the exact resulting disclosure text, bounded height, long wrapping and positive wheel scroll. Source review also followed tab changes, scrolling, options navigation, pooled row reassignment, parent hide and deferred-copy guards through their cleanup owners.

## Reviewed runtime SHA-256

These hashes identify the settled bytes inspected at final review; later edits require appropriate re-review.

| File | SHA-256 |
| --- | --- |
| `FindAnUpgrade/Search.lua` | `e7258058fc0ad4b2bda8a97550cb2ea6e1b4ae145c6ce84eea286542dd4a8bfe` |
| `FindAnUpgrade/SearchViews.lua` | `755d0fb0cbe0160e41992eadf8e56eb7974b9b2b6d8cd5e2cdf388f0459437a0` |
| `FindAnUpgrade/UI.lua` | `457256c2d2733a7e9a1eaff14018608ac8375297519414779893a538f85812a2` |
| `FindAnUpgrade/Options.lua` | `fb1874cd9060ced8ce94e6dfc81ec45ce92cfe716c1f8240d7b68ff140205b0e` |
| `FindAnUpgrade/Copy.lua` | `8095ecada6ec448c6a385f5e464aa6d324c88feecc9925a5e3c7fb939ece3911` |
| `FindAnUpgrade/Stack.lua` | `085ada29b14998c4af315c92399c54bc925d20450be1eb49dca3a7029aee6a14` |
| `FindAnUpgrade/Shortlist.lua` | `122951b59e298f37c38e47f6bf0336e5c6908bb1c63f775524af9d7b2ecc869d` |
| `FindAnUpgrade/Chains.lua` | `66fe21448a65ffc6de283307fa732a16ab9e048a5acf807d8fed1d9909b1e437` |
| `FindAnUpgrade/Providers.lua` | `62610a2c9f36bb52c1140e1a41ddb43bafe10dd7d264ecead66784b23ccff1cc` |

## Specific live acceptance still pending

- Open Quests and Shortlist in the Forever client at default/minimum widths, enlarged fonts, fractional UI scales and a small viewport. Check native tab edges, text baselines, native star fill/outline appearance, rarity borders, long/localized titles, clipping and scrollbar reachability.
- Hover real ring/trinket and hand-slot rewards with the current character's equipped items. Check native one/two comparison frames and deltas, empty slots, remapped comparison modifier, `alwaysCompareItems`, modifier changes while hovering, equipment changes, cold loads and safe pointer transit between icon, tooltip and comparison headers.
- On Windows, verify Ctrl+C physically transfers initially selected, partial and Ctrl+A-selected text before dismissal. Repeat on Mac with Command+C. Check early modifier release, key repeat, post-intent selection changes, edits, focus changes, Escape, Enter, owner hide and reopening before the deferred callback. Offline native-handler fixtures do not establish engine input ordering or OS clipboard success. No "Copied" result is inferred from the chord.
- Check the chain popup against live quest facts and source gaps. Distinguish incomplete verified prerequisites from unknown coverage, optional breadcrumbs and chosen alternatives; static coverage remains incomplete and must not be presented as comprehensive availability.
- Exercise lifecycle and coexistence in and out of combat with native tooltips and other addons. This source/offline review found no protected-layout mutation path, but it does not establish taint safety or live addon compatibility.
