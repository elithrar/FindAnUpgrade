from pathlib import Path
import importlib.util
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('migration', ROOT / 'tools/migrate_settings.py')
migration = importlib.util.module_from_spec(spec); spec.loader.exec_module(migration)


class MigrationTest(unittest.TestCase):
    def test_valid_settings_are_copied_verbatim_and_old_file_preserved(self):
        for raw in (b'QuestBriefDB = { ["version"]=3, enabled=false, scale=1.1, nested={"value", [3]=-1.2e2} }\n',
                    b'\xef\xbb\xbf-- saved\r\nQuestBriefDB={version=99, future="unknown \\"data\\""};\r\n'):
            with self.subTest(raw=raw), tempfile.TemporaryDirectory(dir=ROOT / '.work') as directory:
                source = Path(directory) / 'QuestBrief.lua'; source.write_bytes(raw)
                target = source.with_name('FindAnUpgrade.lua')
                result = migration.copy_settings(source, target, migration.validate_data(raw))
                self.assertEqual(source.read_bytes(), raw)
                self.assertEqual(target.read_bytes(), raw)
                self.assertEqual(result['bytes'], len(raw))

    def test_existing_target_and_changed_source_are_preserved(self):
        with tempfile.TemporaryDirectory(dir=ROOT / '.work') as directory:
            source = Path(directory) / 'QuestBrief.lua'; source.write_bytes(b'QuestBriefDB={enabled=false}')
            target = source.with_name('FindAnUpgrade.lua'); target.write_bytes(b'newer')
            digest = migration.validate_data(source.read_bytes())
            with self.assertRaises(FileExistsError): migration.copy_settings(source, target, digest)
            self.assertEqual(target.read_bytes(), b'newer')
            target.unlink()
            with self.assertRaisesRegex(ValueError, 'changed'): migration.copy_settings(source, target, '0' * 64)
            self.assertFalse(target.exists())

    def test_executable_and_foreign_data_is_rejected(self):
        for raw in (b'QuestBriefDB={x=os.execute("bad")}', b'QuestBriefDB={}; OtherDB={}',
                    b'QuestBriefDB=(function() return {} end)()', b'QuestBriefDB={x=1+2}',
                    b'QuestBriefDB={}; print("bad")', b'OtherDB={}', b'QuestBriefDB={x=setmetatable({}, {})}',
                    b'QuestBriefDB={x=1/0}', b'QuestBriefDB={x=math.huge}', b'QuestBriefDB={ [UnitGUID("player")]=1 }',
                    b'QuestBriefDB={x=1e999}', b'QuestBriefDB={} --[[', b'QuestBriefDB={end=true}',
                    b'QuestBriefDB={x="literal\nnewline"}', b'QuestBriefDB={x="\\q"}', b'QuestBriefDB={x="\\999"}',
                    b'QuestBriefDB={x="literal\0nul"}', b'QuestBriefDB={x=+1}',
                    'QuestBriefDB={x=1.\u0665}'.encode(), 'QuestBriefDB={x=1e\u0663}'.encode(),
                    'QuestBriefDB=\u2003{}'.encode(), 'QuestBriefDB=\u2028{}'.encode(), 'QuestBriefDB=\u0085{}'.encode()):
            with self.subTest(raw=raw), self.assertRaises(ValueError): migration.validate_data(raw)

    def test_bounds_and_destination_are_enforced(self):
        for raw in (b'QuestBriefDB=' + b'{' * 35 + b'}' * 35,
                    b'QuestBriefDB={x="' + b'x' * migration.MAX_BYTES + b'"}'):
            with self.assertRaises(ValueError): migration.validate_data(raw)
        with self.assertRaisesRegex(ValueError, 'owned files'):
            migration.copy_settings(ROOT / 'Other.lua', ROOT / 'FindAnUpgrade.lua', '')


if __name__ == '__main__': unittest.main()
