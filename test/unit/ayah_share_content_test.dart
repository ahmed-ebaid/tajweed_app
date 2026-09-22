import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/constants/app_links.dart';
import 'package:tajweed_practice/features/reader/ayah_share_content.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'Ayah share content includes the product name and $platform store link',
      () {
        debugDefaultTargetPlatformOverride = platform;
        final content = AyahShareContent.build(
          heading: 'Al-Fatihah 1:1',
          arabicText: 'بِسْمِ اللَّهِ',
          translation: 'In the Name of Allah',
        );

        expect(content, contains('Al-Fatihah 1:1'));
        expect(content, contains('بِسْمِ اللَّهِ'));
        expect(content, contains('In the Name of Allah'));
        expect(content, contains('\n${AppLinks.productName}\n'));
        final isAndroid = platform == TargetPlatform.android;
        expect(
          content,
          endsWith(isAndroid ? AppLinks.googlePlay : AppLinks.appStore),
        );
        expect(
          content,
          isNot(contains(isAndroid ? AppLinks.appStore : AppLinks.googlePlay)),
        );
      },
    );
  }
}
