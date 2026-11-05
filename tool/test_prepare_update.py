import hashlib
from pathlib import Path
import tempfile
import unittest
from prepare_update import assert_increasing, build_manifest


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.apk = Path(self.directory.name) / 'sample.apk'
        self.apk.write_bytes(b'signed APK fixture')
        self.metadata = {'package_name': 'dev.phomanachi.phomanachi', 'version_code': 3, 'version_name': '0.3.0', 'min_sdk': 28}

    def test_manifest_matches_bytes_and_release_url(self):
        data = build_manifest(self.apk, self.metadata, 'Storage milestone', 'Notes')
        self.assertEqual(data['sha256'], hashlib.sha256(self.apk.read_bytes()).hexdigest())
        self.assertEqual(data['size_bytes'], self.apk.stat().st_size)
        self.assertEqual(data['apk_url'], 'https://github.com/chi-264/PhoManaChi/releases/download/v0.3.0/phomanachi.apk')

    def test_reject_wrong_package_tag_and_unsafe_version(self):
        with self.assertRaises(ValueError):
            build_manifest(self.apk, {**self.metadata, 'package_name': 'wrong.app'}, 'Title', 'Notes')
        with self.assertRaises(ValueError):
            build_manifest(self.apk, self.metadata, 'Title', 'Notes', tag='v0.2.0')
        with self.assertRaises(ValueError):
            build_manifest(self.apk, {**self.metadata, 'version_name': '../escape'}, 'Title', 'Notes')

    def test_reject_missing_apk_and_oversized_notes(self):
        self.apk.write_bytes(b'')
        with self.assertRaises(ValueError):
            build_manifest(self.apk, self.metadata, 'Title', 'Notes')
        self.apk.write_bytes(b'apk')
        with self.assertRaises(ValueError):
            build_manifest(self.apk, self.metadata, 'Title', 'x' * 16001)

    def test_each_milestone_requires_a_newer_code(self):
        assert_increasing(3, 2)
        assert_increasing(2, None)
        for code in [1, 2]:
            with self.assertRaises(ValueError):
                assert_increasing(code, 2)


if __name__ == '__main__':
    unittest.main()
