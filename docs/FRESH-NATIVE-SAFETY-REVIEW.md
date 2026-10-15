# Fresh Forever API and native UI safety review

Baseline `ac2485ad2f1af451879cbccd08a67bc1c5064306` (FindAnUpgrade 0.1.9),
then re-reviewed the stable Sources/Questie early callback guards added during
this review round. Final 0.1.10 freeze was checked again: Core's version string
and the TOC version are the only subsequent semantic changes in the 13 reviewed
runtime paths. Runtime hashes below identify the final inspected files.
This review independently traced the current implementation, reconstructed the
relevant native contracts, and executed new probes. Earlier review pass counts
were not treated as evidence. This reviewer made no production edits. No
additional production change is requested from this area.

## Source evidence

Target: official Forever 1.60.1.70374, interface 16001, Gethe/wow-ui-source
`735496de78ebd30ce816a0637982c556987f258c`. Recomputed Git blob SHA-1 and
SHA-256 for 28 local native source files against the complete pinned repository
tree. This includes the actual tooltip data handler, comparison manager,
GameTooltip implementation/XML, shared tooltip templates, intrinsic dropdown,
quest map providers, selected fonts and selected Camelot UI overrides. The
existing 70338 detail-renderer fixture is a separate baseline, not live proof.

The installed XPIsland/ATCF UI and options constructors were read directly,
including their bounded text and modern dropdown construction. Installed
Questie 12.1.0's map tooltip, unit tooltip handler and layout implementation were
read directly. These are working conventions and integration contracts; their
presence on disk does not establish runtime acceptance of this addon.

The pinned [tooltip data rules](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataRules.lua)
were additionally inspected for callbacks beyond the base handler. Item
finalization only enters the global automatic comparison path when the tooltip
advertises comparison support. Owned FindAnUpgrade tips use their private
manager instead. Sell-price formatting uses ordinary tooltip lines in this
build; it does not require the older money-frame constructor.

## Entry points and findings

| Path | Reviewed contract and result |
| --- | --- |
| Core / Adapter / UI | Interface is checked directly. Native detail `OnShow`/`OnHide` scripts remain intact; attachment uses additive `HookScript` and `hooksecurefunc`. Attachment is deferred in combat and idempotent. Tint changes only readable texture vertex colors and restores only colors still owned by FindAnUpgrade. No quest action, native anchor, native visibility or shared font mutation was found. |
| Sources / Questie | Map callbacks use current exact quest IDs. Native quest hubs expose `relatedQuests`; pooled marker validity and visible map ownership are rechecked. Questie map sources require a completed render with changed `_Rebuild`, visible nonzero-alpha icon, exact primary ID, and the current data object. Unit associations use the current GUID and rendered registry entry. Native minimap blobs without reliable IDs remain unsupported. No Questie table is written. |
| NativeTooltip / Hover | Native augmentation requires the current public, unprotected tooltip and matching owner or NPC GUID. Readable existing text and data identity are checked. Cleanup retains foreign text and aborts after ownership or token changes. No owner, anchor, mouse policy or native script is replaced. Escape, source invalidation and combat dismissal close owned state. Modifier release hands off to persistent inspection; Shift comparison remains independently native. |
| Stack | Primary item data must be readable, exact-ID matched and item-typed before rendering. `SharedTooltipTemplate` plus the actual handler avoids GameTooltip's global cleanup side effects. Comparison functions are copied onto an isolated manager with owned tips; global comparison state is retained. Stale row generations clear inspection. Pointer transit, native-rect identity and comparison retry paths were traced. |
| Search / Options / Launcher | The sort control uses an intrinsic `DropdownButton` and artwork only, without bank actions. Other dropdowns use `WowStyle1DropdownTemplate`; native mouse handling is preserved by additive hooks. Menus use owned fonts through `SetFontObject`. Escape/close clear focus, transient popups and owned inspection. Resize/drag modifies owned frames. The minimap launcher moves its own button and leaves Minimap layout untouched. |

No source-identifiable API incompatibility, protected native layout mutation,
foreign-tooltip ownership violation or duplicate hook was found in these paths.
The independently identified disabled-callback workload fix was re-reviewed:
`Sources:Enabled` now precedes native reads/provider resolution, and the Questie
post-hooks return before work while globally disabled. These guards leave native
scripts, subscriptions and per-surface finder proof unchanged.

