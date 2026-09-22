import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/shared/widgets/platform_share_icon.dart';

void main() {
  for (final platform in TargetPlatform.values) {
    testWidgets('Share icon follows the $platform theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: const Scaffold(body: PlatformShareIcon()),
        ),
      );

      final isApple =
          platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
      expect(
        find.byIcon(isApple ? CupertinoIcons.share : Icons.share_rounded),
        findsOneWidget,
      );
      expect(tester.widget<Icon>(find.byType(Icon)).size, 22);
    });
  }
}
