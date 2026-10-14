# Source audit: tooltip construction and reward inspection

This independent review examined installed QuestBrief **0.1.2**, commit
`721147c6311a3392f43483ec3b52f22803bf34f7`, against the actual installed reference
addons. Reference files were read only. Findings below describe that baseline;
they are not claims that a subsequent patch has already fixed them.

The reference root is
`C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns`.
Blizzard contracts target official Forever interface 16001, build
1.60.1.70374, revision `735496de78ebd30ce816a0637982c556987f258c`.
The older detail-renderer fixture is not used to infer current tooltip behavior.

## Established defects

### T1: the classification fill cannot produce the requested hues

`QuestBrief/Stack.lua:144–149` begins with native blue background RGB
`(.09,.09,.19)`. It adds at most `.09` to red for New and `.07` to green for
Modified, while preserving blue. Consequently blue remains the largest channel
even at maximum strength. A focused execution of shipped `Fill` produced these
default-strength values:

| Classification | R | G | B |
| --- | ---: | ---: | ---: |
| New | .1395 | .09 | .19 |
| Modified | .09 | .1285 | .19 |

The requested orange and green tint semantics are absent from these colors.
This is a numeric construction defect, independent of native raster appearance.
Blend toward explicit restrained orange/green fills while preserving the native
NineSlice border, inherited opacity and unchanged-quest background. Verify
actual hue relationships at the default and maximum strength, neutral behavior
at zero strength, and exact per-variant classification.

`tests/stack_layout_test.lua` currently requires only that red or green increase.
Those assertions explicitly accept the defective colors and must change.

### T2: reward quantity text bypasses the native item-count font

`Stack.lua:71` passes `10` to `text`, but that constructor's second argument is a
boolean header selector (`Stack.lua:10–15`). The number is ignored: quantity
text inherits `GameTooltipText`. The current native
`SmallItemButtonTemplate` uses `NumberFontNormalSmall` for its 30-unit icon count
(`Blizzard_ItemButton/Mainline/ItemButtonTemplate.xml:248–251`). The corresponding
shared ItemButton uses `NumberFontNormal` (`Shared/ItemButtonTemplate.xml:20–23`).

QuestBrief's 28-unit icons should inherit `NumberFontNormalSmall` directly.
The search icon count (`Search.lua:249`) should use the same constructor rather
than a generic tooltip label restyled to size 10. This is a visual construction
difference with no functionality requiring it. A focused Lua probe confirmed
the stack count's font object is `GameTooltipText`.

### T3: pipeline suppression also disables the native always-compare preference

`Stack.lua:249` correctly isolates automatic comparison processing with
`suppressAutomaticCompareItem=true`. However, `Compare` subsequently calls
`TooltipUtil.ShouldDoItemComparison` on that same object (`Stack.lua:359`).
The current native helper (`TooltipUtil.lua:3–5`) excludes `alwaysCompareItems`
when this flag is set. The private manager therefore ignores the user's native
always-compare setting unless the comparison modified-click action is held.

With `alwaysCompareItems=true`, comparison action released, and a valid active
item inspection, a focused execution of shipped Lua plus the native helper
produced **zero private comparison calls**. This is not a rendering ambiguity.
Keep global-manager suppression, but evaluate the private manager's decision
from the native preference and native `COMPAREITEMS` action without changing
the CVar, bindings, global manager or suppression flag during rendering.
Exercise both preference states, configured comparison keys, release, unrelated
tooltip ownership and pending metadata.

## Construction comparison

