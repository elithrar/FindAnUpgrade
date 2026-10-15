"""Validate and reproducibly package a local candidate. Never install/publish."""
from pathlib import Path
import hashlib, importlib.util, json, re, sys, zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".work/pydeps"))
from lupa.lua51 import LuaRuntime

SHIPPED = {
    "FindAnUpgrade.toc", "Model.lua", "Shortlist.lua", "Copy.lua", "Chains.lua", "SearchViews.lua", "Data/Quests.lua", "Adapter.lua", "UI.lua",
    "Options.lua", "Core.lua", "README.md", "NOTICES.md", "XPISLAND-LICENSE.txt",
    "Rewards.lua", "Providers.lua", "Questie.lua", "Sources.lua", "Stack.lua", "NativeTooltip.lua", "Hover.lua", "QuestState.lua", "LICENSE",
    "Catalog.lua", "SearchModel.lua", "Search.lua", "Launcher.lua", "Character.lua", "Ranking.lua", "Data/Catalog.lua", "Data/ATT-LICENSE.txt",
}
RUNTIME = ["Model.lua", "Shortlist.lua", "Data/Quests.lua", "Data/Catalog.lua", "Adapter.lua", "Character.lua", "UI.lua", "Copy.lua", "Rewards.lua", "Providers.lua", "Chains.lua", "Questie.lua", "Sources.lua", "Stack.lua", "NativeTooltip.lua", "Hover.lua", "QuestState.lua", "Catalog.lua", "Ranking.lua", "SearchModel.lua", "Search.lua", "SearchViews.lua", "Launcher.lua", "Options.lua", "Core.lua"]
SOURCE_DIRS = ["FindAnUpgrade", "data", "docs", "tests", "tools", ".github"]
SOURCE_ROOT = ["AGENTS.md", "README.md", "plan.md", "LICENSE", ".gitignore", ".gitattributes"]
ATT_LICENSE_SHA256 = "955281b9174e0f66b08c8e83d31e0f38b2fcaa247ca3af92d1723d81a13cddfb"

def digest(data): return hashlib.sha256(data).hexdigest()

def validate(root=ROOT):
    addon = root / "FindAnUpgrade"
    actual = {p.relative_to(addon).as_posix() for p in addon.rglob("*") if p.is_file()}
    if actual != SHIPPED: raise ValueError(f"Unexpected addon manifest: extra={actual - SHIPPED}, missing={SHIPPED - actual}")
    toc = (addon / "FindAnUpgrade.toc").read_text(encoding="utf-8")
    metadata={}
    for line in toc.splitlines():
        match=re.fullmatch(r"##\s*([^:]+):\s*(.*)",line)
        if match: metadata.setdefault(match[1].strip().lower(),[]).append(match[2].strip())
    if metadata.get("interface")!=["16001"] or any(key.startswith("interface-") for key in metadata): raise ValueError("Wrong or duplicate supported interface")
    if metadata.get("savedvariables")!=["FindAnUpgradeDB, QuestBriefDB"] or metadata.get("savedvariablespercharacter")!=["FindAnUpgradeCharacterDB"]: raise ValueError("SavedVariables ownership changed")
    entries = [line for line in toc.splitlines() if line and not line.startswith("#")]
    if entries != RUNTIME: raise ValueError("Incorrect TOC prerequisites/load order")
    version = re.search(r"^## Version: (\d+\.\d+\.\d+)$", toc, re.M)
    if not version: raise ValueError("Missing semantic version")
    version = version[1]
    if metadata.get("version")!=[version]: raise ValueError("Duplicate semantic version")
    core = (addon / "Core.lua").read_text(encoding="utf-8")
    if f'version = "{version}"' not in core: raise ValueError("Core/TOC version mismatch")
    if (addon / "README.md").read_bytes() != (root / "README.md").read_bytes(): raise ValueError("Shipped README is stale")
    if (addon / "LICENSE").read_bytes() != (root / "LICENSE").read_bytes(): raise ValueError("Shipped license is stale")
    for module in RUNTIME:
        lua = LuaRuntime(unpack_returned_tuples=True)
        load = lua.eval("function(s, name) local fn, err=loadstring(s,name); return fn~=nil, err end")
        ok, error = load((addon / module).read_text(encoding="utf-8"), module)
        if not ok: raise ValueError(f"Lua 5.1 syntax: {error}")
    spec = importlib.util.spec_from_file_location("questbrief_generator", ROOT / "tools/generate_data.py")
    generator = importlib.util.module_from_spec(spec); spec.loader.exec_module(generator)
    expected = generator.render(json.loads((root / "data/primary-statuses.json").read_bytes()),generator.quest_taxonomy.load(root)).encode()
    if (addon / "Data/Quests.lua").read_bytes() != expected: raise ValueError("Generated data is stale")
    spec = importlib.util.spec_from_file_location("questbrief_catalog_generator", root / "tools/generate_catalog.py")
    catalog = importlib.util.module_from_spec(spec); spec.loader.exec_module(catalog)
    source, catalog_provenance = catalog.load_inputs(root)
    # The ATT component's original grant remains separately validated even when
    # the current catalog also contains independently sourced public facts.
    provenance = json.loads((root / "data/catalog-sources.json").read_bytes())
    expected = catalog.render(source, catalog_provenance)
    if (addon / "Data/Catalog.lua").read_bytes() != expected: raise ValueError("Generated catalog is stale")
    coverage = (json.dumps(catalog.coverage(source, expected), indent=2) + "\n").encode()
    if (root / "data/catalog-coverage.json").read_bytes() != coverage: raise ValueError("Catalog coverage is stale")
    license_rows = [row for row in provenance["files"] if row["path"] == "LICENSE"]
    if len(license_rows) != 1 or license_rows[0]["sha256"] != ATT_LICENSE_SHA256 or digest((addon / "Data/ATT-LICENSE.txt").read_bytes()) != ATT_LICENSE_SHA256:
        raise ValueError("ATT copyright, MIT permission and disclaimer must be retained unchanged")
    return version

