# Changelog

## 0.1.12

- Add Goblin Switchblade, Mystic Heavy Armor Kit and Stromgarde Cuffs to their verified quest reward groups.
- Apply 49 exact quest name and level corrections from the published build 70790 cached catalog, including 14 outside the chart. Preserve unknown availability and unresolved reward groups.
- Name item 282315 Ancient Hilt while preserving its guaranteed association with The Ancient Hilt. Item stats continue to come from the native client.
- Retain original source receipts and per-record cached payload hashes; reject conflicting quest-title refreshes.

## 0.1.11

- Sync verified November 4–6 Quests updates: five new reward items, exact reward choices, eight quest level corrections, and The Ancient Hilt with its unnamed guaranteed item.
- Mark quests completed on turn-in and hide completed quests by default in Quests and Shortlist; turn off Hide completed quests in Options to inspect them again.
- Replace the selected tab underline with a gentle gold glow.

## 0.1.10

- Explicitly enable mouse input on custom options controls, including close/action buttons, checkboxes, fields and sliders.
- Update the bundled SomethingNeedDoing runtime to 0.4.3 for shared options input and aligned color swatches.

## 0.1.9

- Share options control styling with SomethingNeedDoing 0.4.2: consistent dropdowns, checkboxes, numeric fields, sliders and scrollbars.
- Preserve the two-column settings layout, native menus, existing saved settings and recovery after interrupted panel construction.

## 0.1.8

- Sync the October 29 Quest website corrections: add Weevil K. Neevil to My Little Friends, resolve three placeholder reward names, and correct three minimum levels to 35.
- Keep both Sign Me Up! item reward lists unconfirmed instead of claiming they are empty.
- Retain the original source snapshot and hash-bound website update evidence; reject conflicting future imports.

## 0.1.7

- Update the bundled SomethingNeedDoing runtime to 0.4.0; retain existing settings and UI ownership.

## 0.1.6

- Use SomethingNeedDoing 0.3.0 for core events, hooks and slash commands; preserve existing settings and gameplay behavior.

## 0.1.5

- Refresh saved quest titles and levels in Shortlist after player-level changes or metadata invalidation, using the same metadata cache as Quests.

## 0.1.4

- Publish only the current release's notes while preserving and verifying changelog history.
- Allow reviewed release tooling to validate and publish an unchanged older tag, with the same exact-source, archive, tag and upload checks.

## 0.1.3

- Leave keyboard movement available when opening or reopening `/fau`, including after typing in search.
- Use Blizzard's subtle clear-search icon in both Quests and Shortlist. Clearing refreshes results and releases keyboard focus.

## 0.1.2

- Add optional, passive quest-data recording with bounded separate storage, privacy filtering, manual JSON export and clear/pause controls in Options. Recording remains off until enabled.
- Add strict repository-local submission validation and read-only catalog comparison. Native observations remain review evidence; they do not replace published catalog facts.

## 0.1.1

- Keep the quest inspector to the right of the cursor when space permits, using vertical clearance around the game tooltip before switching sides. The inspector stays anchored while moving into reward icons.

- Align quest-card reward and warning footers with the card's left inset.

- Clarify the quest inspector position setting and document patch-version and release-tag requirements for contributors.
