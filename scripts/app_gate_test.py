#!/usr/bin/env python3
"""Behavioral checks for conservative change selection and release separation."""
import ast
import re
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

    def test_file_reading_guard_is_selected_for_tooling_changes(self):
        (self.root / 'test/guard_test.dart').write_text("File('scripts/deploy.py').readAsStringSync();")
        plan = gate.plan(self.root, ['scripts/deploy.py'])
        self.assertFalse(plan['full'])
        self.assertEqual(plan['tests'], ['test/guard_test.dart'])

    def test_preflight_retains_every_non_vm_check_once(self):
        selection = gate.plan(self.root, None)
        all_commands = gate.commands(selection)
        preflight = gate.commands(selection, phase='preflight')
        self.assertEqual(preflight, [c for c in all_commands if c != ['flutter', 'test', '--no-pub', 'test']])

    def test_all_four_shards_run_the_entire_test_tree_partition(self):
        selection = gate.plan(self.root, None)
        workflow = (gate.ROOT / '.github/workflows/app.yml').read_text()
        indices = ast.literal_eval(re.search(r'shard: (\[[^\]]+\])', workflow).group(1))
        self.assertEqual(indices, list(range(gate.FULL_SUITE_SHARDS)))
        executed = []
        for index in indices:
            commands = gate.commands(selection, phase='tests', shard_index=index, root=self.root)
            self.assertEqual(commands[0], ['flutter', 'pub', 'get', '--enforce-lockfile'])
            self.assertEqual(commands[1][:3], ['flutter', 'test', '--no-pub'])
            files = commands[1][3:]
            self.assertTrue(files)
            self.assertTrue(all(p.startswith('test/') and p.endswith('_test.dart') for p in files))
            executed.extend(files)
        expected = sorted(p.relative_to(self.root).as_posix() for p in (self.root / 'test').rglob('*_test.dart'))
        self.assertCountEqual(executed, expected)  # Every file exactly once.
        self.assertEqual(len(executed), len(set(executed)))
        # Check the real release inventory as well as the small fixture.
        actual = [p for index in indices for p in gate.shard_files(gate.ROOT, index)]
        self.assertCountEqual(actual, [p.relative_to(gate.ROOT).as_posix() for p in (gate.ROOT / 'test').rglob('*_test.dart')])
        self.assertEqual(len(actual), len(set(actual)))
        for index in (None, -1, 4):
            with self.subTest(index=index), self.assertRaises(ValueError):
                gate.commands(selection, phase='tests', shard_index=index, root=self.root)
        with self.assertRaises(ValueError):
            gate.commands(gate.plan(self.root, ['lib/owner.dart']), phase='preflight')

    def test_an_empty_shard_cannot_fall_back_to_running_all_tests(self):
        empty = self.root / 'empty'
        empty.mkdir()
        with self.assertRaisesRegex(ValueError, 'empty shard'):
            gate.shard_files(empty, 0)

    def test_conditional_imports_and_parts_are_traversed(self):
        deps = gate.dart_dependencies('lib/a.dart', "import 'a_stub.dart' if (dart.library.html) 'a_web.dart'; part 'a.g.dart';", 'mobile')
        self.assertEqual(deps, {'lib/a_stub.dart', 'lib/a_web.dart', 'lib/a.g.dart'})


if __name__ == '__main__':
    unittest.main()