| Area | Actual source evidence | QuestBrief baseline | Assessment |
| --- | --- | --- | --- |
| Tooltip-shaped card | Native `SharedTooltipTemplates.xml:111–134` supplies `TooltipBackdropTemplate` / `TooltipBorderedFrameTemplate`; Lua `:234–259` forwards colors to NineSlice. | `Stack:58` creates a Frame inheriting the native bordered template, then uses its inherited `SetBackdropColor`. | Correct native border mechanism. A Frame is justified because cards require mouse-targeted child rewards and bounded stack scrolling, without GameTooltip line autosizing. No custom outer backdrop remains. |
| Native art bounds | Current `NineSliceLayouts.lua:235–246` defines `TooltipDefaultLayout`; `NineSlice.lua:85–113` anchors corners and center. | Each card occupies the ScrollFrame child at its measured height. | Default corners have no outward offsets. An alleged clipping defect from an imagined outward border was rejected; no such defect is established by these sources. |
| Fonts before measurement | Native SharedTooltip first line inherits header font, subsequent lines body font. ATCF `UI.lua:163–171` creates an owned SharedTooltip and applies its font before native text measurement. | `Stack:13` inherits `GameTooltipHeaderText` / `GameTooltipText` before setting text; no SharedMedia override. | Correct for card roles. Count exception is T2. Search/options follow their panel font role separately. |
| Card height | Questie `TooltipLayout.lua:181–190,249–280` measures rendered text and resolves width before description wrapping. XPIsland `UI.lua:67–82` measures rendered extents with effective-scale rounding. | `Stack:17–21` sets width before native `GetStringHeight`, omits empty fields, and `:169–197` computes total content/viewport height. | Real text measurement replaces fixed empty rows. 320-unit card width is an explicit accepted product requirement, unlike Questie's variable tooltip width. Bounded two-pass width change for scrollbar clearance is justified. Fractional measurement padding differs from XPIsland; card bottom padding provides slack, so clipping is not established solely from that difference. |
| Empty/unknown rewards | Installed Questie map tooltip builds rows from actual quest evidence; current native item metadata routes are explicit. | `Stack:122–141` renders positive known money/XP and verified currency/reputation rows; unavailable fields allocate no rows. | Appropriate compact policy. Pending known reward slots may show question-mark art; their unready state prevents inspection. No zero-value substitution. Native money namespace matches installed Questie `MapIconTooltip.lua:34`. |
| Guaranteed vs choices | Native quest-info treats item/currency choices separately from guaranteed rewards. | `Stack:123–137` labels both item groups when necessary and explicitly labels currencies beside choice groups. `Rewards:34–95` preserves mixed exposed indices and item-only tooltip indices. | Required quest functionality. Native selection behavior must not be inherited by these display-only icons. |
| Reward icon frame | Current Vanilla `QuestInfo.xml:29–38` uses `WhiteIconFrame`; installed Ellesmere bags use native ContainerFrameItemButtonTemplate and native quality updates (`Grid.lua:80,327`). | Plain 28-unit Button, item texture, native `WhiteIconFrame`, quality vertex color, enter/leave only (`Stack:66–95`). | Plain Button is justified: full bag/quest reward templates introduce item use, selection, drag/cursor or protected behavior irrelevant to inspection. Native border asset is correct. Count font deviation is T2. |
| Scroll navigation | Native slider has its own art/default thumb dimensions. A bare ScrollFrame alone has clipping, not navigation. | Stack/Search enable wheel, create UISlider, resize thumb to 12×22, clamp offset to content range and clear inspection on scroll. | Required stack/finder behavior. Custom compact viewport and thumb size are justified; inherited art stays native. Test the actual size/range behavior, not merely template names. |
| Position/scaling | Native source/reference cursor and owner anchors are chosen for transient tooltips; Ellesmere skin can re-anchor global tooltip through secure post-hooks (`BlizzardSkin.lua:2708–2744,3031–3045`). | Stack converts physical cursor/native rect to UIParent units, freezes source anchor, refits to content height, avoids nearby native tooltip and clamps (`Stack:153–231`). | Different anchoring is required for sticky inspection. Global GameTooltip position/visibility is never changed by Stack. Frozen native snapshots are rejected if owner, data, identity or geometry change. |
| Owned item tooltip | Installed ATCF uses `SharedTooltipTemplate`, owner tracking and owner-hide cleanup (`UI.lua:156–177`). Current SharedTooltip XML `:94–102` provides isolated hide cleanup. | Stack creates private primary and comparison GameTooltips with SharedTooltipTemplate, adds native data-handler mixin, and keeps own inspection token (`Stack:242–353`). | Correct reuse. GameTooltipTemplate is intentionally avoided because its global cleanup is incompatible with simultaneous NPC/map tooltip ownership. Native data rendering is reused rather than manually drawing item stats. |
| Comparison ownership | Native manager `:23–45` owns the supplied tooltip and its shopping tooltips; `:208–315` renders native item/delta/header data. | Stack clones manager methods into a private state owner, provides private shopping tooltips and CompareHeader, suppresses unsupported cycling instructions only while its clone adds them. | Necessary isolation; no global comparison data writes. Unsupported cycling remains deliberately absent rather than hijacking a game binding. T3 affects only preference decision, not ownership design. |
| Metadata callbacks and teardown | Native handler can call addon processors and Show while processing (`TooltipDataHandler.lua:245–306`). Native comparison may cache nil data (`TooltipComparisonManager.lua:156–167`). | Inspection generation, button row identity, open state, data ID/type are rechecked; native calls are followed by token check. Primary/comparison cold retries retain fixed deadlines; teardown clears only owned objects. | Source design correctly addresses reentrant callbacks and cold cache. Retain meaningful tests loading the actual native handler/manager and callback-triggered dismissal, not just success-shaped stubs. |
| Pointer transit | ATCF/XPIsland transient tooltip hides follow owner leave; Questie map tooltip is cursor-owned (`MapIconTooltip:83–84`). | Sticky stack, temporary corridor and owner/data-verified native transit bridges, bounded primary/compare tooltips and Escape handling (`Hover:37–66`, `Stack:399–456`). | Functional deviation required by sticky reward inspection. Deadlines are bounded; refresh preserves active deadline rather than resetting it on event floods. Resolved geometry needs stronger regression coverage. |
| Menus/focus | Modern dropdown owns generated menu and radio state; installed XPIsland/ATCF use native dropdown behavior. | Search's WowStyle1DropdownTemplate restores selected text anchors, uses native radios, a font object, bounded menus, and closes transients before scroll/rebuild/hide. | Finder filters/context actions justify these menus. Search inspector stops while a menu/copy dialog is open; focus and tooltip cleanup occur on hide. Options-specific construction is reviewed separately. |
| Installed skins | Ellesmere `BlizzardSkin.lua:563–627,1290–1308` skins GameTooltip-like frames via post-hook, remeasures shown fonts, and owns only its skin data. Its quest tracker avoids writes to shared widget pools (`QuestTracker_Skin.lua:73–79,233–237,1265–1268`). | QuestBrief cards deliberately inherit stock native font objects/borders; private item tooltip style is subject to legitimate shared-tooltip skin hooks. | Do not copy skin-specific global/font/pooled-frame mutations into QuestBrief. No dependency on installed skin settings or another addon's saved data is justified. Stock card styling and an optional independently skinned native item tooltip may differ; this follows their distinct ownership. |

