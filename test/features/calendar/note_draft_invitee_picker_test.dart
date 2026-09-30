import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/features/sharing/share_flow_sheet.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import '../../support/maat_flow_visual_test_fonts.dart';
import '../ai_generation/compose_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeComposeTests);
  for (final cancel in [false, true]) {
    testWidgets(
      'draft picker ${cancel ? 'cancel discards' : 'Done returns'} selection without sending',
      (tester) async {
        await loadMaatFlowVisualTestFonts();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        List<UserSearchResult>? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'GentiumPlus',
              ),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Choose people'),
                  onPressed: () async {
                    result =
                        await showEditableModalBottomSheet<
                          List<UserSearchResult>
                        >(
                          context: context,
                          builder: (_) => ShareFlowSheet(
                            flowId: null,
                            flowTitle: 'New note',
                            selectForDraft: true,
                            initialPeople: [
                              UserSearchResult(
                                userId: 'friend',
                                displayName: 'Nia',
                              ),
                            ],
                          ),
                        );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Choose people'));
        await tester.pumpAndSettle();
        expect(find.text('Done'), findsOneWidget);
        expect(
          find.text('Invitations are sent when you save the note.'),
          findsOneWidget,
        );
        expect(find.text('Invite Status'), findsNothing);
        expect(find.text('Nia'), findsWidgets);
        if (!cancel && const bool.fromEnvironment('CAPTURE_EDITOR_FIXES')) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('/tmp/editor-draft-invitees.png'),
          );
        }
        await tester.tap(
          cancel ? find.byIcon(Icons.close).first : find.text('Done'),
        );
        await tester.pumpAndSettle();
        if (cancel) {
          expect(result, isNull);
        } else {
          expect(result!.single.userId, 'friend');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
