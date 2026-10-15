# Alignment and settings behavior review

Independent review of the post-0.1.10 sidebar/settings iteration. The approved
design is retained. This report covers source inspection and Lua 5.1 execution;
it does not establish native rendering, physical input, clipboard transfer,
combat/taint safety or client performance.

Status: accepted for the behavior scope after the owner's global production
freeze. The final independent Lua 5.1 run passed all 28 scenarios. Production
and shared-mock SHA-256s were captured before and after that run and were
identical; no unresolved substantive behavior finding remains.

## Evidence and method

Read the current `AGENTS.md`, WoW addon skill and its client, profiles,
UI/settings and validation references. Reviewed the current alignment, settings
and search/copy contract plans, affected production code and TOC load order.
Used fresh Lua runtimes and the shipped constructors/handlers, rather than
accepting the authors' existing test claims. The independent probe files are
under `.work/alignment-review/behavior/`; `run.py` records results and SHA-256s
in `results.json`.

The shared mock deliberately omits native EditBox focus transfer and the
inherited InputBox script defaults. The review adds those to a separate fixture
from the pinned `InputBoxTemplates.xml`/`.lua`: gained focus selects text, lost
focus clears selection, setting text invokes `OnTextChanged(false)`, and focus
transfers between owned fields. These probes exercise the actual registered
clear, numeric-edit, page-navigation and copy handlers. They model the documented
scripts; they are not native input observations.

## Current results

The independent suite currently passes 28 scenarios:

- Schema 3 migration preserves existing values, explicit false values and
  independently owned nested defaults. Mixed malformed values repair only their
  fields; finite offsets floor/clamp to 0–199, and nonfinite values use defaults.
- Future schemas retain the original SavedVariables object through normal
  mutation, nested-default mutation, Reset and options controls. They remain
  read-only and preserve the existing explicit disable behavior.
- New search opens in Same zone, with usable filtering, no dungeon additions,
  and current level −5/+3. Every hidden-to-shown opening reapplies saved defaults
  and a newly computed range; query, slot, scope and sort retain session values.
  Changes while visible do not replace temporary filters or manual bounds.
- Reset restores appearance on the next owned update and leaves active temporary filters
  until the next opening. Reload reconstructs normal transient state from the
  normalized saved preferences.
- Numeric Enter validates; Escape and page navigation discard unfinished edits.
  Twenty repeated three-page navigation/reopen cycles create no additional
  frames or FontStrings, no new menu generations and no saved-data writes.
- A font-registry update while the native font menu is open preserves that
  description until release, then generates the latest list once and removes
  the pending updater. Hiding/reopening also clears pending work. Long Unicode
  font names abbreviate only the selected display at 12 units without scaling;
  full saved/menu identities remain intact.
- Missing selected media names remain saved. A late SharedMedia registration
  reconciles all owned text and the dropdown, with two callbacks registered once
  per library. The native tooltip font objects stay unchanged.
- Under the actual Windows `English_United States.1252` ctype locale, the probe
  reproduces the old `%c` rejection of UTF-8 continuation byte 173 in `中`.
  The corrected validator accepts an exact 104-byte Chinese font preference
  through both validation and load, while rejecting ASCII controls 0–31, DEL,
  markup pipes and overlong names. This is locale execution, not merely a
  different Unicode sample under the default fixture locale.
- Body-font choices leave the Search item-level/count and compact-inspector
  quantity overlays on `NumberFontNormalSmall`, preserving its face, size and
  outline. Specialized numerals are excluded from the ordinary text registry.
- Border None preserves panel background/geometry and the settings dialog.
  Strict backdrop setters require all four RGBA channels and preserve them
  through None/Dialog/Tooltip/Thin/Default. Owned NineSlice centers remain shown;
  None makes only the native edge transparent, explicit replacements use one
  edge-only overlay, and Default restores original edge RGBA.
- Scale changes retain the existing logical anchor and temporary filters while
  fitting the modeled viewport. The physical clamping/rendering boundary remains
  a client check.
