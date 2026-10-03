import 'package:flutter/material.dart';

import '../../shared/glossy_text.dart';

enum DeviceCalendarPanelState {
  disconnected,
  loading,
  choosing,
  selectionChanged,
  connected,
  refreshing,
  paused,
  permissionRequired,
  unavailable,
  offline,
}

@immutable
class DeviceCalendarChoice {
  const DeviceCalendarChoice({
    required this.id,
    required this.name,
    required this.sourceId,
    required this.sourceName,
    required this.selected,
    this.cloudSourceId,
    this.ownershipPending = false,
    this.available = true,
  });
  final String id, name, sourceId, sourceName;
  final bool selected, ownershipPending, available;
  final String? cloudSourceId;
}

@immutable
class DeviceCalendarCloudChoice {
  const DeviceCalendarCloudChoice({
    required this.id,
    required this.name,
    this.accountLabel,
  });
  final String id, name;
  final String? accountLabel;
}

/// Static presentation for a verified native bridge. Source names come from
/// the operating system; provider identity is never inferred from their text.
class DeviceCalendarPanel extends StatelessWidget {
  const DeviceCalendarPanel({
    super.key,
    required this.state,
    this.calendars = const [],
    this.cloudCalendars = const [],
    this.lastUpdatedLabel,
    this.selectionRecoveryMessage,
    this.availabilityMessage,
    this.automaticImport = false,
    this.hasConnection = true,
    this.onConnect,
    this.onRefresh,
    this.onRetry,
    this.onChooseCalendars,
    this.onSelectionChanged,
    this.onCloudBindingChanged,
    this.onSaveSelection,
    this.onCancelSelection,
    this.onAutomaticChanged,
    this.onDisconnect,
    this.onUseThisDevice,
  });
  final DeviceCalendarPanelState state;
  final List<DeviceCalendarChoice> calendars;
  final List<DeviceCalendarCloudChoice> cloudCalendars;
  final String? lastUpdatedLabel, availabilityMessage, selectionRecoveryMessage;
  final bool automaticImport, hasConnection;
  final VoidCallback? onConnect, onRefresh, onRetry, onChooseCalendars;
  final void Function(String id, bool selected)? onSelectionChanged;
  final void Function(String id, String? cloudSourceId)? onCloudBindingChanged;
  final VoidCallback? onSaveSelection, onCancelSelection, onDisconnect;
  final ValueChanged<bool>? onAutomaticChanged;
  final VoidCallback? onUseThisDevice;

