# Shortlist, chains and comparison performance review

Final result: **accepted for the reviewed source and offline lifecycle**. No
actionable performance or ownership defect remains from this independent review.
The final focused rerun passed **162 scenarios in 11 suites**. The final stress
pass began at `2026-10-15T20:23:03Z`; reviewed runtime hashes remained identical
before and after that pass. This reviewer changed only this review document.

## Scope and evidence

The review followed `Shortlist`, `Chains`, `SearchViews`, `Search`, `Stack` and
`Copy`, with their `Core`, `Character`, `QuestState`, `Hover`, `Options`, `UI` and
provider integration. It checked the actual constructors and event paths,
catalogue indexes, graph bounds, pooled rows, modifier/CVar/equipment changes,
item-load recovery, deferred copy dismissal, focus cleanup and hidden work.

Execution used fresh Lua 5.1 runtimes through the repository's Lupa 2.8 setup
and `tests/wow_mock.lua`. Comparison integration executes the pinned Forever
70374 native comparison-manager procedure with modeled engine responses. It
does not query a running game client. The client source revision is
`735496de78ebd30ce816a0637982c556987f258c`.

## Settled behavior rechecked

- Chain descriptions retain their owner and group headings, stop at 32 flat
  entries and depth 8, and handle cycles without recursive graph traversal.
  The reverse dependency index is retained by catalogue identity and replaced
  when that identity changes. Dependency reconciliation is capped at 10,000
  queued IDs. There is no row-owned ticker or idle chain updater.
- The per-character list, tabs, chain popup and copy dialog reuse their owned
  objects. Both views share the card pool. View, menu, options and parent-hide
  transitions clear the relevant inspection, popup and input ownership.
- Native comparison data and deltas remain owned by the native comparison
  manager procedure. Equipment changes invalidate the private candidate cache;
  CVar and modifier transitions reconcile it. Cold retries have a fixed time
  window, and unrelated or duplicate item events cannot perpetually extend it.
- Copy uses the native EditBox input path with additive handlers. A selected
  subrange can issue the platform's copy chord; a subsequent text, selection,
  focus, owner or generation change cancels that dismissal intent. Repeated
  delivery coalesces to one pending timer. A keypress is not treated as proof
  that the operating system clipboard changed.
- Missing prerequisite metadata remains unknown and inspectable. Completion
  still invalidates its dependent row. The earlier quest-state fixture that
  expected missing metadata to prove a block was corrected, then rerun.
  Optional fallback and ancestor-cycle corrections were included in the final
  chain and complete-catalogue stress passes.

## Final focused execution

Each suite ran in a fresh runtime, using its actual registered handlers and
the project's normal fixture initialization. All listed suites are included in
`python tests/run.py`; the complete release verification remains the owner's
separate `python tools/verify.py` step.

| Suite | Passed scenarios |
| --- | ---: |
| `shortlist_test.lua` | 13 |
| `shortlist_ui_test.lua` | 10 |
| `quest_chain_test.lua` | 15 |
| `copy_runtime_test.lua` | 13 |
| `equipped_comparison_test.lua` | 11 |
| `search_lifecycle_test.lua` | 22 |
| `quest_state_test.lua` | 16 |
| `character_constraints_test.lua` | 28 |
| `search_runtime_test.lua` | 16 |
| `native_contract_test.lua` | 2 |
| `options_test.lua` | 16 |
| **Total** | **162** |

These include comparison deadline and load-event floods, primary and comparison
renderer teardown, reassigned pooled rows, view/query/offset recovery, partial
copy selections, stale deferred callbacks, and cleanup through options changes.

## Independent stress execution

The UI stress pass reused the `shortlist_ui_test.lua` setup with 80 quests and
three saved IDs. After warming both views, it performed 1,000 alternating view
switches, 200 sessions that changed list membership and hid/reopened the finder,
then another 400 dedicated view switches. Each transition delivered a tick
0.3 seconds later. It subsequently settled 50 ticks and hid the finder.

