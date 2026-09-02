/// Plain-text tafseer, split into the commentary and the editor's apparatus.
///
/// Classical editions interleave the mufassir's words with the modern editor's
/// footnotes. Keeping them apart lets the reader see clean commentary while the
/// notes stay available rather than being discarded.
class TafseerText {
  const TafseerText({required this.body, this.notes = const []});

  /// The commentary itself, with footnote pointers removed.
  final String body;

  /// The editor's notes, one entry per numbered footnote.
  final List<String> notes;

  bool get isEmpty => body.isEmpty && notes.isEmpty;
  bool get hasNotes => notes.isNotEmpty;
}

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

  /// Start of the editor's critical apparatus, e.g. `------- الهوامش :`.
  ///
  /// These notes belong to the modern print edition rather than to the
  /// mufassir: they cross-reference earlier volumes, record manuscript
  /// variants and trace narrator chains. They are shown separately so the
  /// commentary reads cleanly without discarding published scholarship.
  static final RegExp _footnoteSeparator = RegExp(
    r'[-\u2010-\u2015]{3,}\s*الهوامش\s*:?',
  );

  /// A numbered footnote marker such as `(25)`.
  static final RegExp _footnoteMarker = RegExp(r'\((\d+)\)');

  /// The start of a note definition, i.e. a marker at the head of an entry.
  static final RegExp _footnoteDefinition = RegExp(r'\(\d+\)\s*');

  /// Section dividers and dashes left dangling once the notes are removed.
  static final RegExp _trailingDecoration = RegExp(
    r'[\s*\u2022\u00b7\-\u2010-\u2015]+$',
  );

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
  ///
  /// Returns the commentary only. Use [parse] to keep the editor's notes.
  static String stripHtml(String html, {int? ayahNumber}) =>
      parse(html, ayahNumber: ayahNumber).body;

  /// Splits [html] into readable commentary and the editor's numbered notes.
  ///
  /// Pass [ayahNumber] so the verse's own number is never mistaken for a
  /// footnote marker when the two happen to collide.
  static TafseerText parse(String html, {int? ayahNumber}) {
    if (html.isEmpty) return const TafseerText(body: '');

    // Tags are removed first so decoded entities can never introduce markup.
    var text = html.replaceAll(_tag, ' ');
    text = _decodeEntities(text);
    text = text.replaceAll(_printPageMarker, ' ');
    text = text.replaceAll(_strayMarkerDelimiter, ' ');
    text = _normalizeWhitespace(text);

    return _splitEditorialFootnotes(text, ayahNumber);
  }

  /// Separates the editor's footnote section from the commentary body.
  ///
  /// Only markers actually defined in that section are removed from the body,
  /// so an ayah number such as `(64)` survives when no footnote `(64)` exists.
  /// When the numbers do collide, the first occurrence is kept as the verse
  /// citation, because footnote numbering starts low enough to clash with it.
  static TafseerText _splitEditorialFootnotes(String text, int? ayahNumber) {
    final separator = _footnoteSeparator.firstMatch(text);
    if (separator == null) return TafseerText(body: text);

    final rawBody = text.substring(0, separator.start);
    final notes = _splitNotes(text.substring(separator.end));
    if (notes.isEmpty) {
      return TafseerText(body: _trimDecoration(rawBody));
    }

    final defined = notes
        .map((note) => _footnoteMarker.matchAsPrefix(note)?.group(1))
        .whereType<String>()
        .toSet();

    final verseMarker = ayahNumber?.toString();
    var keptVerseMarker = false;
    final body = rawBody.replaceAllMapped(_footnoteMarker, (match) {
      final number = match.group(1)!;
      if (!defined.contains(number)) return match.group(0)!;
      if (number == verseMarker && !keptVerseMarker) {
        keptVerseMarker = true;
        return match.group(0)!;
      }
      return ' ';
    });

    return TafseerText(body: _trimDecoration(body), notes: notes);
  }

  /// Breaks the apparatus into entries, each beginning with its own marker.
  static List<String> _splitNotes(String section) {
    final starts = _footnoteDefinition
        .allMatches(section)
        .map((match) => match.start)
        .toList();
    if (starts.isEmpty) return const [];

    final notes = <String>[];
    for (var i = 0; i < starts.length; i++) {
      final end = i + 1 < starts.length ? starts[i + 1] : section.length;
      final note = _normalizeWhitespace(section.substring(starts[i], end));
      if (note.isNotEmpty) notes.add(note);
    }
    return notes;
  }

  static String _trimDecoration(String body) =>
      _normalizeWhitespace(body).replaceFirst(_trailingDecoration, '');

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
