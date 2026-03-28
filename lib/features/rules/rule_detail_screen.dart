import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/models/tajweed_models.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/ayah_mapper.dart';
import '../../core/services/quran_api_service.dart';
import 'package:just_audio/just_audio.dart';

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
  bool _playing = false;
  Ayah? _exampleAyah;
  bool _loadingAyah = true;

  static const _audioBaseUrl =
      'https://verses.quran.com/AbdulBaset/Mujawwad/mp3';

  /// Each rule maps to a short verse that prominently demonstrates it.
  static const Map<TajweedRule, String> _exampleAudioCodes = {
    TajweedRule.ghunnah: '002006',
    TajweedRule.qalqalah: '113001',
    TajweedRule.maddTabeei: '001002',
    TajweedRule.maddMuttasil: '110001',
    TajweedRule.maddMunfasil: '002004',
    TajweedRule.maddLazim: '001007',
    TajweedRule.idghamWithGhunnah: '002008',
    TajweedRule.idghamWithoutGhunnah: '002005',
    TajweedRule.idghamShafawi: '002010',
    TajweedRule.idghamMutajanisayn: '011042',
    TajweedRule.ikhfa: '002010',
    TajweedRule.ikhfaShafawi: '002014',
    TajweedRule.iqlab: '002033',
    TajweedRule.izhar: '002007',
    TajweedRule.shaddah: '001001',
    TajweedRule.waqf: '002002',
    TajweedRule.hamzatWasl: '001001',
    TajweedRule.laamShamsiyah: '001003',
    TajweedRule.silent: '002002',
  };

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
    final code = _exampleAudioCodes[widget.definition.rule];
    if (code == null || code.length != 6) {
      if (mounted) setState(() => _loadingAyah = false);
      return;
    }

    final surah = int.tryParse(code.substring(0, 3));
    final ayah = int.tryParse(code.substring(3, 6));
    if (surah == null || ayah == null) {
      if (mounted) setState(() => _loadingAyah = false);
      return;
    }

    try {
      final langCode = context.read<LocaleProvider>().locale.languageCode;
      final verses = await _api.fetchVerses(
        surahNumber: surah,
        langCode: langCode,
        reciterId: 1,
        page: 1,
      );
      final target = verses.where((v) => (v['verse_key'] as String? ?? '') == '$surah:$ayah').toList();
      if (target.isNotEmpty) {
        final tajweed = await _api.fetchTajweedText(chapterNumber: surah);
        final verse = target.first;
        final mapped = AyahMapper.fromApi(
          verse,
          tajweedHtml: tajweed['$surah:$ayah'],
        );
        if (mounted) {
          setState(() {
            _exampleAyah = mapped;
            _loadingAyah = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _loadingAyah = false);
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final def = widget.definition;
    final rule = def.rule;

    return Scaffold(
      appBar: AppBar(
        title: Text(def.name(langCode)),
      ),
      body: SingleChildScrollView(
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
                    height: 1.7,
                  ),
            ),
            const SizedBox(height: 24),

            // ── Examples section ────────────────────────────────────────
            if (def.exampleArabic.isNotEmpty) ...[
              _SectionTitle(title: 'Examples'),
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
              _SectionTitle(title: 'Trigger Letters'),
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

            // ── Pronunciation guide ─────────────────────────────────────
            _PronunciationSection(
              rule: rule,
              langCode: langCode,
            ),
            const SizedBox(height: 24),

            // ── Hear pronunciation button ───────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final code = _exampleAudioCodes[def.rule];
                  if (code == null) return;
                  if (_playing) {
                    _audio.stop();
                    setState(() => _playing = false);
                  } else {
                    final url = '$_audioBaseUrl/$code.mp3';
                    _audio.playUrl(url);
                    setState(() => _playing = true);
                  }
                },
                icon: Icon(
                  _playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                  size: 18,
                ),
                label: Text(_playing ? 'Stop' : l10n.hearPronunciation),
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
    if (loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(12),
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
    }

    if (ayah == null) {
      return const SizedBox.shrink();
    }

    final headerText = isPlaying
        ? 'Now playing: ${ayah!.surahNumber}:${ayah!.ayahNumber}'
        : 'Playback ayah: ${ayah!.surahNumber}:${ayah!.ayahNumber}';

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
                isPlaying ? Icons.play_circle_fill_rounded : Icons.queue_music_rounded,
                size: 16,
                color: selectedRule.color,
              ),
              const SizedBox(width: 6),
              Text(
                headerText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selectedRule.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.rtl,
            child: RichText(
              textAlign: TextAlign.justify,
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 28,
                  height: 1.9,
                  color: Color(0xFF1A1A1A),
                ),
                children: _buildRuleFocusedSpans(ayah!, selectedRule),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Highlighted: ${selectedRule.arabicName}',
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

  List<InlineSpan> _buildRuleFocusedSpans(Ayah ayah, TajweedRule selectedRule) {
    if (ayah.tajweedSegments.isEmpty) {
      return [TextSpan(text: ayah.arabic)];
    }

    return ayah.tajweedSegments.map<InlineSpan>((segment) {
      final isSelected = segment.rule == selectedRule;
      final isUnTagged = segment.rule == null;
      final color = isSelected
          ? selectedRule.color
          : (isUnTagged ? const Color(0xFF1A1A1A) : const Color(0xFF8B8B8B));

      return TextSpan(
        text: segment.text,
        style: TextStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: 28,
          height: 1.9,
          color: color,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          backgroundColor: isSelected
              ? selectedRule.color.withValues(alpha: 0.16)
              : null,
        ),
      );
    }).toList();
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
        border: Border.all(color: rule.color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        children: [
          // Arabic name large
          Text(
            rule.arabicName,
            style: TextStyle(
              fontFamily: 'UthmanicHafs',
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: rule.color,
                    ),
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
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 0.04,
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
          fontFamily: 'UthmanicHafs',
          fontSize: 22,
          color: color,
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: 22,
          color: color,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

class _PronunciationSection extends StatelessWidget {
  final TajweedRule rule;
  final String langCode;

  const _PronunciationSection({
    required this.rule,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    final tips = _tipsFor(rule, langCode);
    if (tips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'How to Pronounce'),
        const SizedBox(height: 10),
        ...tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: rule.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  List<String> _tipsFor(TajweedRule rule, String langCode) {
    // English pronunciation tips — extend per language as needed
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
}
