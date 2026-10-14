# Fresh input, tooltip and lifecycle review

Reviewed `75e88b03b6e8e97500af5ccbd3e7d28ea3424235` (`feature/reward-finder`)
independently on 2026-10-14. The initial review edited only this report and
temporary probes under `.work/lifecycle-review/`. A later delegated follow-up
authorized the Stack implementation and lifecycle regression tests documented
below. Generated data was not edited by this subtask. Followed `AGENTS.md` and the
`wow-addon-development` skill's client, UI, ownership, layout and validation
references.

## Findings closed by implementation and re-review

The follow-up working tree based on the same reviewed commit closes all three
findings below. `Stack.lua` now retains the departure timestamp for same-item
refreshes, checks inspection identity/generation/pooled target after native
render calls, and removes only unsupported cycling instructions from owned
comparison content outside native item-data rendering. Item and delta stats
remain intact, including item text that happens to match an instruction.

Re-review also found and closed an adjacent refresh gap: owned comparison
tooltips have their own data-instance IDs, which the old event path ignored.
`HasTooltipData` now matches the visible owned primary and comparison frames;
the finder and hover event paths refresh the complete current inspection.
Invalid, restricted and unrelated IDs do not claim ownership. The pointer
tick uses the same inspection identity check to reject pooled-row reassignment
without waiting for a data event.

The final adversarial pass also reproduced a cold-comparison recovery defect:
when `GetHyperlink` initially returned nil for an equipped comparison item,
`compareState` stayed true and prevented subsequent native reads while Shift
remained held. The owned clone now marks missing data only for a non-nil
displayed item, and also detects a nil native comparison-info result. Active
inspection retries at most once every 200 ms within a fixed five-second
window. A same-item tooltip refresh preserves that window, next retry and
timeout latch; update floods cannot restart or accelerate it. Nil cached
comparison info is cleared only on the clone before retry. Ready results,
modifier release, departure, hiding and stale identity stop retry work.
No global state, binding, CVar, explicit item-load request or new timer is
changed by this recovery path.

The same final pass identified nil primary tooltip data for a cached, known
item as the remaining recovery gap. The primary read now creates an existing
inspection token before its API call and retains it as pending only for a
readable nil result. Pending data displays no tooltip and does not run item
comparisons. Pointer ticks retry the same inspection at 200 ms intervals
within a fixed five-second deadline, preserving the deadline across retries.
The API return is checked against current owner, generation and pooled row;
restricted, malformed, failed or unavailable getter results close immediately.
Timeout, departure and teardown clear the token, so later data cannot display
an orphan tooltip. No feature, option, event or API scope was added.

These corrections were implemented in `QuestBrief/Stack.lua` with the parent
owning event-path integration and verifier wiring. No commit or publication
was performed by this subtask.

### P2: matching tooltip updates restart pointer-departure grace

Location: `QuestBrief/Stack.lua:191-208`, called by `QuestBrief/Search.lua:96`
and `QuestBrief/Core.lua:113-117`.

Trigger: inspect a ready item, move onto blank card space outside the icon and
all item/comparison tooltip rectangles, then deliver matching
`TOOLTIP_DATA_UPDATE` events faster than the 200 ms transit grace. Each handler
calls `Inspect(button,row,true)`. `Inspect` calls `ClearItem`, discarding
`itemOutsideAt`, before recreating the same inspected item.

Consequence: the old item tooltip remains visible indefinitely on blank card
space while updates continue. The next tick starts a new departure timer every
time. The registered-handler probe ran updates every 100 ms for two seconds;
inspection remained active and its outside timestamp advanced to 2.4 rather
than expiring after its original departure. Tooltip data arriving is not a
new pointer entry and must not re-arm the grace interval.

Suggested correction: preserve the departure timer for a valid same-item
refresh, and reject stale session/target generations before refreshing.

### P2: synchronous native tooltip callbacks can resurrect a cleared tooltip

Location: `QuestBrief/Stack.lua:203-210` and `QuestBrief/Stack.lua:217-220`.

