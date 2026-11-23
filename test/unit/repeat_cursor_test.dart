import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/services/speech_comparison_service.dart';
import 'package:tajweed_practice/features/reader/memorization_screen.dart';

void main() {
  final comparison = SpeechComparisonService();
  const kursi =
      'الله لا إله إلا هو الحي القيوم لا تأخذه سنة ولا نوم له ما في السماوات وما في الأرض';
  final words = comparison.recitationWords(kursi);

  int? cursor(String heard, int displayed) => repeatCursorIndex(
    spoken: comparison.recitationWords(heard),
    words: words,
    displayed: displayed,
  );

  test('stays on the next word while moving forward', () {
    expect(cursor('الله لا إله إلا هو الحي القيوم', 7), isNull);
  });

  test('follows the learner back when they repeat from the start', () {
    expect(cursor('الله لا إله إلا هو الحي القيوم الله لا إله', 7), 3);
  });

  test('follows a repeat from the middle of the ayah', () {
    expect(
      cursor(
        'الله لا إله إلا هو الحي القيوم لا تأخذه سنة ولا نوم الحي القيوم',
        12,
      ),
      7,
    );
  });

  test('picks the latest place when a phrase occurs twice', () {
    expect(
      cursor(
        'الله لا إله إلا هو الحي القيوم لا تأخذه سنة ولا نوم له ما في السماوات وما في الأرض وما في',
        19,
      ),
      18,
    );
  });

  test('ignores a single repeated word or a misheard repeat', () {
    expect(cursor('الله لا إله إلا هو الحي القيوم الله', 7), isNull);
    expect(cursor('الله لا إله إلا هو الحي القيوم الحي القيام', 7), isNull);
  });

  test('copes with a count past the end of the ayah', () {
    expect(cursor('الله لا إله', 40), 3);
  });
}
