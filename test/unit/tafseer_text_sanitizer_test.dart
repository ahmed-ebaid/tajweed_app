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

    test('splits the editorial footnote section off the commentary', () {
      const html =
          '<p>قل يا أهل الكتاب (24) تعالوا إلى كلمة (25) سواء بيننا</p>'
          '<p>----------------------- الهوامش :</p>'
          '<p>(24) انظر تفسير "سواء" فيما سلف 1: 256</p>'
          '<p>(25) في المطبوعة: زيادة</p>';

      final result = TafseerTextSanitizer.parse(html);

      expect(result.body, 'قل يا أهل الكتاب تعالوا إلى كلمة سواء بيننا');
      expect(result.notes, [
        '(24) انظر تفسير "سواء" فيما سلف 1: 256',
        '(25) في المطبوعة: زيادة',
      ]);
    });

    test('keeps the verse number when it collides with a footnote', () {
      const html =
          '<p>﴿قل يا أهل الكتاب﴾ (64) وقوله (64) يعني (2) كذا</p>'
          '<p>------------ الهوامش:</p>'
          '<p>(2) نص الحاشية</p>'
          '<p>(64) حاشية أخرى</p>';

      // Only the first `(64)` survives, as the verse citation.
      final result = TafseerTextSanitizer.stripHtml(html, ayahNumber: 64);

      expect(result, '﴿قل يا أهل الكتاب﴾ (64) وقوله يعني كذا');
    });

    test('keeps parenthesised numbers that no footnote defines', () {
      const html =
          '<p>ذكر في الآية (5) وفي غيرها (7) بيان</p>'
          '<p>--------- الهوامش :</p>'
          '<p>(7) تعليق المحقق</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, 'ذكر في الآية (5) وفي غيرها بيان');
    });

    test('trims section decoration left dangling before the notes', () {
      const html =
          '<p>خاتمة الكلام (3)</p><p> * * * </p>'
          '<p>-------------- الهوامش :</p><p>(3) حاشية</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, 'خاتمة الكلام');
    });

    test('leaves text untouched when there is no footnote section', () {
      const html = '<p>تفسير بغير حواشٍ وفيه رقم (12) مذكور</p>';

      final result = TafseerTextSanitizer.stripHtml(html, ayahNumber: 12);

      expect(result, 'تفسير بغير حواشٍ وفيه رقم (12) مذكور');
    });

    test('requires the separator rule before dropping a notes section', () {
      const html = '<p>ذكر الهوامش في سياق الكلام (4) فقط</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, 'ذكر الهوامش في سياق الكلام (4) فقط');
    });

    test('renders the clause separator as an em dash', () {
      const html = '<p>وهم أهل التوراة والإنجيل = " تعالوا " ، هلموا</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, 'وهم أهل التوراة والإنجيل — " تعالوا " ، هلموا');
    });

    test('normalizes separator spacing and repetition', () {
      const html = '<p>الأول=الثاني ==  الثالث</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, 'الأول — الثاني — الثالث');
    });

    test('drops a separator left dangling at either end', () {
      const html = '<p>= متن الكلام =</p>';

      final result = TafseerTextSanitizer.stripHtml(html);

      expect(result, 'متن الكلام');
    });

    test('converts separators inside the editor notes too', () {
      const html =
          '<p>المتن</p>'
          '<p>-------------- الهوامش :</p>'
          '<p>(1) الأثر = انظر ما مضى</p>';

      final result = TafseerTextSanitizer.parse(html);

      expect(result.notes, ['(1) الأثر — انظر ما مضى']);
    });

    test('keeps the apparatus rule distinct from clause separators', () {
      const html =
          '<p>المتن (1) هنا = وهناك</p>'
          '<p>-------------- الهوامش :</p>'
          '<p>(1) حاشية</p>';

      final result = TafseerTextSanitizer.parse(html);

      expect(result.body, 'المتن هنا — وهناك');
      expect(result.notes, ['(1) حاشية']);
    });
  });
}
