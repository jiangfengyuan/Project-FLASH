"""Host-path regression tests; no native compiler or downloads required."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('lan_builder', Path(__file__).with_name('build.py'))
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class AndroidNDKHostTests(unittest.TestCase):
    def test_linux_runner(self):
        with patch.object(builder.platform, 'system', return_value='Linux'):
            self.assertEqual(builder.android_ndk_binaries(Path('/ndk')),
                             Path('/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin'))

    def test_existing_macos_host(self):
        with patch.object(builder.platform, 'system', return_value='Darwin'):
            self.assertEqual(builder.android_ndk_binaries(Path('/ndk')),
                             Path('/ndk/toolchains/llvm/prebuilt/darwin-x86_64/bin'))

    def test_unsupported_host_fails_explicitly(self):
        with patch.object(builder.platform, 'system', return_value='Windows'):
            with self.assertRaisesRegex(ValueError, 'Unsupported Android NDK build host'):
                builder.android_ndk_binaries(Path('/ndk'))


if __name__ == '__main__':
    unittest.main()