## Fresh execution

`python .work/fresh-review/native/run_probes.py`: **12 new probes passed** under
Lua 5.1. The actual pinned `TooltipDataHandler.lua` and
`TooltipComparisonManager.lua` bodies were loaded, with explicit C API and frame
engine substitutes. Probes challenged:

- Hook attachment across combat retries, exact native script preservation and
  repeated attachment.
- Combat dismissal without native owner/layout/visibility changes.
- Changed native owner and same-owner foreign line replacement.
- Restricted text and protected tooltip refusal.
- Actual handler rendering and handler-state cleanup on hide.
- Denied item data, mismatched IDs and secret item IDs.
- Private comparison while a foreign global comparison session already exists.
- Stale row generation cleanup.
- Disabled callbacks returning before unit reads and provider hydration.

Fresh execution of six retained suites passed **106 scenarios**: native contracts
(2), native tooltip (35), inspection (41), Questie (9), reference widgets (8),
options (11). These supplement the new probes and do not turn frame mocks into
native-engine observations.

Private evidence is in `.work/fresh-review/native/`: `source-receipt.json`,
`probe-results.json`, `retained-results.json` and the reproducible probe scripts.
`verify_sources.py` rechecks the reviewed source hashes. One older cached
GameTooltip source was explicitly rejected when its blob differed; the matching
70374 `.work/ui-review/GameTooltip.lua` was used instead.

## Remaining client checks

Native rendering, physical pointer transit, hit testing, Escape ordering,
tooltip clamping, mixed-addon callback order and actual secret-value behavior
were not observed. Combat/taint safety still requires the live client with
relevant native surfaces and the user's addon set. Ordinary Lua execution cannot
model taint propagation or the engine's secret-value rules. No game process was
launched, closed or reloaded by this reviewer.

## Reviewed runtime SHA-256

| File | SHA-256 |
| --- | --- |
| `FindAnUpgrade/Core.lua` | `4a90e5fc7507b25fe6340d412bfdc8d231f00848c70b9e2d1c2b4c9f08ab4621` |
| `FindAnUpgrade/Adapter.lua` | `6e5bd98bd38aa991c955f9debee4e509e484fd4f4604bbe1affb79d67477da09` |
| `FindAnUpgrade/UI.lua` | `82ab0084ba17f372da8858431a0d360449aee9a0cfb83ea0aa0034b2ef8ad6d5` |
| `FindAnUpgrade/Options.lua` | `9eccec459dada1941265b328cf07e619e12b4508f381ba4c72cb067e995610ed` |
| `FindAnUpgrade/Search.lua` | `2e2b9b7beb5efe07bfb378fbe08697c23cef7d2382fab891b6a12c51fb8cc2ee` |
| `FindAnUpgrade/Stack.lua` | `22dc2c31d122e2633de76907942a4e86e245a420cafbf933b6a25c1a477f3d44` |
| `FindAnUpgrade/Hover.lua` | `9b8174180bc5b6c78c8de6928346d3774baf68dc7649bd64bc80b8f2218b1d13` |
| `FindAnUpgrade/NativeTooltip.lua` | `774a14c2c58d948df0ed26a44c5072b2ee75006db67d5958859c871831644ec5` |
| `FindAnUpgrade/Sources.lua` | `a75be894f9aa31fc0caef71526db9698255260f455089a48b2dc7657783ab494` |
| `FindAnUpgrade/Questie.lua` | `552277315e82bce02a77d054f9d8320554670caf60666e9662e149ba15b3e572` |
| `FindAnUpgrade/Launcher.lua` | `d8c4ff01fd14a863ca649f5bba6c935cd95bca06552463412b28b5f68b92dad5` |
| `FindAnUpgrade/Model.lua` | `cfb0fad44b2f108b9f8510a18fde1c03713afede1d4b5189d50404a7ac2fc42b` |
| `FindAnUpgrade/FindAnUpgrade.toc` | `30ce3879d7d0e36f962b750d6a047ced9410f937385639410fca643a7736935b` |
