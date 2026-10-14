# Independent API and performance review

The review used the WoW addon development skill, repository AGENTS.md, shipped
Lua and TOC, and source contracts for Forever interface 16001. The pinned baseline
is Gethe/wow-ui-source revision `943764493e6b16d63ded3ab304150d1f05e58b57`
(1.60.1.70338); the current source snapshot is revision
`735496de78ebd30ce816a0637982c556987f258c` (1.60.1.70374). Installed Questie 12.1.0
was inspected read-only. This reviewer changed no runtime source or user settings.

## Findings and resolution

**Reward details disabled still performed hidden reward work.**
`Stack:Fill` previously read rewards and marked pending work before testing the
visibility setting. A single pending quest produced eleven reward reads and one
reward preload while no reward details were displayed. Larger stacks multiplied
that work. The implementation now gates reward reads, pending polling and reward
preloads on the setting. The repeated probe records zero reward reads and zero
reward preloads with details disabled. Cached titles and reward readiness also
avoid unnecessary request calls.

The preceding lifecycle review also found and verified fixes for clipped reward
hit tests, unrelated candidate-marker cleanup, pooled-frame activation keys,
comparison anchoring, the native quest-hub entry point, tooltip-data update scope,
refresh during pointer transit, and Questie alpha/throttle early-return freshness.
The latest inspected implementation keeps those fixes. Review reproductions are
retained outside release packages in `.work/reviewer/`.

**Mixed-choice exact item-ID checks did not disambiguate duplicate counts.**
The focused choice review confirmed that the pinned native QuestInfo renderer
uses mixed item/currency indices for metadata and item-only ordinals for native
item tooltips. Its selected-quest calls do not settle the explicit quest-ID
getter's indexing convention. The candidate therefore supports an item-only
metadata fallback, but accepted the mixed-index candidate when its item ID alone
matched the native ordinal. With a currency followed by the same item ID in
quantities one and five, an item-only metadata getter exposed the second item's
quantity for the first tooltip ordinal. The isolated mixed-choice probe reproduced
`ready` with quantity five for both rows. Metadata also accepted a fractional item
quantity of 1.5. The implementation now rejects conflicting matching-ID metadata
and fractional item counts; the original probes confirm both fixes. The further
missing-metadata duplicate case initially still borrowed the later duplicate's
quantity when the correct item-ordinal metadata was absent. The final correction
builds the native item-ordinal ID map first and suppresses shifted mixed slots
when that map is incomplete or the exact item ID repeats. All independent
mixed-choice probes now pass: neither duplicate case displays a borrowed quantity,
fractional counts remain unavailable, distinct known items still display their
own quantities and native ordinals, and an incomplete native ID map suppresses a
shifted candidate. This is a conservative boundary pending direct verification
of the explicit-ID metadata overload; shifted duplicate rewards can remain
unavailable even when their data exists.

## API conclusions

- Item rewards retain their exposed native slot index, kind and exact quest ID.
  Mixed item/currency choices retain the combined loot index for metadata and
  the item-only index for native item inspection, following QuestInfo's separate
  `choiceItemIndex` path. A regression puts a currency before two items; missing
  currency classification fails safely rather than shifting an item index.
  Shifted duplicate IDs and incomplete native ID maps suppress item details
  rather than borrowing another slot's name, count, icon or quality.
  Inspection requests `C_TooltipInfo.GetQuestLogItem(kind, index, questID)` and
  checks the returned item ID before using the data. The current generated
  [tooltip contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoDocumentation.lua)
  supports those arguments. No selection of a different native quest-log entry is
  required, and this implementation never accepts or completes a quest.
- Guaranteed and choice currency rows use exact quest IDs and
  `GetQuestRewardCurrencyInfo(questID, index, true)` for choice entries. Finite,
  readable amounts are retained; missing values do not become zero. The
  [quest-log contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)
  establishes the argument order.
