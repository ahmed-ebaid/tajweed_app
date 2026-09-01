import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/features/reader/tafseer_text_sanitizer.dart';

void main() {
  group('TafseerTextSanitizer.stripHtml', () {
    test('removes Tabari print-edition volume/page markers', () {
      // Real payload shape from tafsir 15 (al-Tabari), ayah 3:64.
      const html =
          '<p>وهم الذين حاجوا في إبراهيم.</p><p>&amp;; 6-484 &amp;;</p>'
          '<p lang="ar" class="ar ">7192 - حدثني المثنى قال</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, contains('وهم الذين حاجوا في إبراهيم.'));
      expect(result, contains('7192 - حدثني المثنى قال'));
      expect(result, isNot(contains('&')));
      expect(result, isNot(contains(';')));
      expect(result, isNot(contains('6-484')));
    });

    test('removes markers split across inline markup', () {
      const html =
          '<span>تعالوا إلى كلمة سواء</span>، &amp;; 6-<span class="blue">485 '
          '&amp;; فقرأ حتى بلغ</span>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, contains('تعالوا إلى كلمة سواء'));
      expect(result, contains('فقرأ حتى بلغ'));
      expect(result, isNot(contains('485')));
      expect(result, isNot(contains('&')));
    });

    test('removes markers written with Arabic-Indic digits', () {
      const html = '<p>نص قبل &amp;; ٦-٤٨٤ &amp;; نص بعد</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, 'نص قبل نص بعد');
    });

    test('decodes numeric and hex character references', () {
      const html = '<p>&#1575;&#1604;&#1604;&#1607; &#x633;&#x644;&#x627;&#x645;</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, 'الله سلام');
    });

    test('decodes named entities without re-decoding escaped ampersands', () {
      const html = '<p>Ibn&nbsp;Kathir &amp;lt;note&amp;gt; &quot;q&quot; &amp; more</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      // The escaped sequence must stay literal instead of becoming a tag.
      expect(result, 'Ibn Kathir &lt;note&gt; "q" & more');
    });

    test('drops unbalanced stray marker delimiters', () {
      const html = '<p>بداية &amp;; نهاية</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, 'بداية نهاية');
    });

    test('does not merge words when tags are removed', () {
      const html = '<p>الحمد</p><p>لله</p>';

      expect(TafseerTextSanitizer.stripHtml(html), 'الحمد لله');
    });

    test('collapses whitespace and trims the result', () {
      const html = '<p>   الحمد \n\n  لله   </p>';

      expect(TafseerTextSanitizer.stripHtml(html), 'الحمد لله');
    });

    test('returns empty string for empty or markup-only input', () {
      expect(TafseerTextSanitizer.stripHtml(''), '');
      expect(TafseerTextSanitizer.stripHtml('<p></p><br/>'), '');
    });

    test('preserves ordinary hyphenated numbers outside markers', () {
      const html = '<p>7192 - حدثنا 6-484 نص</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, '7192 - حدثنا 6-484 نص');
    });
  });
}
