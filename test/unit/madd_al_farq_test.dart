import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';

/// Regression coverage for مد الفرق (Madd al-Farq).
///
/// The interrogative hamza entering a word that opens with hamzat wasl stretches
/// the wasl to six harakat so the question is not misread as a statement. There
/// are only six such places in the Qur'an. Quran.com annotates the two مخفف ones
/// (10:51, 10:91) and ships the four مثقل ones with no markup whatsoever, so the
/// app has to reconstruct them or they render uncoloured.
///
/// Every `wordHtml` below is the verbatim `text_uthmani_tajweed` payload returned
/// by api.quran.com for that word.
void main() {
  TajweedWord wordFor(String verseKey, String wordHtml) {
    final ayah = AyahMapper.fromApi({
      'verse_key': verseKey,
      'page_number': 1,
      'words': [
        {'char_type_name': 'word', 'text_uthmani_tajweed': wordHtml},
      ],
    });
    return ayah.words.first;
  }

  /// Spans covering the madd letter that directly follows the opening `ءَ`.
  List<TajweedSpan> maddLetterSpans(TajweedWord word) {
    const hamza = 0x0621;
    const fatha = 0x064E;
    final text = word.arabic;
    expect(
      text.codeUnitAt(0),
      hamza,
      reason: 'fixture should open with the interrogative hamza',
    );
    expect(text.codeUnitAt(1), fatha);
    return word.spans.where((s) => s.start <= 2 && 2 < s.end).toList();
  }

  group('مثقل — upstream ships these completely untagged', () {
    const cases = [
      (verseKey: '6:143', wordHtml: 'ءَآلذَّكَرَيۡنِ'),
      (verseKey: '6:144', wordHtml: 'ءَآلذَّكَرَيۡنِ'),
      (verseKey: '10:59', wordHtml: 'ءَآللَّهُ'),
      (verseKey: '27:59', wordHtml: 'ءَآللَّهُ'),
    ];

    for (final c in cases) {
      test('${c.verseKey} colours the madd as kalimi muthaqqal', () {
        final word = wordFor(c.verseKey, c.wordHtml);
        final spans = maddLetterSpans(word);

        expect(
          spans,
          hasLength(1),
          reason:
              '${c.verseKey} should have exactly one span on the madd letter, '
              'got ${spans.map((s) => s.rule).toList()}',
        );
        expect(spans.single.rule, TajweedRule.maddLazimKalimiMuthaqqal);
        expect(
          word.arabic.substring(spans.single.start, spans.single.end),
          '\u0622',
          reason: 'the span should cover only the madd letter آ',
        );
      });
    }
  });

  group('مخفف — upstream already tags these; we must not double-tag', () {
    const cases = [
      // 10:51 wraps a bare alif and leaves the maddah outside the tag.
      (
        verseKey: '10:51',
        wordHtml:
            'ءَ<rule class=madda_necessary>ا</rule>ٓلۡـَٔ<rule class=madda_normal>ـٰ</rule>نَ',
      ),
      // 10:91 wraps the precomposed آ instead.
      (
        verseKey: '10:91',
        wordHtml:
            'ءَ<rule class=madda_necessary>آ</rule>لۡـَٔ<rule class=madda_normal>ـٰ</rule>نَ',
      ),
    ];

    for (final c in cases) {
      test('${c.verseKey} stays kalimi mukhaffaf with no duplicate span', () {
        final word = wordFor(c.verseKey, c.wordHtml);
        final spans = maddLetterSpans(word);

        expect(
          spans,
          hasLength(1),
          reason:
              '${c.verseKey} must not gain a synthesised span on top of the '
              'upstream one, got ${spans.map((s) => s.rule).toList()}',
        );
        expect(spans.single.rule, TajweedRule.maddLazimKalimiMukhaffaf);
      });
    }
  });

  group('does not fire on lookalikes', () {
    test('ءَامَنتُم (10:51) is a plain madd badal, not madd al-farq', () {
      final word = wordFor(
        '10:51',
        'ءَامَ<rule class=ikhafa>نت</rule><rule class=ikhafa_shafawi>ُم</rule>',
      );

      expect(
        word.spans.any(
          (s) =>
              s.rule == TajweedRule.maddLazimKalimiMuthaqqal ||
              s.rule == TajweedRule.maddLazimKalimiMukhaffaf,
        ),
        isFalse,
        reason: 'alif without a maddah above is not madd al-farq',
      );
    });

    test('word-internal ءَ in شُهَدَآءَ (6:144) is untouched', () {
      final word = wordFor(
        '6:144',
        'شُهَد<rule class=madda_obligatory_mottasel>َا</rule>ٓءَ',
      );

      expect(
        word.spans.any(
          (s) =>
              s.rule == TajweedRule.maddLazimKalimiMuthaqqal ||
              s.rule == TajweedRule.maddLazimKalimiMukhaffaf,
        ),
        isFalse,
        reason: 'the hamza must open the word to be interrogative',
      );
    });
  });

  test('segment-based parsing colours madd al-farq too', () {
    final segments = AyahMapper.parseTajweedHtml('قُلۡ ءَآللَّهُ أَذِنَ');

    final madd = segments.where(
      (s) => s.rule == TajweedRule.maddLazimKalimiMuthaqqal,
    );
    expect(madd, hasLength(1));
    expect(madd.single.text, '\u0622');

    expect(
      segments.map((s) => s.text).join(),
      'قُلۡ ءَآللَّهُ أَذِنَ',
      reason: 'splitting must preserve the original text exactly',
    );
  });
}