def archive(path, files, root, prefix=""):
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for file in sorted(files):
            name = prefix + file.relative_to(root).as_posix()
            info = zipfile.ZipInfo(name, (2026, 10, 14, 0, 0, 0))
            info.create_system = 3; info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, file.read_bytes(), compresslevel=9)
    with zipfile.ZipFile(path) as z:
        if z.testzip(): raise ValueError("ZIP corruption")
        for file in files:
            name = prefix + file.relative_to(root).as_posix()
            if z.read(name) != file.read_bytes(): raise ValueError(f"ZIP byte mismatch: {name}")

def source_files(root=ROOT):
    files = [root / name for name in SOURCE_ROOT]
    for directory in SOURCE_DIRS:
        for file in (root / directory).rglob("*"):
            if file.is_file() and "__pycache__" not in file.parts and file.suffix != ".pyc": files.append(file)
    return files

def build(root=ROOT, destination=None):
    version = validate(root)
    destination = destination or root / "dist"; destination.mkdir(parents=True, exist_ok=True)
    addon_zip = destination / f"FindAnUpgrade-{version}.zip"
    source_zip = destination / f"FindAnUpgrade-{version}-source.zip"
    addon_files = [root / "FindAnUpgrade" / name for name in SHIPPED]
    archive(addon_zip, addon_files, root)
    archive(source_zip, source_files(root), root, f"FindAnUpgrade-{version}-source/")
    checksums = {file.name: digest(file.read_bytes()) for file in [addon_zip, source_zip]}
    (destination / "SHA256SUMS").write_bytes("".join(f"{sha}  {name}\n" for name, sha in checksums.items()).encode())
    receipt = {
        "addon": "FindAnUpgrade", "version": version, "interface": 16001,
        "candidateOnly": True, "published": False, "installed": False,
        "archives": checksums,
        "payload": [{"path": file.relative_to(root).as_posix(), "bytes": file.stat().st_size, "sha256": digest(file.read_bytes())} for file in sorted(addon_files)],
    }
    (destination / "package-receipt.json").write_bytes((json.dumps(receipt, indent=2) + "\n").encode())
    return receipt

if __name__ == "__main__": print(json.dumps(build(), indent=2))
