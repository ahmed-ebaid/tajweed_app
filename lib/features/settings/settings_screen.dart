import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/recitation_provider.dart';
import '../../core/providers/tafseer_provider.dart';
import '../../core/services/mushaf_assets_service.dart';
import '../../core/services/quran_offline_sync_service.dart';
import '../../core/services/quran_api_service.dart';
import 'language_selector_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          _SectionLabel(label: 'Display'),
          SwitchListTile(
            secondary: const Icon(Icons.palette_rounded),
            title: const Text('Tajweed colors'),
            subtitle: const Text('Highlight rules with colors'),
            value: true,
            onChanged: (_) {},
            activeColor: const Color(0xFF1D9E75),
          ),
          const Divider(height: 0.5, indent: 16),
          SwitchListTile(
            secondary: const Icon(Icons.translate_rounded),
            title: Text(l10n.get('translation')),
            subtitle: const Text('Show translation below each verse'),
            value: true,
            onChanged: (_) {},
            activeColor: const Color(0xFF1D9E75),
          ),
          const Divider(height: 0.5, indent: 16),
          _SectionLabel(label: 'Audio'),
          ListTile(
            leading: const Icon(Icons.record_voice_over_rounded),
            title: const Text('Default reciter'),
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
          _SectionLabel(label: 'Tafseer'),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: const Text('Tafseer source'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    'ID: ${tafseerProvider.selectedTafsirId}',
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
          _SectionLabel(label: 'Quran Data'),
          const _QuranDataTile(),
          const Divider(height: 0.5, indent: 16),
          _SectionLabel(label: 'Mushaf Pages'),
          const _MushafPackTile(),
          const Divider(height: 0.5, indent: 16),
          _SectionLabel(label: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Version'),
            trailing:
                Text('1.0.0', style: Theme.of(context).textTheme.bodyMedium),
          ),
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
      7: 'Mishari Alafasy',
      8: 'Al-Minshawi (Mujawwad)',
      9: 'Al-Minshawi (Murattal)',
      10: 'Sa`ud ash-Shuraym',
      11: 'Mohamed al-Tablawi',
      12: 'Al-Husary (Muallim)',
    };
    return names[id] ?? 'Reciter $id';
  }

  void _showReciterPicker(BuildContext context) {
    final api = QuranApiService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AsyncPickerSheet<Map<String, dynamic>>(
        title: 'Select Reciter',
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
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AsyncPickerSheet<Map<String, dynamic>>(
        title: 'Select Tafseer',
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
            title: const Text('Quran Diagnostics (7:101, 7:122)'),
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
                    const SnackBar(content: Text('Diagnostics copied')),
                  );
                },
                child: const Text('Copy'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
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
    final status = _status;

    String subtitle;
    if (_busy) {
      subtitle = 'Working...';
    } else if (_error != null) {
      subtitle = 'Error while syncing Quran data';
    } else if (status == null) {
      subtitle = 'Checking status...';
    } else if (status.completed) {
      final syncedAt =
          status.lastCompletedAt?.toLocal().toString() ?? 'unknown';
      subtitle =
          'Ready (${status.syncedSurahs}/${status.totalSurahs}) • Last sync: $syncedAt';
    } else if (status.inProgress) {
      subtitle =
          'Syncing ${status.syncedSurahs}/${status.totalSurahs} surahs...';
    } else {
      subtitle =
          'Not fully synced (${status.syncedSurahs}/${status.totalSurahs})';
    }

    return ListTile(
      leading: const Icon(Icons.cloud_sync_outlined),
      title: const Text('Quran text (offline)'),
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
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sync', child: Text('Download / Resume')),
                PopupMenuItem(value: 'resync', child: Text('Re-sync all')),
                PopupMenuItem(
                    value: 'clear', child: Text('Clear local Quran cache')),
                PopupMenuItem(value: 'refresh', child: Text('Refresh status')),
                PopupMenuItem(
                    value: 'diagnostics', child: Text('Show diagnostics')),
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
    final status = _status;
    final installed = status?.installed ?? false;

    String subtitle;
    if (_busy) {
      subtitle = 'Working...';
    } else if (_error != null) {
      subtitle = 'Error while checking/downloading pack';
    } else if (status == null) {
      subtitle = 'Checking status...';
    } else if (installed) {
      subtitle = 'Installed (${status.pageCount} pages)';
    } else {
      subtitle =
          'Not installed yet (${status.pageCount}/${MushafAssetsService.expectedPageCount} pages)';
    }

    return ListTile(
      leading: const Icon(Icons.image_outlined),
      title: const Text('Mushaf image pack'),
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
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'download', child: Text('Download')),
                PopupMenuItem(value: 'redownload', child: Text('Re-download')),
                PopupMenuItem(
                    value: 'delete', child: Text('Delete local pack')),
                PopupMenuItem(value: 'refresh', child: Text('Refresh status')),
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
                    ? const Center(child: Text('No items available'))
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