## Regression quality

The baseline mock is useful for ownership, event filtering, data identity and
bounded deadlines. It is insufficient for resolved placement: `wow_mock.lua:19–25`
stores the last point but `GetRect` returns manually assigned coordinates;
`SetAllPoints` does not resolve geometry, and scrolling records only an offset.
Several stack transit tests manually assign viewport/button/tooltip coordinates.
They verify the corridor math under those coordinates, not the coordinates
produced by production anchors or scrolling. Strengthen the relevant regression
fixture with independent parent/relative-anchor/scale and viewport-intersection
semantics, or use explicit independently calculated rectangle expectations.

The baseline comparison helper stub is also success-shaped: it returns only
`W.shift` and omits the native preference/suppression behavior responsible for
T3. The actual current helper must be part of the regression contract. For T2,
assert the inherited numeric font role, not an arbitrary requested text size.

## Source identity

SHA-256 hashes of installed sources inspected read only:

| Source relative to installed AddOns root | SHA-256 |
| --- | --- |
| QuestBrief/Stack.lua | `42905d639e66a9392f9442c0fb9d40d582d9294ccfe3a85d80050c258088816e` |
| QuestBrief/Hover.lua | `05e680d0fac13b5c3dbad4393dc625f31c9a0b734bc7b03662894db8e425da83` |
| QuestBrief/Rewards.lua | `9dd3743039fd19ff335db937915565347d20db6f158a4d2d1df82ed53d4d0a32` |
| QuestBrief/Search.lua | `0b16877212e68367a1813b7ed403ef6d5e1d2bb558d5beff74ab6510921b293c` |
| AsTheCrowFlies/UI.lua | `0db47da1af7ce3ce4384ba7fe1f3ad6874454431669fd14533ae9255a1ef8aa0` |
| XPIsland/UI.lua | `fcf7f19de1f74568035ff66939c1a333bc86c80b5f76c53d9b1301ce84ca1958` |
| Questie/Modules/Tooltips/TooltipLayout.lua | `5ecfd8406dcbe521899e0ca254e583e59737da3f69ff47693db7c0c451444bfe` |
| Questie/Modules/Tooltips/MapIconTooltip.lua | `2c3735d14312b86461ff1e800d05917b6811fe804204a6bd6058270256c0ebd0` |
| EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin.lua | `3d87e7830776a0d6e60efb24ea9f8b1eca2615956b13b9a89fc29291fe804f30` |
| EllesmereUIBags/EllesmereUIBags_Grid.lua | `6586869b6fd5096039ef481ec8e6c529c6966aaa0c799fa41d4b51f8ff67a035` |
| EllesmereUIQuestTracker/EllesmereUIQuestTracker_Skin.lua | `89119a7ae8c229a7d694887210bd297ae0fdc30018a4d5525eb06d6812803468` |

