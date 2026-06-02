import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/living_text_day_one_node_store.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'Day 1 node slug key is scoped by user, Living Text, and flow id',
    () async {
      const store = LivingTextDayOneNodeStore();
      await store.writeSlug(
        userId: 'user-1',
        flowInstanceId: 'flow-441',
        nodeSlug: 'maat',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('living_text_day1_node_slug'), isNull);
      expect(
        prefs.getString(
          'maat_flow:user-1:$kLivingTextFlowKey:flow-441:day1_node_slug',
        ),
        'maat',
      );
    },
  );
}
