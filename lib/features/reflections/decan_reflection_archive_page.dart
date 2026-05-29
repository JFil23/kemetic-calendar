import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/global_bottom_menu_metrics.dart';
import '../../core/navigation_fallback.dart';
import '../../shared/glossy_text.dart';

import '../../data/decan_reflection_repo.dart';
import '../../data/decan_reflection_model.dart';
import '../../data/decan_reflection_prompt_state.dart';
import '../../data/maat_guidance_model.dart';
import '../../data/maat_guidance_repo.dart';

class DecanReflectionArchivePage extends StatefulWidget {
  const DecanReflectionArchivePage({super.key});

  @override
  State<DecanReflectionArchivePage> createState() =>
      _DecanReflectionArchivePageState();
}

class _DecanReflectionArchivePageState
    extends State<DecanReflectionArchivePage> {
  final _repo = DecanReflectionRepo(Supabase.instance.client);
  final _maatRepo = MaatGuidanceRepo(Supabase.instance.client);
  final _promptState = DecanReflectionPromptState(Supabase.instance.client);
  List<_ArchiveEntry> _items = const [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final result = await _repo.listMineResult();
    final openingResult = await _maatRepo.listDecanOpeningsForArchive();
    final entries = _buildArchiveEntries(
      reflections: result.data,
      openings: openingResult.data,
    );
    final latestReflection = result.data.fold<DecanReflection?>(
      null,
      (latest, reflection) =>
          latest == null || reflection.decanStart.isAfter(latest.decanStart)
          ? reflection
          : latest,
    );
    if (latestReflection != null) {
      await _promptState.markInteracted(latestReflection.decanStart);
      await _repo.markPromptInteracted(
        decanStart: latestReflection.decanStart,
        decanEnd: latestReflection.decanEnd,
        interactionKind: 'archived',
      );
    }
    if (!mounted) return;
    setState(() {
      _items = entries;
      _errorMessage = decanReflectionArchiveVisibleError(
        hasVisibleItems: entries.isNotEmpty,
        reflectionErrorMessage: result.errorMessage,
        openingErrorMessage: openingResult.errorMessage,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final listBottomPadding = bottomPaddingAboveGlobalMenu(context, 16);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => popOrGo(context, '/'),
        ),
        iconTheme: const IconThemeData(color: KemeticGold.base),
        title: const Text(
          'Decan Reflections',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(KemeticGold.base),
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reflections could not load',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: KemeticGold.icon(Icons.refresh, size: 18),
                      label: KemeticGold.text(
                        'Try again',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _items.isEmpty
          ? Center(
              child: Text(
                'No reflections yet',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(0, 0, 0, listBottomPadding),
              itemCount: _items.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: Color(0xFF222222), height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  onTap: () => context.go(item.route),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        item.dateRange,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

enum _ArchiveEntryType { reflection, opening }

List<_ArchiveEntry> _buildArchiveEntries({
  required List<DecanReflection> reflections,
  required List<MaatGuidanceDelivery> openings,
}) {
  return <_ArchiveEntry>[
    ...reflections.map(_ArchiveEntry.reflection),
    ...openings.where(_isArchivedOpening).map(_ArchiveEntry.opening),
  ]..sort((a, b) => b.sortDate.compareTo(a.sortDate));
}

bool _isArchivedOpening(MaatGuidanceDelivery delivery) {
  return delivery.status == MaatGuidanceStatus.opened ||
      delivery.status == MaatGuidanceStatus.acted ||
      delivery.status == MaatGuidanceStatus.archiveOnly;
}

@visibleForTesting
String? decanReflectionArchiveVisibleError({
  required bool hasVisibleItems,
  String? reflectionErrorMessage,
  String? openingErrorMessage,
}) {
  if (hasVisibleItems) return null;
  return reflectionErrorMessage ?? openingErrorMessage;
}

@visibleForTesting
List<({String id, String title, String route, String preview})>
buildDecanReflectionArchiveRowsForTesting(List<DecanReflection> reflections) {
  return _buildArchiveEntries(
        reflections: reflections,
        openings: const <MaatGuidanceDelivery>[],
      )
      .where((entry) => entry.type == _ArchiveEntryType.reflection)
      .map(
        (entry) => (
          id: entry.id,
          title: entry.title,
          route: entry.route,
          preview: entry.preview,
        ),
      )
      .toList(growable: false);
}

@visibleForTesting
List<({String id, String title, String route, String preview})>
buildDecanOpeningArchiveRowsForTesting(List<MaatGuidanceDelivery> openings) {
  return _buildArchiveEntries(
        reflections: const <DecanReflection>[],
        openings: openings,
      )
      .where((entry) => entry.type == _ArchiveEntryType.opening)
      .map(
        (entry) => (
          id: entry.id,
          title: entry.title,
          route: entry.route,
          preview: entry.preview,
        ),
      )
      .toList(growable: false);
}

class _ArchiveEntry {
  const _ArchiveEntry._({
    required this.type,
    required this.id,
    required this.title,
    required this.dateRange,
    required this.preview,
    required this.route,
    required this.sortDate,
  });

  factory _ArchiveEntry.reflection(DecanReflection reflection) {
    return _ArchiveEntry._(
      type: _ArchiveEntryType.reflection,
      id: reflection.id,
      title: reflection.decanName,
      dateRange:
          '${_dateOnly(reflection.decanStart)} → ${_dateOnly(reflection.decanEnd)}',
      preview: _clip(reflection.reflectionText),
      route: '/reflections/${Uri.encodeComponent(reflection.id)}',
      sortDate: reflection.decanStart,
    );
  }

  factory _ArchiveEntry.opening(MaatGuidanceDelivery delivery) {
    final dates = _periodDates(delivery.decanPeriodKey);
    return _ArchiveEntry._(
      type: _ArchiveEntryType.opening,
      id: delivery.id,
      title: 'Opening — ${_openingTitle(delivery)}',
      dateRange: dates == null
          ? 'Decan opening'
          : '${_dateOnly(dates.start)} → ${_dateOnly(dates.end)}',
      preview: _clip(delivery.teaserText),
      route: '/maat-guidance/${Uri.encodeComponent(delivery.id)}',
      sortDate: dates?.start ?? delivery.createdAt ?? DateTime.now(),
    );
  }

  final _ArchiveEntryType type;
  final String id;
  final String title;
  final String dateRange;
  final String preview;
  final String route;
  final DateTime sortDate;
}

({DateTime start, DateTime end})? _periodDates(String periodKey) {
  final parts = periodKey.split(':');
  if (parts.length < 2) return null;
  final start = DateTime.tryParse(parts[0]);
  final end = DateTime.tryParse(parts[1]);
  if (start == null || end == null) return null;
  return (start: start, end: end);
}

String _openingTitle(MaatGuidanceDelivery delivery) {
  final firstLine = delivery.bodyText
      .split(RegExp(r'\n\s*\n'))
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  const prefix = 'This decan opens through ';
  if (firstLine.startsWith(prefix)) {
    return firstLine.substring(prefix.length).replaceAll(RegExp(r'\.$'), '');
  }
  return 'Decan Opening';
}

String _dateOnly(DateTime date) =>
    date.toLocal().toIso8601String().split('T').first;

String _clip(String value) {
  final text = value.trim();
  return text.length > 120 ? '${text.substring(0, 120)}…' : text;
}
