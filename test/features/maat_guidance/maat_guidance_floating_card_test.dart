import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/maat_guidance_model.dart';
import 'package:mobile/features/maat_guidance/maat_guidance_floating_card.dart';

void main() {
  testWidgets('floating card dismiss button does not require an Overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: Colors.black,
            child: MaatGuidanceFloatingCard(
              delivery: _delivery(),
              onDismiss: () {},
              onOpen: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Read guidance'), findsOneWidget);
  });

  testWidgets('floating card has an explicit open button', (tester) async {
    var openCount = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: Colors.black,
            child: MaatGuidanceFloatingCard(
              delivery: _deliveryWithNode(),
              onDismiss: () {},
              onOpen: () => openCount += 1,
            ),
          ),
        ),
      ),
    );

    final openButton = find.widgetWithText(TextButton, 'Open guidance');
    expect(openButton, findsOneWidget);

    await tester.tap(openButton);
    await tester.pump();

    expect(openCount, 1);
  });
}

MaatGuidanceDelivery _delivery() {
  return MaatGuidanceDelivery(
    id: 'opening',
    kind: MaatGuidanceKind.decanOpening,
    decanPeriodKey: '2026-05-19:2026-05-28:3-1',
    status: MaatGuidanceStatus.pending,
    priority: 10,
    teaserText:
        'This decan asks for truth to become practical. Begin with one measured act.',
    bodyText: 'This decan opens through Paopi.',
    payload: const <String, dynamic>{},
    ctaType: MaatGuidanceCtaType.none,
    ctaRef: null,
    triggerReason: 'decan_boundary',
    createdAt: DateTime.utc(2026, 5, 19),
  );
}

MaatGuidanceDelivery _deliveryWithNode() {
  return MaatGuidanceDelivery(
    id: 'opening',
    kind: MaatGuidanceKind.decanOpening,
    decanPeriodKey: '2026-05-19:2026-05-28:3-1',
    status: MaatGuidanceStatus.pending,
    priority: 10,
    teaserText:
        'This decan asks for truth to become practical. Begin with one measured act.',
    bodyText: 'This decan opens through Paopi.',
    payload: const <String, dynamic>{'node_ref': 'maat'},
    ctaType: MaatGuidanceCtaType.node,
    ctaRef: 'maat',
    triggerReason: 'decan_boundary',
    createdAt: DateTime.utc(2026, 5, 19),
  );
}
