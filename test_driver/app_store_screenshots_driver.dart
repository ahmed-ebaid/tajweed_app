import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputPath =
      Platform.environment['SCREENSHOT_OUTPUT_DIR'] ??
      'build/app-store-screenshots';
  final output = Directory(outputPath);
  await output.create(recursive: true);

  await integrationDriver(
    onScreenshot:
        (
          String name,
          List<int> bytes, [
          Map<String, Object?>? arguments,
        ]) async {
          final file = File('${output.path}/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
          return true;
        },
  );
}
