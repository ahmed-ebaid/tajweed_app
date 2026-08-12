import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_links.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/models/tajweed_models.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/ayah_mapper.dart';
import '../../core/services/quran_api_service.dart';
import '../reader/widgets/tajweed_text.dart';
import 'rule_example_references.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

/// Full-screen detail view for a single tajweed rule.
/// Shows the Arabic name, description, example words with color coding,
/// trigger letters, and a "hear pronunciation" button.
class RuleDetailScreen extends StatefulWidget {
  final TajweedRuleDefinition definition;

  const RuleDetailScreen({super.key, required this.definition});

  @override
  State<RuleDetailScreen> createState() => _RuleDetailScreenState();
}

class _RuleDetailScreenState extends State<RuleDetailScreen> {
  final AudioService _audio = AudioService();
  final QuranApiService _api = QuranApiService();
  final GlobalKey _shareButtonKey = GlobalKey();
  bool _playing = false;
  Ayah? _exampleAyah;
  String? _exampleAyahLangCode;
  bool _loadingAyah = true;

  static const int _ruleReciterId = 12;

  ({int surah, int ayah})? _exampleReference() {
    return RuleExampleReferences.referenceFor(widget.definition.rule);
  }

  Future<Ayah?> _fetchExampleAyahForLanguage(String langCode) async {
    if (_exampleAyah != null && _exampleAyahLangCode == langCode) {
      return _exampleAyah;
    }

    final ref = _exampleReference();
    if (ref == null) return null;

    final surah = ref.surah;
    final ayah = ref.ayah;

    final verse = await _api.fetchVerse(
      surahNumber: surah,
      ayahNumber: ayah,
      langCode: langCode,
      reciterId: _ruleReciterId,
    );
    final tajweed = await _api.fetchTajweedText(chapterNumber: surah);
    var mapped = AyahMapper.fromApi(
      verse,
      tajweedHtml: tajweed['$surah:$ayah'],
    );

    final forcedIndices = RuleExampleReferences
        .forcedHighlightWordIndices[widget.definition.rule];
    if (forcedIndices != null) {
      mapped = _forceHighlightWordIndices(
        mapped,
        widget.definition.rule,
        indices: forcedIndices,
      );
    }
    final forcedMarkers = RuleExampleReferences
        .forcedMarkersAfterWordIndices[widget.definition.rule];
    if (forcedMarkers != null) {
      mapped = _forceMarkersAfterWordIndices(mapped, forcedMarkers);
    }

    if (mounted) {
      setState(() {
        _exampleAyah = mapped;
        _exampleAyahLangCode = langCode;
        _loadingAyah = false;
      });
    }

    return mapped;
  }

