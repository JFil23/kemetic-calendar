import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/day_view_restoration_write_gate.dart';

void main() {
  group('DayViewRestorationWriteGate', () {
    test('allows open writes only for the active session', () {
      final gate = DayViewRestorationWriteGate();
      final first = gate.beginOpen();

      expect(gate.canAcceptOpenWrite(first), isTrue);
      expect(gate.shouldPersist(isOpen: true, sessionId: first), isTrue);
      expect(gate.shouldPersist(isOpen: true), isTrue);

      final second = gate.beginOpen();

      expect(gate.canAcceptOpenWrite(first), isFalse);
      expect(gate.canAcceptOpenWrite(second), isTrue);
    });

    test('blocks stale open writes after close but allows closed writes', () {
      final gate = DayViewRestorationWriteGate();
      final session = gate.beginOpen();

      gate.markClosed(session);

      expect(gate.canAcceptOpenWrite(session), isFalse);
      expect(gate.shouldPersist(isOpen: true, sessionId: session), isFalse);
      expect(gate.shouldPersist(isOpen: true), isFalse);
      expect(gate.shouldPersist(isOpen: false, sessionId: session), isTrue);
    });

    test('allows a new explicit open after a prior close', () {
      final gate = DayViewRestorationWriteGate();
      final first = gate.beginOpen();
      gate.markClosed(first);

      final second = gate.beginOpen();

      expect(gate.shouldPersist(isOpen: true, sessionId: first), isFalse);
      expect(gate.shouldPersist(isOpen: true, sessionId: second), isTrue);
    });
  });
}
