import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/models/tajweed_models.dart';
import '../../core/providers/locale_provider.dart';
import 'rule_detail_screen.dart';
import 'rules_repository.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  String _search = '';
  TajweedRule? _filter;
  int? _expandedIndex;

  List<TajweedRuleDefinition> get _filtered {
    return RulesRepository.all.where((d) {
      if (_filter != null && d.rule != _filter) return false;
      if (_search.isEmpty) return true;
      final langCode = context.read<LocaleProvider>().locale.languageCode;
      final name = d.name(langCode).toLowerCase();
      final desc = d.description(langCode).toLowerCase();
      return name.contains(_search) || desc.contains(_search);
    }).toList();
  }

  List<_RuleGroup> _grouped(List<TajweedRuleDefinition> rules, String langCode) {
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
    final extras = buckets.keys.where((k) => !_categoryOrder.contains(k)).toList()
      ..sort();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final rules = _filtered;
    final groups = _grouped(rules, langCode);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rulesLibrary)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchRules,
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() { _search = v.toLowerCase(); _expandedIndex = null; }),
            ),
          ),
          const SizedBox(height: 10),
          _CategoryPills(
            selected: _filter,
            langCode: langCode,
            onSelect: (r) => setState(() { _filter = r; _expandedIndex = null; }),
          ),
          const Divider(height: 0.5),
          Expanded(
            child: rules.isEmpty
                ? Center(child: Text(l10n.get('all_rules'),
                    style: Theme.of(context).textTheme.bodyMedium))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const Divider(height: 0.5, indent: 16),
                    itemBuilder: (context, i) {
                      final group = groups[i];
                      return _RuleGroupSection(
                        group: group,
                        langCode: langCode,
                        l10n: l10n,
                        expandedIndex: _expandedIndex,
                        onToggle: (flatIndex) => setState(
                          () => _expandedIndex = _expandedIndex == flatIndex ? null : flatIndex,
                        ),
                        onOpenDetail: (definition) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RuleDetailScreen(definition: definition),
                          ),
                        ),
                        baseFlatIndex: groups
                            .take(i)
                            .fold<int>(0, (sum, g) => sum + g.rules.length),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPills extends StatelessWidget {
  final TajweedRule? selected;
  final String langCode;
  final void Function(TajweedRule?) onSelect;

  const _CategoryPills({required this.selected, required this.langCode, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _Pill(
            label: 'All',
            selected: selected == null,
            color: const Color(0xFF1D9E75),
            onTap: () => onSelect(null),
          ),
          ...RulesRepository.all.map((d) => _Pill(
            label: d.name(langCode),
            selected: selected == d.rule,
            color: d.rule.color,
            onTap: () => onSelect(selected == d.rule ? null : d.rule),
          )),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.selected, required this.color, required this.onTap});

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
            color: selected ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
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
    required this.definition, required this.langCode,
    required this.expanded, required this.onToggle,
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
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: definition.rule.color, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(definition.name(langCode),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(
                  definition.rule.arabicName,
                  style: const TextStyle(
                      fontFamily: 'UthmanicHafs', fontSize: 15),
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
          crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(definition.description(langCode),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
                if (definition.exampleArabic.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 6,
                    children: definition.exampleArabic.map((ex) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(ex,
                          style: TextStyle(
                              fontFamily: 'UthmanicHafs',
                              fontSize: 20,
                              color: definition.rule.color),
                          textDirection: TextDirection.rtl),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onOpenDetail,
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: Text(AppLocalizations.of(context).get('full_details')),
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