  @override
  void initState() {
    super.initState();
    _loadExampleAyah();
    _audio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playing = false);
      }
    });
  }

  Future<void> _loadExampleAyah() async {
    final ref = _exampleReference();
    if (ref == null) {
      if (mounted) setState(() => _loadingAyah = false);
      return;
    }

    try {
      final langCode = context.read<LocaleProvider>().locale.languageCode;
      final fetched = await _fetchExampleAyahForLanguage(langCode);
      if (fetched != null) return;
    } catch (_) {}

    if (mounted) setState(() => _loadingAyah = false);
  }

  Ayah _forceHighlightWordIndices(
    Ayah ayah,
    TajweedRule rule, {
    required Set<int> indices,
  }) {
    if (ayah.words.isEmpty || indices.isEmpty) return ayah;

    final patchedWords = <TajweedWord>[];
    for (int index = 0; index < ayah.words.length; index++) {
      final word = ayah.words[index];
      if (!indices.contains(index)) {
        patchedWords.add(word);
        continue;
      }

      patchedWords.add(
        TajweedWord(
          arabic: word.arabic,
          audioUrl: word.audioUrl,
          spans: [TajweedSpan(start: 0, end: word.arabic.length, rule: rule)],
        ),
      );
    }

    return Ayah(
      surahNumber: ayah.surahNumber,
      ayahNumber: ayah.ayahNumber,
      pageNumber: ayah.pageNumber,
      juzNumber: ayah.juzNumber,
      hizbNumber: ayah.hizbNumber,
      rubElHizbNumber: ayah.rubElHizbNumber,
      sajdahNumber: ayah.sajdahNumber,
      arabic: ayah.arabic,
      translations: ayah.translations,
      words: patchedWords,
      audioUrl: ayah.audioUrl,
      tajweedSegments: ayah.tajweedSegments,
    );
  }

  Ayah _forceMarkersAfterWordIndices(
    Ayah ayah,
    Map<int, String> markersByWordIndex,
  ) {
    if (ayah.words.isEmpty || markersByWordIndex.isEmpty) return ayah;

    final patchedWords = <TajweedWord>[];
    for (var index = 0; index < ayah.words.length; index++) {
      final word = ayah.words[index];
      final marker = markersByWordIndex[index];
      if (marker == null || word.arabic.contains(marker)) {
        patchedWords.add(word);
        continue;
      }
      patchedWords.add(
        TajweedWord(
          arabic: '${word.arabic} $marker',
          spans: word.spans,
          audioUrl: word.audioUrl,
        ),
      );
    }

    return Ayah(
      surahNumber: ayah.surahNumber,
      ayahNumber: ayah.ayahNumber,
      pageNumber: ayah.pageNumber,
      juzNumber: ayah.juzNumber,
      hizbNumber: ayah.hizbNumber,
      rubElHizbNumber: ayah.rubElHizbNumber,
      sajdahNumber: ayah.sajdahNumber,
      arabic: ayah.arabic,
      translations: ayah.translations,
      words: patchedWords,
      audioUrl: ayah.audioUrl,
      tajweedSegments: ayah.tajweedSegments,
    );
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  Rect _shareOriginRect() {
    final buttonContext = _shareButtonKey.currentContext;
    if (buttonContext != null) {
      final buttonBox = buttonContext.findRenderObject() as RenderBox?;
      if (buttonBox != null &&
          buttonBox.hasSize &&
          buttonBox.size.longestSide > 0) {
        final origin = buttonBox.localToGlobal(Offset.zero);
        return origin & buttonBox.size;
      }
    }

    final rootBox = context.findRenderObject() as RenderBox?;
    if (rootBox != null && rootBox.hasSize && rootBox.size.longestSide > 0) {
      final center = rootBox.localToGlobal(rootBox.size.center(Offset.zero));
      return Rect.fromCenter(center: center, width: 1, height: 1);
    }

    return const Rect.fromLTWH(1, 1, 1, 1);
  }

  Future<void> _shareRule() async {
    final l10n = AppLocalizations.of(context);
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final def = widget.definition;

    final localizedName = def.name(langCode).trim();
    final arabicName = def.rule.arabicName.trim();
    final description = def.description(langCode).trim();
    final examples = def.exampleArabic
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(6)
        .toList();
    final triggerLetters = def.triggerLetters
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final pronunciationTips = _PronunciationSection(
      rule: def.rule,
      langCode: langCode,
      title: '',
    )._tipsFor(def.rule, langCode);
    Ayah? shareAyah = _exampleAyahLangCode == langCode ? _exampleAyah : null;
    if (shareAyah == null) {
      try {
        shareAyah = await _fetchExampleAyahForLanguage(langCode);
      } catch (_) {
        shareAyah = null;
      }
    }

    final quranText = shareAyah?.arabic.trim();
    final ref = shareAyah == null
        ? _exampleReference()
        : (surah: shareAyah.surahNumber, ayah: shareAyah.ayahNumber);
    final quranRef = ref == null
        ? null
        : '${l10n.get('surah')} ${ref.surah}, ${l10n.get('ayah')} ${ref.ayah}';

    const appName = AppLinks.productName;
    final lines = <String>[
      if (localizedName.isNotEmpty) localizedName,
      if (arabicName.isNotEmpty && arabicName != localizedName) arabicName,
      if (description.isNotEmpty) '',
      if (description.isNotEmpty) description,
    ];

    if (examples.isNotEmpty) {
      lines
        ..add('')
        ..add('${l10n.get('examples')}:')
        ..addAll(examples.map((example) => '- $example'));
    }

    if (triggerLetters.isNotEmpty) {
      lines
        ..add('')
        ..add('${l10n.get('trigger_letters')}:')
        ..add(triggerLetters.join(' • '));
    }

    if (quranText != null && quranText.isNotEmpty) {
      lines
        ..add('')
        ..add(
          '${l10n.get('quran_text')}${quranRef == null ? '' : ' ($quranRef)'}:',
        )
        ..add(quranText);
    } else if (examples.isNotEmpty) {
      lines
        ..add('')
        ..add('${l10n.get('quran_text')}:')
        ..add(examples.join(' '));
    }

    if (pronunciationTips.isNotEmpty) {
      lines
        ..add('')
        ..add('${l10n.get('how_to_pronounce')}:')
        ..addAll(pronunciationTips.map((tip) => '- $tip'));
    }

    lines
      ..add('')
      ..add(appName)
      ..add(AppLinks.appStore);

    final text = lines.join('\n');
    final subject = localizedName.isNotEmpty ? localizedName : appName;
    final originRect = _shareOriginRect();

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          sharePositionOrigin: originRect,
        ),
      );
    } catch (error) {
      debugPrint('Rule share failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final def = widget.definition;
    final rule = def.rule;
    final platform = Theme.of(context).platform;
    final isApplePlatform =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          def.name(langCode),
          style: langCode == 'ar'
              ? const TextStyle(fontFamily: 'AmiriQuran')
              : null,
        ),
        actions: [
          if (isApplePlatform)
            CupertinoButton(
              key: _shareButtonKey,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(44, 44),
              onPressed: _shareRule,
              child: const Icon(CupertinoIcons.share, size: 22),
            )
          else
            IconButton(
              key: _shareButtonKey,
              onPressed: _shareRule,
              icon: const Icon(Icons.share_rounded),
              tooltip: l10n.get('share_rule'),
            ),
        ],
      ),
      body: DefaultTextStyle.merge(
        style: TextStyle(fontFamily: langCode == 'ar' ? 'AmiriQuran' : null),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header with Arabic name and color indicator ──────────────
              _RuleHeader(rule: rule, name: def.name(langCode)),
              const SizedBox(height: 24),

              // ── Description ─────────────────────────────────────────────
              Text(
                def.description(langCode),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  height: 1.75,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // ── Examples section ────────────────────────────────────────
              if (def.exampleArabic.isNotEmpty && rule != TajweedRule.waqf) ...[
                _SectionTitle(title: l10n.get('examples')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: def.exampleArabic.map((ex) {
                    return _ExampleChip(text: ex, color: rule.color);
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // ── Trigger letters ─────────────────────────────────────────
              if (def.triggerLetters.isNotEmpty) ...[
                _SectionTitle(title: l10n.get('trigger_letters')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: def.triggerLetters.map((letter) {
                    return _LetterBadge(letter: letter, color: rule.color);
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              if (rule == TajweedRule.waqf) ...[
                _WaqfSymbolsTable(langCode: langCode),
                const SizedBox(height: 24),
              ],

              // ── Pronunciation guide ─────────────────────────────────────
              _PronunciationSection(
                rule: rule,
                langCode: langCode,
                title: l10n.get('how_to_pronounce'),
              ),
              const SizedBox(height: 24),

              // ── Hear pronunciation button ───────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final url = QuranApiService.normalizeAudioUrl(
                      _exampleAyah?.audioUrl,
                    );
                    if (url == null) return;
                    if (_playing) {
                      _audio.stop();
                      setState(() => _playing = false);
                    } else {
                      _audio.playUrl(url);
                      setState(() => _playing = true);
                    }
                  },
                  icon: Icon(
                    _playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _playing ? l10n.get('stop') : l10n.hearPronunciation,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: rule.color,
                    side: BorderSide(color: rule.color, width: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _PlaybackAyahPreview(
                ayah: _exampleAyah,
                loading: _loadingAyah,
                selectedRule: rule,
                isPlaying: _playing,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackAyahPreview extends StatelessWidget {
  final Ayah? ayah;
  final bool loading;
  final TajweedRule selectedRule;
  final bool isPlaying;

  const _PlaybackAyahPreview({
    required this.ayah,
    required this.loading,
    required this.selectedRule,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (ayah == null) {
      return const SizedBox.shrink();
    }

    final ayahReference = isRtl
        ? '${l10n.get('ayah')} ${ayah!.ayahNumber} • ${l10n.get('surah')} ${ayah!.surahNumber}'
        : '${l10n.get('surah')} ${ayah!.surahNumber} • ${l10n.get('ayah')} ${ayah!.ayahNumber}';
    final headerText = isPlaying
        ? '${l10n.get('now_playing')}: $ayahReference'
        : '${l10n.get('playback_ayah')}: $ayahReference';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPlaying
            ? selectedRule.color.withValues(alpha: 0.14)
            : selectedRule.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedRule.color.withValues(alpha: isPlaying ? 0.85 : 0.35),
          width: isPlaying ? 1.2 : 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isPlaying
                    ? Icons.play_circle_fill_rounded
                    : Icons.queue_music_rounded,
                size: 16,
                color: selectedRule.color,
              ),
              const SizedBox(width: 6),
              Text(
                headerText,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selectedRule.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TajweedText(
            ayah: ayah!,
            fontSize: 31,
            lineHeight: 1.9,
            focusedRule: selectedRule,
            highlightEnabled: true,
            strictFocusedRuleOnly: true,
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.get('highlighted')}: ${selectedRule.arabicName}',
            style: TextStyle(
              fontSize: 11,
              color: selectedRule.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _RuleHeader extends StatelessWidget {
  final TajweedRule rule;
  final String name;

  const _RuleHeader({required this.rule, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: rule.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rule.color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Arabic name large
          Text(
            rule.arabicName,
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 40,
              color: rule.color,
              height: 1.4,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          // Translated name with color dot
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: rule.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: rule.color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  final String text;
  final Color color;

  const _ExampleChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.5,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

class _LetterBadge extends StatelessWidget {
  final String letter;
  final Color color;

  const _LetterBadge({required this.letter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.4,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

class _WaqfSymbolsTable extends StatelessWidget {
  final String langCode;

  const _WaqfSymbolsTable({required this.langCode});

  static const _symbols = ['م', 'لا', 'ج', 'قلى', 'صلى', '∴', 'س'];

  @override
  Widget build(BuildContext context) {
    final strings = WaqfRuleStrings(langCode);
    final isRtl = langCode == 'ar' || langCode == 'ur';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: strings.text('title')),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              for (var index = 0; index < _symbols.length; index++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: TajweedRule.waqf.color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Transform.translate(
                            offset: const Offset(0, -4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _symbols[index],
                                style: TextStyle(
                                  fontFamily: 'AmiriQuran',
                                  fontSize: 30,
                                  fontWeight: FontWeight.w600,
                                  color: TajweedRule.waqf.color,
                                  height: 1.1,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.text('name_$index'),
                              textDirection: isRtl
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              strings.text('description_$index'),
                              textDirection: isRtl
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontSize: 16,
                                    height: 1.55,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < _symbols.length - 1)
                  const Divider(height: 1, indent: 70),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class WaqfRuleStrings {
  final String langCode;

  const WaqfRuleStrings(this.langCode);

  static const Map<String, Map<String, String>> _localized = {
    'en': {
      'title': 'Waqf symbols',
      'name_0': 'Obligatory stop',
      'description_0': 'Stop here to preserve the intended meaning.',
      'name_1': 'Do not stop',
      'description_1':
          'Continue reciting because stopping may alter the meaning.',
      'name_2': 'Permissible stop',
      'description_2': 'Both stopping and continuing are acceptable.',
      'name_3': 'Stopping is preferred',
      'description_3': 'Both are allowed, but stopping is better.',
      'name_4': 'Continuing is preferred',
      'description_4': 'Both are allowed, but continuing is better.',
      'name_5': 'Paired stop',
      'description_5': 'Stop at either paired symbol, but not at both.',
      'name_6': 'Brief pause',
      'description_6': 'Pause briefly without taking a new breath.',
    },
    'ar': {
      'title': 'علامات الوقف',
      'name_0': 'وقف لازم',
      'description_0': 'يلزم الوقف هنا للمحافظة على المعنى المقصود.',
      'name_1': 'لا تقف',
      'description_1': 'يُوصل الكلام لأن الوقف قد يغيّر المعنى.',
      'name_2': 'وقف جائز',
      'description_2': 'يجوز الوقف ويجوز الوصل.',
      'name_3': 'الوقف أولى',
      'description_3': 'يجوز الوقف والوصل، لكن الوقف أفضل.',
      'name_4': 'الوصل أولى',
      'description_4': 'يجوز الوقف والوصل، لكن الوصل أفضل.',
      'name_5': 'تعانق الوقف',
      'description_5': 'يُوقف على إحدى العلامتين المتقابلتين دون كلتيهما.',
      'name_6': 'سكتة لطيفة',
      'description_6': 'سكتة قصيرة من غير أخذ نفس جديد.',
    },
    'ur': {
      'title': 'وقف کی علامات',
      'name_0': 'وقف لازم',
      'description_0': 'مطلب محفوظ رکھنے کے لیے یہاں رکنا ضروری ہے۔',
      'name_1': 'نہ رکیں',
      'description_1': 'تلاوت جاری رکھیں کیونکہ رکنے سے معنی بدل سکتا ہے۔',
      'name_2': 'وقف جائز',
      'description_2': 'رکنا اور جاری رکھنا دونوں درست ہیں۔',
      'name_3': 'رکنا بہتر ہے',
      'description_3': 'دونوں جائز ہیں، لیکن رکنا بہتر ہے۔',
      'name_4': 'جاری رکھنا بہتر ہے',
      'description_4': 'دونوں جائز ہیں، لیکن جاری رکھنا بہتر ہے۔',
      'name_5': 'وقفِ معانقہ',
      'description_5': 'دو علامتوں میں سے کسی ایک پر رکیں، دونوں پر نہیں۔',
      'name_6': 'مختصر سکتہ',
      'description_6': 'نیا سانس لیے بغیر مختصر وقفہ کریں۔',
    },
    'tr': {
      'title': 'Vakf işaretleri',
      'name_0': 'Zorunlu durak',
      'description_0': 'Kastedilen anlamı korumak için burada durun.',
      'name_1': 'Durmayın',
      'description_1':
          'Durmak anlamı değiştirebileceği için okumaya devam edin.',
      'name_2': 'İzin verilen durak',
      'description_2': 'Durmak da devam etmek de uygundur.',
      'name_3': 'Durmak tercih edilir',
      'description_3': 'İkisi de uygundur, fakat durmak daha iyidir.',
      'name_4': 'Devam etmek tercih edilir',
      'description_4': 'İkisi de uygundur, fakat devam etmek daha iyidir.',
      'name_5': 'Eşli durak',
      'description_5':
          'Eşli işaretlerden birinde durun, ikisinde birden değil.',
      'name_6': 'Kısa duraklama',
      'description_6': 'Yeni nefes almadan kısa bir süre duraklayın.',
    },
    'fr': {
      'title': 'Signes de pause',
      'name_0': 'Arrêt obligatoire',
      'description_0': 'Arrêtez-vous ici afin de préserver le sens voulu.',
      'name_1': 'Ne pas s’arrêter',
      'description_1': 'Continuez, car l’arrêt pourrait modifier le sens.',
      'name_2': 'Arrêt permis',
      'description_2': 'L’arrêt et la continuation sont tous deux permis.',
      'name_3': 'Arrêt préférable',
      'description_3': 'Les deux sont permis, mais l’arrêt est préférable.',
      'name_4': 'Continuation préférable',
      'description_4': 'Les deux sont permis, mais continuer est préférable.',
      'name_5': 'Arrêt apparié',
      'description_5':
          'Arrêtez-vous à l’un des deux signes, mais pas aux deux.',
      'name_6': 'Pause brève',
      'description_6': 'Faites une courte pause sans reprendre votre souffle.',
    },
    'id': {
      'title': 'Tanda waqaf',
      'name_0': 'Berhenti wajib',
      'description_0': 'Berhentilah di sini untuk menjaga makna yang dimaksud.',
      'name_1': 'Jangan berhenti',
      'description_1': 'Lanjutkan bacaan karena berhenti dapat mengubah makna.',
      'name_2': 'Berhenti diperbolehkan',
      'description_2': 'Berhenti maupun melanjutkan sama-sama diperbolehkan.',
      'name_3': 'Berhenti lebih utama',
      'description_3': 'Keduanya boleh, tetapi berhenti lebih baik.',
      'name_4': 'Melanjutkan lebih utama',
      'description_4': 'Keduanya boleh, tetapi melanjutkan lebih baik.',
      'name_5': 'Waqaf berpasangan',
      'description_5':
          'Berhenti pada salah satu tanda pasangan, bukan keduanya.',
      'name_6': 'Jeda singkat',
      'description_6': 'Berhenti sejenak tanpa mengambil napas baru.',
    },
    'de': {
      'title': 'Waqf-Zeichen',
      'name_0': 'Verpflichtender Halt',
      'description_0':
          'Hier anhalten, um die beabsichtigte Bedeutung zu bewahren.',
      'name_1': 'Nicht anhalten',
      'description_1': 'Weiterlesen, da ein Halt die Bedeutung verändern kann.',
      'name_2': 'Erlaubter Halt',
      'description_2': 'Anhalten und Weiterlesen sind beide erlaubt.',
      'name_3': 'Anhalten ist vorzuziehen',
      'description_3': 'Beides ist erlaubt, aber Anhalten ist besser.',
      'name_4': 'Weiterlesen ist vorzuziehen',
      'description_4': 'Beides ist erlaubt, aber Weiterlesen ist besser.',
      'name_5': 'Gekoppelter Halt',
      'description_5': 'An einem der beiden Zeichen anhalten, nicht an beiden.',
      'name_6': 'Kurze Pause',
      'description_6': 'Kurz pausieren, ohne neu einzuatmen.',
    },
    'es': {
      'title': 'Signos de waqf',
      'name_0': 'Pausa obligatoria',
      'description_0': 'Detente aquí para conservar el significado previsto.',
      'name_1': 'No detenerse',
      'description_1':
          'Continúa, pues detenerse podría alterar el significado.',
      'name_2': 'Pausa permitida',
      'description_2': 'Tanto detenerse como continuar son aceptables.',
      'name_3': 'Es preferible detenerse',
      'description_3': 'Ambas opciones son válidas, pero es mejor detenerse.',
      'name_4': 'Es preferible continuar',
      'description_4': 'Ambas opciones son válidas, pero es mejor continuar.',
      'name_5': 'Pausa emparejada',
      'description_5': 'Detente en uno de los dos signos, pero no en ambos.',
      'name_6': 'Pausa breve',
      'description_6': 'Haz una pausa breve sin tomar un nuevo aliento.',
    },
  };

  String text(String key) =>
      _localized[langCode]?[key] ?? _localized['en']![key] ?? key;
}

class _PronunciationSection extends StatelessWidget {
  final TajweedRule rule;
  final String langCode;
  final String title;

  const _PronunciationSection({
    required this.rule,
    required this.langCode,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final tips = _tipsFor(rule, langCode);
    if (tips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: title),
        const SizedBox(height: 10),
        ...tips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 6, color: rule.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 17,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> _tipsFor(TajweedRule rule, String langCode) {
    if (langCode == 'ar') {
      return _tipsForArabic(rule);
    }
    if (langCode == 'ur') {
      return _tipsForUrdu(rule);
    }
    if (langCode == 'tr') {
      return _tipsForTurkish(rule);
    }
    if (langCode == 'fr') {
      return _tipsForFrench(rule);
    }
    if (langCode == 'id') {
      return _tipsForIndonesian(rule);
    }
    if (langCode == 'de') {
      return _tipsForGerman(rule);
    }

    switch (rule) {
      case TajweedRule.ghunnah:
        return [
          'Hold the sound through your nose for 2 counts',
          'Place your tongue against the upper palate',
          'The nasal resonance should be clear and steady',
        ];
      case TajweedRule.qalqalah:
        return [
          'Add a slight bounce/echo when the letter has sukoon',
          'Stronger (kubra) when stopping at end of a word',
          'Lighter (sughra) when in the middle of a word',
        ];
      case TajweedRule.maddTabeei:
        return [
          'Extend the vowel for exactly 2 counts',
          'Keep the sound natural — don\'t force it',
          'Alif, Waw, and Ya are the madd letters',
        ];
      case TajweedRule.maddMuttasil:
        return [
          'Extend for 4-5 counts when hamza follows in the same word',
          'This is obligatory (wajib) — do not shorten it',
        ];
      case TajweedRule.maddMunfasil:
        return [
          'Extend for 2-5 counts when hamza starts the next word',
          'This is permissible (jaiz) — length varies by reader',
        ];
      case TajweedRule.maddSilahSughra:
        return [
          'Extend the pronoun ha for 2 counts',
          'It occurs between two vowelled letters without a following hamza',
        ];
      case TajweedRule.maddSilahKubra:
        return [
          'Extend the pronoun ha for 4-5 counts',
          'It occurs between two vowelled letters before a hamza',
        ];
      case TajweedRule.ikhfa:
        return [
          'The noon sound is hidden — not fully clear, not fully merged',
          'A ghunnah of 2 counts accompanies the sound',
          'Adjust tongue position toward the following letter',
        ];
      case TajweedRule.iqlab:
        return [
          'Change the noon into a meem sound before ba',
          'Hide the meem with ghunnah for 2 counts',
          'Look for the small meem symbol in the Quran text',
        ];
      case TajweedRule.izhar:
        return [
          'Pronounce the noon clearly and distinctly',
          'No nasalization (ghunnah) — keep it clean',
          'The throat letters trigger this rule',
        ];
      case TajweedRule.idghamWithGhunnah:
        return [
          'Merge the noon into the next letter',
          'Maintain ghunnah for 2 counts during the merge',
          'Letters: Ya, Nun, Meem, Waw',
        ];
      case TajweedRule.idghamWithoutGhunnah:
        return [
          'Merge the noon completely into Lam or Ra',
          'No ghunnah — the noon vanishes entirely',
        ];
      case TajweedRule.shaddah:
        return [
          'Double the letter — press and hold slightly',
          'If on noon or meem, ghunnah is required',
        ];
      case TajweedRule.waqf:
        return [
          'Stop marks indicate where to pause during recitation',
          'Respect the stop type: obligatory, permissible, or forbidden',
        ];
      case TajweedRule.sajdah:
        return [
          'The sajdah sign indicates a verse of prostration',
          'When reciting this verse, perform sajdah according to your practice',
          'The sign is shown as ۩ in the text',
        ];
      case TajweedRule.maddLazim:
        return [
          'Extend for 6 full counts — this is the longest madd',
          'Occurs when a madd letter is followed by a letter with shaddah or sukoon in the same word',
          'Found in special letters at the start of some surahs (e.g., الم)',
        ];
      case TajweedRule.idghamShafawi:
        return [
          'Merge a meem sakinah into a following meem',
          'Accompanied by ghunnah for 2 counts',
          'The lips close and the sound resonates through the nose',
        ];
      case TajweedRule.idghamMutajanisayn:
        return [
          'Merge two letters that share the same point of articulation',
          'The first letter is silent and merges into the second',
          'Example: ت into ط, or ذ into ظ',
        ];
      case TajweedRule.ikhfaShafawi:
        return [
          'Conceal a meem sakinah before the letter ba (ب)',
          'The lips come close together without fully touching',
          'Accompanied by ghunnah for 2 counts',
        ];
      case TajweedRule.hamzatWasl:
        return [
          'A connecting hamza that is only pronounced at the start of speech',
          'When continuing from a previous word, it is dropped',
          'Found at the start of "Al-" and certain verb forms',
        ];
      case TajweedRule.laamShamsiyah:
        return [
          'The lam of "Al-" is not pronounced — it assimilates into the following sun letter',
          'The sun letter that follows gets a shaddah instead',
          'Sun letters: ت ث د ذ ر ز س ش ص ض ط ظ ل ن',
        ];
      case TajweedRule.silent:
        return [
          'Some letters in the Quran are written but not pronounced',
          'These are specific orthographic features of the Uthmani script',
        ];
    }
  }

  List<String> _tipsForArabic(TajweedRule rule) {
    switch (rule) {
      case TajweedRule.ghunnah:
        return [
          'حافظ على الغنة من الخيشوم بمقدار حركتين',
          'ضع اللسان في موضعه الصحيح مع وضوح الرنين الأنفي',
          'ليكن صوت الغنة ثابتًا وواضحًا',
        ];
      case TajweedRule.qalqalah:
        return [
          'أظهر نبرة القلقلة عند الحرف الساكن',
          'تكون القلقلة أكبر عند الوقف في آخر الكلمة',
          'وتكون أخف في وسط الكلمة',
        ];
      case TajweedRule.maddTabeei:
        return [
          'مدّ الصوت الطبيعي بمقدار ٢ حركة فقط',
          'اجعل المد طبيعيًا دون تكلف',
          'حروف المد: الألف والواو والياء',
        ];
      case TajweedRule.maddMuttasil:
        return [
          'يمد ٤–٥ حركات إذا جاء الهمز بعد حرف المد في نفس الكلمة',
          'هذا مد واجب فلا يُقصر',
        ];
      case TajweedRule.maddMunfasil:
        return [
          'يمد ٢–٥ حركات إذا جاء الهمز في أول الكلمة التالية',
          'هو مد جائز ويختلف مقداره بحسب القراءة',
        ];
      case TajweedRule.maddSilahSughra:
        return ['مد هاء الضمير ٢ حركة', 'يكون بين متحركين من غير همز بعدها'];
      case TajweedRule.maddSilahKubra:
        return [
          'مد هاء الضمير ٤–٥ حركات',
          'يكون بين متحركين إذا جاء بعدها همز',
        ];
      case TajweedRule.ikhfa:
        return [
          'أخفِ صوت النون بين الإظهار والإدغام',
          'مع غنة مقدارها حركتان',
          'وجّه اللسان باتجاه الحرف التالي دون إطباق كامل',
        ];
      case TajweedRule.iqlab:
        return [
          'اقلب النون الساكنة أو التنوين ميمًا قبل الباء',
          'وأخفِ الميم مع غنة مقدارها حركتان',
          'تُعرف غالبًا بوجود ميم صغيرة في المصحف',
        ];
      case TajweedRule.izhar:
        return [
          'أظهر النون الساكنة أو التنوين بوضوح',
          'من غير غنة زائدة',
          'ويكون ذلك مع حروف الحلق',
        ];
      case TajweedRule.idghamWithGhunnah:
        return [
          'أدغم النون في الحرف التالي إدغامًا مع غنة',
          'الغنة تكون بمقدار حركتين',
          'حروفه: ي، ن، م، و',
        ];
      case TajweedRule.idghamWithoutGhunnah:
        return ['أدغم النون إدغامًا كاملاً في اللام أو الراء', 'من غير غنة'];
      case TajweedRule.shaddah:
        return [
          'شدّد الحرف كأنه حرفان أولهما ساكن والثاني متحرك',
          'وإن كان على النون أو الميم فالغنة لازمة',
        ];
      case TajweedRule.waqf:
        return [
          'علامات الوقف تحدد مواضع الوقف والابتداء',
          'راعِ نوع العلامة: لازم أو جائز أو ممنوع',
        ];
      case TajweedRule.sajdah:
        return [
          'علامة السجدة تدل على موضع سجود التلاوة',
          'عند قراءتها يُعمل بسجود التلاوة بحسب المذهب المتبع',
          'تظهر في المصحف بالرمز ۩',
        ];
      case TajweedRule.maddLazim:
        return [
          'يمد ٦ حركات كاملة وهو أطول أنواع المد',
          'يكون عند حرف المد إذا جاء بعده سكون أصلي أو شدة في نفس البنية',
          'ويظهر أيضًا في أوائل بعض السور مثل: الم',
        ];
      case TajweedRule.idghamShafawi:
        return [
          'أدغم الميم الساكنة في ميم بعدها',
          'مع غنة مقدارها حركتان',
          'ويكون العمل بالشفتين مع الرنين الأنفي',
        ];
      case TajweedRule.idghamMutajanisayn:
        return [
          'أدغم حرفين متجانسين في المخرج',
          'الأول ساكن والثاني متحرك',
          'مثل إدغام التاء في الطاء والذال في الظاء',
        ];
      case TajweedRule.ikhfaShafawi:
        return [
          'أخفِ الميم الساكنة قبل الباء',
          'مع تقارب الشفتين دون إطباق كامل',
          'ومع غنة مقدارها حركتان',
        ];
      case TajweedRule.hamzatWasl:
        return [
          'همزة الوصل تُنطق في الابتداء فقط',
          'وتسقط في حال الوصل بما قبلها',
          'توجد في أل التعريف وبعض صيغ الأفعال',
        ];
      case TajweedRule.laamShamsiyah:
        return [
          'لام "ال" لا تُنطق مع الحروف الشمسية',
          'ويُشدّد الحرف الشمسي الذي بعدها',
          'حروفها: ت ث د ذ ر ز س ش ص ض ط ظ ل ن',
        ];
      case TajweedRule.silent:
        return [
          'بعض الحروف تُكتب في الرسم العثماني ولا تُنطق',
          'وهذا من خصائص الرسم القرآني',
        ];
    }
  }

  List<String> _tipsForUrdu(TajweedRule rule) {
    switch (rule) {
      case TajweedRule.ghunnah:
        return [
          'ناک سے آواز کو دو حرکات تک برقرار رکھیں',
          'غنہ واضح اور ہموار ہونا چاہیے',
        ];
      case TajweedRule.qalqalah:
        return [
          'ساکن حرف پر ہلکی اچھال پیدا کریں',
          'آخرِ کلمہ وقف میں قلقلة زیادہ واضح کریں',
        ];
      case TajweedRule.maddTabeei:
        return [
          'مدِ طبیعی کو صرف دو حرکات تک کھینچیں',
          'مد کو قدرتی رکھیں، تکلف نہ کریں',
        ];
      case TajweedRule.maddMuttasil:
        return [
          'ایک ہی لفظ میں ہمزہ آئے تو 4-5 حرکات مد کریں',
          'یہ واجب مد ہے، کم نہ کریں',
        ];
      case TajweedRule.maddMunfasil:
        return [
          'اگلے لفظ کے شروع میں ہمزہ ہو تو 2-5 حرکات مد کریں',
          'یہ جائز مد ہے، قاری کے طریقے پر منحصر',
        ];
      case TajweedRule.maddSilahSughra:
        return ['ضمیر کی ہاء کو دو حرکات کھینچیں', 'اس کے بعد ہمزہ نہ ہو'];
      case TajweedRule.maddSilahKubra:
        return ['ضمیر کی ہاء کو 4-5 حرکات کھینچیں', 'اس کے بعد ہمزہ ہو'];
      case TajweedRule.ikhfa:
        return [
          'نون کی آواز کو اخفاء میں رکھیں، نہ مکمل ظاہر نہ مکمل ادغام',
          'دو حرکات غنہ کے ساتھ ادا کریں',
        ];
      case TajweedRule.iqlab:
        return [
          'باء سے پہلے نون کو میم میں تبدیل کریں',
          'میم کو دو حرکات کے غنہ کے ساتھ مخفی پڑھیں',
        ];
      case TajweedRule.izhar:
        return ['نون کو صاف اور واضح ادا کریں', 'غنہ کے بغیر پڑھیں'];
      case TajweedRule.idghamWithGhunnah:
        return [
          'نون کو اگلے حرف میں ادغام کریں',
          'ادغام کے دوران دو حرکات غنہ رکھیں',
        ];
      case TajweedRule.idghamWithoutGhunnah:
        return ['نون کو لام یا را میں مکمل ادغام کریں', 'غنہ نہ کریں'];
      case TajweedRule.shaddah:
        return [
          'حرف کو مشدد یعنی دگنا ادا کریں',
          'نون یا میم پر تشدید ہو تو غنہ لازم ہے',
        ];
      case TajweedRule.waqf:
        return [
          'وقف کی علامات رکنے کی جگہ بتاتی ہیں',
          'علامت کے مطابق لازم، جائز یا ممنوع وقف کریں',
        ];
      case TajweedRule.sajdah:
        return [
          '۩ سجدہ آیت کی علامت ہے',
          'قراءت میں اس مقام پر سجدۂ تلاوت کیا جاتا ہے',
        ];
      case TajweedRule.maddLazim:
        return ['اس مد کو 6 حرکات تک کھینچیں', 'یہ سب سے مضبوط لازمی مد ہے'];
      case TajweedRule.idghamShafawi:
        return [
          'میم ساکن کو اگلی میم میں ادغام کریں',
          'دو حرکات غنہ کے ساتھ ادا کریں',
        ];
      case TajweedRule.idghamMutajanisayn:
        return [
          'ہم مخرج حروف میں ادغام کریں',
          'پہلا ساکن اور دوسرا متحرک حرف مل جاتا ہے',
        ];
      case TajweedRule.ikhfaShafawi:
        return [
          'میم ساکن کو باء سے پہلے مخفی کریں',
          'شفتین قریب رکھیں اور غنہ کریں',
        ];
      case TajweedRule.hamzatWasl:
        return [
          'ہمزۂ وصل ابتدا میں پڑھا جاتا ہے',
          'وصل کی حالت میں ساقط ہو جاتا ہے',
        ];
      case TajweedRule.laamShamsiyah:
        return [
          'ال کی لام حرف شمسی سے پہلے نہیں پڑھی جاتی',
          'اگلا حرف شمسی مشدد پڑھا جاتا ہے',
        ];
      case TajweedRule.silent:
        return [
          'بعض حروف لکھے جاتے ہیں مگر پڑھے نہیں جاتے',
          'یہ رسمِ عثمانی کی خصوصیت ہے',
        ];
    }
  }

  List<String> _tipsForTurkish(TajweedRule rule) {
    switch (rule) {
      case TajweedRule.ghunnah:
        return [
          'Sesi genizden 2 hareke tutun',
          'Ghunna net ve dengeli olmalıdır',
        ];
      case TajweedRule.qalqalah:
        return [
          'Sakin harfte hafif yankı verin',
          'Kelime sonunda vakıfta daha belirgin okuyun',
        ];
      case TajweedRule.maddTabeei:
        return [
          'Doğal meddi tam 2 hareke uzatın',
          'Uzatmayı zorlamadan doğal okuyun',
        ];
      case TajweedRule.maddMuttasil:
        return [
          'Aynı kelimede hemzeden önceki meddi 4-5 hareke uzatın',
          'Bu vacip meddir, kısaltmayın',
        ];
      case TajweedRule.maddMunfasil:
        return [
          'Sonraki kelime hemze ile başlıyorsa 2-5 hareke uzatın',
          'Miktar kıraat usulüne göre değişebilir',
        ];
      case TajweedRule.maddSilahSughra:
        return ['Zamir hâsını 2 hareke uzatın', 'Ardından hemze gelmemelidir'];
      case TajweedRule.maddSilahKubra:
        return ['Zamir hâsını 4-5 hareke uzatın', 'Ardından hemze gelmelidir'];
      case TajweedRule.ikhfa:
        return [
          'Nun sesini izhar ile idğam arasında gizleyin',
          '2 hareke ghunna ile okuyun',
        ];
      case TajweedRule.iqlab:
        return [
          'Ba harfinden önce nun sesini mime çevirin',
          'Mimi 2 hareke ghunna ile gizleyin',
        ];
      case TajweedRule.izhar:
        return ['Nun sesini açık ve net çıkarın', 'Ghunna eklemeyin'];
      case TajweedRule.idghamWithGhunnah:
        return [
          'Nunu sonraki harfe birleştirin',
          'Birleşmede 2 hareke ghunna koruyun',
        ];
      case TajweedRule.idghamWithoutGhunnah:
        return ['Nunu lam veya ra harfine tamamen katın', 'Ghunna yapmayın'];
      case TajweedRule.shaddah:
        return [
          'Harfi iki harf gibi kuvvetli okuyun',
          'Nun ve mimde şedde varsa ghunna gerekir',
        ];
      case TajweedRule.waqf:
        return [
          'Vakf işaretleri durma yerlerini gösterir',
          'İşaret türüne göre durun veya geçin',
        ];
      case TajweedRule.sajdah:
        return ['۩ secde ayetini gösterir', 'Tilavette bu yerde secde yapılır'];
      case TajweedRule.maddLazim:
        return ['Bu meddi 6 hareke uzatın', 'En güçlü zorunlu med türüdür'];
      case TajweedRule.idghamShafawi:
        return [
          'Sakin mimin ardından gelen mime idğam edin',
          '2 hareke ghunna ile okuyun',
        ];
      case TajweedRule.idghamMutajanisayn:
        return [
          'Aynı mahreçli iki harfi idğam edin',
          'İlk sakin harf ikinciye katılır',
        ];
      case TajweedRule.ikhfaShafawi:
        return [
          'Sakin mimi ba harfinden önce gizleyin',
          'Dudakları yaklaştırıp ghunna yapın',
        ];
      case TajweedRule.hamzatWasl:
        return ['Hemze-i vasl sadece başlangıçta okunur', 'Vasl halinde düşer'];
      case TajweedRule.laamShamsiyah:
        return [
          'El takısındaki lam okunmaz',
          'Sonraki şemsi harf şeddeli okunur',
        ];
      case TajweedRule.silent:
        return [
          'Bazı harfler yazılır ama okunmaz',
          'Bu Uthmani yazımın özelliğidir',
        ];
    }
  }

  List<String> _tipsForFrench(TajweedRule rule) {
    switch (rule) {
      case TajweedRule.ghunnah:
        return [
          'Maintenez le son nasal pendant 2 temps',
          'La résonance nasale doit être claire et stable',
        ];
      case TajweedRule.qalqalah:
        return [
          'Ajoutez un léger rebond sur la consonne avec soukoun',
          'En fin de mot à l arrêt, l effet est plus fort',
        ];
      case TajweedRule.maddTabeei:
        return [
          'Allongez la voyelle naturelle de 2 temps',
          'Gardez une prolongation naturelle sans forcer',
        ];
      case TajweedRule.maddMuttasil:
        return [
          'Allongez 4-5 temps si la hamza est dans le même mot',
          'C est un madd obligatoire',
        ];
      case TajweedRule.maddMunfasil:
        return [
          'Allongez 2-5 temps si la hamza ouvre le mot suivant',
          'La longueur dépend de la lecture adoptée',
        ];
      case TajweedRule.maddSilahSughra:
        return [
          'Allongez le ha pronominal de 2 temps',
          'Il n’est pas suivi d’une hamza',
        ];
      case TajweedRule.maddSilahKubra:
        return [
          'Allongez le ha pronominal de 4-5 temps',
          'Il est suivi d’une hamza',
        ];
      case TajweedRule.ikhfa:
        return [
          'Cachez le son de noon entre izhar et idgham',
          'Accompagnez avec une ghounna de 2 temps',
        ];
      case TajweedRule.iqlab:
        return [
          'Transformez noon en son meem avant ba',
          'Cachez le meem avec 2 temps de ghounna',
        ];
      case TajweedRule.izhar:
        return [
          'Prononcez noon clairement et distinctement',
          'Sans nasalisation supplémentaire',
        ];
      case TajweedRule.idghamWithGhunnah:
        return [
          'Fusionnez noon avec la lettre suivante',
          'Gardez 2 temps de ghounna pendant la fusion',
        ];
      case TajweedRule.idghamWithoutGhunnah:
        return ['Fusionnez complètement noon dans lam ou ra', 'Sans ghounna'];
      case TajweedRule.shaddah:
        return [
          'Doublez la consonne avec une articulation appuyée',
          'Sur noon ou meem, la ghounna est requise',
        ];
      case TajweedRule.waqf:
        return [
          'Les signes de waqf indiquent où s arrêter',
          'Respectez le type du signe avant de continuer',
        ];
      case TajweedRule.sajdah:
        return [
          'Le signe ۩ indique un verset de prosternation',
          'On effectue la sajdah de récitation à cet endroit',
        ];
      case TajweedRule.maddLazim:
        return [
          'Allongez à 6 temps complets',
          'C est le madd le plus fort et obligatoire',
        ];
      case TajweedRule.idghamShafawi:
        return [
          'Fusionnez meem sakinah avec meem suivant',
          'Lisez avec 2 temps de ghounna',
        ];
      case TajweedRule.idghamMutajanisayn:
        return [
          'Fusionnez deux lettres de même point d articulation',
          'La première consonne se fond dans la seconde',
        ];
      case TajweedRule.ikhfaShafawi:
        return [
          'Cachez meem sakinah avant ba',
          'Approchez les lèvres avec ghounna',
        ];
      case TajweedRule.hamzatWasl:
        return [
          'Hamzat wasl se prononce au début seulement',
          'Elle tombe en liaison',
        ];
      case TajweedRule.laamShamsiyah:
        return [
          'Le lam de al n est pas prononcé',
          'La lettre solaire suivante porte la shadda',
        ];
      case TajweedRule.silent:
        return [
          'Certaines lettres sont écrites mais non prononcées',
          'C est une particularité du rasm uthmani',
        ];
    }
  }

  List<String> _tipsForIndonesian(TajweedRule rule) {
    switch (rule) {
      case TajweedRule.ghunnah:
        return [
          'Tahan dengung melalui hidung selama 2 harakat',
          'Resonansi dengung harus jelas dan stabil',
        ];
      case TajweedRule.qalqalah:
        return [
          'Beri pantulan ringan pada huruf bersukun',
          'Saat waqaf di akhir kata, pantulan lebih kuat',
        ];
      case TajweedRule.maddTabeei:
        return [
          'Panjangkan mad asli tepat 2 harakat',
          'Bacalah alami tanpa memaksa',
        ];
      case TajweedRule.maddMuttasil:
        return [
          'Panjangkan 4-5 harakat jika hamzah dalam kata yang sama',
          'Ini mad wajib, jangan dipendekkan',
        ];
      case TajweedRule.maddMunfasil:
        return [
          'Panjangkan 2-5 harakat bila hamzah di awal kata berikutnya',
          'Panjang bacaan mengikuti riwayat qiraah',
        ];
      case TajweedRule.maddSilahSughra:
        return ['Panjangkan ha dhamir 2 harakat', 'Tidak diikuti hamzah'];
      case TajweedRule.maddSilahKubra:
        return ['Panjangkan ha dhamir 4-5 harakat', 'Diikuti hamzah'];
      case TajweedRule.ikhfa:
        return [
          'Sembunyikan suara nun antara izhar dan idgham',
          'Baca dengan ghunnah 2 harakat',
        ];
      case TajweedRule.iqlab:
        return [
          'Ubah nun menjadi bunyi mim sebelum ba',
          'Sembunyikan mim dengan ghunnah 2 harakat',
        ];
      case TajweedRule.izhar:
        return ['Lafalkan nun dengan jelas', 'Tanpa tambahan dengung'];
      case TajweedRule.idghamWithGhunnah:
        return [
          'Gabungkan nun ke huruf berikutnya',
          'Pertahankan ghunnah 2 harakat saat menggabung',
        ];
      case TajweedRule.idghamWithoutGhunnah:
        return ['Gabungkan nun sepenuhnya ke lam atau ra', 'Tanpa ghunnah'];
      case TajweedRule.shaddah:
        return [
          'Tekankan huruf seolah dua huruf',
          'Jika pada nun atau mim, ghunnah wajib',
        ];
      case TajweedRule.waqf:
        return [
          'Tanda waqaf menunjukkan tempat berhenti',
          'Ikuti jenis tanda saat berhenti atau lanjut',
        ];
      case TajweedRule.sajdah:
        return [
          'Tanda ۩ menunjukkan ayat sajdah',
          'Pada ayat ini dilakukan sujud tilawah',
        ];
      case TajweedRule.maddLazim:
        return [
          'Panjangkan sampai 6 harakat penuh',
          'Ini jenis mad wajib paling kuat',
        ];
      case TajweedRule.idghamShafawi:
        return [
          'Idghamkan mim sukun ke mim berikutnya',
          'Baca dengan ghunnah 2 harakat',
        ];
      case TajweedRule.idghamMutajanisayn:
        return [
          'Gabungkan dua huruf dengan makhraj yang sama',
          'Huruf pertama melebur ke huruf kedua',
        ];
      case TajweedRule.ikhfaShafawi:
        return [
          'Sembunyikan mim sukun sebelum ba',
          'Dekatkan bibir disertai ghunnah',
        ];
      case TajweedRule.hamzatWasl:
        return [
          'Hamzat wasl dibaca saat memulai',
          'Saat washal, hamzah tidak dibaca',
        ];
      case TajweedRule.laamShamsiyah:
        return [
          'Lam pada al tidak dibaca',
          'Huruf syamsiyah setelahnya dibaca bertasydid',
        ];
      case TajweedRule.silent:
        return [
          'Sebagian huruf ditulis tetapi tidak dilafalkan',
          'Ini ciri khusus rasm Utsmani',
        ];
    }
  }

  List<String> _tipsForGerman(TajweedRule rule) {
    switch (rule) {
      case TajweedRule.ghunnah:
        return [
          'Halte den Nasalklang 2 Zählzeiten',
          'Die Resonanz soll klar und gleichmäßig sein',
        ];
      case TajweedRule.qalqalah:
        return [
          'Gib beim stillen Buchstaben einen leichten Rückprall',
          'Am Wortende im Stopp ist der Effekt stärker',
        ];
      case TajweedRule.maddTabeei:
        return [
          'Verlängere natürlich genau 2 Zählzeiten',
          'Lies natürlich ohne zu übertreiben',
        ];
      case TajweedRule.maddMuttasil:
        return [
          'Verlängere 4-5 Zählzeiten bei Hamza im selben Wort',
          'Dies ist verpflichtend und darf nicht gekürzt werden',
        ];
      case TajweedRule.maddMunfasil:
        return [
          'Verlängere 2-5 Zählzeiten bei Hamza im nächsten Wort',
          'Die Länge folgt der gewählten Lesart',
        ];
      case TajweedRule.maddSilahSughra:
        return [
          'Verlängere das Pronomen-Ha 2 Zählzeiten',
          'Danach folgt kein Hamza',
        ];
      case TajweedRule.maddSilahKubra:
        return [
          'Verlängere das Pronomen-Ha 4-5 Zählzeiten',
          'Danach folgt ein Hamza',
        ];
      case TajweedRule.ikhfa:
        return [
          'Verberge den Nun-Laut zwischen Izhar und Idgham',
          'Mit Ghunna von 2 Zählzeiten lesen',
        ];
      case TajweedRule.iqlab:
        return [
          'Wandle Nun vor Ba in Mim-Laut um',
          'Verdecke Mim mit 2 Zählzeiten Ghunna',
        ];
      case TajweedRule.izhar:
        return [
          'Sprich den Nun-Laut klar und deutlich',
          'Ohne zusätzliche Nasalisation',
        ];
      case TajweedRule.idghamWithGhunnah:
        return [
          'Verschmelze Nun mit dem folgenden Buchstaben',
          'Bewahre 2 Zählzeiten Ghunna',
        ];
      case TajweedRule.idghamWithoutGhunnah:
        return ['Verschmelze Nun vollständig in Lam oder Ra', 'Ohne Ghunna'];
      case TajweedRule.shaddah:
        return [
          'Sprich den Buchstaben verdoppelt und betont',
          'Bei Nun oder Mim mit Shaddah ist Ghunna nötig',
        ];
      case TajweedRule.waqf:
        return [
          'Waqf-Zeichen markieren Haltepunkte',
          'Beachte die Art des Zeichens beim Anhalten',
        ];
      case TajweedRule.sajdah:
        return [
          'Das Zeichen ۩ markiert einen Niederwerfungsvers',
          'An dieser Stelle erfolgt Sajdah at-Tilawah',
        ];
      case TajweedRule.maddLazim:
        return [
          'Verlängere auf volle 6 Zählzeiten',
          'Dies ist die stärkste verpflichtende Madd-Form',
        ];
      case TajweedRule.idghamShafawi:
        return [
          'Verschmelze Meem Sakinah mit folgendem Meem',
          'Mit 2 Zählzeiten Ghunna lesen',
        ];
      case TajweedRule.idghamMutajanisayn:
        return [
          'Verschmelze zwei Buchstaben mit gleichem Artikulationsort',
          'Der erste Laut geht in den zweiten über',
        ];
      case TajweedRule.ikhfaShafawi:
        return [
          'Verberge Meem Sakinah vor Ba',
          'Lippen annähern und mit Ghunna lesen',
        ];
      case TajweedRule.hamzatWasl:
        return [
          'Hamzat Wasl wird nur am Satzanfang gesprochen',
          'In der Verbindung fällt sie weg',
        ];
      case TajweedRule.laamShamsiyah:
        return [
          'Das Laam von al wird nicht gesprochen',
          'Der folgende Sonnenbuchstabe trägt Shaddah',
        ];
      case TajweedRule.silent:
        return [
          'Manche Buchstaben sind geschrieben, aber stumm',
          'Das ist eine Besonderheit der uthmanischen Schrift',
        ];
    }
  }
}
