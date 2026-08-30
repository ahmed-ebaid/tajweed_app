import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/features/rules/tajweed_article.dart';
import 'package:tajweed_practice/features/rules/tajweed_articles_repository.dart';

void main() {
  test('educational library contains the requested lesson groups', () {
    final fundamentals = TajweedArticlesRepository.all
        .where(
          (article) => article.category == TajweedArticleCategory.fundamentals,
        )
        .toList();
    final miscellaneous = TajweedArticlesRepository.all
        .where(
          (article) => article.category == TajweedArticleCategory.miscellaneous,
        )
        .toList();

    expect(
      fundamentals.map((article) => article.id),
      containsAll(['tafkhim', 'tarqiq', 'waqf_ibtida']),
    );
    expect(
      miscellaneous.map((article) => article.id),
      containsAll([
        'recitation_etiquette',
        'istiadha_basmala',
        'qiraat_qurra',
        'hafs_distinctions',
      ]),
    );
  });

  test('every educational article is complete in all supported languages', () {
    for (final article in TajweedArticlesRepository.all) {
      for (final languageCode
          in TajweedArticlesRepository.supportedLanguageCodes) {
        expect(
          article.titles[languageCode]?.trim(),
          isNotEmpty,
          reason: '${article.id} title is missing in $languageCode',
        );
        expect(
          article.summaries[languageCode]?.trim(),
          isNotEmpty,
          reason: '${article.id} summary is missing in $languageCode',
        );
        expect(
          article.bodies[languageCode]?.trim(),
          isNotEmpty,
          reason: '${article.id} body is missing in $languageCode',
        );
      }
    }
  });

  test('tabs and Tafkhim/Tarqiq sections are localized in every language', () {
    final tafkheem = TajweedArticlesRepository.all.firstWhere(
      (article) => article.id == 'tafkhim',
    );
    final tarqiq = TajweedArticlesRepository.all.firstWhere(
      (article) => article.id == 'tarqiq',
    );

    for (final languageCode
        in TajweedArticlesRepository.supportedLanguageCodes) {
      final l10n = AppLocalizations(Locale(languageCode));
      expect(l10n.get('rules_tab_tajweed'), isNot('rules_tab_tajweed'));
      expect(l10n.get('rules_tab_more'), isNot('rules_tab_more'));
      expect(l10n.get('search_tajweed_topics'), isNot('search_tajweed_topics'));
      expect(
        tafkheem.sections(languageCode),
        hasLength(3),
        reason: 'Tafkheem section titles are incomplete in $languageCode',
      );
      expect(
        tarqiq.sections(languageCode),
        hasLength(3),
        reason: 'Tarqiq section titles are incomplete in $languageCode',
      );
    }
  });

  test('search matches localized titles and article content', () {
    expect(
      TajweedArticlesRepository.search('التفخيم', 'ar').single.id,
      'tafkhim',
    );
    expect(
      TajweedArticlesRepository.search('الترقيق', 'ar').single.id,
      'tarqiq',
    );
    expect(
      TajweedArticlesRepository.search(
        'four famous brief pauses',
        'en',
      ).single.id,
      'hafs_distinctions',
    );
    expect(
      TajweedArticlesRepository.search('besmele', 'tr').single.id,
      'istiadha_basmala',
    );
  });
}
