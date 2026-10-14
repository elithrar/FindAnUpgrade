# Reward finder UX review

Independent source and Lua 5.1 mock review of `Search.lua`, `SearchModel.lua`,
`Launcher.lua` and the reused `Stack.lua` inspector. The approved reference is
the 560 x 600 QuestBrief finder with XPIsland-style dark chrome, native menus,
class-usable filtering enabled, a player-level -5/+3 range, slot filters,
compact reward cards, 28-unit item icons and aligned reward summaries.

This is **not live verification**. The review read XPIsland and ATCF's settings
constructors and the user's WoW addon development UI/layout guidance. Native
contracts were checked at Forever 1.60.1.70374, Gethe/wow-ui-source revision
`735496de78ebd30ce816a0637982c556987f258c`.

## Findings and re-review

The implementation owner applied the runtime fixes. This reviewer did not edit
runtime modules. Each corrected path was then checked independently.

| Finding | Trigger and consequence | Correction and re-review |
| --- | --- | --- |
| Eager dropdown generation reached an unconstructed inspector | Native `DropdownButtonMixin:SetupMenu` can generate a shown child's menu immediately. The initial generator accessed `self.inspector` before `Create` assigned it, raising a Lua error. The original mock only stored the callback. | Guard the inspector in the generator. An independent eager-generation surrogate now constructs both native-style descriptions without error. |
| Four default cards did not fit | A 600-unit window reserves 158 units outside its results, leaving 442. The initial 116-unit cards plus gaps required 479 units for four complete cards. | Compact default cards now measure 105 units. Four cards plus three gaps require 435, fitting the 442-unit viewport. Expanded cards and narrow resized layouts remain scrollable. |
| Native reward promotion bypassed the selected slot | A Head-filtered result with native helmet and boots rewards displayed both, although its recorded item set had already been filtered. | Native guaranteed/choice entries are now restricted to the matching item-ID set. The independent fixture displays helmet ID 123 and excludes boots ID 125. |
| Dropdowns remained open during owner interaction | `CloseMenu` initially closed only the context menu. Native dropdown owners remain visible during a drag or resize, so the native manager's hidden-owner cleanup does not close them. | Finder cleanup now calls both dropdowns' public `CloseMenu` methods. Independent spies verify both calls. Existing native scripts and menu callbacks remain intact. |
| Resize left a stale screen-fit scale | At an 800 x 600 viewport, initial fitting produced scale .96. A size change to 900 x 900 retained .96, creating an 864-unit footprint. | `OnSizeChanged` refits before requesting results layout. The independent size-change probe now gives .64 and a 576-unit footprint, preserving the 24-unit screen allowance. Physical resize gestures remain a live check. |
| Footer cleanup used a global tooltip lifecycle | The initial text-only footer tooltip inherited `GameTooltipTemplate`. Its native hide path unconditionally hides the global `BattlePetTooltip`, beyond the finder's owned text. | Use `SharedTooltipTemplate`, matching the launcher and isolated item-inspector approach. Current source confirms the owned footer uses that template. |
| Collapsing an expanded card left the list overscrolled | At the bottom of ten distinct quest rows, collapsing the last reward-heavy card reduced the maximum from 812 to 724 while the old offset stayed 812. | Recomputed layout clamps the offset and synchronizes the scroll frame and bar. The independent collapse probe now reports offset 724, maximum 724. |
| A drag without a sampled angle also opened the finder | Drag start, drag stop and release click can occur before an `OnUpdate` sample. Click suppression was initially assigned only when a new angle existed. | Every completed drag now suppresses its release click; saving remains conditional on a readable angle and writable settings. The independent no-update sequence leaves the finder closed. |

The native Classic dropdown inherits right-justified selection text. The finder
now explicitly uses left justification, removes its inherited top anchors,
centers the 12-unit font in the 24-unit control and reserves arrow clearance,
following XPIsland's constructor. Menu rows receive an owned Font object through
the supported `SetFontObject` method; compositor-owned fonts are not rewritten.

## Reviewed behavior

- The window title is only **QuestBrief**; default size is 560 x 600, with a
  full-width search field, restrained native controls and a dedicated title drag
  region. The bounded resize control closes transient inspection state.
- Class usability defaults on. Default quest range is current player level -5/+3,
  clamped at level one, and follows level changes until manually edited. Slot
  entries include weapons, off hand, ranged, robes/chest and empty slots.
- Four ordinary compact cards fit at the default width. Reward icons are 28
  units; item names retain their full source strings, with native item tooltips
  available on ready exact-ID icons. Guaranteed and choose-one membership is
  separate from recorded membership.
- Footer columns share one baseline. Exact or unavailable values remain separate;
  footer hover surfaces expose the complete values when a column is truncated.
- Context menus, dropdown interaction, scrolling, resize, filter changes and hide
  clear item/comparison state. Copy actions use an owned highlighted edit box.
  The finder removes its update script when hidden; drag update work belongs only
  to the active launcher drag.
- Item inspection uses addon-owned tooltip names and an isolated comparison
  manager. Shift comparison is reconciled while inspecting, including when a
  modifier event was missed. Cold or mismatched item data fails safely.

The changing catalogue provider was intentionally outside this UX pass.
Catalogue coverage, actual quest availability, class-usability completeness,
navigation facts and licence provenance require their separate data/API review.
Unknown usability is explicitly unconfirmed; the checkbox is not evidence that
every pending item is class-usable.

## Evidence and pending client checks

The ignored independent probe is `.work/ui-review/search_probe.py`. It executes
production modules under Lua 5.1 using the existing native API mock and isolated
catalogue fixtures, adds eager menu generation, and fails on the seven numeric or
lifecycle invariants above. Native-source evidence includes:

- [DropdownButton.lua](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Menu/DropdownButton.lua): eager generation and public menu ownership.
- [Classic menu templates](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Menu/Classic/MenuTemplates.xml): inherited selection anchors, height and justification.
- [Menu.lua](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Menu/Menu.lua): hidden-owner menu cleanup and native Escape handling.
- [GameTooltip.lua](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua): global battle-pet cleanup in the generic game-tooltip lifecycle.

Pending in the official Forever client: inspect pixels at default/fractional UI
scales and small screens; confirm long item/quest names and dropdown arrows;
exercise wheel/bar scrolling, card expansion and actual resize gestures; check
Escape with a dropdown, context menu and copy dialog; test pointer transit into
native comparison tooltips; verify minimap click/drag release order; and check
combat transitions, taint logs, native tooltip coexistence, XPIsland and ATCF.
No client installation, merge or release was performed for this review.
