import '../../core/constants/app_links.dart';
import 'tajweed_article.dart';

abstract final class TajweedArticleShareContent {
  static String build(TajweedArticle article, String languageCode) {
    final paragraphs = article.body(languageCode).split('\n\n');
    final sections = article.sections(languageCode);
    return [
      article.title(languageCode),
      '',
      article.summary(languageCode),
      '',
      for (var index = 0; index < paragraphs.length; index++) ...[
        if (index < sections.length) sections[index],
        paragraphs[index],
        '',
      ],
      '${AppLinks.productName}\n${AppLinks.appStore}',
    ].join('\n').trim();
  }
}
