import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';

String _cp(List<int> codes) => String.fromCharCodes(codes);

const int _zwnj = 0x200C;
const int _waqfSala = 0x06D6;
const int _waqfWaqfLazim = 0x06D8;
const int _waqfSmallSeen = 0x06DC;

/// A run must start with something that actually occupies space. Nonspacing
/// combining marks and zero-width format characters give the shaper no advance
/// to work with, so anything that follows is drawn back over the preceding
/// letter's harakah.
bool _lacksVisibleBase(String text) {
  if (text.isEmpty) return false;
  final cp = text.codeUnitAt(0);
  if (cp == 0x200B || (cp >= 0x200C && cp <= 0x200F) || cp == 0xFEFF) {
    return true;
  }
  return (cp >= 0x0610 && cp <= 0x061A) ||
      (cp >= 0x064B && cp <= 0x065F) ||
      (cp >= 0x06D6 && cp <= 0x06DC) ||
      (cp >= 0x06DF && cp <= 0x06E8) ||
      (cp >= 0x06EA && cp <= 0x06ED);
}

/// 2:5 رَّبِّهِمْ ۖ exactly as Quran.com serves it: the tajweed HTML separates
/// the waqf sign with a ZWNJ where `text_uthmani` uses a space.
String _rabbihimArabic() {
  final ayah = AyahMapper.fromApi({
    'verse_key': '2:5',
    'page_number': 2,
    'text_uthmani': 'رَّبِّهِمْ ۖ',
    'words': [
      {
        'char_type_name': 'word',
        'text_uthmani': _cp(const [
          0x0631, 0x0651, 0x064E, 0x0628, 0x0651, 0x0650, 0x0643, 0x064F, //
          0x0645, 0x0652, 0x20, _waqfSala,
        ]),
        'text_uthmani_tajweed':
            '<rule class=idgham_wo_ghunnah>${_cp(const [0x0631])}</rule>'
            '${_cp(const [
              0x0651, 0x064E, 0x0628, 0x0651, 0x0650, 0x0643, 0x064F, //
              0x0645, 0x06E1, _zwnj, _waqfSala,
            ])}',
      },
    ],
  });
  return ayah.words.first.arabic;
}

void main() {
  group('waqf separator normalization', () {
    test('ZWNJ before a waqf sign becomes a real space', () {
      final arabic = _rabbihimArabic();

      expect(
        arabic.contains(String.fromCharCode(_zwnj)),
        isFalse,
        reason:
            'A zero-width separator gives the waqf sign no room, so it is '
            'drawn back over the preceding harakah.',
      );
      expect(arabic, contains(' ${String.fromCharCode(_waqfSala)}'));
    });

    test('the replacement preserves offsets so tajweed spans stay aligned', () {
      final source = _cp(const [0x0645, 0x06E1, _zwnj, _waqfSala]);
      final normalized = AyahMapper.normalizeArabicForDisplay(source);

      expect(normalized.length, source.length);
      expect(normalized.codeUnitAt(2), 0x20);
    });

    test('ZWNJ not followed by a Quranic mark is left alone', () {
      final source = _cp(const [0x0645, _zwnj, 0x0646]);

      expect(AyahMapper.normalizeArabicForDisplay(source), source);
    });
  });

  group('styled run splitting', () {
    test('waqf sign never opens a run without a visible base', () {
      final runs = TajweedText.splitIntoStyledRuns(_rabbihimArabic());

      expect(
        runs.map((r) => r.text).where(_lacksVisibleBase).toList(),
        isEmpty,
        reason:
            'A run starting with a combining mark has nothing to attach to, '
            "so the waqf sign is drawn over the previous letter's harakah.",
      );
    });

    test('waqf sign carries its separator into the marker run', () {
      final runs = TajweedText.splitIntoStyledRuns(_rabbihimArabic());
      final waqfRuns = runs
          .where((r) => r.text.contains(String.fromCharCode(_waqfSala)))
          .toList();

      expect(waqfRuns, hasLength(1));
      expect(waqfRuns.single.isMarker, isTrue);
      expect(waqfRuns.single.text, ' ${String.fromCharCode(_waqfSala)}');
    });

    test('the letter before the waqf keeps body styling', () {
      final runs = TajweedText.splitIntoStyledRuns(_rabbihimArabic());
      final bodyText = runs
          .where((r) => !r.isMarker)
          .map((r) => r.text)
          .join();

      expect(bodyText, contains(_cp(const [0x0645, 0x06E1])));
      expect(
        runs.any((r) => r.isMarker && r.text.contains('\u0645')),
        isFalse,
        reason: 'Marker colouring must not bleed onto the preceding letter.',
      );
    });

    test('splitting is lossless', () {
      final arabic = _rabbihimArabic();

      expect(TajweedText.splitIntoStyledRuns(arabic).map((r) => r.text).join(),
          arabic);
    });

    test('a waqf sitting directly on a letter stays with that letter', () {
      // U+06DC appears mid-word (e.g. 2:245 يَبْصُۜطُ) with no separator. It
      // must not be torn out of its cluster, or it loses its base glyph.
      final source = _cp(const [0x0635, 0x064F, _waqfSmallSeen, 0x0637]);
      final runs = TajweedText.splitIntoStyledRuns(source);

      expect(runs.map((r) => r.text).where(_lacksVisibleBase), isEmpty);
      expect(runs.map((r) => r.text).join(), source);
    });

    test('every waqf sign in the range is handled', () {
      for (final waqf in [_waqfSala, _waqfWaqfLazim, 0x06D7, 0x06D9, 0x06DA]) {
        final source = _cp([0x0645, 0x06E1, 0x20, waqf]);
        final runs = TajweedText.splitIntoStyledRuns(source);

        expect(
          runs.map((r) => r.text).where(_lacksVisibleBase),
          isEmpty,
          reason: 'U+${waqf.toRadixString(16)} left without a base glyph.',
        );
      }
    });
  });
}
