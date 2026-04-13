import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/recitation_provider.dart';
import '../../core/providers/tafseer_provider.dart';
import '../../core/services/audio_cache_service.dart';
import '../../core/services/mushaf_assets_service.dart';
import '../../core/services/quran_offline_sync_service.dart';
import '../../core/services/quran_api_service.dart';
import 'language_selector_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = _SettingsStrings.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final recitationProvider = context.watch<RecitationProvider>();
    final tafseerProvider = context.watch<TafseerProvider>();
    final currentLang =
        LocaleProvider.languageNames[localeProvider.locale.languageCode] ??
            'English';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _SectionLabel(label: l10n.language),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.selectLanguage),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(currentLang,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LanguageSelectorScreen())),
          ),
          const Divider(height: 0.5, indent: 16),
          _SectionLabel(label: s.text('audio_section')),
          ListTile(
            leading: const Icon(Icons.record_voice_over_rounded),
            title: Text(s.text('default_reciter')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_reciterLabel(recitationProvider.selectedReciterId),
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
            onTap: () => _showReciterPicker(context),
          ),
          const Divider(height: 0.5, indent: 16),
          const _RecitationDownloadTile(),
          const Divider(height: 0.5, indent: 16),
          _SectionLabel(label: s.text('tafseer_section')),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: Text(s.text('tafseer_source')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    s.text('id_value', {'value': '${tafseerProvider.selectedTafsirId}'}),
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
            onTap: () => _showTafseerPicker(context),
          ),
          const Divider(height: 0.5, indent: 16),
          const _TafseerDownloadTile(),
          const Divider(height: 0.5, indent: 16),
          _SectionLabel(label: s.text('quran_data_section')),
          const _QuranDataTile(),
          const Divider(height: 0.5, indent: 16),
          _SectionLabel(label: s.text('mushaf_pages_section')),
          const _MushafPackTile(),
          const Divider(height: 0.5, indent: 16),
          _SectionLabel(label: s.text('about_section')),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(s.text('version')),
            trailing:
                Text('1.0.0', style: Theme.of(context).textTheme.bodyMedium),
          ),
          const Divider(height: 0.5, indent: 16),
          const _AboutSourcesTile(),
        ],
      ),
    );
  }

  static String _reciterLabel(int id) {
    const names = {
      1: 'AbdulBaset (Mujawwad)',
      2: 'AbdulBaset (Murattal)',
      3: 'Abdur-Rahman as-Sudais',
      4: 'Abu Bakr al-Shatri',
      5: 'Hani ar-Rifai',
      6: 'Al-Husary',
      8: 'Al-Minshawi (Mujawwad)',
      10: 'Sa`ud ash-Shuraym',
      11: 'Mohamed al-Tablawi',
      12: 'Al-Husary (Muallim)',
    };
    return names[id] ?? 'Reciter $id';
  }

  void _showReciterPicker(BuildContext context) {
    final api = QuranApiService();
    final s = _SettingsStrings.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AsyncPickerSheet<Map<String, dynamic>>(
        title: s.text('select_reciter'),
        fetchItems: () => api.fetchAvailableReciters(),
        itemTitle: (r) {
          final name = r['reciter_name'] as String? ?? '';
          final style = r['style'] as String?;
          return style != null ? '$name ($style)' : name;
        },
        isSelected: (r) =>
            (r['id'] as int?) ==
            context.read<RecitationProvider>().selectedReciterId,
        onSelect: (r) {
          final id = r['id'] as int;
          context.read<RecitationProvider>().setReciter(id);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showTafseerPicker(BuildContext context) {
    final api = QuranApiService();
    final s = _SettingsStrings.of(context);
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AsyncPickerSheet<Map<String, dynamic>>(
        title: s.text('select_tafseer'),
        fetchItems: () async {
          final all = await api.fetchAvailableTafsirs();
          // Map language names to our lang codes for filtering
          const langMap = {
            'en': 'english',
            'ar': 'arabic',
            'ur': 'urdu',
            'tr': 'turkish',
            'fr': 'french',
            'id': 'indonesian',
            'de': 'german',
            'es': 'spanish',
          };
          final target = langMap[langCode] ?? 'english';
          // Show tafsirs matching current language, plus all Arabic ones
          return all.where((t) {
            final lang = (t['language_name'] as String? ?? '').toLowerCase();
            return lang == target || lang == 'arabic';
          }).toList();
        },
        itemTitle: (t) => '${t['name'] ?? ''} — ${t['author_name'] ?? ''}',
        isSelected: (t) =>
            (t['id'] as int?) ==
            context.read<TafseerProvider>().selectedTafsirId,
        onSelect: (t) {
          final id = t['id'] as int;
          context.read<TafseerProvider>().setTafsir(id);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _RecitationDownloadTile extends StatefulWidget {
  const _RecitationDownloadTile();

  @override
  State<_RecitationDownloadTile> createState() => _RecitationDownloadTileState();
}

class _RecitationDownloadTileState extends State<_RecitationDownloadTile> {
  final QuranApiService _api = QuranApiService();
  final AudioCacheService _audioCache = AudioCacheService();
  bool _busy = false;
  bool _cancelBulkRecitation = false;

  Future<int?> _askSurahNumber() async {
    final s = _SettingsStrings.of(context);
    final controller = TextEditingController();
    String? error;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: Text(s.text('download_recitation')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.text('enter_surah_number')),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: s.text('surah_number_hint'),
                    errorText: error,
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(s.text('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(controller.text.trim());
                  if (value == null || value < 1 || value > 114) {
                    setLocalState(() {
                      error = s.text('invalid_surah_number');
                    });
                    return;
                  }
                  Navigator.pop(dialogContext, value);
                },
                child: Text(s.text('download')),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<bool> _downloadRecitationSurah({
    required int surahNumber,
    required int reciterId,
    bool showDialogProgress = true,
  }) async {
    final s = _SettingsStrings.of(context);
    final audioMap = await _api.fetchAudioFiles(
      reciterId: reciterId,
      surahNumber: surahNumber,
    );
    if (audioMap.isEmpty) return false;

    final progress = ValueNotifier<Map<String, int>>({'done': 0, 'total': 1});
    try {
      if (showDialogProgress && mounted) {
        unawaited(showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(s.text('downloading_recitation')),
            content: ValueListenableBuilder<Map<String, int>>(
              valueListenable: progress,
              builder: (_, value, __) {
                final done = value['done'] ?? 0;
                final total = (value['total'] ?? 1).clamp(1, 99999);
                final ratio = (done / total).clamp(0.0, 1.0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.text('surah_reciter_status', {
                        'surah': '$surahNumber',
                        'reciter': '$reciterId',
                      }),
                      style:
                          const TextStyle(fontSize: 12, color: Color(0xFF6E6E6E)),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: ratio),
                    const SizedBox(height: 8),
                    Text(s.text('downloaded_of_ayahs', {
                      'done': '$done',
                      'total': '$total',
                    })),
                  ],
                );
              },
            ),
          ),
        ));
      }

      await _audioCache.downloadSurah(
        reciterId: reciterId,
        surahNumber: surahNumber,
        audioUrls: audioMap,
        onProgress: (done, total) {
          progress.value = {'done': done, 'total': total};
        },
      );

      if (showDialogProgress && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return true;
    } finally {
      progress.dispose();
    }
  }

  Future<void> _downloadOne() async {
    if (_busy) return;
    final s = _SettingsStrings.of(context);
    final surahNumber = await _askSurahNumber();
    if (surahNumber == null) return;

    final reciterId = context.read<RecitationProvider>().selectedReciterId;
    setState(() => _busy = true);
    try {
      final ok = await _downloadRecitationSurah(
        surahNumber: surahNumber,
        reciterId: reciterId,
        showDialogProgress: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? s.text('recitation_surah_downloaded', {'surah': '$surahNumber'})
              : s.text('no_audio_urls_found', {'surah': '$surahNumber'})),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.text('recitation_download_failed', {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadAll() async {
    if (_busy) return;
    final s = _SettingsStrings.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(s.text('download_all_surahs_recitation')),
            content: Text(s.text('large_download_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.text('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.text('start')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final reciterId = context.read<RecitationProvider>().selectedReciterId;
    _cancelBulkRecitation = false;
    final progress = ValueNotifier<Map<String, int>>({
      'surahDone': 0,
      'surahTotal': 114,
      'currentSurah': 1,
    });

    setState(() => _busy = true);
    if (mounted) {
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(s.text('downloading_all_recitations')),
          content: ValueListenableBuilder<Map<String, int>>(
            valueListenable: progress,
            builder: (_, value, __) {
              final done = value['surahDone'] ?? 0;
              final total = value['surahTotal'] ?? 114;
              final currentSurah = value['currentSurah'] ?? 1;
              final ratio = (done / total).clamp(0.0, 1.0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.text('reciter_surah_compact', {
                    'reciter': '$reciterId',
                    'surah': '$currentSurah',
                  })),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: ratio),
                  const SizedBox(height: 8),
                  Text(s.text('completed_of_surahs', {
                    'done': '$done',
                    'total': '$total',
                  })),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _cancelBulkRecitation = true;
              },
              child: Text(s.text('stop')),
            ),
          ],
        ),
      ));
    }

    try {
      var surahDone = 0;
      for (int surah = 1; surah <= 114; surah++) {
        if (_cancelBulkRecitation) break;
        progress.value = {
          'surahDone': surahDone,
          'surahTotal': 114,
          'currentSurah': surah,
        };
        try {
          await _downloadRecitationSurah(
            surahNumber: surah,
            reciterId: reciterId,
            showDialogProgress: false,
          );
        } catch (_) {
          // Continue downloading remaining surahs.
        }
        surahDone++;
        if (_cancelBulkRecitation) break;
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_cancelBulkRecitation
                ? s.text('recitation_download_stopped')
                : s.text('all_surahs_recitation_completed')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.text('bulk_recitation_download_failed', {'error': '$e'}))),
        );
      }
    } finally {
      progress.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _SettingsStrings.of(context);
    final reciterId = context.watch<RecitationProvider>().selectedReciterId;
    return ListTile(
      leading: const Icon(Icons.download_for_offline_outlined),
      title: Text(s.text('offline_recitation_downloads')),
      subtitle: Text(s.text('reciter_id', {'id': '$reciterId'})),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'one') {
                  _downloadOne();
                } else if (value == 'all') {
                  _downloadAll();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'one', child: Text(s.text('download_one_surah'))),
                PopupMenuItem(value: 'all', child: Text(s.text('download_all_surahs'))),
              ],
            ),
    );
  }
}

class _TafseerDownloadTile extends StatefulWidget {
  const _TafseerDownloadTile();

  @override
  State<_TafseerDownloadTile> createState() => _TafseerDownloadTileState();
}

class _TafseerDownloadTileState extends State<_TafseerDownloadTile> {
  final QuranApiService _api = QuranApiService();
  final QuranOfflineSyncService _offlineSync = QuranOfflineSyncService();
  bool _busy = false;
  bool _cancelBulkTafseer = false;

  Future<List<String>> _fetchSurahVerseKeys({
    required int surahNumber,
    required String langCode,
  }) async {
    final keys = <String>[];
    var page = 1;
    while (true) {
      final verses = await _api.fetchVerses(
        surahNumber: surahNumber,
        langCode: langCode,
        page: page,
      );
      if (verses.isEmpty) break;

      for (final v in verses) {
        final key = v['verse_key'] as String?;
        if (key != null && key.isNotEmpty) keys.add(key);
      }
      if (verses.length < 50) break;
      page++;
    }

    final unique = keys.toSet().toList(growable: false)
      ..sort((a, b) {
        final aa = int.tryParse(a.split(':').last) ?? 0;
        final bb = int.tryParse(b.split(':').last) ?? 0;
        return aa.compareTo(bb);
      });
    return unique;
  }

  Future<int?> _askSurahNumber() async {
    final s = _SettingsStrings.of(context);
    final controller = TextEditingController();
    String? error;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: Text(s.text('download_tafseer')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.text('enter_surah_number')),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: s.text('surah_number_hint'),
                    errorText: error,
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(s.text('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(controller.text.trim());
                  if (value == null || value < 1 || value > 114) {
                    setLocalState(() {
                      error = s.text('invalid_surah_number');
                    });
                    return;
                  }
                  Navigator.pop(dialogContext, value);
                },
                child: Text(s.text('download')),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _downloadTafseerForSurah() async {
    if (_busy) return;
    final s = _SettingsStrings.of(context);
    final surahNumber = await _askSurahNumber();
    if (surahNumber == null) return;

    final tafsirId = context.read<TafseerProvider>().selectedTafsirId;
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final progress = ValueNotifier<Map<String, int>>({'done': 0, 'total': 1});

    setState(() => _busy = true);

    if (mounted) {
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(s.text('downloading_tafseer')),
          content: ValueListenableBuilder<Map<String, int>>(
            valueListenable: progress,
            builder: (_, value, __) {
              final done = value['done'] ?? 0;
              final total = (value['total'] ?? 1).clamp(1, 99999);
              final ratio = (done / total).clamp(0.0, 1.0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.text('surah_tafseer_status', {
                      'surah': '$surahNumber',
                      'id': '$tafsirId',
                    }),
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF6E6E6E)),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: ratio),
                  const SizedBox(height: 8),
                  Text(s.text('downloaded_of_ayahs', {
                    'done': '$done',
                    'total': '$total',
                  })),
                ],
              );
            },
          ),
        ),
      ));
    }

    try {
      final verseKeys = await _fetchSurahVerseKeys(
        surahNumber: surahNumber,
        langCode: langCode,
      );

      if (verseKeys.isEmpty) {
        throw Exception(s.text('no_verses_returned'));
      }

      final cached = await _offlineSync.getCachedTafsirMap(
        tafsirId: tafsirId,
        surahNumber: surahNumber,
      );
      final map = Map<String, String>.from(cached);

      final total = verseKeys.length;
      var done = 0;
      progress.value = {'done': done, 'total': total};

      for (final verseKey in verseKeys) {
        final existing = map[verseKey];
        if (existing != null && existing.trim().isNotEmpty) {
          done++;
          progress.value = {'done': done, 'total': total};
          continue;
        }

        final text = await _api.fetchTafsirForAyah(
          tafsirId: tafsirId,
          verseKey: verseKey,
        );
        map[verseKey] = text;
        done++;
        progress.value = {'done': done, 'total': total};
      }

      await _offlineSync.saveTafsirMap(
        tafsirId: tafsirId,
        surahNumber: surahNumber,
        tafsirMap: map,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.text('tafseer_surah_downloaded', {'surah': '$surahNumber'})),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.text('tafseer_download_failed', {'error': '$e'})),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      progress.dispose();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _downloadAllTafseer() async {
    if (_busy) return;
    final s = _SettingsStrings.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(s.text('download_all_surahs_tafseer')),
            content: Text(s.text('large_download_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.text('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.text('start')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final tafsirId = context.read<TafseerProvider>().selectedTafsirId;
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    _cancelBulkTafseer = false;
    final progress = ValueNotifier<Map<String, int>>({
      'surahDone': 0,
      'surahTotal': 114,
      'currentSurah': 1,
    });

    setState(() => _busy = true);
    if (mounted) {
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(s.text('downloading_all_tafseer')),
          content: ValueListenableBuilder<Map<String, int>>(
            valueListenable: progress,
            builder: (_, value, __) {
              final done = value['surahDone'] ?? 0;
              final total = value['surahTotal'] ?? 114;
              final currentSurah = value['currentSurah'] ?? 1;
              final ratio = (done / total).clamp(0.0, 1.0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.text('tafseer_id_surah_compact', {
                    'id': '$tafsirId',
                    'surah': '$currentSurah',
                  })),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: ratio),
                  const SizedBox(height: 8),
                  Text(s.text('completed_of_surahs', {
                    'done': '$done',
                    'total': '$total',
                  })),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _cancelBulkTafseer = true;
              },
              child: Text(s.text('stop')),
            ),
          ],
        ),
      ));
    }

    try {
      var surahDone = 0;
      for (int surah = 1; surah <= 114; surah++) {
        if (_cancelBulkTafseer) break;
        progress.value = {
          'surahDone': surahDone,
          'surahTotal': 114,
          'currentSurah': surah,
        };

        try {
          final verseKeys = await _fetchSurahVerseKeys(
            surahNumber: surah,
            langCode: langCode,
          );
          final cached = await _offlineSync.getCachedTafsirMap(
            tafsirId: tafsirId,
            surahNumber: surah,
          );
          final map = Map<String, String>.from(cached);

          for (final verseKey in verseKeys) {
            final existing = map[verseKey];
            if (existing != null && existing.trim().isNotEmpty) continue;
            final text = await _api.fetchTafsirForAyah(
              tafsirId: tafsirId,
              verseKey: verseKey,
            );
            map[verseKey] = text;
          }

          await _offlineSync.saveTafsirMap(
            tafsirId: tafsirId,
            surahNumber: surah,
            tafsirMap: map,
          );
        } catch (_) {
          // Continue with remaining surahs.
        }
        surahDone++;
        if (_cancelBulkTafseer) break;
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_cancelBulkTafseer
                ? s.text('tafseer_download_stopped')
                : s.text('all_surahs_tafseer_completed')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.text('bulk_tafseer_download_failed', {'error': '$e'}))),
        );
      }
    } finally {
      progress.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _SettingsStrings.of(context);
    final tafsirId = context.watch<TafseerProvider>().selectedTafsirId;
    return ListTile(
      leading: const Icon(Icons.download_for_offline_outlined),
      title: Text(s.text('download_tafseer_offline')),
      subtitle: Text(s.text('current_source_id', {'id': '$tafsirId'})),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'one') {
                  _downloadTafseerForSurah();
                } else if (value == 'all') {
                  _downloadAllTafseer();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'one', child: Text(s.text('download_one_surah'))),
                PopupMenuItem(value: 'all', child: Text(s.text('download_all_surahs'))),
              ],
            ),
      onTap: null,
    );
  }
}

