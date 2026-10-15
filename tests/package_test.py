from pathlib import Path
import importlib.util, json, shutil, tempfile, unittest, zipfile
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("package", ROOT / "tools/package.py")
package = importlib.util.module_from_spec(spec); spec.loader.exec_module(package)

class PackageTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for file in package.source_files():
            destination = self.root / file.relative_to(ROOT)
            destination.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(file, destination)
        self.version = package.validate(self.root)

    def test_candidate_is_reproducible_and_payload_exact(self):
        first = package.build(self.root, self.root / "out1")
        second = package.build(self.root, self.root / "out2")
        self.assertEqual(first, second)
        for filename in first["archives"]:
            self.assertEqual((self.root / "out1" / filename).read_bytes(), (self.root / "out2" / filename).read_bytes())
        addon = self.root / "out1" / f"FindAnUpgrade-{self.version}.zip"
        with zipfile.ZipFile(addon) as z:
            self.assertEqual(set(z.namelist()), {"FindAnUpgrade/" + name for name in package.SHIPPED})

    def test_bundled_catalog_and_full_license_survive_both_archives(self):
        package.build(self.root)
        addon = self.root / "dist" / f"FindAnUpgrade-{self.version}.zip"
        source = self.root / "dist" / f"FindAnUpgrade-{self.version}-source.zip"
        with zipfile.ZipFile(addon) as z:
            for name in ["Data/Catalog.lua", "Data/ATT-LICENSE.txt", "LICENSE", "XPISLAND-LICENSE.txt"]:
                self.assertEqual(z.read("FindAnUpgrade/" + name), (self.root / "FindAnUpgrade" / name).read_bytes())
            self.assertEqual(package.digest(z.read("FindAnUpgrade/Data/ATT-LICENSE.txt")), package.ATT_LICENSE_SHA256)
        with zipfile.ZipFile(source) as z:
            prefix = f"FindAnUpgrade-{self.version}-source/"
            for name in ["FindAnUpgrade/Data/Catalog.lua", "FindAnUpgrade/Data/ATT-LICENSE.txt", "data/catalog-source.json", "data/catalog-sources.json", "data/catalog-coverage.json", "data/catalog-complete-source.json", "data/catalog-complete-sources.json", "data/catalog-reconciliation.json", "data/catalog-public-records.json", "data/catalog-metadata-records.json", "data/catalog-compiled-quests.json", "data/catalog-primary-records.json", "data/catalog-client-evidence.json", "tools/generate_catalog.py", "tools/import_complete_catalog.py", "tools/collect_catalog_sources.py"]:
                self.assertEqual(z.read(prefix + name), (self.root / name).read_bytes())

    def test_catalog_load_order_staleness_and_license_loss_are_rejected(self):
        toc = self.root / "FindAnUpgrade/FindAnUpgrade.toc"; original = toc.read_bytes()
        canonical = original.replace(b"\r\n", b"\n")
        self.assertIn(b"Data/Quests.lua\nData/Catalog.lua", canonical)
        reordered = canonical.replace(b"Data/Quests.lua\nData/Catalog.lua", b"Data/Catalog.lua\nData/Quests.lua")
        self.assertNotEqual(reordered, canonical)
        toc.write_bytes(reordered)
        with self.assertRaisesRegex(ValueError, "load order"): package.validate(self.root)
        toc.write_bytes(original)
        path = self.root / "FindAnUpgrade/Data/Catalog.lua"; original = path.read_bytes()
        changed = original.replace(b"schemaVersion=", b"schemaVersion=9", 1)
        self.assertNotEqual(changed, original)
        path.write_bytes(changed)
        with self.assertRaisesRegex(ValueError, "catalog is stale"): package.validate(self.root)
        path.write_bytes(original)
        path = self.root / "data/catalog-coverage.json"; original = path.read_bytes()
        coverage = json.loads(original); coverage["liveClientVerified"] = True
        path.write_text(json.dumps(coverage))
        with self.assertRaisesRegex(ValueError, "coverage is stale"): package.validate(self.root)
        path.write_bytes(original)
        path = self.root / "FindAnUpgrade/Data/ATT-LICENSE.txt"
        path.write_text("MIT label without the copyright, permission or disclaimer")
        with self.assertRaisesRegex(ValueError, "MIT permission"): package.validate(self.root)

    def test_source_excludes_dependencies_references_credentials(self):
        for directory in [".work", "references", ".library-transfer", ".git"]:
            path = self.root / directory / "private.txt"; path.parent.mkdir(); path.write_text("must not ship")
        package.build(self.root)
        with zipfile.ZipFile(self.root / f"dist/FindAnUpgrade-{self.version}-source.zip") as z:
            self.assertFalse(any("private.txt" in name for name in z.namelist()))

    def test_stray_shipped_file_is_rejected(self):
        (self.root / "FindAnUpgrade/surprise.lua").write_text("print('unreviewed')")
        with self.assertRaisesRegex(ValueError, "Unexpected addon manifest"): package.validate(self.root)

    def test_wrong_client_and_load_order_are_rejected(self):
        path = self.root / "FindAnUpgrade/FindAnUpgrade.toc"; original = path.read_text()
        path.write_text(original.replace("16001", "120001"))
        with self.assertRaisesRegex(ValueError, "interface"): package.validate(self.root)
        path.write_text(original.replace("Model.lua\nData/Quests.lua", "Data/Quests.lua\nModel.lua"))
        with self.assertRaisesRegex(ValueError, "load order"): package.validate(self.root)

    def test_version_mismatch_is_rejected(self):
        path = self.root / "FindAnUpgrade/Core.lua"; path.write_text(path.read_text().replace(f'version = "{self.version}"', 'version = "999.999.999"'))
        with self.assertRaisesRegex(ValueError, "version mismatch"): package.validate(self.root)

    def test_saved_variables_cannot_add_duplicate_or_foreign_owners(self):
        path = self.root / "FindAnUpgrade/FindAnUpgrade.toc"; original = path.read_text(encoding="utf-8")
        for declaration in [
            "## SavedVariables: FindAnUpgradeDB", "## SavedVariables: QuestieDB",
            "## savedvariables : QuestieDB", "## SavedVariablesPerCharacter: FindAnUpgradeDB",
            "## SavedVariablesPerCharacter: QuestieDB", "## savedvariablespercharacter: ",
        ]:
            with self.subTest(declaration=declaration):
                path.write_text(original + "\n" + declaration + "\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "SavedVariables ownership"):
                    package.build(self.root)
                self.assertFalse((self.root / "dist").exists(), "Invalid metadata produced package output")
        path.write_text(original, encoding="utf-8")
        self.assertEqual(package.validate(self.root), self.version)

    def test_duplicate_and_flavored_interface_metadata_cannot_package(self):
        path = self.root / "FindAnUpgrade/FindAnUpgrade.toc"; original = path.read_text(encoding="utf-8")
        for declaration in [
            "## Interface: 16001", "## Interface: 120001",
            "## interface : 16001", "## Interface-Camelot: 16001",
        ]:
            with self.subTest(declaration=declaration):
                path.write_text(original + "\n" + declaration + "\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "interface"):
                    package.build(self.root)
                self.assertFalse((self.root / "dist").exists(), "Invalid metadata produced package output")
        path.write_text(original, encoding="utf-8")
        self.assertEqual(package.validate(self.root), self.version)

    def test_duplicate_version_metadata_cannot_package(self):
        path = self.root / "FindAnUpgrade/FindAnUpgrade.toc"; original = path.read_text(encoding="utf-8")
        for declaration in [
            "## Version: " + self.version, "## Version: 999.999.999",
            "## version : " + self.version, "## Version: invalid",
        ]:
            with self.subTest(declaration=declaration):
                path.write_text(original + "\n" + declaration + "\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "semantic version"):
                    package.build(self.root)
                self.assertFalse((self.root / "dist").exists(), "Invalid metadata produced package output")
        path.write_text(original, encoding="utf-8")
        self.assertEqual(package.validate(self.root), self.version)

    def test_syntax_and_stale_classification_are_rejected(self):
        path = self.root / "FindAnUpgrade/Model.lua"; original = path.read_text(); path.write_text("this is not lua")
        with self.assertRaisesRegex(ValueError, "syntax"): package.validate(self.root)
        path.write_text(original)
        path = self.root / "FindAnUpgrade/Data/Quests.lua"; path.write_text(path.read_text().replace('[286] = "verifiedUnchanged"', '[286] = "verifiedNew"'))
        with self.assertRaisesRegex(ValueError, "stale"): package.validate(self.root)

if __name__ == "__main__": unittest.main()
