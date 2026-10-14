# Independent finder UI review

Initial independent review performed 2026-10-14 against implementation HEAD `75e88b03b6e8e97500af5ccbd3e7d28ea3424235`. That pass edited only this document and ignored probe code. A subsequently delegated correction pass modified finder UI functions in `QuestBrief/Search.lua` and UI cases in `tests/search_test.lua`; it did not edit installed addons, reference addons or catalogue data. Correction evidence below describes the current uncommitted integration and is not an independent re-review of the author's own fixes.

## Evidence and boundary

Read `AGENTS.md`, the user's wow-addon-development skill and its UI/settings, layout and validation references, the shipped TOC and affected UI/model modules. Inspected the actual installed `XPIsland/Options.lua`, `AsTheCrowFlies/Options.lua` and `AsTheCrowFlies/UI.lua` read-only under `_classic_beta_/Interface/AddOns/`. No earlier review's conclusions were used as evidence.

Current native contract inspection uses Gethe/wow-ui-source revision `735496de78ebd30ce816a0637982c556987f258c`, Forever 1.60.1.70374 / interface 16001. The older detail-renderer fixture was not substituted for these menu contracts. Relevant primary sources are the [Classic dropdown XML](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Menu/Classic/MenuTemplates.xml), [dropdown implementation](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Menu/DropdownButton.lua), [menu templates](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Menu/MenuTemplates.lua), and [compositor](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Menu/Compositor.lua).

Initial independent Lua 5.1 probes execute the shipped implementation with new fixtures, using the common API mock only as scaffolding. They inject the native dropdown's inherited TOP anchors / 10-unit text height and reject direct compositor FontString `SetFont`. The probe is `.work/fresh-ui-review/probe.py`; results are `dist/fresh-ui-review-probes.json`, which records the original defects before correction. This establishes declared geometry and Lua state, not native rendered pixels, physical input, event timing, combat or taint safety. Native UI automation was unavailable.

## Findings requiring correction

### UI-1 — P2: Recorded alternate quest givers have no selection or inspection path

**Location:** `QuestBrief/Search.lua:185` and `QuestBrief/Catalog.lua:51`.

**Trigger:** A result has multiple recorded locations. The shipped catalogue has **21** such quests, with up to **9** locations; examples include quest IDs 415, 6602, 7930 and 7931.

**Evidence:** `Catalog:Locations` retains every entry; `Catalog:Location` returns one current-map or first entry. `Search:Fill` reads `self.locationChoice[row.id]`, but no finder interaction assigns it. The right-click menu uses only `row.location`, and reward expansion exposes only additional items. The independent two-giver fixture returns two locations with an empty choice state. The README promises expanded recorded givers, which the UI does not implement.

**Consequence:** Users cannot inspect alternate NPCs or choose their coordinates for copy/waypoint actions. A default unavailable/phased location can also hide a useful alternate.

**Required outcome:** Expose a compact, discoverable native giver/location choice when multiple entries exist; selected giver, location label and context actions must agree. Keep unknown coordinates and phase conflicts explicit. One-location cards should keep their compact layout.

### UI-2 — P2: Bottom scrolling loses its destination when unseen card heights grow

**Location:** `QuestBrief/Search.lua:150`, `QuestBrief/Search.lua:216`, `QuestBrief/Search.lua:228`, `QuestBrief/Search.lua:232`.

**Trigger:** Render results at width 560, expand a card, narrow to width 520, then drag the scrollbar to its bottom. Four rewards become two rows at the narrower width, increasing the heights of previously unseen cards.

**Evidence:** A fresh twelve-result fixture with eight choices per quest starts with 105-unit compact cards and 149-unit expanded cards. After narrowing to 520 × 400, scrolling to the current maximum yields **offset 1287**, then visible-card measurement increases the maximum to **1353**. The final **66 units** remain below the viewport. `LayoutResults` clamps excessive offsets downward but does not retain bottom intent when the range grows. No native pixel measurement is implied by these source-coordinate numbers.

**Consequence:** The scrollbar moves away from its bottom and the final card remains incomplete after a bottom drag; users must scroll again as newly measured geometry changes the range.

**Required outcome:** Resolve row heights for the active width before final scroll-range application, or preserve the user's bottom target after measurement settles. Recheck collapse/expand and width changes in both directions, including last-card footer reachability.

### UI-3 — P2: A truncated quest title has no full-text view

**Location:** `QuestBrief/Search.lua:182`.

**Trigger:** A native/localized quest title exceeds the single-line allocation. The default title allocation is 367 units, falling to 327 at minimum width; the allocation also reserves 155 units even when the status tag is empty.

**Evidence:** Titles use `SetWordWrap(false)` and fixed width. They have no tooltip/full-title handler, expansion adds only rewards, and context actions offer ID / NPC / coordinates / URL but no title. The independent long-title fixture confirms no full-text handler. The longest recorded English title is 55 characters; actual font and locale clipping thresholds remain a native check.

**Consequence:** Distinguishing words at the end of a long title cannot be read within the finder. An external Wowhead page is unnecessary friction for basic identification.

**Required outcome:** Provide full quest text on hover or in a compact details/menu path, without shrinking the chosen font. Verify readable reward names and the combined giver/zone line with long labels at minimum/default width.

### UI-4 — P2: Disabled location actions do not explain their conditions

**Location:** `QuestBrief/Search.lua:254`–`257`.

**Trigger:** The location is missing coordinates, phase-conflicted, or the native map cannot accept a user waypoint.

