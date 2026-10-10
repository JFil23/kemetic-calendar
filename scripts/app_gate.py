#!/usr/bin/env python3
"""Focused implementation checks and the complete release suite, with saved logs.

Selection chooses coverage; release qualification verifies hosted full-run
proof separately. Unknown inputs or a changed Dart owner without a reachable
test fall back to the complete suite.
"""
from __future__ import annotations

import argparse
import json
import os
import posixpath
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FULL_SUITE_SHARDS = 4
CONTRACT_TESTS = (
    'web_release_pipeline_test.py', 'maat_visual_contract_test.py',
    'netjeru_art_contract_test.py', 'warm_state_contract_test.py',
    'flow_detail_authority_contract_test.py', 'validate_deep_links_test.py',
    'served_artifact_verifier_test.py', 'public_site_test.py',
    'app_gate_test.py', 'deploy_web_release_test.py', 'release_web_test.py',
)


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(['git', *args], cwd=root, text=True)


def changed_paths(root: Path, base: str, head: str | None) -> list[str]:
    # --no-renames includes both the deleted and added identity of a rename.
    paths = set(git(root, 'diff', '--name-only', '--no-renames', '-z', base,
                    *([head] if head else [])).split('\0'))
    if head is None:
        paths.update(git(root, 'ls-files', '--others', '--exclude-standard', '-z').split('\0'))
    return sorted(paths - {''})


def dart_dependencies(path: str, text: str, package: str) -> set[str]:
    result = set()
    for directive in re.findall(r'\b(?:import|export|part)\s+([^;]+);', text):
        for uri in re.findall(r'''["']([^"']+)["']''', directive):
            if uri.startswith(f'package:{package}/'):
                result.add('lib/' + uri.split('/', 1)[1])
            elif ':' not in uri:
                result.add(posixpath.normpath(posixpath.join(posixpath.dirname(path), uri)))
    return result


def is_documentation(path: str) -> bool:
    return path.endswith('.md') and (path.startswith('docs/') or '/' not in path)


def plan(root: Path, paths: list[str] | None) -> dict:
    if paths == [] or (paths is not None and all(is_documentation(p) for p in paths)):
        return dict(full=False, reason='Documentation only; no runtime inputs changed.',
                    contracts=False, analyze=False, tests=[], browser=[])
    sources = {p.relative_to(root).as_posix(): p.read_text() for folder in ('lib', 'test')
               for p in (root / folder).rglob('*.dart')}
    tests = {p for p in sources if p.startswith('test/') and p.endswith('_test.dart')}
    browser = {p for p in tests if re.search(r"@TestOn\s*\([^)]*browser", sources[p])}
    full = paths is None
    reason = 'Complete release qualification.' if full else 'Tests that import affected Dart owners.'
    selected = set()
    changed_dart = [p for p in paths or [] if p.endswith('.dart')]
    if not full:
        tooling = lambda p: p.startswith(('scripts/', '.github/', 'public-site/')) or p == 'docs/web_release_build_contract.md'
        unknown = [p for p in paths if not (is_documentation(p) or tooling(p) or
                    (p.endswith('.dart') and p.startswith(('lib/', 'test/'))))]
        if unknown:
            full, reason = True, 'Non-import inputs changed: ' + ', '.join(unknown[:5])
        else:
            package = re.search(r'^name:\s*(\S+)', (root / 'pubspec.yaml').read_text(), re.M).group(1)
            reverse: dict[str, set[str]] = {}
            for path, source in sources.items():
                reads = set(re.findall(r"File\s*\(\s*['\"]([^'\"$]+)['\"]", source))
                for dependency in dart_dependencies(path, source, package) | reads:
                    reverse.setdefault(dependency, set()).add(path)
            for changed in paths:
                seen, queue = set(), [changed]
                while queue:
                    current = queue.pop()
                    if current in seen:
                        continue
                    seen.add(current)
                    queue.extend(reverse.get(current, ()))
                affected = tests & seen
                if not affected and changed in changed_dart:
                    full, reason = True, f'No reachable test for {changed}; use the full suite.'
                    break
                selected.update(affected)
            guard = 'test/core/web_runtime_config_guard_test.dart'
            if any(p.startswith(('scripts/', '.github/')) for p in paths) and guard in tests:
                selected.add(guard)
    return dict(full=full, reason=reason, contracts=True,
                analyze=full or bool(changed_dart),
                tests=['test'] if full else sorted(selected - browser),
                browser=sorted(browser if full else selected & browser))


def test_files(root: Path) -> list[str]:
    # Match Flutter's discovery: recurse under test/, do not follow directory
    # links, and include every file ending in _test.dart. Partition files before
    # invoking Flutter; its native shard flags load every suite on every worker.
    return sorted((Path(directory) / name).relative_to(root).as_posix()
                  for directory, _, names in os.walk(root / 'test', followlinks=False)
                  for name in names if name.endswith('_test.dart')
                  and (Path(directory) / name).is_file())


