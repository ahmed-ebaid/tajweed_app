// Renders surah 26 ayah 31 under three ikhfa colouring policies so the
// whole-word-coloured "kunta" question can be decided from pixels.
//
// All three variants are driven by real AyahMapper spans; only the colour
// policy differs. Not collected by `flutter test` (lives outside test/).
//
// Run: flutter test tool/ikhfa_colour_comparison_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';

const _outputDir = 'build/ikhfa-comparison';
const _family = 'AmiriQuran';
const _fontPath = 'assets/fonts/AmiriQuran.ttf';
const _size = 46.0;
const _ratio = 2.0;
const _width = 900.0;
const _lineHeight = 120.0;

const _nun = 0x0646;
const _tanween = {0x064B, 0x064C, 0x064D};
const _ikhfaColour = Color(0xFF8E4A75);
final _lightIkhfa = Color.lerp(_ikhfaColour, Colors.white, 0.55)!;

const _words = <Map<String, dynamic>>[
    {'char_type_name': 'word', 'text_uthmani': '\u0642\u064e\u0627\u0644\u064e', 'text_uthmani_tajweed': '\u0642\u064e\u0627\u0644\u064e'},
    {'char_type_name': 'word', 'text_uthmani': '\u0641\u064e\u0623\u0652\u062a\u0650', 'text_uthmani_tajweed': '\u0641\u064e\u0623\u06e1\u062a\u0650'},
    {'char_type_name': 'word', 'text_uthmani': '\u0628\u0650\u0647\u0650\u06e6\u0653', 'text_uthmani_tajweed': '\u0628\u0650\u0647<rule class=madda_obligatory_monfasel>\u0650\u06e6\u0653</rule>'},
    {'char_type_name': 'word', 'text_uthmani': '\u0625\u0650\u0646', 'text_uthmani_tajweed': '\u0625\u0650<rule class=ikhafa>\u0646</rule>'},
    {'char_type_name': 'word', 'text_uthmani': '\u0643\u064f\u0646\u062a\u064e', 'text_uthmani_tajweed': '<rule class=ikhafa>\u0643</rule>\u064f<rule class=ikhafa>\u0646\u062a</rule>\u064e'},
    {'char_type_name': 'word', 'text_uthmani': '\u0645\u0650\u0646\u064e', 'text_uthmani_tajweed': '\u0645\u0650\u0646\u064e'},
    {'char_type_name': 'word', 'text_uthmani': '\u0671\u0644\u0635\u0651\u064e\u0640\u0670\u062f\u0650\u0642\u0650\u064a\u0646\u064e', 'text_uthmani_tajweed': '<rule class=ham_wasl>\u0671</rule><rule class=laam_shamsiyah>\u0644</rule>\u0635\u0651\u064e<rule class=madda_normal>\u0640\u0670</rule>\u062f\u0650\u0642<rule class=madda_permissible>\u0650\u064a</rule>\u0646\u064e'},
];

const _labelFamily = 'Label';
const _labelFontPath = '/System/Library/Fonts/Supplemental/Arial.ttf';

Future<void> _loadFont() async {
  final loader = FontLoader(_family)
    ..addFont(File(_fontPath).readAsBytes().then(ByteData.sublistView));
  await loader.load();
  // flutter_tester runs with --disable-asset-fonts, so Latin labels render as
  // tofu unless a real face is registered from disk.
  final labels = FontLoader(_labelFamily)
    ..addFont(File(_labelFontPath).readAsBytes().then(ByteData.sublistView));
  await labels.load();
}

bool _isMark(int r) =>
    (r >= 0x064B && r <= 0x065F) || r == 0x0670 || (r >= 0x06D6 && r <= 0x06ED);

/// Splits a span's text into (baseLetter + its trailing marks) clusters.
List<String> _clusters(String text) {
  final out = <String>[];
  for (final rune in text.runes) {
    if (out.isNotEmpty && _isMark(rune)) {
      out[out.length - 1] += String.fromCharCode(rune);
    } else {
      out.add(String.fromCharCode(rune));
    }
  }
  return out;
}

bool _isCarrier(String cluster) =>
    cluster.runes.first == _nun ||
    cluster.runes.any((r) => _tanween.contains(r));

enum _Variant { shipping, carrierOnly, lightTrigger }

/// Emits the runs for one ikhfa span under the given policy.
List<TextSpan> _ikhfaRuns(String text, _Variant v, TextStyle base) {
  if (v == _Variant.shipping) {
    return [TextSpan(text: text, style: base.copyWith(color: _ikhfaColour))];
  }
  return [
    for (final c in _clusters(text))
      TextSpan(
        text: c,
        style: base.copyWith(
          color: _isCarrier(c)
              ? _ikhfaColour
              : (v == _Variant.carrierOnly ? base.color : _lightIkhfa),
        ),
      ),
  ];
}

