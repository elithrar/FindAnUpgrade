# FindAnUpgrade 0.1.11 review

This iteration addresses the user's sidebar alignment and settings feedback.
The plans in `ALIGNMENT-DESIGN-PLAN.md` and `SETTINGS-DESIGN-PLAN.md` were agreed
before implementation. They retain the compact sidebar, icon sizes, native
item/comparison tooltips, classification authority, character constraints and
item-level heuristic. No catalogue/classification facts or unrelated addons
are changed.

Implementation separates layout and retained-result restyling in `Search`,
verified subclass matching in `SearchModel`, saved schema validation in `Model`,
appearance/media ownership in `UI`, and native settings controls in `Options`.
The settings shell follows installed XPIsland; the dropdown lifecycle follows
the installed AsTheCrowFlies conventions.

Three independent reviewers execute fresh probes against actual constructors
and registered handlers. Their reports are:

- [Design and geometry](ALIGNMENT-DESIGN-REVIEW.md)
- [Behavior, settings and copy lifecycle](ALIGNMENT-BEHAVIOR-REVIEW.md)
- [Performance and retained ownership](ALIGNMENT-PERFORMANCE-REVIEW.md)

The final stable-file reruns pass 30 design scenarios, 28 behavior scenarios
and 40 performance workloads. Before/after hashes retain the frozen runtime
identity. These are offline/source acceptance results.

Concrete findings corrected during review include backdrop RGBA return loss,
preserving the native NineSlice center when replacing borders, ambiguous saved
scope copy, native dropdown atlas padding, long selected-font labels, locale-
sensitive rejection of valid UTF-8 font names, specialized numeric overlay fonts,
full search work on appearance changes, late native-family remeasurement,
repeated media resolution and font-registry scans while a menu remains open.
Each reviewer reran against stable affected files and bound their hashes;
draft findings alone were not accepted.

The required verifier passes all 17 commands: 543 Lua 5.1 scenarios in 27 suites
and 171 Python tests. CI, exact commit, archive hashes, changed files and
installation identity are recorded in the
final `dist/FindAnUpgrade-patch-0.1.11-receipt.json`. The development installer
compares every delivered file, preserves a backup of the preceding version,
and verifies unrelated addons and SavedVariables remain unchanged.

The parent reviewer reported actual observations from three new screenshots;
the worker could read metadata/OCR for all eight, but did not retrieve their
latest pixels. Independent geometry uses measured Expressway glyph advances
with modeled frame services, not a running game. Source and mocked execution
do not establish native rendering, physical input, Ctrl+C, effective-scale
rounding, item/comparison pointer transit, client CPU or combat/taint safety.
No current-candidate live verification, release/tag or CurseForge publication
is implied.
