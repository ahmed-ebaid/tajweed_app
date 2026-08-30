import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/models/tajweed_models.dart';
import '../../core/providers/locale_provider.dart';
import 'rule_detail_screen.dart';
import 'rules_repository.dart';
import 'tajweed_article.dart';
import 'tajweed_article_detail_screen.dart';
import 'tajweed_articles_repository.dart';

enum _RulesLibraryTab { rules, more }

class RulesScreen extends StatefulWidget {
  final String? languageCodeOverride;

  const RulesScreen({super.key, this.languageCodeOverride});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  TajweedRule? _filter;
  int? _expandedIndex;
  _RulesLibraryTab _selectedTab = _RulesLibraryTab.rules;

  String get _languageCode =>
      widget.languageCodeOverride ??
      context.read<LocaleProvider>().locale.languageCode;

  List<TajweedRuleDefinition> get _filtered {
    if (_selectedTab != _RulesLibraryTab.rules) return const [];
    return RulesRepository.all.where((d) {
      if (_filter != null && d.rule != _filter) return false;
      if (_search.isEmpty) return true;
      final name = d.name(_languageCode).toLowerCase();
      final desc = d.description(_languageCode).toLowerCase();
      return name.contains(_search) || desc.contains(_search);
    }).toList();
  }

  List<TajweedArticle> get _filteredArticles {
    if (_filter != null) return const [];
    final category = _selectedTab == _RulesLibraryTab.rules
        ? TajweedArticleCategory.fundamentals
        : TajweedArticleCategory.miscellaneous;
    return TajweedArticlesRepository.search(
      _search,
      _languageCode,
    ).where((article) => article.category == category).toList();
  }

  List<_ArticleGroup> _groupedArticles(
    List<TajweedArticle> articles,
    String langCode,
  ) {
    return TajweedArticleCategory.values
        .map((category) {
          final matches =
              articles.where((article) => article.category == category).toList()
                ..sort(
                  (a, b) => a.title(langCode).compareTo(b.title(langCode)),
                );
          return _ArticleGroup(category: category, articles: matches);
        })
        .where((group) => group.articles.isNotEmpty)
        .toList();
  }

  List<_RuleGroup> _grouped(
    List<TajweedRuleDefinition> rules,
    String langCode,
  ) {
    final buckets = <String, List<TajweedRuleDefinition>>{};
    for (final r in rules) {
      final key = _categoryFor(r.rule);
      buckets.putIfAbsent(key, () => <TajweedRuleDefinition>[]).add(r);
    }

    final ordered = <_RuleGroup>[];
    for (final key in _categoryOrder) {
      final list = buckets[key];
      if (list == null || list.isEmpty) continue;
      list.sort((a, b) => a.name(langCode).compareTo(b.name(langCode)));
      ordered.add(_RuleGroup(title: key, rules: list));
    }

    // Keep any unexpected categories visible at the end.
    final extras =
        buckets.keys.where((k) => !_categoryOrder.contains(k)).toList()..sort();
    for (final key in extras) {
      final list = buckets[key]!;
      list.sort((a, b) => a.name(langCode).compareTo(b.name(langCode)));
      ordered.add(_RuleGroup(title: key, rules: list));
    }

    return ordered;
  }

  static const List<String> _categoryOrder = [
    'rules_category_madd',
    'rules_category_noon_meem',
    'rules_category_merging',
    'rules_category_stops_signs',
    'rules_category_orthographic',
  ];

