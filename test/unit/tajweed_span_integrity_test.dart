import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';

/// Builds a string from explicit code points so the Arabic in these fixtures
/// is unambiguous — several of these words differ only in combining marks.
String _cp(List<int> codes) => String.fromCharCodes(codes);

Map<String, dynamic> _word(String uthmani, String tajweed) {
  return {
    'char_type_name': 'word',
    'text_uthmani': uthmani,
    'text_uthmani_tajweed': tajweed,
  };
}

Set<TajweedRule> _rulesOf(TajweedWord word) {
  return word.spans.map((span) => span.rule).toSet();
}

String _spanText(TajweedWord word, TajweedRule rule) {
  final span = word.spans.firstWhere((s) => s.rule == rule);
  return word.arabic.substring(span.start, span.end);
}

void main() {
  // ── 18:29 إِنَّآ أَعْتَدْنَا ────────────────────────────────────────────────
  //
  // Regression for a dropped span. Quran.com annotates the final ـَآ of إِنَّآ as
  // `madda_obligatory_monfasel`, but `_normalizeArabicText` reorders the
  // shaddah of نّ to sit *after* its fatha. That slides the shaddah between the
  // ghunnah span and the madd's opening fatha, so the scan position advanced
  // past the fatha and every forward search for ـَآ failed. The rule was then
  // skipped outright and the alif rendered uncoloured.
  const innaUthmani = [0x0625, 0x0650, 0x0646, 0x0651, 0x064E, 0x0627, 0x0653];
  final innaTajweed =
      '${_cp(const [0x0625, 0x0650])}'
      '<rule class=ghunnah>${_cp(const [0x0646, 0x0651])}</rule>'
      '<rule class=madda_obligatory_monfasel>'
      '${_cp(const [0x064E, 0x0627, 0x0653])}</rule>';

  final aAtadnaTajweed =
      '${_cp(const [0x0623, 0x064E, 0x0639, 0x06E1, 0x062A, 0x064E])}'
      '<rule class=qalaqah>${_cp(const [0x062F, 0x06E1])}</rule>'
      '${_cp(const [0x0646, 0x064E, 0x0627])}';

  Ayah buildInnaAyah() {
    return AyahMapper.fromApi({
      'verse_key': '18:29',
      'page_number': 296,
      'text_uthmani': '${_cp(innaUthmani)} أَعْتَدْنَا',
      'words': [
        _word(_cp(innaUthmani), innaTajweed),
        _word('أَعْتَدْنَا', aAtadnaTajweed),
      ],
    });
  }

  test('colours madd munfasil when the madd harakah sits on a shaddah', () {
    final ayah = buildInnaAyah();
    final inna = ayah.words.first;

    expect(
      _rulesOf(inna),
      contains(TajweedRule.maddMunfasil),
      reason:
          'إِنَّآ (18:29) is annotated madda_obligatory_monfasel upstream; the '
          'shaddah reordering must not drop the span.',
    );
  });

  test('madd munfasil span covers only the madd letter, not the shaddah', () {
    final inna = buildInnaAyah().words.first;

    expect(
      _spanText(inna, TajweedRule.maddMunfasil),
      _cp(const [0x0627, 0x0653]),
      reason:
          'Madd spans highlight the madd letter alone — never the preceding '
          'consonant, its harakah, or the shaddah.',
    );
  });

  test('recovering the madd span leaves the preceding ghunnah intact', () {
    final inna = buildInnaAyah().words.first;

    expect(_rulesOf(inna), contains(TajweedRule.ghunnah));

    final ghunnah = inna.spans.firstWhere(
      (s) => s.rule == TajweedRule.ghunnah,
    );
    final madd = inna.spans.firstWhere(
      (s) => s.rule == TajweedRule.maddMunfasil,
    );
    expect(
      madd.start,
      greaterThanOrEqualTo(ghunnah.end),
      reason: 'Recovered spans must not overlap the span that preceded them.',
    );
  });

  // ── No rule may be silently discarded ──────────────────────────────────────
  //
  // The bug above failed silently: the rule class was recognised, its span
  // could not be located, and the parser moved on. These fixtures lock that
  // behaviour down for words that exercise the shaddah-reordering path.
  group('every annotated rule produces a span', () {
    final fixtures = <String, Map<String, dynamic>>{
      // 18:29 إِنَّآ — shaddah directly before a madd munfasil.
      'إِنَّآ': _word(_cp(innaUthmani), innaTajweed),
      // 18:29 شَآءَ — madd muttasil with no shaddah involved (control).
      'شَآءَ': _word(
        _cp(const [0x0634, 0x064E, 0x0627, 0x0653, 0x0621, 0x064E]),
        '<rule class=ikhafa>${_cp(const [0x0634])}</rule>'
        '<rule class=madda_obligatory_mottasel>'
        '${_cp(const [0x064E, 0x0627])}</rule>'
        '${_cp(const [0x0653, 0x0621, 0x064E])}',
      ),
      // 18:29 لِلظَّـٰلِمِينَ — natural madd on a dagger alif after a shaddah.
      'لِلظَّـٰلِمِينَ': _word(
        _cp(const [
          0x0644, 0x0650, 0x0644, 0x0638, 0x0651, 0x064E, 0x0640, 0x0670, //
          0x0644, 0x0650, 0x0645, 0x0650, 0x064A, 0x0646, 0x064E,
        ]),
        '${_cp(const [0x0644, 0x0650, 0x0644, 0x0638, 0x0651, 0x064E])}'
            '<rule class=madda_normal>${_cp(const [0x0640, 0x0670])}</rule>'
            '${_cp(const [
              0x0644, 0x0650, 0x0645, 0x0650, 0x064A, 0x0646, 0x064E, //
            ])}',
      ),
      // 18:29 بِمَآءٍۢ — muttasil followed by a second rule after the maddah.
      'بِمَآءٍۢ': _word(
        _cp(const [
          0x0628, 0x0650, 0x0645, 0x064E, 0x0627, 0x0653, 0x0621, 0x064D, //
          0x06E2,
        ]),
        '${_cp(const [0x0628, 0x0650, 0x0645])}'
            '<rule class=madda_obligatory_mottasel>'
            '${_cp(const [0x064E, 0x0627])}</rule>${_cp(const [0x0653])}'
            '<rule class=ikhafa>${_cp(const [0x0621, 0x064D])}</rule>',
      ),
    };

    fixtures.forEach((label, word) {
      test('$label drops no annotated rule', () {
        expect(
          AyahMapper.unmatchedRuleClasses(word),
          isEmpty,
          reason: '$label has rule tags the parser could not place in the text.',
        );
      });
    });
  });
}
