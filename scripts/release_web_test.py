#!/usr/bin/env python3
import unittest
import json
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

    def test_background_candidate_cannot_advance_before_or_during_the_wait(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with patch.object(coordinator.release, 'require_canonical_release_source', return_value={'app_source_commit': self.commit}), patch.object(coordinator, 'qualify') as qualify:
                with self.assertRaisesRegex(coordinator.release.ReleaseInputError, 'changed before'):
                    coordinator.prepare('staging', root, expected_commit='b'*40)
                qualify.assert_not_called()
            with patch.object(coordinator.release, 'require_canonical_release_source', side_effect=[{'app_source_commit': self.commit}, {'app_source_commit': 'b'*40}]), patch.object(coordinator, 'qualify', return_value={'run_id':1}), patch.object(coordinator.app_gate, 'run_step') as build:
                with self.assertRaisesRegex(coordinator.release.ReleaseInputError, 'changed while'):
                    coordinator.prepare('staging', root)
                build.assert_not_called()

    def test_background_returns_one_process_and_keeps_upload_explicit(self):
        with tempfile.TemporaryDirectory() as temporary:
            logs = Path(temporary)
            with patch.object(coordinator.release, 'require_canonical_release_source', return_value={'app_source_commit': self.commit}), patch.object(coordinator.subprocess, 'Popen', return_value=Mock(pid=321)) as spawn, patch.object(coordinator, 'prepare') as prepare:
                result = coordinator.launch_background('staging', logs, None, False)
                prepare.assert_not_called()
                command = spawn.call_args.args[0]
                self.assertNotIn('--background', command)
                self.assertIn('--expected-sha', command)
                self.assertIn(self.commit, command)
                self.assertNotIn('--deploy', command)
                self.assertTrue(spawn.call_args.kwargs['start_new_session'])
                self.assertEqual(result['pid'], 321)
                self.assertEqual(result['commit'], self.commit)
                self.assertTrue((logs / 'process.json').exists())
                with self.assertRaisesRegex(coordinator.release.ReleaseInputError, 'already has'):
                    coordinator.launch_background('staging', logs, None, False)
                next_logs = logs / 'next'
                next_logs.mkdir()
                coordinator.launch_background('staging', next_logs, logs / 'artifact', True)
                command = spawn.call_args.args[0]
                self.assertIn('--deploy', command)
                self.assertIn('--release-dir', command)

    def test_reusing_artifact_never_rebuilds_and_checks_source_lane(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            receipt = {'source': {'app_commit': self.commit}, 'environment': 'staging'}
            with patch.object(coordinator.release, 'require_canonical_release_source', return_value={'app_source_commit': self.commit}) as source, patch.object(coordinator, 'qualify', return_value={'run_id': 1}), patch.object(coordinator.release, 'verify_release', return_value=receipt), patch.object(coordinator.app_gate, 'run_step') as build:
                coordinator.prepare('staging', root, root / 'artifact')
                build.assert_not_called()
                self.assertEqual(source.call_count, 3)
                receipt['environment'] = 'production'
                with self.assertRaisesRegex(coordinator.release.ReleaseInputError, 'another lane'):
                    coordinator.prepare('staging', root, root / 'artifact')


class PublicWebsitePreviewTest(unittest.TestCase):
    commit = 'a' * 40
    origin = 'https://1234abcd.haw-info.pages.dev'

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.logs = Path(self.temporary.name)
        self.directory = self.logs / 'sealed'
        self.label = 'website-preview-' + self.commit[:12]
        self.receipt = {'source_commit': self.commit}
        self.gate = {'run_id': 123, 'commit': self.commit}
        self.fetch = Mock(return_value=coordinator.public_site.HttpResult(
            200, {'content-type': 'text/html'}, b'existing production website',
            coordinator.public_site.ORIGIN + '/'))
        self.commands = []
        self.metadata = dict(Deployment=self.origin, Environment='Preview', Branch=self.label,
                             Source=self.commit[:7])
        for owner, name, value in [
            (coordinator, 'qualify_source', self.commit),
            (coordinator.public_site, 'seal', self.directory),
            (coordinator.public_site, 'verify_seal', (self.receipt, {}, {})),
            (coordinator.public_site, 'source_identity', (self.commit, 'b' * 64)),
            (coordinator.public_site, 'validate_payload', ({}, {})),
            (coordinator.public_site, 'verify_live', {'origin': self.origin}),
            (coordinator.release, 'require_canonical_release_source', {'app_source_commit': self.commit}),
        ]:
            patcher = patch.object(owner, name, return_value=value)
            setattr(self, name, patcher.start())
            self.addCleanup(patcher.stop)
        coordinator.release.write_json(self.logs / 'app-gate.json', self.gate)

    def runner(self, command, output):
        self.commands.append(command)
        if command[4] == 'deploy':
            output.write_text('Deployment complete: ' + self.origin)
        else:
            output.write_text(json.dumps([self.metadata]))
        return 0

    def publish(self):
        return coordinator.publish_site_preview(self.logs, expected_commit=self.commit,
                                                runner=self.runner, fetch=self.fetch)

    def test_preview_uses_full_qualification_and_only_the_closed_website_payload(self):
        result = self.publish()
        self.qualify_source.assert_called_once_with('production', self.logs, self.commit)
        upload = self.commands[0]
        self.assertEqual(upload[:5], ['npx', '--yes', 'wrangler@4.114.0', 'pages', 'deploy'])
        self.assertEqual(upload[5], str(self.directory / 'payload'))
        self.assertEqual(upload[upload.index('--project-name') + 1], 'haw-info')
        self.assertEqual(upload[upload.index('--branch') + 1], self.label)
        self.assertNotIn('production', upload)
        self.assertEqual(upload[upload.index('--commit-hash') + 1], self.commit)
        self.assertEqual(result['origin'], self.origin)
        self.assertTrue(result['deployed'])
        self.verify_live.assert_called_once_with(self.directory, self.origin, fetch=self.fetch)
        self.assertEqual(self.fetch.call_count, 2)
        self.assertTrue((self.logs / 'release.json').exists())

    def test_failed_gate_changed_source_or_mismatched_seal_never_uploads(self):
        for boundary in ('gate', 'source', 'seal'):
            with self.subTest(boundary=boundary):
                self.commands.clear()
                self.qualify_source.side_effect = None
                self.require_canonical_release_source.return_value = {'app_source_commit': self.commit}
                self.receipt['source_commit'] = self.commit
                if boundary == 'gate':
                    self.qualify_source.side_effect = coordinator.release.ReleaseInputError('Gate failed')
                elif boundary == 'source':
                    self.require_canonical_release_source.return_value = {'app_source_commit': 'b' * 40}
                else:
                    self.receipt['source_commit'] = 'b' * 40
                with self.assertRaises((coordinator.release.ReleaseInputError, coordinator.public_site.PublicSiteError)):
                    self.publish()
                self.assertEqual(self.commands, [])

    def test_wrong_project_environment_label_or_source_cannot_claim_verified_preview(self):
        for field, value in [('Deployment', 'https://1234abcd.kemet.pages.dev'),
                             ('Environment', 'Production'), ('Branch', 'production'), ('Source', 'b' * 7)]:
            with self.subTest(field=field):
                original = self.metadata[field]
                self.metadata[field] = value
                with self.assertRaises(coordinator.public_site.PublicSiteError):
                    self.publish()
                self.metadata[field] = original
        self.verify_live.assert_not_called()

    def test_production_change_or_live_verification_failure_stops_success_receipt(self):
        before = self.fetch.return_value
        self.fetch.side_effect = [before, coordinator.public_site.HttpResult(
            200, before.headers, b'changed production website', before.url)]
        with self.assertRaisesRegex(coordinator.public_site.PublicSiteError, 'Production website identity changed'):
            self.publish()
        self.assertFalse((self.logs / 'release.json').exists())
        self.fetch.side_effect = None
        self.verify_live.side_effect = coordinator.public_site.PublicSiteError('Wrong asset body')
        with self.assertRaisesRegex(coordinator.public_site.PublicSiteError, 'Wrong asset body'):
            self.publish()
        self.assertFalse((self.logs / 'release.json').exists())

    def test_background_preview_is_explicit_and_rejects_rc_or_missing_upload_authority(self):
        for lane, deploy in [('staging', True), ('production', False)]:
            with self.assertRaisesRegex(coordinator.release.ReleaseInputError, 'production source and --deploy'):
                coordinator.launch_background(lane, self.logs, None, deploy, public_site_preview=True)
        with patch.object(coordinator.subprocess, 'Popen', return_value=Mock(pid=321)) as spawn:
            result = coordinator.launch_background('production', self.logs, None, True, public_site_preview=True)
            command = spawn.call_args.args[0]
            self.assertIn('--public-site-preview', command)
            self.assertIn('--deploy', command)
            self.assertTrue(result['public_site_preview'])


if __name__ == '__main__':
    unittest.main()
