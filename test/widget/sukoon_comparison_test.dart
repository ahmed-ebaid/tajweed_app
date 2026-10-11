import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/features/rules/widgets/sukoon_comparison.dart';

void main() {
  testWidgets(
    'reader font keeps small-head sukoon distinct from rounded zero',
    (tester) async {
      await tester.runAsync(() async {
        final loader = FontLoader('AmiriQuran')
          ..addFont(rootBundle.load('assets/fonts/AmiriQuran.ttf'));
        await loader.load();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(Colors.white, BlendMode.src);
        for (final size in [19.0, 28.0, 36.0]) {
          final masks = <List<int>>[];
          for (final mark in ['\u06E1', '\u06DF', '\u0652']) {
            final span = TextSpan(
              text: 'ب$mark',
              style: TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: size,
                color: Colors.black,
                height: 2,
              ),
            );
            final painter = TextPainter(
              text: span,
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
            )..layout(minWidth: 80, maxWidth: 80);
            final sampleRecorder = ui.PictureRecorder();
            painter.paint(Canvas(sampleRecorder), const Offset(0, 20));
            final picture = sampleRecorder.endRecording();
            final image = await picture.toImage(100, 120);
            final bytes = (await image.toByteData())!.buffer.asUint8List();
            masks.add([
              for (var i = 3; i < bytes.length; i += 4) bytes[i] > 0 ? 1 : 0,
            ]);
            painter.paint(
              canvas,
              Offset(20 + (masks.length - 1) * 100, 20 + (size - 19) * 12),
            );
            image.dispose();
            picture.dispose();
            painter.dispose();
          }
          expect(masks[0], isNot(equals(masks[1])), reason: 'size $size');
          expect(masks[0].where((pixel) => pixel == 1), isNotEmpty);
          expect(masks[1].where((pixel) => pixel == 1), isNotEmpty);
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(330, 350);
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await Directory('build/sukoon-comparison').create(recursive: true);
        await File(
          'build/sukoon-comparison/reader-marks.png',
        ).writeAsBytes(png.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
    },
  );

  testWidgets('comparison fits narrow screens in every locale at large scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in SukoonComparison.labels.keys) {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: Directionality(
                textDirection: ['ar', 'ur'].contains(locale)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: SukoonComparison(languageCode: locale),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$locale $brightness');
        for (final sample in SukoonComparison.samples) {
          expect(find.text(sample), findsOneWidget);
        }
        expect(
          RulesRepository.findByRule(TajweedRule.silent)!.descriptions[locale],
          contains('بْ'),
        );
      }
    }
  });
}
