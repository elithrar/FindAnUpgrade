# Final independent UI adversarial review

Reviewed the integrated tooltip, inspector, finder, settings and command changes
on 2026-10-15. The reviewer made no production edits; implementation owners fixed
the findings and the reviewer reran the original failure probes.

## Inputs and contracts

- Inspected all eleven supplied screenshots under `.work/ui-feedback/`:
  `111141`–`111145` (hover), `111411` (dropdown), and `111546`–`111550`
  (finder and website reference), with full names `image(20261015-N).png`.
- Read the TOC and `NativeTooltip`, `Stack`, `Hover`, `Sources`, `Questie`,
  `Core`, `Model`, `Options`, `UI`, `Search`, `SearchModel` and `QuestState`.
- Compared the installed XPIsland and AsTheCrowFlies dropdown constructors and
  installed Questie `TooltipHandler.lua`, `MapIconTooltip.lua`, `Tooltip.lua`
  and `TooltipLayout.lua`. Their files were read without modification.
- Checked the Forever 1.60.1.70374 source contracts pinned at
  `735496de78ebd30ce816a0637982c556987f258c`, including native dropdown input,
  outside-click dismissal, tooltip templates and data/comparison processing.
  The [matching native hide handler](https://github.com/Gethe/wow-ui-source/blob/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua#L376)
  clears handler state and auxiliary content without clearing text rows. This
  supports testing a same-owner hide/show independently of a clear/rebuild.

## Findings fixed and independently reproduced again

| Trigger | Original consequence | Corrected behavior |
| --- | --- | --- |
| Another addon's secure `AddLine` post-hook appends its own row | Capturing `NumLines()` after the call adopted the foreign row; our supplement survived release | Capture the insertion index before append and verify exact text before owning it; preserve the foreign row |
| Native tooltip hides and shows without `ClearLines` | Hide discarded the token while leaving the supplement, then another supplement was appended | Clean only still-owned public text on hide and reuse its empty slot within the same clear epoch |
| Native hide occurs inside the append post-hook | The pending token had no recorded region when hide cleanup ran, leaving an orphan after the call returned | Aborted transactions also clean their verified region with hidden-safe identity checks |
| The same Questie marker successfully rebuilds with fewer grouped quest IDs | The active source retained quests removed from the current marker | Reconcile changed exact groups for the same marker owner and refresh only changed content |
| A successful Questie rebuild has no usable IDs or omits its primary ID | Early return kept the old preview open | Invalidate that owner's old source; unchanged-token/throttled renders retain their existing behavior |

An additional independent probe checks expanded-group and icon-pool reuse: a reused
card resets its expanded state and removes hidden reward hit targets. No defect
was found in that case. Probes and receipts are in
`.work/final-ui-adversarial/probe.lua`, `probe.py` and `results.json`.

## Integrated behavior checked

The default held-key preview adds one owned multiline block to the existing
public, unprotected `GameTooltip`. It retains original NPC/Questie text, owner,
anchors, scripts and mouse behavior. Inline textures are passive; releasing the
key opens the separate persistent inspector with native item/comparison
rendering and rarity borders. No interactive reward buttons are inserted into
the native tooltip. The None modifier and compact-inspector layout open that
inspector directly. Right-offset placement, screen clamping, source/tooltip/item
transit, bounded scroll, Escape, stale generations and comparison cleanup were
reviewed together.

The dropdown keeps the native intrinsic mouse-down handler, adds only edit-focus
cleanup, and installs no mouse-up toggle. Passive updates defer query/layout
while a menu is open; selection and deliberate dismissal retain native control.
The targeted regression executes the pinned intrinsic handler rather than
assuming an invented click sequence. Native menu text uses an owned font object,
matching XPIsland/ATCF and avoiding writes to compositor-owned font faces.

Finder rows remove the screenshot's fixed empty footer columns and jammed item
names. Titles wrap and expose full text, reward names/details remain accessible
through native item tooltips, and guaranteed/choice groups stay distinct. Rows
and controls are reused. Quest/location context actions use the recorded starter
type and suppress unsupported coordinates or waypoints. The README matches the
actual slash commands, modifier/release/fallback behavior, settings and optional
Questie surfaces; it makes no live-verification claim.

The last integration pass also challenged native proof expiry outside marker
hide. The runtime reviewer reproduced a combat-dismissal path which cleared
`Sources.current` directly without invalidating finder results. Core cleanup now
uses the shared clear/notification path; ordinary NPC pointer departure can
retain the active inspector while dropping its source observation. Current map
availability also requires an explicit public `inProgress == false`. These
changes were reviewed with the state/runtime reviewers rather than treating a
missing value as proof. See [FINAL-STATE-ADVERSARIAL.md](FINAL-STATE-ADVERSARIAL.md)
and [RUNTIME-RECOVERY-REVIEW.md](RUNTIME-RECOVERY-REVIEW.md).

All six independent adversarial probes passed after the fixes. A separate rerun
of eleven focused suites passed 225 scenarios covering native augmentation,
stack layout, source-derived native widgets/geometry, item inspection, Questie,
finder lifecycle/input, settings and fonts. The execution receipt and reviewed
source SHA-256 values are in `.work/final-ui-adversarial/suites.json`; start and
end hashes match. An older finder fixture expected duplicate ready metadata to
make the UI dirty. It now changes real item/quest names before asserting an
update, preserving the interaction test while matching the meaningful-change
contract. Broader
meaningful quest-state and database validation have separate reviewers; these
counts do not replace their findings or the repository's full verifier.

## Remaining client evidence

No game reload, input automation or installation was performed by this reviewer.
Offline execution cannot establish native glyph metrics, emptied-row height
collapse, physical mouse timing, perceived appearance, in-game CPU or taint
safety. Targeted client checks remain for the single emptied native block,
inline texture wrapping, actual dropdown open/select/outside-click/Escape,
release handoff and pointer transit at Matt's scale and screen edges, Questie
rebuild ordering, long stacks, comparison layering, Ctrl/Alt and combat with
other tooltip addons. There are no remaining source-reproducible findings in
the reviewed UI snapshot.
