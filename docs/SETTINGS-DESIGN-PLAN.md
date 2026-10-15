# Settings design plan

This plan covers Matt's requested font, border, scale and search-default preferences. It preserves the current search design and uses the installed XPIsland and AsTheCrowFlies constructors as source references. It is a source/design plan; it does not establish native rendering or input acceptance.

## Working references

- Installed `XPIsland/Options.lua:71Ã¢â‚¬â€œ104`: native `DropdownButton` / `WowStyle1DropdownTemplate`, 24-unit height, selection text anchored `LEFT` at 9 units, arrow clearance 31 units, native radio rows, 220-unit scroll limit and an owned menu Font object applied with `SetFontObject`.
- Installed `XPIsland/Options.lua:164Ã¢â‚¬â€œ215`: 620-unit dialog, 16-unit outside sections, two 288-unit columns at x=16 and x=316, content x=28 and x=328, gold 12-unit section titles, 12-unit controls, 16-unit dialog heading; font preferences include Game tooltip, Arial, Friz Quadrata and registered SharedMedia names.
- Installed `XPIsland/UI.lua:172Ã¢â‚¬â€œ188`: requested font is checked before applying it, an unavailable preference uses the runtime game-tooltip family, and the saved preference remains available for a later registration.
- Installed `XPIsland/Options.lua:339Ã¢â‚¬â€œ371` and `AsTheCrowFlies/UI.lua:84Ã¢â‚¬â€œ100`: refresh native menu descriptions for actual selection/font/list changes, rather than rebuilding open menus during unrelated layout updates.
- Installed `AsTheCrowFlies/Settings.lua:20Ã¢â‚¬â€œ39`: finite numeric validation, field-level repair, bounded font names and explicit future-schema protection.

## Schema and ownership

Advance the saved schema from 3 to 4. Add:

| Field | Default | Accepted values |
| --- | --- | --- |
| `font` | `Game tooltip` | Nonempty media name, at most 128 bytes, no control characters or WoW markup pipes. Built-ins: Game tooltip, Arial, Friz Quadrata. |
| `border` | `default` | `default`, `none`, `tooltip`, `dialog`, `thin` |
| `searchDefaults.hideUnusable` | `true` | Boolean, preserving explicit false. |
| `searchDefaults.levelsBelow` | `5` | Integer 0Ã¢â‚¬â€œ199; finite inputs clamp and round down. |
| `searchDefaults.levelsAbove` | `3` | Integer 0Ã¢â‚¬â€œ199; finite inputs clamp and round down. |
| `searchDefaults.includeDungeons` | `false` | Boolean, preserving explicit false. |

Keep existing `scale` at 0.8Ã¢â‚¬â€œ1.2, displayed as 80Ã¢â‚¬â€œ120%, and all current valid preferences. Copy nested defaults independently. Loading old schemas backfills only the new fields. Do not infer that a former default represented a deliberate choice. Preserve unsupported future schemas verbatim through the owner and disable edits; read them through safe current defaults, including the existing explicit opt-out behavior.

The configuration model owns validation. `Core:Change` remains the persistent entry point. Add `Core:ChangeSearchDefault(key,value)` to copy and validate one nested preference atomically. Search query, current slot/scope/sort, manual range, scroll and expansion stay owned by `Search`, never SavedVariables.

## Layout and type

Use the same 620-unit XPIsland dialog shell and two columns. Add three small tabs, **Appearance**, **Behavior** and **Search defaults**, using the existing 86Ãƒâ€”22 button constructor and a single gold active underline. This keeps settings out of the compact search panel and avoids stretching the options window for four new defaults.

The shell is 462 units high. Sections use x=16/316, width=288; content uses x=28/328 and width=260. Heading and Close placement retain the current shell. Sections start at y=80 after tabs at y=42. The Appearance page has Font at y=105/dropdown=125, Border at y=163/dropdown=183 and scale at y=225/slider=250 in the left column. The right column has Quest colors / Quest dialog tint / Reward details at y=105/133/161, Preview layout at y=199/dropdown=221, and Tint strength at y=269/slider=294. Behavior uses the same grid for reveal/position and surface toggles. Footer Reset and status share y=420. All labels use owned 12-unit text; no global Font object is modified.

