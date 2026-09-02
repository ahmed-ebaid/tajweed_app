import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';

/// The ayah-by-ayah reader and the Mushaf page view both render the same
/// [TajweedText] widget fed by the same [AyahMapper] output; the only
/// difference is `compactFlow` (and font size). These tests pin that
/// invariant so a rule fixed in the mapper can never apply to one view only.
void main() {
  Ayah buildAyah() => AyahMapper.fromApi({
    'verse_key': '2:1',
    'words': [
      {
        'char_type_name': 'word',
        'text_uthmani': '\u0627\u0644\u0653\u0645\u0653',
        'text_uthmani_tajweed':
            '\u0627<rule class=madda_necessary>\u0644\u0653</rule>'
            '<rule class=madda_necessary>\u0645\u0653</rule>',
      },
    ],
  });

  Future<Set<int>> colorsFor(WidgetTester tester, {required bool compact}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TajweedText(
            ayah: buildAyah(),
            compactFlow: compact,
            fontSize: compact ? 22 : 26,
          ),
        ),
      ),
    );

    final colors = <int>{};
    // visitChildren already walks the whole subtree, including the root span.
    for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
      text.text.visitChildren((span) {
        final color = span.style?.color;
        if (color != null) colors.add(color.toARGB32());
        return true;
      });
    }
    return colors;
  }

  testWidgets('mushaf and ayah-by-ayah views highlight identically', (
    tester,
  ) async {
    final ayahByAyah = await colorsFor(tester, compact: false);
    final mushaf = await colorsFor(tester, compact: true);

    expect(ayahByAyah, isNotEmpty);
    expect(
      mushaf,
      equals(ayahByAyah),
      reason:
          'compactFlow only changes layout; it must never change which rules '
          'are coloured',
    );
  });

  testWidgets('both views show the two distinct madd lazim colours', (
    tester,
  ) async {
    final muthaqqal = TajweedRule.maddLazimHarfiMuthaqqal.color.toARGB32();
    final mukhaffaf = TajweedRule.maddLazimHarfiMukhaffaf.color.toARGB32();
    expect(muthaqqal, isNot(mukhaffaf));

    for (final compact in [false, true]) {
      final colors = await colorsFor(tester, compact: compact);
      expect(
        colors,
        containsAll([muthaqqal, mukhaffaf]),
        reason: 'compactFlow=$compact must render both madd lazim types',
      );
    }
  });
}
