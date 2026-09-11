import 'dart:io' show Platform;

abstract final class AppLinks {
  static const productName = 'Tajweed Practice';
  static const appStore = 'https://apps.apple.com/app/id6794283460';
  static const playStore =
      'https://play.google.com/store/apps/details?id=com.ebaidllc.tajweed_practice';

  /// Store link for the platform the app is running on.
  ///
  /// A shared message is read on someone else's device, so this can only be a
  /// guess, but the sender's platform is the better one: an Android user is
  /// more likely to be sharing with another Android user than the App Store
  /// link this used to always emit.
  static String get storeListing =>
      Platform.isAndroid ? playStore : appStore;
}
