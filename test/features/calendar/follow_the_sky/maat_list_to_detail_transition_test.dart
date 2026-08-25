import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/maat_list_to_detail_route.dart';

void main() {
  testWidgets('list shell shifts on secondary animation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _TransitionHarness(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open detail'), findsOneWidget);

    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Detail page'), findsOneWidget);
  });
}

class _TransitionHarness extends StatefulWidget {
  @override
  State<_TransitionHarness> createState() => _TransitionHarnessState();
}

class _TransitionHarnessState extends State<_TransitionHarness> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      onGenerateInitialRoutes: (_, _) => [
        PageRouteBuilder(
          pageBuilder: (_, _, _) => MaatFlowsListTransitionShell(
            child: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    _navigatorKey.currentState!.push(
                      FollowSkyDetailPageRoute(
                        builder: (_) => const Scaffold(
                          body: Center(child: Text('Detail page')),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open detail'),
                ),
              ),
            ),
          ),
          transitionsBuilder: (_, _, _, child) => child,
        ),
      ],
    );
  }
}
