import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/core/services/quran_api_service.dart';

void main() {
  test('scan shortest examples for remaining manual rules', () async {
    final api = QuranApiService();
    const targets = {
      TajweedRule.maddMunfasil,
      TajweedRule.izhar,
      TajweedRule.shaddah,
      TajweedRule.waqf,
    };
    final best = <TajweedRule, ({int surah, int ayah, int score, String text})>{};

    for (var surah = 1; surah <= 114; surah++) {
      if (best.keys.length == targets.length) {
        break;
      }

      final tajweedMap = await api.fetchTajweedText(chapterNumber: surah);
      var page = 1;

      while (true) {
        final verses = await api.fetchVerses(
          surahNumber: surah,
          langCode: 'en',
          page: page,
        );
        if (verses.isEmpty) break;

        final ayahs = AyahMapper.fromApiList(
          verses,
          tajweedMap: tajweedMap,
          requestedLangCode: 'en',
        );

        for (final ayah in ayahs) {
          final rules = <TajweedRule>{
            for (final word in ayah.words) ...word.spans.map((span) => span.rule),
          };
          for (final rule in targets) {
            if (!rules.contains(rule)) continue;
            final normalized = ayah.arabic.replaceAll(RegExp(r'\s+'), ' ').trim();
            final score = ayah.words.length * 1000 + normalized.runes.length;
            final current = best[rule];
            if (current == null || score < current.score) {
              best[rule] = (
                surah: ayah.surahNumber,
                ayah: ayah.ayahNumber,
                score: score,
                text: normalized,
              );
            }
          }
        }

        if (best.keys.length == targets.length) {
          break;
        }

        if (verses.length < 50) break;
        page++;
      }
    }

    for (final rule in targets) {
      final hit = best[rule];
      // ignore: avoid_print
      print('${rule.name}: ${hit == null ? 'no match found' : '${hit.surah.toString().padLeft(3, '0')}${hit.ayah.toString().padLeft(3, '0')} score=${hit.score} text=${hit.text}'}');
    }

    expect(best.keys.toSet(), equals(targets));
  },
      timeout: const Timeout(Duration(minutes: 5)),
      skip: 'Utility scan only; izhar, shaddah, and waqf require manual curation because upstream tajweed spans do not expose them reliably.');
}