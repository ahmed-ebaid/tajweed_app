import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/providers/daily_lesson_provider.dart';
import 'package:tajweed_practice/core/providers/reader_navigation_provider.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';

void main() {
  final lessons = List.generate(
    7,
    (index) => DailyLesson.forDate(DateTime(2026, 1, index + 1)),
  );

  test('lesson navigation carries focus; ordinary navigation does not', () {
    final navigation = ReaderNavigationProvider();
    navigation.openLesson(lessons.first);
    final request = navigation.consumePending()!;
    expect(request.lesson, same(lessons.first));
    expect(request.surah, lessons.first.surah);
    expect(request.ayah, lessons.first.ayah);
    expect(navigation.pending, isNull);
    navigation.openSurahAyah(surah: request.surah, ayah: request.ayah);
    expect(navigation.consumePending()!.lesson, isNull);
    navigation.dispose();
  });

  test('all lesson titles and focus instructions are localized', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = AppLocalizations(locale);
      expect(l10n.get('lesson_focus_hint'), isNot('lesson_focus_hint'));
      for (final lesson in lessons) {
        expect(lesson.wordIndices, isNotEmpty);
        expect(lesson.titleFor(locale.languageCode), isNotEmpty);
        if (!['en', 'ar'].contains(locale.languageCode)) {
          expect(
            lesson.titleFor(locale.languageCode),
            contains(l10n.get(lesson.rule.nameKey)),
          );
        }
      }
    }
  });

  test('lesson selection depends on the calendar day, not the time', () {
    for (var day = 1; day <= 365; day++) {
      final date = DateTime(2026, 1, day);
      expect(
        DailyLesson.forDate(DateTime(date.year, date.month, date.day, 23)),
        same(DailyLesson.forDate(date)),
      );
    }
  });

  final path = Platform.environment['QURAN_WORDS_JSON_PATH'];
  test(
    'every authored focus points to its rule in the Quran corpus',
    () {
      final root =
          jsonDecode(File(path!).readAsStringSync()) as Map<String, dynamic>;
      final verses = (root['verses'] as List).cast<Map<String, dynamic>>();
      for (final lesson in lessons) {
        final raw = verses.singleWhere(
          (verse) => verse['verse_key'] == '${lesson.surah}:${lesson.ayah}',
        );
        final ayah = AyahMapper.fromApi(raw);
        expect(lesson.matches(ayah), isTrue);
        for (final index in lesson.wordIndices) {
          final word = ayah.words[index];
          expect(
            word.spans.any((span) => span.rule == lesson.rule) ||
                (lesson.rule == TajweedRule.waqf && word.arabic.contains('ۖ')),
            isTrue,
            reason:
                '${lesson.surah}:${lesson.ayah} word $index (${word.arabic})',
          );
        }
        final missingWords = Ayah(
          surahNumber: lesson.surah,
          ayahNumber: lesson.ayah,
          pageNumber: 1,
          arabic: ayah.arabic,
          translations: const {},
          words: const [],
        );
        expect(lesson.matches(missingWords), isFalse);
      }
    },
    skip: path == null
        ? 'Requires QURAN_WORDS_JSON_PATH corpus fixture'
        : false,
  );
}
