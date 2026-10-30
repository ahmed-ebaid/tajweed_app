import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajweed_practice/core/services/hijri_calendar_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native Umm al-Qura calendar follows local civil dates', (
    _,
  ) async {
    const calendar = HijriCalendarService();
    for (final hour in [0, 12, 23]) {
      expect(
        await calendar.dateFor(DateTime(2024, 3, 11, hour)),
        const HijriDate(1445, 9, 1),
      );
      expect(
        await calendar.dateFor(DateTime(2024, 4, 10, hour)),
        const HijriDate(1445, 10, 1),
      );
      expect(
        await calendar.dateFor(DateTime(2024, 6, 7, hour)),
        const HijriDate(1445, 12, 1),
      );
    }
    expect(
      await calendar.dateFor(DateTime(2024, 3, 10, 23, 59, 59)),
      const HijriDate(1445, 8, 29),
    );
    expect(
      await calendar.dateFor(DateTime(2024, 3, 11)),
      const HijriDate(1445, 9, 1),
    );
  });
}
