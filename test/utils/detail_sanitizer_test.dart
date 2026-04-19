import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/detail_sanitizer.dart';

void main() {
  group('cleanFlowOverview', () {
    test('decodes overview from legacy notes metadata', () {
      final overview = cleanFlowOverview(
        'mode=gregorian;split=1;ov=Morning%20ritual',
      );

      expect(overview, 'Morning ritual');
    });

    test('drops metadata-only notes instead of showing code print', () {
      final overview = cleanFlowOverview('mode=gregorian;split=1');

      expect(overview, isEmpty);
    });

    test('drops serialized event payload json from overview display', () {
      final overview = cleanFlowOverview(
        '{"id":"e44e664e-b92c-4c36-9560-e1105a104dc7","title":"Family Salon","startLocal":"2026-04-19T09:00:00"}',
      );

      expect(overview, isEmpty);
    });

    test('extracts repeating note detail from json metadata', () {
      final overview = cleanFlowOverview(
        '{"kind":"repeating_note","detail":"Bring journal","location":"Temple"}',
      );

      expect(overview, 'Bring journal');
    });
  });

  group('cleanFlowDetail', () {
    test('strips hidden metadata prefixes and cid lines', () {
      final detail = cleanFlowDetail(
        'color=ffcc00;alert=-15;flowLocalId=12;Bring water\nkemet_cid:ky=1-km=2-kd=3|s=540|t=ritual|f=99',
      );

      expect(detail, 'Bring water');
    });

    test('drops serialized json detail blobs', () {
      final detail = cleanFlowDetail(
        '{"id":"1","title":"Workout","offset_days":0,"all_day":false}',
      );

      expect(detail, isEmpty);
    });
  });

  group('cleanFlowTitle', () {
    test('extracts title from serialized json', () {
      final title = cleanFlowTitle(
        '{"id":"1","title":"Family Salon","offset_days":0}',
      );

      expect(title, 'Family Salon');
    });

    test('drops time-only titles', () {
      final title = cleanFlowTitle('7:00 PM');

      expect(title, isEmpty);
    });
  });
}
