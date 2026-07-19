import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/onboarding_target_reconciliation.dart';

class _TargetItem {
  const _TargetItem(this.id, {this.pending = false});

  final String id;
  final bool pending;
}

void main() {
  bool matchesTarget(_TargetItem item) => item.id == 'target-event';
  bool isPendingCopy(_TargetItem item) => item.pending;

  test('missing refresh payload preserves the pending onboarding target', () {
    final result = reconcilePendingOnboardingTarget<_TargetItem>(
      refreshedItems: const <_TargetItem>[_TargetItem('other-event')],
      matchesTarget: matchesTarget,
      isPendingCopy: isPendingCopy,
    );

    expect(result.authoritativeTargetFound, isFalse);
    expect(result.shouldPreservePending, isTrue);
    expect(result.cleanedRefreshItems.map((item) => item.id), ['other-event']);
  });

  test(
    'authoritative refresh payload reconciles without a duplicate target',
    () {
      final result = reconcilePendingOnboardingTarget<_TargetItem>(
        refreshedItems: const <_TargetItem>[
          _TargetItem('target-event'),
          _TargetItem('other-event'),
        ],
        matchesTarget: matchesTarget,
        isPendingCopy: isPendingCopy,
      );

      expect(result.authoritativeTargetFound, isTrue);
      expect(result.shouldPreservePending, isFalse);
      expect(result.cleanedRefreshItems.map((item) => item.id), [
        'target-event',
        'other-event',
      ]);
    },
  );

  test('stale pending copies are stripped before reconciliation', () {
    final result = reconcilePendingOnboardingTarget<_TargetItem>(
      refreshedItems: const <_TargetItem>[
        _TargetItem('target-event', pending: true),
        _TargetItem('other-event'),
      ],
      matchesTarget: matchesTarget,
      isPendingCopy: isPendingCopy,
    );

    expect(result.authoritativeTargetFound, isFalse);
    expect(result.shouldPreservePending, isTrue);
    expect(result.cleanedRefreshItems.map((item) => item.id), ['other-event']);
  });

  test(
    'transient missing refresh then authoritative refresh reconciles once',
    () {
      final firstRefresh = reconcilePendingOnboardingTarget<_TargetItem>(
        refreshedItems: const <_TargetItem>[_TargetItem('other-event')],
        matchesTarget: matchesTarget,
        isPendingCopy: isPendingCopy,
      );

      expect(firstRefresh.shouldPreservePending, isTrue);

      final visibleAfterFirstRefresh = <_TargetItem>[
        ...firstRefresh.cleanedRefreshItems,
        if (firstRefresh.shouldPreservePending)
          const _TargetItem('target-event', pending: true),
      ];
      expect(visibleAfterFirstRefresh.map((item) => item.id), [
        'other-event',
        'target-event',
      ]);

      final secondRefresh = reconcilePendingOnboardingTarget<_TargetItem>(
        refreshedItems: <_TargetItem>[
          ...visibleAfterFirstRefresh,
          const _TargetItem('target-event'),
        ],
        matchesTarget: matchesTarget,
        isPendingCopy: isPendingCopy,
      );

      expect(secondRefresh.authoritativeTargetFound, isTrue);
      expect(secondRefresh.shouldPreservePending, isFalse);
      expect(
        secondRefresh.cleanedRefreshItems
            .where((item) => item.id == 'target-event')
            .length,
        1,
      );
    },
  );
}
