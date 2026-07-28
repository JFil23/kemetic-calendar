import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/day_key.dart';
import '../../shared/glossy_text.dart';
import '../../widgets/kemetic_day_info.dart';
import '../settings/settings_prefs.dart';
import 'calendar_page.dart' show KemeticMath;

const dailyCosmicContextOverlayKey = ValueKey<String>(
  'daily-cosmic-context-overlay',
);
const dailyCosmicContextDismissButtonKey = ValueKey<String>(
  'daily-cosmic-context-dismiss',
);

typedef DailyCosmicContextBadgeResolver =
    DailyCosmicContextBadge? Function(DateTime localDate);
typedef DailyCosmicContextInfoResolver =
    KemeticDayInfo? Function(String dayKey);

@immutable
class DailyCosmicContextBadge {
  const DailyCosmicContextBadge({
    required this.dayKey,
    required this.gregorianDateKey,
    required this.gregorianDateLabel,
    required this.kemeticDate,
    required this.decanName,
    required this.cosmicContext,
  });

  final String dayKey;
  final String gregorianDateKey;
  final String gregorianDateLabel;
  final String kemeticDate;
  final String decanName;
  final String cosmicContext;
}

class DailyCosmicContextPrefs {
  const DailyCosmicContextPrefs({SharedPreferences? prefs}) : _prefs = prefs;

  static const String _lastShownGregorianDatePrefix =
      'daily_cosmic_context:last_shown_gregorian_date';

  final SharedPreferences? _prefs;

  static String lastShownGregorianDateKeyForUser(String userId) {
    return '$_lastShownGregorianDatePrefix:${userId.trim()}';
  }

  Future<bool> isEnabled() async {
    final prefs = await _store();
    return SettingsPrefs.dailyCosmicContextBadgeEnabledFrom(prefs);
  }

  Future<String?> lastShownGregorianDate(String userId) async {
    final prefs = await _store();
    final raw = prefs.getString(lastShownGregorianDateKeyForUser(userId));
    final value = raw?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> markShown(String userId, String gregorianDateKey) async {
    final prefs = await _store();
    await prefs.setString(
      lastShownGregorianDateKeyForUser(userId),
      gregorianDateKey,
    );
  }

  Future<SharedPreferences> _store() async {
    return _prefs ?? SharedPreferences.getInstance();
  }
}

class DailyCosmicContextController extends ChangeNotifier {
  DailyCosmicContextController({
    DailyCosmicContextPrefs prefs = const DailyCosmicContextPrefs(),
    DateTime Function()? now,
    DailyCosmicContextBadgeResolver badgeForDate =
        dailyCosmicContextBadgeForDate,
  }) : _prefs = prefs,
       _now = now ?? DateTime.now,
       _badgeForDate = badgeForDate;

  final DailyCosmicContextPrefs _prefs;
  final DateTime Function() _now;
  final DailyCosmicContextBadgeResolver _badgeForDate;

  DailyCosmicContextBadge? _current;
  String? _activeUserId;
  int _evaluationSerial = 0;
  bool _disposed = false;

  DailyCosmicContextBadge? get current => _current;
  bool get hasVisibleBadge => _current != null;

  Future<void> evaluate({
    required String? userId,
    required bool isAuthenticated,
    required bool onboardingComplete,
    required bool suppressed,
  }) async {
    final serial = ++_evaluationSerial;
    final normalizedUserId = userId?.trim();
    if (!isAuthenticated ||
        normalizedUserId == null ||
        normalizedUserId.isEmpty ||
        !onboardingComplete ||
        suppressed) {
      _clearCurrent();
      return;
    }

    final now = DateUtils.dateOnly(_now());
    final gregorianDateKey = dailyCosmicContextGregorianDateKey(now);
    final enabled = await _prefs.isEnabled();
    if (!_isCurrentEvaluation(serial)) return;
    if (!enabled) {
      _clearCurrent();
      return;
    }

    final lastShown = await _prefs.lastShownGregorianDate(normalizedUserId);
    if (!_isCurrentEvaluation(serial)) return;
    if (lastShown == gregorianDateKey) {
      if (_activeUserId == normalizedUserId &&
          _current?.gregorianDateKey == gregorianDateKey) {
        return;
      }
      _clearCurrent();
      return;
    }

    final badge = _badgeForDate(now);
    if (!_isCurrentEvaluation(serial)) return;
    if (badge == null) {
      _clearCurrent();
      return;
    }

    _activeUserId = normalizedUserId;
    _setCurrent(badge);
    await _prefs.markShown(normalizedUserId, badge.gregorianDateKey);
  }

  Future<void> dismiss() async {
    _evaluationSerial += 1;
    final badge = _current;
    final userId = _activeUserId;
    _clearCurrent();
    if (badge == null || userId == null || userId.trim().isEmpty) return;
    await _prefs.markShown(userId, badge.gregorianDateKey);
  }

  bool _isCurrentEvaluation(int serial) {
    return !_disposed && serial == _evaluationSerial;
  }

  void _setCurrent(DailyCosmicContextBadge badge) {
    if (_current == badge) return;
    _current = badge;
    _notifySafely();
  }

