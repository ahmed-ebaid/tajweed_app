abstract final class ShareText {
  /// Removes combining-mark notation from prose; Quran quotations stay intact.
  static String guidance(String text) =>
      text.replaceAll(RegExp(r'\s*\((?:و۟|بۡ|۟|ۡ)\)'), '');
}
