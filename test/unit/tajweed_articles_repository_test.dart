import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/features/rules/rule_example_references.dart';
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
      containsAll(['tafkhim', 'tarqiq', 'madd_al_farq', 'waqf_ibtida']),
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
    expect(
      TajweedArticlesRepository.search('مد الفرق', 'ar').single.id,
      'madd_al_farq',
    );
    expect(
      TajweedArticlesRepository.search('al-Farq', 'en').single.id,
      'madd_al_farq',
    );
  });

  // The article detail screen zips section titles, body paragraphs, example
  // ayat and captions by index, so a mismatch in any one of them silently
  // drops or misaligns content instead of failing loudly.
  test('article examples stay aligned with captions and highlights', () {
    for (final entry in RuleExampleReferences.articleExampleCodes.entries) {
      final articleId = entry.key;
      final codes = entry.value;

      final article = TajweedArticlesRepository.all
          .where((candidate) => candidate.id == articleId)
          .toList();
      expect(
        article,
        hasLength(1),
        reason: '$articleId has examples but no matching article',
      );

      expect(
        RuleExampleReferences.referencesForArticle(articleId),
        hasLength(codes.length),
        reason: '$articleId has an ayah code that does not parse',
      );

      final captions = RuleExampleReferences.articleExampleCaptions[articleId];
      expect(captions, isNotNull, reason: '$articleId has no captions');

      for (final languageCode
          in TajweedArticlesRepository.supportedLanguageCodes) {
        expect(
          captions![languageCode],
          hasLength(codes.length),
          reason: '$articleId captions are wrong in $languageCode',
        );
        expect(
          article.single.sections(languageCode),
          hasLength(codes.length),
          reason: '$articleId section titles are wrong in $languageCode',
        );
        expect(
          article.single.bodies[languageCode]!.split('\n\n'),
          hasLength(codes.length),
          reason: '$articleId body paragraphs are wrong in $languageCode',
        );
      }

      final highlights =
          RuleExampleReferences.articleHighlightWords[articleId];
      if (highlights != null) {
        expect(
          highlights,
          hasLength(codes.length),
          reason: '$articleId highlight rows do not match example count',
        );
      }
    }
  });

  test('madd al-farq points at the six Quranic places it actually occurs', () {
    final article = TajweedArticlesRepository.all.firstWhere(
      (candidate) => candidate.id == 'madd_al_farq',
    );
    expect(article.category, TajweedArticleCategory.fundamentals);

    final refs = RuleExampleReferences.referencesForArticle('madd_al_farq');
    expect(refs, hasLength(3));
    // One muthaqqal the reader is most likely to meet, then one of each type.
    expect((refs[0].surah, refs[0].ayah), (27, 59));
    expect((refs[1].surah, refs[1].ayah), (6, 143));
    expect((refs[2].surah, refs[2].ayah), (10, 91));

    // The highlighted word must be the one carrying the madd, not the verse.
    expect(RuleExampleReferences.highlightWordsForExample('madd_al_farq', 0), [
      'ءَآللَّهُ',
    ]);
    expect(RuleExampleReferences.highlightWordsForExample('madd_al_farq', 1), [
      'ءَآلذَّكَرَيۡنِ',
    ]);
    expect(RuleExampleReferences.highlightWordsForExample('madd_al_farq', 2), [
      'ءَآلۡـَٔـٰنَ',
    ]);
  });
}