class _QuranDataTile extends StatefulWidget {
  const _QuranDataTile();

  @override
  State<_QuranDataTile> createState() => _QuranDataTileState();
}

class _QuranDataTileState extends State<_QuranDataTile> {
  final QuranOfflineSyncService _syncService = QuranOfflineSyncService();

  QuranOfflineSyncStatus? _status;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _error = null);
    try {
      final status = await _syncService.getStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _sync({required bool force}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (force) {
        await _syncService.forceResync();
      } else {
        await _syncService.ensureBackgroundSync();
      }
      await _refreshStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _clear() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _syncService.clearQuranCache();
      await _refreshStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showDiagnostics() async {
    final s = _SettingsStrings.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final diagnostics = await _syncService.getDiagnostics(
        surahNumber: 7,
        ayahNumbers: const [101, 122],
      );
      if (!mounted) return;

      final report = diagnostics.toMultilineString();
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(s.text('quran_diagnostics_title')),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(report),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: report));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.text('diagnostics_copied'))),
                  );
                },
                child: Text(s.text('copy')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(s.text('close')),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _SettingsStrings.of(context);
    final status = _status;

    String subtitle;
    if (_busy) {
      subtitle = s.text('working');
    } else if (_error != null) {
      subtitle = s.text('error_syncing_quran_data');
    } else if (status == null) {
      subtitle = s.text('checking_status');
    } else if (status.completed) {
      final syncedAt =
          status.lastCompletedAt?.toLocal().toString() ?? 'unknown';
      subtitle = s.text('ready_status', {
        'synced': '${status.syncedSurahs}',
        'total': '${status.totalSurahs}',
        'time': syncedAt,
      });
    } else if (status.inProgress) {
      subtitle = s.text('syncing_surahs_status', {
        'synced': '${status.syncedSurahs}',
        'total': '${status.totalSurahs}',
      });
    } else {
      subtitle = s.text('not_fully_synced_status', {
        'synced': '${status.syncedSurahs}',
        'total': '${status.totalSurahs}',
      });
    }

    return ListTile(
      leading: const Icon(Icons.cloud_sync_outlined),
      title: Text(s.text('quran_text_offline')),
      subtitle: Text(subtitle),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'sync') {
                  _sync(force: false);
                } else if (value == 'resync') {
                  _sync(force: true);
                } else if (value == 'clear') {
                  _clear();
                } else if (value == 'refresh') {
                  _refreshStatus();
                } else if (value == 'diagnostics') {
                  _showDiagnostics();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'sync', child: Text(s.text('download_resume'))),
                PopupMenuItem(value: 'resync', child: Text(s.text('resync_all'))),
                PopupMenuItem(
                    value: 'clear', child: Text(s.text('clear_local_quran_cache'))),
                PopupMenuItem(value: 'refresh', child: Text(s.text('refresh_status'))),
                PopupMenuItem(
                    value: 'diagnostics', child: Text(s.text('show_diagnostics'))),
              ],
            ),
    );
  }
}

class _MushafPackTile extends StatefulWidget {
  const _MushafPackTile();

  @override
  State<_MushafPackTile> createState() => _MushafPackTileState();
}

class _MushafPackTileState extends State<_MushafPackTile> {
  MushafAssetsStatus? _status;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _error = null;
    });
    try {
      final status = await MushafAssetsService.getStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _download({required bool force}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (force) {
        await MushafAssetsService.forceRedownload();
      } else {
        await MushafAssetsService.getMushafPagesDir();
      }
      await _refreshStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deletePack() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await MushafAssetsService.clearMushafPages();
      await _refreshStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _SettingsStrings.of(context);
    final status = _status;
    final installed = status?.installed ?? false;

    String subtitle;
    if (_busy) {
      subtitle = s.text('working');
    } else if (_error != null) {
      subtitle = s.text('error_pack_checking');
    } else if (status == null) {
      subtitle = s.text('checking_status');
    } else if (installed) {
      subtitle = s.text('installed_pages', {'count': '${status.pageCount}'});
    } else {
      subtitle = s.text('not_installed_yet', {
        'count': '${status.pageCount}',
        'expected': '${MushafAssetsService.expectedPageCount}',
      });
    }

    return ListTile(
      leading: const Icon(Icons.image_outlined),
      title: Text(s.text('mushaf_image_pack')),
      subtitle: Text(subtitle),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'download') {
                  _download(force: false);
                } else if (value == 'redownload') {
                  _download(force: true);
                } else if (value == 'delete') {
                  _deletePack();
                } else if (value == 'refresh') {
                  _refreshStatus();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'download', child: Text(s.text('download'))),
                PopupMenuItem(value: 'redownload', child: Text(s.text('redownload'))),
                PopupMenuItem(
                    value: 'delete', child: Text(s.text('delete_local_pack'))),
                PopupMenuItem(value: 'refresh', child: Text(s.text('refresh_status'))),
              ],
            ),
    );
  }
}

