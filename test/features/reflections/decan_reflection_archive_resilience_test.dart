import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/decan_reflection_model.dart';
import 'package:mobile/data/decan_reflection_prompt_state.dart';
import 'package:mobile/data/decan_reflection_repo.dart';
import 'package:mobile/data/maat_guidance_repo.dart';
import 'package:mobile/features/reflections/decan_reflection_archive_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final reflection = DecanReflection(
  id: 'r',
  decanName: 'Peret — Measure',
  decanTheme: 'Measure',
  decanStart: DateTime.utc(2026, 5, 6),
  decanEnd: DateTime.utc(2026, 5, 15),
  badgeCount: 3,
  reflectionText: 'A preserved reflection.',
  createdAt: DateTime.utc(2026, 5, 16),
);
const emptyR = DecanReflectionListResult(data: []);
const errorR = DecanReflectionListResult(data: [], errorMessage: 'Offline');
const emptyM = MaatGuidanceListResult(data: []);
const errorM = MaatGuidanceListResult(data: [], errorMessage: 'Offline');
final populated = DecanReflectionListResult(data: [reflection]);
SupabaseClient client() => SupabaseClient(
  'https://example.test',
  'key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class Reflections extends DecanReflectionRepo {
  Reflections() : super(client());
  String? user = 'a';
  final accounts = StreamController<String?>.broadcast(sync: true);
  Object cached = populated;
  FutureOr<DecanReflectionListResult> live = emptyR;
  @override
  String? get accountId => user;
  @override
  Stream<String?> get accountChanges => accounts.stream;
  @override
  Future<DecanReflectionListResult> listMineResult({
    bool cachedOnly = false,
  }) async {
    if (!cachedOnly) return live;
    if (cached is! DecanReflectionListResult) throw cached;
    return cached as DecanReflectionListResult;
  }

  @override
  Future<void> markPromptInteracted({
    required DateTime decanStart,
    DateTime? decanEnd,
    String interactionKind = 'interacted',
  }) async {}
}

class Openings extends MaatGuidanceRepo {
  Openings() : super(client());
  Object cached = emptyM;
  FutureOr<MaatGuidanceListResult> live = emptyM;
  @override
  Future<MaatGuidanceListResult> listDecanOpeningsForArchive({
    bool cachedOnly = false,
  }) async {
    if (!cachedOnly) return live;
    if (cached is! MaatGuidanceListResult) throw cached;
    return cached as MaatGuidanceListResult;
  }
}

class PromptState extends DecanReflectionPromptState {
  PromptState() : super.withUserIdProvider(() => 'a');
  @override
  Future<void> markInteracted(DateTime decanStart) async {}
}

void main() {
  late Reflections repo;
  late Openings openings;
  late Completer<DecanReflectionListResult> refresh;
  setUp(() {
    repo = Reflections();
    openings = Openings();
  });
  tearDown(() async {
    await repo.accounts.close();
  });
  Future<void> mount(WidgetTester tester, {GlobalKey? key}) async {
    refresh = Completer();
    repo.live = refresh.future;
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: DecanReflectionArchivePage(
            reflectionRepoForTesting: repo,
            maatRepoForTesting: openings,
            promptStateForTesting: PromptState(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<List<int>> pixels(WidgetTester tester, GlobalKey key) async {
    return (await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List().toList();
    }))!;
  }

  testWidgets('failed refresh retains the exact populated archive pixels', (
    tester,
  ) async {
    final key = GlobalKey();
    await mount(tester, key: key);
    expect(find.text('Peret — Measure'), findsOneWidget);
    final before = await pixels(tester, key);
    refresh.complete(errorR);
    await tester.pumpAndSettle();
    expect(find.text('Peret — Measure'), findsOneWidget);
    expect(find.text('Reflections could not load'), findsNothing);
    expect(await pixels(tester, key), before);
  });
  testWidgets('auth refresh error retains content without an unhandled error', (
    tester,
  ) async {
    await mount(tester);
    repo.accounts.addError(StateError('Temporary token refresh failure'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Peret — Measure'), findsOneWidget);
    refresh.complete(errorR);
    await tester.pumpAndSettle();
    expect(find.text('Peret — Measure'), findsOneWidget);
  });
  testWidgets('missing opening cache does not prevent reflection cache paint', (
    tester,
  ) async {
    openings.cached = StateError('cache miss');
    await mount(tester);
    expect(find.text('Peret — Measure'), findsOneWidget);
    refresh.complete(errorR);
    await tester.pumpAndSettle();
    expect(find.text('Peret — Measure'), findsOneWidget);
  });
  testWidgets(
    'cold partial success publishes reflections despite opening failure',
    (tester) async {
      repo.cached = emptyR;
      openings.live = errorM;
      await mount(tester);
      refresh.complete(populated);
      await tester.pumpAndSettle();
      expect(find.text('Peret — Measure'), findsOneWidget);
      expect(find.text('No reflections yet'), findsNothing);
    },
  );
  testWidgets('successful empty result clears obsolete cached content', (
    tester,
  ) async {
    await mount(tester);
    refresh.complete(emptyR);
    await tester.pumpAndSettle();
    expect(find.text('Peret — Measure'), findsNothing);
    expect(find.text('No reflections yet'), findsOneWidget);
  });
  testWidgets(
    'access denial clears cached content rather than treating it as offline',
    (tester) async {
      await mount(tester);
      refresh.complete(
        const DecanReflectionListResult(
          data: [],
          errorMessage: 'Denied',
          discardCached: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Peret — Measure'), findsNothing);
      expect(find.text('Reflections could not load'), findsOneWidget);
    },
  );
  testWidgets(
    'account switch clears the old view and rejects its late refresh',
    (tester) async {
      await mount(tester);
      expect(find.text('Peret — Measure'), findsOneWidget);
      repo.cached = emptyR;
      repo.live = emptyR;
      repo.user = 'b';
      repo.accounts.add('b');
      await tester.pumpAndSettle();
      expect(find.text('Peret — Measure'), findsNothing);
      refresh.complete(populated);
      await tester.pumpAndSettle();
      expect(find.text('Peret — Measure'), findsNothing);
      expect(find.text('No reflections yet'), findsOneWidget);
    },
  );
  testWidgets('cold failure retains retry and recovers on its next request', (
    tester,
  ) async {
    repo.cached = emptyR;
    await mount(tester);
    refresh.complete(errorR);
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    repo.live = populated;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Peret — Measure'), findsOneWidget);
  });
}
