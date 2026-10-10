#!/usr/bin/env python3
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import deploy_web_release as deploy
from web_release_pipeline_test import create_fixture_release
import served_artifact_verifier_test as served_fixtures


class DeploymentTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = create_fixture_release(Path(self.temp.name), 'staging')
        self.receipt = deploy.release.load_json(self.directory / 'release-receipt.json')
        self.archive = self.receipt['payload']['archive_sha256']
        self.calls = []
        self.upload_status = 0
        self.mutate = False
        self.source = self.enterContext(patch.object(deploy.release, 'require_canonical_release_source',
                         return_value={'app_source_commit': self.receipt['source']['app_commit']}))
        self.gate = self.enterContext(patch.object(deploy.release, 'require_green_app_gate', return_value={'run_id': 42}))
        self.real_verifier = deploy.served.verify_deployment
        self.served = self.enterContext(patch.object(deploy.served, 'verify_deployment', return_value={'verified': True}))

    def runner(self, command, stdout, stderr=None):
        self.calls.append(command)
        if 'deploy' in command:
            self.assertTrue((Path(command[5]) / 'main.dart.js').is_file())
            if self.mutate:
                (Path(command[5]) / 'main.dart.js').write_text('tampered')
            stdout.write_text('Deployment complete: https://0123abcd.kemet-rc.pages.dev\n')
            return self.upload_status
        stdout.write_text(json.dumps([{'Id': '12345678-1234-1234-1234-123456789abc', 'Environment': 'Production', 'Branch': 'main', 'Deployment': 'https://0123abcd.kemet-rc.pages.dev'}]))
        return 0

    def run_deploy(self, environment='staging', archive=None):
        return deploy.deploy(self.directory, archive or self.archive, environment, runner=self.runner)

    def test_upload_reuses_preflight_but_preserves_target_gate_and_served_proofs(self):
        with patch.object(deploy.release, 'verify_release', wraps=deploy.release.verify_release) as verify:
            receipt = self.run_deploy()
        self.assertTrue(receipt.is_file())
        self.assertEqual(verify.call_count, 1)  # post-upload verifier owns its separate check
        self.assertEqual(self.source.call_count, 2)
        self.gate.assert_called_once()
        self.assertEqual(len(self.calls), 2)
        self.assertEqual(self.calls[0][-4:], ['--project-name', 'kemet-rc', '--branch', 'main'])
        self.assertEqual(self.calls[1][-5:], ['--project-name', 'kemet-rc', '--environment', 'production', '--json'])
        args = self.served.call_args.kwargs
        self.assertEqual(args['immutable_url'], 'https://0123abcd.kemet-rc.pages.dev')
        self.assertEqual(args['alias_url'], 'https://kemet-rc.pages.dev')
        self.assertEqual(args['expected_archive_sha256'], self.archive)
        self.assertTrue((receipt.parent / 'upload-attempt.json').is_file())

    def test_complete_deployment_checks_both_origins_and_only_two_archive_passes(self):
        fixture = served_fixtures.ServedArtifactVerifierTest()
        fixture.setUp()
        bodies = {path.relative_to(self.directory).as_posix(): path.read_bytes()
                  for path in (self.directory / 'web').rglob('*') if path.is_file()}
        responses = fixture.responses_for(fixture.origin, bodies=bodies)
        responses.update(fixture.responses_for(fixture.alias, bodies=bodies))
        fetch = served_fixtures.FakeFetcher(responses)
        # Exercise the real verifier with HTTP fixtures; nothing is deployed.
        self.served.side_effect = lambda **kwargs: self.real_verifier(**kwargs, fetcher=fetch)
        with patch.object(deploy.release, 'verify_release', wraps=deploy.release.verify_release) as verify:
            receipt = self.run_deploy()
        result = json.loads(receipt.read_text())
        self.assertEqual(verify.call_count, 2)
        for key in ('immutable_verification', 'alias_verification'):
            self.assertEqual(result[key]['verified_direct_bodies'], len(result[key]['classification']['body_paths']))
            self.assertTrue(all(result[key]['verdicts'].values()))
        self.assertEqual(len(fetch.calls), len(set(fetch.calls)))

    def test_production_target_is_closed_and_independent_of_git_branch(self):
        self.directory = create_fixture_release(Path(self.temp.name), 'production')
        self.receipt = deploy.release.load_json(self.directory / 'release-receipt.json')
        self.archive = self.receipt['payload']['archive_sha256']
        def runner(command, stdout, stderr=None):
            self.calls.append(command)
            stdout.write_text('Deployment complete: https://0123abcd.kemet.pages.dev\n' if 'deploy' in command else '[]')
            return 0
        deploy.deploy(self.directory, self.archive, 'production', runner=runner)
        self.assertEqual(self.calls[0][-4:], ['--project-name', 'kemet', '--branch', 'main'])
        self.assertEqual(self.served.call_args.kwargs['alias_url'], 'https://kemet.pages.dev')
        self.assertEqual(self.gate.call_args.kwargs['environment'], 'production')

    def test_wrong_lane_or_hash_never_uploads(self):
        for kwargs in ({'environment': 'production'}, {'archive': '0' * 64}):
            with self.subTest(kwargs=kwargs), self.assertRaises(deploy.release.ReleaseInputError):
                self.run_deploy(**kwargs)
        self.assertEqual(self.calls, [])

    def test_failed_gate_never_uploads(self):
        self.gate.side_effect = deploy.release.ReleaseInputError('Exact gate not green')
        with self.assertRaises(deploy.release.ReleaseInputError):
            self.run_deploy()
        self.assertEqual(self.calls, [])

    def test_source_change_during_preflight_never_uploads(self):
        self.source.side_effect = [{'app_source_commit': self.receipt['source']['app_commit']},
                                   deploy.release.ReleaseInputError('source moved')]
        with self.assertRaisesRegex(deploy.release.ReleaseInputError, 'source moved'):
            self.run_deploy()
        self.assertEqual(self.calls, [])

    def test_failed_upload_keeps_receipt_and_does_not_retry(self):
        self.upload_status = 1
        with self.assertRaisesRegex(deploy.served.ServedVerificationError, 'Upload failed'):
            self.run_deploy()
        self.assertEqual(len(self.calls), 1)
        receipt = next((self.directory.parent / 'web-deployment-receipts').glob('*/upload-attempt.json'))
        self.assertEqual(json.loads(receipt.read_text())['upload_exit_status'], 1)
        self.served.assert_not_called()

    def test_snapshot_mutation_stops_before_served_verification(self):
        self.mutate = True
        with self.assertRaisesRegex(deploy.served.ServedVerificationError, 'snapshot changed'):
            self.run_deploy()
        self.assertEqual(len(self.calls), 1)
        self.served.assert_not_called()

    def test_served_mismatch_does_not_retry_rebuild_or_rollback(self):
        self.served.side_effect = deploy.served.ServedVerificationError('live body mismatch')
        with self.assertRaisesRegex(deploy.served.ServedVerificationError, 'live body mismatch'):
            self.run_deploy()
        self.assertEqual(len(self.calls), 2)
        result = next((self.directory.parent / 'web-deployment-receipts').glob('*/result.json'))
        self.assertFalse(json.loads(result.read_text())['success'])


if __name__ == '__main__':
    unittest.main()
