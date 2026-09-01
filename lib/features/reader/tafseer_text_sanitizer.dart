/// Converts raw tafseer HTML from the content API into readable plain text.
///
/// Classical tafseer sources embed print-edition artifacts that must not reach
/// the reader. Tafsir al-Tabari, for example, marks the printed volume and page
/// with `&amp;; 6-484 &amp;;`, which decodes to `&; 6-484 &;` and previously
/// rendered as unreadable punctuation in the middle of Arabic sentences.
abstract final class TafseerTextSanitizer {
  static final RegExp _tag = RegExp(r'<[^>]*>');
  static final RegExp _numericEntity = RegExp(
    r'&#(x[0-9a-f]+|[0-9]+);',
    caseSensitive: false,
  );

  /// Print-edition volume/page markers such as `&; 6-484 &;`.
  ///
  /// Matched after tag removal because the marker is frequently split by
  /// inline markup, e.g. `&amp;; 6-<span class="blue">485 &amp;;`.
  static final RegExp _printPageMarker = RegExp(
    r'&\s*;\s*[\u0660-\u06690-9]+\s*[-\u2010-\u2015/]\s*[\u0660-\u06690-9]+\s*&\s*;',
  );

  /// Any stray marker delimiter left behind by an unbalanced source marker.
  static final RegExp _strayMarkerDelimiter = RegExp(r'&\s*;');

  static const Map<String, String> _namedEntities = {
    '&nbsp;': ' ',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&laquo;': '«',
    '&raquo;': '»',
    '&ldquo;': '“',
    '&rdquo;': '”',
    '&lsquo;': '‘',
    '&rsquo;': '’',
    '&hellip;': '…',
    '&ndash;': '–',
    '&mdash;': '—',
    '&middot;': '·',
    '&bull;': '•',
    '&shy;': '',
    '&zwnj;': '\u200c',
    '&zwj;': '\u200d',
  };

  /// Strips markup and editorial artifacts from [html] for plain display.
  static String stripHtml(String html) {
    if (html.isEmpty) return '';

    // Tags are removed first so decoded entities can never introduce markup.
    var text = html.replaceAll(_tag, ' ');
    text = _decodeEntities(text);
    text = text.replaceAll(_printPageMarker, ' ');
    text = text.replaceAll(_strayMarkerDelimiter, ' ');
    return _normalizeWhitespace(text);
  }

  static String _decodeEntities(String input) {
    var text = input;
    for (final entry in _namedEntities.entries) {
      if (text.contains(entry.key)) {
        text = text.replaceAll(entry.key, entry.value);
      }
    }

    text = text.replaceAllMapped(_numericEntity, (match) {
      final raw = match.group(1)!;
      final codePoint = raw.toLowerCase().startsWith('x')
          ? int.tryParse(raw.substring(1), radix: 16)
          : int.tryParse(raw);
      if (codePoint == null ||
          codePoint <= 0 ||
          codePoint > 0x10FFFF ||
          (codePoint >= 0xD800 && codePoint <= 0xDFFF)) {
        return '';
      }
      return String.fromCharCode(codePoint);
    });

    // Decoded last so escaped ampersands cannot resurrect other entities.
    return text.replaceAll('&amp;', '&');
  }

  static String _normalizeWhitespace(String input) {
    final buffer = StringBuffer();
    var pendingSpace = false;
    var wroteContent = false;

    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      if (char.trim().isEmpty) {
        pendingSpace = wroteContent;
        continue;
      }
      if (pendingSpace) {
        buffer.write(' ');
        pendingSpace = false;
      }
      buffer.write(char);
      wroteContent = true;
    }

    return buffer.toString();
  }
}
