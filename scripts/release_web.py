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
import public_site
import web_release_pipeline as release

ROOT = Path(__file__).resolve().parents[1]


def gh_json(url: str, *, environ) -> dict:
    return json.loads(subprocess.check_output(['gh', 'api', url], cwd=ROOT, text=True, env=environ))


def qualify(commit: str, environment: str, *, fetch=gh_json, run=subprocess.run, sleep=time.sleep) -> dict:
    kwargs = dict(environment=environment, environ=os.environ, fetch_json=fetch)

    def visible_run(after_id=None):
        # A newly pushed commit may not be visible in Actions immediately. Do
        # not race its automatic run by dispatching another complete suite.
        for _ in range(30):
            current = release.latest_app_gate_run(commit, **kwargs)
            if current is not None and current["id"] != after_id:
                return current
            sleep(2)
        raise release.ReleaseInputError(
            "Candidate App run is not visible yet. Inspect Actions before restarting; no duplicate gate was dispatched."
        )

    current = visible_run()
    for stage in range(2):
        if current.get('status') != 'completed':
            print(f"Waiting for existing App run {current['id']}; no duplicate suite.", flush=True)
            run(['gh', 'run', 'watch', str(int(current['id'])), '--repo', release.GITHUB_REPOSITORY,
                 '--exit-status', '--interval', '15'], cwd=ROOT, check=True,
                stdout=subprocess.DEVNULL)
        current = release.latest_app_gate_run(commit, **kwargs)
        if current is None:
            raise release.ReleaseInputError('Candidate App run disappeared; qualification stopped.')
        scope = release.app_gate_run_scope(current, environ=os.environ, fetch_json=fetch)
        if scope == 'full':
            print(f"Reusing complete App run {current['id']} for this exact candidate.", flush=True)
            return release.require_green_app_gate(commit, **kwargs)
        if stage:
            raise release.ReleaseInputError('Requested complete App gate returned only focused evidence.')
        previous_id = current['id']
        run(['gh', 'workflow', 'run', release.APP_GATE_WORKFLOW_FILE,
             '--repo', release.GITHUB_REPOSITORY, '--ref', release.authorized_git_source_branch(environment),
             '-f', f'expected_sha={commit}'], cwd=ROOT, check=True)
        current = visible_run(after_id=previous_id)
    raise AssertionError('Unreachable qualification state')


def qualify_source(environment: str, log_dir: Path, expected_commit: str | None = None) -> str:
    source = release.require_canonical_release_source(ROOT, environment=environment)
    commit = source['app_source_commit']
    if expected_commit is not None and commit != expected_commit:
        raise release.ReleaseInputError('Background release candidate changed before qualification.')
    gate = qualify(commit, environment)
    current = release.require_canonical_release_source(ROOT, environment=environment)
    if current['app_source_commit'] != commit:
        raise release.ReleaseInputError('Release candidate changed while waiting for qualification.')
    release.write_json(log_dir / 'app-gate.json', gate)
    return commit


def prepare(environment: str, log_dir: Path, existing: Path | None = None, expected_commit: str | None = None) -> tuple[Path, dict]:
    commit = qualify_source(environment, log_dir, expected_commit)
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
    if receipt['source']['app_commit'] != commit:
        raise release.ReleaseInputError('Artifact belongs to another candidate.')
    if receipt['environment'] != environment:
        raise release.ReleaseInputError('Artifact belongs to another lane.')
    release.require_canonical_release_source(ROOT, environment=environment, expected_source=receipt['source'])
    return directory, receipt


