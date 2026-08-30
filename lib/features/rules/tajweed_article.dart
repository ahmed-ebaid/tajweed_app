enum TajweedArticleCategory { fundamentals, miscellaneous }

class TajweedArticle {
  final String id;
  final TajweedArticleCategory category;
  final Map<String, String> titles;
  final Map<String, String> summaries;
  final Map<String, String> bodies;
  final Map<String, List<String>> sectionTitles;

  const TajweedArticle({
    required this.id,
    required this.category,
    required this.titles,
    required this.summaries,
    required this.bodies,
    this.sectionTitles = const {},
  });

  String title(String languageCode) =>
      titles[languageCode] ?? titles['en'] ?? '';

  String summary(String languageCode) =>
      summaries[languageCode] ?? summaries['en'] ?? '';

  String body(String languageCode) =>
      bodies[languageCode] ?? bodies['en'] ?? '';

  List<String> sections(String languageCode) =>
      sectionTitles[languageCode] ?? sectionTitles['en'] ?? const [];

  bool matches(String query, String languageCode) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return title(languageCode).toLowerCase().contains(normalized) ||
        summary(languageCode).toLowerCase().contains(normalized) ||
        body(languageCode).toLowerCase().contains(normalized) ||
        sections(
          languageCode,
        ).any((section) => section.toLowerCase().contains(normalized));
  }
}
