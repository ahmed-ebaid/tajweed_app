import '../../core/constants/app_links.dart';

abstract final class AyahShareContent {
  static String build({
    required String heading,
    required String arabicText,
    required String translation,
  }) {
    return [
      heading,
      if (arabicText.isNotEmpty) '',
      if (arabicText.isNotEmpty) arabicText,
      if (translation.isNotEmpty) '',
      if (translation.isNotEmpty) translation,
      '',
      AppLinks.productName,
      AppLinks.appStore,
    ].join('\n');
  }
}
