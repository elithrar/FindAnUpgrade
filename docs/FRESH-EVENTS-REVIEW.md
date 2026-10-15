# Fresh event and lifecycle review

Reviewed 2026-10-15 against FindAnUpgrade 0.1.9, baseline
`ac2485ad2f1af451879cbccd08a67bc1c5064306`. This review traced actual handlers
and ran fresh entrypoint probes; it did not adopt previous test totals as proof.
The reviewer edited no production code or tracked tests and did not start the
client, install an addon, or change any installed reference addon.

## Finding and disposition

**P2: Disabled source callbacks hydrate character and quest-log state.** In the
baseline, `Core.lua` handles `GOSSIP_SHOW` by calling `Sources:Gossip` regardless
of the enabled state. `Sources:Pin` resolves provider rows before the enabled
guard in `Sources:Set`. The Questie render callbacks have the same ordering.
`Providers.ResolveRows` obtains the character snapshot, whose first read primes
the quest log. Therefore a disabled addon still performs eligibility and native
state work when a user opens gossip or enters a native quest pin.

Independent reproduction with a 25-quest log, with the addon disabled and both
finder and hover closed, measured **one complete log scan, 25 `GetInfo`, 26
`IsOnQuest`, 27 `IsComplete`, and one identity capture** for either a normal
`GOSSIP_SHOW` event or the registered `MapCanvas.QuestPin.OnEnter` callback.
Neither path opened UI. The probes call the registered entrypoints and execute
the shipped Sources, Providers, Character and QuestState implementations.

The correction belongs before source/provider resolution in the global
ready/supported/enabled gates. It must retain cheap dirty-state subscriptions:
disabling must not erase evidence needed after re-enabling. Gossip must **not**
be gated solely by the NPC-preview toggle or finder visibility, because live
gossip is also exact availability evidence for the finder. The independent
probe confirms that a visible finder still receives that proof with NPC
previews off.

**Resolved and independently re-reviewed.** `Sources:Enabled` now centralizes
the ready/supported/enabled gate. NPC, gossip, pin and hub callbacks check it
before native reads or provider resolution; both Questie render callbacks do the
same. Gossip clears its retained session before declining disabled work, and
Core still sends the lightweight offer-state dirty signal. Re-executing all six
disabled entrypoints and the native/Questie entrypoints on an unsupported client
produces zero measured state reads and does not initialize Character/QuestState
on the unsupported client. Enabled finder gossip with NPC previews off still
passes. No extra event subscriptions or timer were introduced.

The corrected production files inspected and executed have these SHA-256s:

| File | SHA-256 |
| --- | --- |
| `FindAnUpgrade/Sources.lua` | `a75be894f9aa31fc0caef71526db9698255260f455089a48b2dc7657783ab494` |
| `FindAnUpgrade/Questie.lua` | `552277315e82bce02a77d054f9d8320554670caf60666e9662e149ba15b3e572` |

The private final receipt includes hashes for all eleven lifecycle modules
examined. Later patch-version metadata changes are outside those two behavioral
file hashes; further behavioral edits require another relevant re-review.

## Ownership and contracts traced

