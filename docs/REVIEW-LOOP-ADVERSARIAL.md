# Final independent adversarial review

Reviewed the changing QuestBrief 0.1.1 working-tree candidate independently of
the implementation and earlier review authors. Scope: negative API paths,
settings application, exact variant/classification provenance, isolated native
tooltip ownership, scheduling and release boundaries. This reviewer edited only
this report and ignored probe artifacts. No commit, merge, installation,
publication or running-client observation was made.

Read the replacement `AGENTS.md` and the user's local
`wow-addon-development/SKILL.md`, together with its client/source, ownership,
validation, layout, UI/settings and packaging references. Current native tooltip
procedures are pinned to Gethe revision
`735496de78ebd30ce816a0637982c556987f258c`, build 1.60.1.70374; the older detail
renderer stays separately pinned. Surrounding engine services remain mocks.

## Findings and re-review

### A1 — P2: Finder colors ignored existing appearance settings — closed

`Search:Fill` originally applied a fixed classification accent regardless of
`profile.accents` or `profile.strength`; `Core:Change` did not refresh an already
visible finder. With Quest colors disabled and strength 0.1, an independently
classified New fixture rendered `(0.105, 0.06, 0.07, 0.97)`. Strength 1 produced
the same color. This contradicted the existing settings labels and the hover
stack/dialog implementation.

The correction reads current appearance settings, updates visible finder work
from `Core:Change` and `Core:Defaults`, and applies the compact scale setting with
the screen clamp. The independent entry-point probe now verifies:

- Disabled colors: `(0.06, 0.06, 0.07, 0.97)`; classification text remains useful.
- Enabled strength 0.1: `(0.068, 0.06, 0.07, 0.97)`.
- Enabled strength 1: `(0.14, 0.06, 0.07, 0.97)`.
- Live setting application in the mock: scale 0.8 and 1.2, defaults restore 1,
  and a 400 × 300 parent clamps the 560 × 600 finder to scale 0.46.

The reward-details option now explicitly reads **Preview reward details**,
clarifying its scope. Multi-coordinate controls read **locations** and **Choose
location**, so two coordinates for one NPC are not presented as two NPCs.

Evidence: `.work/final_adversarial_probe.py` and
`dist/final-adversarial-probes.json`. Synthetic classification in this test does
not modify or enlarge the shipped exact-ID authority.

### A2 — P2: A cold comparison stayed blank after its item loaded — closed

The independent reproduction executes the pinned comparison manager's real
`SetItemTooltip` path. Its call to `C_TooltipInfo.GetHyperlink("item:124")`
initially returns nil, which the native implementation explicitly handles by
returning without showing that comparison. QuestBrief nevertheless cached
`compareState=true`. When the item then became ready, both native
`ITEM_DATA_LOAD_RESULT(124, true)` and `GET_ITEM_INFO_RECEIVED(124, true)` plus
120 active frames caused no further fetch. The comparison remained hidden.
Releasing and pressing Shift fetched it again and showed it immediately.

At the reproduced snapshot, the item event handler rejected equipment-comparison
IDs absent from catalogue cache/request tables, while `Compare` returned on the
unchanged comparison boolean. A nil initial tooltip has no data instance for the
separate `TOOLTIP_DATA_UPDATE` matcher to recognize. This is distinct from the
earlier correction for an already-rendered comparison's data instance.

The correction retries cold owned comparisons at 0.2-second intervals within a
fixed five-second window. It clears the owned manager clone's nil cached result
before retrying and preserves the deadline across matching inspection refreshes.
Successful rendering, modifier release, departure, owner teardown and stale
generation/row identity end retry work. A missing equipped entry is not classified
as a pending comparison.

The original independent probe now shows the comparison after load with two
fetches and no Shift rearm. Additional independent probes force permanently nil
comparison metadata or item tooltip data at 30 and 240 FPS, flood matching
tooltip updates, then deliver ten more simulated seconds. Each makes 24–25
fetches, stops at the unchanged 5.3 deadline, and preserves the global manager,
global comparison index and native tooltip. All 17 current lifecycle cases pass,
including transit and reentrant teardown regressions. A2 is closed offline.

Evidence: `.work/final_adversarial_cold_compare.py` and
`dist/final-adversarial-cold-compare.json`.

### A3 — P2: Primary nil tooltip recovery — closed

The same pinned `GetHyperlink` contract declares `MayReturnNothing=true` for the
primary native tooltip. A separate probe keeps full item metadata ready, returns
nil from the initial primary tooltip lookup, then makes it ready and delivers
successful native item events for that exact item. After 120 active frames, the
primary remains hidden with one lookup and no inspection token. Its nil result
exits `Inspect` before the bounded comparison state exists. This is a distinct
recovery path from A2, and does not fabricate content or mutate native UI.

