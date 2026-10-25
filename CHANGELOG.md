# Changelog

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
