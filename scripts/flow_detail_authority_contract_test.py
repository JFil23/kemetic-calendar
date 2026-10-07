#!/usr/bin/env python3
"""Guard the universal flow-detail ownership contract (also exercised in Flutter)."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
files = {str(p.relative_to(ROOT)): p.read_text() for p in (ROOT / 'lib').rglob('*.dart')}
errors = []

# These are source/loading adapters or the existing canonical renderers. A new
# flow-detail page must be reviewed as a refactor of an owner, never an entry-
# specific visual alternative. Ma'at Guidance is a separate content type.
owners = {
    '_FlowPreviewPage': 'lib/features/calendar/calendar_flow_pages.dart',
    '_ActiveMaatFlowDetailSurface': 'lib/features/calendar/calendar_active_maat_flows.dart',
    'SharedFlowDetailsPage': 'lib/features/inbox/shared_flow_details_page.dart',
    'FlowPostDetailPage': 'lib/features/profile/flow_post_detail_page.dart',
    'ArchivedMaatFlowDetailView': 'lib/features/calendar/presentation/archived_maat_flow_detail_view.dart',
    'MaatGuidanceDetailPage': 'lib/features/maat_guidance/maat_guidance_detail_page.dart',
}
pattern = re.compile(r'class\s+(\w*(?:Flow|Maat)\w*(?:Detail|Preview)\w*(?:Page|Surface|View))\b')
for path, source in files.items():
    for match in pattern.finditer(source):
        if owners.get(match[1]) != path:
            errors.append(f'{path}: unregistered full-detail owner {match[1]}')
    for retired in ('useCanonicalUserFlowDetail', 'useMySavedExpansionParity', 'InboxFlowDetailsPage', 'Widget _buildDashboardBody(', 'Widget _buildFlowBody('):
        if retired in source:
            errors.append(f'{path}: retired alternate detail contract {retired}')

# Full Ma'at views may be constructed by the common composition owner; Reading
# House's authoring/room adapters use that same view and its existing authority.
core = 'lib/features/calendar/calendar_active_maat_flows.dart'
renderers = {
    'FollowSkyDetailSurface': 'lib/features/calendar/follow_the_sky/presentation/follow_sky_detail_page.dart',
    'OfferingTableDetailSurface': 'lib/features/calendar/the_offering_table/presentation/offering_table_detail_page.dart',
    'ReadingHouseDetailSurface': 'lib/features/calendar/the_reading_house/presentation/reading_house_detail_page.dart',
    'DjedDetailSurface': 'lib/features/calendar/the_djed/presentation/djed_detail_page.dart',
    'KarDetailSurface': 'lib/features/calendar/the_kar/presentation/kar_detail_surface.dart',
}
for renderer, owner in renderers.items():
    allowed = {owner, core}
    if renderer == 'ReadingHouseDetailSurface':
        allowed.update({'lib/features/calendar/reading_house_authoring_page.dart',
                        'lib/features/shared_practice/shared_practice_room_page.dart'})
    for path, source in files.items():
        if re.search(r'\b' + renderer + r'\s*\(', source) and path not in allowed:
            errors.append(f'{path}: bypasses canonical composition for {renderer}')

for path in (core, 'lib/features/calendar/calendar_user_flow_detail.dart'):
    if 'FlowDetailCalendarScope(' not in files[path]:
        errors.append(f'{path}: missing account calendar read boundary')
shared = files['lib/features/inbox/shared_flow_details_page.dart']
for required in ('CalendarPage.buildCanonicalOwnedFlowDetail(', 'CalendarPage.buildCanonicalFlowDetail('):
    if required not in shared:
        errors.append(f'shared source adapter must use {required}')
if 'buildCanonicalMaatFlowDetail(' in shared:
    errors.append('shared adapter must not own flow-kind dispatch')
custom = files['lib/features/calendar/calendar_user_flow_detail.dart']
predicate = custom.split('bool _usesUserFlowDetailSurface(', 1)[1].split('Widget _buildUserFlowDetailSurface', 1)[0]
if 'kDiscoverableMaatFlowKinds.contains(kind)' not in predicate or 'kArchivedCompatibilityMaatFlowKinds.contains(kind)' not in predicate:
    errors.append('only supported Ma’at kinds may bypass the My Flows fallback')
if 'widget.' in predicate:
    errors.append('custom detail presentation must not depend on an entry/mode flag')

if errors:
    raise SystemExit('\n'.join(errors))
print('Universal flow detail authority: PASS (owners, kind dispatch, calendar context, retired alternatives)')
