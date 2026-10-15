# Reward amount evidence

The 0.1.6 baseline had 5,672 exact quest identities: 5,433 published Forever
records and 239 historical or unconfirmed candidates. Amounts in the public
Forever panels were distinct from player-specific native rewards. A blank
amount field did not establish a zero award.

## Parser repairs

`tools/catalog_html.py` now accepts the source's explicit unsigned zero
reputation lines, such as `0 reputation with Gelkis Clan Centaur`. The old
parser required a `+` or `-` prefix and silently skipped these observations.
Reparsing the complete retained corpus recovers **64 zero-valued faction
observations across 55 quests**. Six previously unknown reputation lists become
known: **91899, 91900, 91901, 91904, 91905 and 91906**. Another 49 existing lists
gain their missing zero-valued entries. This does not invent positive rewards.

The source also explicitly displays negative money on **70 quests**, for
example `-1g -3s` on quest 2945. Those **10,300 copper are a cost**, not a reward.
The importer retains `moneyCost` separately and does not replace missing money
rewards with zero. It accepts complete labelled coin units, rejects duplicate
or mixed-sign units, and keeps base amounts in copper.

Explicit malformed amounts and duplicate XP/money lines stop staging. Commas
must group thousands correctly: `1,450` is accepted; `1,,450` is not. Item lists,
Classic Era panels, objectives and change summaries cannot supply Forever
reward amounts. The new regression tests exercise the actual detail parser and
retained primary importer, including absent fields, explicit zeros, negative
reputation, costs, span-split coins and exact quest identity.

Independent review found that a missing title closing tag could hide the
reward block under the title while the tolerant HTML parser still produced a
published empty item list. Panel nodes now retain explicit closing-tag and
malformed-nesting evidence. Unclosed descendants, closing-ancestor recovery
and unmatched closing tags fail staging; supported self-closing/void elements
remain valid. All **5,633 retained detail documents** still parse (5,433
published, 200 explicitly unconfirmed), and the malformed-panel regressions
reject the false-empty cases. No repaired markup is treated as complete data.

Retained primary HTML also omitted `reprewards` on **48 of 135 pages**. The old
importer emitted an empty list anyway. `primary_reward_values` now preserves an
absent key as unknown and accepts an empty list only when explicitly encoded.
The retained primary pages contain no additional explicit XP/money values
beyond those already in the public panels.

The audit also inventoried the complete website worktree outside dependency
folders, rather than stopping at its 135 primary detail pages. The outdoor
evidence archive contains 46 files; the confirmed implementation archive
contains 15. Their raw rendered rows and every retained `sourceCells` variant
across the provenance JSONs supply **13,044 observations of 3,235 exact IDs**.
Of **2,824 IDs with displayed XP**, 2,600 match the detail amounts and 224 are
exactly five points higher. All 224 differences match rounding up to the next
ten, which is evidence of a presentation difference, not a more exact base
amount. None supplies XP where the detail catalog has none. The retained
Stranglethorn accessibility snapshot identifies `cells[6]` as `Exp.` and
`cells[7]` as `Money` (zero-based); flattened money cells omit coin units. A value
such as `3 50` cannot establish copper units and is not imported as 350 copper
or 3 gold 50 silver by assumption.

Every imported public row retains the exact URL, source SHA-256 and byte count
in [catalog-public-records.json](../data/catalog-public-records.json). Primary
receipts remain in [catalog-primary-records.json](../data/catalog-primary-records.json).
Normal `sync_catalog.py reparse` and `refresh` use these parser repairs, so they
persist without a hand-maintained per-ID reward patch. Run the focused checks
with `python tests/reward_amount_recovery_test.py`; the normal verifier includes
them as part of the full validation.

## Remaining source limits

All **4,399 displayed positive XP lines** and **1,130 displayed money reward
lines** in the retained public corpus were already parsed. No additional
positive XP or money is present in those visible Forever panels. The baseline
unknown counts therefore remain **1,273 XP** and **4,542 money rewards**; the
money count includes the 70 explicit cost cases. The reputation correction
reduces unknown lists from **2,454 to 2,448**, before any separately reviewed
source integrations. The 239 historical/unconfirmed candidates remain part of
those counts, not proof of currently obtainable quests.

Eighteen public records repeat a faction name in several reward slots without
explaining the effective award: 7604, 7788, 7789, 7871–7876, 8114, 8121, 8291,
8294, 8295, 8857–8859 and 9120. The evidence parser retains each observation;
it neither sums nor silently deduplicates them into a verified effective
amount. No retained primary page independently resolves these cases.

The installed QuestieDB 1.0.6 Forever artifact was inspected without executing
Lua or modifying the installation. Its reputation field has 52 values where
the baseline lacks a list, but 42 belong to unconfirmed quest identities. The
other ten belong to published identities (8484, 8485, 8579, 8595, 8784, 8945,
9259, 9266–9268). Forty-one overlapping lists disagree with the public source
before zero-line recovery; some are repeated source slots, others have
different faction amounts. This is separate source evidence, not permission to
overwrite current explicit Forever rewards. The source's 399/499/999 values
are not rounded or replaced with guessed 400/500/1,000 awards.

QuestieDB's `support/Forever/QuestXP/xpDB-classic.lua` is a legacy Classic XP
table with Classic/TBC/WotLK comparison comments. It offers 25 baseline gap
IDs (17 published, eight unconfirmed), but disagrees with 138 explicit Forever
XP values. Its directory name alone cannot establish current Forever XP.

Current Wowhead exact-page access failed in the available web tool; its robots
policy explicitly disallows GPTBot. No challenge or policy bypass was used.
The permitted local extraction already records encrypted QuestV2 rejection
and four empty plaintext tables. The current WDB reward layout is unverified;
an identity receipt is not reward decoding evidence. Neither cached static
evidence nor offline tests establish live native reward modifiers, rendering
or taint safety. Unavailable currency lists and other omitted amounts remain
unknown until an explicit reliable source is acquired.
