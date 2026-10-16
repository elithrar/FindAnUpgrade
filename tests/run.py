"""Execute shipped Lua under Lua 5.1 in fresh deterministic native API mocks."""

import hashlib
import json
import time
from pathlib import Path

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

CURRENT_PATHS = [
    "Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua",
    "Interface/AddOns/Blizzard_SharedMapDataProviders/QuestOfferDataProvider.lua",
    "Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua",
    "Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.xml",
    "Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.lua",
    "Interface/AddOns/Blizzard_APIDocumentationGenerated/CurrencyInfoDocumentation.lua",
    "Interface/AddOns/Blizzard_Menu/DropdownButton.lua",
    "Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.xml",
    "Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua",
]


def fixture_evidence(root=ROOT):
    """Check every available pinned source, including partial caches."""
    contracts = json.loads((root / "docs/client-contracts.json").read_bytes())
    report = {}
    native = (
        root
        / ".work/blizzard/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua"
    )
    report["pinnedNativeSourceIntegration"] = native.is_file()
    available = []
    missing = []
    for row in contracts["currentSnapshot"]["files"]:
        path = root / ".work/current-api" / row["path"]
        if not path.is_file():
            missing.append(row["path"])
            continue
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"], (
            "Current native source differs from its pinned contract snapshot: "
            + row["path"]
        )
        available.append(row["path"])
    report["currentNativeSourceIntegration"] = all(
        path in available for path in CURRENT_PATHS
    )
    report["currentNativeSourceAvailableFixtures"] = available
    report["currentNativeSourceMissingFixtures"] = missing
    if available:
        report["currentNativeSourceRevision"] = contracts["currentSnapshot"]["revision"]
    if native.is_file():
        data = native.read_bytes()
        blob = hashlib.sha1(
            b"blob " + str(len(data)).encode() + b"\0" + data
        ).hexdigest()
        expected = next(
            f["blobSha1"]
            for f in contracts["files"]
            if f["path"].endswith("Mainline/QuestFrame.lua")
        )
        assert blob == expected, "Native fixture differs from the pinned source"
        report["nativeSourceBlobSha1"] = blob
    else:
        report["limitation"] = (
            "Pinned native source fixture absent; portable mocks only"
        )
    return report


def main(root=ROOT):
    start = time.perf_counter()
    report = {"runtime": "Lua 5.1 via Lupa 2.8", "suites": [], **fixture_evidence(root)}
    for filename in [
        "model_test.lua",
        "shortlist_test.lua",
        "shortlist_ui_test.lua",
        "quest_chain_test.lua",
        "copy_runtime_test.lua",
        "equipped_comparison_test.lua",
        "runtime_test.lua",
        "independent_review_test.lua",
        "inspection_test.lua",
        "questie_test.lua",
        "font_test.lua",
        "options_test.lua",
        "eligibility_test.lua",
        "provider_recovery_test.lua",
        "reward_browser_model_test.lua",
        "reputation_recovery_test.lua",
        "native_tooltip_test.lua",
        "stack_layout_test.lua",
        "reference_ui_test.lua",
        "reference_widgets_test.lua",
        "native_contract_test.lua",
        "search_test.lua",
        "search_runtime_test.lua",
        "search_lifecycle_test.lua",
        "quest_state_test.lua",
        "character_constraints_test.lua",
        "sidebar_design_test.lua",
        "sidebar_eligibility_test.lua",
        "filter_scope_test.lua",
        "reward_usability_test.lua",
        "ranking_test.lua",
        "complete_catalog_test.lua",
    ]:
        lua = LuaRuntime(unpack_returned_tuples=True)
        skipped = []

        def output(*arguments):
            message = "\t".join(str(value) for value in arguments)
            if message.startswith("SKIP "):
                skipped.append(message[5:])
            print(message)

        lua.globals().print = output
        lua.globals().ROOT = str(root).replace("\\", "/")
        lua.execute((root / "tests" / filename).read_text(encoding="utf-8"))
        report["suites"].append(
            {"name": filename, "scenarios": lua.globals().PASSED, "skips": skipped}
        )
    report["seconds"] = round(time.perf_counter() - start, 4)
    (root / "dist").mkdir(exist_ok=True)
    (root / "dist/test-results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
