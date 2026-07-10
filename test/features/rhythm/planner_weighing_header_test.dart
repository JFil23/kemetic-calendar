import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rhythm/widgets/planner/planner_weighing_header.dart';

void main() {
  Widget buildHeader({required bool showProgressStatus}) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox(
          width: 390,
          child: PlannerWeighingHeader(
            percent: 0,
            dateLabel: 'Ka-her-Ka 22 · Akhet',
            showProgressStatus: showProgressStatus,
          ),
        ),
      ),
    );
  }

  testWidgets('empty planner hides the 0% aligned status', (tester) async {
    await tester.pumpWidget(buildHeader(showProgressStatus: false));

    expect(find.text('0%'), findsNothing);
    expect(find.text('ALIGNED'), findsNothing);
  });

  testWidgets('planner with meaningful data still shows progress status', (
    tester,
  ) async {
    await tester.pumpWidget(buildHeader(showProgressStatus: true));

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('ALIGNED'), findsOneWidget);
  });
}
