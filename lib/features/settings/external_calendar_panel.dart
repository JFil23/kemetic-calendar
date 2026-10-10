import 'package:flutter/material.dart';

import '../../shared/glossy_text.dart';

/// Presentation only. The account-scoped import owner supplies confirmed state.
enum ExternalCalendarPanelState {
  disconnected,
  loading,
  choosing,
  selectionChanged,
  needsSelection,
  connected,
  refreshing,
  paused,
  offline,
  reconnectRequired,
  unconfigured,
}

@immutable
class ExternalCalendarChoice {
  const ExternalCalendarChoice({
    required this.id,
    required this.name,
    required this.selected,
    this.detail,
  });

  final String id;
  final String name;
  final bool selected;
  final String? detail;
}

/// Uses the existing Settings card, typography and action geometry. It owns no
/// asynchronous work, persistence, permission request, or platform detection.
class ExternalCalendarPanel extends StatelessWidget {
  const ExternalCalendarPanel({
    super.key,
    required this.state,
    this.accountLabel,
    this.lastUpdatedLabel,
    this.importedEventCount,
    this.readFailed = false,
    this.onRetryRead,
    this.selectionRecoveryMessage,
    this.calendars = const [],
    this.automaticImport = true,
    this.hasConnection = true,
    this.appleImportAvailable = false,
    this.showAppleAvailability = true,
    this.onConnect,
    this.onRefresh,
    this.onRetry,
    this.onChooseCalendars,
    this.onSelectionChanged,
    this.onSaveSelection,
    this.onCancelSelection,
    this.onAutomaticChanged,
    this.onDisconnect,
    this.onAppleImport,
  });

  final ExternalCalendarPanelState state;
  final String? accountLabel;
  final String? lastUpdatedLabel;
  final int? importedEventCount;
  final bool readFailed;
  final VoidCallback? onRetryRead;
  final String? selectionRecoveryMessage;
  final List<ExternalCalendarChoice> calendars;
  final bool automaticImport, hasConnection;

  /// Enable only after native import is supported and verified for this build.
  final bool appleImportAvailable;
  final bool showAppleAvailability;
  final VoidCallback? onConnect;
  final VoidCallback? onRefresh;
  final VoidCallback? onRetry;
  final VoidCallback? onChooseCalendars;
  final void Function(String id, bool selected)? onSelectionChanged;
  final VoidCallback? onSaveSelection;
  final VoidCallback? onCancelSelection;
  final ValueChanged<bool>? onAutomaticChanged;
  final VoidCallback? onDisconnect;
  final VoidCallback? onAppleImport;

  bool get _busy =>
      state == ExternalCalendarPanelState.loading ||
      state == ExternalCalendarPanelState.refreshing;