  void _clearCurrent() {
    if (_current == null && _activeUserId == null) return;
    _current = null;
    _activeUserId = null;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

DailyCosmicContextBadge? dailyCosmicContextBadgeForDate(
  DateTime localDate, {
  DailyCosmicContextInfoResolver infoForDay = KemeticDayData.getInfoForDay,
}) {
  final dateOnly = DateUtils.dateOnly(localDate);
  final kemetic = KemeticMath.fromGregorian(dateOnly);
  final dayKey = kemeticDayKey(kemetic.kMonth, kemetic.kDay);
  final info = infoForDay(dayKey);
  final cosmicContext = info?.cosmicContext.trim();
  if (info == null || cosmicContext == null || cosmicContext.isEmpty) {
    return null;
  }

  return DailyCosmicContextBadge(
    dayKey: dayKey,
    gregorianDateKey: dailyCosmicContextGregorianDateKey(dateOnly),
    gregorianDateLabel: _formatGregorianDateLabel(dateOnly),
    kemeticDate: info.kemeticDate,
    decanName: info.decanName.trim(),
    cosmicContext: cosmicContext,
  );
}

String dailyCosmicContextGregorianDateKey(DateTime date) {
  final local = date.isUtc ? date.toLocal() : date;
  final dateOnly = DateUtils.dateOnly(local);
  return '${dateOnly.year.toString().padLeft(4, '0')}-'
      '${dateOnly.month.toString().padLeft(2, '0')}-'
      '${dateOnly.day.toString().padLeft(2, '0')}';
}

bool isDailyCosmicContextRouteSuppressed(Uri uri) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  final onboarding = uri.queryParameters['onboarding'] == '1';
  final requireCompletion = uri.queryParameters['requireCompletion'] == '1';
  if (onboarding || requireCompletion) return true;

  if (path == '/login' || path == '/auth' || path == '/password-recovery') {
    return true;
  }
  return false;
}

class DailyCosmicContextOverlayHost extends StatefulWidget {
  const DailyCosmicContextOverlayHost({super.key, required this.controller});

  final DailyCosmicContextController controller;

  @override
  State<DailyCosmicContextOverlayHost> createState() =>
      _DailyCosmicContextOverlayHostState();
}

class _DailyCosmicContextOverlayHostState
    extends State<DailyCosmicContextOverlayHost> {
  DailyCosmicContextBadge? _badge;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromController);
    _syncFromController();
  }

  @override
  void didUpdateWidget(covariant DailyCosmicContextOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_syncFromController);
    widget.controller.addListener(_syncFromController);
    _syncFromController();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    super.dispose();
  }

  void _syncFromController() {
    final next = widget.controller.current;
    if (next == null) {
      if (_badge == null && !_visible) return;
      setState(() {
        _badge = null;
        _visible = false;
      });
      return;
    }

    if (identical(next, _badge) && _visible) return;
    setState(() {
      _badge = next;
      _visible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.controller.current != next) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    if (badge == null) return const SizedBox.shrink();

    return Positioned.fill(
      key: dailyCosmicContextOverlayKey,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: _DailyCosmicContextScrim(
          child: _DailyCosmicContextCard(
            badge: badge,
            onDismiss: () => unawaited(widget.controller.dismiss()),
          ),
        ),
      ),
    );
  }
}

class _DailyCosmicContextScrim extends StatelessWidget {
  const _DailyCosmicContextScrim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(color: Color(0x52000000), dismissible: false),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(child: child),
          ),
        ),
      ],
    );
  }
}

class _DailyCosmicContextCard extends StatelessWidget {
  const _DailyCosmicContextCard({required this.badge, required this.onDismiss});

  final DailyCosmicContextBadge badge;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = MediaQuery.sizeOf(context);
    final maxWidth = size.width < 560 ? size.width - 40 : 460.0;
    final availableHeight = size.height - mediaQuery.padding.vertical - 48;
    final maxHeight = availableHeight > 0 ? availableHeight : size.height;
    final decanName = _floatingBadgeDecanName(badge.decanName);

    return Semantics(
      namesRoute: false,
      label: 'The Day’s Rhythm',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.98, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xF20D0D10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: KemeticGold.base.withValues(alpha: 0.44),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xAA000000),
                    blurRadius: 28,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 18),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(letterSpacing: 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: KemeticGold.text(
                              'The Day’s Rhythm',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          SizedBox.square(
                            dimension: 40,
                            child: Semantics(
                              label: 'Dismiss The Day’s Rhythm',
                              button: true,
                              child: IconButton(
                                key: dailyCosmicContextDismissButtonKey,
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, size: 20),
                                color: Colors.white70,
                                onPressed: onDismiss,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${badge.kemeticDate} | ${badge.gregorianDateLabel}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      if (decanName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          decanName,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(
                            badge.cosmicContext,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.48,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatGregorianDateLabel(DateTime date) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final local = date.isUtc ? date.toLocal() : date;
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

String _floatingBadgeDecanName(String rawDecanName) {
  return rawDecanName
      .split('|')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .where((part) => !part.toLowerCase().startsWith('deck:'))
      .join(' | ');
}
