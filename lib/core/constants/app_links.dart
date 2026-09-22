import 'package:flutter/foundation.dart';

abstract final class AppLinks {
  static const productName = 'Tajweed Practice';
  static const appStore = 'https://apps.apple.com/app/id6794283460';
  static const googlePlay =
      'https://play.google.com/store/apps/details?id=com.ebaidllc.tajweed_practice';

  static String get store =>
      defaultTargetPlatform == TargetPlatform.android ? googlePlay : appStore;
}
