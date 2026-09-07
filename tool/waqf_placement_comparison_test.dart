// Investigation harness — renders the waqf sign under competing placement
// strategies so they can be compared visually. Not part of the test suite; it
// lives outside test/ so `flutter test` does not pick it up.
//
//   flutter test tool/waqf_placement_comparison_test.dart
//
// Writes PNGs and a geometry report to build/waqf-comparison/.
//
// The question it answers: can a waqf sign be stacked above the preceding
// letter's harakah while still being painted in the waqf colour? That needs the
// sign to stay in the same shaping run as the letter, because GPOS mark
// attachment and mkmk do not cross run boundaries — and a run is the unit
// Flutter styles. Whether a colour-only difference forces a new shaping run is
// the crux, so it is measured here rather than assumed.

// This is test-only tooling that deliberately drives the production splitter
// through its @visibleForTesting seam, but it lives in tool/ rather than test/
// so `flutter test` does not collect it into the suite.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';

const String _outputDir = 'build/waqf-comparison';
const String _bodyFamily = 'AmiriQuran';

/// A genuinely different Arabic typeface, used for the marker runs.
///
/// Production styles marker runs with `GoogleFonts.scheherazadeNew`, which is
/// not bundled and cannot be fetched under `flutter test`. Registering the same
/// AmiriQuran bytes under a second family name would *not* reproduce the real
/// condition, because the resolved typeface would be identical and the shaper
/// need not break the run. macOS ships SF Arabic, a real second Arabic face, so
/// a marker run styled with it forces a true cross-typeface shaping boundary —
/// exactly what Scheherazade does in production.
const String _markerFamily = 'ComparisonMarkerFace';
const String _markerFontPath = '/System/Library/Fonts/SFArabic.ttf';

/// `flutter_tester` runs with `--use-test-fonts`, which renders every Latin
/// glyph as a filled box. A real face has to be registered for the labels.
const String _labelFamily = 'ComparisonLabel';
const String _labelFontPath = '/System/Library/Fonts/Supplemental/Arial.ttf';

const double _renderFontSize = 56;
const double _pixelRatio = 2.5;

const Color _bodyColor = Color(0xFF1B1B1B);
const Color _waqfColor = Color(0xFFD62828);
const Color _backgroundColor = Color(0xFFFFFDF7);

const Set<int> _waqfRunes = {
  0x06D6,
  0x06D7,
  0x06D8,
  0x06D9,
  0x06DA,
  0x06DB,
  0x06DC,
};

/// Words pulled from the corpus where the waqf sign follows a harakah — the
/// case the user reported. Shaped through [AyahMapper] so the text under test
/// is what the renderer actually receives.
const List<_Sample> _samples = [
  _Sample(
    id: '1-rayba',
    verseKey: '2:2',
    label: 'rayba (2:2) - fatha then U+06DB',
    textUthmani: 'رَيْبَ ۛ',
    tajweedHtml: 'رَيۡبَ\u200Cۛ',
  ),
  _Sample(
    id: '2-sufahau',
    verseKey: '2:13',
    label: 'as-sufahau (2:13) - damma then U+06D7',
    textUthmani: 'ٱلسُّفَهَآءُ ۗ',
    tajweedHtml: 'ٱلسُّفَهَآءُ\u200Cۗ',
  ),
  _Sample(
    id: '3-aduwwun',
    verseKey: '2:36',
    label: 'aduwwun (2:36) - shadda + tanwin damm then U+06D6',
    textUthmani: 'عَدُوٌّۭ ۖ',
    tajweedHtml: 'عَدُوٌّ\u200Cۖ',
  ),
  _Sample(
    id: '4-rabbihim',
    verseKey: '2:26',
    label: 'rabbihim (2:26) - sukun then U+06D6',
    textUthmani: 'رَّبِّهِمْ ۖ',
    tajweedHtml: 'رَّبِّهِمۡ\u200Cۖ',
  ),
];

class _Sample {
  const _Sample({
    required this.id,
    required this.verseKey,
    required this.label,
    required this.textUthmani,
    required this.tajweedHtml,
  });

