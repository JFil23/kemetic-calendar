import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/navigation_fallback.dart';
import '../../data/account_operation_fence.dart';
import '../../data/decan_reflection_model.dart';
import '../../data/decan_reflection_repo.dart';
import '../../data/warm_state/warm_snapshot_store.dart';
import 'decan_review_controller.dart';
import 'decan_review_screen.dart';
import 'decan_review_widgets.dart';

/// Every saved period, including pre-review rows, opens the same review owner.
class DecanReflectionDetailPage extends StatefulWidget {
  const DecanReflectionDetailPage({
    super.key,
    required this.reflectionId,
    this.initialWindow,
    this.compose = false,
  });
  final String reflectionId;
  final DecanReviewWindow? initialWindow;
  final bool compose;
  @override
  State<DecanReflectionDetailPage> createState() =>
      _DecanReflectionDetailPageState();
}

class _DecanReflectionDetailPageState extends State<DecanReflectionDetailPage> {
  final _repo = DecanReflectionRepo(Supabase.instance.client);
  late final _account = AccountOperationFence(Supabase.instance.client);
  StreamSubscription<AuthState>? _auth;
  DecanReflection? _reflection;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted && !_account.isCurrent) {
        setState(() {
          _reflection = null;
          _loading = false;
        });
      }
    });
    if (widget.initialWindow == null) unawaited(_load());
  }

  @override
  void dispose() {
    _auth?.cancel();
    _account.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final cached = await _repo.getById(widget.reflectionId, cachedOnly: true);
      if (!mounted || !_account.isCurrent) return;
      if (cached != null)
        setState(() {
          _reflection = cached;
          _loading = false;
        });
    } catch (_) {}
    try {
      final row = await _repo.getById(widget.reflectionId, strict: true);
      if (!mounted || !_account.isCurrent) return;
      setState(() {
        _reflection = row;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || !_account.isCurrent) return;
      setState(() {
        if (error is WarmAccessDenied) _reflection = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _reflection;
    if (_account.isCurrent && (widget.initialWindow != null || data != null)) {
      return DecanReviewScreen(
        compose: widget.compose,
        reflection: data,
        window:
            widget.initialWindow ??
            DecanReviewWindow(
              start: data!.decanStart,
              end: data.decanEnd,
              name: data.decanName,
            ),
      );
    }
    return Scaffold(
      backgroundColor: DecanReviewStyle.base,
      body: DecanReviewCanvas(
        children: [
          DecanReviewIntro(
            eyebrow: 'As the decan closes',
            title: _account.isCurrent ? 'These ten days' : 'Sign in again',
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: DecanReviewStyle.gold),
            )
          else ...[
            DecanReviewNotice(
              !_account.isCurrent
                  ? 'Sign in again to open your reflection.'
                  : _failed
                  ? 'Could not open this reflection. Please try again.'
                  : 'Reflection not found.',
            ),
            if (_failed && _account.isCurrent)
              TextButton(onPressed: _load, child: const Text('Try again')),
            TextButton(
              onPressed: () => popOrGo(context, '/reflections'),
              child: const Text('Back to reflections'),
            ),
          ],
        ],
      ),
    );
  }
}
