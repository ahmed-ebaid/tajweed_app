import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/models/tajweed_models.dart';
import '../../core/providers/recitation_provider.dart';
import '../../core/services/audio_cache_service.dart';
import '../../core/services/hifz_content_service.dart';
import '../../core/services/quran_api_service.dart';
import '../../core/services/quran_content_sync_service.dart';
import '../../core/services/quran_asr_speech_input.dart';
import '../reader/memorization_screen.dart';
import 'quran_asr_experiment_screen.dart';

class HifzScreen extends StatefulWidget {
  final bool isActive;
  final HifzContentService? content;

  const HifzScreen({super.key, this.isActive = true, this.content});

  @override
  State<HifzScreen> createState() => _HifzScreenState();
}

class _HifzScreenState extends State<HifzScreen> {
  late final _content = widget.content ?? HifzContentService();
  final _audio = AudioPlayer();
  final _api = QuranApiService();
  final _audioCache = AudioCacheService();
  final _contentSync = QuranContentSyncService();
  List<Map<String, dynamic>>? _chapters;
  String _query = '';
  int _selected = 1;
  int _generation = 0;
  int _openingGeneration = 0;
  bool _loading = false;
  bool _opening = false;
  bool _stepByStep = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) unawaited(_loadChapters());
  }

  @override
  void didUpdateWidget(HifzScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && _chapters == null && !_loading) {
      unawaited(_loadChapters());
    }
    if (!widget.isActive && oldWidget.isActive) {
      ++_openingGeneration;
      unawaited(_stopReference());
    }
  }

  Future<void> _loadChapters() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final chapters = await _content.chapters();
      if (mounted) setState(() => _chapters = chapters);
    } catch (error) {
      debugPrint('Hifz chapter loading failed: $error');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _name(int number) =>
      _chapters!.firstWhere((chapter) => chapter['id'] == number)['name_arabic']
          as String;

  Future<void> _stopReference() async {
    ++_generation;
    await _audio.stop();
  }

  Future<bool> _playReference(Ayah ayah, int reciterId) async {
    final generation = ++_generation;
    final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
    try {
      var path = await _audioCache.getCachedAyahPath(
        reciterId: reciterId,
        surahNumber: ayah.surahNumber,
        ayahNumber: ayah.ayahNumber,
      );
      if (!mounted || generation != _generation) return false;
      var url = path == null ? ayah.audioUrl : null;
      if (path == null && (url == null || url.isEmpty)) {
        url = _contentSync.getCachedRecitationMap(
          reciterId: reciterId,
          surahNumber: ayah.surahNumber,
        )[key];
      }
      if (path == null && (url == null || url.isEmpty)) {
        final files = await _api
            .fetchAudioFilesWithTimings(
              reciterId: reciterId,
              surahNumber: ayah.surahNumber,
            )
            .timeout(const Duration(seconds: 20));
        url = files[key]?.url;
      }
      if (path == null && (url == null || url.isEmpty)) {
        url = _api.audioUrl(
          reciterId: reciterId,
          surahNumber: ayah.surahNumber,
          ayahNumber: ayah.ayahNumber,
        );
      }
      if (!mounted || generation != _generation) return false;
      if (path == null && (url == null || url.isEmpty)) {
        throw StateError('Missing Hifz reference audio');
      }
      await _audio.stop();
      if (!mounted || generation != _generation) return false;
      if (path != null) {
        await _audio.setFilePath(path);
      } else {
        await _audio.setUrl(url!);
        unawaited(
          _audioCache
              .cacheAyahAudio(
                reciterId: reciterId,
                surahNumber: ayah.surahNumber,
                ayahNumber: ayah.ayahNumber,
                url: url,
              )
              .then<void>((_) {}, onError: (_) {}),
        );
      }
      if (!mounted || generation != _generation) return false;
      unawaited(
        _audio.play().catchError((Object error) {
          debugPrint('Hifz reference playback failed: $error');
          if (mounted && generation == _generation) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).get('mem_audio_error'),
                ),
              ),
            );
          }
        }),
      );
      return true;
    } catch (error) {
      debugPrint('Hifz reference loading failed: $error');
      return false;
    }
  }

  Future<void> _open({required bool review}) async {
    if (_opening || _chapters == null) return;
    final selected = _selected;
    final openingGeneration = ++_openingGeneration;
    final reciter = context.read<RecitationProvider>().selectedReciterId;
    setState(() => _opening = true);
    try {
      final chapter = _chapters!.firstWhere(
        (chapter) => chapter['id'] == selected,
      );
      final ayahs = await _content.loadSurah(
        surahNumber: selected,
        expectedCount: chapter['verses_count'] as int,
        reciterId: reciter,
      );
      // Resolve the complete first page before entering practice. Later pages
      // are loaded on demand, never replaced by a selected-surah fragment.
      final firstPage = await _content.loadPage(
        ayahs.first.pageNumber,
        _chapters!,
      );
      if (!mounted ||
          !widget.isActive ||
          selected != _selected ||
          openingGeneration != _openingGeneration ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MemorizationScreen(
            localQuranLab:
                quranAsrExperimentEnabled &&
                !kIsWeb &&
                defaultTargetPlatform == TargetPlatform.iOS,
            speechInput:
                quranAsrExperimentEnabled &&
                    !kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.iOS
                ? QuranAsrSpeechInput()
                : null,
            ayahs: ayahs,
            loadPage: (page) => page == ayahs.first.pageNumber
                ? Future.value(firstPage)
                : _content.loadPage(page, _chapters!),
            surahNameFor: _name,
            review: review,
            continuous: !_stepByStep,
            playReference: (ayah) => _playReference(ayah, reciter),
            stopReference: _stopReference,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Hifz practice loading failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).get('mem_load_error')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chapters = _chapters?.where((chapter) {
      final name =
          '${chapter['id']} ${l10n.digits(chapter['id'] as int)} ${chapter['name_arabic']} '
          '${chapter['name_simple']} ${chapter['name_complex']}';
      return name.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    return SafeArea(
      child: Column(
        children: [
          if (HifzContentService.prelivePreviewEnabled)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'DEBUG: Quran Foundation prelive sandbox — limited surahs.',
                textAlign: TextAlign.center,
              ),
            ),
          if (quranAsrExperimentEnabled &&
              !kReleaseMode &&
              !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.iOS)
            TextButton(
              onPressed: () async {
                await _stopReference();
                if (!context.mounted) return;
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const QuranAsrExperimentScreen(),
                  ),
                );
              },
              child: Text(l10n.get('quran_asr_title')),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.get('tab_hifz'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              enabled: !_opening,
              onChanged: (query) => setState(() => _query = query),
              decoration: InputDecoration(
                labelText: l10n.get('hifz_select'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.get('mem_load_error'),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: _loadChapters,
                          child: Text(l10n.get('retry')),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      for (final chapter
                          in chapters ?? <Map<String, dynamic>>[])
                        ListTile(
                          selected: chapter['id'] == _selected,
                          leading: Text(l10n.digits(chapter['id'] as int)),
                          title: Text(
                            chapter['name_arabic'] as String,
                            textDirection: TextDirection.rtl,
                          ),
                          trailing: chapter['id'] == _selected
                              ? const Icon(Icons.check)
                              : null,
                          onTap: _opening
                              ? null
                              : () => setState(
                                  () => _selected = chapter['id'] as int,
                                ),
                        ),
                    ],
                  ),
          ),
          if (_chapters != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_name(_selected), textDirection: TextDirection.rtl),
                  SwitchListTile(
                    dense: true,
                    title: Text(l10n.get('hifz_step')),
                    value: _stepByStep,
                    onChanged: _opening
                        ? null
                        : (value) => setState(() => _stepByStep = value),
                  ),
                  if (_opening) const LinearProgressIndicator(),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _opening ? null : () => _open(review: true),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: Text(l10n.get('hifz_review')),
                      ),
                      FilledButton.icon(
                        onPressed: _opening ? null : () => _open(review: false),
                        icon: const Icon(Icons.mic_outlined),
                        label: Text(l10n.get('hifz_recite')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