  bool get _hasConnection =>
      hasConnection &&
      switch (state) {
        ExternalCalendarPanelState.needsSelection ||
        ExternalCalendarPanelState.connected ||
        ExternalCalendarPanelState.refreshing ||
        ExternalCalendarPanelState.paused ||
        ExternalCalendarPanelState.offline ||
        ExternalCalendarPanelState.reconnectRequired => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('external-calendar-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calendar Import',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bring your outside calendar events into Hꜣw. '
            'Your original calendars stay unchanged.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 20),
          _providerHeading(Icons.calendar_month_outlined, 'Google Calendar'),
          if (accountLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              accountLabel!,
              style: const TextStyle(color: Colors.white60, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          ..._googleContent(),
          if (showAppleAvailability) ...[
            const Divider(color: Color(0xFF242424), height: 32),
            _providerHeading(Icons.calendar_month_outlined, 'Apple Calendar'),
            const SizedBox(height: 8),
            Text(
              appleImportAvailable
                  ? 'Import from calendars on this iPhone.'
                  : 'Device calendars require the Hꜣw mobile app. This web app imports calendars from your connected Google account.',
              style: const TextStyle(color: Colors.white60, height: 1.4),
            ),
            if (appleImportAvailable) ...[
              const SizedBox(height: 12),
              _secondaryAction('Choose device calendars', onAppleImport),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _googleContent() {
    if (state == ExternalCalendarPanelState.choosing) {
      return [
        const Text(
          'Choose the calendars to bring into Hꜣw.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 8),
        if (calendars.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No calendars are available for this Google account.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
          ),
        for (final calendar in calendars)
          CheckboxListTile(
            key: ValueKey('external-calendar-choice-${calendar.id}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: KemeticGold.base,
            checkColor: Colors.black,
            title: Text(
              calendar.name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: calendar.detail == null
                ? null
                : Text(
                    calendar.detail!,
                    style: const TextStyle(color: Colors.white60),
                  ),
            value: calendar.selected,
            onChanged: onSelectionChanged == null
                ? null
                : (value) => onSelectionChanged!(calendar.id, value ?? false),
          ),
        const SizedBox(height: 12),
        _primaryAction(
          'Import selected calendars',
          calendars.any((calendar) => calendar.selected)
              ? onSaveSelection
              : null,
        ),
        const SizedBox(height: 8),
        _secondaryAction('Cancel', onCancelSelection),
      ];
    }

    final status = switch (state) {
      ExternalCalendarPanelState.disconnected =>
        'Connect Google, then choose which calendars to import.',
      ExternalCalendarPanelState.loading =>
        'Checking your calendar connection…',
      ExternalCalendarPanelState.needsSelection =>
        'Google is connected. Choose at least one calendar to start importing.',
      ExternalCalendarPanelState.connected =>
        lastUpdatedLabel == null
            ? 'Connected. Ready for your first import.'
            : 'Last updated $lastUpdatedLabel',
      ExternalCalendarPanelState.refreshing =>
        'Updating events. Your saved events remain available.',
      ExternalCalendarPanelState.paused =>
        'Automatic import is paused. Your imported events remain in Hꜣw.',
      ExternalCalendarPanelState.offline =>
        'Could not update right now. Your saved events remain available.',
      ExternalCalendarPanelState.reconnectRequired =>
        'Reconnect Google to update your events. Your saved events remain available.',
      ExternalCalendarPanelState.unconfigured =>
        'Google Calendar connection is not available yet.',
      ExternalCalendarPanelState.selectionChanged =>
        selectionRecoveryMessage ??
            'Your calendar connection changed. Choose your calendars again.',
      ExternalCalendarPanelState.choosing => '',
    };

    return [
      Semantics(
        liveRegion: true,
        child: Text(
          status,
          key: const ValueKey('external-calendar-status'),
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ),
      if (importedEventCount != null &&
          _hasConnection &&
          state != ExternalCalendarPanelState.needsSelection) ...[
        const SizedBox(height: 6),
        Text(
          '$importedEventCount imported ${importedEventCount == 1 ? 'event' : 'events'} in Hꜣw · ${calendars.where((c) => c.selected).length} selected calendars',
          style: const TextStyle(color: Colors.white60, height: 1.4),
        ),
        const SizedBox(height: 6),
        const Text(
          'Import checks the past 30 days and next 6 months. With automatic import on, other dates update when you view them.',
          style: TextStyle(color: Colors.white60, height: 1.4),
        ),
      ],
      if (readFailed) ...[
        const SizedBox(height: 12),
        const Text(
          'Imported events could not be loaded. Any saved copies remain visible.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 8),
        _secondaryAction('Retry loading events', _busy ? null : onRetryRead),
      ],
      if (_busy) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(
          color: KemeticGold.base,
          backgroundColor: Color(0xFF242424),
          minHeight: 2,
          semanticsLabel: 'Calendar import in progress',
        ),
      ],
      if (_hasConnection &&
          state != ExternalCalendarPanelState.needsSelection) ...[
        if (lastUpdatedLabel != null &&
            state != ExternalCalendarPanelState.connected &&
            state != ExternalCalendarPanelState.needsSelection) ...[
          const SizedBox(height: 6),
          Text(
            'Last updated $lastUpdatedLabel',
            style: const TextStyle(color: Colors.white60, height: 1.35),
          ),
        ],
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          key: const ValueKey('external-calendar-automatic'),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: KemeticGold.base,
          title: const Text(
            'Import automatically',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          subtitle: const Text(
            'Keeps your selected calendars up to date. Turn off to pause imports.',
            style: TextStyle(color: Colors.white60, height: 1.35),
          ),
          value: automaticImport,
          onChanged: _busy ? null : onAutomaticChanged,
        ),
        const SizedBox(height: 12),
      ] else if (!_busy) ...[
        const SizedBox(height: 16),
      ],
      if (state == ExternalCalendarPanelState.needsSelection)
        _primaryAction('Choose calendars', onChooseCalendars),
      if (state == ExternalCalendarPanelState.selectionChanged)
        _primaryAction('Choose calendars again', onChooseCalendars),
      if (state == ExternalCalendarPanelState.disconnected)
        _primaryAction('Connect Google Calendar', onConnect),
      if (state == ExternalCalendarPanelState.reconnectRequired)
        _primaryAction('Reconnect Google Calendar', onConnect),
      if (state == ExternalCalendarPanelState.offline)
        _primaryAction('Retry', onRetry),
      if (_hasConnection &&
          state != ExternalCalendarPanelState.needsSelection &&
          state != ExternalCalendarPanelState.offline &&
          state != ExternalCalendarPanelState.reconnectRequired)
        _primaryAction(
          _busy ? 'Updating events…' : 'Import now',
          _busy ? null : onRefresh,
        ),
      if (_hasConnection) ...[
        const SizedBox(height: 8),
        if (state != ExternalCalendarPanelState.needsSelection)
          _secondaryAction(
            'Choose calendars',
            _busy ? null : onChooseCalendars,
          ),
        const SizedBox(height: 8),
        _secondaryAction('Disconnect Google', _busy ? null : onDisconnect),
      ],
    ];
  }

  Widget _providerHeading(IconData icon, String title) => Row(
    children: [
      Icon(icon, color: KemeticGold.base, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _primaryAction(String label, VoidCallback? callback) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: KemeticGold.base,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: callback,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );

  Widget _secondaryAction(String label, VoidCallback? callback) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: KemeticGold.base,
        side: const BorderSide(color: Color(0xFF303030)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: callback,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}