| Owner | Actual entrypoints and lifecycle |
| --- | --- |
| Core | One file-load event frame owns initialization, delayed native hookup, hover delivery, native-tooltip data updates and world/interaction dismissal. Its hover `OnUpdate` ends when both inspection and source are absent. |
| Character | Thirteen subscriptions mark identity/location/equipment/capability domains. Hidden consumers retain dirty flags without native captures or an updater. Visible bursts share one next-frame capture; `Ensure` can consume it synchronously and still publishes a visible transition. `Sleep` removes obsolete queued work. |
| QuestState | The sole owner of `QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`, `QUEST_REMOVED` and `QUEST_TURNED_IN`. It scans only the bounded native log and previously observed IDs. Hidden updates mark state stale. Explicit transitions use exact IDs and bounded deduplication; completion changes invalidate affected consumers without clearing unrelated metadata. |
| Search | Its event frame is constructed once on first use. Data-only events retain cache invalidations while hidden. Its updater is active for indexing, coalesced refresh, throttled metadata requests and current item inspection, and is removed at quiescence or hide. Open native menus defer layout; their release callbacks wake pending work. Hiding closes menus, item tooltips, copy UI and text focus. |
| Hover / Stack / NativeTooltip | Sessions have generations and exact source ownership. Dismissal ends item inspection and owned native supplements before hiding owned frames. Modifier changes retain native comparison semantics. Primary/comparison retries have deadlines and belong to the current item. Marker hide/leave and map hide invalidate only the relevant owner. |
| Sources / Questie | Native map callbacks and secure post-hooks attach once. Pooled marker identity and successful Questie render tokens distinguish replacement data. Marker hooks are additive and held in weak-key ownership tables. Global disabled gates need the correction above before eligibility resolution. |
| Launcher / Options | Launcher `OnUpdate` exists only during dragging and stops on drag completion or hide. Options closes menus, clears edit focus and stops moving on hide. Scale/display subscriptions remain owned by the reusable options frame. |

The current `QuestLogDocumentation.lua` was SHA-256 checked against the tracked
contract receipt for **Forever 1.60.1.70374**, revision
`735496de78ebd30ce816a0637982c556987f258c`:
`e637368f36d153f8b432455cfa247d0c67c84996dce8d591bc1eb4d1cd7bc098`.
It specifies a first and sole quest ID for `QUEST_ACCEPTED`, an ID followed by a
replay boolean for removal, and an ID followed by XP/money for turn-in. The
implementation consumes those shapes. It also marks `QUEST_LOG_UPDATE`
`UniqueEvent = true`. A deliberately synthetic burst of 100 same-frame log
events caused 100 scans in the mock; it is **not reported as a native defect**,
because that fixture bypasses the engine's unique-event contract. No new timer
or speculative throttle is justified by that artificial result.

Installed XPIsland and AsTheCrowFlies Core modules were read for their actual
frame/event ownership, additive hooks, deferred sampling, cleanup and settings
entrypoints. Questie's EventHandler and QuestEventHandler were read for current
membership/objective separation, bounded pending tracker work and owned retry
timers. Their broader tracking workload is not copied into this reward finder.
Installed-reference hashes are recorded in the private receipt below.

## Independent execution

Private harnesses and receipts:

- `.work/fresh-review/events/probe.py` and `probe.lua` execute actual shipped
  modules with explicit counters and event payloads. The existing fixture is
  used for native frame emulation; those counts do not claim native timing.
- `.work/fresh-review/events/baseline-result.json` preserves the original
  disabled-path failure and baseline module hashes.
- `.work/fresh-review/events/result.json` records the latest 16 focused probes
  and module hashes.
- `.work/fresh-review/events/run_suites.py`, `suite-results.json` and
  `suite-output.log` freshly execute the seven relevant existing suites in
  separate Lua 5.1 VMs: 189 scenarios passed in both the baseline and corrected
  runs. This is
  supplementary evidence, not a substitute for the independently demonstrated
  disabled-path failure.

The independent checks established these modeled outcomes:

- 1,000 hidden batches of quest-log, equipment, level and zone events perform no
  log/identity reads and leave no Character updater.
- 100 mixed visible character-event signals collapse to one capture and one
  publication; pending level state survives hide and is applied on reopening.
- 1,000 repeated initialization/attachment calls retain three event frames,
  two map callbacks and one hook per attached native script.
- Initial native attachment deferred by combat succeeds once after regen.
- 200 complete browser open/close cycles with a visible reward row retain the
  warm 28-frame allocation and leave neither Search nor Character updating while
  closed. The harness explicitly asserts that a result card is visible before
  testing reuse.
- Leaving the current source stops Core's hover updater.
- The visible finder retains current native gossip proof with NPC previews off.

## Boundaries

These checks establish inspected-source contracts and offline Lua lifecycle
behavior. They do not establish native event delivery order beyond documented
contracts, actual mouse/key input, engine frame allocations, font rendering,
combat/taint safety, or in-client CPU/memory cost. Those remain specific live
checks; no game session was started for this review.
