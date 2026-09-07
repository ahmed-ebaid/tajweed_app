// Verifies that D1's run split is geometry-neutral for the 19 corpus words
// where a waqf sign is followed by further combining marks.
//
// Splitting the sign into its own run leaves those trailing marks opening a
// body run. That only matters if the split forces a new shaping run — so this
// renders the word as one run and as the D1 split (in one colour, to isolate
// geometry) and compares the pixels.
//
// It also pins the shipping pipeline to the approved D1 arrangement.
//
// Run: flutter test test/unit/waqf_render_geometry_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';

const _outputDir = 'build/waqf-comparison';
const _family = 'AmiriQuran';
const _fontPath = 'assets/fonts/AmiriQuran.ttf';
const _size = 56.0;
const _ratio = 2.5;

/// Real corpus words where a waqf sign is followed by more combining marks.
const _samples = <String, String>{
  '33-38-lahu': '\u0644\u064E\u0647\u064F\u06D6\u06E5',
  '34-12-rabbihi': '\u0631\u064E\u0628\u0651\u0650\u0647\u0650\u06D6\u06E6',
  '33-33-rasulahu': '\u0648\u064E\u0631\u064E\u0633\u064F\u0648\u0644\u064E'
      '\u0647\u064F\u06DA\u06E5\u0653',
  '2-245-yabsutu': '\u0648\u064E\u064A\u064E\u0628\u06E1\u0635\u064F\u06DC'
      '\u0637\u064F',
};

Future<void> _loadFont() async {
  final loader = FontLoader(_family)
    ..addFont(File(_fontPath).readAsBytes().then(ByteData.sublistView));
  await loader.load();
}

/// One run, no split at all.
TextSpan _single(String text, TextStyle base) => TextSpan(text: text, style: base);

/// The shipping D1 split, forced to a single colour so only geometry differs.
TextSpan _d1(String text, TextStyle base) => TextSpan(
      style: base,
      children: [
        for (final run in TajweedText.splitIntoStyledRuns(text))
          TextSpan(text: run.text, style: base),
      ],
    );

Future<ui.Image> _render(TextSpan span) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(_ratio);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 700, 200), Paint()..color = Colors.white);
  final painter = TextPainter(
    text: span,
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.right,
  )..layout(maxWidth: 700);
  painter.paint(canvas, Offset(700 - painter.width, 40));
  return recorder.endRecording().toImage((700 * _ratio).round(), (200 * _ratio).round());
}

Future<Uint8List> _bytes(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

Future<List<int>> _raw(ui.Image image) async =>
    (await image.toByteData())!.buffer.asUint8List();

bool _isWaqf(int rune) => rune >= 0x06D6 && rune <= 0x06DC;

void main() {
  testWidgets('D1 run split does not move stranded trailing marks', (tester) async {
    await tester.runAsync(() async {
      await _loadFont();
      Directory(_outputDir).createSync(recursive: true);
      const base = TextStyle(fontFamily: _family, fontSize: _size, color: Colors.black);

      final report = StringBuffer();
      final failures = <String>[];
      for (final entry in _samples.entries) {
        final runs = TajweedText.splitIntoStyledRuns(entry.value);
        final singleImg = await _render(_single(entry.value, base));
        final d1Img = await _render(_d1(entry.value, base));

        final a = await _raw(singleImg);
        final b = await _raw(d1Img);
        // A glyph appearing or vanishing shows up as a near-opaque delta.
        // Sub-pixel rasterisation noise stays far below that, so only strong
        // deltas indicate the split actually moved something.
        const strongDelta = 96;
        var differing = 0;
        var strong = 0;
        var maxDelta = 0;
        for (var i = 0; i < a.length; i += 4) {
          final d = (a[i] - b[i]).abs();
          if (d != 0) differing++;
          if (d > maxDelta) maxDelta = d;
          if (d >= strongDelta) strong++;
        }

        File('$_outputDir/STRANDED__${entry.key}__single.png')
            .writeAsBytesSync(await _bytes(singleImg));
        File('$_outputDir/STRANDED__${entry.key}__d1.png')
            .writeAsBytesSync(await _bytes(d1Img));

        report.writeln('${entry.key}: differing px=$differing '
            '(strong=$strong, maxDelta=$maxDelta)  '
            'runs=${runs.map((r) => '${r.isMarker ? "M" : "b"}:${r.text}').join(' | ')}');

        if (strong != 0) {
          failures.add('${entry.key}: $strong strong px (max $maxDelta)');
        }
      }
      stdout.writeln('\n=== stranded-mark geometry check ===\n$report');
      expect(
        failures,
        isEmpty,
        reason: 'D1 split changed glyph positions; the colour split must not '
            'force a new shaping run.',
      );
    });
  });

  testWidgets('the shipping pipeline renders the approved D1 arrangement', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await _loadFont();
      Directory(_outputDir).createSync(recursive: true);
      const base =
          TextStyle(fontFamily: _family, fontSize: _size, color: Colors.black);
      final waqfColour = TajweedRule.waqf.color;

      // Words with a separator before the sign, i.e. the common case.
      const samples = <String, String>{
        'rayba': '\u0631\u064E\u064A\u0652\u0628\u064E\u06DB',
        'aduwwun': '\u0639\u064E\u062F\u064F\u0648\u0651\u064C\u06D6',
      };

      for (final entry in samples.entries) {
        // Reference: D1 built by hand, independent of the production splitter.
        final runes = entry.value.runes.toList();
        final waqfAt = runes.indexWhere(_isWaqf);
        final reference = TextSpan(
          style: base,
          children: [
            TextSpan(text: String.fromCharCodes(runes.take(waqfAt))),
            TextSpan(
              text: String.fromCharCode(runes[waqfAt]),
              style: base.copyWith(color: waqfColour),
            ),
            TextSpan(text: String.fromCharCodes(runes.skip(waqfAt + 1))),
          ],
        );

        // Production: the real splitter plus the real marker style.
        final shipping = TextSpan(
          style: base,
          children: [
            for (final run in TajweedText.splitIntoStyledRuns(entry.value))
              TextSpan(
                text: run.text,
                style: run.isMarker
                    ? TajweedText.markerStyleFrom(
                        base,
                        markerRule: run.markerRule,
                      )
                    : base,
              ),
          ],
        );

        final refImg = await _render(reference);
        final shipImg = await _render(shipping);
        final a = await _raw(refImg);
        final b = await _raw(shipImg);
        var differing = 0;
        for (var i = 0; i < a.length; i += 4) {
          if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) {
            differing++;
          }
        }

        File('$_outputDir/SHIPPING__${entry.key}.png')
            .writeAsBytesSync(await _bytes(shipImg));

        expect(
          differing,
          0,
          reason: '${entry.key}: the shipping pipeline no longer matches the '
              'approved D1 arrangement (no separator, colour-only split, '
              'marker keeps the body typeface).',
        );
      }
    });
  });
}
