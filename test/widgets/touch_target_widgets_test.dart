import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/features/invites/event_invite_action_row.dart';
import 'package:mobile/features/nodes/widgets.dart';
import 'package:mobile/features/rhythm/models/rhythm_models.dart';
import 'package:mobile/features/rhythm/widgets/rhythm_state_button.dart';

Future<void> _pumpTouchWidget(WidgetTester tester, Widget child) async {
  await _pumpTouchWidgetWithSize(tester, child, const Size(390, 844));
}

Future<void> _pumpTouchWidgetWithSize(
  WidgetTester tester,
  Widget child,
  Size size,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Rhythm state dots keep a full touch target on phones', (
    tester,
  ) async {
    await _pumpTouchWidget(
      tester,
      const RhythmStateDot(state: RhythmItemState.done, isActive: true),
    );

    final size = tester.getSize(
      find
          .descendant(
            of: find.byType(RhythmStateDot),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
  });

  testWidgets('Rhythm state button groups stay on one horizontal row', (
    tester,
  ) async {
    await _pumpTouchWidgetWithSize(
      tester,
      const SizedBox(
        width: 120,
        child: RhythmStateButtonGroup(current: RhythmItemState.done),
      ),
      const Size(320, 844),
    );

    final doneY = tester.getCenter(find.byIcon(Icons.check_circle_rounded)).dy;
    final partialY = tester.getCenter(find.byIcon(Icons.adjust_rounded)).dy;
    final skippedY = tester
        .getCenter(find.byIcon(Icons.remove_circle_outline_rounded))
        .dy;

    expect(partialY, closeTo(doneY, 0.1));
    expect(skippedY, closeTo(doneY, 0.1));
  });

  testWidgets('Glyph back button keeps a full touch target on phones', (
    tester,
  ) async {
    await _pumpTouchWidget(
      tester,
      GlyphBackButton(onTap: () {}, showLabel: false, showCloseIcon: true),
    );

    final size = tester.getSize(
      find
          .descendant(
            of: find.byType(GlyphBackButton),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
  });

  testWidgets('Compact invite actions expand to touch-safe heights on phones', (
    tester,
  ) async {
    await _pumpTouchWidget(
      tester,
      EventInviteActionRow(
        currentStatus: EventInviteResponseStatus.noResponse,
        compact: true,
        onSelected: (_) {},
      ),
    );

    final size = tester.getSize(
      find
          .descendant(
            of: find.byType(EventInviteActionRow),
            matching: find.byWidgetPredicate(
              (widget) => widget is Row && widget.children.length == 3,
            ),
          )
          .first,
    );
    expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
  });
}