class _AboutSourcesTile extends StatelessWidget {
  const _AboutSourcesTile();

  @override
  Widget build(BuildContext context) {
    final s = _SettingsStrings.of(context);
    return ListTile(
      leading: const Icon(Icons.copyright_outlined),
      title: Text(s.text('about_this_app')),
      subtitle: Text(s.text('quran_sources_ownership')),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => const _AboutSourcesSheet(),
      ),
    );
  }
}

class _AboutSourcesSheet extends StatelessWidget {
  const _AboutSourcesSheet();

  static const List<MapEntry<String, String>> _translationSources = [
    MapEntry('English', 'Dr. Mustafa Khattab'),
    MapEntry('Arabic', 'Muhammad Taqi-ud-Din al-Hilali'),
    MapEntry('Urdu', 'Fateh Muhammad Jalandhari'),
    MapEntry('Turkish', 'Diyanet Isleri'),
    MapEntry('French', 'Muhammad Hamidullah'),
    MapEntry('Indonesian', 'Indonesian Ministry of Religious Affairs'),
    MapEntry('German', 'Adul Hye and Ahmad von Denffer'),
    MapEntry('Spanish', 'Fallback to Dr. Mustafa Khattab (English)'),
  ];

  static const List<MapEntry<String, String>> _defaultTafsirSources = [
    MapEntry('English', 'Ibn Kathir (Abridged)'),
    MapEntry('Arabic', 'Tafsir Muyassar'),
    MapEntry('Urdu', 'Tafsir Ibn Kathir (Urdu)'),
    MapEntry('Turkish', 'Diyanet Isleri'),
    MapEntry('French', 'Muhammad Hamidullah'),
    MapEntry('Indonesian', 'Quran.com resource ID 33'),
    MapEntry('German', 'Quran.com resource ID 27'),
    MapEntry('Spanish', 'Fallback to Ibn Kathir (Abridged) in English'),
  ];

  static const List<String> _supportedReciters = [
    'AbdulBaset (Mujawwad)',
    'AbdulBaset (Murattal)',
    'Abdur-Rahman as-Sudais',
    'Abu Bakr al-Shatri',
    'Hani ar-Rifai',
    'Al-Husary',
    'Al-Minshawi (Mujawwad)',
    'Al-Minshawi (Murattal)',
    'Sa`ud ash-Shuraym',
    'Mohamed al-Tablawi',
    'Al-Husary (Muallim)',
  ];

