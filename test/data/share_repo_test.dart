import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/share_repo.dart';

void main() {
  group('isExternalInboxActivityActor', () {
    test('rejects self activity rows', () {
      expect(isExternalInboxActivityActor('user-1', 'user-1'), isFalse);
    });

    test('rejects missing actor ids', () {
      expect(isExternalInboxActivityActor(null, 'user-1'), isFalse);
      expect(isExternalInboxActivityActor('', 'user-1'), isFalse);
    });

    test('accepts activity from other users', () {
      expect(isExternalInboxActivityActor('user-2', 'user-1'), isTrue);
    });
  });
}
