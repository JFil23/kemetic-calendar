import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/device_calendar_controller.dart';
import '../settings/external_calendar_settings.dart';
import '../settings/device_calendar_settings.dart';
import 'onboarding_progress.dart';

/// Reuses Settings' production consent, selection and status presentation.
/// Entering this page never requests provider or device permission.
class HawCalendarConnectionPage extends StatefulWidget {
  const HawCalendarConnectionPage({
    super.key,
    required this.onContinue,
    this.callbackResult,
    this.onCallbackConsumed,
    this.googlePanel,
    this.devicePanel,
  });
  final Future<void> Function() onContinue;
  final String? callbackResult;
  final ValueChanged<String>? onCallbackConsumed;
  final Widget? googlePanel, devicePanel;
  @override
  State<HawCalendarConnectionPage> createState() =>
      _HawCalendarConnectionPageState();
}

class _HawCalendarConnectionPageState extends State<HawCalendarConnectionPage> {
  bool _continuing = false;
  String? _error;
  Future<void> _continue() async {
    if (_continuing) return;
    setState(() {
      _continuing = true;
      _error = null;
    });
    try {
      await widget.onContinue();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your place. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF060604),
    appBar: AppBar(
      backgroundColor: const Color(0xFF060604),
      automaticallyImplyLeading: false,
      title: const Text(
        'Bring your time with you.',
        style: TextStyle(
          color: Color(0xFFC9A84C),
          fontFamily: 'GentiumPlus',
          fontSize: 22,
        ),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
        children: [
          widget.googlePanel ??
              ExternalCalendarSettings(
                callbackResult: widget.callbackResult,
                onCallbackConsumed: widget.onCallbackConsumed,
                showAppleAvailability:
                    !DeviceCalendarController.supportedPlatform,
              ),
          if (widget.devicePanel != null ||
              DeviceCalendarController.supportedPlatform) ...[
            const SizedBox(height: 20),
            widget.devicePanel ?? const DeviceCalendarSettings(),
          ],
          const SizedBox(height: 24),
          TextButton(
            onPressed: _continuing ? null : _continue,
            child: Text(
              _continuing ? 'Continuing…' : 'Continue',
              style: const TextStyle(
                color: Color(0xFFC9A84C),
                fontFamily: 'CormorantGaramond',
                fontSize: 21,
              ),
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFF8A7A58))),
        ],
      ),
    ),
  );
}

/// The provider already returns to /settings. A saved, account-owned checkpoint
/// resumes onboarding there; ordinary Settings entry retains its existing page.
class HawCalendarReturn extends StatefulWidget {
  const HawCalendarReturn({
    super.key,
    required this.child,
    this.callbackResult,
  });
  final Widget child;
  final String? callbackResult;
  @override
  State<HawCalendarReturn> createState() => _HawCalendarReturnState();
}

class _HawCalendarReturnState extends State<HawCalendarReturn> {
  final _storage = OnboardingProgressStorage();
  StreamSubscription<AuthState>? _auth;
  String? _owner;
  OnboardingProgress? _progress;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (_owner != Supabase.instance.client.auth.currentUser?.id) {
        unawaited(_load());
      }
    }, onError: (Object _) {});
    unawaited(_load());
  }

  Future<void> _load() async {
    final owner = Supabase.instance.client.auth.currentUser?.id;
    _owner = owner;
    if (mounted) {
      setState(() {
        _loading = true;
        _progress = null;
      });
    }
    final progress = owner == null ? null : await _storage.load(owner);
    if (!mounted ||
        _owner != owner ||
        owner != Supabase.instance.client.auth.currentUser?.id) {
      return;
    }
    setState(() {
      _loading = false;
      _progress = progress;
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  Future<void> _continue() async {
    final owner = _owner;
    if (owner == null ||
        owner != Supabase.instance.client.auth.currentUser?.id) {
      return;
    }
    final progress = await _storage.load(owner);
    if (owner != Supabase.instance.client.auth.currentUser?.id) return;
    await _storage.saveRequired(
      owner,
      progress.copyWith(
        hawSlide: 'segmentation',
        calendarConnectionPending: false,
      ),
    );
    if (mounted && owner == Supabase.instance.client.auth.currentUser?.id) {
      context.go('/');
    }
  }

  void _consume(String result) {
    if (!mounted) return;
    final router = GoRouter.of(context);
    final uri = router.routeInformationProvider.value.uri;
    if (uri.path != '/settings' ||
        uri.queryParameters['external_calendar'] != result) {
      return;
    }
    final query = Map<String, List<String>>.from(uri.queryParametersAll)
      ..remove('external_calendar');
    router.replace(uri.replace(queryParameters: query).toString());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ColoredBox(color: Color(0xFF060604));
    final progress = _progress;
    if (progress == null ||
        (progress.completedOnboarding && !progress.replayActive) ||
        !progress.calendarConnectionPending) {
      return widget.child;
    }
    return HawCalendarConnectionPage(
      key: ValueKey(_owner),
      callbackResult: widget.callbackResult,
      onCallbackConsumed: _consume,
      onContinue: _continue,
    );
  }
}