| Workload | Observed result |
| --- | --- |
| 1,400 dedicated view switches plus 200 hide/reopen sessions | Owned fixture frames stayed at **89**: initial, high-water and final counts matched. |
| Settled finder and subsequent hide | Finder `OnUpdate` removed; **0** active `OnUpdate` handlers among fixture frames after hide. |
| `Describe` and `State` for all **5,672** bundled exact quest IDs | Maximum **32** description entries; **323** descriptions explicitly marked truncated. |
| 1,000 repeated dependency queries | The same reverse-index table was retained. |
| Replace catalogue identity with a different graph | Reverse index rebuilt and returned the new dependant without retaining the old graph. |

For the catalogue pass, character facts were fixed to explicit incomplete,
inactive and nonrepeatable states, keeping the graph workload deterministic.
The earlier graph pass had 394 truncated descriptions; **323 supersedes that
count after the settled optional and cycle corrections**. Both passes covered
5,672 IDs and respected the same 32-entry limit.

The frame count measures the portable fixture's created frames, not native
engine memory. It distinguishes stable frame reuse from continued allocation;
it does not establish native allocation size, garbage-collection cost or FPS.

## Reviewed runtime identity

SHA-256 values below matched before and after the final stress pass. Generated
`Data/Catalog.lua` is deliberately excluded: its provenance receipts were being
normalized to canonical LF separately, with final data/package hashes owned by
the complete verifier and delivery receipt.

| File under `FindAnUpgrade/` | SHA-256 |
| --- | --- |
| `Shortlist.lua` | `122951b59e298f37c38e47f6bf0336e5c6908bb1c63f775524af9d7b2ecc869d` |
| `Chains.lua` | `66fe21448a65ffc6de283307fa732a16ab9e048a5acf807d8fed1d9909b1e437` |
| `SearchViews.lua` | `755d0fb0cbe0160e41992eadf8e56eb7974b9b2b6d8cd5e2cdf388f0459437a0` |
| `Search.lua` | `e7258058fc0ad4b2bda8a97550cb2ea6e1b4ae145c6ce84eea286542dd4a8bfe` |
| `Stack.lua` | `085ada29b14998c4af315c92399c54bc925d20450be1eb49dca3a7029aee6a14` |
| `Copy.lua` | `8095ecada6ec448c6a385f5e464aa6d324c88feecc9925a5e3c7fb939ece3911` |
| `Core.lua` | `6fbe7899a9473824cf3a4aa36a7ec2555986d5d8336e45e58bbeaea0ff8fa704` |
| `Hover.lua` | `4555b6b2c561210bc0bbc2c06a39520d6e8f5802cab0fbcaeb0c6a8334bb417f` |
| `Character.lua` | `de02774f17b75214d4cd739bcab246471b37ed94999ee0e32235a0099d44914b` |
| `QuestState.lua` | `3582cdf8f9706b2155eebb0eecc5466f7366067c33cdac5abb4a69fa2966a86d` |
| `Options.lua` | `fb1874cd9060ced8ce94e6dfc81ec45ce92cfe716c1f8240d7b68ff140205b0e` |
| `UI.lua` | `457256c2d2733a7e9a1eaff14018608ac8375297519414779893a538f85812a2` |
| `Providers.lua` | `62610a2c9f36bb52c1140e1a41ddb43bafe10dd7d264ecead66784b23ccff1cc` |
| `FindAnUpgrade.toc` | `10dfe7a964dcbab4ff4347a470c0479a65fc412d37c4914df818d8b5d44a9897` |

## Live-client limits

No native CPU profiling, frame-time measurement, in-game rendering, physical
keyboard input, operating-system clipboard acknowledgement, combat/taint test
or coexistence session was performed by this reviewer. Real equipped-item
engine responses, Windows Ctrl+C/Mac Command+C dispatch timing, native pointer
transit and live visual acceptance remain client checks. The source and offline
counts above must not be described as live performance or input verification.
