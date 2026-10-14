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
        addon = self.root / "out1" / f"QuestBrief-{self.version}.zip"
        with zipfile.ZipFile(addon) as z:
            self.assertEqual(set(z.namelist()), {"QuestBrief/" + name for name in package.SHIPPED})

    def test_source_excludes_dependencies_references_credentials(self):
        for directory in [".work", "references", ".library-transfer", ".git"]:
            path = self.root / directory / "private.txt"; path.parent.mkdir(); path.write_text("must not ship")
        package.build(self.root)
        with zipfile.ZipFile(self.root / f"dist/QuestBrief-{self.version}-source.zip") as z:
            self.assertFalse(any("private.txt" in name for name in z.namelist()))

    def test_stray_shipped_file_is_rejected(self):
        (self.root / "QuestBrief/surprise.lua").write_text("print('unreviewed')")
        with self.assertRaisesRegex(ValueError, "Unexpected addon manifest"): package.validate(self.root)

    def test_wrong_client_and_load_order_are_rejected(self):
        path = self.root / "QuestBrief/QuestBrief.toc"; original = path.read_text()
        path.write_text(original.replace("16001", "120001"))
        with self.assertRaisesRegex(ValueError, "interface"): package.validate(self.root)
        path.write_text(original.replace("Model.lua\nData/Quests.lua", "Data/Quests.lua\nModel.lua"))
        with self.assertRaisesRegex(ValueError, "load order"): package.validate(self.root)

    def test_version_mismatch_is_rejected(self):
        path = self.root / "QuestBrief/Core.lua"; path.write_text(path.read_text().replace(f'version = "{self.version}"', 'version = "999.999.999"'))
        with self.assertRaisesRegex(ValueError, "version mismatch"): package.validate(self.root)

    def test_syntax_and_stale_classification_are_rejected(self):
        path = self.root / "QuestBrief/Model.lua"; original = path.read_text(); path.write_text("this is not lua")
        with self.assertRaisesRegex(ValueError, "syntax"): package.validate(self.root)
        path.write_text(original)
        path = self.root / "QuestBrief/Data/Quests.lua"; path.write_text(path.read_text().replace('[286] = "verifiedUnchanged"', '[286] = "verifiedNew"'))
        with self.assertRaisesRegex(ValueError, "stale"): package.validate(self.root)

if __name__ == "__main__": unittest.main()
