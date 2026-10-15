# Upgrade ranking design

Research for the accepted FindAnUpgrade sorting iteration, 2026-10-15.
`FindAnUpgrade/Ranking.lua` now implements the conservative subset described
below. This is source and offline evidence; no API or final ranking behavior has
been observed in the game during this iteration.

## Implemented subset and limits

The native adapter rates plain cached armor, rings, passive stat-only trinkets
and held items when character usability, recognized stats, uniqueness and the
structured effect scan are complete. Exact equipped links retain suffix/enchant
identity; generic reward links with enchant/gem/suffix modifications are unranked
because `GetItemInfo(itemID)` does not prove that quest's exact roll. Sets,
enchants, sockets, proc/use/equip effects and unknown nonzero stat keys remain
unranked. Native weapons remain unranked until an actual Forever weapon damage
and speed contract can be established. The pure model covers hand configurations
so a future verified adapter cannot ignore lost off-hand gear.

The module exposes `Styles`, `Style`, `Usable`, `Quest`, `Interested` and
`InvalidateItem`, plus pure `Normalize` and `Compare`. `Usable` shares the native
`C_PlayerInfo.CanUseItem` fact with both lightweight filtering and full ranking.
It is memoized by the coherent identity/capability/equipment context. Explicit
false is distinct from unknown. The existing UI owns event delivery and requests;
the ranker owns no frame, timer, request scheduler or native tooltip mutation.

`InvalidateItem(id, snapshot, visible)` refreshes only retained observations of
that ID when visible and compares semantic states/stats/limits, including stats
readiness with unchanged `GetItemInfo` identity. Equal callbacks return false.
Hidden delivery only marks data dirty. Current gear dependencies remain tracked
even after their item-cache records are evicted. Context changes discard prior
metadata/memo contexts rather than accumulating each level or talent group.
Changed currently equipped exact-link metadata sends a sorted bounded stamp to
`Character:EquipmentMetadata` with the expected equipment revision. Its second
return value reports whether the central owner accepted that notification, so
the UI can defer to one coalesced Character refresh instead of querying twice.

The bounded metadata cache is **4,096 records per current context**, replacing
the initial 512-record proposal after independent review reproduced sequential
cache thrashing with 600 eligible rewards. The actual owned corpus contains
2,623 distinct reward item IDs; these plus 19 equipped variants fit the bound.
Unsupported/pending observations and usability interests have the same finite
retention limit. Arbitrary future variant sets beyond that bound may evict and
re-read records; no unbounded history is retained.

Focused verification currently has 47 Lua 5.1 scenarios, including the actual
native-adapter entry, a 600-reward warm scan with zero additional native item
reads, 1,000 warm comparisons without rescans, 1,000 hidden/unrelated callbacks
without native reads, capacity/eviction, stats-only readiness, semantic event
no-ops, capability changes and an evicted equipped-row recovery. Independent
review found and fixed shield-tank replacement with a held item and the initial
cache-thrashing/stale-evicted-baseline defects. Native sell-price content is
cosmetic; requests hide it where supported and the allowlist accepts it safely.
Pending reward and equipment tooltip observations retry on the next actual
query/reopen. No broad `TOOLTIP_DATA_UPDATE` listener or idle poll is introduced:
when the API returns no correlatable tooltip identity and no later item event,
that item remains not rated until a finder interaction requests a new query.
This recovery limit is explicit; native event timing remains a client check.

Weights are original, fixed heuristic preferences. Primary melee attributes
carry weight 1 with a smaller secondary attribute allowance; stamina is .25 for
damage and 1 for tanks. Caster intellect/spell power are 1/1.2; healer intellect,
spirit and healing are .8/.8/1. Shield and bear styles emphasize armor/stamina.
The module contains the complete values. They are estimated stat points and are
not simulation-derived Forever stat weights, DPS percentages or item levels.

## Product contract

`Biggest upgrade` compares a reward with **currently equipped gear**, using a
visible, selected playstyle's estimated stat weights. It ranks the best individual
reward improvement on a quest. It does not estimate DPS, optimize an entire
character, value unowned companion items, or sum mutually exclusive choices.
Item level remains useful on the icon, but is never the upgrade score.

Use positive **absolute weighted stat gain** as the primary ordering. A percentage
of the replaced item would favor tiny or empty slots artificially; an empty slot
must not produce an infinite percentage. Since one selected profile supplies a
common unit for every slot, absolute gain can compare a useful chest improvement
with a useful ring improvement. Any optional relative figure must be labeled
`stat score`, omitted for a zero baseline, and must not drive the default order.
The initial UI need not show percentages at all.