  bool get _busy =>
      state == DeviceCalendarPanelState.loading ||
      state == DeviceCalendarPanelState.refreshing;
  bool get _connected =>
      hasConnection &&
      switch (state) {
        DeviceCalendarPanelState.connected ||
        DeviceCalendarPanelState.refreshing ||
        DeviceCalendarPanelState.paused ||
        DeviceCalendarPanelState.offline ||
        DeviceCalendarPanelState.permissionRequired => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('device-calendar-panel'),
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
          'Device Calendars',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bring calendars from this device into Hꜣw. '
          'Your original calendars stay unchanged.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (state == DeviceCalendarPanelState.choosing)
          ..._selection(context)
        else
          ..._status(),
      ],
    ),
  );

  List<Widget> _selection(BuildContext context) {
    final groups = <String, List<DeviceCalendarChoice>>{};
    for (final calendar in calendars) {
      groups.putIfAbsent(calendar.sourceId, () => []).add(calendar);
    }
    return [
      const Text(
        'Choose calendars and their import source.',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      const SizedBox(height: 8),
      const Text(
        'If a calendar is already connected through Google, choose its Google '
        'copy below to avoid importing it twice.',
        style: TextStyle(color: Colors.white60, height: 1.4),
      ),
      if (calendars.isEmpty) ...[
        const SizedBox(height: 16),
        const Text(
          'No calendars are available on this device.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
      for (final group in groups.values) ...[
        const SizedBox(height: 20),
        Text(
          group.first.sourceName,
          style: const TextStyle(
            color: KemeticGold.base,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        for (final calendar in group) ...[
          CheckboxListTile(
            key: ValueKey('device-calendar-choice-${calendar.id}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: KemeticGold.base,
            checkColor: Colors.black,
            title: Text(
              calendar.name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: calendar.available
                ? null
                : const Text(
                    'Not available on this device',
                    style: TextStyle(color: Colors.white60),
                  ),
            value: calendar.selected,
            onChanged:
                onSelectionChanged == null ||
                    (!calendar.available && !calendar.selected)
                ? null
                : (value) => onSelectionChanged!(calendar.id, value ?? false),
          ),
          if (calendar.selected &&
              (cloudCalendars.isNotEmpty ||
                  calendar.ownershipPending ||
                  calendar.cloudSourceId != null))
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 12),
              child: _ownerChoice(context, calendar),
            ),
          if (calendar.selected &&
              calendar.cloudSourceId != null &&
              !calendar.ownershipPending)
            const Padding(
              padding: EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                'Google keeps this calendar up to date. '
                'This device will not import another copy.',
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
            ),
        ],
      ],
      const SizedBox(height: 16),
      _action(
        'Import selected calendars',
        calendars.any((c) => c.selected) &&
                !calendars.any((c) => c.selected && c.ownershipPending)
            ? onSaveSelection
            : null,
        primary: true,
      ),
      const SizedBox(height: 8),
      _action('Cancel', onCancelSelection),
    ];
  }

  Widget _ownerChoice(BuildContext context, DeviceCalendarChoice calendar) {
    final cloud = cloudCalendars
        .where((entry) => entry.id == calendar.cloudSourceId)
        .firstOrNull;
    final label = calendar.ownershipPending
        ? 'Choose import source'
        : (cloud == null ? 'Import from this device' : _cloudLabel(cloud));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Import source', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: ValueKey('device-calendar-owner-${calendar.id}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF303030)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onCloudBindingChanged == null
                ? null
                : () async {
                    final selected = await showDialog<String>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('Import source'),
                        children: [
                          SimpleDialogOption(
                            onPressed: () => Navigator.of(context).pop(''),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Import from this device'),
                            ),
                          ),
                          for (final entry in cloudCalendars)
                            SimpleDialogOption(
                              onPressed: () =>
                                  Navigator.of(context).pop(entry.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(_cloudLabel(entry)),
                              ),
                            ),
                        ],
                      ),
                    );
                    if (selected != null && context.mounted) {
                      onCloudBindingChanged!(
                        calendar.id,
                        selected.isEmpty ? null : selected,
                      );
                    }
                  },
            child: Row(
              children: [
                Expanded(child: Text(label)),
                const SizedBox(width: 8),
                const Icon(
                  Icons.expand_more,
                  size: 20,
                  color: KemeticGold.base,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _cloudLabel(DeviceCalendarCloudChoice cloud) =>
      'Google · ${cloud.name}'
      '${cloud.accountLabel == null ? '' : ' · ${cloud.accountLabel}'}';

  List<Widget> _status() {
    final message = switch (state) {
      DeviceCalendarPanelState.disconnected =>
        'Choose which calendars to import from this device.',
      DeviceCalendarPanelState.loading => 'Checking calendar access…',
      DeviceCalendarPanelState.connected =>
        lastUpdatedLabel == null
            ? 'Connected. Ready for your first import.'
            : 'Last updated $lastUpdatedLabel',
      DeviceCalendarPanelState.refreshing =>
        'Updating events. Your saved events remain available.',
      DeviceCalendarPanelState.paused =>
        'Automatic import is paused. Your imported events remain in Hꜣw.',
      DeviceCalendarPanelState.permissionRequired =>
        'Check calendar access in your device Settings, then return to Hꜣw '
            'and retry. Your saved events remain available.',
      DeviceCalendarPanelState.unavailable =>
        availabilityMessage ??
            'Device calendar import is not available in this build.',
      DeviceCalendarPanelState.offline =>
        'Could not update right now. Your saved events remain available.',
      DeviceCalendarPanelState.selectionChanged =>
        selectionRecoveryMessage ??
            'Your calendar connection changed. Choose your calendars again.',
      DeviceCalendarPanelState.choosing => '',
    };
    return [
      Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ),
      if (_busy) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(
          color: KemeticGold.base,
          backgroundColor: Color(0xFF242424),
          minHeight: 2,
          semanticsLabel: 'Device calendar import in progress',
        ),
      ],
      if (state == DeviceCalendarPanelState.unavailable &&
          onUseThisDevice != null) ...[
        const SizedBox(height: 16),
        _action('Use this device', onUseThisDevice, primary: true),
      ],
      if (_connected) ...[
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: KemeticGold.base,
          title: const Text(
            'Import automatically',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          subtitle: const Text(
            'Refreshes from this device while Hꜣw is open. '
            'Turn off to pause imports.',
            style: TextStyle(color: Colors.white60, height: 1.35),
          ),
          value: automaticImport,
          onChanged: _busy ? null : onAutomaticChanged,
        ),
      ],
      const SizedBox(height: 16),
      if (state == DeviceCalendarPanelState.selectionChanged)
        _action('Choose calendars again', onChooseCalendars, primary: true),
      if (state == DeviceCalendarPanelState.disconnected)
        _action('Choose device calendars', onConnect, primary: true),
      if (state == DeviceCalendarPanelState.permissionRequired)
        _action('Retry calendar access', onConnect, primary: true),
      if (state == DeviceCalendarPanelState.offline)
        _action('Retry', onRetry, primary: true),
      if (_connected &&
          state != DeviceCalendarPanelState.permissionRequired &&
          state != DeviceCalendarPanelState.offline)
        _action(
          _busy ? 'Updating events…' : 'Import now',
          _busy ? null : onRefresh,
          primary: true,
        ),
      if (_connected) ...[
        const SizedBox(height: 8),
        _action('Choose calendars', _busy ? null : onChooseCalendars),
        const SizedBox(height: 8),
        _action('Disconnect device calendars', _busy ? null : onDisconnect),
      ],
    ];
  }

  Widget _action(String label, VoidCallback? callback, {bool primary = false}) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    final child = Text(label, textAlign: TextAlign.center);
    return SizedBox(
      width: double.infinity,
      child: primary
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KemeticGold.base,
                foregroundColor: Colors.black,
                padding: padding,
                shape: shape,
              ),
              onPressed: callback,
              child: child,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: KemeticGold.base,
                side: const BorderSide(color: Color(0xFF303030)),
                padding: padding,
                shape: shape,
              ),
              onPressed: callback,
              child: child,
            ),
    );
  }
}
