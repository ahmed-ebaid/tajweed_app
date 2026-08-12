import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/services/quran_api_service.dart';
import 'package:tajweed_practice/core/services/quran_offline_sync_service.dart';
import 'package:tajweed_practice/features/reader/widgets/tafseer_sheet.dart';
import 'package:tajweed_practice/core/constants/app_links.dart';

class _FakeQuranApiService extends QuranApiService {
  _FakeQuranApiService({
    required this.sources,
    required this.textByTafsirId,
    this.failingTafsirIds = const {},
  });

  final List<Map<String, dynamic>> sources;
  final Map<int, String> textByTafsirId;
  final Set<int> failingTafsirIds;

  @override
  Future<List<Map<String, dynamic>>> fetchAvailableTafsirs() async => sources;

  @override
  Future<String> fetchTafsirForAyah({
    required int tafsirId,
    required String verseKey,
  }) async {
    if (failingTafsirIds.contains(tafsirId)) {
      throw Exception('Tafseer unavailable');
    }
    return textByTafsirId[tafsirId] ?? '';
  }
}

class _FakeOfflineSyncService extends QuranOfflineSyncService {
  final Map<String, Map<String, String>> _cache = {};

  String _key(int tafsirId, int surahNumber) => '$tafsirId:$surahNumber';

  @override
  Future<Map<String, String>> getCachedTafsirMap({
    required int tafsirId,
    required int surahNumber,
  }) async {
    return Map<String, String>.from(
      _cache[_key(tafsirId, surahNumber)] ?? const {},
    );
  }

  @override
  Future<void> saveTafsirMap({
    required int tafsirId,
    required int surahNumber,
    required Map<String, String> tafsirMap,
  }) async {
    _cache[_key(tafsirId, surahNumber)] = Map<String, String>.from(tafsirMap);
  }
}

void main() {
  const ibnKathir = <String, dynamic>{
    'id': 169,
    'name': 'Ibn Kathir',
    'author_name': 'Ibn Kathir',
    'language_name': 'english',
  };
  const tabari = <String, dynamic>{
    'id': 15,
    'name': 'Al-Tabari',
    'author_name': 'Al-Tabari',
    'language_name': 'english',
  };

  test('Tafseer sources are deduplicated and sorted alphabetically', () {
    final sources = TafseerSourceOption.fromApiList([
      ibnKathir,
      tabari,
      ibnKathir,
      {'id': 'invalid', 'name': 'Invalid'},
      {'id': 90, 'name': ''},
    ]);

    expect(sources.map((source) => source.id), [15, 169]);
    expect(sources.first.label, 'Al-Tabari — Al-Tabari');
  });

  test('Tafseer share content includes attribution and the app link', () {
    final content = TafseerShareContent.build(
      heading: 'Tafseer — Ayah 1:1',
      sourceLine: 'Source: Ibn Kathir',
      tafseerText: 'Commentary text',
      appName: 'Tajweed',
    );

    expect(content, contains('Tafseer — Ayah 1:1'));
    expect(content, contains('Source: Ibn Kathir'));
    expect(content, contains('Commentary text'));
    expect(content, contains(AppLinks.appStore));
  });

  testWidgets('successful selection updates content and persists globally', (
    tester,
  ) async {
    final selected = <Object>[];
    await tester.pumpWidget(
      _testApp(
        api: _FakeQuranApiService(
          sources: const [ibnKathir, tabari],
          textByTafsirId: const {
            169: 'Initial commentary',
            15: 'Tabari commentary',
          },
        ),
        onSelected: (id, name) async {
          selected
            ..add(id)
            ..add(name);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tafseer-source-dropdown-169')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tafsir al-Tabari — Al-Tabari').last);
    await tester.pumpAndSettle();

    expect(find.text('Tabari commentary'), findsOneWidget);
    expect(selected, [15, 'Al-Tabari']);
    expect(
      find.byKey(const ValueKey('tafseer-source-dropdown-15')),
      findsOneWidget,
    );
    expect(find.textContaining('Tafsir al-Tabari'), findsNWidgets(2));
    expect(find.byTooltip('Share Tafseer'), findsOneWidget);
  });

  testWidgets('failed selection retains previous content and selection', (
    tester,
  ) async {
    var persisted = false;
    await tester.pumpWidget(
      _testApp(
        api: _FakeQuranApiService(
          sources: const [ibnKathir, tabari],
          textByTafsirId: const {169: 'Initial commentary'},
          failingTafsirIds: const {15},
        ),
        onSelected: (_, __) async => persisted = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tafseer-source-dropdown-169')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tafsir al-Tabari — Al-Tabari').last);
    await tester.pumpAndSettle();

    expect(find.text('Initial commentary'), findsOneWidget);
    expect(persisted, isFalse);
    expect(
      find.byKey(const ValueKey('tafseer-source-dropdown-169')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Could not load the selected Tafseer. '
        'The previous source remains selected.',
      ),
      findsOneWidget,
    );
  });
}

Widget _testApp({
  required _FakeQuranApiService api,
  required Future<void> Function(int, String) onSelected,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 800,
        child: TafseerSheet(
          verseKey: '1:1',
          tafsirId: 169,
          tafsirName: 'Ibn Kathir',
          api: api,
          offlineSync: _FakeOfflineSyncService(),
          onTafsirSelected: onSelected,
        ),
      ),
    ),
  );
}