- `GetQuestLogMajorFactionReputationRewards(questID)` is explicitly scoped to
  major factions. Its pinned `QuestRewardReputationInfo` fields are `factionID`
  and `rewardAmount`. Valid exposed rows are retained in that scope; malformed or
  restricted values are omitted. An empty result does not establish ordinary
  Classic faction rewards. Ordinary faction reputation remains unavailable.
- Scalar reward readers preserve the difference between a restricted value and
  an unavailable/throwing API. Neither case invents a number. The probes execute
  the actual shipped readers under Lua 5.1.
- The owned item and shopping tooltips use natively hidden SharedTooltipTemplate
  frames with separate handler cleanup. The addon copies the native comparison
  manager's function methods into an addon-owned state object and uses owned
  shopping frames; it does not clear or replace the shared native manager state.
- Questie integration uses additive secure post-hooks and read-only rendered
  exact IDs. Positive texture alpha, a fresh native render token and matching
  primary marker ID guard alpha/throttle early returns. Marker identity checks
  account for pooled data replacement and in-place quest-ID changes. No marker is
  created or hidden by QuestBrief, and no Questie data is written.
- Legacy initialization reads an already-restored QuestTintDB only if
  QuestBriefDB is missing, validates it and creates a separate current profile.
  It neither loads a disabled legacy addon nor edits the old table. Existing
  QuestBrief data takes priority; unrecognized newer legacy schemas are ignored.

## Workload and ownership evidence

`python .work/reviewer/performance_probes.py` independently exercised the shipped
code with supporting WoW API fixtures. It confirmed:

1. A continuously pending inspection session performs one initial read and at
   most ten half-second rereads through the five-second deadline. Later ticks
   perform no further periodic reward reads. No repeated preload request occurs
   in that session.
2. Pending work pauses while a reward item is inspected, preserving its tooltip
   and geometry. When inspection ends after the deadline, one reconciliation
   renders unavailable state and periodic work stops.
3. Dismissal clears the pending owner. With no current source and no open stack,
   the addon removes its hover OnUpdate callback.
4. Disabled reward details produce no reward reads, pending polling or preloads.
5. Restricted and throwing scalar APIs remain distinct; valid major-faction rows
   do not imply ordinary-faction coverage; legacy seeding preserves both source
   tables.

Frames, cards, reward buttons, options and item tooltips are reused. The existing
inspection regressions cover 200 repeated open/close sessions without additional
frame construction after warmup. Source and tooltip-token identity caches use
weak keys; the active source, request set and pending deadline have one inspection
owner. Item and source inputs are bounded before iteration. Periodic reward reads
are bounded in time and do not use catch-up loops after frame stalls.

The current implementation refreshes the full stack while pending data is being
reconciled. Work therefore scales with the bounded number of cards and item slots,
including ready cards. The source review and offline call counts do not measure
engine frame time or native allocation cost. A live profile of a representative
long stack is needed before asserting an in-game CPU or memory budget.

## Checks and remaining boundary

This reviewer ran all five data checks successfully during the preceding review
and the latest 112-scenario Lua 5.1 suite successfully during the focused choice
review. The additional isolated mixed-choice probes all pass after the final
missing duplicate-metadata correction. The final runner report in
`dist/test-results.json` is the source of truth for the final scenario count; a
passing runner does not establish coverage of later independent counterexamples.

No remaining concrete API or performance defect was identified within the
reviewed source contracts after the hidden reward-work and mixed-choice fixes.
The minor contract cleanup was applied: GetNumQuestLogRewards receives its exact
quest-ID argument, and GetNumQuestLogChoices separately receives its
include-currencies boolean.

There was no live UI operation or installation. Native rendering, physical mouse
dispatch/clipping, modifier focus delivery, actual reward availability, Questie
timing/fade/load order, combat taint, and CPU/allocation cost remain pending live
Forever checks. Ordinary reputation and native minimap quest identity without
Questie remain unsupported rather than inferred. No other addon, user
configuration, GitHub repository, merge or release was modified by this reviewer.
