import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_links.dart';
import '../../../core/providers/tafseer_provider.dart';
import '../../../core/services/quran_api_service.dart';
import '../../../core/services/quran_offline_sync_service.dart';
import '../../../shared/utils/arabic_utils.dart';
import '../tafseer_text_sanitizer.dart';

class TafseerSourceOption {
  final int id;
  final String name;
  final String displayName;
  final String authorName;

  const TafseerSourceOption({
    required this.id,
    required this.name,
    required this.displayName,
    required this.authorName,
  });

  String get label =>
      authorName.isEmpty ? displayName : '$displayName — $authorName';

  static List<TafseerSourceOption> fromApiList(
    Iterable<Map<String, dynamic>> sources, {
    String Function(Map<String, dynamic> source)? displayNameForSource,
  }) {
    final byId = <int, TafseerSourceOption>{};
    for (final source in sources) {
      final id = source['id'];
      final name = source['name']?.toString().trim() ?? '';
      if (id is! int || name.isEmpty) continue;
      byId.putIfAbsent(
        id,
        () => TafseerSourceOption(
          id: id,
          name: name,
          displayName: displayNameForSource?.call(source) ?? name,
          authorName: source['author_name']?.toString().trim() ?? '',
        ),
      );
    }

    final options = byId.values.toList(growable: true);
    options.sort((left, right) {
      final byName = left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      );
      if (byName != 0) return byName;
      return left.authorName.toLowerCase().compareTo(
        right.authorName.toLowerCase(),
      );
    });
    return options;
  }
}

class TafseerShareContent {
  const TafseerShareContent._();

  static String build({
    required String heading,
    required String sourceLine,
    required String tafseerText,
    required String appName,
  }) {
    return [
      heading,
      sourceLine,
      '',
      tafseerText.trim(),
      '',
      appName,
      AppLinks.appStore,
    ].join('\n');
  }
}

/// Bottom sheet that displays tafseer (commentary) for a single ayah.
class TafseerSheet extends StatefulWidget {
  final String verseKey; // e.g. '2:255'
  final int tafsirId;
  final String tafsirName;
  final String surahName; // Arabic surah name, e.g. 'طه'
  final String languageCode;
  final QuranApiService? api;
  final QuranOfflineSyncService? offlineSync;
  final Future<void> Function(int tafsirId, String tafsirName)?
  onTafsirSelected;

  const TafseerSheet({
    super.key,
    required this.verseKey,
    required this.tafsirId,
    this.tafsirName = '',
    this.surahName = '',
    this.languageCode = 'en',
    this.api,
    this.offlineSync,
    this.onTafsirSelected,
  });

  @override
  State<TafseerSheet> createState() => _TafseerSheetState();
}

class _TafseerSheetState extends State<TafseerSheet> {
  late final QuranApiService _api;
  late final QuranOfflineSyncService _offlineSync;
  late int _selectedTafsirId;
  late String _selectedTafsirName;
  final GlobalKey _shareButtonKey = GlobalKey();