  static String _categoryFor(TajweedRule rule) {
    switch (rule) {
      case TajweedRule.maddTabeei:
      case TajweedRule.maddMuttasil:
      case TajweedRule.maddMunfasil:
      case TajweedRule.maddLazim:
      case TajweedRule.maddSilahSughra:
      case TajweedRule.maddSilahKubra:
        return 'rules_category_madd';
      case TajweedRule.ghunnah:
      case TajweedRule.iqlab:
      case TajweedRule.izhar:
        return 'rules_category_noon_meem';
      case TajweedRule.idghamWithGhunnah:
      case TajweedRule.idghamWithoutGhunnah:
      case TajweedRule.idghamShafawi:
      case TajweedRule.idghamMutajanisayn:
      case TajweedRule.ikhfa:
      case TajweedRule.ikhfaShafawi:
      case TajweedRule.qalqalah:
      case TajweedRule.shaddah:
        return 'rules_category_merging';
      case TajweedRule.waqf:
      case TajweedRule.sajdah:
        return 'rules_category_stops_signs';
      case TajweedRule.hamzatWasl:
      case TajweedRule.laamShamsiyah:
      case TajweedRule.silent:
        return 'rules_category_orthographic';
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _search = '';
      _expandedIndex = null;
    });
  }

  void _selectTab(_RulesLibraryTab tab) {
    if (_selectedTab == tab) return;
    _searchController.clear();
    setState(() {
      _selectedTab = tab;
      _search = '';
      _filter = null;
      _expandedIndex = null;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = _languageCode;
    final rules = _filtered;
    final groups = _grouped(rules, langCode);
    final articleGroups = _groupedArticles(_filteredArticles, langCode);
    final sections = <Widget>[
      ...articleGroups.map(
        (group) => _ArticleGroupSection(
          group: group,
          languageCode: langCode,
          l10n: l10n,
          onOpen: (article) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TajweedArticleDetailScreen(
                article: article,
                languageCode: langCode,
              ),
            ),
          ),
        ),
      ),
      ...groups.indexed.map((entry) {
        final index = entry.$1;
        final group = entry.$2;
        return _RuleGroupSection(
          group: group,
          langCode: langCode,
          l10n: l10n,
          expandedIndex: _expandedIndex,
          onToggle: (flatIndex) => setState(
            () =>
                _expandedIndex = _expandedIndex == flatIndex ? null : flatIndex,
          ),
          onOpenDetail: (definition) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RuleDetailScreen(definition: definition),
            ),
          ),
          baseFlatIndex: groups
              .take(index)
              .fold<int>(0, (sum, item) => sum + item.rules.length),
        );
      }),
    ];

    return PopScope(
      canPop: _search.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _search.isNotEmpty) _clearSearch();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.rulesLibrary)),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _LibraryTabSelector(
                selected: _selectedTab,
                rulesLabel: l10n.get('rules_tab_tajweed'),
                moreLabel: l10n.get('rules_tab_more'),
                onSelect: _selectTab,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _selectedTab == _RulesLibraryTab.rules
                      ? l10n.searchRules
                      : l10n.get('search_tajweed_topics'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: _clearSearch,
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() {
                  _search = v.toLowerCase();
                  _expandedIndex = null;
                }),
              ),
            ),
            if (_selectedTab == _RulesLibraryTab.rules) ...[
              const SizedBox(height: 10),
              _CategoryPills(
                selected: _filter,
                langCode: langCode,
                allLabel: l10n.allRules,
                onSelect: (r) => setState(() {
                  _filter = r;
                  _expandedIndex = null;
                }),
              ),
            ] else
              const SizedBox(height: 10),
            const Divider(height: 0.5),
            Expanded(
              child: sections.isEmpty
                  ? Center(
                      child: Text(
                        l10n.get('all_rules'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sections.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 0.5, indent: 16),
                      itemBuilder: (_, index) => sections[index],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTabSelector extends StatelessWidget {
  final _RulesLibraryTab selected;
  final String rulesLabel;
  final String moreLabel;
  final ValueChanged<_RulesLibraryTab> onSelect;

  const _LibraryTabSelector({
    required this.selected,
    required this.rulesLabel,
    required this.moreLabel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LibraryTabButton(
              label: rulesLabel,
              selected: selected == _RulesLibraryTab.rules,
              onTap: () => onSelect(_RulesLibraryTab.rules),
            ),
          ),
          Expanded(
            child: _LibraryTabButton(
              label: moreLabel,
              selected: selected == _RulesLibraryTab.more,
              onTap: () => onSelect(_RulesLibraryTab.more),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LibraryTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPills extends StatelessWidget {
  final TajweedRule? selected;
  final String langCode;
  final String allLabel;
  final void Function(TajweedRule?) onSelect;

  const _CategoryPills({
    required this.selected,
    required this.langCode,
    required this.allLabel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _Pill(
            label: allLabel,
            selected: selected == null,
            color: const Color(0xFF1D9E75),
            onTap: () => onSelect(null),
          ),
          ...RulesRepository.all.map(
            (d) => _Pill(
              label: d.name(langCode),
              selected: selected == d.rule,
              color: d.rule.color,
              onTap: () => onSelect(selected == d.rule ? null : d.rule),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleGroup {
  final TajweedArticleCategory category;
  final List<TajweedArticle> articles;

  const _ArticleGroup({required this.category, required this.articles});
}

class _ArticleGroupSection extends StatelessWidget {
  final _ArticleGroup group;
  final String languageCode;
  final AppLocalizations l10n;
  final ValueChanged<TajweedArticle> onOpen;

  const _ArticleGroupSection({
    required this.group,
    required this.languageCode,
    required this.l10n,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final categoryKey = group.category == TajweedArticleCategory.fundamentals
        ? 'rules_category_fundamentals'
        : 'rules_category_miscellaneous';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            l10n.get(categoryKey),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...group.articles.map(
          (article) => _ArticleCard(
            article: article,
            languageCode: languageCode,
            onOpen: () => onOpen(article),
          ),
        ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final TajweedArticle article;
  final String languageCode;
  final VoidCallback onOpen;

  const _ArticleCard({
    required this.article,
    required this.languageCode,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final color = article.category == TajweedArticleCategory.fundamentals
        ? const Color(0xFF176B5B)
        : const Color(0xFF6A4C93);

    return ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(
          article.category == TajweedArticleCategory.fundamentals
              ? Icons.menu_book_rounded
              : Icons.auto_stories_rounded,
          size: 20,
        ),
      ),
      title: Text(
        article.title(languageCode),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          article.summary(languageCode),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
            color: selected
                ? Colors.white
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final TajweedRuleDefinition definition;
  final String langCode;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onOpenDetail;

  const _RuleCard({
    required this.definition,
    required this.langCode,
    required this.expanded,
    required this.onToggle,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          onLongPress: onOpenDetail,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: definition.rule.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    definition.name(langCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  definition.rule.arabicName,
                  style: const TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 15,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(width: 8),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.description(langCode),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
                if (definition.exampleArabic.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: definition.exampleArabic
                        .map(
                          (ex) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ex,
                              style: TextStyle(
                                fontFamily: 'UthmanicHafs',
                                fontSize: 20,
                                color: definition.rule.color,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onOpenDetail,
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: Text(
                      AppLocalizations.of(context).get('full_details'),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: definition.rule.color,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _RuleGroup {
  final String title;
  final List<TajweedRuleDefinition> rules;

  const _RuleGroup({required this.title, required this.rules});
}

class _RuleGroupSection extends StatelessWidget {
  final _RuleGroup group;
  final String langCode;
  final int? expandedIndex;
  final int baseFlatIndex;
  final ValueChanged<int> onToggle;
  final ValueChanged<TajweedRuleDefinition> onOpenDetail;
  final AppLocalizations l10n;

  const _RuleGroupSection({
    required this.group,
    required this.langCode,
    required this.expandedIndex,
    required this.baseFlatIndex,
    required this.onToggle,
    required this.onOpenDetail,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            l10n.get(group.title),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...List.generate(group.rules.length, (idx) {
          final definition = group.rules[idx];
          final flatIndex = baseFlatIndex + idx;
          return _RuleCard(
            definition: definition,
            langCode: langCode,
            expanded: expandedIndex == flatIndex,
            onToggle: () => onToggle(flatIndex),
            onOpenDetail: () => onOpenDetail(definition),
          );
        }),
      ],
    );
  }
}
