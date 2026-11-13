#!/usr/bin/env python3
"""Offline regression tests for pinned Skydroid SDK retrieval."""
import hashlib
import http.client
import importlib.util
import io
from pathlib import Path
import unittest
from unittest import mock

source = Path(__file__).resolve().parents[1] / "tools" / "prepare-skydroid-android.py"
spec = importlib.util.spec_from_file_location("navo_skydroid_sdk", source)
sdk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sdk)


class SkydroidSdkDownloadTests(unittest.TestCase):
    def setUp(self):
        self.expected = b"verified pinned vendor bytes"
        self.sha = mock.patch.object(sdk, "SDK_SHA256", hashlib.sha256(self.expected).hexdigest())
        self.sha.start()
        self.addCleanup(self.sha.stop)

    def test_valid_raw_download_avoids_git(self):
        with mock.patch.object(sdk.urllib.request, "urlopen", return_value=io.BytesIO(self.expected)) as raw, \
                mock.patch.object(sdk.subprocess, "run") as git:
            self.assertEqual(sdk.download_official_sdk(), self.expected)
            self.assertEqual(raw.call_count, 1)
            git.assert_not_called()

    def test_truncated_raw_download_falls_back_to_exact_vendor_commit(self):
        with mock.patch.object(sdk.urllib.request, "urlopen",
                               side_effect=http.client.IncompleteRead(b"partial")) as raw, \
                mock.patch.object(sdk.subprocess, "run") as run, \
                mock.patch.object(sdk.subprocess, "check_output", return_value=self.expected) as show:
            self.assertEqual(sdk.download_official_sdk(), self.expected)
            self.assertEqual(raw.call_count, 3)
            commands = [c.args[0] for c in run.call_args_list]
            self.assertTrue(any(sdk.SDK_COMMIT in command for command in commands))
            self.assertIn(sdk.SDK_COMMIT, show.call_args.args[0][-1])

    def test_wrong_hash_is_never_accepted(self):
        with mock.patch.object(sdk.urllib.request, "urlopen", return_value=io.BytesIO(b"wrong")), \
                mock.patch.object(sdk.subprocess, "run"), \
                mock.patch.object(sdk.subprocess, "check_output", return_value=b"wrong"):
            with self.assertRaisesRegex(RuntimeError, "Cannot download pinned official RCSDK"):
                sdk.download_official_sdk()


if __name__ == "__main__":
    unittest.main()
