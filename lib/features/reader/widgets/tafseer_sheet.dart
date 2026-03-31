import 'package:flutter/material.dart';

import '../../../core/services/quran_api_service.dart';
import '../../../core/services/quran_offline_sync_service.dart';

/// Bottom sheet that displays tafseer (commentary) for a single ayah.
class TafseerSheet extends StatefulWidget {
  final String verseKey; // e.g. '2:255'
  final int tafsirId;

  const TafseerSheet({
    super.key,
    required this.verseKey,
    required this.tafsirId,
  });

  @override
  State<TafseerSheet> createState() => _TafseerSheetState();
}

class _TafseerSheetState extends State<TafseerSheet> {
  final _api = QuranApiService();
  final _offlineSync = QuranOfflineSyncService();
  String? _text;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTafseer();
  }

  Future<void> _fetchTafseer() async {
    try {
      final surah = int.tryParse(widget.verseKey.split(':').first);
      if (surah != null) {
        final cachedMap = await _offlineSync.getCachedTafsirMap(
          tafsirId: widget.tafsirId,
          surahNumber: surah,
        );
        final cached = cachedMap[widget.verseKey];
        if (cached != null && cached.trim().isNotEmpty) {
          if (mounted) {
            setState(() {
              _text = cached;
              _loading = false;
            });
          }
          return;
        }
      }

      final text = await _api.fetchTafsirForAyah(
        tafsirId: widget.tafsirId,
        verseKey: widget.verseKey,
      );

      if (surah != null && text.trim().isNotEmpty) {
        final cachedMap = await _offlineSync.getCachedTafsirMap(
          tafsirId: widget.tafsirId,
          surahNumber: surah,
        );
        cachedMap[widget.verseKey] = text;
        await _offlineSync.saveTafsirMap(
          tafsirId: widget.tafsirId,
          surahNumber: surah,
          tafsirMap: cachedMap,
        );
      }

      if (mounted) {
        setState(() {
          _text = text;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    color: Color(0xFF1D9E75), size: 22),
                const SizedBox(width: 8),
                Text(
                  'Tafseer — Ayah ${widget.verseKey}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 0.5),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load tafseer.\n$_error',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          _stripHtml(_text ?? ''),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.8,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Strip HTML tags from tafseer text for plain display.
  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }
}