TextSpan _build(Ayah ayah, _Variant v, TextStyle base, {int? from, int? to}) {
  final children = <InlineSpan>[];
  final lo = from ?? 0;
  final hi = to ?? ayah.words.length;
  for (var i = lo; i < hi; i++) {
    final word = ayah.words[i];
    final sorted = [...word.spans]..sort((a, b) => a.start.compareTo(b.start));
    var cursor = 0;
    for (final span in sorted) {
      if (span.start < cursor || span.end <= span.start) continue;
      if (cursor < span.start) {
        children.add(
          TextSpan(text: word.arabic.substring(cursor, span.start), style: base),
        );
      }
      final text = word.arabic.substring(span.start, span.end);
      if (span.rule == TajweedRule.ikhfa) {
        children.addAll(_ikhfaRuns(text, v, base));
      } else {
        children.add(
          TextSpan(text: text, style: base.copyWith(color: span.rule.color)),
        );
      }
      cursor = span.end;
    }
    if (cursor < word.arabic.length) {
      children.add(TextSpan(text: word.arabic.substring(cursor), style: base));
    }
    if (i != hi - 1) {
      children.add(TextSpan(text: ' ', style: base));
    }
  }
  return TextSpan(style: base, children: children);
}

Future<ui.Image> _render(
  List<TextSpan> spans,
  List<String> labels, {
  double lineHeight = _lineHeight,
  double width = _width,
}) async {
  final height = lineHeight * spans.length + 70;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_ratio);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = Colors.white,
  );
  for (var i = 0; i < spans.length; i++) {
    final label = TextPainter(
      text: TextSpan(
        text: labels[i],
        style: const TextStyle(
          fontFamily: _labelFamily,
          fontSize: 13,
          color: Colors.black54,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(12, i * lineHeight + 10));

    final painter = TextPainter(
      text: spans[i],
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
    )..layout(maxWidth: width - 24);
    painter.paint(
      canvas,
      Offset(width - 16 - painter.width, i * lineHeight + 30),
    );
  }
  return recorder.endRecording().toImage(
    (width * _ratio).round(),
    (height * _ratio).round(),
  );
}

void main() {
  testWidgets('render ikhfa colouring options for 26:31', (tester) async {
    await tester.runAsync(() async {
      await _loadFont();
      Directory(_outputDir).createSync(recursive: true);

      final ayah = AyahMapper.fromApi({
        'verse_key': '26:31',
        'page_number': 368,
        'text_uthmani': _words.map((w) => w['text_uthmani']).join(' '),
        'words': _words,
      });

      // Report the spans the mapper actually produced.
      for (final w in ayah.words) {
        for (final s in w.spans) {
          if (s.rule != TajweedRule.ikhfa) continue;
          debugPrint('IKHFA "${w.arabic}" [${s.start},${s.end}) = '
              '"${w.arabic.substring(s.start, s.end)}"');
        }
      }

      const base = TextStyle(
        fontFamily: _family,
        fontSize: _size,
        color: Color(0xFF1A1A1A),
      );

      const labels = [
        'A  SHIPPING - carrier + trigger both full colour (whole KUNTA coloured)',
        'B  CARRIER ONLY - trigger letters left black',
        'C  LIGHT TRIGGER - carrier full colour, trigger lightened',
      ];
      final variants = [
        _Variant.shipping,
        _Variant.carrierOnly,
        _Variant.lightTrigger,
      ];

      final all = <TextSpan>[];
      for (var i = 0; i < variants.length; i++) {
        final span = _build(ayah, variants[i], base);
        all.add(span);
        final img = await _render([span], [labels[i]]);
        final bytes =
            (await img.toByteData(format: ui.ImageByteFormat.png))!
                .buffer
                .asUint8List();
        File('$_outputDir/${String.fromCharCode(65 + i)}.png')
            .writeAsBytesSync(bytes);
      }

      final sheet = await _render(all, labels);
      final sheetBytes =
          (await sheet.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();
      File('$_outputDir/COMPARE.png').writeAsBytesSync(sheetBytes);
      debugPrint('Wrote $_outputDir/COMPARE.png');

      // Zoomed crop of just the two words in question, so the difference is
      // unambiguous at a glance.
      const zoomBase = TextStyle(
        fontFamily: _family,
        fontSize: 110,
        color: Color(0xFF1A1A1A),
      );
      const zoomLabels = [
        'A  SHIPPING  - whole KUNTA coloured',
        'B  CARRIER ONLY  - only the noon coloured',
        'C  LIGHT TRIGGER  - noon full, trigger lightened',
      ];
      final zoomSpans = [
        for (final v in variants) _build(ayah, v, zoomBase, from: 3, to: 5),
      ];
      final zoom = await _render(
        zoomSpans,
        zoomLabels,
        lineHeight: 185,
        width: 560,
      );
      final zoomBytes =
          (await zoom.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();
      File('$_outputDir/ZOOM.png').writeAsBytesSync(zoomBytes);
      debugPrint('Wrote $_outputDir/ZOOM.png');
    });
  });
}
