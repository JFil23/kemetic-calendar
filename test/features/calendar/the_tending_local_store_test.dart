import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/archived_maat_flow_detail_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the-tending legacy values are decoded through the generic reader',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'tending_42_prompt_care': 'Preserved response',
      });

      final responses = await ArchivedMaatFlowLocalStateReader.load(
        flowKey: 'the-tending',
        flowId: 42,
      );

      expect(responses, hasLength(1));
      expect(responses.single.prompt, 'Care');
      expect(responses.single.response, 'Preserved response');
    },
  );
}
