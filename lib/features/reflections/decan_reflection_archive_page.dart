import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/navigation_fallback.dart';
import '../../widgets/kemetic_date_picker.dart';

import '../../data/decan_reflection_repo.dart';
import '../../data/decan_reflection_model.dart';
import '../../data/decan_reflection_prompt_state.dart';
import '../../data/maat_guidance_model.dart';
import '../../data/maat_guidance_repo.dart';
import '../calendar/kemetic_month_metadata.dart';
import 'decan_reflection_skin.dart';

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
    return DecanReflectionSkinScaffold(
      navBar: DecanReflectionNavBar(
        title: 'Decan Reflections',
        onBack: () => popOrGo(context, '/'),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(DecanReflectionTokens.gold),
          strokeWidth: 2,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Reflections could not load',
                textAlign: TextAlign.center,
                style: DecanReflectionTokens.emptyTitleStyle,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: DecanReflectionTokens.emptyBodyStyle,
              ),
              const SizedBox(height: 18),
              DecanBridgeAction(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text(
            'No reflections yet',
            textAlign: TextAlign.center,
            style: DecanReflectionTokens.emptyTitleStyle,
          ),
        ),
      );
    }

    final months = _groupArchiveEntries(_items);
    final bottomPadding =
        DecanReflectionTokens.scrollBottomPadding +
        MediaQuery.paddingOf(context).bottom;

    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
      itemCount: months.length,
      itemBuilder: (context, monthIndex) {
        final month = months[monthIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DecanMonthHeader(label: month.label),
            DecanTrack(
              children: <Widget>[
                for (var i = 0; i < month.entries.length; i++)
                  DecanChronicleEntry(
                    type: month.entries[i].type == _ArchiveEntryType.reflection
                        ? DecanChronicleEntryType.record
                        : DecanChronicleEntryType.opening,
                    dateRange: month.entries[i].dateRange,
                    title: month.entries[i].title,
                    preview: month.entries[i].preview,
                    addTopGap: i > 0,
                    onTap: () => unawaited(
                      openDetailRoute<void>(context, month.entries[i].route),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
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

class _ArchiveMonth {
  const _ArchiveMonth({required this.label, required this.entries});

  final String label;
  final List<_ArchiveEntry> entries;
}

List<_ArchiveMonth> _groupArchiveEntries(List<_ArchiveEntry> entries) {
  final months = <_ArchiveMonth>[];
  String? currentKey;
  var currentEntries = <_ArchiveEntry>[];

  void flush() {
    if (currentEntries.isEmpty) return;
    months.add(
      _ArchiveMonth(
        label: _monthLabelFor(currentEntries.first.sortDate),
        entries: List<_ArchiveEntry>.unmodifiable(currentEntries),
      ),
    );
    currentEntries = <_ArchiveEntry>[];
  }

  for (final entry in entries) {
    final key = _monthKeyFor(entry.sortDate);
    if (currentKey != null && key != currentKey) {
      flush();
    }
    currentKey = key;
    currentEntries.add(entry);
  }
  flush();
  return months;
}

String _monthKeyFor(DateTime date) {
  final kDate = KemeticMath.fromGregorian(date.toLocal());
  return '${kDate.kYear}:${kDate.kMonth}';
}

String _monthLabelFor(DateTime date) {
  final kDate = KemeticMath.fromGregorian(date.toLocal());
  return getMonthById(kDate.kMonth).displayShort;
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
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
