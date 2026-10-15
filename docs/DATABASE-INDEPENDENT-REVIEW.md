# Comprehensive database independent review

Review scope: the public HTML collector/parser, canonical reconciliation,
generated/package inputs, and the affected reward/search/card runtime. This
review reads the acquired inputs and executes isolated probes; it makes no
in-game rendering or taint claim. AGENTS.md and the installed
`wow-addon-development` skill's validation guidance were read.

## Findings sent for correction

1. **Known class restriction lost when authored metadata is rejected.** Exact
   quest 792 has `classes = exclude(WARLOCK, ALL_CLASSES)` at line 301 of the
   pinned authored Durotar source. The literal parser rejects that expression,
   removing the metadata row; the public record still supplies four choice
   rewards and no class restriction. The compiled constraint explicitly lists
   every original class except WARLOCK. Applying compiled constraints only to
   surviving metadata records misses the quest. The resulting search can show
   those rewards to a Horde warlock. Canonical identity/rewards must survive,
   while the separately verified compiled constraint is retained.
2. **A third occurrence can restore a conflicted restriction.** Independent
   controlled parser results Alliance/Horde/Alliance for one ID show that the
   second occurrence clears the faction, then the third adds Alliance again.
   The conflict is recorded but source order still selects the restriction.
   Evidence: `.work/database-review/sticky-probe.json`.
3. **A partial native reputation list erases other verified factions.** With
   two published ordinary reputation rows and one unrelated native major
   faction row, `Rewards.Recorded` returns only the native row because source
   fallback runs only when the native list is empty. The native contract is
   explicitly partial. Evidence:
   `.work/database-review/initial-probes.json`. Native per-faction authority
   should preserve independently identified published ordinary factions.
4. **Equal reputation amounts/order are not faction identity.** The initial
   reconciler attaches retained primary faction IDs to public names by `zip`
   and amount equality. Two equal awards can be reordered without detection.
   A name-to-ID association requires independent identity evidence; otherwise
   the verified public name/amount can remain without an invented ID.
5. **Imported constant dependencies need their source receipts.** Metadata
   reads `maps.lua` and `raceIDs.lua` before checking acquisition hashes and
   does not include them in its selected source receipt list. Native map IDs
   and race restrictions depend on these constants, so their acquisition
   hashes must be checked and retained.
6. **Restriction rejection erased independent giver facts.** After the class
   list was recovered, quest 792 still lacked its independently literal
   NPC 3145 and Durotar coordinates. Metadata parsing now preserves those
   independent facts, carrying each unresolved restriction to a separate
   compiled-field resolution or static-use guard. Quest 1049's exact numeric
   race restriction also resolves independently.
7. **Merged unresolved fields must accumulate.** Distinct occurrences carrying
   unresolved `classes` and `races` originally kept only the first marker.
   Their union is now retained, so a compiled class list cannot accidentally
   resolve an unrelated unknown race restriction.
8. **Search bypassed native item authority.** With native rewards ready but
   choices ambiguous/unavailable, `Rewards.Read` refused public fallback, but
   `SearchModel:Reward` re-added those choices through its pending list and
   `Search:Fill` displayed them as recorded rewards. The whole search path now
   suppresses that fallback whenever native rewards own the item set.
9. **Starter kinds require quoted literal tokens.** The new typed starter
   parser initially accepted `{n,123}` as if it were `{"n",123}`. It now rejects
   variable/expression kinds and records the unsupported field. Nested
   objective providers do not become quest starters.

## Independently checked behavior

- The actual retained public page for quest 682 preserves item 4741 in both
  guaranteed and choice groups. It is not deduplicated across groups.
- Cutting the actual page before its closing document produces unknown item
  rewards; requesting another exact quest ID from that page is also unknown.
- Published empty item lists and unknown lists are distinct in the runtime.
- Native readiness owns the complete item set: a native confirmed-empty set
  and an ambiguous native choice list do not fall back to class-unfiltered
  published choices.
- Per-item metadata cache copies preserve each reward occurrence's separate
  group and quantity instead of sharing mutable reward semantics by item ID.
- Native zero XP/money remain authoritative zero values rather than falling
  back to nonzero published base values.
- Native reputation wins by explicit faction ID or a resolved exact faction
  name. If native name identity is unavailable, the independently named source
  row stays explicitly published; no faction ID is guessed for it.
- Explicit item/object starter identities remain separate from NPC IDs and
  are not assigned unverified item-click/NPC coordinates.

## Review status

All nine findings above have been corrected and independently rechecked.
`python .work/database-review/review_probes.py` passes all 12 independent
cases, including the actual quest 792 canonical row and the complete search
authority path. Probes live outside shipped/test production files.

Frozen-input reconciliation reproduces 5,669 exact IDs, including all 5,633
public index IDs: 2,136 item-bearing records, 3,297 explicitly empty item lists,
and 236 unknown item lists. All 3,606 published item associations match their
frozen public lists exactly, with 2,623 distinct items. All public IDs are
retained. Giver/starter evidence covers 4,354 quests: 3,962 with NPC starters,
283 with object starters, and 490 with item starters (categories overlap).
Recorded native-map coordinates cover 3,389 quests.

The previous catalog changes for 134 existing quests: 84 quest/item pairs are
added and 89 removed. Fifty previously item-bearing rows now have explicitly
empty published item lists. The site's 85 scoped corrections have retained
primary-page corroboration; the additional full-index corrections use the
public source and are not claimed as newly primary-verified.

Independent reconciliation receipt:
`.work/database-review/final-data-review.json`. Reviewed canonical source
SHA-256: `cc0d077d854ed3e53ea35feed0a78366212d8c9f733f94e61537448ccfcde2bf`.
Reviewed report SHA-256:
`341c75f399bae0aa429ea77c6e68317894bfefccefbe5dd8c76f595f596a65a1`.

Final generated runtime checks load and index all 5,669 records under Lua 5.1.
The actual NPC 3145 starter is recovered. An independent typed-starter runtime
fixture confirms that item 123 and object 456 do not enter the NPC starter
index, while explicit NPC 789 does. `python tools/generate_catalog.py --check`
passes, and read-only `package.validate` passes for candidate version **0.1.4**,
including manifest/load order, Lua syntax, source regeneration, coverage and
license checks. Generated Lua SHA-256:
`60510a19b015619b639296cdd61e3233bbb2b3d9bc05b13b45cbf645ffea642d`.

No current known accuracy or runtime finding remains open in the reviewed
implementation. This review does not claim push, CI, archive installation or
in-game verification. Source evidence does not establish current server
availability, in-game rendering, or taint safety. The coverage report
explicitly lists missing per-ID fields and the specific acquisition limits;
those are not represented as verified zero data.
