#!/usr/bin/env python3
import unittest
from unittest.mock import Mock, patch
from pathlib import Path
import tempfile
import release_web as coordinator
from web_release_pipeline_test import app_gate_jobs_fixture


class QualificationTest(unittest.TestCase):
    commit = 'a' * 40

    def setUp(self):
        self.current = self.fixture()
        self.full = True
        self.calls = []
        self.sleep = Mock()

    def fixture(self, *, status='completed', conclusion='success', event='push', run_id=1):
        return dict(id=run_id, name='App', head_sha=self.commit, head_branch='rc',
                    event=event, run_number=run_id, run_attempt=1,
                    html_url=f'https://github.com/JFil23/kemetic-calendar/actions/runs/{run_id}',
                    status=status, conclusion=conclusion)

    def fetch(self, url, *, environ):
        if '/attempts/' in url:
            self.assertIn(f"/{self.current['id']}/attempts/1/jobs", url)
            return app_gate_jobs_fixture(self.commit, full=self.full)
        return {'workflow_runs': [self.current] if self.current else []}

    def run_command(self, command, **kwargs):
        self.calls.append(command)
        if command[1:3] == ['workflow', 'run']:
            self.assertEqual(self.current['status'], 'completed')
            self.assertFalse(self.full)
            self.assertIn('expected_sha=' + self.commit, command)
            self.current = self.fixture(status='queued', conclusion=None, event='workflow_dispatch', run_id=2)
            self.full = True
        elif command[1:3] == ['run', 'watch']:
            self.current.update(status='completed', conclusion='success')

    def qualify(self):
        return coordinator.qualify(self.commit, 'staging', fetch=self.fetch, run=self.run_command, sleep=self.sleep)

    def test_successful_full_push_is_reused_without_dispatch_or_watch(self):
        self.assertEqual(self.qualify()['run_id'], 1)
        self.assertEqual(self.calls, [])

    def test_active_full_push_is_awaited_without_dispatching_duplicate(self):
        self.current.update(status='in_progress', conclusion=None)
        self.assertEqual(self.qualify()['run_id'], 1)
        self.assertEqual([c[1:3] for c in self.calls], [['run', 'watch']])

    def test_focused_push_dispatches_one_full_gate_for_exact_candidate(self):
        self.full = False
        self.assertEqual(self.qualify()['run_id'], 2)
        self.assertEqual([c[1:3] for c in self.calls], [['workflow', 'run'], ['run', 'watch']])
        self.assertEqual(self.calls[0][-4:-2], ['--ref', 'rc'])

    def test_active_focused_push_finishes_before_full_dispatch(self):
        self.full = False
        self.current.update(status='in_progress', conclusion=None)
        self.qualify()
        self.assertEqual([c[1:3] for c in self.calls], [['run', 'watch'], ['workflow', 'run'], ['run', 'watch']])

    def test_missing_push_run_never_races_it_with_another_suite(self):
        self.current = None
        with self.assertRaisesRegex(coordinator.release.ReleaseInputError, 'not visible'):
            self.qualify()
        self.assertEqual(self.calls, [])

    def test_failed_or_cancelled_gate_is_not_automatically_retried(self):
        for conclusion in ('failure', 'cancelled'):
            self.current = self.fixture(conclusion=conclusion)
            with self.subTest(conclusion=conclusion), self.assertRaises(coordinator.release.ReleaseInputError):
                self.qualify()
        self.assertEqual(self.calls, [])

    def test_existing_dispatch_is_reused_without_another_dispatch(self):
        self.current = self.fixture(event='workflow_dispatch')
        self.qualify()
        self.assertEqual(self.calls, [])

    def test_dispatched_full_gate_must_not_return_focused_evidence(self):
        self.full = False
        original = self.run_command
        def run(command, **kwargs):
            original(command, **kwargs)
            if command[1:3] == ['workflow', 'run']:
                self.full = False
        with self.assertRaisesRegex(coordinator.release.ReleaseInputError, 'only focused evidence'):
            coordinator.qualify(self.commit, 'staging', fetch=self.fetch, run=run, sleep=self.sleep)
        self.assertEqual(sum(c[1:3] == ['workflow', 'run'] for c in self.calls), 1)

    def test_dispatched_gate_visibility_timeout_does_not_repeat_dispatch(self):
        self.full = False
        def run(command, **kwargs):
            self.calls.append(command)  # Simulate Actions not showing the new run.
        with self.assertRaisesRegex(coordinator.release.ReleaseInputError, 'not visible'):
            coordinator.qualify(self.commit, 'staging', fetch=self.fetch, run=run, sleep=self.sleep)
        self.assertEqual(len(self.calls), 1)

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
