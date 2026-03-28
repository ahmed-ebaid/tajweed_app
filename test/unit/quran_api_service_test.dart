import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/quran_api_service.dart';

void main() {
  group('QuranApiService.ruleFromCode', () {
    test('maps all known tajweed codes to rules', () {
      final expected = {
        'g': TajweedRule.ghunnah,
        'q': TajweedRule.qalqalah,
        'm': TajweedRule.maddTabeei,
        'M': TajweedRule.maddMuttasil,
        'n': TajweedRule.maddMunfasil,
        'i': TajweedRule.ikhfa,
        'I': TajweedRule.iqlab,
        'd': TajweedRule.idghamWithGhunnah,
        'D': TajweedRule.idghamWithoutGhunnah,
        'z': TajweedRule.izhar,
        's': TajweedRule.shaddah,
      };
      for (final entry in expected.entries) {
        expect(
          QuranApiService.ruleFromCode(entry.key),
          equals(entry.value),
          reason: 'Code "${entry.key}" should map to ${entry.value}',
        );
      }
    });

    test('returns null for unknown codes', () {
      expect(QuranApiService.ruleFromCode('x'), isNull);
      expect(QuranApiService.ruleFromCode(''), isNull);
      expect(QuranApiService.ruleFromCode('Z'), isNull);
    });

    test('codes are case-sensitive (m ≠ M)', () {
      expect(QuranApiService.ruleFromCode('m'), equals(TajweedRule.maddTabeei));
      expect(QuranApiService.ruleFromCode('M'), equals(TajweedRule.maddMuttasil));
    });
  });

  group('QuranApiService.audioUrl', () {
    test('formats URL correctly with zero-padded surah and ayah', () {
      final service = QuranApiService();
      final url = service.audioUrl(reciterId: 7, surahNumber: 1, ayahNumber: 1);
      expect(url, equals('https://verses.quran.com/7/001001.mp3'));
    });

    test('handles double-digit surah and ayah', () {
      final service = QuranApiService();
      final url = service.audioUrl(reciterId: 7, surahNumber: 67, ayahNumber: 30);
      expect(url, equals('https://verses.quran.com/7/067030.mp3'));
    });
  });
}
