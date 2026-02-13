import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/models/reminder.dart';

void main() {
  group('Reminder multi timing', () {
    test('supports before, at, and after in one task', () {
      final reminders = <Reminder>[
        Reminder.fifteenMinutesBefore(),
        Reminder.atTaskTime(),
        Reminder.fiveMinutesAfter(),
      ];

      final fingerprints = reminders.map((r) => r.fingerprint).toSet();
      expect(fingerprints.length, reminders.length);
    });

    test('calculates before/at/after fire times correctly', () {
      final due = DateTime(2026, 2, 13, 10, 0);

      final before = Reminder.fifteenMinutesBefore();
      final at = Reminder.atTaskTime();
      final after = Reminder.fiveMinutesAfter();

      expect(before.calculateReminderTime(due), DateTime(2026, 2, 13, 9, 45));
      expect(at.calculateReminderTime(due), DateTime(2026, 2, 13, 10, 0));
      expect(after.calculateReminderTime(due), DateTime(2026, 2, 13, 10, 5));
    });

    test('after factories produce expected payload-friendly values', () {
      final five = Reminder.fiveMinutesAfter();
      final fifteen = Reminder.fifteenMinutesAfter();
      final thirty = Reminder.thirtyMinutesAfter();
      final hour = Reminder.oneHourAfter();

      expect(five.type, 'after');
      expect(five.value, 5);
      expect(five.unit, 'minutes');

      expect(fifteen.type, 'after');
      expect(fifteen.value, 15);
      expect(fifteen.unit, 'minutes');

      expect(thirty.type, 'after');
      expect(thirty.value, 30);
      expect(thirty.unit, 'minutes');

      expect(hour.type, 'after');
      expect(hour.value, 1);
      expect(hour.unit, 'hours');
    });

    test('encodes/decodes mixed reminders without losing after type', () {
      final original = <Reminder>[
        Reminder.oneHourBefore(),
        Reminder.atTaskTime(),
        Reminder.thirtyMinutesAfter(),
      ];

      final encoded = Reminder.encodeList(original);
      final decoded = Reminder.decodeList(encoded);

      expect(decoded.length, 3);
      expect(decoded[0].type, 'before');
      expect(decoded[1].type, 'at_time');
      expect(decoded[2].type, 'after');
      expect(decoded[2].value, 30);
      expect(decoded[2].unit, 'minutes');
    });
  });
}
