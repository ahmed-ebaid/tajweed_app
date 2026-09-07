import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';

String _cp(List<int> codes) => String.fromCharCodes(codes);

const int _zwnj = 0x200C;
const int _waqfSala = 0x06D6;
const int _waqfWaqfLazim = 0x06D8;
const int _waqfSmallSeen = 0x06DC;

/// A *body* run must start with something that occupies space. A body run that
/// opens with a nonspacing mark or a zero-width format character has been torn
/// out of its grapheme cluster and will be drawn over the preceding letter.
///
/// Waqf marker runs are deliberately exempt: the sign is *meant* to be a bare
/// nonspacing mark so the font can stack it above the harakah.
bool _bodyRunLacksVisibleBase(String text) {
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


/// Collects body runs that open without a visible base *and* are not the
/// harmless trailing-mark case.
///
/// 19 corpus words (e.g. 33:38 لَهُۖۥ, 2:245 وَيَبۡصُۜطُ) carry combining marks
/// *after* the waqf sign. Splitting the sign out leaves those marks opening a
/// body run. `test/unit/waqf_render_geometry_test.dart` renders those words with and
/// without the split and finds no glyph moves — the runs share a typeface, so
/// Skia keeps them in one shaping run and the marks still attach. A body run
/// that opens with a mark right after a waqf marker run is therefore expected.
List<String> _strandedBodyRuns(
  List<({String text, TajweedRule? markerRule, bool isMarker})> runs,
) {
  final offenders = <String>[];
  var afterWaqfMarker = false;
  for (final run in runs) {
    final isWaqfMarker = run.isMarker && run.markerRule == TajweedRule.waqf;
    if (!run.isMarker && !afterWaqfMarker && _bodyRunLacksVisibleBase(run.text)) {
      offenders.add(run.text);
    }
    afterWaqfMarker = isWaqfMarker;
  }
  return offenders;
}

Iterable<String> _bodyRuns(
  List<({String text, TajweedRule? markerRule, bool isMarker})> runs,
) => runs.where((r) => !r.isMarker).map((r) => r.text);

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
    test('the waqf sign becomes its own colour-only run', () {
      final runs = TajweedText.splitIntoStyledRuns(_rabbihimArabic());
      final waqfRuns = runs
          .where((r) => r.text.contains(String.fromCharCode(_waqfSala)))
          .toList();

      expect(waqfRuns, hasLength(1));
      expect(waqfRuns.single.isMarker, isTrue);
      expect(waqfRuns.single.markerRule, TajweedRule.waqf);
      expect(
        waqfRuns.single.text,
        String.fromCharCode(_waqfSala),
        reason:
            'The run must hold the sign alone. A carried separator gives the '
            'nonspacing mark its own base and pushes the sign clear of the '
            'word instead of stacking it above the harakah.',
      );
    });

    test('the separator before a waqf sign is dropped, not carried', () {
      final runs = TajweedText.splitIntoStyledRuns(_rabbihimArabic());

      expect(runs.map((r) => r.text).join(), isNot(contains(' ')));
      expect(
        runs.map((r) => r.text).join(),
        isNot(contains(String.fromCharCode(_zwnj))),
      );
    });

    test('no body run opens without a visible base', () {
      final runs = TajweedText.splitIntoStyledRuns(_rabbihimArabic());

      expect(_strandedBodyRuns(runs), isEmpty);
    });

    test('the letter before the waqf keeps body styling', () {
      final runs = TajweedText.splitIntoStyledRuns(_rabbihimArabic());

      expect(_bodyRuns(runs).join(), contains(_cp(const [0x0645, 0x06E1])));
      expect(
        runs.any((r) => r.isMarker && r.text.contains('\u0645')),
        isFalse,
        reason: 'Marker colouring must not bleed onto the preceding letter.',
      );
    });

    test('splitting drops only the waqf separator', () {
      final arabic = _rabbihimArabic();
      final rebuilt = TajweedText.splitIntoStyledRuns(arabic)
          .map((r) => r.text)
          .join();

      // Lossless apart from the one separator that D1 deliberately removes.
      expect(rebuilt, arabic.replaceAll(' ${String.fromCharCode(_waqfSala)}',
          String.fromCharCode(_waqfSala)));
    });

    test('a waqf sitting directly on a letter still gets its colour', () {
      // U+06DC appears mid-word (2:245 وَيَبۡصُۜطُ) with no separator at all.
      // It used to be left in plain text and silently lose the waqf palette.
      final source = _cp(const [0x0635, 0x064F, _waqfSmallSeen, 0x0637]);
      final runs = TajweedText.splitIntoStyledRuns(source);
      final waqfRuns = runs.where((r) => r.isMarker).toList();

      expect(waqfRuns, hasLength(1));
      expect(waqfRuns.single.markerRule, TajweedRule.waqf);
      expect(waqfRuns.single.text, String.fromCharCode(_waqfSmallSeen));
      expect(_strandedBodyRuns(runs), isEmpty);
      // Nothing is dropped here: there was no separator to remove.
      expect(runs.map((r) => r.text).join(), source);
    });

    test('a word carrying both a mid-word and a trailing waqf', () {
      // 7:69 بَصۜۡطَةً ۖ exercises both forms in a single word.
      final source = _cp(const [
        0x0628, 0x064E, 0x0635, _waqfSmallSeen, 0x06E1, 0x0637, 0x064E, //
        0x0629, 0x064B, 0x20, _waqfSala,
      ]);
      final runs = TajweedText.splitIntoStyledRuns(source);
      final markers = runs.where((r) => r.isMarker).toList();

      expect(markers, hasLength(2));
      expect(markers.map((r) => r.text), [
        String.fromCharCode(_waqfSmallSeen),
        String.fromCharCode(_waqfSala),
      ]);
      expect(_strandedBodyRuns(runs), isEmpty);
      expect(runs.map((r) => r.text).join(), isNot(contains(' ')));
    });

    test('every waqf sign in the range gets an isolated marker run', () {
      for (final waqf in [
        _waqfSala, 0x06D7, _waqfWaqfLazim, 0x06D9, 0x06DA, 0x06DB, //
        _waqfSmallSeen,
      ]) {
        final source = _cp([0x0645, 0x06E1, 0x20, waqf]);
        final runs = TajweedText.splitIntoStyledRuns(source);
        final markers = runs.where((r) => r.isMarker).toList();

        expect(
          markers.map((r) => r.text),
          [String.fromCharCode(waqf)],
          reason: 'U+${waqf.toRadixString(16)} did not get an isolated run.',
        );
        expect(_strandedBodyRuns(runs), isEmpty);
      }
    });
  });

  group('marker styling', () {
    const body = TextStyle(
      fontFamily: 'AmiriQuran',
      fontSize: 28,
      color: Color(0xFF111111),
    );

    test('the waqf marker run keeps the body typeface', () {
      final styled = TajweedText.markerStyleFrom(
        body,
        markerRule: TajweedRule.waqf,
      );

      expect(
        styled.fontFamily,
        'AmiriQuran',
        reason:
            'A typeface change forces a separate shaping run, which tears the '
            "sign off the letter and drops it onto the harakah. Colour alone "
            'does not split the run, so only the colour may differ.',
      );
      expect(styled.fontFamilyFallback, body.fontFamilyFallback);
      expect(styled.fontSize, body.fontSize);
    });

    test('the waqf marker run is recoloured to the waqf palette', () {
      final styled = TajweedText.markerStyleFrom(
        body,
        markerRule: TajweedRule.waqf,
      );

      expect(styled.color, TajweedRule.waqf.color);
      expect(styled.color, isNot(body.color));
    });
  });
}