Keep sorting separate from scope. `Same zone` is a real default filter, rather
than a zone-first sort that silently includes every other zone. `Level range`
switches that scope. `Include dungeon quests` is additive to the selected scope
and still applies faction, class/race, level, completion, chain and starter-path
eligibility. An upgrade score cannot turn an unobtainable quest into a result.
Uncertain dungeon identity, chain availability or zone membership must not be
guessed from a reward's item level or a giver's coordinates.

## Verified target and sources

The contracts below were inspected at Gethe's mirror of Blizzard-authored source,
commit `735496de78ebd30ce816a0637982c556987f258c`, the already accepted Forever
1.60.1.70374 / interface 16001 contract. The local source receipt contains path,
Git blob identity, SHA-256 and byte size in
[`ranking-native-contract-receipts.json`](ranking-native-contract-receipts.json). These are source checks,
not live observations.

| Contract | Consequence |
| --- | --- |
| `C_Item.GetItemInfo(itemInfo)` includes equipment location, class/subclass, requirement and optional set identity. `C_Item.GetItemStats(link)` can return nothing and its table is not given a typed stat-key schema. | Require complete ordinary values; keep the exact hyperlink in cache keys; an item ID or item level alone is insufficient. Stat-key completeness needs a client fixture before claiming full coverage. |
| `C_Item.GetItemUniqueness` returns a category and limit; `GetItemUniquenessByID` separately returns uniqueness and optional category details. | Validate every resulting equipped configuration. Unknown returns are not proof of unrestricted equipment. A possession limit and an equip-category limit are distinct concerns. |
| `C_PlayerInfo.CanUseItem(itemID)` returns a character-usability boolean. | Share this lightweight native fact with the finder and ranking. Require cached item identity; false excludes a currently unusable option, while unavailable data remains unknown. It does not authorize an equip action or validate an invented paired outfit. |
| Camelot's paper doll reads `GetInventoryItemLink("player", slot)` and `C_PaperDollInfo.GetInventorySlotInfo`. | Snapshot actual equipped links and current empty-slot proof. Do not substitute an item-ID-only template for an enchanted or random-suffix equipped item. |
| Native comparison distinguishes `Single`, `WithBothHands`, `WithBagMainHandItem` and `WithBagOffHandItem`. | Native comparison data is a useful pairing signal, not a promise that a bag partner belongs in an equipped-only score. Never score a hypothetical missing partner as owned. |
| Structured tooltip line types distinguish requirements, use/equip/proc effects, enchants and sockets. | Detect unsupported effects without scraping another addon's rendered tooltip or replacing native hover. A partial effect scan must not assert that no effect exists. |

Primary source files:

- [Item contracts](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua).
- [Player item-usability contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerInfoDocumentation.lua).
- [Paper doll contracts](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/PaperDollInfoDocumentation.lua)
  and [loaded Camelot implementation](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua).
- [Native comparison contract](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipComparisonDocumentation.lua).
- [Structured tooltip types](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoSharedDocumentation.lua).

## Forever talent context

Do not map a returned specialization ID through Retail role presets. Camelot's
loaded talent visuals identify one class-wide specialization per supported class:
Mage 1482, Druid 1484, Hunter 1485, Paladin 1486, Priest 1487, Rogue 1488,
Shaman 1489, Warlock 1490 and Warrior 1491. These IDs distinguish classes, not
Fire versus Frost, cat versus bear, or healing versus damage.

The native Camelot talent panel uses
`C_SpecializationInfo.GetActiveSpecGroup()` and
`GetCombatConfigIDForSpecGroup(groupIndex)` for primary/secondary groups. Trait
configurations expose tree IDs; group display and currency APIs expose current
group expenditure. Display names, tree position and the largest spent-point
group alone do not prove the player's intended role. Do not use previewed,
uncommitted talents or whichever talent tab the user is inspecting.

Prefer one compact **Scoring style** choice in the sort menu, restricted to the
character's class. Examples are melee damage, ranged damage, spell damage,
healing, shield tank and bear tank. They describe intent without pretending that
Forever has Retail specializations. Preserve a selection for each character and
active talent group. A future exact node/spell-to-profile mapping must have a
matching-build receipt and an ambiguity fallback.

Safe initial fallback: use a visibly named class preset only when its role is
unambiguous, such as Rogue melee or Mage/Warlock spell damage. For hybrid classes
or unresolved context, leave comparisons unranked with `Choose scoring style`
in the sort menu until the user selects one. Default `Biggest upgrade` ordering
can still be selected while comparisons are unknown. Never infer the role from
gear, a dungeon role flag, shapeshift state, localized text or an old saved spec
ID. Temporary identity loss preserves the existing choice instead of overwriting
it; it cannot silently apply a different character's preset.

Sources: [Camelot flavor selection](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_PlayerSpells/Blizzard_PlayerSpells.toc),
[class identities](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentUtil.lua),
[talent groups](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua),
[specialization contracts](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua)
and [trait contracts](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua).

## Scoring and completeness