  @override
  Widget build(BuildContext context) {
    final s = _SettingsStrings.of(context);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.text('about_this_app'),
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: s.text('close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s.text('owned_operated'),
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              _AboutSectionTitle(title: s.text('quran_sources_title')),
              _AboutBullet(text: s.text('quran_b1')),
              _AboutBullet(text: s.text('quran_b2')),
              _AboutBullet(text: s.text('quran_b3')),
              ..._translationSources.map(
                (entry) => _AboutSourceLine(label: entry.key, value: entry.value),
              ),
              _AboutBullet(text: s.text('quran_b4')),
              const SizedBox(height: 20),
              _AboutSectionTitle(title: s.text('tafseer_sources_title')),
              _AboutBullet(text: s.text('tafseer_b1')),
              _AboutBullet(text: s.text('tafseer_b2')),
              ..._defaultTafsirSources.map(
                (entry) => _AboutSourceLine(label: entry.key, value: entry.value),
              ),
              _AboutBullet(text: s.text('tafseer_b3')),
              const SizedBox(height: 12),
              _AboutSectionTitle(title: s.text('recitation_sources_title')),
              _AboutBullet(text: s.text('recitation_b1')),
              _AboutBullet(text: s.text('recitation_b2')),
              _AboutBullet(text: s.text('recitation_b3')),
              ..._supportedReciters.map(
                (name) => _AboutSourceLine(label: s.text('reciter_label'), value: name),
              ),
              const SizedBox(height: 12),
              _AboutSectionTitle(title: s.text('other_sources_title')),
              _AboutBullet(text: s.text('other_b1')),
              _AboutBullet(text: s.text('other_b2')),
              _AboutBullet(text: s.text('other_b3')),
              const SizedBox(height: 12),
              Text(
                'Version 1.0.0',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutSectionTitle extends StatelessWidget {
  final String title;

  const _AboutSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _AboutSourceLine extends StatelessWidget {
  final String label;
  final String value;

  const _AboutSourceLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _AboutBullet extends StatelessWidget {
  final String text;

  const _AboutBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF1D9E75),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic async picker bottom sheet — fetches items then displays a list.
class _AsyncPickerSheet<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function() fetchItems;
  final String Function(T) itemTitle;
  final bool Function(T) isSelected;
  final void Function(T) onSelect;

  const _AsyncPickerSheet({
    required this.title,
    required this.fetchItems,
    required this.itemTitle,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  State<_AsyncPickerSheet<T>> createState() => _AsyncPickerSheetState<T>();
}

class _AsyncPickerSheetState<T> extends State<_AsyncPickerSheet<T>> {
  List<T>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.fetchItems();
      if (mounted)
        setState(() {
          _items = items;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 0.5),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items == null || _items!.isEmpty
                    ? Center(child: Text(_SettingsStrings.of(context).text('no_items_available')))
                    : ListView.separated(
                        controller: controller,
                        itemCount: _items!.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 0.5, indent: 16),
                        itemBuilder: (_, i) {
                          final item = _items![i];
                          final selected = widget.isSelected(item);
                          return ListTile(
                            title: Text(widget.itemTitle(item)),
                            trailing: selected
                                ? const Icon(Icons.check_circle,
                                    color: Color(0xFF1D9E75), size: 20)
                                : null,
                            onTap: () => widget.onSelect(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SettingsStrings {
  final String _languageCode;

  const _SettingsStrings._(this._languageCode);

  factory _SettingsStrings.of(BuildContext context) {
    return _SettingsStrings._(Localizations.localeOf(context).languageCode);
  }

  static final Map<String, Map<String, String>> _localized = {
    'en': {
      'audio_section': 'Audio',
      'default_reciter': 'Default reciter',
      'tafseer_section': 'Tafseer',
      'tafseer_source': 'Tafseer source',
      'quran_data_section': 'Quran Data',
      'mushaf_pages_section': 'Mushaf Pages',
      'about_section': 'About',
      'version': 'Version',
      'id_value': 'ID: {value}',
      'select_reciter': 'Select Reciter',
      'select_tafseer': 'Select Tafseer',
      'download_recitation': 'Download Recitation',
      'enter_surah_number': 'Enter surah number (1-114)',
      'surah_number_hint': 'e.g. 1',
      'cancel': 'Cancel',
      'download': 'Download',
      'invalid_surah_number': 'Please enter a number between 1 and 114',
      'downloading_recitation': 'Downloading recitation',
      'downloaded_of_ayahs': 'Downloaded {done} of {total} ayahs',
      'surah_reciter_status': 'Surah {surah} · Reciter {reciter}',
      'recitation_surah_downloaded': 'Recitation for surah {surah} downloaded.',
      'no_audio_urls_found': 'No audio URLs found for surah {surah}.',
      'recitation_download_failed': 'Recitation download failed: {error}',
      'download_all_surahs_recitation': 'Download all surahs recitation',
      'large_download_confirm': 'This may take significant storage and time. Continue?',
      'start': 'Start',
      'downloading_all_recitations': 'Downloading all recitations',
      'reciter_surah_compact': 'Reciter {reciter} • Surah {surah}',
      'completed_of_surahs': 'Completed {done} of {total} surahs',
      'stop': 'Stop',
      'recitation_download_stopped': 'Recitation download stopped.',
      'all_surahs_recitation_completed': 'All surahs recitation download completed.',
      'bulk_recitation_download_failed': 'Bulk recitation download failed: {error}',
      'offline_recitation_downloads': 'Offline recitation downloads',
      'reciter_id': 'Reciter ID: {id}',
      'download_one_surah': 'Download one surah',
      'download_all_surahs': 'Download all surahs',
      'download_tafseer': 'Download Tafseer',
      'downloading_tafseer': 'Downloading tafseer',
      'surah_tafseer_status': 'Surah {surah} · Tafseer ID {id}',
      'no_verses_returned': 'No verses returned for this surah.',
      'tafseer_surah_downloaded': 'Tafseer for surah {surah} downloaded.',
      'tafseer_download_failed': 'Tafseer download failed: {error}',
      'download_all_surahs_tafseer': 'Download all surahs tafseer',
      'downloading_all_tafseer': 'Downloading all tafseer',
      'tafseer_id_surah_compact': 'Tafseer ID {id} • Surah {surah}',
      'tafseer_download_stopped': 'Tafseer download stopped.',
      'all_surahs_tafseer_completed': 'All surahs tafseer download completed.',
      'bulk_tafseer_download_failed': 'Bulk tafseer download failed: {error}',
      'download_tafseer_offline': 'Download tafseer for offline',
      'current_source_id': 'Current source ID: {id}',
      'quran_diagnostics_title': 'Quran Diagnostics (7:101, 7:122)',
      'diagnostics_copied': 'Diagnostics copied',
      'copy': 'Copy',
      'close': 'Close',
      'working': 'Working...',
      'error_syncing_quran_data': 'Error while syncing Quran data',
      'checking_status': 'Checking status...',
      'ready_status': 'Ready ({synced}/{total}) • Last sync: {time}',
      'syncing_surahs_status': 'Syncing {synced}/{total} surahs...',
      'not_fully_synced_status': 'Not fully synced ({synced}/{total})',
      'quran_text_offline': 'Quran text (offline)',
      'download_resume': 'Download / Resume',
      'resync_all': 'Re-sync all',
      'clear_local_quran_cache': 'Clear local Quran cache',
      'refresh_status': 'Refresh status',
      'show_diagnostics': 'Show diagnostics',
      'error_pack_checking': 'Error while checking/downloading pack',
      'installed_pages': 'Installed ({count} pages)',
      'not_installed_yet': 'Not installed yet ({count}/{expected} pages)',
      'mushaf_image_pack': 'Mushaf image pack',
      'redownload': 'Re-download',
      'delete_local_pack': 'Delete local pack',
      'about_this_app': 'About this app',
      'quran_sources_ownership': 'Quran sources and ownership',
      'owned_operated': 'This app is owned and operated by Ebaid LLC.',
      'quran_sources_title': 'Quran sources',
      'quran_b1': 'Quran text, surah and ayah structure, word-by-word data, and tajweed markup are fetched from the Quran.com API v4.',
      'quran_b2': 'The app uses these translation sources for its supported interface languages:',
      'quran_b3': 'When you switch the app language, the app requests the matching translation for that language. If a translation is unavailable, it falls back to English.',
      'quran_b4': 'Remote Mushaf page references point to Quran CDN page images hosted at cdn.qurancdn.com and static.qurancdn.com.',
      'tafseer_sources_title': 'Tafseer sources',
      'tafseer_b1': 'The tafseer catalog and verse-by-verse tafseer text are loaded from Quran.com API v4 resources and tafsir endpoints.',
      'tafseer_b2': 'Default tafseer sources configured by app language are:',
      'tafseer_b3': 'Users can switch to other tafseer sources returned by Quran.com through the in-app tafseer picker.',
      'recitation_sources_title': 'Recitation sources',
      'recitation_b1': 'The recitation catalog is loaded from Quran.com API v4 resource endpoints.',
      'recitation_b2': 'Verse audio playback and downloadable recitation files are served from the Quran.com audio CDN at verses.quran.com.',
      'recitation_b3': 'This app currently supports these reciters:',
      'reciter_label': 'Reciter',
      'other_sources_title': 'Other content sources',
      'other_b1': 'Tajweed rule definitions used in lessons and quizzes are bundled locally in assets/tajweed/rules_db.json.',
      'other_b2': 'Offline Mushaf page images were originally sourced from the GovarJabbar/Quran-PNG repository on GitHub and are distributed in this app through its downloadable image pack hosted on GitHub Releases.',
      'other_b3': 'Quranic display in the app uses the bundled UthmanicHafs font asset for Mushaf-style rendering.',
      'no_items_available': 'No items available',
    },
    'ar': {
      'audio_section': 'الصوت',
      'default_reciter': 'القارئ الافتراضي',
      'tafseer_section': 'التفسير',
      'tafseer_source': 'مصدر التفسير',
      'quran_data_section': 'بيانات القرآن',
      'mushaf_pages_section': 'صفحات المصحف',
      'about_section': 'حول',
      'version': 'الإصدار',
      'id_value': 'المعرف: {value}',
      'select_reciter': 'اختر القارئ',
      'select_tafseer': 'اختر التفسير',
      'download_recitation': 'تنزيل التلاوة',
      'enter_surah_number': 'أدخل رقم السورة (1-114)',
      'surah_number_hint': 'مثال: 1',
      'cancel': 'إلغاء',
      'download': 'تنزيل',
      'invalid_surah_number': 'يرجى إدخال رقم بين 1 و114',
      'downloading_recitation': 'جارٍ تنزيل التلاوة',
      'downloaded_of_ayahs': 'تم تنزيل {done} من {total} آيات',
      'surah_reciter_status': 'سورة {surah} · القارئ {reciter}',
      'recitation_surah_downloaded': 'تم تنزيل تلاوة السورة {surah}.',
      'no_audio_urls_found': 'لم يتم العثور على روابط صوتية للسورة {surah}.',
      'recitation_download_failed': 'فشل تنزيل التلاوة: {error}',
      'download_all_surahs_recitation': 'تنزيل تلاوة جميع السور',
      'large_download_confirm': 'قد يتطلب هذا وقتاً ومساحة تخزين كبيرة. هل تريد المتابعة؟',
      'start': 'ابدأ',
      'downloading_all_recitations': 'جارٍ تنزيل جميع التلاوات',
      'reciter_surah_compact': 'القارئ {reciter} • السورة {surah}',
      'completed_of_surahs': 'اكتمل {done} من {total} سور',
      'stop': 'إيقاف',
      'recitation_download_stopped': 'تم إيقاف تنزيل التلاوة.',
      'all_surahs_recitation_completed': 'اكتمل تنزيل تلاوات جميع السور.',
      'bulk_recitation_download_failed': 'فشل تنزيل التلاوات دفعة واحدة: {error}',
      'offline_recitation_downloads': 'تنزيلات التلاوة دون اتصال',
      'reciter_id': 'معرف القارئ: {id}',
      'download_one_surah': 'تنزيل سورة واحدة',
      'download_all_surahs': 'تنزيل جميع السور',
      'download_tafseer': 'تنزيل التفسير',
      'downloading_tafseer': 'جارٍ تنزيل التفسير',
      'surah_tafseer_status': 'سورة {surah} · معرف التفسير {id}',
      'no_verses_returned': 'لم يتم إرجاع آيات لهذه السورة.',
      'tafseer_surah_downloaded': 'تم تنزيل تفسير السورة {surah}.',
      'tafseer_download_failed': 'فشل تنزيل التفسير: {error}',
      'download_all_surahs_tafseer': 'تنزيل تفسير جميع السور',
      'downloading_all_tafseer': 'جارٍ تنزيل جميع التفاسير',
      'tafseer_id_surah_compact': 'معرف التفسير {id} • السورة {surah}',
      'tafseer_download_stopped': 'تم إيقاف تنزيل التفسير.',
      'all_surahs_tafseer_completed': 'اكتمل تنزيل تفسير جميع السور.',
      'bulk_tafseer_download_failed': 'فشل تنزيل التفسير دفعة واحدة: {error}',
      'download_tafseer_offline': 'تنزيل التفسير للاستخدام دون اتصال',
      'current_source_id': 'معرف المصدر الحالي: {id}',
      'quran_diagnostics_title': 'تشخيص القرآن (7:101، 7:122)',
      'diagnostics_copied': 'تم نسخ التشخيص',
      'copy': 'نسخ',
      'close': 'إغلاق',
      'working': 'جارٍ العمل...',
      'error_syncing_quran_data': 'خطأ أثناء مزامنة بيانات القرآن',
      'checking_status': 'جارٍ التحقق من الحالة...',
      'ready_status': 'جاهز ({synced}/{total}) • آخر مزامنة: {time}',
      'syncing_surahs_status': 'جارٍ مزامنة {synced}/{total} سورة...',
      'not_fully_synced_status': 'غير مكتمل ({synced}/{total})',
      'quran_text_offline': 'النص القرآني (دون اتصال)',
      'download_resume': 'تنزيل / متابعة',
      'resync_all': 'إعادة مزامنة الكل',
      'clear_local_quran_cache': 'مسح ذاكرة القرآن المحلية',
      'refresh_status': 'تحديث الحالة',
      'show_diagnostics': 'عرض التشخيص',
      'error_pack_checking': 'خطأ أثناء فحص/تنزيل الحزمة',
      'installed_pages': 'مثبت ({count} صفحة)',
      'not_installed_yet': 'غير مثبت بعد ({count}/{expected} صفحات)',
      'mushaf_image_pack': 'حزمة صور المصحف',
      'redownload': 'إعادة التنزيل',
      'delete_local_pack': 'حذف الحزمة المحلية',
      'about_this_app': 'حول هذا التطبيق',
      'quran_sources_ownership': 'مصادر القرآن والملكية',
      'owned_operated': 'هذا التطبيق مملوك ومدار بواسطة شركة Ebaid LLC.',
      'quran_sources_title': 'مصادر القرآن',
      'quran_b1': 'يتم جلب نص القرآن وبنية السور والآيات وبيانات الكلمات وعلامات التجويد من واجهة Quran.com API v4.',
      'quran_b2': 'يستخدم التطبيق مصادر الترجمة التالية للغات الواجهة المدعومة:',
      'quran_b3': 'عند تغيير لغة التطبيق، يطلب التطبيق الترجمة المطابقة لتلك اللغة. وإذا لم تتوفر ترجمة، يعود إلى الإنجليزية.',
      'quran_b4': 'تشير مراجع صفحات المصحف البعيدة إلى صور صفحات مستضافة على cdn.qurancdn.com و static.qurancdn.com.',
      'tafseer_sources_title': 'مصادر التفسير',
      'tafseer_b1': 'يتم تحميل فهرس التفسير ونصوص التفسير لكل آية من موارد ونهايات tafsir في Quran.com API v4.',
      'tafseer_b2': 'مصادر التفسير الافتراضية حسب لغة التطبيق هي:',
      'tafseer_b3': 'يمكن للمستخدمين التبديل إلى مصادر تفسير أخرى يعرضها Quran.com من خلال منتقي التفسير داخل التطبيق.',
      'recitation_sources_title': 'مصادر التلاوة',
      'recitation_b1': 'يتم تحميل فهرس التلاوات من نهايات الموارد في Quran.com API v4.',
      'recitation_b2': 'يتم تقديم تشغيل صوت الآيات وملفات التلاوة القابلة للتنزيل من شبكة Quran.com الصوتية على verses.quran.com.',
      'recitation_b3': 'يدعم هذا التطبيق حالياً هؤلاء القراء:',
      'reciter_label': 'القارئ',
      'other_sources_title': 'مصادر محتوى أخرى',
      'other_b1': 'يتم تضمين تعريفات أحكام التجويد المستخدمة في الدروس والاختبارات محلياً في assets/tajweed/rules_db.json.',
      'other_b2': 'تم الحصول على صور صفحات المصحف غير المتصلة في الأصل من مستودع GovarJabbar/Quran-PNG على GitHub ويتم توزيعها في هذا التطبيق عبر حزمة الصور القابلة للتنزيل والمستضافة على GitHub Releases.',
      'other_b3': 'يستخدم عرض القرآن في التطبيق خط UthmanicHafs المضمن لإظهار نمط المصحف.',
      'no_items_available': 'لا توجد عناصر متاحة',
    },
    'ur': {
      'audio_section': 'آڈیو',
      'default_reciter': 'ڈیفالٹ قاری',
      'tafseer_section': 'تفسیر',
      'tafseer_source': 'تفسیر کا ماخذ',
      'quran_data_section': 'قرآن کا ڈیٹا',
      'mushaf_pages_section': 'مصحف کے صفحات',
      'about_section': 'تعارف',
      'version': 'ورژن',
      'id_value': 'آئی ڈی: {value}',
      'select_reciter': 'قاری منتخب کریں',
      'select_tafseer': 'تفسیر منتخب کریں',
      'download_recitation': 'تلاوت ڈاؤن لوڈ کریں',
      'enter_surah_number': 'سورہ نمبر درج کریں (1-114)',
      'surah_number_hint': 'مثلاً 1',
      'cancel': 'منسوخ',
      'download': 'ڈاؤن لوڈ',
      'invalid_surah_number': 'براہ کرم 1 سے 114 کے درمیان نمبر درج کریں',
      'downloading_recitation': 'تلاوت ڈاؤن لوڈ ہو رہی ہے',
      'downloaded_of_ayahs': '{total} میں سے {done} آیات ڈاؤن لوڈ ہوئیں',
      'surah_reciter_status': 'سورہ {surah} · قاری {reciter}',
      'recitation_surah_downloaded': 'سورہ {surah} کی تلاوت ڈاؤن لوڈ ہو گئی۔',
      'no_audio_urls_found': 'سورہ {surah} کے لیے آڈیو روابط نہیں ملے۔',
      'recitation_download_failed': 'تلاوت ڈاؤن لوڈ ناکام: {error}',
      'download_all_surahs_recitation': 'تمام سورتوں کی تلاوت ڈاؤن لوڈ کریں',
      'large_download_confirm': 'اس میں کافی وقت اور اسٹوریج لگ سکتی ہے۔ کیا جاری رکھنا ہے؟',
      'start': 'شروع کریں',
      'downloading_all_recitations': 'تمام تلاوتیں ڈاؤن لوڈ ہو رہی ہیں',
      'reciter_surah_compact': 'قاری {reciter} • سورہ {surah}',
      'completed_of_surahs': '{total} میں سے {done} سورتیں مکمل',
      'stop': 'روکیں',
      'recitation_download_stopped': 'تلاوت کا ڈاؤن لوڈ روک دیا گیا۔',
      'all_surahs_recitation_completed': 'تمام سورتوں کی تلاوت کا ڈاؤن لوڈ مکمل ہو گیا۔',
      'bulk_recitation_download_failed': 'اجتماعی تلاوت ڈاؤن لوڈ ناکام: {error}',
      'offline_recitation_downloads': 'آف لائن تلاوت ڈاؤن لوڈز',
      'reciter_id': 'قاری آئی ڈی: {id}',
      'download_one_surah': 'ایک سورہ ڈاؤن لوڈ کریں',
      'download_all_surahs': 'تمام سورتیں ڈاؤن لوڈ کریں',
      'download_tafseer': 'تفسیر ڈاؤن لوڈ کریں',
      'downloading_tafseer': 'تفسیر ڈاؤن لوڈ ہو رہی ہے',
      'surah_tafseer_status': 'سورہ {surah} · تفسیر آئی ڈی {id}',
      'no_verses_returned': 'اس سورہ کے لیے کوئی آیات واپس نہیں آئیں۔',
      'tafseer_surah_downloaded': 'سورہ {surah} کی تفسیر ڈاؤن لوڈ ہو گئی۔',
      'tafseer_download_failed': 'تفسیر ڈاؤن لوڈ ناکام: {error}',
      'download_all_surahs_tafseer': 'تمام سورتوں کی تفسیر ڈاؤن لوڈ کریں',
      'downloading_all_tafseer': 'تمام تفاسیر ڈاؤن لوڈ ہو رہی ہیں',
      'tafseer_id_surah_compact': 'تفسیر آئی ڈی {id} • سورہ {surah}',
      'tafseer_download_stopped': 'تفسیر کا ڈاؤن لوڈ روک دیا گیا۔',
      'all_surahs_tafseer_completed': 'تمام سورتوں کی تفسیر کا ڈاؤن لوڈ مکمل ہو گیا۔',
      'bulk_tafseer_download_failed': 'اجتماعی تفسیر ڈاؤن لوڈ ناکام: {error}',
      'download_tafseer_offline': 'آف لائن کے لیے تفسیر ڈاؤن لوڈ کریں',
      'current_source_id': 'موجودہ ماخذ آئی ڈی: {id}',
      'quran_diagnostics_title': 'قرآن تشخیص (7:101، 7:122)',
      'diagnostics_copied': 'تشخیص کا متن کاپی ہو گیا',
      'copy': 'کاپی',
      'close': 'بند کریں',
      'working': 'کام جاری ہے...',
      'error_syncing_quran_data': 'قرآن ڈیٹا ہم آہنگ کرتے وقت خرابی',
      'checking_status': 'حالت چیک کی جا رہی ہے...',
      'ready_status': 'تیار ({synced}/{total}) • آخری ہم آہنگی: {time}',
      'syncing_surahs_status': '{synced}/{total} سورتیں ہم آہنگ ہو رہی ہیں...',
      'not_fully_synced_status': 'ابھی مکمل ہم آہنگ نہیں ({synced}/{total})',
      'quran_text_offline': 'قرآنی متن (آف لائن)',
      'download_resume': 'ڈاؤن لوڈ / جاری رکھیں',
      'resync_all': 'سب دوبارہ ہم آہنگ کریں',
      'clear_local_quran_cache': 'مقامی قرآن کیش صاف کریں',
      'refresh_status': 'حالت تازہ کریں',
      'show_diagnostics': 'تشخیص دکھائیں',
      'error_pack_checking': 'پیک چیک/ڈاؤن لوڈ کرتے وقت خرابی',
      'installed_pages': 'انسٹال شدہ ({count} صفحات)',
      'not_installed_yet': 'ابھی انسٹال نہیں ({count}/{expected} صفحات)',
      'mushaf_image_pack': 'مصحف تصویری پیک',
      'redownload': 'دوبارہ ڈاؤن لوڈ',
      'delete_local_pack': 'مقامی پیک حذف کریں',
      'about_this_app': 'اس ایپ کے بارے میں',
      'quran_sources_ownership': 'قرآن کے ماخذ اور ملکیت',
      'owned_operated': 'یہ ایپ Ebaid LLC کی ملکیت ہے اور اسی کے زیر انتظام ہے۔',
      'quran_sources_title': 'قرآن کے ماخذ',
      'quran_b1': 'قرآن کا متن، سورہ اور آیت کی ساخت، لفظ بہ لفظ ڈیٹا، اور تجوید مارک اپ Quran.com API v4 سے حاصل کیے جاتے ہیں۔',
      'quran_b2': 'ایپ اپنی معاون زبانوں کے لیے یہ ترجمہ جاتی ماخذ استعمال کرتی ہے:',
      'quran_b3': 'جب آپ ایپ کی زبان تبدیل کرتے ہیں تو ایپ اسی زبان کا ترجمہ مانگتی ہے۔ اگر ترجمہ دستیاب نہ ہو تو انگریزی استعمال ہوتی ہے۔',
      'quran_b4': 'آن لائن مصحف صفحات کے روابط cdn.qurancdn.com اور static.qurancdn.com پر موجود تصاویر کی طرف اشارہ کرتے ہیں۔',
      'tafseer_sources_title': 'تفسیر کے ماخذ',
      'tafseer_b1': 'تفسیر کی فہرست اور آیت بہ آیت تفسیر کا متن Quran.com API v4 کے وسائل اور tafsir endpoints سے لوڈ ہوتا ہے۔',
      'tafseer_b2': 'ایپ کی زبان کے مطابق طے شدہ تفسیر کے ماخذ یہ ہیں:',
      'tafseer_b3': 'صارف ایپ کے اندر موجود تفسیر منتخب کنندہ کے ذریعے Quran.com کی دیگر تفاسیر بھی منتخب کر سکتے ہیں۔',
      'recitation_sources_title': 'تلاوت کے ماخذ',
      'recitation_b1': 'تلاوت کی فہرست Quran.com API v4 کے resource endpoints سے لوڈ ہوتی ہے۔',
      'recitation_b2': 'آیات کی آڈیو پلے بیک اور ڈاؤن لوڈ ایبل تلاوت فائلیں verses.quran.com پر Quran.com آڈیو CDN سے دی جاتی ہیں۔',
      'recitation_b3': 'یہ ایپ فی الحال ان قراء کی حمایت کرتی ہے:',
      'reciter_label': 'قاری',
      'other_sources_title': 'دیگر مواد کے ماخذ',
      'other_b1': 'اسباق اور کوئز میں استعمال ہونے والے تجوید قوانین کی تعریفیں assets/tajweed/rules_db.json میں مقامی طور پر شامل ہیں۔',
      'other_b2': 'آف لائن مصحف تصاویر اصل میں GitHub کے GovarJabbar/Quran-PNG repository سے لی گئی تھیں اور اس ایپ میں GitHub Releases پر موجود downloadable image pack کے ذریعے فراہم کی جاتی ہیں۔',
      'other_b3': 'ایپ میں قرآنی متن کی نمائش کے لیے UthmanicHafs فونٹ استعمال ہوتا ہے۔',
      'no_items_available': 'کوئی آئٹم دستیاب نہیں',
    },
    'tr': {
      'audio_section': 'Ses',
      'default_reciter': 'Varsayılan kari',
      'tafseer_section': 'Tefsir',
      'tafseer_source': 'Tefsir kaynağı',
      'quran_data_section': "Kur'an Verisi",
      'mushaf_pages_section': 'Mushaf Sayfaları',
      'about_section': 'Hakkında',
      'version': 'Sürüm',
      'id_value': 'Kimlik: {value}',
      'select_reciter': 'Kari Seç',
      'select_tafseer': 'Tefsir Seç',
      'download_recitation': 'Tilavet İndir',
      'enter_surah_number': 'Sure numarasını girin (1-114)',
      'surah_number_hint': 'örn. 1',
      'cancel': 'İptal',
      'download': 'İndir',
      'invalid_surah_number': 'Lütfen 1 ile 114 arasında bir sayı girin',
      'downloading_recitation': 'Tilavet indiriliyor',
      'downloaded_of_ayahs': '{total} ayetin {done} tanesi indirildi',
      'surah_reciter_status': 'Sure {surah} · Kari {reciter}',
      'recitation_surah_downloaded': '{surah}. sure için tilavet indirildi.',
      'no_audio_urls_found': '{surah}. sure için ses URLsi bulunamadı.',
      'recitation_download_failed': 'Tilavet indirme başarısız: {error}',
      'download_all_surahs_recitation': 'Tüm surelerin tilavetini indir',
      'large_download_confirm': 'Bu işlem önemli miktarda zaman ve depolama gerektirebilir. Devam edilsin mi?',
      'start': 'Başlat',
      'downloading_all_recitations': 'Tüm tilavetler indiriliyor',
      'reciter_surah_compact': 'Kari {reciter} • Sure {surah}',
      'completed_of_surahs': '{total} surenin {done} tanesi tamamlandı',
      'stop': 'Durdur',
      'recitation_download_stopped': 'Tilavet indirme durduruldu.',
      'all_surahs_recitation_completed': 'Tüm surelerin tilaveti indirildi.',
      'bulk_recitation_download_failed': 'Toplu tilavet indirme başarısız: {error}',
      'offline_recitation_downloads': 'Çevrimdışı tilavet indirmeleri',
      'reciter_id': 'Kari kimliği: {id}',
      'download_one_surah': 'Bir sure indir',
      'download_all_surahs': 'Tüm sureleri indir',
      'download_tafseer': 'Tefsir İndir',
      'downloading_tafseer': 'Tefsir indiriliyor',
      'surah_tafseer_status': 'Sure {surah} · Tefsir kimliği {id}',
      'no_verses_returned': 'Bu sure için ayet döndürülmedi.',
      'tafseer_surah_downloaded': '{surah}. sure için tefsir indirildi.',
      'tafseer_download_failed': 'Tefsir indirme başarısız: {error}',
      'download_all_surahs_tafseer': 'Tüm surelerin tefsirini indir',
      'downloading_all_tafseer': 'Tüm tefsirler indiriliyor',
      'tafseer_id_surah_compact': 'Tefsir kimliği {id} • Sure {surah}',
      'tafseer_download_stopped': 'Tefsir indirme durduruldu.',
      'all_surahs_tafseer_completed': 'Tüm surelerin tefsiri indirildi.',
      'bulk_tafseer_download_failed': 'Toplu tefsir indirme başarısız: {error}',
      'download_tafseer_offline': 'Çevrimdışı kullanım için tefsir indir',
      'current_source_id': 'Geçerli kaynak kimliği: {id}',
      'quran_diagnostics_title': "Kur'an Tanılama (7:101, 7:122)",
      'diagnostics_copied': 'Tanılama kopyalandı',
      'copy': 'Kopyala',
      'close': 'Kapat',
      'working': 'Çalışıyor...',
      'error_syncing_quran_data': "Kur'an verisi eşitlenirken hata oluştu",
      'checking_status': 'Durum kontrol ediliyor...',
      'ready_status': 'Hazır ({synced}/{total}) • Son eşitleme: {time}',
      'syncing_surahs_status': '{synced}/{total} sure eşitleniyor...',
      'not_fully_synced_status': 'Henüz tam eşitlenmedi ({synced}/{total})',
      'quran_text_offline': "Kur'an metni (çevrimdışı)",
      'download_resume': 'İndir / Devam et',
      'resync_all': 'Tümünü yeniden eşitle',
      'clear_local_quran_cache': "Yerel Kur'an önbelleğini temizle",
      'refresh_status': 'Durumu yenile',
      'show_diagnostics': 'Tanılamayı göster',
      'error_pack_checking': 'Paket kontrolü/indirmesi sırasında hata',
      'installed_pages': 'Yüklü ({count} sayfa)',
      'not_installed_yet': 'Henüz yüklü değil ({count}/{expected} sayfa)',
      'mushaf_image_pack': 'Mushaf görsel paketi',
      'redownload': 'Yeniden indir',
      'delete_local_pack': 'Yerel paketi sil',
      'about_this_app': 'Bu uygulama hakkında',
      'quran_sources_ownership': "Kur'an kaynakları ve sahiplik",
      'owned_operated': 'Bu uygulamanın sahibi ve işletmecisi Ebaid LLCdir.',
      'quran_sources_title': "Kur'an kaynakları",
      'quran_b1': "Kur'an metni, sure ve ayet yapısı, kelime kelime veri ve tecvid işaretlemeleri Quran.com API v4ten alınır.",
      'quran_b2': 'Uygulama, desteklenen arayüz dilleri için şu çeviri kaynaklarını kullanır:',
      'quran_b3': 'Uygulama dilini değiştirdiğinizde uygulama o dile uygun çeviriyi ister. Bir çeviri yoksa İngilizceye döner.',
      'quran_b4': 'Uzak mushaf sayfası başvuruları cdn.qurancdn.com ve static.qurancdn.com üzerindeki sayfa görsellerine işaret eder.',
      'tafseer_sources_title': 'Tefsir kaynakları',
      'tafseer_b1': 'Tefsir kataloğu ve ayet bazlı tefsir metni Quran.com API v4 kaynakları ve tafsir uç noktalarından yüklenir.',
      'tafseer_b2': 'Uygulama diline göre yapılandırılan varsayılan tefsir kaynakları şunlardır:',
      'tafseer_b3': 'Kullanıcılar uygulama içindeki tefsir seçicisi üzerinden Quran.com tarafından sunulan diğer tefsir kaynaklarına geçebilir.',
      'recitation_sources_title': 'Tilavet kaynakları',
      'recitation_b1': 'Tilavet kataloğu Quran.com API v4 kaynak uç noktalarından yüklenir.',
      'recitation_b2': 'Ayet ses oynatımı ve indirilebilir tilavet dosyaları verses.quran.com üzerindeki Quran.com ses CDNinden sunulur.',
      'recitation_b3': 'Bu uygulama şu karileri destekler:',
      'reciter_label': 'Kari',
      'other_sources_title': 'Diğer içerik kaynakları',
      'other_b1': 'Derslerde ve quizlerde kullanılan tecvid kural tanımları assets/tajweed/rules_db.json içinde yerel olarak paketlenmiştir.',
      'other_b2': 'Çevrimdışı mushaf sayfa görselleri ilk olarak GitHubdaki GovarJabbar/Quran-PNG deposundan alınmış ve bu uygulamada GitHub Releases üzerinde barındırılan indirilebilir görsel paket aracılığıyla sunulmuştur.',
      'other_b3': "Uygulamadaki Kur'an gösterimi mushaf tarzı görünüm için gömülü UthmanicHafs yazı tipini kullanır.",
      'no_items_available': 'Kullanılabilir öğe yok',
    },
    'fr': {
      'audio_section': 'Audio',
      'default_reciter': 'Récitateur par défaut',
      'tafseer_section': 'Tafsir',
      'tafseer_source': 'Source du tafsir',
      'quran_data_section': 'Données du Coran',
      'mushaf_pages_section': 'Pages du mushaf',
      'about_section': 'À propos',
      'version': 'Version',
      'id_value': 'ID : {value}',
      'select_reciter': 'Choisir un récitateur',
      'select_tafseer': 'Choisir un tafsir',
      'download_recitation': 'Télécharger la récitation',
      'enter_surah_number': 'Entrez le numéro de sourate (1-114)',
      'surah_number_hint': 'ex. 1',
      'cancel': 'Annuler',
      'download': 'Télécharger',
      'invalid_surah_number': 'Veuillez saisir un nombre entre 1 et 114',
      'downloading_recitation': 'Téléchargement de la récitation',
      'downloaded_of_ayahs': '{done} ayats téléchargées sur {total}',
      'surah_reciter_status': 'Sourate {surah} · Récitateur {reciter}',
      'recitation_surah_downloaded': 'Récitation de la sourate {surah} téléchargée.',
      'no_audio_urls_found': 'Aucune URL audio trouvée pour la sourate {surah}.',
      'recitation_download_failed': 'Échec du téléchargement de la récitation : {error}',
      'download_all_surahs_recitation': 'Télécharger la récitation de toutes les sourates',
      'large_download_confirm': "Cela peut prendre du temps et beaucoup d'espace de stockage. Continuer ?",
      'start': 'Démarrer',
      'downloading_all_recitations': 'Téléchargement de toutes les récitations',
      'reciter_surah_compact': 'Récitateur {reciter} • Sourate {surah}',
      'completed_of_surahs': '{done} sourates terminées sur {total}',
      'stop': 'Arrêter',
      'recitation_download_stopped': 'Le téléchargement de la récitation a été arrêté.',
      'all_surahs_recitation_completed': 'Le téléchargement de la récitation de toutes les sourates est terminé.',
      'bulk_recitation_download_failed': 'Échec du téléchargement groupé de récitations : {error}',
      'offline_recitation_downloads': 'Téléchargements de récitations hors ligne',
      'reciter_id': 'ID du récitateur : {id}',
      'download_one_surah': 'Télécharger une sourate',
      'download_all_surahs': 'Télécharger toutes les sourates',
      'download_tafseer': 'Télécharger le tafsir',
      'downloading_tafseer': 'Téléchargement du tafsir',
      'surah_tafseer_status': 'Sourate {surah} · ID du tafsir {id}',
      'no_verses_returned': 'Aucun verset renvoyé pour cette sourate.',
      'tafseer_surah_downloaded': 'Tafsir de la sourate {surah} téléchargé.',
      'tafseer_download_failed': 'Échec du téléchargement du tafsir : {error}',
      'download_all_surahs_tafseer': 'Télécharger le tafsir de toutes les sourates',
      'downloading_all_tafseer': 'Téléchargement de tous les tafsirs',
      'tafseer_id_surah_compact': 'ID du tafsir {id} • Sourate {surah}',
      'tafseer_download_stopped': 'Le téléchargement du tafsir a été arrêté.',
      'all_surahs_tafseer_completed': 'Le téléchargement du tafsir de toutes les sourates est terminé.',
      'bulk_tafseer_download_failed': 'Échec du téléchargement groupé du tafsir : {error}',
      'download_tafseer_offline': 'Télécharger le tafsir pour le mode hors ligne',
      'current_source_id': 'ID de la source actuelle : {id}',
      'quran_diagnostics_title': 'Diagnostic du Coran (7:101, 7:122)',
      'diagnostics_copied': 'Diagnostic copié',
      'copy': 'Copier',
      'close': 'Fermer',
      'working': 'En cours...',
      'error_syncing_quran_data': 'Erreur lors de la synchronisation des données du Coran',
      'checking_status': 'Vérification du statut...',
      'ready_status': 'Prêt ({synced}/{total}) • Dernière synchronisation : {time}',
      'syncing_surahs_status': 'Synchronisation de {synced}/{total} sourates...',
      'not_fully_synced_status': 'Pas encore totalement synchronisé ({synced}/{total})',
      'quran_text_offline': 'Texte coranique (hors ligne)',
      'download_resume': 'Télécharger / Reprendre',
      'resync_all': 'Tout resynchroniser',
      'clear_local_quran_cache': 'Effacer le cache coranique local',
      'refresh_status': 'Actualiser le statut',
      'show_diagnostics': 'Afficher le diagnostic',
      'error_pack_checking': 'Erreur lors de la vérification/téléchargement du pack',
      'installed_pages': 'Installé ({count} pages)',
      'not_installed_yet': 'Pas encore installé ({count}/{expected} pages)',
      'mushaf_image_pack': 'Pack d’images du mushaf',
      'redownload': 'Retélécharger',
      'delete_local_pack': 'Supprimer le pack local',
      'about_this_app': 'À propos de cette application',
      'quran_sources_ownership': 'Sources du Coran et propriété',
      'owned_operated': 'Cette application est détenue et exploitée par Ebaid LLC.',
      'quran_sources_title': 'Sources du Coran',
      'quran_b1': 'Le texte coranique, la structure des sourates et des ayats, les données mot à mot et le balisage du tajwid proviennent de l’API v4 de Quran.com.',
      'quran_b2': 'L’application utilise les sources de traduction suivantes pour les langues d’interface prises en charge :',
      'quran_b3': 'Lorsque vous changez la langue de l’application, elle demande la traduction correspondante. Si elle est indisponible, elle revient à l’anglais.',
      'quran_b4': 'Les références distantes des pages du mushaf pointent vers des images hébergées sur cdn.qurancdn.com et static.qurancdn.com.',
      'tafseer_sources_title': 'Sources du tafsir',
      'tafseer_b1': 'Le catalogue du tafsir et le texte du tafsir verset par verset sont chargés depuis les ressources et endpoints tafsir de l’API v4 de Quran.com.',
      'tafseer_b2': 'Les sources de tafsir par défaut configurées selon la langue de l’application sont :',
      'tafseer_b3': 'Les utilisateurs peuvent choisir d’autres sources de tafsir renvoyées par Quran.com via le sélecteur intégré.',
      'recitation_sources_title': 'Sources de récitation',
      'recitation_b1': 'Le catalogue des récitations est chargé depuis les endpoints de ressources de l’API v4 de Quran.com.',
      'recitation_b2': 'La lecture audio des versets et les fichiers de récitation téléchargeables sont fournis par le CDN audio de Quran.com sur verses.quran.com.',
      'recitation_b3': 'Cette application prend actuellement en charge ces récitateur :',
      'reciter_label': 'Récitateur',
      'other_sources_title': 'Autres sources de contenu',
      'other_b1': 'Les définitions des règles de tajwid utilisées dans les leçons et les quiz sont intégrées localement dans assets/tajweed/rules_db.json.',
      'other_b2': 'Les images de pages du mushaf hors ligne proviennent à l’origine du dépôt GitHub GovarJabbar/Quran-PNG et sont distribuées dans cette application via son pack d’images téléchargeable hébergé sur GitHub Releases.',
      'other_b3': 'L’affichage coranique dans l’application utilise la police intégrée UthmanicHafs pour un rendu de style mushaf.',
      'no_items_available': 'Aucun élément disponible',
    },
    'id': {
      'audio_section': 'Audio',
      'default_reciter': 'Qari default',
      'tafseer_section': 'Tafsir',
      'tafseer_source': 'Sumber tafsir',
      'quran_data_section': 'Data Al-Quran',
      'mushaf_pages_section': 'Halaman Mushaf',
      'about_section': 'Tentang',
      'version': 'Versi',
      'id_value': 'ID: {value}',
      'select_reciter': 'Pilih qari',
      'select_tafseer': 'Pilih tafsir',
      'download_recitation': 'Unduh tilawah',
      'enter_surah_number': 'Masukkan nomor surah (1-114)',
      'surah_number_hint': 'mis. 1',
      'cancel': 'Batal',
      'download': 'Unduh',
      'invalid_surah_number': 'Masukkan angka antara 1 dan 114',
      'downloading_recitation': 'Mengunduh tilawah',
      'downloaded_of_ayahs': 'Mengunduh {done} dari {total} ayat',
      'surah_reciter_status': 'Surah {surah} · Qari {reciter}',
      'recitation_surah_downloaded': 'Tilawah untuk surah {surah} berhasil diunduh.',
      'no_audio_urls_found': 'URL audio untuk surah {surah} tidak ditemukan.',
      'recitation_download_failed': 'Gagal mengunduh tilawah: {error}',
      'download_all_surahs_recitation': 'Unduh tilawah semua surah',
      'large_download_confirm': 'Ini mungkin memerlukan waktu dan ruang penyimpanan yang besar. Lanjutkan?',
      'start': 'Mulai',
      'downloading_all_recitations': 'Mengunduh semua tilawah',
      'reciter_surah_compact': 'Qari {reciter} • Surah {surah}',
      'completed_of_surahs': 'Selesai {done} dari {total} surah',
      'stop': 'Berhenti',
      'recitation_download_stopped': 'Pengunduhan tilawah dihentikan.',
      'all_surahs_recitation_completed': 'Pengunduhan tilawah semua surah selesai.',
      'bulk_recitation_download_failed': 'Gagal mengunduh tilawah massal: {error}',
      'offline_recitation_downloads': 'Unduhan tilawah offline',
      'reciter_id': 'ID qari: {id}',
      'download_one_surah': 'Unduh satu surah',
      'download_all_surahs': 'Unduh semua surah',
      'download_tafseer': 'Unduh tafsir',
      'downloading_tafseer': 'Mengunduh tafsir',
      'surah_tafseer_status': 'Surah {surah} · ID tafsir {id}',
      'no_verses_returned': 'Tidak ada ayat yang dikembalikan untuk surah ini.',
      'tafseer_surah_downloaded': 'Tafsir untuk surah {surah} berhasil diunduh.',
      'tafseer_download_failed': 'Gagal mengunduh tafsir: {error}',
      'download_all_surahs_tafseer': 'Unduh tafsir semua surah',
      'downloading_all_tafseer': 'Mengunduh semua tafsir',
      'tafseer_id_surah_compact': 'ID tafsir {id} • Surah {surah}',
      'tafseer_download_stopped': 'Pengunduhan tafsir dihentikan.',
      'all_surahs_tafseer_completed': 'Pengunduhan tafsir semua surah selesai.',
      'bulk_tafseer_download_failed': 'Gagal mengunduh tafsir massal: {error}',
      'download_tafseer_offline': 'Unduh tafsir untuk offline',
      'current_source_id': 'ID sumber saat ini: {id}',
      'quran_diagnostics_title': 'Diagnostik Quran (7:101, 7:122)',
      'diagnostics_copied': 'Diagnostik disalin',
      'copy': 'Salin',
      'close': 'Tutup',
      'working': 'Sedang bekerja...',
      'error_syncing_quran_data': 'Terjadi kesalahan saat menyinkronkan data Al-Quran',
      'checking_status': 'Memeriksa status...',
      'ready_status': 'Siap ({synced}/{total}) • Sinkronisasi terakhir: {time}',
      'syncing_surahs_status': 'Menyinkronkan {synced}/{total} surah...',
      'not_fully_synced_status': 'Belum tersinkron penuh ({synced}/{total})',
      'quran_text_offline': 'Teks Al-Quran (offline)',
      'download_resume': 'Unduh / Lanjutkan',
      'resync_all': 'Sinkron ulang semua',
      'clear_local_quran_cache': 'Hapus cache Quran lokal',
      'refresh_status': 'Segarkan status',
      'show_diagnostics': 'Tampilkan diagnostik',
      'error_pack_checking': 'Kesalahan saat memeriksa/mengunduh paket',
      'installed_pages': 'Terpasang ({count} halaman)',
      'not_installed_yet': 'Belum terpasang ({count}/{expected} halaman)',
      'mushaf_image_pack': 'Paket gambar mushaf',
      'redownload': 'Unduh ulang',
      'delete_local_pack': 'Hapus paket lokal',
      'about_this_app': 'Tentang aplikasi ini',
      'quran_sources_ownership': 'Sumber Al-Quran dan kepemilikan',
      'owned_operated': 'Aplikasi ini dimiliki dan dioperasikan oleh Ebaid LLC.',
      'quran_sources_title': 'Sumber Al-Quran',
      'quran_b1': 'Teks Al-Quran, struktur surah dan ayat, data kata per kata, dan markup tajwid diambil dari Quran.com API v4.',
      'quran_b2': 'Aplikasi menggunakan sumber terjemahan berikut untuk bahasa antarmuka yang didukung:',
      'quran_b3': 'Saat Anda mengganti bahasa aplikasi, aplikasi meminta terjemahan yang sesuai untuk bahasa itu. Jika tidak tersedia, aplikasi kembali ke bahasa Inggris.',
      'quran_b4': 'Referensi halaman mushaf jarak jauh menunjuk ke gambar halaman yang dihosting di cdn.qurancdn.com dan static.qurancdn.com.',
      'tafseer_sources_title': 'Sumber tafsir',
      'tafseer_b1': 'Katalog tafsir dan teks tafsir per ayat dimuat dari resource dan endpoint tafsir Quran.com API v4.',
      'tafseer_b2': 'Sumber tafsir default yang dikonfigurasi berdasarkan bahasa aplikasi adalah:',
      'tafseer_b3': 'Pengguna dapat beralih ke sumber tafsir lain yang dikembalikan oleh Quran.com melalui pemilih tafsir di aplikasi.',
      'recitation_sources_title': 'Sumber tilawah',
      'recitation_b1': 'Katalog tilawah dimuat dari endpoint resource Quran.com API v4.',
      'recitation_b2': 'Pemutaran audio ayat dan file tilawah yang dapat diunduh disajikan dari CDN audio Quran.com di verses.quran.com.',
      'recitation_b3': 'Aplikasi ini saat ini mendukung qari berikut:',
      'reciter_label': 'Qari',
      'other_sources_title': 'Sumber konten lainnya',
      'other_b1': 'Definisi aturan tajwid yang digunakan dalam pelajaran dan kuis dibundel secara lokal di assets/tajweed/rules_db.json.',
      'other_b2': 'Gambar halaman mushaf offline awalnya bersumber dari repositori GitHub GovarJabbar/Quran-PNG dan didistribusikan dalam aplikasi ini melalui paket gambar yang dapat diunduh yang dihosting di GitHub Releases.',
      'other_b3': 'Tampilan Al-Quran dalam aplikasi menggunakan font UthmanicHafs bawaan untuk rendering bergaya mushaf.',
      'no_items_available': 'Tidak ada item tersedia',
    },
    'de': {
      'audio_section': 'Audio',
      'default_reciter': 'Standardrezitator',
      'tafseer_section': 'Tafsir',
      'tafseer_source': 'Tafsir-Quelle',
      'quran_data_section': 'Koran-Daten',
      'mushaf_pages_section': 'Mushaf-Seiten',
      'about_section': 'Über',
      'version': 'Version',
      'id_value': 'ID: {value}',
      'select_reciter': 'Rezitator auswählen',
      'select_tafseer': 'Tafsir auswählen',
      'download_recitation': 'Rezitation herunterladen',
      'enter_surah_number': 'Sura-Nummer eingeben (1-114)',
      'surah_number_hint': 'z. B. 1',
      'cancel': 'Abbrechen',
      'download': 'Herunterladen',
      'invalid_surah_number': 'Bitte geben Sie eine Zahl zwischen 1 und 114 ein',
      'downloading_recitation': 'Rezitation wird heruntergeladen',
      'downloaded_of_ayahs': '{done} von {total} Ayat heruntergeladen',
      'surah_reciter_status': 'Sura {surah} · Rezitator {reciter}',
      'recitation_surah_downloaded': 'Rezitation für Sura {surah} heruntergeladen.',
      'no_audio_urls_found': 'Keine Audio-URLs für Sura {surah} gefunden.',
      'recitation_download_failed': 'Herunterladen der Rezitation fehlgeschlagen: {error}',
      'download_all_surahs_recitation': 'Rezitation aller Suren herunterladen',
      'large_download_confirm': 'Dies kann viel Zeit und Speicherplatz benötigen. Fortfahren?',
      'start': 'Starten',
      'downloading_all_recitations': 'Alle Rezitationen werden heruntergeladen',
      'reciter_surah_compact': 'Rezitator {reciter} • Sura {surah}',
      'completed_of_surahs': '{done} von {total} Suren abgeschlossen',
      'stop': 'Stopp',
      'recitation_download_stopped': 'Rezitationsdownload wurde gestoppt.',
      'all_surahs_recitation_completed': 'Der Download der Rezitation aller Suren ist abgeschlossen.',
      'bulk_recitation_download_failed': 'Massen-Download der Rezitation fehlgeschlagen: {error}',
      'offline_recitation_downloads': 'Offline-Rezitationsdownloads',
      'reciter_id': 'Rezitator-ID: {id}',
      'download_one_surah': 'Eine Sura herunterladen',
      'download_all_surahs': 'Alle Suren herunterladen',
      'download_tafseer': 'Tafsir herunterladen',
      'downloading_tafseer': 'Tafsir wird heruntergeladen',
      'surah_tafseer_status': 'Sura {surah} · Tafsir-ID {id}',
      'no_verses_returned': 'Für diese Sura wurden keine Verse zurückgegeben.',
      'tafseer_surah_downloaded': 'Tafsir für Sura {surah} heruntergeladen.',
      'tafseer_download_failed': 'Herunterladen des Tafsir fehlgeschlagen: {error}',
      'download_all_surahs_tafseer': 'Tafsir aller Suren herunterladen',
      'downloading_all_tafseer': 'Alle Tafsir werden heruntergeladen',
      'tafseer_id_surah_compact': 'Tafsir-ID {id} • Sura {surah}',
      'tafseer_download_stopped': 'Tafsir-Download wurde gestoppt.',
      'all_surahs_tafseer_completed': 'Der Download des Tafsir aller Suren ist abgeschlossen.',
      'bulk_tafseer_download_failed': 'Massen-Download des Tafsir fehlgeschlagen: {error}',
      'download_tafseer_offline': 'Tafsir für Offline-Nutzung herunterladen',
      'current_source_id': 'Aktuelle Quellen-ID: {id}',
      'quran_diagnostics_title': 'Koran-Diagnose (7:101, 7:122)',
      'diagnostics_copied': 'Diagnose kopiert',
      'copy': 'Kopieren',
      'close': 'Schließen',
      'working': 'Wird ausgeführt...',
      'error_syncing_quran_data': 'Fehler beim Synchronisieren der Koran-Daten',
      'checking_status': 'Status wird geprüft...',
      'ready_status': 'Bereit ({synced}/{total}) • Letzte Synchronisierung: {time}',
      'syncing_surahs_status': '{synced}/{total} Suren werden synchronisiert...',
      'not_fully_synced_status': 'Noch nicht vollständig synchronisiert ({synced}/{total})',
      'quran_text_offline': 'Korantekst (offline)',
      'download_resume': 'Herunterladen / Fortsetzen',
      'resync_all': 'Alles erneut synchronisieren',
      'clear_local_quran_cache': 'Lokalen Koran-Cache löschen',
      'refresh_status': 'Status aktualisieren',
      'show_diagnostics': 'Diagnose anzeigen',
      'error_pack_checking': 'Fehler beim Prüfen/Herunterladen des Pakets',
      'installed_pages': 'Installiert ({count} Seiten)',
      'not_installed_yet': 'Noch nicht installiert ({count}/{expected} Seiten)',
      'mushaf_image_pack': 'Mushaf-Bildpaket',
      'redownload': 'Erneut herunterladen',
      'delete_local_pack': 'Lokales Paket löschen',
      'about_this_app': 'Über diese App',
      'quran_sources_ownership': 'Koranquellen und Eigentum',
      'owned_operated': 'Diese App gehört Ebaid LLC und wird von ihr betrieben.',
      'quran_sources_title': 'Koranquellen',
      'quran_b1': 'Korantext, Sura- und Ayah-Struktur, Wort-für-Wort-Daten und Tajweed-Markup werden aus der Quran.com API v4 geladen.',
      'quran_b2': 'Die App verwendet die folgenden Übersetzungsquellen für ihre unterstützten Oberflächensprachen:',
      'quran_b3': 'Wenn Sie die App-Sprache wechseln, fordert die App die passende Übersetzung für diese Sprache an. Ist keine verfügbar, fällt sie auf Englisch zurück.',
      'quran_b4': 'Entfernte Mushaf-Seitenverweise zeigen auf Seitenbilder, die auf cdn.qurancdn.com und static.qurancdn.com gehostet werden.',
      'tafseer_sources_title': 'Tafsir-Quellen',
      'tafseer_b1': 'Der Tafsir-Katalog und der ayahweise Tafsir-Text werden aus Ressourcen und Tafsir-Endpunkten der Quran.com API v4 geladen.',
      'tafseer_b2': 'Die standardmäßig nach App-Sprache konfigurierten Tafsir-Quellen sind:',
      'tafseer_b3': 'Benutzer können über die Tafsir-Auswahl in der App zu anderen von Quran.com bereitgestellten Tafsir-Quellen wechseln.',
      'recitation_sources_title': 'Rezitationsquellen',
      'recitation_b1': 'Der Rezitationskatalog wird aus Ressourcen-Endpunkten der Quran.com API v4 geladen.',
      'recitation_b2': 'Ayah-Audiowiedergabe und herunterladbare Rezitationsdateien werden vom Quran.com-Audio-CDN unter verses.quran.com bereitgestellt.',
      'recitation_b3': 'Diese App unterstützt derzeit die folgenden Rezitatoren:',
      'reciter_label': 'Rezitator',
      'other_sources_title': 'Weitere Inhaltsquellen',
      'other_b1': 'Die in Lektionen und Quiz verwendeten Tajweed-Regeldefinitionen sind lokal in assets/tajweed/rules_db.json enthalten.',
      'other_b2': 'Offline-Mushaf-Seitenbilder stammen ursprünglich aus dem GitHub-Repository GovarJabbar/Quran-PNG und werden in dieser App über ein auf GitHub Releases gehostetes herunterladbares Bildpaket verteilt.',
      'other_b3': 'Die Korandarstellung in der App verwendet die integrierte Schrift UthmanicHafs für ein Mushaf-ähnliches Rendering.',
      'no_items_available': 'Keine Elemente verfügbar',
    },
    'es': {
      'audio_section': 'Audio',
      'default_reciter': 'Recitador predeterminado',
      'tafseer_section': 'Tafsir',
      'tafseer_source': 'Fuente de tafsir',
      'quran_data_section': 'Datos del Corán',
      'mushaf_pages_section': 'Páginas del mushaf',
      'about_section': 'Acerca de',
      'version': 'Versión',
      'id_value': 'ID: {value}',
      'select_reciter': 'Seleccionar recitador',
      'select_tafseer': 'Seleccionar tafsir',
      'download_recitation': 'Descargar recitación',
      'enter_surah_number': 'Introduce el número de sura (1-114)',
      'surah_number_hint': 'p. ej. 1',
      'cancel': 'Cancelar',
      'download': 'Descargar',
      'invalid_surah_number': 'Introduce un número entre 1 y 114',
      'downloading_recitation': 'Descargando recitación',
      'downloaded_of_ayahs': '{done} de {total} ayat descargadas',
      'surah_reciter_status': 'Sura {surah} · Recitador {reciter}',
      'recitation_surah_downloaded': 'Se descargó la recitación de la sura {surah}.',
      'no_audio_urls_found': 'No se encontraron URL de audio para la sura {surah}.',
      'recitation_download_failed': 'Error al descargar la recitación: {error}',
      'download_all_surahs_recitation': 'Descargar la recitación de todas las suras',
      'large_download_confirm': 'Esto puede requerir bastante tiempo y almacenamiento. ¿Continuar?',
      'start': 'Iniciar',
      'downloading_all_recitations': 'Descargando todas las recitaciones',
      'reciter_surah_compact': 'Recitador {reciter} • Sura {surah}',
      'completed_of_surahs': '{done} de {total} suras completadas',
      'stop': 'Detener',
      'recitation_download_stopped': 'Se detuvo la descarga de la recitación.',
      'all_surahs_recitation_completed': 'Se completó la descarga de la recitación de todas las suras.',
      'bulk_recitation_download_failed': 'Error en la descarga masiva de recitaciones: {error}',
      'offline_recitation_downloads': 'Descargas de recitación sin conexión',
      'reciter_id': 'ID del recitador: {id}',
      'download_one_surah': 'Descargar una sura',
      'download_all_surahs': 'Descargar todas las suras',
      'download_tafseer': 'Descargar tafsir',
      'downloading_tafseer': 'Descargando tafsir',
      'surah_tafseer_status': 'Sura {surah} · ID de tafsir {id}',
      'no_verses_returned': 'No se devolvieron versículos para esta sura.',
      'tafseer_surah_downloaded': 'Se descargó el tafsir de la sura {surah}.',
      'tafseer_download_failed': 'Error al descargar el tafsir: {error}',
      'download_all_surahs_tafseer': 'Descargar el tafsir de todas las suras',
      'downloading_all_tafseer': 'Descargando todos los tafsir',
      'tafseer_id_surah_compact': 'ID de tafsir {id} • Sura {surah}',
      'tafseer_download_stopped': 'Se detuvo la descarga del tafsir.',
      'all_surahs_tafseer_completed': 'Se completó la descarga del tafsir de todas las suras.',
      'bulk_tafseer_download_failed': 'Error en la descarga masiva del tafsir: {error}',
      'download_tafseer_offline': 'Descargar tafsir para uso sin conexión',
      'current_source_id': 'ID de la fuente actual: {id}',
      'quran_diagnostics_title': 'Diagnóstico del Corán (7:101, 7:122)',
      'diagnostics_copied': 'Diagnóstico copiado',
      'copy': 'Copiar',
      'close': 'Cerrar',
      'working': 'Trabajando...',
      'error_syncing_quran_data': 'Error al sincronizar los datos del Corán',
      'checking_status': 'Comprobando estado...',
      'ready_status': 'Listo ({synced}/{total}) • Última sincronización: {time}',
      'syncing_surahs_status': 'Sincronizando {synced}/{total} suras...',
      'not_fully_synced_status': 'Aún no está totalmente sincronizado ({synced}/{total})',
      'quran_text_offline': 'Texto coránico (sin conexión)',
      'download_resume': 'Descargar / Reanudar',
      'resync_all': 'Volver a sincronizar todo',
      'clear_local_quran_cache': 'Borrar caché local del Corán',
      'refresh_status': 'Actualizar estado',
      'show_diagnostics': 'Mostrar diagnóstico',
      'error_pack_checking': 'Error al comprobar/descargar el paquete',
      'installed_pages': 'Instalado ({count} páginas)',
      'not_installed_yet': 'Aún no instalado ({count}/{expected} páginas)',
      'mushaf_image_pack': 'Paquete de imágenes del mushaf',
      'redownload': 'Volver a descargar',
      'delete_local_pack': 'Eliminar paquete local',
      'about_this_app': 'Acerca de esta aplicación',
      'quran_sources_ownership': 'Fuentes del Corán y propiedad',
      'owned_operated': 'Esta aplicación es propiedad de Ebaid LLC y está operada por ella.',
      'quran_sources_title': 'Fuentes del Corán',
      'quran_b1': 'El texto coránico, la estructura de las suras y ayat, los datos palabra por palabra y el marcado de tajwid se obtienen de Quran.com API v4.',
      'quran_b2': 'La aplicación utiliza las siguientes fuentes de traducción para sus idiomas de interfaz compatibles:',
      'quran_b3': 'Cuando cambias el idioma de la aplicación, esta solicita la traducción correspondiente. Si no está disponible, vuelve al inglés.',
      'quran_b4': 'Las referencias remotas de páginas del mushaf apuntan a imágenes alojadas en cdn.qurancdn.com y static.qurancdn.com.',
      'tafseer_sources_title': 'Fuentes de tafsir',
      'tafseer_b1': 'El catálogo de tafsir y el texto de tafsir por ayah se cargan desde los recursos y endpoints de tafsir de Quran.com API v4.',
      'tafseer_b2': 'Las fuentes de tafsir predeterminadas configuradas por idioma de la aplicación son:',
      'tafseer_b3': 'Los usuarios pueden cambiar a otras fuentes de tafsir devueltas por Quran.com mediante el selector de tafsir dentro de la aplicación.',
      'recitation_sources_title': 'Fuentes de recitación',
      'recitation_b1': 'El catálogo de recitaciones se carga desde los endpoints de recursos de Quran.com API v4.',
      'recitation_b2': 'La reproducción de audio de ayat y los archivos de recitación descargables se sirven desde el CDN de audio de Quran.com en verses.quran.com.',
      'recitation_b3': 'Actualmente esta aplicación admite estos recitadores:',
      'reciter_label': 'Recitador',
      'other_sources_title': 'Otras fuentes de contenido',
      'other_b1': 'Las definiciones de reglas de tajwid utilizadas en las lecciones y cuestionarios se incluyen localmente en assets/tajweed/rules_db.json.',
      'other_b2': 'Las imágenes de páginas del mushaf sin conexión se obtuvieron originalmente del repositorio de GitHub GovarJabbar/Quran-PNG y se distribuyen en esta aplicación mediante su paquete de imágenes descargable alojado en GitHub Releases.',
      'other_b3': 'La visualización coránica en la aplicación utiliza la fuente integrada UthmanicHafs para un renderizado estilo mushaf.',
      'no_items_available': 'No hay elementos disponibles',
    },
  };

  String text(String key, [Map<String, String> replacements = const {}]) {
    var value = _localized[_languageCode]?[key] ?? _localized['en']![key] ?? key;
    replacements.forEach((placeholder, replacement) {
      value = value.replaceAll('{$placeholder}', replacement);
    });
    return value;
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.04,
            ),
      ),
    );
  }
}
