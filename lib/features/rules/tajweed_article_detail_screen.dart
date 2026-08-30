import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/ayah_mapper.dart';
import '../../core/services/quran_api_service.dart';
import 'rule_example_references.dart';
import 'tajweed_article.dart';

class TajweedArticleDetailScreen extends StatefulWidget {
  final TajweedArticle article;
  final String languageCode;

  const TajweedArticleDetailScreen({
    super.key,
    required this.article,
    required this.languageCode,
  });

  @override
  State<TajweedArticleDetailScreen> createState() =>
      _TajweedArticleDetailScreenState();
}

class _ArticleExample {
  final AyahReference reference;
  String? arabicText;
  String? audioUrl;
  bool loading = false;

  _ArticleExample(this.reference);
}

class _TajweedArticleDetailScreenState
    extends State<TajweedArticleDetailScreen> {
  final AudioService _audio = AudioService();
  final QuranApiService _api = QuranApiService();
  int? _playingIndex;
  late final List<_ArticleExample> _examples;

  static const int _articleReciterId = 12; // Husary Al-Muallim

  @override
  void initState() {
    super.initState();
    _examples = RuleExampleReferences.referencesForArticle(widget.article.id)
        .map(_ArticleExample.new)
        .toList();
    _audio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playingIndex = null);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllExamples());
  }

  Future<void> _loadAllExamples() async {
    for (var i = 0; i < _examples.length; i++) {
      await _loadExample(i);
    }
  }

  Future<void> _loadExample(int index) async {
    final example = _examples[index];
    if (example.arabicText != null) return;

    setState(() => example.loading = true);
    try {
      final langCode = context.read<LocaleProvider>().locale.languageCode;
      final verse = await _api.fetchVerse(
        surahNumber: example.reference.surah,
        ayahNumber: example.reference.ayah,
        langCode: langCode,
        reciterId: _articleReciterId,
      );
      final mapped = AyahMapper.fromApi(verse);
      final normalizedUrl = QuranApiService.normalizeAudioUrl(
        mapped.audioUrl,
      );
      if (!mounted) return;
      setState(() {
        example.audioUrl = normalizedUrl;
        example.arabicText = mapped.plainArabicText();
        example.loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => example.loading = false);
    }
  }

  Future<void> _toggle(int index) async {
    if (_playingIndex == index) {
      _audio.stop();
      setState(() => _playingIndex = null);
      return;
    }

    final example = _examples[index];
    var url = QuranApiService.normalizeAudioUrl(example.audioUrl);
    if (url == null) {
      await _loadExample(index);
      url = QuranApiService.normalizeAudioUrl(example.audioUrl);
    }
    if (url == null) return;

    _audio.stop();
    _audio.playUrl(url);
    if (mounted) setState(() => _playingIndex = index);
  }

  @override
  void dispose() {
    _audio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final article = widget.article;
    final languageCode = widget.languageCode;
    final paragraphs = article
        .body(languageCode)
        .split('\n\n')
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .toList();
    final sectionTitles = article.sections(languageCode);
    final exampleCaptions = RuleExampleReferences.captionsForArticle(
      article.id,
    );
    final accent = article.category == TajweedArticleCategory.fundamentals
        ? const Color(0xFF176B5B)
        : const Color(0xFF6A4C93);

    return Scaffold(
      appBar: AppBar(title: Text(article.title(languageCode))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                article.summary(languageCode),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  height: 1.6,
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...paragraphs.indexed.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (entry.$1 < sectionTitles.length) ...[
                      Text(
                        sectionTitles[entry.$1],
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      entry.$2,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.75,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_examples.isNotEmpty) ...[
              const SizedBox(height: 6),
              _SectionTitle(title: l10n.get('examples'), accent: accent),
              const SizedBox(height: 10),
              for (var index = 0; index < _examples.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (index < sectionTitles.length)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            sectionTitles[index],
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      if (index < exampleCaptions.length &&
                          exampleCaptions[index].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            exampleCaptions[index],
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(height: 1.4),
                          ),
                        ),
                      if (_examples[index].arabicText != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text.rich(
                            _highlightedSpan(
                              _examples[index].arabicText!,
                              RuleExampleReferences.highlightWordsForExample(
                                article.id,
                                index,
                              ),
                              accent,
                            ),
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _examples[index].loading
                              ? null
                              : () => _toggle(index),
                          icon: _examples[index].loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _playingIndex == index
                                      ? Icons.stop_rounded
                                      : Icons.volume_up_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            _playingIndex == index
                                ? l10n.get('stop')
                                : l10n.hearExample,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            side: BorderSide(color: accent, width: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  TextSpan _highlightedSpan(
    String arabicText,
    List<String> highlights,
    Color accent,
  ) {
    const baseStyle = TextStyle(
      fontFamily: 'AmiriQuran',
      fontSize: 24,
      height: 1.8,
    );
    if (highlights.isEmpty) {
      return TextSpan(text: arabicText, style: baseStyle);
    }

    final spans = <TextSpan>[];
    var remaining = arabicText;
    while (remaining.isNotEmpty) {
      var earliestIndex = -1;
      var matchedWord = '';
      for (final word in highlights) {
        if (word.isEmpty) continue;
        final idx = remaining.indexOf(word);
        if (idx != -1 && (earliestIndex == -1 || idx < earliestIndex)) {
          earliestIndex = idx;
          matchedWord = word;
        }
      }
      if (earliestIndex == -1) {
        spans.add(TextSpan(text: remaining, style: baseStyle));
        break;
      }
      if (earliestIndex > 0) {
        spans.add(
          TextSpan(
            text: remaining.substring(0, earliestIndex),
            style: baseStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: matchedWord,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      );
      remaining = remaining.substring(earliestIndex + matchedWord.length);
    }
    return TextSpan(children: spans, style: baseStyle);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color accent;

  const _SectionTitle({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: accent, fontWeight: FontWeight.w700),
    );
  }
}