  final String id;
  final String verseKey;
  final String label;
  final String textUthmani;
  final String tajweedHtml;

  /// Runs the API payload through the real mapper so normalization (including
  /// the ZWNJ to space replacement) is exercised rather than simulated.
  String get normalized => AyahMapper.fromApi({
    'verse_key': verseKey,
    'page_number': 1,
    'text_uthmani': textUthmani,
    'words': [
      {
        'char_type_name': 'word',
        'text_uthmani': textUthmani,
        'text_uthmani_tajweed': tajweedHtml,
      },
    ],
  }).words.first.arabic;
}

class _Variant {
  const _Variant({
    required this.id,
    required this.title,
    required this.summary,
    required this.build,
  });

  final String id;
  final String title;
  final String summary;
  final Widget Function(String normalized) build;
}

TextStyle _style({
  required String family,
  required Color color,
  List<String> fallback = const [],
}) => TextStyle(
  color: color,
  fontSize: _renderFontSize,
  height: 2.0,
  fontFamily: family,
  fontFamilyFallback: fallback,
  fontFeatures: const [
    FontFeature.enable('ccmp'),
    FontFeature.enable('mark'),
    FontFeature.enable('mkmk'),
    FontFeature.enable('rlig'),
    FontFeature.enable('liga'),
    FontFeature.enable('calt'),
  ],
);

TextStyle get _bodyStyle => _style(family: _bodyFamily, color: _bodyColor);

Widget _rich(List<InlineSpan> children) => Text.rich(
  TextSpan(children: children),
  textDirection: TextDirection.rtl,
  textAlign: TextAlign.center,
);

/// Strips the separator that precedes a waqf sign, reproducing the tajweed
/// payload as it looked before the fix.
String _withoutSeparator(String text) {
  final out = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final isSeparatorBeforeWaqf =
        text.codeUnitAt(i) == 0x20 &&
        i + 1 < text.length &&
        _waqfRunes.contains(text.codeUnitAt(i + 1));
    if (!isSeparatorBeforeWaqf) out.writeCharCode(text.codeUnitAt(i));
  }
  return out.toString();
}

String _withoutWaqf(String text) {
  final out = StringBuffer();
  for (final unit in text.codeUnits) {
    if (!_waqfRunes.contains(unit)) out.writeCharCode(unit);
  }
  return out.toString();
}

/// Restores the ZWNJ that the mapper replaces with a space, reproducing exactly
/// the string that reached the renderer before commit `e26841d`.
///
/// The mapper's replacement is 1:1, so undoing it is lossless.
String _withZwnjSeparator(String text) => text.replaceAllMapped(
  RegExp('\u0020(?=[\u06D6-\u06ED])'),
  (_) => '\u200C',
);

/// Splits at waqf signs, leaving the separator (if any) with the body text.
List<({String text, bool isWaqf})> _splitAtWaqf(String text) {
  final runs = <({String text, bool isWaqf})>[];
  final buffer = StringBuffer();
  for (final unit in text.codeUnits) {
    if (_waqfRunes.contains(unit)) {
      if (buffer.isNotEmpty) {
        runs.add((text: buffer.toString(), isWaqf: false));
        buffer.clear();
      }
      runs.add((text: String.fromCharCode(unit), isWaqf: true));
      continue;
    }
    buffer.writeCharCode(unit);
  }
  if (buffer.isNotEmpty) runs.add((text: buffer.toString(), isWaqf: false));
  return runs;
}