Trigger: a native tooltip post callback tears down the inspector's owner
during `ProcessInfo`, for example by hiding the search window. Exact current
Forever source executes `ProcessTooltipPostCalls` before its final `self:Show()`
(`TooltipDataHandler.lua:298-300`). The hide handler clears inspection and hides
owned tooltips, then native processing resumes and shows the same tooltip.

Consequence: the search frame is hidden and `inspector.item` is nil, but the
owned tooltip remains shown. It is parented to `UIParent`, so hiding the finder
does not hide it through parenting, and the finder's updater has been removed.
`Inspect` does not revalidate the operation after the native call returns.
The probe executes the actual extracted native `ProcessInfo` and
`InternalProcessInfo` methods with a post callback that hides the owner; all
three resulting facts were observed offline: hidden search, cleared item,
visible tooltip.

Comparison rendering has the same reentry boundary: native comparison methods
call each shopping tooltip's `ProcessInfo`. Validate session, target and
generation after comparison calls too, and explicitly hide all owned frames
when the operation was invalidated. A scoped manager clear alone can become a
no-op after reentrant cleanup already set its `tooltip` to nil.

The separate `comparison_reentry.py` probe executes the actual current native
comparison manager with reentry during primary comparison rendering: finder
hidden, item cleared, primary comparison still shown, global manager untouched.

### P2: native comparison cycling hint points at the unrelated global manager

Location: `QuestBrief/Stack.lua:185-188` and `QuestBrief/Stack.lua:217-219`.

Trigger: native comparison metadata has multiple additional comparison items,
`allowCompareWithToggle` is enabled, and the cycling action has a binding.
The copied native `SetItemTooltip` writes its ordinary cycling hint, such as
"Press TAB to swap", to QuestBrief's comparison tooltip.

Consequence: the advertised action does not cycle QuestBrief's owned comparison.
Exact Forever `Bindings_Camelot.xml` invokes
`GameTooltip_CycleSecondaryComparedItem(GameTooltip)` for
`ITEMCOMPARISONCYCLING`; that current function ignores its argument and calls
the global `TooltipComparisonManager:CycleItem()`. QuestBrief has a separate
cloned manager and no owned cycling control or action route. With another
comparison active, following the hint can cycle that global session instead.

`comparison_cycle.py` loads actual current comparison methods and the extracted
current native cycling function. It observed the hint, an owned index staying
at 1, a global index advancing from 1 to 2, and a global refresh. Avoid promising
the unsupported binding in owned tooltip content, or provide an explicit owned
control without taking over the global binding or unrelated comparison manager.
This defect is shared by the reused Stack inspector and the new finder.

## Focused evidence and passing checks

Run `python .work/lifecycle-review/probes.py` from the repository root. It loads
the shipped TOC modules through the existing setup fixture and exercises
registered `OnEnter`, `OnUpdate`, `OnEvent`, `OnMouseWheel`, `OnSizeChanged`,
`OnEscapePressed`, launcher drag, map callback and hide paths in Lua 5.1 via
the existing `.work/pydeps` Lupa installation. No full verifier was run while
other agents were editing the branch.

`python .work/lifecycle-review/focused_suites.py` also passed the existing
inspection (41), current native contract (2) and search (38) scenarios, 81
total. Those passing scenarios do not cover the three fresh defects above.

After corrections, the same focused runner passes inspection (41), current
native contracts (2), the updated search suite (45), and new lifecycle (21),
109 scenarios total. `tests/search_lifecycle_test.lua` covers registered
tooltip-data events, departure/transit, stale sessions and pooled targets,
teardown during actual pinned primary and both comparison renderers, cycling
hint suppression, item/delta preservation, and comparison-only updates with
departure and global ownership retained. Its final six cases cover cold item
and comparison-info recovery without modifier re-arming, permanent-cold
read bounds under 100 Hz primary updates, absent equipped entries, cancellation
on release/teardown/reassignment, and recovery during departure or reentrant
native rendering. The exact final adversarial cold-item probe now observes
one initial comparison read, one recovery read, and a visible comparison
without releasing Shift.

