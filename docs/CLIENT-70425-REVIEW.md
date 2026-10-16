# Forever 70425 source contract update

MONOLITH's installed `WowB.exe` reports 1.60.1.70425; the read-only
`.build.info` row for `wow_classic_beta` agrees. This is installation metadata,
not a running `GetBuildInfo()` observation. The attempted 0.1.13 update stopped
at its 70374 build guard before staging, moving or writing addon/settings files.

The dedicated Gethe `forever` branch resolves to
`b401e0332adfbf0460d319b06d8ea29279a941f1`, whose `version.txt` is
`1.60.1.70425`. The current 13-file API/UI snapshot was downloaded from that
exact revision and compared with 70374. `client-contracts.json` records its
SHA-256/Git blob identities and preserves the prior snapshot. The historical
70338 detail-renderer fixture remains pinned independently.

Among current fixtures, only version.txt, DropdownButton.lua and
GameTooltip.xml changed. The dropdown adds `HasOnlyRadioDescriptions`; its
existing menu construction/input methods are unchanged. GameTooltip.xml adds
an OnUpdate to BuffFrameTooltip, outside this addon's owned tooltip templates.
Quest-log/reward/currency documentation, quest offer providers, comparison
manager, tooltip handler/templates/utilities remain byte-identical.

Four additional inspected files establish nearby behavior:

- Current QuestFrame.lua adds gamepad footer refresh and reorders gamepad cursor
  suspension. Quest-detail renderer hooks used by this addon are unchanged.
- QuestFrameTemplates.xml is unchanged.
- Auction-house shared templates add a sample-item-link tooltip path. The native
  favorite empty/filled atlas swap used by the shortlist star is unchanged.
- Input documentation adds cursor-center and visibility getters; existing
  modifier/copy-key APIs are unchanged.

The current `tools/update_local.ps1` guard now requires exactly 1.60.1.70425;
it does not accept arbitrary newer builds. All path, closed-client, prior-payload,
exact-source/package, backup and unrelated-addon/settings preservation checks
remain in place. The historical one-time 0.1.8 migration installer keeps its
original build/version guard and is not used for this update.

The changed native-source fixtures run in the ordinary Lua contract suites.
Source inspection and offline execution do not verify native rendering, physical
input, gamepad behavior, combat/taint, secret values or addon coexistence.
