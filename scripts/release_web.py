#!/usr/bin/env python3
"""Qualify and prepare one canonical web release; upload only with --deploy."""
from __future__ import annotations
import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import app_gate
import deploy_web_release
import web_release_pipeline as release

ROOT = Path(__file__).resolve().parents[1]


def gh_json(url: str, *, environ) -> dict:
    return json.loads(subprocess.check_output(['gh', 'api', url], cwd=ROOT, text=True, env=environ))


def qualify(commit: str, environment: str, *, fetch=gh_json, run=subprocess.run, sleep=time.sleep) -> dict:
    kwargs = dict(environment=environment, environ=os.environ, fetch_json=fetch)
    current = release.latest_app_gate_run(commit, **kwargs)
    if current is None:
        run(['gh', 'workflow', 'run', release.APP_GATE_WORKFLOW_FILE,
             '--repo', release.GITHUB_REPOSITORY, '--ref', release.authorized_git_source_branch(environment),
             '-f', f'expected_sha={commit}'], cwd=ROOT, check=True)
        for _ in range(30):
            current = release.latest_app_gate_run(commit, **kwargs)
            if current is not None:
                break
            sleep(2)
        if current is None:
            raise release.ReleaseInputError('Dispatched gate is not visible yet. Inspect Actions before another dispatch; no artifact was built.')
    if current.get('status') != 'completed':
        run(['gh', 'run', 'watch', str(int(current['id'])), '--repo', release.GITHUB_REPOSITORY,
             '--exit-status', '--interval', '15'], cwd=ROOT, check=True,
            stdout=subprocess.DEVNULL)
    return release.require_green_app_gate(commit, **kwargs)


def prepare(environment: str, log_dir: Path, existing: Path | None = None) -> tuple[Path, dict]:
    source = release.require_canonical_release_source(ROOT, environment=environment)
    gate = qualify(source['app_source_commit'], environment)
    release.write_json(log_dir / 'app-gate.json', gate)
    if existing is not None:
        directory = existing.resolve()
    else:
        build_log = log_dir / 'build.log'
        result = app_gate.run_step(['bash', 'scripts/build_web_release.sh', environment], root=ROOT, log=build_log)
        if result['exit_code']:
            raise release.ReleaseInputError(f'Build failed; see {build_log}')
        paths = [line.removeprefix('release_dir=') for line in build_log.read_text().splitlines()
                 if line.startswith('release_dir=')]
        if len(paths) != 1:
            raise release.ReleaseInputError('Builder did not report exactly one sealed release directory.')
        directory = Path(paths[0])
    receipt = release.verify_release(directory)
    if receipt['environment'] != environment:
        raise release.ReleaseInputError('Artifact belongs to another lane.')
    release.require_canonical_release_source(ROOT, environment=environment, expected_source=receipt['source'])
    return directory, receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('environment', choices=tuple(release.ENVIRONMENT_CONFIGS))
    parser.add_argument('--deploy', action='store_true', help='Also upload and verify the sealed artifact.')
    parser.add_argument('--release-dir', type=Path, help='Resume with this sealed artifact without rebuilding.')
    args = parser.parse_args()
    logs = Path(tempfile.mkdtemp(prefix='kemet-release-'))
    print(f'Release logs: {logs}', flush=True)
    try:
        directory, receipt = prepare(args.environment, logs, args.release_dir)
        result = dict(source=receipt['source'], environment=args.environment,
                      release_dir=str(directory), archive_sha256=receipt['payload']['archive_sha256'],
                      gate=release.load_json(logs / 'app-gate.json'), deployed=False)
        release.write_json(logs / 'release.json', result)
        if args.deploy:
            served = deploy_web_release.deploy(directory, result['archive_sha256'], args.environment)
            result.update(deployed=True, served_receipt=str(served))
            release.write_json(logs / 'release.json', result)
        print(json.dumps(result, indent=2))
        return 0
    except (release.ReleaseInputError, deploy_web_release.served.ServedVerificationError,
            subprocess.CalledProcessError, OSError, ValueError) as error:
        release.write_json(logs / 'failure.json', dict(error=str(error)))
        print(f'ERROR: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
