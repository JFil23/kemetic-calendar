import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/device_calendar_controller.dart';
import '../../services/external_calendar_controller.dart';
import '../../shared/glossy_text.dart';
import 'device_calendar_panel.dart';

/// Subscribes to the native import owner without starting a second lifecycle or
/// creating another persistence authority. Permission requires a user action.
class DeviceCalendarSettings extends StatefulWidget {
  const DeviceCalendarSettings({
    super.key,
    this.controller,
    this.googleController,
  });
  final DeviceCalendarController? controller;
  final ExternalCalendarController? googleController;
  @override
  State<DeviceCalendarSettings> createState() => _DeviceCalendarSettingsState();
}

class _DeviceCalendarSettingsState extends State<DeviceCalendarSettings>
    with WidgetsBindingObserver {
  late DeviceCalendarController _controller;
  late ExternalCalendarController _google;
  String? _actionMessage;

  @override
  void initState() {
    super.initState();
    _attach();
    WidgetsBinding.instance.addObserver(this);
    if (!_controller.choosing) unawaited(_perform(_controller.refreshStatus));
  }

  void _attach() {
    _controller = widget.controller ?? DeviceCalendarController.instance;
    _google =
        widget.googleController ??
        externalCalendarController(Supabase.instance.client);
    _controller.addListener(_changed);
    _google.addListener(_changed);
  }

  void _detach() {
    _controller.removeListener(_changed);
    _google.removeListener(_changed);
  }

  @override
  void didUpdateWidget(covariant DeviceCalendarSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == oldWidget.controller &&
        widget.googleController == oldWidget.googleController) {
      return;
    }
    _detach();
    _attach();
    _actionMessage = null;
    if (!_controller.choosing) unawaited(_perform(_controller.refreshStatus));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_controller.choosing) {
      unawaited(_perform(_controller.refreshStatus));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detach();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _perform(Future<void> Function() action) async {
    final controller = _controller;
    final accountId = controller.accountId;
    if (_actionMessage != null) setState(() => _actionMessage = null);
    try {
      await action();
    } catch (_) {
      if (mounted &&
          controller == _controller &&
          accountId == controller.accountId) {
        setState(
          () => _actionMessage =
              'Could not finish that action. Please try again.',
        );
      }
    }
  }

  Future<void> _confirm({required bool transfer}) async {
    final controller = _controller;
    final account = controller.accountId;
    final generation = controller.generation;
    final connection = controller.status.connectionId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0C0C0C),
        title: Text(
          transfer
              ? 'Use this device for import?'
              : 'Disconnect device calendars?',
        ),
        content: Text(
          transfer
              ? 'This device will manage calendar imports for your Hꜣw account. '
                    'The previous device will stop importing. Your original calendars stay unchanged.'
              : 'Remove this connection’s imported copies from Hꜣw. '
                    'Your original calendars, Google imports, and Hꜣw-created events stay unchanged.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: KemeticGold.base,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(transfer ? 'Use this device' : 'Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        controller != _controller ||
        account != controller.accountId ||
        generation != controller.generation ||
        connection != controller.status.connectionId) {
      return;
    }
    await _perform(
      transfer
          ? () => controller.connect(replaceDevice: true)
          : controller.disconnect,
    );
  }

  DeviceCalendarPanelState get _state {
    final status = _controller.status;
    final error = _controller.errorCode;
    if (!_controller.supported ||
        !status.available ||
        error == 'not_configured') {
      return DeviceCalendarPanelState.unavailable;
    }
    if (_controller.busy) {
      return status.connected
          ? DeviceCalendarPanelState.refreshing
          : DeviceCalendarPanelState.loading;
    }
    if (status.connected && !_controller.isOwner) {
      return DeviceCalendarPanelState.unavailable;
    }
    if (error == 'permission_denied' ||
        error == 'permission_required' ||
        status.connectionState == 'permission_required') {
      return DeviceCalendarPanelState.permissionRequired;
    }
    if (error != null && _controller.choosing) {
      return DeviceCalendarPanelState.selectionChanged;
    }
    if (error != null) return DeviceCalendarPanelState.offline;
    if (_controller.choosing) return DeviceCalendarPanelState.choosing;
    if (!status.connected) return DeviceCalendarPanelState.disconnected;
    return status.automatic
        ? DeviceCalendarPanelState.connected
        : DeviceCalendarPanelState.paused;
  }

  @override
  Widget build(BuildContext context) {
    final status = _controller.status;
    final updated = status.lastSyncedAt?.toLocal();
    final controller = _controller;
    final account = controller.accountId;
    final generation = controller.generation;
    final googleSources =
        _google.status?.sources.where((source) => source.selected).toList() ??
        [];
    final googleIds = googleSources.map((source) => source.id).toSet();
    final otherDevice = status.connected && !controller.isOwner;
    final unresolved = _controller.unresolvedCloudSources;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeviceCalendarPanel(
          state: _state,
          selectionRecoveryMessage: _controller.errorCode == 'stale_attempt'
              ? null
              : 'Your calendar choices could not be confirmed. Choose your calendars again.',
          availabilityMessage: otherDevice
              ? 'Your device calendars are managed by another device.'
              : null,
          lastUpdatedLabel: updated == null
              ? null
              : _timestamp(context, updated),
          automaticImport: status.automatic,
          hasConnection: status.connected,
          calendars: [
            for (final source in status.sources)
              DeviceCalendarChoice(
                id: source.id,
                name: source.label,
                available: source.available,
                sourceId: source.accountLabel,
                sourceName: source.accountLabel,
                selected: controller.choosing
                    ? controller.selectedSources.contains(source.id)
                    : source.selected,
                cloudSourceId: controller.choosing
                    ? controller.googleBindings[source.id]
                    : source.googleSourceId,
                ownershipPending:
                    unresolved.contains(source.id) ||
                    (controller.googleBindings[source.id] != null &&
                        !googleIds.contains(
                          controller.googleBindings[source.id],
                        )),
              ),
          ],
          cloudCalendars: [
            for (final source in googleSources)
              DeviceCalendarCloudChoice(
                id: source.id,
                name: source.label,
                accountLabel: _google.status?.accountLabel,
              ),
          ],
          onConnect: () => unawaited(_perform(() => controller.connect())),
          onRefresh: () => unawaited(_perform(controller.refresh)),
          onRetry: () => unawaited(
            _perform(
              status.connected ? controller.refresh : controller.refreshStatus,
            ),
          ),
          onChooseCalendars: () =>
              unawaited(_perform(controller.chooseCalendars)),
          onSelectionChanged: controller.selectSource,
          onCloudBindingChanged: (id, googleId) {
            if (controller != _controller ||
                account != controller.accountId ||
                generation != controller.generation) {
              return;
            }
            controller.bindCloudSource(id, googleId);
          },
          onSaveSelection: () => unawaited(_perform(controller.saveSelection)),
          onCancelSelection: controller.cancelSelection,
          onAutomaticChanged: (enabled) =>
              unawaited(_perform(() => controller.setAutomatic(enabled))),
          onDisconnect: () => unawaited(_confirm(transfer: false)),
          onUseThisDevice: otherDevice && controller.supported
              ? () => unawaited(_confirm(transfer: true))
              : null,
        ),
        if (_actionMessage != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _actionMessage!,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ],
    );
  }

  String _timestamp(BuildContext context, DateTime date) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatShortDate(date)} at '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }
}
