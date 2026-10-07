abstract final class ShareText {
  /// Use illustrative letters because receiving apps choose their own font.
  /// Never apply this to Quran quotations; those must retain their source text.
  static String guidance(String text) =>
      text.replaceAll('(۟)', '(و۟)').replaceAll('(ۡ)', '(بۡ)');
}
