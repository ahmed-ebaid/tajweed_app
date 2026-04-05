import 'dart:convert';
import 'dart:io';

Map<String, dynamic> _asStringDynamicMap(dynamic input) {
  return Map<String, dynamic>.from(input as Map);
}

List<Map<String, dynamic>> _loadVersesFromJson(String jsonPath) {
  final file = File(jsonPath);
  if (!file.existsSync()) {
    throw StateError('Input JSON not found: $jsonPath');
  }

  final root = jsonDecode(file.readAsStringSync());
  final verses = <Map<String, dynamic>>[];

  if (root is List) {
    for (final item in root) {
      if (item is Map) verses.add(_asStringDynamicMap(item));
    }
    return verses;
  }

  if (root is Map) {
    final dynamicVerses = root['verses'];
    if (dynamicVerses is List) {
      for (final item in dynamicVerses) {
        if (item is Map) verses.add(_asStringDynamicMap(item));
      }
      return verses;
    }

    // Supports per-surah dump shape: { "1": [ ...verses ], "2": [ ... ] }
    for (final entry in root.entries) {
      final value = entry.value;
      if (value is! List) continue;
      for (final item in value) {
        if (item is Map) verses.add(_asStringDynamicMap(item));
      }
    }
  }

  return verses;
}

Map<String, dynamic>? _findEndToken(List<dynamic> words) {
  for (int i = words.length - 1; i >= 0; i--) {
    final token = words[i];
    if (token is! Map) continue;
    final map = _asStringDynamicMap(token);
    if ((map['char_type_name'] as String?) == 'end') {
      return map;
    }
  }
  return null;
}

bool _isShiftedEndTokenCase(Map<String, dynamic> verse) {
  final words = verse['words'];
  if (words is! List) return false;

  final endToken = _findEndToken(words);
  if (endToken == null) return false;

  final endText =
      (endToken['text'] as String? ?? endToken['text_uthmani'] as String? ?? '')
          .trim();
  final endTajweed = (endToken['text_uthmani_tajweed'] as String? ?? '').trim();

  if (endText.isEmpty || endTajweed.isEmpty) return false;
  return endText != endTajweed;
}

int _compareVerseKey(String a, String b) {
  final ap = a.split(':');
  final bp = b.split(':');
  final as = int.tryParse(ap.first) ?? 0;
  final bs = int.tryParse(bp.first) ?? 0;
  if (as != bs) return as.compareTo(bs);
  final aa = ap.length > 1 ? int.tryParse(ap[1]) ?? 0 : 0;
  final ba = bp.length > 1 ? int.tryParse(bp[1]) ?? 0 : 0;
  return aa.compareTo(ba);
}

void _printUsage() {
  print('Usage:');
  print(
      '  dart run tool/end_token_audit.dart --input <quran_words.json> [--output <flagged.json>]');
  print('');
  print('Accepted input formats:');
  print('  1) [ { verse objects... } ]');
  print('  2) { "verses": [ { verse objects... } ] }');
  print('  3) { "1": [ ... ], "2": [ ... ] }  // per-surah map');
}

Map<String, String> _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (int i = 0; i < args.length; i++) {
    final current = args[i];
    if (!current.startsWith('--')) continue;
    if (i + 1 >= args.length) {
      throw ArgumentError('Missing value for argument $current');
    }
    map[current] = args[i + 1];
    i++;
  }
  return map;
}

void main(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exit(0);
  }

  final parsed = _parseArgs(args);
  final input = parsed['--input'];
  final output = parsed['--output'];

  if (input == null || input.isEmpty) {
    stderr.writeln('Error: --input is required.');
    _printUsage();
    exit(2);
  }

  final verses = _loadVersesFromJson(input);
  if (verses.isEmpty) {
    stderr.writeln('Error: No verses found in input JSON.');
    exit(2);
  }

  if (verses.length != 6236) {
    stderr.writeln(
      'Warning: expected 6236 ayahs but found ${verses.length}. Continuing audit.',
    );
  }

  final flagged = <String>[];
  for (final verse in verses) {
    if (!_isShiftedEndTokenCase(verse)) continue;
    final verseKey = verse['verse_key']?.toString();
    if (verseKey != null && verseKey.contains(':')) {
      flagged.add(verseKey);
    }
  }

  flagged.sort(_compareVerseKey);

  print('Shifted end-token ayahs: ${flagged.length}');
  for (final key in flagged) {
    print('SHIFTED_END_TOKEN $key');
  }

  if (output != null && output.isNotEmpty) {
    final file = File(output);
    file.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'audited_ayah_count': verses.length,
        'flagged_count': flagged.length,
        'flagged_ayahs': flagged,
      }),
    );
    print('Wrote report: ${file.path}');
  }
}
