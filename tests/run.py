"""Execute shipped Lua under Lua 5.1 in fresh deterministic native API mocks."""
from pathlib import Path
import sys, time, json, hashlib
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".work/pydeps"))
from lupa.lua51 import LuaRuntime

start = time.perf_counter()
report = {"runtime": "Lua 5.1 via Lupa 2.8", "suites": []}
contracts = json.loads((ROOT / "docs/client-contracts.json").read_bytes())
native = ROOT / ".work/blizzard/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua"
report["pinnedNativeSourceIntegration"] = native.is_file()
current_paths = ["Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua", "Interface/AddOns/Blizzard_SharedMapDataProviders/QuestOfferDataProvider.lua", "Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua", "Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.xml", "Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.lua", "Interface/AddOns/Blizzard_APIDocumentationGenerated/CurrencyInfoDocumentation.lua", "Interface/AddOns/Blizzard_Menu/DropdownButton.lua", "Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.xml", "Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua"]
report["currentNativeSourceIntegration"] = all((ROOT / ".work/current-api" / path).is_file() for path in current_paths)
if report["currentNativeSourceIntegration"]:
    for path in current_paths:
        content=(ROOT / ".work/current-api" / path).read_bytes()
        expected=next(row["sha256"] for row in contracts["currentSnapshot"]["files"] if row["path"]==path)
        assert hashlib.sha256(content).hexdigest()==expected, "Current native source differs from its pinned contract snapshot"
    report["currentNativeSourceRevision"] = contracts["currentSnapshot"]["revision"]
if native.is_file():
    data = native.read_bytes()
    blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    expected = next(f["blobSha1"] for f in contracts["files"] if f["path"].endswith("Mainline/QuestFrame.lua"))
    assert blob == expected, "Native fixture differs from the pinned source"
    report["nativeSourceBlobSha1"] = blob
else:
    report["limitation"] = "Pinned native source fixture absent; portable mocks only"
for filename in ["model_test.lua", "runtime_test.lua", "independent_review_test.lua", "inspection_test.lua", "questie_test.lua", "font_test.lua", "options_test.lua", "eligibility_test.lua", "stack_layout_test.lua", "reference_ui_test.lua", "reference_widgets_test.lua", "native_contract_test.lua", "search_test.lua", "search_runtime_test.lua", "search_lifecycle_test.lua"]:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ROOT = str(ROOT).replace("\\", "/")
    lua.execute((ROOT / "tests" / filename).read_text(encoding="utf-8"))
    report["suites"].append({"name": filename, "scenarios": lua.globals().PASSED})
report["seconds"] = round(time.perf_counter() - start, 4)
(ROOT / "dist").mkdir(exist_ok=True)
(ROOT / "dist/test-results.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
