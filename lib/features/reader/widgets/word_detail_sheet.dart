import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/tajweed_models.dart';
import '../../../core/providers/locale_provider.dart';
import '../../rules/rules_repository.dart';
import 'tajweed_text.dart';
import '../../rules/widgets/rule_example_text.dart';

const _tanweenRules = {
  TajweedRule.idghamWithGhunnah,
  TajweedRule.idghamWithoutGhunnah,
  TajweedRule.ikhfa,
  TajweedRule.iqlab,
  TajweedRule.izhar,
};

bool _isWordBoundaryFormattingRune(int rune) =>
    rune == 0x0020 ||
    rune == 0x0640 ||
    rune == 0x0670 ||
    rune == 0x0653 ||
    rune == 0x200C ||
    (rune >= 0x064B && rune <= 0x065F) ||
    (rune >= 0x06D6 && rune <= 0x06ED);

bool _onlyWordBoundaryFormatting(String text) =>
    text.runes.every(_isWordBoundaryFormattingRune);

bool _hasRuleAtWordEdge(
  TajweedWord word,
  TajweedRule rule, {
  required bool leading,
}) => word.spans.any((span) {
  if (span.rule != rule) return false;
  final remainder = leading
      ? word.arabic.substring(0, span.start)
      : word.arabic.substring(span.end);
  if (leading) return _onlyWordBoundaryFormatting(remainder);
  final spanText = word.arabic.substring(span.start, span.end);
  final hasTanween = spanText.runes.any(
    (rune) => rune >= 0x064B && rune <= 0x064D,
  );
  return remainder.runes.every(
    (rune) =>
        _isWordBoundaryFormattingRune(rune) ||
        (_tanweenRules.contains(rule) &&
            hasTanween &&
            (rune == 0x0627 || rune == 0x0649)),
  );
});

bool _startsWithHamza(TajweedWord word) {
  for (final rune in word.arabic.runes) {
    if (_isWordBoundaryFormattingRune(rune)) continue;
    return const {0x0621, 0x0623, 0x0625, 0x0624, 0x0626}.contains(rune);
  }
  return false;
}

bool _spansWordBoundary(
  TajweedWord previous,
  TajweedWord next,
  TajweedRule rule,
) {
  if (!_hasRuleAtWordEdge(previous, rule, leading: false)) return false;
  if (_hasRuleAtWordEdge(next, rule, leading: true)) return true;
  return rule == TajweedRule.maddMunfasil && _startsWithHamza(next);
}

List<TajweedWord> _wordDetailContext(
  Ayah? ayah,
  TajweedWord selectedWord,
  TajweedRule rule,
) {
  if (ayah == null || ayah.words.length < 2) return [selectedWord];
  var selectedIndex = ayah.words.indexWhere(
    (word) => identical(word, selectedWord),
  );
  if (selectedIndex < 0) {
    selectedIndex = ayah.words.indexWhere(
      (word) =>
          word.arabic == selectedWord.arabic &&
          word.spans.length == selectedWord.spans.length &&
          Iterable<int>.generate(word.spans.length).every((index) {
            final left = word.spans[index];
            final right = selectedWord.spans[index];
            return left.start == right.start &&
                left.end == right.end &&
                left.rule == right.rule;
          }),
    );
  }
  if (selectedIndex < 0) return [selectedWord];

  var first = selectedIndex;
  while (first > 0 &&
      _spansWordBoundary(ayah.words[first - 1], ayah.words[first], rule)) {
    first--;
  }
  var last = selectedIndex;
  while (last < ayah.words.length - 1 &&
      _spansWordBoundary(ayah.words[last], ayah.words[last + 1], rule)) {
    last++;
  }
  return ayah.words.sublist(first, last + 1);
}

class WordDetailSheet extends StatefulWidget {
  final TajweedRule rule;
  final TajweedWord word;
  final Ayah? ayah;
  final String? wordAudioUrl;
  final String? ayahAudioUrl;

  const WordDetailSheet({
    super.key,
    required this.rule,
    required this.word,
    this.ayah,
    this.wordAudioUrl,
    this.ayahAudioUrl,
  });

  @override
  State<WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends State<WordDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final definition = RulesRepository.findByRule(widget.rule);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text.rich(
                  key: const Key('word_detail_header'),
                  TextSpan(children: _buildWordHeader(context)),
                  textDirection: TextDirection.rtl,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.rule.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      definition?.name(langCode) ?? widget.rule.arabicName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.rule.arabicName,
                      style: TextStyle(
                        fontFamily: 'UthmanicHafs',
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.ayah != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.rule.color.withValues(alpha: 0.24),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${l10n.get('ayah')} ${widget.ayah!.surahNumber}:${widget.ayah!.ayahNumber}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      TajweedText(
                        ayah: widget.ayah!,
                        fontSize: 28,
                        lineHeight: 2.0,
                        focusedRule: widget.rule,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (definition != null)
                Text(
                  definition.description(langCode),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              if (definition != null &&
                  definition.exampleArabic.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.get('examples'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: definition.exampleArabic
                      .asMap()
                      .entries
                      .map(
                        (entry) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: widget.rule.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.rule.color.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: RuleExampleText(
                            rule: widget.rule,
                            text: entry.value,
                            exampleIndex: entry.key,
                            fontSize: 20,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(widget.rule),
                  icon: const Icon(Icons.library_books_outlined, size: 18),
                  label: Text(l10n.get('full_details_in_rules_library')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.rule.color,
                    side: BorderSide(
                      color: widget.rule.color.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildWordHeader(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: 'UthmanicHafs',
      fontSize: 36,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final suppressedRules = TajweedRule.values
        .where((rule) => rule != widget.rule)
        .toSet();
    final words = _wordDetailContext(widget.ayah, widget.word, widget.rule);
    return [
      for (var index = 0; index < words.length; index++) ...[
        if (index > 0) TextSpan(text: ' ', style: baseStyle),
        ...TajweedText.buildStyledWordSpans(
          words[index],
          baseStyle: baseStyle,
          suppressedRules: suppressedRules,
        ),
      ],
    ];
  }
}
