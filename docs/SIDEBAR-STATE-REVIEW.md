# Sidebar eligibility and lifecycle review

Independent review for the FindAnUpgrade sidebar iteration in `plan.md`.
Target: official Forever 1.60.1.70374 / interface 16001. Baseline: QuestBrief
0.1.7, commit `363a64df0350c39f5464a8240a603a4a95d19e50`.

The reviewer read the addon skill's client/source, validation and performance
references. Production files were not edited by this reviewer. Independent
probes live in `.work/sidebar-state-review/`; they execute the shipped Lua 5.1
through the repository's WoW mock. This is logic and modeled lifecycle evidence,
not live-client rendering, physical input, event timing, CPU or taint evidence.

## Eligibility

The original baseline reproduced these failures:

- `Providers.Availability`: an available map line or optional-provider marker
  returned before quest faction, class, race and verified prerequisite checks.
  A wrong-side quest could therefore enter the finder when given that evidence.
- `SearchModel.StartPath`: any native evidence returned before inspecting a
  known starter path. A current map line could admit a quest whose only known
  NPC starter belonged to the opposing faction.
- An unqualified duplicate starter row erased a qualifier on the same NPC.
  An exact NPC hover could also borrow a different eligible starter for the quest.
- A pending minimum-level result needed to leave verified prerequisites in the
  decision path; allowing inspection of a future-level reward must not bypass
  a verified incomplete chain.

The implementation now applies the hard constraints before generic map/optional
evidence, shares typed starter filtering across providers, finder and locations,
and preserves actual native log/fresh exact gossip authority over stale static
records. A missing qualifier is not inferred from map, race or NPC reaction.
Neutral/unqualified paths, correct alternatives and item/object starters remain
usable. Numeric IDs in different starter namespaces remain separate.

The independent probe currently passes all 23 cases. An adversarial projection
of map proof over all 5,672 source quests and both factions found 3,501 known
opposite-quest-faction admissions in 0.1.7 and zero after repair. This intentionally
contradictory projection is a guard test, not a count of real map offers or live
occurrences. Published source qualifiers are limited: 164 location records on
67 quests have explicit faction qualifiers; missing NPC faction is not invented.

## Controls and lifecycle

The reviewer reported a source-reproducible range-control mismatch: typing a
minimum level, then clicking a slot dropdown, cleared focus while leaving the
displayed number different from the applied filter. The author added validated
range commit/restore during that transfer; the original failure probe passes.
The old code displays 10 while applying 15 in the exact reproduced transfer;
the revised code displays and applies 10 (`range-comparison.json`).

Eight independent interaction/workload probes currently pass:

- 11,000 registered events while hidden: zero native quest/item/log reads,
  metadata or reward requests, finder queries and renders; no idle updater.
- 3,000 unchanged visible log/item/quest callbacks: zero queries, renders or
  requests after warmup.
- 1,000 cache changes interleaved with log callbacks while a menu is open:
  no query/render/request during the menu, one coalesced query on release.
- 100 warm slash/minimap reopen cycles, including scrolling and options warmup:
  one finder frame and stable pools of 111 frames and 146 FontStrings.
- Cog, `opts` and `options` use one settings panel; cog clears finder focus.
- Disabled finder and minimap paths reject opening until reenabled.
- Range field and applied filter agree after the original dropdown transfer.
- A faithful changed-size callback delivered from `SetSize` settles without
  recursive fitting. Thirty resize/scale cycles leave no idle updater or pool
  growth; the first warmup includes small/default/large panel sizes.

Evidence: `eligibility-results.json` and `lifecycle-results.json` under the
independent probe directory. `frozen-initial.json` records unchanged hashes of
every production Lua file before and after that complete probe run.

## Final integration boundary

**Accepted for the reviewed source and modeled runtime behavior.** The final
combined run passed 77 independent probes and 307 regression scenarios across
15 focused repository suites in 33.11 seconds. All 27 shipped payload files,
plus the shared WoW fixture, retained identical hashes before and after the run.
Every original failure described below was rerun after its repair. No remaining
source-reproducible eligibility, state, event, cache, entrypoint or lifecycle
blocker was identified in this scope.

The exact case inventory, suite counts, per-file hashes and success flags are in
`.work/sidebar-state-review/final-acceptance.json`; the suite details are in
`suites.json` alongside the independent result files. This review did not commit,
install, publish or modify production code. Package/installer checks and the
full required verifier remain the root workflow's responsibility.

Native text metrics, physical dropdown/focus/resize interaction, actual pointer
transit and combat/taint require the corresponding live-client checks.

## Character owner focused integration