Define original, versioned heuristic weight tables in an isolated model. The
formula is `sum(normalizedStatAmount * selectedWeight)`. Explain in current docs
that these are leveling preferences, not simulation-derived Forever stat weights.
The sort menu should identify the active style and offer a short `Estimated stat
gain` description. Avoid a full stat-weight editor in this iteration.

An acceptable small preset family favors class-appropriate offensive stats, adds
a modest stamina allowance for leveling, and separates healing and tank intents.
Tank styles value armor/stamina/defense and their actual mitigation equipment;
healing values healing and mana sustain separately from spell damage. Physical
styles distinguish melee and ranged weapon contribution. Off-hand weapon damage
must have a separate weight and must not simply count as a second full main hand.
Feral weapon contribution needs its actual Forever rule and is unranked until
that rule is established. Do not import unreviewed Classic/Retail conversion
constants, hit caps, combat-rating coefficients or school-specific assumptions.

Normalize only an explicit allowlist of proven stat keys and units. Aliases must
be reconciled, rather than summed twice. A present unknown stat/effect, malformed
number, secret value, incomplete tooltip, random suffix without exact reward
variant, unknown weapon damage/speed contribution, set interaction or unmodeled
equip restriction makes that comparison **unranked**. A missing table is pending,
not an empty stat table; an empty equipment slot is zero only with native proof.
Item-level-derived pseudo-stats and a best random-enchant roll are excluded.

A static always-on stat effect may be admitted only after its contribution and
units are completely represented in the normalized stats. `GetItemSpell` alone
does not establish complete effect coverage. Until this is proved, use/proc
trinkets, set pieces and unsupported equip effects remain visible for native
inspection, with no numeric upgrade claim. Do not label a base-stat-only loss as
an actual downgrade when the removed item has an unmodeled effect.

Compare equipped and candidate **base gear** consistently if native base links
can be established without guessing; otherwise compare exact full links and
mark unsupported enchants/sockets unranked. Silently stripping enchant/suffix
fields from hyperlinks is unacceptable. Either choice must be documented in the
implemented adapter and its client evidence.

## Legal equipment configurations

For each reward enumerate the small set of legal replacements, evaluate resulting
equipment, and take the greatest valid gain. No equip action is ever performed.

| Reward | Required comparison |
| --- | --- |
| One ordinary armor slot | Candidate minus that equipped slot. |
| Ring or trinket | Test each of the two slots; keep the untouched partner and enforce item/category uniqueness over the resulting equipment. A duplicate of the retained unique item must replace that item, not the weaker other slot. |
| Two-handed weapon | Candidate with off-hand empty minus the equipped main-hand **and off-hand**. Reject a shield-required style; do not keep off-hand stats accidentally. |
| One-handed/main-hand weapon | Replace the main hand and retain a legal off-hand. From an equipped two-hander, compare the candidate with an empty off-hand; never invent a bag or future quest partner. |
| Off-hand weapon, shield or held item | Replace the equipped off-hand only when the remaining main-hand configuration is legal. An equipped two-hander supplies no legal partner; that proposed combination is unranked. |
| Flexible one-handed weapon | Test the main hand and, only with proved dual-wield capability, the off-hand. Apply hand-specific weights and main/off-hand restrictions. |
| Ranged weapon/relic | Use the actual Forever slot and class/proficiency rules. Do not inherit Retail's slot-16 ranged mapping. |

The comparison must preserve the whole equipment context for uniqueness, set
effects and prerequisites, even when only one slot's stats change. Known invalid
class, proficiency, level, faction or category combinations are ineligible.
`IsEquippableItem` means an equipment item exists, not that this character can
equip it. `IsUsableItem` is not by itself a complete hypothetical outfit validator.
The currently inspected generated contracts do not establish a complete
Forever dual-wield/Titan's-Grip/proficiency capability adapter. Avoid permanent
class/level guesses; validate an appropriate native contract or leave those
configurations unranked. Existing off-hand equipment is useful evidence about
the current outfit, not universal permission for every new weapon subclass.

## Quest ordering and reward groups

Keep guaranteed and choose-one groups distinct. The quest's score is the best
**single legal reward improvement** in the currently relevant slot filter. It is
not the sum of all choice rewards, all quantities, or hypothetical multi-quest
loadouts. An exact item present in both groups remains represented in both; its
score is not counted twice. This policy is deliberately bounded and transparent.
Two separate guaranteed items might together be useful, but the initial score
does not promise a joint optimization. Retain native inspection for that case.

Order these tiers deterministically:

1. Fully comparable positive estimated gain, descending gain.
2. Pending, unsupported or otherwise incomparable items, and non-gear rewards.
3. Fully comparable zero/negative gain, descending gain.

