#!/usr/bin/env python3
"""Keep executable CI dependencies immutable and the App token read-only."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def mutable_actions(source):
    references = re.findall(r'^\s*(?:-\s*)?uses:\s*([^\s#]+)', source, re.M)
    return [ref for ref in references if not (
        ref.startswith('./') or
        re.fullmatch(r'[^@\s]+@[0-9a-f]{40}', ref) or
        re.fullmatch(r'docker://[^@\s]+@sha256:[0-9a-f]{64}', ref)
    )]


class WorkflowSecurityTest(unittest.TestCase):
    def test_all_workflow_actions_are_immutable(self):
        workflows = sorted((ROOT / '.github/workflows').glob('*.y*ml'))
        self.assertTrue(workflows)
        for path in workflows:
            with self.subTest(workflow=path.name):
                self.assertEqual(mutable_actions(path.read_text()), [])

    def test_mutable_tags_branches_and_expressions_are_rejected(self):
        for ref in ('actions/checkout@v4', 'owner/action@main',
                    'owner/action@1234567', 'owner/action@${{ inputs.ref }}'):
            with self.subTest(reference=ref):
                self.assertTrue(mutable_actions('  - uses: ' + ref))

    def test_app_token_remains_read_only(self):
        source = (ROOT / '.github/workflows/app.yml').read_text()
        self.assertRegex(source, r'(?m)^permissions:\n  contents: read\n')
        self.assertNotRegex(source, r'(?m)^\s*(?:permissions:\s*write-all|[\w-]+:\s*write)\s*$')
        self.assertNotIn('pull_request_target:', source)


if __name__ == '__main__':
    unittest.main()