The later Character/Core/QuestState/Hover integration was reviewed separately
while Search controls and ranking were still in development. Thirteen independent
cases and 26 owned Character scenarios pass with those four production files
unchanged throughout the run (`character-frozen.json`). Four concrete findings
were fixed by the author and rerun against their original failures:

1. `Character:Ensure` canceled a queued visible equipment update and consumed
   its facts with notifications disabled. A synchronous context consumer could
   leave displayed results stale. The registered equipment-event scenario now
   produces exactly one visible notification even when a consumer reads first.
2. Every cached quest lookup still entered an allocating `Flush`. One thousand
   repeated cached reads now enter zero flushes and copy zero quest maps, after
   the initial four native fact reads.
3. Metadata stamps retained every past equipped item. Three hundred exact gear
   replacements now retain one stamp for the current configuration.
4. A synchronous context read during equipment capture could cancel a newer
   level event queued during that capture. The owned update now drains the new
   identity transition without an unrelated reader. The author also covered a
   concurrent quest publication surviving non-quest capture.

Other exercised paths: old snapshots remain unchanged after replacement;
published active/offer maps do not alias mutable QuestState tables; explicit
incomplete `false` remains false; hidden event bursts defer hydration; exact
hyperlinks distinguish same-ID equipment; missing metadata stays pending rather
than empty; late replaced-item responses do no native work or revision churn;
and hidden reconciliation refreshes completion facts even when active/offer sets
are equal. These are registered-handler and owner-method probes, with a stubbed
visible consumer for isolation; full Search notification acceptance remains part
of the final integrated pass.

## Scope model focused integration

Eighteen independent model probes pass over a deliberately mixed 16-quest fixture:
both scopes, dungeon inclusion on/off and four ordering modes obey independently
specified membership sets. The fixture includes opposing quest/NPC constraints,
current/other/missing categories, resolved/unresolved chains, absent starters,
completed/historical/current-native quests, unknown levels and Raid versus Dungeon.
Changing sort does not change the set; giver location/title cannot manufacture a
primary category; missing zone identity yields a recoverable empty set.

The primary-cache taxonomy check also reproduces all 36 owned exact types,
including seven Dungeon records, against the already retained 135 exact HTML
pages and receipts. This establishes the imported subset, not comprehensive
dungeon coverage or live native tag availability. Evidence: `scope-results.json`
and the command `python tools/quest_taxonomy.py --check --primary-cache <owned
primary cache>`.

## Integrated fixes and entry points

Seven actual-query usability cases exercise the repaired **Hide unusable** rule.
Originally, a cached published Plate reward remained visible despite an explicit
current `C_PlayerInfo.CanUseItem=false` when native quest rewards were cold.
The shared cached item-use check now rejects explicit false from either native
reward evidence or current item-use evidence, preserves unknown, retains usable
choose-one alternatives and keeps a verified amount-only benefit useful. Turning
the option off still permits inspection. Evidence: `usability-results.json`.

The renamed lifecycle fixture contains 40 matching current-zone reward quests.
Its 12 cases include real registered slash, cog, minimap and event handlers:
`/findanupgrade` and `/fau` register one command function, old public command
registrations are absent, and all finder/settings entry points reuse their
respective panels. Profile tests preserve legacy explicit false, prefer an
existing new profile, retain a future schema verbatim in read-only mode and
leave the old global unchanged. The current warm pool stabilizes at 114 frames
and 147 FontStrings across 100 reopen cycles. Hidden 11,000-event and unchanged
3,000-callback metrics remain zero for query/render/request work.

The later world-entry review reproduced another integrated failure: a completed
quest outside the current log remained visible after `PLAYER_ENTERING_WORLD`
when identity, location and gear values were equal. The Character owner now
reconciles that separate quest-evidence family. The original registered-event
probe removes the row with one query, equal non-quest family revisions and
`QuestState.stale=false`; no intervening log-set change is assumed.

Four actual item-event paths supplement the independent pure-ranking review:

- Equipped stat readiness changes with the same ID/link/item-info fields:
  unknown comparison becomes +5 estimated gain; the shared equipment revision
  advances 1 to 2, with one result query.
- After forced normalized-cache eviction, changed equipped stats replace a
  prior +5 result with -10 through the registered item event and one query.
- Two thousand unchanged equipped-item callbacks cause zero queries and no
  equipment revision change.
- Two thousand hidden callbacks perform no stat/item-info reads, requests or
  queries; reopening uses the fresh -10 comparison.

The metadata-to-Character bridge was specifically checked: a private score
refresh without advancing the shared equipment revision was reproduced first
and failed the probe; the repaired bridge passes. Evidence:
`ranking-events-results.json` and `lifecycle-results.json` under the independent
probe directory. The combined final acceptance above reran every one of these
cases against the same stable payload.
