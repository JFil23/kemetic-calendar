import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/external_calendar_controller.dart';
import '../../shared/glossy_text.dart';
import 'external_calendar_panel.dart';

/// Settings presentation subscribes to the account-owned controller. It never
/// changes app authentication or owns calendar persistence itself.
class ExternalCalendarSettings extends StatefulWidget {
  const ExternalCalendarSettings({
    super.key,
    this.controller,
    this.launchAuthorization,
    this.showAppleAvailability = true,
    this.callbackResult,
    this.onCallbackConsumed,
  });

  final ExternalCalendarController? controller;
  final Future<bool> Function(Uri uri)? launchAuthorization;
  final bool showAppleAvailability;

  /// Navigation feedback only; connection state always comes from the server.
  final String? callbackResult;
  final ValueChanged<String>? onCallbackConsumed;

  @override
  State<ExternalCalendarSettings> createState() =>
      _ExternalCalendarSettingsState();
}

class _ExternalCalendarSettingsState extends State<ExternalCalendarSettings>
    with WidgetsBindingObserver {
  late ExternalCalendarController _controller;
  String? _actionMessage;
  String? _callbackMessage;
  String? _presentationAccountId;
  bool _finishConnection = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        externalCalendarController(Supabase.instance.client);
    _presentationAccountId = _controller.accountId;
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addObserver(this);
    _receiveCallback();
    unawaited(_perform(_loadStatus, userAction: false));
  }

  @override
  void didUpdateWidget(covariant ExternalCalendarSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      _controller.removeListener(_onChanged);
      _controller =
          widget.controller ??
          externalCalendarController(Supabase.instance.client);
      _presentationAccountId = _controller.accountId;
      _controller.addListener(_onChanged);
      _actionMessage = null;
      _callbackMessage = null;
    }
    final callbackReceived =
        oldWidget.callbackResult != widget.callbackResult && _receiveCallback();
    if (controllerChanged || callbackReceived) {
      unawaited(_perform(_loadStatus, userAction: false));
    }
  }

  bool _receiveCallback() {
    final result = widget.callbackResult;
    if (!const {
      'connected',
      'denied',
      'account_mismatch',
      'reconnect_required',
    }.contains(result)) {
      // Removing a consumed query must not remove its displayed notice.
      return false;
    }
    _finishConnection = result == 'connected';
    _actionMessage = null;
    _callbackMessage = switch (result) {
      'denied' =>
        'Google Calendar access wasn’t granted. You can try connecting again.',
      'account_mismatch' =>
        'That Google account differs from your existing calendar connection. '
            'Reconnect the same account, or disconnect it before choosing another.',
      'reconnect_required' =>
        'Google Calendar could not finish connecting. Please try again.',
      _ => null,
    };
    // The Settings page may still be loading when the route arrives. Only
    // acknowledge after this child has received and presented the outcome.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.callbackResult == result) {
        widget.onCallbackConsumed?.call(result!);
      }
    });
    return true;
  }

  Future<void> _loadStatus() async {
    if (_finishConnection) {
      _finishConnection = false;
      await _controller.finishConnection();
    } else {
      await _controller.loadStatus();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_perform(_loadStatus, userAction: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {
      if (_presentationAccountId != _controller.accountId) {
        _presentationAccountId = _controller.accountId;
        _actionMessage = null;
        _callbackMessage = null;
        _finishConnection = false;
      }
    });
  }

  void _clearMessages() {
    if (mounted && (_actionMessage != null || _callbackMessage != null)) {
      setState(() {
        _actionMessage = null;
        _callbackMessage = null;
        _finishConnection = false;
      });
    }
  }

  Future<void> _perform(
    Future<void> Function() action, {
    bool userAction = true,
  }) async {
    final controller = _controller;
    final accountId = controller.accountId;
    if (userAction) _clearMessages();
    try {
      await action();
    } catch (_) {
      if (mounted &&
          controller == _controller &&
          accountId == controller.accountId) {
        setState(() {
          _actionMessage = 'Could not finish that action. Please try again.';
        });
      }
    }
  }

  Future<void> _connect() async {
    final controller = _controller;
    final accountId = controller.accountId;
    await _perform(() async {
      final uri = await controller.connect();
      if (uri == null ||
          !mounted ||
          controller != _controller ||
          accountId != controller.accountId) {
        return;
      }
      final opened = await (widget.launchAuthorization ?? _launchAuthorization)(
        uri,
      );
      if (!opened && mounted) {
        setState(() {
          _actionMessage =
              'Could not open Google. Please try connecting again.';
        });
      }
    });
  }

  Future<bool> _launchAuthorization(Uri uri) => launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: kIsWeb ? '_self' : null,
  );

  Future<void> _confirmDisconnect() async {
    _clearMessages();
    final controller = _controller;
    final accountId = controller.accountId;
    final generation = controller.generation;
    final connectionId = controller.status?.connectionId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0C0C0C),
        title: const Text('Disconnect Google Calendar?'),
        content: const Text(
          'Remove this connection’s imported copies from Hꜣw. '
          'Your original calendars and Hꜣw-created events stay unchanged.',
          style: TextStyle(color: Colors.white70, height: 1.4),
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
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        controller != _controller ||
        accountId != controller.accountId ||
        generation != controller.generation ||
        connectionId != controller.status?.connectionId) {
      return;
    }
    await _perform(controller.disconnect);
  }

  ExternalCalendarPanelState get _panelState {
    final status = _controller.status;
    final error = _controller.error;
    if (status?.available == false || error?.code == 'not_configured') {
      return ExternalCalendarPanelState.unconfigured;
    }
    if (_controller.busy ||
        (status?.syncing == true &&
            error == null &&
            !_controller.choosingCalendars)) {
      return status?.connected == true
          ? ExternalCalendarPanelState.refreshing
          : ExternalCalendarPanelState.loading;
    }
    if (status?.requiresReconnect == true ||
        error?.code == 'reconnect_required' ||
        error?.code == 'account_mismatch') {
      return ExternalCalendarPanelState.reconnectRequired;
    }
    if (error != null && _controller.choosingCalendars) {
      return ExternalCalendarPanelState.selectionChanged;
    }
    if (error?.code == 'no_calendars_selected') {
      return ExternalCalendarPanelState.needsSelection;
    }
    if (error != null) return ExternalCalendarPanelState.offline;
    if (_controller.choosingCalendars) {
      return ExternalCalendarPanelState.choosing;
    }
    if (status == null) return ExternalCalendarPanelState.loading;
    if (!status.connected) return ExternalCalendarPanelState.disconnected;
    if (!status.hasSelection) return ExternalCalendarPanelState.needsSelection;
    return status.automatic
        ? ExternalCalendarPanelState.connected
        : ExternalCalendarPanelState.paused;
  }

  @override
  Widget build(BuildContext context) {
    final status = _controller.status;
    final updated = status?.lastSyncedAt?.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExternalCalendarPanel(
          state: _panelState,
          selectionRecoveryMessage: _controller.error?.code == 'stale_attempt'
              ? null
              : 'Your calendar choices could not be confirmed. Choose your calendars again.',
          showAppleAvailability: widget.showAppleAvailability,
          accountLabel: status?.accountLabel,
          lastUpdatedLabel: updated == null
              ? null
              : _timestamp(context, updated),
          importedEventCount: status?.importedEventCount,
          readFailed: _controller.readFailure != null,
          onRetryRead: () => unawaited(_perform(_controller.retryReads)),
          automaticImport: status?.automatic ?? false,
          hasConnection: status?.connected ?? false,
          calendars: [
            for (final source in status?.sources ?? [])
              ExternalCalendarChoice(
                id: source.id,
                name: source.label,
                detail:
                    source.selected &&
                        source.lastSyncedAt != null &&
                        source.importedEventCount != null
                    ? '${source.importedEventCount} imported ${source.importedEventCount == 1 ? 'event' : 'events'}'
                    : null,
                selected: _controller.choosingCalendars
                    ? _controller.selectedSourceIds.contains(source.id)
                    : source.selected,
              ),
          ],
          onConnect: _connect,
          onRefresh: () => unawaited(_perform(_controller.refresh)),
          onRetry: () => unawaited(
            _perform(
              _controller.status?.connected == true
                  ? _controller.refresh
                  : _controller.loadStatus,
            ),
          ),
          onChooseCalendars: () =>
              unawaited(_perform(_controller.chooseCalendars)),
          onSelectionChanged: (id, selected) {
            _clearMessages();
            _controller.setSourceSelected(id, selected);
          },
          onSaveSelection: () => unawaited(_perform(_controller.saveSelection)),
          onCancelSelection: () {
            _clearMessages();
            _controller.cancelSelection();
          },
          onAutomaticChanged: (enabled) =>
              unawaited(_perform(() => _controller.setAutomatic(enabled))),
          onDisconnect: _confirmDisconnect,
        ),
        if (_callbackMessage != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _callbackMessage!,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _clearMessages,
              style: TextButton.styleFrom(foregroundColor: KemeticGold.base),
              child: const Text('Dismiss'),
            ),
          ),
        ],
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