The correction creates a pending inspection only for already-ready exact item
metadata and a nil native tooltip payload. It retries at 0.2-second intervals
within a fixed five-second window, checks owner/generation/row identity after the
native getter, and postpones comparisons until readable exact-ID primary data
exists. Getter errors, absent APIs, malformed or restricted payloads close the
inspection instead of becoming retry candidates. Departure and teardown cancel
pending work; a permanent nil result leaves no inspection after timeout.

The original stationary-pointer probe now fetches twice and shows the primary
tooltip after the exact item's load events. Independent permanent-primary tests
at 30 and 240 FPS flood successful item events and nil tooltip-update events:
they make 24 and 25 fetches, respectively, preserve the original 5.3 deadline,
end inspection, and perform no further fetch in ten additional seconds. Separate
delayed-getter probes hide the finder, disable the addon, open a menu, change its
generation or reassign its pooled row during the retry that returns ready data.
Each ends at two fetches, keeps every owned tooltip hidden and preserves the
global manager, global comparison index and native tooltip. A3 is closed offline.

Evidence: `.work/final_adversarial_pending_tooltips.py` and
`dist/final-adversarial-pending-tooltips.json`, which also contains the additional
independent A2 permanent-cold/flood checks.

## Checks actually performed

Independently executed focused Lua 5.1 suites: 45 finder cases, 15 runtime cases,
11 lifecycle cases, two pinned native-contract cases and ten model cases, all
passing before the A2 correction. Executed 20 catalogue tests and five
classification tests, all passing. These results are snapshot-specific; final
counts after further corrections belong to a new receipt.

After the final A3 correction, independently reran the focused suites against the
frozen functional code: **45 finder, 15 runtime, 21 lifecycle, two pinned
native-contract and ten model scenarios all pass**. Reran the original A1/A2
probes with the same successful outcomes, plus the independent A3 cases above.

A separate data probe confirms 1,250 exact quests, 1,934 distinct items and 2,266
retained pairs. Every pair belongs to the pinned compiled cross-check; none of
the 435 explicitly excluded pairs is retained. Quantity and guaranteed/choice
membership are absent from every recorded item. The catalog has 48 per-variant
New IDs; the separate primary authority remains 1,194 exact IDs with 218 New
variants. No title group or catalog membership assigns classification.

Inspected retained direct item nodes with descriptions or container children.
The examples carry recorded associations and unknown group/count status; no
additional concrete input-as-reward defect was established in that pass. The
source build remains 69893 and the target build 70374, explicitly distinct.

The inspected implementation owns its search/hover frames, tooltip frames,
comparison state, timers and cache tables. Native observation uses secure
post-hooks and additive scripts. This pass found no quest acceptance/completion,
global binding/CVar edits, protected layout/visibility edits or writes to another
addon's saved data in the reviewed paths. This is a source boundary check, not a
taint-safety verdict.

The corrected scheduler's focused tests cover failure progression beyond 128
items, fair quest/reward turns, frame-rate-independent dispatch budgets,
sustained callbacks, hidden-cache invalidation, synchronous dismissal and removal
of idle update work. The final integration must rerun the complete verifier and
rebuild packages after all review corrections.

## Evidence and pending client checks

`dist/final-adversarial-results.json` records the focused suite counts and tested
file SHA-256 values. The appearance re-review used `Search.lua` SHA-256
`7542914b4c1f27a0be321aef9581f3629404c7fc34c9a7db0c7c1d473f1f7bc4` and `Core.lua`
SHA-256 `cb5c3e105394e9abdd357d245126ffa2ec2ffed18c517662753d90fecc100bf5`.
The A2 reproduction used `Stack.lua` SHA-256
`b536e7d0aa644e7bd0a9f0bc1aeafd92eda9a4876917ec5c55045b8479f98a6c`.
Final A1/A2/A3 closure and focused reruns use `Stack.lua` SHA-256
`d27e0f05d679c7ce2aea289090f64c739b15eb5a4069d7234f36e0c777acdc5b`.
The final catalog source SHA-256 is
`2d83e341171aa2e405f486049bc1a2070e797061bb367e7bdda0f40d25e5bbec`.

Native appearance, physical modifiers/Escape/transit, cold server hydration,
arbitrary quest rewards, item variants, ordinary reputation, coordinate/phasing
accuracy, other-addon coexistence, actual frame cost and combat/taint remain
pending in the official Forever client. Installation alone does not establish
any of them. User-authorized merge/installation results are separate integration
outcomes; this review does not authorize or perform publication or release tags.

**Final review verdict:** A1, A2 and A3 are corrected and independently reverified
offline. No other concrete blocker was established in this adversarial review.
The parent integration owns the final complete verifier, package receipts, CI,
authorized merge and installation. All listed live-client checks remain pending.
