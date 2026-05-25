import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_kept_word_flow.dart';
import 'package:mobile/features/calendar/the_kept_word_local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('agreement inventory round-trips in SharedPreferences only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = TheKeptWordLocalStore(prefs: prefs);

    await store.saveAgreementInventory(42, const <KeptWordAgreementEntry>[
      KeptWordAgreementEntry(
        personLabel: 'A',
        agreementText: 'trash on Fridays',
        status: 'drifted',
      ),
      KeptWordAgreementEntry(
        personLabel: 'B',
        agreementText: 'rent by first',
        status: 'kept',
      ),
    ]);

    final entries = await store.loadAgreementInventory(42);
    expect(entries, hasLength(2));
    expect(entries.first.personLabel, 'A');
    expect(entries.first.agreementText, 'trash on Fridays');
    expect(entries.first.status, 'drifted');
    expect(prefs.getKeys(), contains('kept_word_42_agreement_inventory'));
  });

  test('prompt text saves locally and parses event-one inventory', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = TheKeptWordLocalStore(prefs: prefs);

    await store.savePromptText(
      7,
      KeptWordLocalPromptKind.agreementInventory,
      'Name One - dishes - broken\nName Two - dinner check-in - kept',
    );

    final text = await store.loadPromptText(
      7,
      KeptWordLocalPromptKind.agreementInventory,
    );
    final entries = await store.loadAgreementInventory(7);

    expect(text, contains('Name One'));
    expect(entries, hasLength(2));
    expect(entries.last.personLabel, 'Name Two');
    expect(entries.last.agreementText, 'dinner check-in');
    expect(entries.last.status, 'kept');
  });

  test('conversation flags are local and deletable per flow', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'kept_word_7_conversation_completed': true,
      'kept_word_7_conversation_paused': true,
      'kept_word_8_conversation_completed': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = TheKeptWordLocalStore(prefs: prefs);

    expect(await store.loadConversationCompleted(7), isTrue);
    expect(await store.loadConversationPaused(7), isTrue);

    await store.deleteFlowData(7);

    expect(await store.loadConversationCompleted(7), isFalse);
    expect(await store.loadConversationPaused(7), isFalse);
    expect(await store.loadConversationCompleted(8), isTrue);
  });
}
