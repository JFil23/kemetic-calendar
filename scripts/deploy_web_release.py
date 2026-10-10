#!/usr/bin/env python3
"""Upload one sealed lane artifact, with exact-source and served proof.

The shell entry remains the public interface. This owner consolidates preflight
and extraction and reuses in-memory preflight evidence when recording the upload.
"""
from __future__ import annotations
import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import served_artifact_verifier as served
import web_release_pipeline as release

ROOT = Path(__file__).resolve().parents[1]
WRANGLER_VERSION = '4.114.0'


def run_process(command: list[str], stdout: Path, stderr: Path | None = None) -> int:
    with stdout.open('w') as output:
        if stderr is None:
            return subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, cwd=ROOT).returncode
        with stderr.open('w') as errors:
            return subprocess.run(command, stdout=output, stderr=errors, cwd=ROOT).returncode


def deploy(release_dir: Path, archive_hash: str, environment: str, *,
           root: Path = ROOT, runner=run_process) -> Path:
    lane = served.CANONICAL_LANES[environment]
    receipt = release.load_json(release_dir / 'release-receipt.json')
    release.validate_release_receipt(receipt)
    if receipt['environment'] != environment:
        raise release.ReleaseInputError('Release receipt environment does not match the deployment lane.')
    source = release.require_canonical_release_source(
        root, environment=environment, expected_source=receipt['source'])
    gate = release.require_green_app_gate(source['app_source_commit'], environment=environment, environ=os.environ)
    evidence_root = release_dir.parent / 'web-deployment-receipts'
    evidence_root.mkdir(parents=True, exist_ok=True)
    attempt = Path(tempfile.mkdtemp(prefix='attempt.', dir=evidence_root))
    release.write_json(attempt / 'app-gate.json', gate)
    print(f'Deployment evidence: {attempt}', flush=True)
    try:
        with tempfile.TemporaryDirectory(prefix='kemetic-web-upload-') as temporary:
            snapshot = Path(temporary)
            preflight = served.preflight_deployment_target(
                release_dir=release_dir, expected_archive_sha256=archive_hash,
                project=lane['project'], branch=lane['branch'],
                contract_path=root / served.CONTRACT_PATH, extract_to=snapshot)
            snapshot_manifest = release.file_manifest(snapshot)
            # The network gate and archive checks may take time; recheck mutable
            # source authority immediately before crossing the upload boundary.
            release.require_canonical_release_source(
                root, environment=environment, expected_source=receipt['source'])
            upload_log = attempt / 'wrangler.log'
            command = ['npx', '--yes', f'wrangler@{WRANGLER_VERSION}', 'pages', 'deploy',
                       str(snapshot / 'web'), '--project-name', lane['project'], '--branch', lane['branch']]
            status = runner(command, upload_log)
            upload = served._record_verified_upload_attempt(
                preflight=preflight, wrangler_version=WRANGLER_VERSION,
                upload_result_path=upload_log, upload_status=status)
            release.write_json(attempt / 'upload-attempt.json', upload)
            if status:
                raise served.ServedVerificationError(f'Upload failed ({status}); see {upload_log}')
            if release.file_manifest(snapshot) != snapshot_manifest:
                raise served.ServedVerificationError('Upload snapshot changed during deployment.')
            immutable = served.extract_immutable_origin(
                upload_result=upload_log.read_text(), project=lane['project'], alias_origin=lane['alias'])
            metadata = attempt / 'cloudflare-production-deployments.json'
            status = runner(['npx', '--yes', f'wrangler@{WRANGLER_VERSION}', 'pages', 'deployment',
                             'list', '--project-name', lane['project'], '--environment', 'production', '--json'],
                            metadata, attempt / 'cloudflare-production-deployments.stderr.log')
            if status:
                raise served.ServedVerificationError('Cloudflare production metadata lookup failed.')
            # Revalidate the sealed local release after the external upload, then
            # check both live origins. This is a distinct mutation boundary.
            result = served.verify_deployment(
                release_dir=release_dir, expected_archive_sha256=archive_hash,
                immutable_url=immutable, alias_url=lane['alias'], project=lane['project'],
                branch=lane['branch'], wrangler_version=WRANGLER_VERSION,
                upload_result_path=upload_log, deployment_metadata_path=metadata,
                contract_path=root / served.CONTRACT_PATH)
            release.write_json(attempt / 'served-deployment.json', result)
            release.write_json(attempt / 'result.json', dict(success=True, source=receipt['source'],
                               archive_sha256=archive_hash, gate=gate, origin=lane['alias']))
            print(f"Verified {lane['alias']} ({receipt['build_version']})", flush=True)
            return attempt / 'served-deployment.json'
    except Exception as error:
        release.write_json(attempt / 'result.json', dict(success=False, error=str(error)))
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('release_directory', type=Path)
    parser.add_argument('authorized_archive_sha256')
    parser.add_argument('environment', choices=tuple(served.CANONICAL_LANES))
    args = parser.parse_args()
    try:
        deploy(args.release_directory.resolve(), args.authorized_archive_sha256, args.environment)
        return 0
    except (release.ReleaseInputError, served.ServedVerificationError, OSError, ValueError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