**Evidence:** The entries are correctly disabled, but only the Wowhead entry has a tooltip. The independent phased-location fixture has a disabled waypoint and no explanation. `Catalog:Locations` preserves phase/mobile/conflict information, but the card does not expose that reason.

**Consequence:** Users see a grey action with no indication whether a coordinate, map capability, or availability restriction caused it. This also makes alternate-giver selection less discoverable when one candidate is unusable.

**Required outcome:** Add concise condition-specific native menu tooltips or equivalent adjacent state text for disabled waypoint/coordinate/NPC actions. Keep the action disabled unless the existing contract permits it.

## Checks with no source/state defect found

- The initial window is 560 × 600, dark with a gold `QuestBrief` title, full-width search, checked class-usability filter, native player-level −5/+3 defaults, 17 slot choices (including empty slots and weapon families), result count and Level fit / Quest level sort.
- The default 522-unit card width supplies four 28-unit reward icons per row, 90.5-unit single-line name allocations and 105-unit compact cards. Four complete compact cards fit within the 442-unit default results viewport in the independent fixture.
- Expansion exposes all eight fixture rewards; the rows and footer remain separated at default and minimum width. Money/currency, XP and reputation footer anchors share a baseline, and full footer values have tooltip hit regions.
- Dropdown text clears the inherited Classic TOP anchors, then uses one LEFT anchor, 113 × 24 allocation and middle vertical justification. This matches installed XPIsland/ATCF conventions and avoids the inherited ten-unit height trap. In-menu rows use the owned Font object through `SetFontObject`, which the current compositor permits; direct `SetFont` is not used on compositor-owned text.
- Fonts check optional registered Expressway and native-path readback before falling back. Shared Blizzard Font objects are not modified. The finder applies its own font state to labels and controls.
- Native menus are associated with invoking owners and are closed before refresh, scroll, resize, drag and hide. Copy uses a native edit box, selects its text, and dismisses on Enter/Escape. The fixture confirmed copy show and Escape dismissal.
- Resize has a visible corner handle and supported bounds; wheel/slider navigation is present. Hidden search tears down its update handler and owned tooltip/menu state. The separate minimap launcher has minimap-relative placement, effective-scale cursor conversion and saved visibility/angle, with slash-command recovery separate from quest-marker previews.

## Pending native validation

On official Forever 1.60.1.70374, inspect reference and finder pixels with native fallback and registered Expressway at default/minimum/maximum sizes, fractional UI scale and small/large displays. Verify long/localized titles, item names, givers, zones, multi-location choices, checkbox labels, dropdown selections/arrows and open-menu disabled states without clipping or overlap. Check first open/reopen, text focus, physical dropdown/scroll/resize input, expansion near the bottom, complete last-card footers, native full item tooltips and Shift comparisons, context-menu ownership, copy dismissal and launcher drag-release/reload/hide/recover. Repeat in combat with native quest panels and Questie coexistence; offline evidence does not establish taint safety.

## Re-review status

Initial review: **changes required** for UI-1 through UI-4. The delegated correction pass implemented:

| Finding | Correction and focused regression evidence |
| --- | --- |
| UI-1 | A compact location-count control opens native radio choices, and the card context menu offers the same choices in a submenu. Selecting another recorded location updates the card's zone/name/coordinates and both waypoint and copy targets. Tests choose a second giver on another map and verify the actual selected map/coordinates/NPC copy text; single-location cards keep their full location allocation. Labels read `<n> locations` and `Choose location`, because entries can contain multiple coordinates for one NPC (for example, quest 96875). |
| UI-2 | A bottom-target state survives range growth and is cleared by deliberate upward scrolling or filter reset. Rendering settles geometry in at most four passes, recomputes layout after every changed pass, then reconciles final existing-card anchors and queues a later settling refresh if more rows are revealed. Tests cover width 560 → 520, bottom scrolling, expansion/collapse, resizing back to 560, mixed old heights that require a newly visible third-pass row, and final positions/child height/range/scroll/slider coherence when the pass limit is reached. |
| UI-3 | Owned full-text tooltips expose the complete quest title and combined giver/zone/coordinates line. Hit regions respect the scroll viewport, menu and copy-dialog gates. Tests cover long distinguishing title suffixes, viewport rejection, menu exclusion, leave/hide cleanup and pooled-card refresh cleanup. |
| UI-4 | Disabled location actions expose condition-specific native menu tooltips for missing recorded coordinates, phase/conflict restrictions, unsupported native waypoint maps and missing NPC names. The root integration preserves `location.nameKnown`, and Copy NPC name requires it to be true; fabricated fallback labels cannot be copied as a known name. Tests cover each disabled reason and the explicit missing-name guard. |

Executed the entire `tests/search_test.lua` in Lua 5.1 via Lupa: **45 scenarios passed**, including seven focused UI regressions. The installed-reference and current native menu source checks remain applicable; no direct compositor `SetFont` was added. Scheduler integration uses the root-owned `DataChanged`, reward queue and `Wake` paths, including owned-menu release and item entry. Pooled-card rendering closes owned full-text/footer tooltips before moving or reusing rows.

The corrections are **implemented and covered by focused offline regressions; fresh independent cross-review is pending**. The root workflow owns the complete `python tools/verify.py` run and package evidence. Native pixels, physical input, tooltips/comparisons, event timing and combat/taint checks remain pending as listed above; no native validation is claimed.