The Search defaults page uses the same columns: left **Search defaults**, containing Hide unusable and Include dungeon quests; right **Level range**, containing Levels below and Levels above with equal 58Ãƒâ€”22 numeric edits aligned to the column's right edge. A single muted sentence explains that changes apply on the next search opening. No new main-panel settings are added. Current-zone remains the initial scope.

Reuse existing native edit/slider/dropdown/check constructors and their disabled states. Construct both page trees once. Page changes close native menus and clear numeric focus before hiding the page. Reopening refreshes bindings from the current profile without writes. Programmatic refresh guards slider callbacks. Native menu descriptions regenerate only when selection, effective font, or available entries change; reopening an unchanged dialog does not accumulate frames or callback registrations.

## Runtime behavior

- Font selection applies immediately to owned search/options/compact-inspector text through `UI:Font`, retaining the current fixed role sizes. Specialized item-level/quantity overlays retain their native NumberFontNormalSmall family and outline. Native item/comparison tooltips and the native tooltip preview keep their native fonts. Use a checked requested family, then the runtime tooltip family, then `STANDARD_TEXT_FONT`, then an owned reference to `GameFontNormal` if path loading fails. Retain missing media names in preferences and show their name as unavailable in the dropdown. Registered media is optional; do not bundle or depend on another addon. Register each SharedMedia callback once; font callbacks reconcile the family, refresh descriptions and relayout visible owned text. No polling.
- Border selection applies to owned search shell/cards/copy dialog and compact inspector surfaces. `default` preserves their existing per-surface art. `none` removes only the edge artwork while preserving background, fixed content insets and geometry. Tooltip, Dialog and Thin use existing Blizzard backdrop assets. Restore the selected edge when leaving none; do not modify Blizzard/other-addon tooltip frames. Settings keeps the standard XPIsland dialog shell so choosing none cannot obscure the settings surface.
- Scale continues to affect preview/search only. Settings uses its existing viewport fit. Search preserves its logical parent-relative anchor when scale changes, refits the full frame before clamping, and keeps the drag handle reachable. Changing font/border does not recenter it or reset transient search filters. No new saved-position feature is introduced.
- Search defaults apply on the next hidden-to-shown search transition: copy Hide unusable and dungeon choices; recompute the inclusive level interval from current level minus/below and plus/above, clamped to 1Ã¢â‚¬â€œ200. Reset the manual-range marker for that new opening. Query, slot, scope and sort retain their existing session lifetime; new sessions still start in current-zone mode. Settings edits do not unexpectedly replace a visible search's active checkboxes or manually entered range.
- Reset restores all persistent settings, including font/border and search defaults, without writing another addon's data. Appearance applies immediately. Default search choices take effect at the next opening. Reset does not write or persist the current query, sort, slot or scope. Numeric Escape discards the unfinished edit; Enter validates and applies. Closing a page releases focus and restores unfinished text from saved values.

## Integration boundary

`Model.SearchDefaults(value)` returns a fresh normalized defaults table. `Core:ChangeSearchDefault(key,value)` persists a validated nested edit. `UI:Border(frame, defaultKind)` applies only an owned frame's backdrop edge, preserving its configured background/insets. `UI:FontEntries()` returns deterministic built-ins plus valid registered names and the current missing preference. `Options` owns page navigation and control construction. `Search` reads `Core.profile.searchDefaults` at opening and uses `UI:Border` while rendering/restyling owned surfaces; it does not write default preferences.

## Required evidence

Execute schema-3 migration, independent nested defaults, explicit false, malformed/future data, finite/clamped offsets, missing and late media, family-wide fallback, no global-font writes, border noneÃ¢â€ â€™restore, scale/anchor preservation, unopened/hidden/visible search default timing, Reset, Enter/Escape, page/menu/focus lifecycle, unchanged reopen object counts and actual reload reconstruction. Run the repository verifier after integration. Retain native checks for visual alignment, clipping, fractional scales, physical menu input and combat/taint; source and mocks alone do not establish them.