final List<_Variant> _variants = [
  _Variant(
    id: 'Z1-baseline-no-waqf-with-space',
    title: 'Z1. Baseline: word only, separator kept, no waqf sign',
    summary:
        'Reference render used to isolate the waqf glyph by image difference. '
        'The sign is nonspacing, so deleting it shifts nothing else.',
    build: (normalized) => _rich([
      TextSpan(text: _withoutWaqf(normalized), style: _bodyStyle),
    ]),
  ),
  _Variant(
    id: 'Z2-baseline-no-waqf-no-space',
    title: 'Z2. Baseline: word only, separator removed, no waqf sign',
    summary: 'Reference render for the variants that drop the separator.',
    build: (normalized) => _rich([
      TextSpan(
        text: _withoutWaqf(_withoutSeparator(normalized)),
        style: _bodyStyle,
      ),
    ]),
  ),
  _Variant(
    id: 'A-current-shipping',
    title: 'A. Current (e26841d): space carried into a separate coloured run',
    summary:
        'Marker run has its own colour and its own font family. Separate '
        'shaping run, so the sign anchors to the space and sits after the word.',
    build: (normalized) => _rich([
      for (final run in TajweedText.splitIntoStyledRuns(normalized))
        TextSpan(
          text: run.text,
          style: run.isMarker
              ? _style(
                  family: _markerFamily,
                  color: _waqfColor,
                  fallback: const [_bodyFamily],
                )
              : _bodyStyle,
        ),
    ]),
  ),
  _Variant(
    id: 'B-in-run-uncoloured',
    title: 'B. In-run, uncoloured: one span, font does the stacking',
    summary:
        'A single shaping run, so GPOS mark/mkmk can position the sign '
        'relative to the letter and its harakah. No separate colour.',
    build: (normalized) => _rich([
      TextSpan(text: normalized, style: _bodyStyle),
    ]),
  ),
  _Variant(
    id: 'B2-in-run-no-separator',
    title: 'B2. In-run, uncoloured, separator removed (sign on the letter)',
    summary:
        'Same as B but with the space stripped, so the font is asked to stack '
        'the sign directly on the preceding letter.',
    build: (normalized) => _rich([
      TextSpan(text: _withoutSeparator(normalized), style: _bodyStyle),
    ]),
  ),
  _Variant(
    id: 'C0-prefix-zwnj-original-bug',
    title: 'C0. The reported bug: ZWNJ separator + differently-typefaced run',
    summary:
        'Exactly what shipped before e26841d: the raw ZWNJ payload, with the '
        'bare waqf given its own run in a second typeface.',
    build: (normalized) => _rich([
      for (final run in _splitAtWaqf(_withZwnjSeparator(normalized)))
        TextSpan(
          text: run.text,
          style: run.isWaqf
              ? _style(
                  family: _markerFamily,
                  color: _waqfColor,
                  fallback: const [_bodyFamily],
                )
              : _bodyStyle,
        ),
    ]),
  ),
  _Variant(
    id: 'C1-prefix-zwnj-in-run',
    title: 'C1. ZWNJ separator, single uncoloured run',
    summary:
        'The same pre-fix payload left in one shaping run. Isolates the ZWNJ '
        'itself from the run splitting.',
    build: (normalized) =>
        _rich([TextSpan(text: _withZwnjSeparator(normalized), style: _bodyStyle)]),
  ),
  _Variant(
    id: 'C2-prefix-zwnj-colour-only',
    title: 'C2. ZWNJ separator, colour-only split (same typeface)',
    summary:
        'Pre-fix payload with the waqf recoloured but not re-typefaced. Shows '
        'whether the typeface switch or the colour split caused the overlap.',
    build: (normalized) => _rich([
      for (final run in _splitAtWaqf(_withZwnjSeparator(normalized)))
        TextSpan(
          text: run.text,
          style: run.isWaqf
              ? _style(family: _bodyFamily, color: _waqfColor)
              : _bodyStyle,
        ),
    ]),
  ),
  _Variant(
    id: 'C-original-bug',
    title: 'C. Original bug: coloured run with no base glyph',
    summary:
        'Separator stripped and the bare combining mark given its own styled '
        'run. Zero advance width, so it is drawn at the run origin.',
    build: (normalized) => _rich([
      for (final run in _splitAtWaqf(_withoutSeparator(normalized)))
        TextSpan(
          text: run.text,
          style: run.isWaqf
              ? _style(
                  family: _markerFamily,
                  color: _waqfColor,
                  fallback: const [_bodyFamily],
                )
              : _bodyStyle,
        ),
    ]),
  ),
  _Variant(
    id: 'D0-colour-only-split-with-space',
    title: 'D0. Colour-only split, same font, space kept',
    summary:
        'Identical to A except the marker run keeps the body font. Tests '
        'whether a colour change alone forces a new shaping run.',
    build: (normalized) => _rich([
      for (final run in TajweedText.splitIntoStyledRuns(normalized))
        TextSpan(
          text: run.text,
          style: run.isMarker
              ? _bodyStyle.copyWith(color: _waqfColor)
              : _bodyStyle,
        ),
    ]),
  ),
  _Variant(
    id: 'D1-colour-only-split-no-space',
    title: 'D1. Colour-only split, same font, no separator',
    summary:
        'The sign is asked to stack on the letter while carrying its own '
        'colour. This is the arrangement the user is asking for.',
    build: (normalized) => _rich([
      for (final run in _splitAtWaqf(_withoutSeparator(normalized)))
        TextSpan(
          text: run.text,
          style: run.isWaqf
              ? _bodyStyle.copyWith(color: _waqfColor)
              : _bodyStyle,
        ),
    ]),
  ),
  _Variant(
    id: 'D2-stack-overlay',
    title: 'D2. Stacked layers: uncoloured shaping, coloured sign',
    summary:
        'Bottom layer paints the whole string in the waqf colour as one run. '
        'Top layer repaints it in the body colour with the sign deleted. The '
        'sign is nonspacing, so removing it shifts nothing and the coloured '
        'one shows through at the position the font chose.',
    build: (normalized) {
      final withoutSeparator = _withoutSeparator(normalized);
      return Stack(
        children: [
          _rich([
            TextSpan(
              text: withoutSeparator,
              style: _bodyStyle.copyWith(color: _waqfColor),
            ),
          ]),
          _rich([
            TextSpan(
              text: _withoutWaqf(withoutSeparator),
              style: _bodyStyle,
            ),
          ]),
        ],
      );
    },
  ),
  _Variant(
    id: 'D3-raised-coloured-run',
    title: 'D3. Coloured run lifted with a Transform inside a WidgetSpan',
    summary:
        'Separately coloured sign, manually translated up and back over the '
        'word. Placement is hand-tuned rather than font-driven.',
    build: (normalized) {
      final withoutSeparator = _withoutSeparator(normalized);
      final runs = _splitAtWaqf(withoutSeparator);
      return _rich([
        for (final run in runs)
          if (!run.isWaqf)
            TextSpan(text: run.text, style: _bodyStyle)
          else
            WidgetSpan(
              // A zero-width box has no baseline, so baseline alignment
              // resolves to NaN and layout asserts. Middle alignment avoids
              // needing one.
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                width: 0,
                height: _renderFontSize,
                child: OverflowBox(
                  maxWidth: _renderFontSize * 2,
                  maxHeight: _renderFontSize * 3,
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: const Offset(
                      _renderFontSize * 0.45,
                      -_renderFontSize * 0.70,
                    ),
                    child: Text(
                      run.text,
                      style: _bodyStyle.copyWith(
                        color: _waqfColor,
                        height: 1.0,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ),
              ),
            ),
      ]);
    },
  ),
];

Future<void> _loadFont(String family, [String? path]) async {
  final bytes = await File(path ?? 'assets/fonts/AmiriQuran.ttf').readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

/// [RenderRepaintBoundary.toImage] completes off the fake-async zone that
/// `testWidgets` installs, so awaiting it directly deadlocks the test. It has
/// to run through [WidgetTester.runAsync].
Future<void> _writePng(
  WidgetTester tester,
  Key key,
  String path,
) async {
  final boundary =
      tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(path)..parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// Where the shaper actually put each glyph, so the comparison rests on
/// measurements and not only on eyeballing the PNGs.
Map<String, dynamic>? _measure(String label, List<InlineSpan> spans) {
  // A bare TextPainter cannot lay out a placeholder without dimensions.
  if (spans.any((s) => s is WidgetSpan)) {
    return {
      'variant': label,
      'note': 'contains a WidgetSpan; position is hand-set, not font-derived',
    };
  }

  final painter = TextPainter(
    text: TextSpan(children: spans),
    textDirection: TextDirection.rtl,
  )..layout();

  final plain = painter.plainText;
  final waqfIndex = plain.codeUnits.indexWhere(_waqfRunes.contains);
  Map<String, dynamic>? waqfBox;
  Map<String, dynamic>? previousBox;

  if (waqfIndex >= 0) {
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: waqfIndex, extentOffset: waqfIndex + 1),
    );
    if (boxes.isNotEmpty) {
      waqfBox = {
        'left': boxes.first.left,
        'right': boxes.first.right,
        'top': boxes.first.top,
        'bottom': boxes.first.bottom,
      };
    }
    if (waqfIndex > 0) {
      final prev = painter.getBoxesForSelection(
        TextSelection(baseOffset: waqfIndex - 1, extentOffset: waqfIndex),
      );
      if (prev.isNotEmpty) {
        previousBox = {
          'left': prev.first.left,
          'right': prev.first.right,
          'top': prev.first.top,
          'bottom': prev.first.bottom,
        };
      }
    }
  }

  final result = <String, dynamic>{
    'variant': label,
    'paragraphWidth': painter.width,
    'paragraphHeight': painter.height,
    'waqfBox': waqfBox,
    'charBeforeWaqfBox': previousBox,
  };
  painter.dispose();
  return result;
}

void main() {
  setUpAll(() async {
    await _loadFont(_bodyFamily);
    await _loadFont(_markerFamily, _markerFontPath);
    if (File(_labelFontPath).existsSync()) {
      await _loadFont(_labelFamily, _labelFontPath);
    }
  });

  testWidgets('renders waqf placement variants', (tester) async {
    final report = <String, dynamic>{
      'font': 'assets/fonts/AmiriQuran.ttf',
      'fontSize': _renderFontSize,
      'samples': <Map<String, dynamic>>[],
    };

    for (final sample in _samples) {
      final normalized = sample.normalized;
      final sampleReport = <String, dynamic>{
        'id': sample.id,
        'verseKey': sample.verseKey,
        'textUthmani': sample.textUthmani,
        'normalized': normalized,
        'normalizedCodePoints': normalized.codeUnits
            .map((u) => 'U+${u.toRadixString(16).toUpperCase().padLeft(4, '0')}')
            .toList(),
        'variants': <Map<String, dynamic>>[],
      };

      for (final variant in _variants) {
        final key = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: Center(
                child: RepaintBoundary(
                  key: key,
                  child: Container(
                    color: _backgroundColor,
                    // Fixed box, anchored at the RTL start edge, so every
                    // variant of a sample renders at the same origin and the
                    // images can be compared pixel for pixel.
                    width: 900,
                    height: 260,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                    alignment: Alignment.centerRight,
                    child: variant.build(normalized),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await _writePng(
          tester,
          key,
          '$_outputDir/${sample.id}__${variant.id}.png',
        );

        final measurable = variant.build(normalized);
        if (measurable is Text) {
          final span = measurable.textSpan;
          if (span is TextSpan && span.children != null) {
            final measured = _measure(variant.id, span.children!);
            if (measured != null) sampleReport['variants'].add(measured);
          }
        } else {
          sampleReport['variants'].add({
            'variant': variant.id,
            'note': 'composite widget; measured visually only',
          });
        }
      }

      report['samples'].add(sampleReport);
    }

    File('$_outputDir/geometry.json')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(report),
      );

    expect(Directory(_outputDir).listSync().length, greaterThan(1));
  });

  testWidgets('renders a labelled comparison sheet per sample', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final sample in _samples) {
      final normalized = sample.normalized;
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: _backgroundColor,
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Waqf placement - ${sample.label}',
                      style: const TextStyle(
                        fontFamily: _labelFamily,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _bodyColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final variant in _variants) ...[
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDDDDDD)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              variant.title,
                              style: const TextStyle(
                                fontFamily: _labelFamily,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: variant.build(normalized),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await _writePng(tester, key, '$_outputDir/sheet__${sample.id}.png');
    }
  });
}