def publish_site_preview(logs: Path, existing: Path | None = None,
                         expected_commit: str | None = None, *,
                         runner=deploy_web_release.run_process,
                         fetch=public_site.curl_once) -> dict:
    """Use the shared qualification owner, then upload only the public-site seal."""
    commit = qualify_source('production', logs, expected_commit)
    directory = existing.resolve() if existing else public_site.seal(ROOT)
    receipt, _, _ = public_site.verify_seal(directory)
    public_site.require(receipt['source_commit'] == commit, 'Website seal belongs to another candidate.')
    public_site.source_identity(ROOT, public_site.validate_payload(directory / 'payload')[0])
    # This is a Cloudflare preview label, never a Git branch or source checkout.
    preview_label = 'website-preview-' + commit[:12]
    baseline = fetch(public_site.ORIGIN + '/')
    public_site.require(baseline.status == 200 and baseline.url == public_site.ORIGIN + '/',
                        'Cannot establish the existing public website identity.')
    before = dict(origin=public_site.ORIGIN, status=baseline.status, sha256=public_site.sha(baseline.body))
    release.write_json(logs / 'production-before.json', before)
    current = release.require_canonical_release_source(ROOT, environment='production')
    public_site.require(current['app_source_commit'] == commit, 'Website candidate changed before upload.')
    public_site.verify_seal(directory)
    upload_log = logs / 'wrangler.log'
    command = ['npx', '--yes', f'wrangler@{deploy_web_release.WRANGLER_VERSION}', 'pages', 'deploy',
               str(directory / 'payload'), '--project-name', public_site.PROJECT,
               '--branch', preview_label, '--commit-hash', commit, '--commit-dirty=false']
    if runner(command, upload_log):
        raise release.ReleaseInputError(f'Website preview upload failed; see {upload_log}')
    origin = deploy_web_release.served.extract_immutable_origin(
        upload_result=upload_log.read_text(), project=public_site.PROJECT, alias_origin=public_site.ORIGIN)
    public_site.verify_seal(directory)
    metadata = logs / 'cloudflare-preview-deployments.json'
    if runner(['npx', '--yes', f'wrangler@{deploy_web_release.WRANGLER_VERSION}', 'pages', 'deployment',
               'list', '--project-name', public_site.PROJECT, '--environment', 'preview', '--json'], metadata):
        raise release.ReleaseInputError('Cannot verify the Cloudflare preview deployment identity.')
    matches = [item for item in json.loads(metadata.read_text()) if item.get('Deployment') == origin]
    public_site.require(len(matches) == 1, 'Preview deployment metadata is missing or ambiguous.')
    deployment = matches[0]
    source = deployment.get('Source', '')
    public_site.require(deployment.get('Environment') == 'Preview' and
                        deployment.get('Branch') == preview_label and
                        isinstance(source, str) and 7 <= len(source) <= 40 and commit.startswith(source),
                        'Cloudflare preview environment, label or source mismatch.')
    served = public_site.verify_live(directory, origin, fetch=fetch)
    release.write_json(logs / 'served-public-site.json', served)
    after = fetch(public_site.ORIGIN + '/')
    after_identity = dict(origin=public_site.ORIGIN, status=after.status, sha256=public_site.sha(after.body))
    release.write_json(logs / 'production-after.json', after_identity)
    public_site.require(after.url == public_site.ORIGIN + '/' and before == after_identity,
                        'Production website identity changed during the preview upload.')
    result = dict(source_commit=commit, project=public_site.PROJECT, environment='preview',
                  preview_label=preview_label, origin=origin, release_dir=str(directory),
                  gate=release.load_json(logs / 'app-gate.json'), deployed=True,
                  served_receipt=str(logs / 'served-public-site.json'))
    release.write_json(logs / 'release.json', result)
    return result



def launch_background(environment: str, logs: Path, existing: Path | None, deploy: bool,
                      public_site_preview: bool = False) -> dict:
    if public_site_preview and (environment != 'production' or not deploy):
        raise release.ReleaseInputError('Public website previews require production source and --deploy.')
    source = release.require_canonical_release_source(ROOT, environment=environment)
    if (logs / 'process.json').exists():
        raise release.ReleaseInputError('This release attempt already has a background coordinator; inspect its PID and logs.')
    command = [sys.executable, '-u', str(Path(__file__).resolve()), environment,
               '--log-dir', str(logs), '--expected-sha', source['app_source_commit']]
    if existing is not None:
        command.extend(['--release-dir', str(existing.resolve())])
    if deploy:
        command.append('--deploy')
    if public_site_preview:
        command.append('--public-site-preview')
    output = logs / 'coordinator.log'
    with output.open('w') as stream:
        process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL,
                                   stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
    result = dict(pid=process.pid, commit=source['app_source_commit'], environment=environment,
                  log_dir=str(logs), log=str(output), deployed=False, background=True,
                  public_site_preview=public_site_preview)
    release.write_json(logs / 'process.json', result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('environment', choices=tuple(release.ENVIRONMENT_CONFIGS))
    parser.add_argument('--deploy', action='store_true', help='Also upload and verify the sealed artifact.')
    parser.add_argument('--release-dir', type=Path, help='Resume with this sealed artifact without rebuilding.')
    parser.add_argument('--background', action='store_true', help='Start once, save PID/logs, and return without agent polling.')
    parser.add_argument('--log-dir', type=Path, help='Directory for this release attempt and its receipts.')
    parser.add_argument('--expected-sha', help=argparse.SUPPRESS)
    parser.add_argument('--public-site-preview', action='store_true',
                        help='Publish the isolated public website to a temporary Cloudflare preview address.')
    args = parser.parse_args()
    logs = args.log_dir.resolve() if args.log_dir else Path(tempfile.mkdtemp(prefix='kemet-release-'))
    logs.mkdir(parents=True, exist_ok=True)
    print(f'Release logs: {logs}', flush=True)
    try:
        if args.public_site_preview and (args.environment != 'production' or not args.deploy):
            raise release.ReleaseInputError('Public website previews require production source and --deploy.')
        if args.background:
            print(json.dumps(launch_background(args.environment, logs, args.release_dir, args.deploy,
                                               args.public_site_preview), indent=2))
            return 0
        if args.public_site_preview:
            print(json.dumps(publish_site_preview(logs, args.release_dir, args.expected_sha), indent=2))
            return 0
        directory, receipt = prepare(args.environment, logs, args.release_dir, args.expected_sha)
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
    except (release.ReleaseInputError, deploy_web_release.served.ServedVerificationError, public_site.PublicSiteError,
            subprocess.CalledProcessError, OSError, ValueError) as error:
        release.write_json(logs / 'failure.json', dict(error=str(error)))
        print(f'ERROR: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