Within unknown tiers use stable level fit, title and exact quest ID tie breaks.
Never replace unknown with zero. A quest with one known positive option and
another unknown option can show the known positive result as `At least +N stat
score`; it must not claim that option is its definitively best reward. To avoid
extra row copy, retaining an uncertainty flag in the model and giving such a quest
the unranked tier is a simpler acceptable initial policy. The implementation must
pick and test one policy explicitly.

## Ownership, caching and performance

Use a separate item/gear adapter and pure ranking model. Reuse the established
XPIsland/ATCF pattern of one event owner, validated inputs, an owned coalesced
refresh and no idle per-row update. Do not hook general GameTooltip updates to
recompute all scores. Native item/comparison hover remains independent.

Snapshot at most the relevant 19 equipment slots when the finder opens or an
equipment signature changes. Cache normalized items by complete hyperlink,
effective player level, locale, source/build and adapter version; cache scores by
item signature, gear signature and style revision. Use bounded FIFO/LRU retention
(4,096 item records for the current owned corpus) and per-query scratch tables, not an unbounded
history. Never issue an uncached load from a sort comparator.

Apply quest eligibility and scope first. Request only unresolved reward items
from the eligible result set, with deduplication and a bounded visible-window
priority queue. Preserve the existing bounded request scheduler. Model pending
data separately and invalidate only affected records on a successful item-load
event; unsuccessful loads do not create ready zero-score items. Cache readiness
can change without changing item ID.

`PLAYER_EQUIPMENT_CHANGED(slot, hasCurrent)` invalidates gear scores after a
coalesced equipped-link check. `ACTIVE_TALENT_GROUP_CHANGED` and
`PLAYER_TALENT_UPDATE` invalidate context when the actual context signature
changes. Level changes invalidate scaling/requirements; spell/proficiency changes
invalidate legality only when those inputs are used. Quest-log objective noise
does not invalidate item stats or gear context. Hidden state marks revisions dirty
and cancels pending work; it does not scan gear, traits, quests or items. On reopen,
resolve once from the latest state. No polling, tooltip scanning or metadata
requests should remain active while hidden.

## Independent challenge cases

Use a pure Lua 5.1 model fixture and the actual event entry points. Include:

- Higher item level with worse relevant stats; lower item level with better stats;
  healer versus damage style; hybrid unknown context; group swap and unresolved
  identity preserving the saved selection.
- Known empty slot versus occupied-but-uncached slot; negative/zero stat score;
  equal scores; two aliases for the same stat; unknown key; malformed/secret data;
  exact random suffix versus unspecified variant; proc/set/enchanted baseline.
- Two unequal rings; unique candidate already in the stronger slot; shared
  unique category across different IDs; missing uniqueness metadata; retained
  equipment outside the paired slots carrying the limit.
- Two-hander replacing sword plus shield; one-hander replacing two-hander with
  no partner; off-hand offered against two-hander; main-hand-only versus generic
  weapon; unknown dual-wield capability; ranged slot 18; Feral damage uncertainty.
- Guaranteed plus choose-one rewards; same item in both groups (quest 682);
  quantity greater than one; two mutually exclusive weapons; one known positive
  option plus one unknown; non-gear reward retaining deterministic placement.
- Equipment/item/talent events in bursts, duplicated events, stale item callbacks,
  menu open during refresh, close/reopen, all pending metadata, repeated failures,
  bounded cache eviction, no API calls from comparator, hidden event bursts and
  no active idle callback/request queue after closing.

Client checks still needed: actual stat key/unit coverage, weapon DPS and speed
coverage, equip/unique API values and restrictions, random suffix links, effect
line completeness, talent initialization/group event timing, item-cache event
timing, native hover coexistence, combat/secret behavior and measured native CPU.
Source-identifiable defects and deterministic model behavior do not wait on those
checks. An unavailable contract causes a labeled unknown result, not a fake score.

## Working-addon references and reuse boundary

[Pawn's current source](https://github.com/VgerMods/Pawn/blob/master/Pawn.lua)
separates scales, item caches, paired slots and unknown tooltip content. Its current
Forever support is explicitly work in progress. It is a useful architectural
reference, not proof of this client's complete behavior; its license prohibits
copying an adapted implementation into this addon. No Pawn code or weight table
was copied.

[GearQuest Forever](https://www.curseforge.com/wow/addons/gearquest-forever)
documents per-style stat weights and comparisons rather than item-level sorting,
and warns that beta talent/item changes affect ranking. Its published description
also identifies expensive level refreshes. This supports a bounded on-demand
approach here; its All Rights Reserved implementation/data is not imported.

[GearedForever](https://www.curseforge.com/wow/addons/gearedforever)
documents class/faction filtering, quest chains and equipment comparison while
explicitly describing its weights as estimates. Do not claim reward discovery or
gear ranking is unique to FindAnUpgrade. The requested compact native surfaces
and exact Forever quest classification remain separate product strengths.
