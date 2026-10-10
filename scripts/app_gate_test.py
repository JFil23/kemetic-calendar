#!/usr/bin/env python3
"""Behavioral checks for conservative change selection and release separation."""
import tempfile
import unittest
from pathlib import Path
import app_gate as gate


class SelectionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        files = {
            'pubspec.yaml': 'name: mobile\n',
            'lib/owner.dart': 'class Owner {}',
            'lib/facade.dart': "export 'owner.dart';",
            'lib/uncovered.dart': 'class Uncovered {}',
            'test/a_test.dart': "import 'package:mobile/facade.dart';",
            'test/b_test.dart': "import 'helper.dart';",
            'test/helper.dart': "import '../lib/owner.dart';",
            'test/browser_test.dart': "@TestOn('browser')\nimport '../lib/owner.dart';",
            'test/unrelated_test.dart': 'void main() {}',
        }
        for name, text in files.items():
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)

    def test_shared_owner_follows_transitive_exports_helpers_and_browser(self):
        plan = gate.plan(self.root, ['lib/owner.dart'])
        self.assertFalse(plan['full'])
        self.assertEqual(plan['tests'], ['test/a_test.dart', 'test/b_test.dart'])
        self.assertEqual(plan['browser'], ['test/browser_test.dart'])

    def test_deleted_imported_owner_still_selects_consumers(self):
        (self.root / 'lib/owner.dart').unlink()
        self.assertEqual(gate.plan(self.root, ['lib/owner.dart'])['tests'],
                         ['test/a_test.dart', 'test/b_test.dart'])

    def test_unknown_asset_fixture_dependency_and_uncovered_owner_fall_back(self):
        for path in ('assets/art.png', 'assets/about.md', 'pubspec.lock', 'test/fixtures/persisted.json',
                     'lib/uncovered.dart', 'native/unknown.cc', 'test/removed_test.dart'):
            with self.subTest(path=path):
                self.assertTrue(gate.plan(self.root, [path])['full'])

    def test_docs_skip_but_mixed_change_keeps_runtime_coverage(self):
        self.assertFalse(gate.plan(self.root, ['docs/release_workflow.md'])['contracts'])
        self.assertTrue(gate.plan(self.root, ['README.md', 'lib/owner.dart'])['tests'])

    def test_tooling_change_runs_contracts_without_unrelated_flutter(self):
        commands = gate.commands(gate.plan(self.root, ['scripts/web_release_pipeline.py']))
        self.assertTrue(any('scripts/web_release_pipeline_test.py' in c for c in commands))
        self.assertFalse(any(c[0] == 'flutter' for c in commands))

    def test_complete_gate_retains_all_tests_analysis_and_browser(self):
        plan = gate.plan(self.root, None)
        commands = gate.commands(plan)
        self.assertIn(['flutter', 'test', '--no-pub', 'test'], commands)
        self.assertIn(['flutter', 'analyze', '--no-fatal-infos'], commands)
        self.assertIn(['flutter', 'test', '--no-pub', '--platform', 'chrome', 'test/browser_test.dart'], commands)

    def test_conditional_imports_and_parts_are_traversed(self):
        deps = gate.dart_dependencies('lib/a.dart', "import 'a_stub.dart' if (dart.library.html) 'a_web.dart'; part 'a.g.dart';", 'mobile')
        self.assertEqual(deps, {'lib/a_stub.dart', 'lib/a_web.dart', 'lib/a.g.dart'})


if __name__ == '__main__':
    unittest.main()
