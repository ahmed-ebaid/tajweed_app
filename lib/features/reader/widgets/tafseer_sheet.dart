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
    final strings = _TafseerSheetStrings.of(context);
    final strippedText = _stripHtml(_text ?? '');
    final showEmptyState = !_loading && _error == null && strippedText.isEmpty;
    final localeCode = Localizations.localeOf(context).languageCode;
    final isRtl = localeCode == 'ar' || localeCode == 'ur';

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
                Expanded(
                  child: Text(
                    strings.text('title', {'verseKey': widget.verseKey}),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: strings.text('close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
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
                            strings.text('load_failed', {'error': _error ?? ''}),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : showEmptyState
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                strings.text('empty', {'tafsirId': '${widget.tafsirId}'}),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                    : SingleChildScrollView(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          strippedText,
                          textDirection:
                              isRtl ? TextDirection.rtl : TextDirection.ltr,
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


class _TafseerSheetStrings {
  final String _languageCode;

  const _TafseerSheetStrings._(this._languageCode);

  factory _TafseerSheetStrings.of(BuildContext context) {
    return _TafseerSheetStrings._(Localizations.localeOf(context).languageCode);
  }

  static const Map<String, Map<String, String>> _localized = {
    'en': {
      'title': 'Tafseer — Ayah {verseKey}',
      'close': 'Close',
      'load_failed': 'Could not load tafseer.\n{error}',
      'empty': 'No tafseer text was returned for this ayah with source ID {tafsirId}.',
    },
    'ar': {
      'title': 'التفسير — الآية {verseKey}',
      'close': 'إغلاق',
      'load_failed': 'تعذر تحميل التفسير.\n{error}',
      'empty': 'لم يتم إرجاع نص تفسير لهذه الآية باستخدام مصدر التفسير {tafsirId}.',
    },
    'ur': {
      'title': 'تفسیر — آیت {verseKey}',
      'close': 'بند کریں',
      'load_failed': 'تفسیر لوڈ نہ ہو سکی۔\n{error}',
      'empty': 'اس آیت کے لیے تفسیر کے ماخذ {tafsirId} سے کوئی متن واپس نہیں آیا۔',
    },
    'tr': {
      'title': 'Tefsir — Ayet {verseKey}',
      'close': 'Kapat',
      'load_failed': 'Tefsir yüklenemedi.\n{error}',
      'empty': 'Bu ayet için {tafsirId} kaynak kimliğiyle tefsir metni döndürülmedi.',
    },
    'fr': {
      'title': 'Tafsir — Ayah {verseKey}',
      'close': 'Fermer',
      'load_failed': 'Impossible de charger le tafsir.\n{error}',
      'empty': 'Aucun texte de tafsir n’a été renvoyé pour cette ayah avec la source {tafsirId}.',
    },
    'id': {
      'title': 'Tafsir — Ayat {verseKey}',
      'close': 'Tutup',
      'load_failed': 'Tidak dapat memuat tafsir.\n{error}',
      'empty': 'Tidak ada teks tafsir yang dikembalikan untuk ayat ini dengan sumber ID {tafsirId}.',
    },
    'de': {
      'title': 'Tafsir — Ayah {verseKey}',
      'close': 'Schließen',
      'load_failed': 'Tafsir konnte nicht geladen werden.\n{error}',
      'empty': 'Für diese Ayah wurde mit der Quellen-ID {tafsirId} kein Tafsir-Text zurückgegeben.',
    },
    'es': {
      'title': 'Tafsir — Aleya {verseKey}',
      'close': 'Cerrar',
      'load_failed': 'No se pudo cargar el tafsir.\n{error}',
      'empty': 'No se devolvió texto de tafsir para esta aleya con la fuente {tafsirId}.',
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
