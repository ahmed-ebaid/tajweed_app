import '../../core/constants/app_links.dart';
import 'tajweed_article.dart';
import '../../shared/utils/share_text.dart';

abstract final class TajweedArticleShareContent {
  static String build(TajweedArticle article, String languageCode) {
    final paragraphs = article.body(languageCode).split('\n\n');
    final sections = article.sections(languageCode);
    return [
      article.title(languageCode),
      '',
      ShareText.guidance(article.summary(languageCode)),
      '',
      for (var index = 0; index < paragraphs.length; index++) ...[
        if (index < sections.length) sections[index],
        ShareText.guidance(paragraphs[index]),
        '',
      ],
      '${AppLinks.productName}\n${AppLinks.appStore}',
    ].join('\n').trim();
  }
}
