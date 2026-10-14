# Bundled reward catalogue plan

The reward finder will read QuestBrief's bundled catalogue without Questie or
QuestieDB. Questie's optional marker integration remains separate. The installed
0.1.0 build is replaced only by a separately authorized installation of the
verified merged package. Installation receipts record that outcome.

## Sources and boundaries

1. Pin ATTWoWAddon/AllTheThings at
   `d75383ccdbff1208b87cf4024fa425c0825a7ad6`. Review its MIT grant and the
   dedicated `.contrib/.db/forever/` authoring files before importing numeric
   quest IDs, direct reward item IDs, explicitly recorded constraints,
   prerequisites, questgivers and coordinates. Include the complete MIT notice
   with the separately attributed data component. Do not run harvesters or copy
   addon code, artwork, lore, guides, full comments or raw external harvest
   output. Short exact-ID quest/item/NPC identification labels may be retained
   under that MIT grant; native names take precedence when ready.
2. ATT's Forever configuration identifies `1.60.1.69893`. Record that source
   snapshot separately from QuestBrief's target `1.60.1.70374`, interface
   `16001`. Imported records are not current live-client verification.
3. Preserve the existing `data/primary-statuses.json` as the sole classification
   authority. Reward catalogue membership never assigns a New or Modified tint.
   Native APIs hydrate current item names, equipment slots, rarity, icons and
   tooltips. Missing item metadata remains pending or unconfirmed.
4. Existing Wowhead research establishes exact Forever quest links, but its
   public tooltip embedding is not an offline database export grant. Do not
   scrape it or import its reward compilation into this feature. Client files
   may be inspected read-only; do not infer questgiver or reward facts from
   tables that do not encode those relationships.

## Reproducible pipeline

- Traverse the actual recursively loaded Forever authoring inputs, including
  `zzOLD` and expansion features. A folder name is not a retirement rule.
- Cross-check every direct authored quest/item pair against numeric membership
  in the pinned XML-loaded Camelot output, including reviewed item-backed recipe,
  mount, pet and toy transformations. Compiled-only item children are not
  reward evidence: the compiler also promotes objective component tables. Keep
  the cross-check's input hashes and reproduce it with `tools/check_membership.py`.
  The compiled output has no embedded build stamp; its same-pin source config
  identifies 69893, and this cross-check is not a reproduced 70374 build.
- Keep a reviewed, minimal numeric input snapshot in `data/`, together with
  revision, source paths, SHA-256 hashes, field semantics and source license.
- Implement an allowlisted parser and deterministic generator. Never execute
  upstream Lua or interpret arbitrary source expressions. Omit records with
  unsupported class/race constraints; omit other unsupported fields with an
  explicit uncertainty flag and diagnostic. Reject conflicting known eligibility
  constraints until independently resolved. Record each omitted record/field.
- Generate `QuestBrief/Data/Catalog.lua` and a machine-readable coverage report.
  Validate positive exact IDs, bounded coordinates with native UiMap IDs,
  explicit eligibility constraints and each reward association.
- Direct item children establish an association. Unless explicit source schema
  proves quantity and guaranteed versus choose-one status, leave both unknown.
  Do not default a reward quantity to one, synthesize zero money/XP/reputation,
  treat all alternatives as guaranteed, or sum exclusive choices.
- Direct item children can also document inputs and intermediate components.
  Exclude objective/provider/cost references, issued items, transitive acquisition
  components and item nodes with acquisition facts before the compiled gate.
  Preserve per-pair exclusions so a repeated occurrence cannot reintroduce them.
  Unresolved class/race restrictions reject the entire exact quest across source
  occurrences. Unsupported prerequisite thresholds leave the group unknown.
- Per-record source references permit later correction. Preserve conflicting
  locations separately; disable waypoint actions for unverified map/coordinates.
- Normal updates select a new pinned revision, review its source/license changes,
  regenerate, compare coverage and run the offline verifier. Independently
  captured native facts must identify the exact client build, quest ID and
  observation context before enriching the snapshot.

Current guarded coverage is recorded in `data/catalog-coverage.json`, and
`data/catalog-sources.json` records each exclusion and source receipt. Unsupported
class/race expressions exclude exact quests; unsupported optional metadata stays
unknown with explicit omission records. There are no static reward quantities,
choice groups, money, XP, currency or reputation amounts in this source.

## Runtime and validation

Load the catalogue before its read-only adapter. Build indexes incrementally only
while the finder is open. Use native completion/availability checks, class and
faction constraints where explicit, and concise uncertainty labels elsewhere.
Show Level fit until role-aware upgrade scoring is defensible. Native rewards
override recorded associations when their exact quest data is ready.

Tests must open and query production catalogue records with Questie and
QuestieDB absent, reject malformed or mismatched source facts, reproduce the
generated output, and exercise filtering, pending item data, menus, dismissal,
scrolling, tooltips, launcher persistence and bounded background work. Independent
data/license, API, UX, adversarial and package reviews precede the PR.

Native appearance, input coexistence, current reward amounts, NPC coordinates
and combat/taint behavior remain pending in-client checks until actually observed
in the official Forever client. The current user authorization permits reviewed
merge and installation; it does not authorize a release, tag or publication.
