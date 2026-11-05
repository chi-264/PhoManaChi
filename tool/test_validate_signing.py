"""Exercise real keystores without using the developer's signing material."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


@unittest.skipUnless(all(shutil.which(tool) for tool in ['java', 'javac', 'keytool']),
                     'Signing checks require a JDK')
class SigningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.directory.cleanup)
        cls.root = Path(cls.directory.name)
        source = Path(__file__).with_name('ValidateSigning.java')
        subprocess.run(['javac', '--release', '17', '-d', str(cls.root), str(source)],
                       check=True, capture_output=True)
        for kind in ['JKS', 'PKCS12']:
            key_password = 'fixture-key' if kind == 'JKS' else 'fixture-store'
            subprocess.run([
                'keytool', '-genkeypair', '-keystore', str(cls.root / kind),
                '-storetype', kind, '-storepass', 'fixture-store',
                '-keypass', key_password, '-alias', 'fixture-alias',
                '-keyalg', 'RSA', '-keysize', '2048', '-validity', '1',
                '-dname', 'CN=Signing validation test', '-noprompt',
            ], check=True, capture_output=True)

    def validate(self, kind='JKS', **changes):
        env = {
            **os.environ,
            'PHOMANACHI_KEYSTORE_PATH': str(self.root / kind),
            'PHOMANACHI_STORE_PASSWORD': 'fixture-store',
            'PHOMANACHI_KEY_ALIAS': 'fixture-alias',
            'PHOMANACHI_KEY_PASSWORD': 'fixture-key' if kind == 'JKS' else 'fixture-store',
            **changes,
        }
        result = subprocess.run(['java', '-cp', str(self.root), 'ValidateSigning'],
                                env=env, capture_output=True, text=True)
        for value in ['fixture-store', 'fixture-key', 'fixture-alias', 'wrong-secret']:
            self.assertNotIn(value, result.stdout + result.stderr)
        return result

    def test_valid_jks_with_separate_key_password(self):
        self.assertEqual(self.validate().returncode, 0)

    def test_valid_pkcs12_without_filename_extension(self):
        self.assertEqual(self.validate('PKCS12').returncode, 0)

    def test_wrong_store_password(self):
        result = self.validate(PHOMANACHI_STORE_PASSWORD='wrong-secret')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Cannot open signing keystore', result.stderr)

    def test_wrong_private_key_password(self):
        result = self.validate(PHOMANACHI_KEY_PASSWORD='wrong-secret')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Cannot unlock signing key', result.stderr)

    def test_wrong_alias(self):
        result = self.validate(PHOMANACHI_KEY_ALIAS='wrong-secret')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('PHOMANACHI_KEY_ALIAS', result.stderr)

    def test_missing_setting(self):
        result = self.validate(PHOMANACHI_KEY_PASSWORD='')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Missing signing setting', result.stderr)

    def test_corrupted_keystore(self):
        path = self.root / 'invalid-keystore'
        path.write_bytes(b'not a keystore')
        result = self.validate(PHOMANACHI_KEYSTORE_PATH=str(path))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Cannot open signing keystore', result.stderr)


if __name__ == '__main__':
    unittest.main()
