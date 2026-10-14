# Independent UI and lifecycle cross-review

Reviewed the corrected 0.1.1 finder and reused Stack inspector independently on
2026-10-14. This reviewer did not implement the UI or lifecycle corrections and
made no runtime, tooling, data or committed-test changes. The report is the only
new deliverable in the source tree; disposable probes are under
`.work/cross-review/`. No commit, merge, installation or publication was performed.

## Result

No additional concrete defect was identified in the final UI/lifecycle paths
reviewed. Eight independent negative/interaction probes passed. Focused execution
also passed 45 finder scenarios, 11 lifecycle scenarios and two current native
contract scenarios, 58 total. The full integration verifier remains the root
task's responsibility after the final source changes settle.

`dist/fresh-cross-review-probes.json` records the source and native-fixture hashes
plus each independent probe result. `dist/fresh-cross-review-suites.json` records
the separate focused suite results. Reproduce the independent probes with
`python .work/cross-review/probes.py` in the development workspace; that ignored
probe helper is not an addon dependency or packaged source requirement.

## Render settling and data invalidation

The independent geometry fixture supplied 24 results with stale 1,000-unit
height estimates, deliberately exhausting the renderer's four-pass cap. It then
used the real finder `Tick`, `Refresh`, `Render`, request queues and updater to
finish settling. The queued refresh completed within four refresh calls, each
tick respected the render pass bound, positions/child height/range remained
coherent, and dirty/pending work cleared. The visible finder removed its updater;
200 subsequent synthetic frame deliveries caused no additional fills.

`Tick` clears `changeAt` after `Refresh`, including when a capped render has
called `DataChanged`. This allows the next owned tick to finish the outstanding
work. It does not discard `dirty`, and stable cached heights terminate the work
in the tested fixture. It can retry on the next frame rather than waiting the
new 150 ms deadline; this review found no starvation or perpetual redraw from
that sequence. Source-coordinate measurements and mock call bounds do not
measure native frame time or visual smoothness.

A separate asynchronous refresh test expanded the last result while at the
bottom. Bottom intent, scrollbar and offset remained at the recomputed maximum,
and the last footer was reachable. Deliberate upward scrolling cancelled bottom
intent; a later data refresh retained that chosen offset.

## Full text, menus and pooled controls

The independent interaction probes confirmed that copy, scrolling and finder
hide close the owned full-text tooltip, and copy-dialog visibility prevents it
reopening. Closing finder-owned menus did not close an unrelated menu. A submenu
release callback retained the root menu owner; choosing an alternate giver
closed the owned menu and updated the giver copied by the resulting card's
context action.

The pinned [native MenuUtil source](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_Menu/MenuUtil.lua)
supports nested description utilities and associates context menus with their
invoking region. Matching Menu source defines scroll mode on base descriptions,
children as submenus, and release callbacks using the released menu proxy.
Common menu templates preserve motion handlers for disabled buttons, supporting
the condition-specific tooltip path. These are source contracts, not a native
compositor or physical-input observation. No direct font setter on compositor
text or global menu-close call was added by the reviewed addon paths.

## Native tooltip re-entry and line filtering

The probes executed the actual pinned `ProcessInfo`/`InternalProcessInfo` and
comparison-manager methods, with surrounding native services mocked. Both
fixture SHA-256 values matched `client-contracts.json` at Forever 1.60.1.70374,
revision `735496de78ebd30ce816a0637982c556987f258c`.

- Errors from post callbacks on the primary tooltip or either comparison
  tooltip left every owned tooltip hidden, with no inspection or filtering flag.
- Reassigning a pooled button to another row with the same item ID during native
  comparison processing invalidated the old inspection and hid its tooltips.
- A comparison-only data-instance update refreshed the owned inspection while
  preserving its original departure deadline. Unrelated IDs did not replace the
  inspection, and departure still expired at the original grace limit.
- Owned `AddLine` delegated ordinary text and its color/wrap arguments. Native
  item data whose text exactly matched a cycling instruction remained present;
  the extra unsupported instruction was omitted outside native item processing.
  The scoped processing flag and hint table were restored after rendering.

The separate global comparison manager retained its tooltip and comparison
index, and unrelated global item/shopping tooltip frames remained untouched in
these probes. The final `HasTooltipData` path handles visible owned primary and
comparison instances; it also rejects stale inspection ownership and unreadable
or invalid instance identities. The reviewed calls preserve the captured
generation and exact pooled-row identity across native callback boundaries.

## Remaining client checks

Offline source execution does not establish native pixels, physical pointer
transit, native menu/compositor behavior, event timing, taint safety or in-game
CPU. On official Forever 1.60.1.70374/interface 16001, check long/localized text,
fractional scale, small displays, submenu/disabled tooltip behavior, final-card
reachability during resize and incoming data, pointer travel between primary
and comparison tips, Escape/focus order, combat transitions, and coexistence with
the global tooltips and the user's other addons. Installation evidence, if
recorded by the root task, remains separate from those live observations.
