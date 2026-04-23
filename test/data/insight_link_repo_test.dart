import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/insight_link_model.dart';
import 'package:mobile/data/insight_link_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveLinks and fetchLinks stay user scoped in local fallback mode', () async {
    final repo = InsightLinkRepo();
    final userOneLink = InsightLink(
      id: 'link-1',
      userId: 'user-1',
      sourceType: InsightSourceType.journalEntry,
      sourceId: 'journal-2026-04-22',
      start: 0,
      end: 4,
      selectedText: 'Maat',
      targetType: InsightTargetType.node,
      targetId: 'maat',
      createdAt: DateTime(2026, 4, 22),
      updatedAt: DateTime(2026, 4, 22),
    );
    final userTwoLink = InsightLink(
      id: 'link-2',
      userId: 'user-2',
      sourceType: InsightSourceType.reflectionEntry,
      sourceId: 'reflection-1',
      start: 5,
      end: 9,
      selectedText: 'Ra',
      targetType: InsightTargetType.node,
      targetId: 'ra',
      createdAt: DateTime(2026, 4, 23),
      updatedAt: DateTime(2026, 4, 23),
    );

    await repo.saveLinks('user-1', [userOneLink]);
    await repo.saveLinks('user-2', [userTwoLink]);

    expect(await repo.fetchLinks('user-1'), hasLength(1));
    expect((await repo.fetchLinks('user-1')).single.targetId, 'maat');
    expect(await repo.fetchLinks('user-2'), hasLength(1));
    expect((await repo.fetchLinks('user-2')).single.targetId, 'ra');
  });

  test('saveNodeContent and fetchNodeContent stay user scoped in local fallback mode', () async {
    final repo = InsightLinkRepo();
    final firstUserContent = NodeUserContent(
      id: 'node-serpent',
      userId: 'user-1',
      nodeId: 'serpent',
      text: 'Power has to be contained.',
      createdAt: DateTime(2026, 4, 20),
      updatedAt: DateTime(2026, 4, 20),
    );
    final secondUserContent = NodeUserContent(
      id: 'node-ra',
      userId: 'user-2',
      nodeId: 'ra',
      text: 'Light has to move.',
      createdAt: DateTime(2026, 4, 21),
      updatedAt: DateTime(2026, 4, 21),
    );

    await repo.saveNodeContent('user-1', [firstUserContent]);
    await repo.saveNodeContent('user-2', [secondUserContent]);

    expect(await repo.fetchNodeContent('user-1'), hasLength(1));
    expect((await repo.fetchNodeContent('user-1')).single.nodeId, 'serpent');
    expect(await repo.fetchNodeContent('user-2'), hasLength(1));
    expect((await repo.fetchNodeContent('user-2')).single.nodeId, 'ra');
  });

  test('fetchLinks returns local fallback data when Supabase is unavailable', () async {
    final repo = InsightLinkRepo();
    final link = InsightLink(
      id: 'link-local',
      userId: 'local',
      sourceType: InsightSourceType.nodeUserText,
      sourceId: 'node-ptah',
      start: 0,
      end: 5,
      selectedText: 'Ptah',
      targetType: InsightTargetType.node,
      targetId: 'ptah',
      createdAt: DateTime(2026, 4, 24),
      updatedAt: DateTime(2026, 4, 24),
    );

    await repo.saveLinks('local', [link]);

    final loaded = await repo.fetchLinks('local');
    expect(loaded, hasLength(1));
    expect(loaded.single.sourceId, 'node-ptah');
    expect(loaded.single.targetId, 'ptah');
  });
}