The final four primary-data cases verify recovery under a stationary pointer
after cache events, permanent-nil call/deadline bounds at 30 and 240 FPS,
departure/teardown/reassignment during and after getters, and fail-closed
handling of restricted, malformed, erroneous or absent APIs. The final
adversarial primary probe now reports one initial read and one recovery read,
with the actual native tooltip shown without a second hover.

The committed native renderer regression executes the actual pinned
`ProcessInfo`, `InternalProcessInfo`, `ClearHandlerInfo` and
`HasDataInstanceID` procedures with mocked callback and line services. The
fixture is now at
`.work/current-api/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua`:
19,497 bytes, blob SHA-1 `90c60103b3ed34e08e283b209820f6bea200719d`,
SHA-256 `05a86b963b518a589cfebf22dec825507a5b1f564f66eb64fd7caead919f0642`.
It was re-fetched from the exact current revision and matched the GitHub tree
blob. Missing fixtures skip the explicitly native cases; portable lifecycle
cases still run.

`python .work/lifecycle-review/mutation_check.py` separately removed each
original correction in memory and confirmed the regressions reject all three:
departure-timer preservation, native-render ownership validation, and cycling
instruction filtering. Additional mutations removing cold-item retry,
preservation of its fixed window, or its 200 ms cadence are also rejected.
Mutations disabling pending-primary retry or discarding its fixed deadline
are likewise rejected by the new primary-data cases.
`git diff --check` passed for the owned source/test
changes. Full verification remains the parent's responsibility.

- Scroll and resize clear owned inspection before changing result geometry.
- Map close dismisses the map stack; disable hides the finder, clears its item
  and removes its updater.
- Matching asynchronous item-data floods preserve active finder inspection;
  departure clears it and applies the queued refresh afterward.
- Future-schema SavedVariables remain the original table and contents; drag
  and slash settings changes do not write them.
- Focused copy edit Escape hides the copy panel while retaining the finder.
  Executing exact native `CloseSpecialWindows` hides both named special frames
  if the global Escape path reaches that handler. The native implementation
  iterates every shown special frame, rather than promising topmost-only order.
- Source paths retain additive hooks and isolated addon tooltip frames. The
  cloned comparison manager passes its owned tooltip to scoped clear; no
  global `GameTooltip`, shopping or battle-pet mutation was found in the addon
  paths inspected.

An artificial stale-generation probe showed that matching tooltip events can
refresh an inspection before the next tick rejects it. Normal finder refresh
currently clears the item while incrementing generation, so that synthetic
probe alone is not a third user-visible defect. The post-native-call ownership
guard now verifies the captured generation and pooled target, and both event
paths clear an invalid inspection before considering its tooltip data.

The query edit box automatically receives focus on open and has no explicit
Enter handler; the current `InputBoxTemplate` also has none. Escape closes the
finder. An Enter-to-release-focus behavior would be useful to assess during
the pending native input pass; no keyboard-focus-routing defect is claimed
from the mock, whose focus methods are placeholders.

## Source and runtime limits

Current contracts are official Forever interface 16001, build 1.60.1.70374,
Gethe/wow-ui-source revision
`735496de78ebd30ce816a0637982c556987f258c`. Inspected the repository's pinned
comparison/SharedTooltip fixtures and fetched the exact same revision's
[tooltip data handler](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua),
[panel manager](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua),
and [menu utility](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Menu/MenuUtil.lua).
Also checked current [input templates](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml),
[Escape priorities](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_GameMenuEsc/Blizzard_GameMenuEsc.lua),
[Forever bindings](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_FrameXML/Bindings_Camelot.xml),
and [native cycling function](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua).
The original detail-renderer fixture remains at build 70338/revision
`943764493e6b16d63ded3ab304150d1f05e58b57`.

These are source contracts and offline execution, not live game observations.
Pending client checks: actual keyboard-focus routing, copy/menu/map Escape
priority, clipped hit testing, physical pointer transit at screen edges and
fractional scales, mouse-transparent native item/comparison geometry, resize
and drag release outside controls, combat/taint behavior, and coexistence with
global item/battle-pet/comparison tooltips and other addons. No merge, release,
game installation or publication was performed by this review.
