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
      'Closed rounded zero: this marked letter is not pronounced when continuing or stopping.',
      'Ordinary Arabic sukoon can look circular too: the consonant is still pronounced without a vowel. Do not judge by a circle alone; follow the Mushaf’s notation.',
    ],
    'ar': [
      'سكون أم حرف لا يُنطق؟',
      'سكون برأس حاء صغيرة: يُنطق الحرف بلا حركة.',
      'صفر مستدير مغلق: الحرف الذي يحمل هذه العلامة لا يُنطق وصلًا ولا وقفًا.',
      'قد يُرسم السكون في الكتابة العربية المعتادة دائرة أيضًا، لكن الحرف يُنطق بلا حركة. لا تحكم من شكل الدائرة وحده؛ اتبع اصطلاح ضبط المصحف.',
    ],
    'ur': [
      'سکون یا غیر ملفوظ حرف؟',
      'چھوٹے سرِ حاء والا سکون: حرف کو حرکت کے بغیر ادا کریں۔',
      'بند گول صفر: اس نشان والا حرف وصل اور وقف دونوں میں نہیں پڑھا جاتا۔',
      'عام عربی سکون بھی گول دکھائی دے سکتا ہے، مگر حرف حرکت کے بغیر پڑھا جاتا ہے۔ صرف دائرہ دیکھ کر فیصلہ نہ کریں؛ مصحف کے ضبط کو دیکھیں۔',
    ],
    'tr': [
      'Sükûn mu, okunmayan harf mi?',
      'Küçük hâ başı biçimindeki sükûn: ünsüzü harekesiz okuyun.',
      'Kapalı yuvarlak sıfır: işaretli harf vasılda da vakıfta da okunmaz.',
      'Normal Arapça sükûn da daire biçiminde olabilir; ünsüz yine harekesiz okunur. Yalnız daireye bakarak karar vermeyin; Mushafın işaretleme düzenini izleyin.',
    ],
    'fr': [
      'Soukoun ou lettre non prononcée ?',
      'Soukoun en petite tête de hâ : prononcez la consonne sans voyelle.',
      'Zéro rond fermé : la lettre marquée ne se prononce ni en continuant ni à l’arrêt.',
      'Le soukoun arabe ordinaire peut aussi être circulaire ; la consonne reste prononcée sans voyelle. Ne vous fiez pas au cercle seul ; suivez la notation du Mushaf.',
    ],
    'id': [
      'Sukun atau huruf yang tidak dibaca?',
      'Sukun berbentuk kepala ha kecil: ucapkan konsonan tanpa vokal.',
      'Nol bulat tertutup: huruf bertanda ini tidak dibaca saat wasal maupun waqaf.',
      'Sukun Arab biasa juga dapat berbentuk lingkaran; konsonan tetap dibaca tanpa vokal. Jangan menilai dari lingkaran saja; ikuti tanda baca Mushaf.',
    ],
    'de': [
      'Sukun oder stummer Buchstabe?',
      'Sukun in Form eines kleinen Ha-Kopfes: den Konsonanten ohne Vokal aussprechen.',
      'Geschlossene runde Null: der markierte Buchstabe wird weder beim Weiterlesen noch beim Anhalten ausgesprochen.',
      'Auch gewöhnliches arabisches Sukun kann kreisförmig sein; der Konsonant wird trotzdem ohne Vokal gesprochen. Nicht allein nach dem Kreis urteilen; die Zeichenkonvention des Mushaf beachten.',
    ],
    'es': [
      '¿Sukún o letra no pronunciada?',
      'Sukún con forma de pequeña cabeza de ha: pronuncie la consonante sin vocal.',
      'Cero redondo cerrado: la letra marcada no se pronuncia ni al continuar ni al detenerse.',
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
