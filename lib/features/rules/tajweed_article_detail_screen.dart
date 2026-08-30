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

class _TajweedArticleDetailScreenState
    extends State<TajweedArticleDetailScreen> {
  final AudioService _audio = AudioService();
  final QuranApiService _api = QuranApiService();
  bool _playing = false;
  bool _loadingAudio = false;
  String? _audioUrl;

  static const int _articleReciterId = 12; // Husary Al-Muallim

  @override
  void initState() {
    super.initState();
    _audio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playing = false);
      }
    });
  }

  ({int surah, int ayah})? get _reference =>
      RuleExampleReferences.referenceForArticle(widget.article.id);

  Future<void> _toggleExample() async {
    if (_playing) {
      _audio.stop();
      setState(() => _playing = false);
      return;
    }

    final existingUrl = QuranApiService.normalizeAudioUrl(_audioUrl);
    if (existingUrl != null) {
      _audio.playUrl(existingUrl);
      setState(() => _playing = true);
      return;
    }

    final ref = _reference;
    if (ref == null) return;

    setState(() => _loadingAudio = true);
    try {
      final langCode = context.read<LocaleProvider>().locale.languageCode;
      final verse = await _api.fetchVerse(
        surahNumber: ref.surah,
        ayahNumber: ref.ayah,
        langCode: langCode,
        reciterId: _articleReciterId,
      );
      final mapped = AyahMapper.fromApi(verse);
      final normalizedUrl = QuranApiService.normalizeAudioUrl(
        mapped.audioUrl,
      );
      if (normalizedUrl == null) {
        if (mounted) setState(() => _loadingAudio = false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _audioUrl = normalizedUrl;
        _loadingAudio = false;
      });
      _audio.playUrl(normalizedUrl);
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) setState(() => _loadingAudio = false);
    }
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
    final accent = article.category == TajweedArticleCategory.fundamentals
        ? const Color(0xFF176B5B)
        : const Color(0xFF6A4C93);
    final hasExample = _reference != null;

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
            if (hasExample) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadingAudio ? null : _toggleExample,
                  icon: _loadingAudio
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _playing
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _playing ? l10n.get('stop') : l10n.hearExample,
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
          ],
        ),
      ),
    );
  }
}
