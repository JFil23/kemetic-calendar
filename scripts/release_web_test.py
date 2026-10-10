#!/usr/bin/env python3
import unittest
from unittest.mock import Mock, patch
from pathlib import Path
import tempfile
import release_web as coordinator


class QualificationTest(unittest.TestCase):
    commit = 'a' * 40

    def fixture(self, **kwargs):
        return dict(id=1, name='App', head_sha=self.commit, head_branch='rc',
                    event='workflow_dispatch', run_number=1, run_attempt=1,
                    html_url='https://github.com/JFil23/kemetic-calendar/actions/runs/1', **kwargs)

    def test_successful_gate_is_reused_without_dispatch_or_watch(self):
        fetch = Mock(return_value={'workflow_runs': [self.fixture(status='completed', conclusion='success')]})
        run = Mock()
        coordinator.qualify(self.commit, 'staging', fetch=fetch, run=run)
        run.assert_not_called()

    def test_missing_gate_is_dispatched_for_exact_lane_and_sha_then_awaited(self):
        queued = self.fixture(status='queued', conclusion=None)
        done = self.fixture(status='completed', conclusion='success')
        fetch = Mock(side_effect=[{'workflow_runs': []}, {'workflow_runs': [queued]}, {'workflow_runs': [done]}])
        run = Mock()
        result = coordinator.qualify(self.commit, 'staging', fetch=fetch, run=run, sleep=Mock())
        self.assertEqual(result['commit'], self.commit)
        self.assertIn('expected_sha=' + self.commit, run.call_args_list[0].args[0])
        self.assertEqual(run.call_args_list[0].args[0][-4:-2], ['--ref', 'rc'])
        self.assertEqual(run.call_args_list[1].args[0][1:3], ['run', 'watch'])

    def test_existing_active_gate_is_watched_without_dispatch(self):
        fetch = Mock(side_effect=[{'workflow_runs': [self.fixture(status='in_progress', conclusion=None)]},
                                  {'workflow_runs': [self.fixture(status='completed', conclusion='success')]}])
        run = Mock()
        coordinator.qualify(self.commit, 'staging', fetch=fetch, run=run)
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0][1:3], ['run', 'watch'])

    def test_failed_gate_is_not_automatically_retried(self):
        fetch = Mock(return_value={'workflow_runs': [self.fixture(status='completed', conclusion='failure')]})
        run = Mock()
        with self.assertRaises(coordinator.release.ReleaseInputError):
            coordinator.qualify(self.commit, 'staging', fetch=fetch, run=run)
        run.assert_not_called()

    def test_dispatch_visibility_timeout_cannot_qualify(self):
        fetch = Mock(return_value={'workflow_runs': []})
        run = Mock()
        with self.assertRaisesRegex(coordinator.release.ReleaseInputError, 'not visible'):
            coordinator.qualify(self.commit, 'staging', fetch=fetch, run=run, sleep=Mock())
        self.assertEqual(run.call_count, 1)

    def test_reusing_artifact_never_rebuilds_and_checks_source_lane(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            receipt = {'source': {'app_commit': self.commit}, 'environment': 'staging'}
            with patch.object(coordinator.release, 'require_canonical_release_source', return_value={'app_source_commit': self.commit}) as source, patch.object(coordinator, 'qualify', return_value={'run_id': 1}), patch.object(coordinator.release, 'verify_release', return_value=receipt), patch.object(coordinator.app_gate, 'run_step') as build:
                coordinator.prepare('staging', root, root / 'artifact')
                build.assert_not_called()
                self.assertEqual(source.call_count, 2)
                receipt['environment'] = 'production'
                with self.assertRaisesRegex(coordinator.release.ReleaseInputError, 'another lane'):
                    coordinator.prepare('staging', root, root / 'artifact')


if __name__ == '__main__':
    unittest.main()