Additional current native files were fetched by exact revision and hashed in
memory without altering reference installations. Paths below are relative to
`Interface/AddOns` in [the pinned Gethe source](https://github.com/Gethe/wow-ui-source/tree/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns).

| Native source | SHA-256 |
| --- | --- |
| Blizzard_SharedXML/Mainline/NineSliceLayouts.lua | `679f46d39cde6cd77df3899d41a439f8daf036a992c0e36100ddb59cf98400fe` |
| Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua | `4825bac4057b4002e630ffa7a6104add204f1164c0910e73bfe7b84ea6b31ec8` |
| Blizzard_ItemButton/Mainline/ItemButtonTemplate.xml | `5e3a14afe1c5e1a83740f3723d9e5899eebe1b75fbb90fa90fae80ab1e54dab1` |
| Blizzard_ItemButton/Shared/ItemButtonTemplate.xml | `f75d8cc8793397647e41a297786570f8ad5210119f3d6a7e597ed863cb5c59ce` |
| Blizzard_UIPanels_Game/Vanilla/QuestInfo.xml | `1c42797c9e2be4cb3924cf74af3bd9d3f66f389f5fd757edcd4cc0fb5834c07d` |

The existing current SharedTooltip/DataHandler/Comparison files were also read
from `.work/current-api`; their revision hashes are recorded in
`docs/client-contracts.json` and verified by the existing source integration
runner.

This review establishes the three code defects and the justified construction
differences above. It did not change production code, tests, installed addons,
configuration, game state or Git history. Native glyph rasterization, physical
pointer event timing and combat taint checks remain supplementary client
confirmation; they are not used to defer the source-established fixes.

## Correction re-review

The implementation owner subsequently corrected the baseline findings. This
second independent pass inspected the settled source and executed the relevant
suites; it did not edit production code or tests.

| Finding / material difference | Disposition established by revised source and checks |
| --- | --- |
| T1: incorrect tint hues | Closed. `Model.AccentFill` blends all RGB channels toward restrained orange `(.20,.14,.025)` or green `(.055,.18,.055)`. Stack and finder use the same function. Default and maximum-strength tests require the intended dominant hue; an additional independent probe verified zero strength preserves the exact native color for all classifications. |
| T2: item count font | Closed. Both views directly inherit `NumberFontNormalSmall`. The tests check the inherited font object and absence of writes to that shared object or generic panel font application. |
| T3: always-compare preference | Closed. The private manager's decision reads native `alwaysCompareItems` and `IsModifiedClick("COMPAREITEMS")` separately while keeping automatic-manager suppression. Tests load the pinned native helper to demonstrate its suppression semantics, then verify the private path honors both inputs independently without touching the global manager. |
| Full finder/copy dialog chrome | Corrected. `UI:Dialog` supplies the installed XPIsland/ATCF dialog border, opacity and fill for options, finder and copy shell. Finder result cards retain separate row styling because their content/interaction role differs from dialog chrome. |
| Vertical scrollbar artwork | Corrected. `UI:VerticalBar` copies the actual installed Questie/AceGUI dropdown pullout's bare Slider/BackdropTemplate, vertical background/border and `UI-SliderBar-Button-Vertical` pattern. Its reference is `Questie/Libs/AceGUI-3.0/widgets/AceGUIWidget-DropDown.lua:50–55,303–308`, not the separate AceGUI scroll-frame widget. The compact 12×22 thumb is a justified size adaptation. |
| Comparison header art and geometry | Corrected. Current pinned `Blizzard_GameTooltip/Mainline/GameTooltip.xml:109–126` specifies a 22-unit header, bottom-left to tooltip top-left at y=-1, `tooltip-compare-label` atlas, native body font and `NORMAL_FONT_COLOR`. The private header now follows those properties and stays one level below its tooltip. Its plain Frame remains appropriate because adopting the entire ShoppingTooltipTemplate would reintroduce unrelated native global cleanup. |
| Item-tooltip layering | Corrected. Private primary/comparison tooltips receive a level above the owning root's entire card/button subtree. The new independent fixture resolves overlapping rectangles and inherited frame levels; assertions compare effective ordering rather than requiring a particular setter call. Root-relative construction is preferable to an arbitrary global high level. |
| Native focus events | Covered. Finder range edits cancel on Escape or window hide without `OnEditFocusLost` committing unfinished input. The independent fixture actually emits focus-loss events and checks stored filter values. |

Focused suites passed in fresh Lua 5.1 runtimes:

| Suite | Passed scenarios |
| --- | ---: |
| `reference_widgets_test.lua` | 7 |
| `reference_ui_test.lua` | 12 |
| `stack_layout_test.lua` | 16 |
| `native_contract_test.lua` | 2 |
| `inspection_test.lua` | 41 |
| `search_lifecycle_test.lua` | 21 |
| Total | **99** |

`reference_ui_test.lua` now independently resolves parent/relative anchors and
effective scale, propagated visibility, actual focus loss, native dropdown
initialization and tooltip backdrop methods, slider clamping, comparison header
geometry and overlapping layer order. This meaningfully improves the source
checks identified above. It still does not apply scroll offsets to its rectangle
solver; the existing separate viewport-intersection and scroll-clamping cases
remain useful, but must not be described as resolved post-scroll geometry.

Hashes of the revised production files inspected in this correction pass:

| Revised source | SHA-256 |
| --- | --- |
| QuestBrief/Stack.lua | `80e2e7841dbe24231de27ec606bddf24eac01f464003c4e3190137f7a2479f41` |
| QuestBrief/Search.lua | `0ac26843487db9b6057471ee30c62448f38c76336b8cd632ce4d56fb794018a1` |
| QuestBrief/Model.lua | `ab0ba3770acf15d98aa2dbde1c65f768d93072915236212a6c7059a27485ba6b` |
| QuestBrief/UI.lua | `b4275dd473fd3fd1ba38006215b902d5f34322bd788d9ea45b8b80c5642536a4` |

No further concrete defect was found in these corrections. The remaining
supplementary checks concern engine rasterization, physical pointer timing and
combat taint, plus the explicitly stated scroll-offset fixture boundary; none
is a reason to defer the closed source findings or to redefine them as unknown.

### Final 0.1.3 comparison-header check

A final narrow pass inspected the native initial header width and label draw
layer, and the header's pointer-containment lifetime. `CompareHeader` now starts
at the native 100×22 size, and its label uses `ARTWORK`, matching the pinned
ShoppingTooltipTemplate. Its dimensions, plate, gold font color, -1 offset and
relative frame-level order remain correct.

`ItemContains` includes the comparison label's rectangle above the tooltip body
only while the owning comparison tooltip is visible. This keeps inspection alive
over its native label without allowing a still-shown child under a hidden tip to
retain inspection. The new test initially exposed an unrelated legacy-fixture
default: an unspecified primary tooltip rectangle covered the whole screen. The
implementation owner corrected the test with explicit primary-body bounds; no
production change was needed for that fixture issue. The resulting case isolates
the label rectangle and verifies both visible and hidden-parent behavior.

Fresh execution of the persisted test files passed **8 widget scenarios and
12 reference-UI scenarios**. No new defect was found in this narrow change.
This final pass supersedes the previous Stack hash with
`bc6303a26d62831584af0e365a1f75b9d0336199b254209f70335ce7c57d686e`.
