import 'package:flutter/material.dart';

/// Illustrations are teaching samples, not substitutions in the Quran text.
class SukoonComparison extends StatelessWidget {
  final String languageCode;

  const SukoonComparison({super.key, required this.languageCode});

  static const samples = ['بۡ', 'و۟', 'بْ'];
  static const labels = {
    'en': [
      'Sukoon or an unpronounced letter?',
      'Small-head sukoon: pronounce the consonant without a vowel.',
      'Closed rounded zero over an unpronounced written alif (ا), waw (و), or ya (ي): omit only the marked letter when continuing or stopping. Other ا، و، ي are not silent unless marked.',
      'Ordinary Arabic sukoon can look circular too: the consonant is still pronounced without a vowel. Do not judge by a circle alone; follow the Mushaf’s notation.',
    ],
    'ar': [
      'سكون أم حرف لا يُنطق؟',
      'سكون برأس حاء صغيرة: يُنطق الحرف بلا حركة.',
      'صفر مستدير مغلق فوق ألف (ا) أو واو (و) أو ياء (ي) زائدة غير منطوقة: لا يُنطق إلا الحرف الذي يحمل العلامة وصلًا ولا وقفًا. ولا تسكت سائر حروف ا، و، ي.',
      'قد يُرسم السكون في الكتابة العربية المعتادة دائرة أيضًا، لكن الحرف يُنطق بلا حركة. لا تحكم من شكل الدائرة وحده؛ اتبع اصطلاح ضبط المصحف.',
    ],
    'ur': [
      'سکون یا غیر ملفوظ حرف؟',
      'چھوٹے سرِ حاء والا سکون: حرف کو حرکت کے بغیر ادا کریں۔',
      'بند گول صفر زائد اور غیر ملفوظ الف (ا)، واو (و)، یا یا (ي) پر: وصل اور وقف دونوں میں صرف نشان والا حرف نہیں پڑھا جاتا۔ باقی ا، و، ي خاموش نہیں ہوتے۔',
      'عام عربی سکون بھی گول دکھائی دے سکتا ہے، مگر حرف حرکت کے بغیر پڑھا جاتا ہے۔ صرف دائرہ دیکھ کر فیصلہ نہ کریں؛ مصحف کے ضبط کو دیکھیں۔',
    ],
    'tr': [
      'Sükûn mu, okunmayan harf mi?',
      'Küçük hâ başı biçimindeki sükûn: ünsüzü harekesiz okuyun.',
      'Yazıda bulunan ancak okunmayan elif (ا), vav (و) veya ya (ي) üzerindeki kapalı yuvarlak sıfır: vasılda ve vakıfta yalnızca işaretli harf okunmaz. Diğer ا، و، ي harfleri işaret yoksa sessiz değildir.',
      'Normal Arapça sükûn da daire biçiminde olabilir; ünsüz yine harekesiz okunur. Yalnız daireye bakarak karar vermeyin; Mushafın işaretleme düzenini izleyin.',
    ],
    'fr': [
      'Soukoun ou lettre non prononcée ?',
      'Soukoun en petite tête de hâ : prononcez la consonne sans voyelle.',
      'Zéro rond fermé sur un alif (ا), waw (و) ou ya (ي) écrit mais non prononcé : seule la lettre marquée est omise en continuant comme à l’arrêt. Les autres ا، و، ي ne sont pas muets sans ce signe.',
      'Le soukoun arabe ordinaire peut aussi être circulaire ; la consonne reste prononcée sans voyelle. Ne vous fiez pas au cercle seul ; suivez la notation du Mushaf.',
    ],
    'id': [
      'Sukun atau huruf yang tidak dibaca?',
      'Sukun berbentuk kepala ha kecil: ucapkan konsonan tanpa vokal.',
      'Nol bulat tertutup pada alif (ا), wau (و), atau ya (ي) tertulis yang tidak dibaca: hanya huruf bertanda yang diabaikan saat wasal maupun waqaf. ا، و، ي lainnya tidak diam jika tidak bertanda.',
      'Sukun Arab biasa juga dapat berbentuk lingkaran; konsonan tetap dibaca tanpa vokal. Jangan menilai dari lingkaran saja; ikuti tanda baca Mushaf.',
    ],
    'de': [
      'Sukun oder stummer Buchstabe?',
      'Sukun in Form eines kleinen Ha-Kopfes: den Konsonanten ohne Vokal aussprechen.',
      'Geschlossene runde Null über einem geschriebenen, ungesprochenen Alif (ا), Waw (و) oder Ya (ي): Nur der markierte Buchstabe entfällt beim Weiterlesen und beim Anhalten. Andere ا، و، ي sind ohne dieses Zeichen nicht stumm.',
      'Auch gewöhnliches arabisches Sukun kann kreisförmig sein; der Konsonant wird trotzdem ohne Vokal gesprochen. Nicht allein nach dem Kreis urteilen; die Zeichenkonvention des Mushaf beachten.',
    ],
    'es': [
      '¿Sukún o letra no pronunciada?',
      'Sukún con forma de pequeña cabeza de ha: pronuncie la consonante sin vocal.',
      'Cero redondo cerrado sobre un alif (ا), waw (و) o ya (ي) escrito pero no pronunciado: solo se omite la letra marcada al continuar o detenerse. Las demás ا، و، ي no son mudas sin este signo.',
      'El sukún árabe habitual también puede ser circular; la consonante sigue pronunciándose sin vocal. No se guíe solo por el círculo; siga la notación del Mushaf.',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final strings = labels[languageCode] ?? labels['en']!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.first, style: Theme.of(context).textTheme.titleMedium),
        for (var index = 0; index < samples.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    samples[index],
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: 36,
                      height: 1.8,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(strings[index + 1])),
              ],
            ),
          ),
      ],
    );
  }
}