- The query clear control handles the native programmatic text event with one
  query invalidation, clears query/offset, preserves other filters and restores
  focus. Clicking an empty clear control has no extra invalidation.
- Native selected-text Copy preserves exact strings, reuses one dialog, and
  releases focus through Enter, Escape, direct hide and parent hide. All four
  context-menu Copy actions enter that same flow with exact coordinate, quest
  ID, verified starter-name and Forever URL values. No clipboard/debug API or
  chat operation is invoked.
- Neutral item/quest names force gun, one-/two-handed sword and wand matches to
  use real native class/subclass evidence. Slot and known-usability exclusions
  still apply. Cold instant metadata avoids full-info reads; subtype-only
  callbacks recover exact matches, equal callbacks remain idle, and hidden
  callbacks invalidate without hydration. Unknown/contradictory classes receive
  no invented English aliases.
- Location labels use literal U+2022 separators, omit missing components and
  retain `Starts from` for item starters.
- Actual card fill changes only required-level evidence to `Req. lvl X` and
  retains useful `In quest log` state. Absent evidence is hidden.

## Findings and disposition

No unresolved substantive behavior defect has been identified in the current
probed implementation. Cross-review identified that the new blanket font
registry also captured native reward numerals, changing their face and outline
even with the default preference. The owner confirmed the planned native-number
exception; the authors removed those registrations. An independent constructor
probe now verifies that body-font changes leave those specialized roles intact.

The owner's full-suite pass also exposed a Windows-locale validation defect:
`%c` classified a valid UTF-8 continuation byte as a control. The independent
review reproduced that original predicate failure under the actual system
locale and accepts the explicit ASCII-control replacement described above.

During review, the owner identified the backdrop
multi-return defect: wrapping `Adapter.Call(GetBackdropColor)` retained only the
first channel. The independent strict-RGBA probe accepts the corrected direct
protected call and four-channel validation. The initial NineSlice approach was
superseded while this review was running; the final probe explicitly requires
the native center/background to remain visible and unchanged.

No production files or shared tests were changed by this reviewer. Native
pixel alignment, actual font fallback/rendering, dropdown physical input,
Ctrl+C transfer, effective-scale clamping and combat/taint remain pending live
checks.

## Stable acceptance hashes

These hashes bind the final behavior run to the frozen source. The full
19-module/TOC/shared-mock hash set is recorded in the private execution receipt.

| File | SHA-256 |
| --- | --- |
| `FindAnUpgrade/Core.lua` | `d98d51d57fd79100442ce9ae638c8ac9be3797ce2eadaaa336a7e6d06b103491` |
| `FindAnUpgrade/Model.lua` | `a655186a304fe0365baf7f4e61b83fddc0c8be20ac51144dc5a4c0c1b43a0099` |
| `FindAnUpgrade/Options.lua` | `69ae45d516af7ee60cd862589a593b5dee4365766429029b605a10cad1a7719d` |
| `FindAnUpgrade/UI.lua` | `317eed8208777b5dbbc5e1b02953c9f45e8bb83784c4c292e802a7ac753468e1` |
| `FindAnUpgrade/Search.lua` | `23a74d4b8af5beff3d45f64dec0c904ee14cdb3eedc711386bacddccfae20884` |
| `FindAnUpgrade/SearchModel.lua` | `78d2350efe963c3e83775c479f766a5b656c2d123b55f1f1e6114a89b61bec7a` |
| `FindAnUpgrade/Stack.lua` | `6c97f99ebbdc7ec084fc5ab34536a3ce60c968283f54ba1be56fae9582e743bc` |
| `FindAnUpgrade/FindAnUpgrade.toc` | `6ca68d2756e1599177372a31653f467760f24303310fe9f30b8342360fa8d54b` |
| `tests/wow_mock.lua` | `0a60bdda438a11d9d94bc1b8d02168ad72a90a0d8c2823ab6cd7dc16a2b9eb97` |