  List<TafseerSourceOption> _sources = const [];
  String? _text;
  bool _loading = true;
  bool _sourcesLoading = true;
  bool _switching = false;
  String? _error;
  String? _sourcesError;
  String? _selectionError;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? QuranApiService();
    _offlineSync = widget.offlineSync ?? QuranOfflineSyncService();
    _selectedTafsirId = widget.tafsirId;
    _selectedTafsirName = widget.tafsirName;
    _fetchTafseer();
    _fetchSources();
  }

  Future<void> _fetchTafseer() async {
    try {
      final text = await _loadTafseerText(_selectedTafsirId);
      if (mounted) {
        setState(() {
          _text = text;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<String> _loadTafseerText(int tafsirId) async {
    final surah = int.tryParse(widget.verseKey.split(':').first);
    var cachedMap = <String, String>{};
    if (surah != null) {
      cachedMap = await _offlineSync.getCachedTafsirMap(
        tafsirId: tafsirId,
        surahNumber: surah,
      );
      final cached = cachedMap[widget.verseKey];
      if (cached != null && cached.trim().isNotEmpty) return cached;
    }

    final text = await _api.fetchTafsirForAyah(
      tafsirId: tafsirId,
      verseKey: widget.verseKey,
    );
    if (surah != null && text.trim().isNotEmpty) {
      cachedMap[widget.verseKey] = text;
      await _offlineSync.saveTafsirMap(
        tafsirId: tafsirId,
        surahNumber: surah,
        tafsirMap: cachedMap,
      );
    }
    return text;
  }

  Future<void> _fetchSources() async {
    final selectedFallback = _selectedTafsirName.isEmpty
        ? <TafseerSourceOption>[]
        : [
            TafseerSourceOption(
              id: _selectedTafsirId,
              name: _selectedTafsirName,
              displayName: _selectedTafsirName,
              authorName: '',
            ),
          ];
    if (mounted) {
      setState(() {
        _sources = selectedFallback;
        _sourcesLoading = selectedFallback.isEmpty;
        _sourcesError = null;
      });
    }

    try {
      final allSources = await _api.fetchAvailableTafsirs();
      final sources = TafseerSourceOption.fromApiList(
        TafseerProvider.sourcesForLanguage(allSources, widget.languageCode),
        displayNameForSource: (source) {
          return TafseerProvider.sourceDisplayName(widget.languageCode, source);
        },
      );
      if (!sources.any((source) => source.id == _selectedTafsirId) &&
          _selectedTafsirName.isNotEmpty) {
        sources.add(
          TafseerSourceOption(
            id: _selectedTafsirId,
            name: _selectedTafsirName,
            displayName: _selectedTafsirName,
            authorName: '',
          ),
        );
        sources.sort(
          (left, right) => left.displayName.toLowerCase().compareTo(
            right.displayName.toLowerCase(),
          ),
        );
      }
      if (sources.isEmpty) {
        throw StateError('No Tafseer sources were returned.');
      }
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _sourcesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sourcesError = selectedFallback.isEmpty ? e.toString() : null;
        _sourcesLoading = false;
      });
    }
  }

  Future<void> _selectTafsir(int? tafsirId) async {
    if (tafsirId == null || tafsirId == _selectedTafsirId || _switching) {
      return;
    }

    final source = _sources.firstWhere((item) => item.id == tafsirId);
    final failureMessage = _TafseerSheetStrings.of(
      context,
    ).text('switch_failed');
    setState(() {
      _switching = true;
      _selectionError = null;
    });

    try {
      final text = await _loadTafseerText(tafsirId);
      if (text.trim().isEmpty) {
        throw StateError('The selected Tafseer returned no text.');
      }
      await widget.onTafsirSelected?.call(source.id, source.name);
      if (!mounted) return;
      setState(() {
        _selectedTafsirId = source.id;
        _selectedTafsirName = source.displayName;
        _text = text;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _selectionError = failureMessage);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Rect _shareOriginRect() {
    final renderObject =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObject != null && renderObject.hasSize) {
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }
    return const Rect.fromLTWH(1, 1, 1, 1);
  }

  Future<void> _shareTafseer() async {
    final strings = _TafseerSheetStrings.of(context);
    final text = _stripHtml(_text ?? '');
    if (text.isEmpty) return;

    final localeCode = Localizations.localeOf(context).languageCode;
    final verseReference = _localizedVerseKey(widget.verseKey, localeCode);
    final source = _selectedTafsirName.trim().isNotEmpty
        ? _selectedTafsirName.trim()
        : '$_selectedTafsirId';
    final content = TafseerShareContent.build(
      heading: strings.text('share_heading', {'verseKey': verseReference}),
      sourceLine: strings.text('share_source', {'source': source}),
      tafseerText: text,
      appName: AppLinks.productName,
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: content,
          subject: strings.text('share_heading', {'verseKey': verseReference}),
          sharePositionOrigin: _shareOriginRect(),
        ),
      );
    } catch (error) {
      debugPrint('Tafseer share failed: $error');
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
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF1D9E75),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedTafsirName.isNotEmpty
                        ? strings.text('title_with_source', {
                            'source': _selectedTafsirName,
                            'verseKey': _localizedVerseKey(
                              widget.verseKey,
                              localeCode,
                            ),
                          })
                        : strings.text('title', {
                            'verseKey': _localizedVerseKey(
                              widget.verseKey,
                              localeCode,
                            ),
                          }),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: _shareButtonKey,
                  tooltip: strings.text('share'),
                  onPressed:
                      _loading ||
                          _switching ||
                          _error != null ||
                          strippedText.isEmpty
                      ? null
                      : _shareTafseer,
                  icon: const Icon(CupertinoIcons.share, size: 22),
                  color: const Color(0xFF1D9E75),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: strings.text('close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          _buildSourceSelector(strings),
          if (_switching) const LinearProgressIndicator(minHeight: 2),
          if (_selectionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                _selectionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                        strings.text('empty', {
                          'tafsirId': '$_selectedTafsirId',
                        }),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      strippedText,
                      textDirection: isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
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

  Widget _buildSourceSelector(_TafseerSheetStrings strings) {
    if (_sourcesLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(strings.text('loading_sources')),
          ],
        ),
      );
    }

    if (_sourcesError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Expanded(child: Text(strings.text('sources_failed'))),
            TextButton(
              onPressed: _fetchSources,
              child: Text(strings.text('retry')),
            ),
          ],
        ),
      );
    }

    final hasSelectedSource = _sources.any(
      (source) => source.id == _selectedTafsirId,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DropdownButtonFormField<int>(
        key: ValueKey('tafseer-source-dropdown-$_selectedTafsirId'),
        initialValue: hasSelectedSource ? _selectedTafsirId : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: strings.text('select_source'),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        items: _sources
            .map(
              (source) => DropdownMenuItem<int>(
                key: ValueKey('tafseer-source-${source.id}'),
                value: source.id,
                child: Text(
                  source.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: _switching ? null : _selectTafsir,
      ),
    );
  }

  /// Returns a localized verse reference.
  /// Arabic/Urdu: 'طه: ٦١' (surah name + Arabic-Indic ayah number).
  /// Others: '20:61' (unchanged).
  String _localizedVerseKey(String verseKey, String localeCode) {
    final parts = verseKey.split(':');
    if (parts.length != 2) return verseKey;
    final ayahNum = int.tryParse(parts[1]);
    if (ayahNum == null) return verseKey;

    if (localeCode == 'ar' || localeCode == 'ur') {
      final name = widget.surahName.isNotEmpty ? widget.surahName : parts[0];
      return '$name: ${ArabicUtils.toArabicNumerals(ayahNum)}';
    }
    return verseKey;
  }

  /// Strip HTML tags and print-edition artifacts from tafseer text.
  String _stripHtml(String html) => TafseerTextSanitizer.stripHtml(
    html,
    ayahNumber: int.tryParse(widget.verseKey.split(':').last),
  );
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
      'title_with_source': '{source} — Ayah {verseKey}',
      'close': 'Close',
      'load_failed': 'Could not load tafseer.\n{error}',
      'empty':
          'No tafseer text was returned for this ayah with source ID {tafsirId}.',
      'select_source': 'Tafseer source',
      'loading_sources': 'Loading Tafseer sources...',
      'sources_failed': 'Could not load Tafseer sources.',
      'retry': 'Retry',
      'switch_failed':
          'Could not load the selected Tafseer. The previous source remains selected.',
      'share': 'Share Tafseer',
      'share_heading': 'Tafseer — Ayah {verseKey}',
      'share_source': 'Source: {source}',
    },
    'ar': {
      'title': 'التفسير — {verseKey}',
      'title_with_source': '{source} — {verseKey}',
      'close': 'إغلاق',
      'load_failed': 'تعذر تحميل التفسير.\n{error}',
      'empty':
          'لم يتم إرجاع نص تفسير لهذه الآية باستخدام مصدر التفسير {tafsirId}.',
      'select_source': 'مصدر التفسير',
      'loading_sources': 'جارٍ تحميل مصادر التفسير...',
      'sources_failed': 'تعذر تحميل مصادر التفسير.',
      'retry': 'إعادة المحاولة',
      'switch_failed': 'تعذر تحميل التفسير المحدد. سيبقى المصدر السابق محددًا.',
      'share': 'مشاركة التفسير',
      'share_heading': 'تفسير الآية {verseKey}',
      'share_source': 'المصدر: {source}',
    },
    'ur': {
      'title': 'تفسیر — {verseKey}',
      'title_with_source': '{source} — {verseKey}',
      'close': 'بند کریں',
      'load_failed': 'تفسیر لوڈ نہ ہو سکی۔\n{error}',
      'empty':
          'اس آیت کے لیے تفسیر کے ماخذ {tafsirId} سے کوئی متن واپس نہیں آیا۔',
      'select_source': 'تفسیر کا ماخذ',
      'loading_sources': 'تفسیر کے مآخذ لوڈ ہو رہے ہیں...',
      'sources_failed': 'تفسیر کے مآخذ لوڈ نہیں ہو سکے۔',
      'retry': 'دوبارہ کوشش کریں',
      'switch_failed': 'منتخب تفسیر لوڈ نہیں ہو سکی۔ پچھلا ماخذ منتخب رہے گا۔',
      'share': 'تفسیر شیئر کریں',
      'share_heading': 'آیت {verseKey} کی تفسیر',
      'share_source': 'ماخذ: {source}',
    },
    'tr': {
      'title': 'Tefsir — Ayet {verseKey}',
      'title_with_source': '{source} — Ayet {verseKey}',
      'close': 'Kapat',
      'load_failed': 'Tefsir yüklenemedi.\n{error}',
      'empty':
          'Bu ayet için {tafsirId} kaynak kimliğiyle tefsir metni döndürülmedi.',
      'select_source': 'Tefsir kaynağı',
      'loading_sources': 'Tefsir kaynakları yükleniyor...',
      'sources_failed': 'Tefsir kaynakları yüklenemedi.',
      'retry': 'Yeniden dene',
      'switch_failed':
          'Seçilen tefsir yüklenemedi. Önceki kaynak seçili kalacak.',
      'share': 'Tefsiri paylaş',
      'share_heading': 'Ayet {verseKey} tefsiri',
      'share_source': 'Kaynak: {source}',
    },
    'fr': {
      'title': 'Tafsir — Ayah {verseKey}',
      'title_with_source': '{source} — Ayah {verseKey}',
      'close': 'Fermer',
      'load_failed': 'Impossible de charger le tafsir.\n{error}',
      'empty':
          "Aucun texte de tafsir n'a été renvoyé pour cette ayah avec la source {tafsirId}.",
      'select_source': 'Source du tafsir',
      'loading_sources': 'Chargement des sources de tafsir...',
      'sources_failed': 'Impossible de charger les sources de tafsir.',
      'retry': 'Réessayer',
      'switch_failed':
          "Impossible de charger le tafsir sélectionné. La source précédente reste sélectionnée.",
      'share': 'Partager le tafsir',
      'share_heading': 'Tafsir — Ayah {verseKey}',
      'share_source': 'Source : {source}',
    },
    'id': {
      'title': 'Tafsir — Ayat {verseKey}',
      'title_with_source': '{source} — Ayat {verseKey}',
      'close': 'Tutup',
      'load_failed': 'Tidak dapat memuat tafsir.\n{error}',
      'empty':
          'Tidak ada teks tafsir yang dikembalikan untuk ayat ini dengan sumber ID {tafsirId}.',
      'select_source': 'Sumber tafsir',
      'loading_sources': 'Memuat sumber tafsir...',
      'sources_failed': 'Tidak dapat memuat sumber tafsir.',
      'retry': 'Coba lagi',
      'switch_failed':
          'Tafsir yang dipilih tidak dapat dimuat. Sumber sebelumnya tetap dipilih.',
      'share': 'Bagikan tafsir',
      'share_heading': 'Tafsir — Ayat {verseKey}',
      'share_source': 'Sumber: {source}',
    },
    'de': {
      'title': 'Tafsir — Ayah {verseKey}',
      'title_with_source': '{source} — Ayah {verseKey}',
      'close': 'Schließen',
      'load_failed': 'Tafsir konnte nicht geladen werden.\n{error}',
      'empty':
          'Für diese Ayah wurde mit der Quellen-ID {tafsirId} kein Tafsir-Text zurückgegeben.',
      'select_source': 'Tafsir-Quelle',
      'loading_sources': 'Tafsir-Quellen werden geladen...',
      'sources_failed': 'Tafsir-Quellen konnten nicht geladen werden.',
      'retry': 'Erneut versuchen',
      'switch_failed':
          'Der ausgewählte Tafsir konnte nicht geladen werden. Die vorherige Quelle bleibt ausgewählt.',
      'share': 'Tafsir teilen',
      'share_heading': 'Tafsir — Ayah {verseKey}',
      'share_source': 'Quelle: {source}',
    },
    'es': {
      'title': 'Tafsir — Aleya {verseKey}',
      'title_with_source': '{source} — Aleya {verseKey}',
      'close': 'Cerrar',
      'load_failed': 'No se pudo cargar el tafsir.\n{error}',
      'empty':
          'No se devolvió texto de tafsir para esta aleya con la fuente {tafsirId}.',
      'select_source': 'Fuente del tafsir',
      'loading_sources': 'Cargando fuentes de tafsir...',
      'sources_failed': 'No se pudieron cargar las fuentes de tafsir.',
      'retry': 'Reintentar',
      'switch_failed':
          'No se pudo cargar el tafsir seleccionado. La fuente anterior seguirá seleccionada.',
      'share': 'Compartir tafsir',
      'share_heading': 'Tafsir — Aleya {verseKey}',
      'share_source': 'Fuente: {source}',
    },
  };

  String text(String key, [Map<String, String> replacements = const {}]) {
    var value =
        _localized[_languageCode]?[key] ?? _localized['en']![key] ?? key;
    replacements.forEach((placeholder, replacement) {
      value = value.replaceAll('{$placeholder}', replacement);
    });
    return value;
  }
}
