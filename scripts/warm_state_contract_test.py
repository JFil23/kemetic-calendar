#!/usr/bin/env python3
"""Release guard: retained destinations and boundaries require explicit review.

This is deliberately complementary to restart/race/visual tests, not a claim
that static source inventory establishes user-visible readiness.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONTRACT = ROOT / 'config/warm_state_release_contract.v1.json'

def routes(source):
    source = source[source.index('GoRouter _createRouter('):]
    source = source[:source.index('/* ─')]
    return set(re.findall(r"path:\s*'([^']+)'", source))

def check(root=ROOT):
    contract = json.loads((root / CONTRACT.relative_to(ROOT)).read_text())
    failures = []
    main = (root / 'lib/main.dart').read_text()
    registered = {r['path'] for r in contract['routes']}
    if routes(main) != registered:
        failures.append('Route inventory changed: review warm-read/durable-write ownership and update the route contract with evidence.')
    for entry in contract['routes']:
        if not entry['owner'] or not entry['policy'] or not (root / entry['owner']).exists():
            failures.append(f"Route ownership missing: {entry['path']}")
    for path, count in contract['minimum_read_boundaries'].items():
        actual = (root / path).read_text()
        if len(re.findall(r'WarmJsonReads\(|_warm\.(?:rows|value)\(', actual)) < count:
            failures.append(f'Persistent read boundary removed: {path}; preserve coverage or review a replacement with upgrade evidence.')
    for path, tokens in contract['required_lifecycle_contracts'].items():
        source = (root / path).read_text()
        for token in tokens:
            if token not in source:
                failures.append(f'Lifecycle contract missing from {path}: {token}')
    for path in ['lib/features/rhythm/pages/todays_alignment_page.dart',
                 'lib/features/rhythm/widgets/planner/planner_notes_section.dart',
                 'lib/features/rhythm/widgets/planner/planner_nutrition_section.dart']:
        if 'saved only on this device' in (root / path).read_text():
            failures.append(f'Local-only Planner storage fallback returned: {path}')
    return failures

if __name__ == '__main__':
    errors = check()
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        sys.exit(1)
    print('Warm-state release contracts passed.')