def shard_files(root: Path, index: int) -> list[str]:
    if index not in range(FULL_SUITE_SHARDS):
        raise ValueError('A valid index is required for every full-suite shard.')
    files = test_files(root)[index::FULL_SUITE_SHARDS]
    if not files:
        raise ValueError('An empty shard must not silently run the default full suite.')
    return files


def commands(selection: dict, *, phase: str = 'all', shard_index: int | None = None,
             root: Path = ROOT) -> list[list[str]]:
    if phase not in ('all', 'preflight', 'tests'):
        raise ValueError('Unknown gate phase.')
    if phase != 'all' and not selection['full']:
        raise ValueError('Only the complete suite can be split into phases.')
    if phase == 'tests':
        return [['flutter', 'pub', 'get', '--enforce-lockfile'],
                ['flutter', 'test', '--no-pub', *shard_files(root, shard_index)]]
    if shard_index is not None:
        raise ValueError('A shard index is only valid for the tests phase.')
    result = []
    if selection['contracts']:
        result.append(['node', '--test', 'scripts/web_bootstrap_test.mjs'])
        result.extend([sys.executable, 'scripts/' + name] for name in CONTRACT_TESTS)
        result.append([sys.executable, '-m', 'py_compile', *['scripts/' + name for name in ('maat_visual_contract_test.py', 'web_release_pipeline.py', 'web_release_pipeline_test.py', 'served_artifact_verifier.py', 'served_artifact_verifier_test.py', 'app_gate.py', 'deploy_web_release.py', 'release_web.py')]])
        result.append(['bash', '-n', 'scripts/build_web_release.sh', 'scripts/deploy_cloudflare_pages.sh'])
        for name in ('staging.public.json', 'production.public.json',
                     'cloudflare-served-contract.v1.json', 'environment-delta-contract.v1.json'):
            result.append([sys.executable, '-m', 'json.tool', 'config/web/' + name])
    if selection['analyze'] or selection['tests'] or selection['browser']:
        result.append(['flutter', 'pub', 'get', '--enforce-lockfile'])
    if selection['analyze']:
        result.append(['flutter', 'analyze', '--no-fatal-infos'])
    if selection['browser']:
        result.append(['flutter', 'test', '--no-pub', '--platform', 'chrome', *selection['browser']])
    if selection['tests'] and phase != 'preflight':
        result.append(['flutter', 'test', '--no-pub', *selection['tests']])
    return result


def run_step(command: list[str], *, root: Path, log: Path) -> dict:
    started = time.monotonic()
    env = dict(os.environ, TZ='America/Los_Angeles', PYTHONDONTWRITEBYTECODE='1')
    with log.open('w') as output:
        process = subprocess.run(command, cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT)
    result = dict(command=command, exit_code=process.returncode,
                  seconds=round(time.monotonic() - started, 2), log=str(log))
    if process.returncode:
        print('\n'.join(log.read_text(errors='replace').splitlines()[-60:]), file=sys.stderr)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('changed', 'full'))
    parser.add_argument('--base', default='HEAD')
    parser.add_argument('--head', help='Omit to include staged, unstaged and untracked changes.')
    parser.add_argument('--plan', action='store_true', help='Inspect selection without running checks.')
    parser.add_argument('--log-dir', type=Path)
    parser.add_argument('--phase', choices=('all', 'preflight', 'tests'), default='all')
    parser.add_argument('--shard-index', type=int)
    args = parser.parse_args()
    try:
        paths = None if args.mode == 'full' else changed_paths(ROOT, args.base, args.head)
    except subprocess.CalledProcessError:
        paths = None  # Missing history must never produce an empty success.
    selection = plan(ROOT, paths)
    if args.plan:
        print(json.dumps(selection, indent=2))
        return 0
    logs = args.log_dir or Path(tempfile.mkdtemp(prefix='kemet-app-gate-'))
    logs.mkdir(parents=True, exist_ok=True)
    summary = dict(mode=args.mode, phase=args.phase, shard_index=args.shard_index,
                   total_shards=FULL_SUITE_SHARDS if args.phase == 'tests' else None,
                   selection=selection, changed_paths=paths, steps=[], success=False,
                   test_inventory=test_files(ROOT) if args.phase == 'preflight' else None,
                   shard_files=shard_files(ROOT, args.shard_index) if args.phase == 'tests' else None)
    print(selection['reason'], flush=True)
    print(f'Logs: {logs}', flush=True)
    try:
        for index, command in enumerate(commands(selection, phase=args.phase, shard_index=args.shard_index)):
            step = run_step(command, root=ROOT, log=logs / f'{index:02d}.log')
            summary['steps'].append(step)
            print(f"{'PASS' if step['exit_code'] == 0 else 'FAIL'} {command[0]} {command[1]} ({step['seconds']}s)", flush=True)
            if step['exit_code']:
                return step['exit_code']
        summary['success'] = True
        return 0
    finally:
        (logs / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')


if __name__ == '__main__':
    raise SystemExit(main())
