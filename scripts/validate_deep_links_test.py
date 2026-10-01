#!/usr/bin/env python3
"""Exercise the real deep-link launcher without contacting a device."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().with_name('validate_deep_links.sh')

class DeepLinkDeviceDetectionTest(unittest.TestCase):
    def run_script(self, devices, device=None):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name, source in {
                'flutter': '#!/bin/sh\nprintf "%s" "$TEST_DEVICES"\n',
                'adb': '#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_ADB_LOG"\n',
            }.items():
                path = root / name
                path.write_text(source)
                path.chmod(0o755)
            log = root / 'adb.log'
            result = subprocess.run(['bash', str(SCRIPT), 'android', *([device] if device else [])],
                env={**os.environ, 'PATH': str(root)+os.pathsep+os.environ['PATH'],
                     'TEST_DEVICES': devices, 'TEST_ADB_LOG': str(log)},
                capture_output=True, text=True)
            return result, log.read_text().splitlines() if log.exists() else []

    def test_selects_android_among_other_platforms(self):
        result, calls = self.run_script(json.dumps([
            {'id': 'chrome', 'targetPlatform': 'web-javascript'},
            {'id': 'audit-device', 'targetPlatform': 'android-arm64'}]))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 4)
        self.assertTrue(all(call.startswith('-s audit-device ') for call in calls))
        self.assertIn('maat://share/share-123', calls[0])
        self.assertIn('kemet.app://login-callback', calls[-1])

    def test_no_android_fails_without_launching(self):
        result, calls = self.run_script('[]')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('No android device', result.stderr)
        self.assertEqual(calls, [])

    def test_invalid_inventory_fails_without_launching(self):
        result, calls = self.run_script('invalid json')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_explicit_device_bypasses_discovery(self):
        result, calls = self.run_script('invalid json', 'explicit-device')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 4)
        self.assertTrue(all(call.startswith('-s explicit-device ') for call in calls))

if __name__ == '__main__':
    unittest.main()
