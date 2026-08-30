import 'tajweed_article.dart';

class TajweedArticlesRepository {
  static const supportedLanguageCodes = [
    'en',
    'ar',
    'ur',
    'tr',
    'fr',
    'id',
    'de',
    'es',
  ];

  static const all = <TajweedArticle>[
    TajweedArticle(
      id: 'tafkhim',
      category: TajweedArticleCategory.fundamentals,
      titles: {
        'en': 'Tafkhim',
        'ar': 'التفخيم',
        'ur': 'تفخیم',
        'tr': 'Tefhim',
        'fr': 'Tafkhim',
        'id': 'Tafkhim',
        'de': 'Tafkhim',
        'es': 'Tafkhim',
      },
      summaries: {
        'en': 'How full letters are pronounced and when heaviness changes.',
        'ar': 'كيفية نطق الحروف المفخمة وتفاوت مراتب التفخيم.',
        'ur': 'بھاری حروف کی ادائیگی اور تفخیم کے درجات۔',
        'tr': 'Kalın harflerin okunuşu ve kalınlık derecelerinin değişimi.',
        'fr': 'La prononciation emphatique et ses différents degrés.',
        'id': 'Cara membaca huruf tebal dan perbedaan tingkat ketebalannya.',
        'de': 'Die volle Aussprache und ihre unterschiedlichen Stufen.',
        'es': 'La pronunciación gruesa y sus diferentes grados.',
      },
      sectionTitles: {
        'en': [
          'The seven full letters',
          'Degrees of Tafkhim',
          'Conditional cases',
        ],
        'ar': ['حروف الاستعلاء السبعة', 'مراتب التفخيم', 'الحالات المشروطة'],
        'ur': ['سات حروفِ استعلاء', 'تفخیم کے درجات', 'مشروط صورتیں'],
        'tr': ['Yedi kalın harf', 'Tefhim dereceleri', 'Şarta bağlı durumlar'],
        'fr': [
          'Les sept lettres emphatiques',
          'Les degrés du Tafkhim',
          'Les cas conditionnels',
        ],
        'id': ['Tujuh huruf tebal', 'Tingkatan Tafkhim', 'Kondisi khusus'],
        'de': [
          'Die sieben vollen Buchstaben',
          'Stufen des Tafkhim',
          'Bedingte Fälle',
        ],
        'es': [
          'Las siete letras gruesas',
          'Grados de Tafkhim',
          'Casos condicionales',
        ],
      },
      bodies: {
        'en':
            'The seven letters خ ص ض غ ط ق ظ are always pronounced with Tafkhim. Raise the back of the tongue so the sound fills the mouth, while avoiding forced lip rounding unless the letter carries dammah. Examples include قَالَ، طَيِّب، and خُلِقَ.\n\nTafkhim is strongest with fathah followed by alif, then fathah, dammah, sukun, and kasrah in a common practical ordering. A sakin full letter is influenced by the vowel before it, so listen carefully rather than giving every occurrence the same weight.\n\nRa is full with fathah or dammah and in several sakin cases. The lam in the name of Allah is full after fathah or dammah, as in قَالَ اللَّهُ, while alif takes the quality of the letter before it. Detailed exceptions of Ra should be learned from a qualified teacher.',
        'ar':
            'حروف الاستعلاء السبعة خ ص ض غ ط ق ظ مفخمة دائماً. يرتفع أقصى اللسان فيمتلئ الفم بصدى الحرف، من غير تكلّف ضم الشفتين إلا مع الضمة. ومن أمثلتها: قَالَ، طَيِّب، خُلِقَ.\n\nأعلى مراتب التفخيم المفتوح بعده ألف، ثم المفتوح، ثم المضموم، ثم الساكن، ثم المكسور في ترتيب تعليمي شائع. ويتأثر الحرف المفخم الساكن بحركة ما قبله، فلا تُسوّى جميع مراتبه في الأداء.\n\nتفخم الراء إذا كانت مفتوحة أو مضمومة وفي أحوال من السكون. وتفخم لام لفظ الجلالة بعد فتح أو ضم، مثل قَالَ اللَّهُ، وتتبع الألف ما قبلها تفخيماً وترقيقاً. وتُتلقى استثناءات الراء الدقيقة من معلّم متقن.',
        'ur':
            'استعلاء کے سات حروف خ ص ض غ ط ق ظ ہمیشہ بھاری پڑھے جاتے ہیں۔ زبان کا پچھلا حصہ بلند ہوتا ہے اور آواز منہ میں بھر جاتی ہے، مگر ضمہ کے سوا ہونٹوں کو زبردستی گول نہ کیا جائے۔ مثالیں: قَالَ، طَيِّب، خُلِقَ۔\n\nتفخیم کا بلند ترین درجہ فتحہ کے بعد الف، پھر فتحہ، ضمہ، سکون اور کسرہ ہے۔ ساکن حرف کی قوت اس سے پہلے کی حرکت سے بھی متاثر ہوتی ہے، اس لیے ہر صورت کو یکساں بھاری نہ پڑھیں۔\n\nراء فتحہ یا ضمہ کے ساتھ اور بعض ساکن حالتوں میں بھاری ہوتی ہے۔ لفظ اللہ کا لام فتحہ یا ضمہ کے بعد، جیسے قَالَ اللَّهُ، بھاری ہے؛ الف اپنے سے پہلے حرف کے تابع ہے۔ راء کی باریک تفصیلات ماہر استاد سے سیکھی جائیں۔',
        'tr':
            'İsti‘lâ harfleri خ ص ض غ ط ق ظ daima kalın okunur. Dilin arkası yükselir ve ses ağzı doldurur; damme dışında dudaklar gereksiz yere yuvarlanmaz. Örnekler: قَالَ، طَيِّب، خُلِقَ.\n\nYaygın öğretim sırasına göre tefhim; fethadan sonra elifte en güçlü, ardından fetha, damme, sükûn ve kesrede daha hafiftir. Sakin kalın harf önceki harekeden etkilenir; bütün örnekler aynı ağırlıkta okunmaz.\n\nRa fetha veya damme ile ve bazı sakin durumlarda kalın okunur. Allah lafzındaki lam fetha veya dammeden sonra, قَالَ اللَّهُ örneğindeki gibi, kalındır. Elif önceki harfe uyar. Ra’nın ayrıntılı istisnaları ehil bir hocadan öğrenilmelidir.',
        'fr':
            'Les sept lettres خ ص ض غ ط ق ظ sont toujours emphatiques. L’arrière de la langue se soulève et le son remplit la bouche, sans arrondir artificiellement les lèvres sauf avec une damma. Exemples : قَالَ، طَيِّب، خُلِقَ.\n\nDans un classement pédagogique courant, le Tafkhim est maximal avec fatha suivie d’alif, puis viennent fatha, damma, sukun et kasra. Une lettre emphatique sakin est influencée par la voyelle précédente ; toutes les occurrences n’ont donc pas la même force.\n\nLe ra est emphatique avec fatha ou damma et dans certains cas de sukun. Le lam du nom d’Allah est emphatique après fatha ou damma, comme dans قَالَ اللَّهُ. L’alif suit la qualité de la lettre précédente. Les exceptions du ra s’apprennent auprès d’un enseignant qualifié.',
        'id':
            'Tujuh huruf خ ص ض غ ط ق ظ selalu dibaca tebal. Pangkal lidah terangkat sehingga suara memenuhi mulut, tanpa membulatkan bibir secara berlebihan kecuali saat berharakat dammah. Contoh: قَالَ، طَيِّب، خُلِقَ.\n\nDalam urutan belajar yang umum, Tafkhim paling kuat pada fathah yang diikuti alif, lalu fathah, dammah, sukun, dan kasrah. Huruf tebal yang sukun dipengaruhi harakat sebelumnya, sehingga tidak semuanya dibaca dengan ketebalan yang sama.\n\nRa dibaca tebal saat berfathah atau berdammah dan pada beberapa kondisi sukun. Lam pada lafaz Allah tebal setelah fathah atau dammah, seperti قَالَ اللَّهُ. Alif mengikuti sifat huruf sebelumnya. Pelajari pengecualian Ra dari guru yang ahli.',
        'de':
            'Die sieben Buchstaben خ ص ض غ ط ق ظ werden immer voll ausgesprochen. Der hintere Teil der Zunge hebt sich und der Klang füllt den Mund; außer bei Damma werden die Lippen nicht künstlich gerundet. Beispiele: قَالَ، طَيِّب، خُلِقَ.\n\nIn einer üblichen Lernreihenfolge ist Tafkhim bei Fatha mit folgendem Alif am stärksten, danach folgen Fatha, Damma, Sukun und Kasra. Ein voller sakin-Buchstabe wird vom vorherigen Vokal beeinflusst; nicht jedes Vorkommen klingt gleich stark.\n\nRa wird mit Fatha oder Damma und in bestimmten Sukun-Fällen voll gesprochen. Das Lam im Namen Allah ist nach Fatha oder Damma voll, wie in قَالَ اللَّهُ. Alif folgt dem vorherigen Buchstaben. Feinheiten des Ra sollten bei einer qualifizierten Lehrkraft gelernt werden.',
        'es':
            'Las siete letras خ ص ض غ ط ق ظ siempre se pronuncian con sonido grueso. La parte posterior de la lengua se eleva y el sonido llena la boca, sin redondear los labios de forma forzada salvo con damma. Ejemplos: قَالَ، طَيِّب، خُلِقَ.\n\nEn una clasificación didáctica común, el Tafkhim es más fuerte con fatha seguida de alif; después vienen fatha, damma, sukun y kasra. Una letra gruesa sakin recibe influencia de la vocal anterior, por lo que no todas tienen la misma intensidad.\n\nRa es gruesa con fatha o damma y en ciertos casos de sukun. La lam del nombre de Allah es gruesa después de fatha o damma, como en قَالَ اللَّهُ. El alif sigue la cualidad de la letra anterior. Las excepciones de Ra deben aprenderse con un maestro cualificado.',
      },
    ),
    TajweedArticle(
      id: 'tarqiq',
      category: TajweedArticleCategory.fundamentals,
      titles: {
        'en': 'Tarqiq',
        'ar': 'الترقيق',
        'ur': 'ترقیق',
        'tr': 'Terkik',
        'fr': 'Tarqiq',
        'id': 'Tarqiq',
        'de': 'Tarqiq',
        'es': 'Tarqiq',
      },
      summaries: {
        'en':
            'How light letters are pronounced and the special cases of Ra and Lam.',
        'ar': 'كيفية نطق الحروف المرققة وأحكام الراء واللام الخاصة.',
        'ur': 'باریک حروف اور راء و لام کی خاص صورتوں کی ادائیگی۔',
        'tr': 'İnce harflerin ve Ra ile Lam’ın özel durumlarının okunuşu.',
        'fr':
            'La prononciation légère et les cas particuliers du ra et du lam.',
        'id': 'Cara membaca huruf tipis serta kondisi khusus Ra dan Lam.',
        'de': 'Die leichte Aussprache und die Sonderfälle von Ra und Lam.',
        'es': 'La pronunciación ligera y los casos especiales de Ra y Lam.',
      },
      sectionTitles: {
        'en': [
          'Letters normally read lightly',
          'When Ra is light',
          'Lam and Alif',
        ],
        'ar': ['الحروف المرققة أصلاً', 'مواضع ترقيق الراء', 'اللام والألف'],
        'ur': ['اصلاً باریک حروف', 'راء کب باریک ہے', 'لام اور الف'],
        'tr': [
          'Aslen ince harfler',
          'Ra’nın ince okunduğu yerler',
          'Lam ve Elif',
        ],
        'fr': [
          'Les lettres normalement légères',
          'Quand le ra est léger',
          'Le lam et l’alif',
        ],
        'id': [
          'Huruf yang pada dasarnya tipis',
          'Kapan Ra dibaca tipis',
          'Lam dan Alif',
        ],
        'de': [
          'Grundsätzlich leichte Buchstaben',
          'Wann Ra leicht ist',
          'Lam und Alif',
        ],
        'es': [
          'Letras normalmente ligeras',
          'Cuándo Ra es ligera',
          'Lam y Alif',
        ],
      },
      bodies: {
        'en':
            'All Arabic letters are normally light except the seven full letters خ ص ض غ ط ق ظ and conditional cases of Ra, the lam in Allah, and alif. Keep the tongue relaxed and avoid letting the sound fill the mouth. Examples include بِسْمِ، نَعْبُدُ، and هِدَايَة.\n\nRa is light when it carries kasrah, as in رِزْقًا, and commonly when it is sakin after an original kasrah with no full letter following it in the same word, as in فِرْعَوْنَ. Some Quranic words are exceptions or permit more than one transmitted treatment, so advanced cases require direct study.\n\nLam is normally light. In the name of Allah it is light after kasrah, as in بِسْمِ اللَّهِ, but full after fathah or dammah. Alif has no independent Tafkhim or Tarqiq: it follows the preceding letter, light in كَانَ and full in قَالَ.',
        'ar':
            'الأصل في الحروف العربية الترقيق، ما عدا حروف الاستعلاء السبعة خ ص ض غ ط ق ظ، وما يعرض للراء ولام لفظ الجلالة والألف. يُحافظ على انخفاض اللسان وخفة الصوت من غير ملء الفم بصداه. ومن الأمثلة: بِسْمِ، نَعْبُدُ، هِدَايَة.\n\nترقق الراء إذا كانت مكسورة، مثل رِزْقًا، وترقق غالباً إذا كانت ساكنة قبلها كسرة أصلية ولم يأت بعدها حرف استعلاء في الكلمة نفسها، مثل فِرْعَوْنَ. وفي القرآن كلمات مستثناة أو أوجه منقولة تحتاج إلى التلقي المباشر.\n\nالأصل في اللام الترقيق. وترقق لام لفظ الجلالة إذا سبقها كسر، مثل بِسْمِ اللَّهِ، وتفخم بعد فتح أو ضم. وليس للألف تفخيم أو ترقيق مستقل، بل تتبع ما قبلها؛ فترقق في كَانَ وتفخم في قَالَ.',
        'ur':
            'عربی کے تمام حروف اصولاً باریک ہیں، سوائے سات حروفِ استعلاء خ ص ض غ ط ق ظ اور راء، لفظ اللہ کے لام اور الف کی مشروط صورتوں کے۔ زبان کو ہلکا رکھیں اور آواز کو منہ میں ضرورت سے زیادہ نہ بھریں۔ مثالیں: بِسْمِ، نَعْبُدُ، هِدَايَة۔\n\nراء کسرہ کے ساتھ باریک ہے، جیسے رِزْقًا، اور عموماً اس وقت بھی جب ساکن ہو، اس سے پہلے اصلی کسرہ ہو اور اسی لفظ میں آگے حرفِ استعلاء نہ ہو، جیسے فِرْعَوْنَ۔ بعض قرآنی الفاظ مستثنیٰ ہیں یا منقول وجوہ رکھتے ہیں، اس لیے اعلیٰ صورتیں استاد سے سیکھی جائیں۔\n\nلام اصولاً باریک ہے۔ لفظ اللہ کا لام کسرہ کے بعد، جیسے بِسْمِ اللَّهِ، باریک اور فتحہ یا ضمہ کے بعد بھاری ہے۔ الف خود مستقل طور پر بھاری یا باریک نہیں؛ وہ پچھلے حرف کی پیروی کرتا ہے، جیسے كَانَ میں باریک اور قَالَ میں بھاری۔',
        'tr':
            'Arapça harfler esas olarak incedir; خ ص ض غ ط ق ظ harfleri ile Ra, Allah lafzındaki lam ve elifin şartlı durumları istisnadır. Dil rahat tutulur ve ses gereksiz yere ağzı doldurmaz. Örnekler: بِسْمِ، نَعْبُدُ، هِدَايَة.\n\nRa kesreli olduğunda, رِزْقًا örneğindeki gibi, ince okunur. Genellikle sakin olup öncesinde aslî kesre bulunduğunda ve aynı kelimede ardından kalın harf gelmediğinde de incedir; فِرْعَوْنَ buna örnektir. Bazı Kur’an kelimeleri istisnadır veya birden fazla nakledilmiş vecih içerir.\n\nLam esas olarak incedir. Allah lafzındaki lam kesreden sonra, بِسْمِ اللَّهِ örneğinde olduğu gibi, ince; fetha veya dammeden sonra kalındır. Elifin bağımsız tefhim veya terkiki yoktur: كَانَ kelimesinde ince, قَالَ kelimesinde kalın olarak önceki harfe uyar.',
        'fr':
            'Toutes les lettres arabes sont normalement légères, sauf خ ص ض غ ط ق ظ et les cas conditionnels du ra, du lam dans le nom d’Allah et de l’alif. La langue reste détendue et le son ne remplit pas excessivement la bouche. Exemples : بِسْمِ، نَعْبُدُ، هِدَايَة.\n\nLe ra est léger avec kasra, comme dans رِزْقًا. Il l’est généralement lorsqu’il est sakin après une kasra d’origine sans lettre emphatique après lui dans le même mot, comme dans فِرْعَوْنَ. Certains mots coraniques sont des exceptions ou admettent plusieurs traitements transmis.\n\nLe lam est normalement léger. Dans le nom d’Allah, il est léger après kasra, comme dans بِسْمِ اللَّهِ, mais emphatique après fatha ou damma. L’alif n’a pas de qualité indépendante : il suit la lettre précédente, léger dans كَانَ et emphatique dans قَالَ.',
        'id':
            'Semua huruf Arab pada dasarnya dibaca tipis, kecuali خ ص ض غ ط ق ظ serta kondisi khusus Ra, lam pada lafaz Allah, dan alif. Lidah tetap rileks dan suara tidak memenuhi mulut secara berlebihan. Contoh: بِسْمِ، نَعْبُدُ، هِدَايَة.\n\nRa dibaca tipis ketika berkasrah, seperti رِزْقًا. Umumnya Ra juga tipis saat sukun setelah kasrah asli dan tidak diikuti huruf tebal dalam kata yang sama, seperti فِرْعَوْنَ. Beberapa kata Al-Quran merupakan pengecualian atau memiliki lebih dari satu cara yang diriwayatkan.\n\nLam pada dasarnya tipis. Lam pada lafaz Allah tipis setelah kasrah, seperti بِسْمِ اللَّهِ, tetapi tebal setelah fathah atau dammah. Alif tidak memiliki Tafkhim atau Tarqiq sendiri; ia mengikuti huruf sebelumnya, tipis pada كَانَ dan tebal pada قَالَ.',
        'de':
            'Alle arabischen Buchstaben sind grundsätzlich leicht, außer خ ص ض غ ط ق ظ und den bedingten Fällen von Ra, dem Lam im Namen Allah und Alif. Die Zunge bleibt entspannt und der Klang füllt den Mund nicht übermäßig. Beispiele: بِسْمِ، نَعْبُدُ، هِدَايَة.\n\nRa ist mit Kasra leicht, wie in رِزْقًا. Es ist gewöhnlich auch leicht, wenn es sakin nach einer ursprünglichen Kasra steht und im selben Wort kein voller Buchstabe folgt, wie in فِرْعَوْنَ. Einige koranische Wörter sind Ausnahmen oder besitzen mehrere überlieferte Lesarten.\n\nLam ist grundsätzlich leicht. Im Namen Allah ist es nach Kasra leicht, wie in بِسْمِ اللَّهِ, aber nach Fatha oder Damma voll. Alif besitzt keine unabhängige Qualität: Es folgt dem vorherigen Buchstaben, leicht in كَانَ und voll in قَالَ.',
        'es':
            'Todas las letras árabes son normalmente ligeras, excepto خ ص ض غ ط ق ظ y los casos condicionales de Ra, la lam del nombre de Allah y el alif. La lengua se mantiene relajada y el sonido no llena la boca en exceso. Ejemplos: بِسْمِ، نَعْبُدُ، هِدَايَة.\n\nRa es ligera con kasra, como en رِزْقًا. Generalmente también es ligera cuando está sakin después de una kasra original y no la sigue una letra gruesa en la misma palabra, como en فِرْعَوْنَ. Algunas palabras coránicas son excepciones o admiten más de un tratamiento transmitido.\n\nLam es normalmente ligera. En el nombre de Allah es ligera después de kasra, como en بِسْمِ اللَّهِ, pero gruesa después de fatha o damma. El alif no tiene cualidad independiente: sigue a la letra anterior, ligera en كَانَ y gruesa en قَالَ.',
      },
    ),
    TajweedArticle(
      id: 'waqf_ibtida',
      category: TajweedArticleCategory.fundamentals,
      titles: {
        'en': 'Stopping and Starting',
        'ar': 'الوقف والابتداء',
        'ur': 'وقف اور ابتداء',
        'tr': 'Vakıf ve İbtida',
        'fr': 'Arrêt et reprise',
        'id': 'Waqaf dan Ibtida',
        'de': 'Anhalten und Beginnen',
        'es': 'Pausa y comienzo',
      },
      summaries: {
        'en': 'How to pause and resume without distorting the Quranic meaning.',
        'ar': 'كيفية الوقف والبدء من غير إخلال بالمعنى القرآني.',
        'ur':
            'قرآنی معنی کو متاثر کیے بغیر رکنے اور دوبارہ شروع کرنے کا طریقہ۔',
        'tr': 'Kur’an anlamını bozmadan durma ve yeniden başlama.',
        'fr': 'S’arrêter et reprendre sans altérer le sens coranique.',
        'id': 'Cara berhenti dan memulai kembali tanpa merusak makna Al-Quran.',
        'de':
            'Anhalten und fortsetzen, ohne die koranische Bedeutung zu verändern.',
        'es': 'Cómo pausar y reanudar sin alterar el significado coránico.',
      },
      bodies: {
        'en':
            'Stopping is chosen with regard to both breath and meaning. A complete stop ends a complete meaning; a sufficient or good stop may be acceptable while remaining connected to what follows.\n\nDo not deliberately stop where the wording creates a false, offensive, or incomplete meaning. If breath forces such a stop, return to a suitable earlier phrase before continuing.\n\nMushaf stop signs are practical guidance: م indicates a necessary stop, لا warns against stopping, ج permits either choice, and paired dots indicate stopping at one of the two places, not both. Meaning remains the governing principle.',
        'ar':
            'يُختار موضع الوقف بمراعاة النفس والمعنى معاً. فالوقف التام ينتهي عند تمام المعنى، وقد يصح الوقف الكافي أو الحسن مع بقاء تعلق بما بعده.\n\nلا يُتعمد الوقف حيث يوهم اللفظ معنى فاسداً أو قبيحاً أو ناقصاً. فإن اضطر القارئ لانقطاع النفس رجع عند الابتداء إلى موضع مناسب قبله.\n\nعلامات المصحف إرشاد عملي: (م) للوقف اللازم، و(لا) للنهي عن الوقف، و(ج) لجواز الوجهين، والنقاط المتعانقة للوقف على أحد الموضعين دون كليهما. ويبقى المعنى هو الأصل.',
        'ur':
            'وقف کی جگہ سانس اور معنی دونوں کو دیکھ کر منتخب کی جاتی ہے۔ وقفِ تام مکمل معنی پر ہوتا ہے، جبکہ وقفِ کافی یا حسن میں اگلے کلام سے کچھ تعلق باقی رہ سکتا ہے۔\n\nایسی جگہ جان بوجھ کر نہ رکیں جہاں غلط، نامناسب یا ادھورا معنی پیدا ہو۔ سانس ختم ہونے سے رکنا پڑے تو دوبارہ مناسب پچھلے مقام سے شروع کریں۔\n\nمصحف کی علامات رہنمائی کرتی ہیں: م لازم وقف، لا نہ رکنے، ج دونوں صورتوں کی اجازت، اور جوڑی دار نقطے دونوں میں سے صرف ایک مقام پر رکنے کی علامت ہیں۔ اصل معیار معنی ہے۔',
        'tr':
            'Durulacak yer nefes ve anlam birlikte gözetilerek seçilir. Tam vakıf anlamın tamamlandığı yerdedir; kâfi veya güzel vakıfta sonraki ifadeyle bağ sürebilir.\n\nYanlış, çirkin veya eksik bir anlam doğuran yerde bilerek durmayın. Nefes zorunlu kılarsa devam ederken daha önceki uygun bir ifadeden başlayın.\n\nMushaf işaretleri yol gösterir: م gerekli duruşu, لا durmamayı, ج iki seçeneğin de mümkün olduğunu, eşleşen noktalar ise iki yerden yalnız birinde durmayı bildirir. Temel ölçü anlamdır.',
        'fr':
            'Le lieu d’arrêt se choisit selon le souffle et le sens. Un arrêt complet clôt un sens complet ; un arrêt suffisant ou bon peut rester lié à la suite.\n\nNe vous arrêtez pas volontairement là où les mots produiraient un sens faux, inconvenant ou incomplet. Si le souffle l’impose, reprenez depuis une expression appropriée située avant.\n\nLes signes du Mushaf guident la lecture : م demande l’arrêt, لا le déconseille, ج permet les deux choix et les points jumelés indiquent de s’arrêter à l’un des deux endroits, pas aux deux. Le sens reste le critère principal.',
        'id':
            'Tempat berhenti dipilih dengan mempertimbangkan napas dan makna. Waqaf sempurna mengakhiri makna yang lengkap; waqaf cukup atau baik masih dapat berkaitan dengan kalimat berikutnya.\n\nJangan sengaja berhenti di tempat yang menimbulkan makna salah, buruk, atau belum lengkap. Jika napas memaksa berhenti, mulailah kembali dari frasa sebelumnya yang sesuai.\n\nTanda Mushaf memberi panduan: م berarti harus berhenti, لا jangan berhenti, ج membolehkan keduanya, dan titik berpasangan berarti berhenti pada salah satu tempat saja. Makna tetap menjadi pedoman utama.',
        'de':
            'Die Haltestelle wird nach Atem und Bedeutung gewählt. Ein vollständiger Halt schließt einen vollständigen Sinn ab; ein ausreichender oder guter Halt kann noch mit dem Folgenden verbunden sein.\n\nHalte nicht absichtlich dort, wo ein falscher, anstößiger oder unvollständiger Sinn entsteht. Erzwingt der Atem den Halt, beginne wieder bei einer geeigneten früheren Wortgruppe.\n\nMushaf-Zeichen helfen: م verlangt den Halt, لا warnt davor, ج erlaubt beide Möglichkeiten und gepaarte Punkte bedeuten, an nur einer der beiden Stellen zu halten. Die Bedeutung bleibt maßgeblich.',
        'es':
            'El lugar de pausa se elige considerando la respiración y el sentido. Una pausa completa cierra un significado completo; una pausa suficiente o buena puede conservar relación con lo siguiente.\n\nNo pauses deliberadamente donde se produzca un sentido falso, ofensivo o incompleto. Si la respiración obliga, reanuda desde una frase anterior adecuada.\n\nLos signos del Mushaf orientan: م indica pausa necesaria, لا advierte que no se pare, ج permite ambas opciones y los puntos emparejados indican parar en uno de los dos lugares, no en ambos. El sentido sigue siendo el criterio principal.',
      },
    ),
    TajweedArticle(
      id: 'recitation_etiquette',
      category: TajweedArticleCategory.miscellaneous,
      titles: {
        'en': 'Etiquette of Recitation and Completion',
        'ar': 'آداب التلاوة والختم',
        'ur': 'تلاوت اور ختم کے آداب',
        'tr': 'Tilavet ve Hatim Adabı',
        'fr': 'Éthique de la récitation et de la clôture',
        'id': 'Adab Tilawah dan Khatam',
        'de': 'Etikette der Rezitation und des Abschlusses',
        'es': 'Etiqueta de la recitación y la finalización',
      },
      summaries: {
        'en': 'Spiritual and practical manners for engaging with the Quran.',
        'ar': 'آداب قلبية وعملية عند تلاوة القرآن وختمه.',
        'ur': 'قرآن کی تلاوت اور ختم کے روحانی اور عملی آداب۔',
        'tr': 'Kur’an tilaveti ve hatmi için manevi ve pratik edepler.',
        'fr': 'Attitudes spirituelles et pratiques envers le Coran.',
        'id': 'Adab rohani dan praktis dalam berinteraksi dengan Al-Quran.',
        'de': 'Geistige und praktische Umgangsformen bei der Koranrezitation.',
        'es': 'Modales espirituales y prácticos al relacionarse con el Corán.',
      },
      bodies: {
        'en':
            'Recite sincerely, attentively, and with reflection. Choose a clean place, treat the Mushaf respectfully, and purification is recommended when handling it.\n\nRead with tartil: clearly, calmly, and without rushing. Beautify the voice naturally while preserving correct letters and rules; listen respectfully when the Quran is recited.\n\nOn completing the Quran, thank Allah and make permissible supplication. No particular completion formula is obligatory, and completion should lead to continued reading and practice rather than abandonment.',
        'ar':
            'تُستحضر النية والإخلاص والخشوع والتدبر، ويُختار المكان الطاهر، ويُصان المصحف، وتُستحب الطهارة عند مسّه.\n\nتكون القراءة ترتيلاً بتمهل ووضوح من غير عجلة، مع تحسين الصوت بلا تكلف والمحافظة على الحروف والأحكام، والإنصات عند سماع القرآن.\n\nعند الختم يُحمد الله ويُدعى بما تيسر من الدعاء المشروع، ولا تلزم صيغة مخصوصة. والختم بداية لمداومة جديدة على التلاوة والعمل لا سبباً للانقطاع.',
        'ur':
            'اخلاص، توجہ، خشوع اور تدبر کے ساتھ پڑھیں۔ پاک جگہ منتخب کریں، مصحف کا احترام کریں، اور اسے چھونے کے لیے طہارت مستحب ہے۔\n\nترتیل کے ساتھ واضح اور اطمینان سے پڑھیں، جلدی نہ کریں۔ حروف اور احکام درست رکھتے ہوئے آواز کو فطری طور پر خوبصورت بنائیں اور تلاوت کے وقت توجہ سے سنیں۔\n\nختم پر اللہ کا شکر ادا کریں اور جائز دعا کریں۔ کوئی خاص دعا لازم نہیں، اور ختم کے بعد تلاوت اور عمل کا سلسلہ جاری رہنا چاہیے۔',
        'tr':
            'İhlas, dikkat, huşu ve tefekkürle okuyun. Temiz bir yer seçin, Mushaf’a saygı gösterin; ona dokunurken abdestli olmak tavsiye edilir.\n\nTertil ile açık, sakin ve acele etmeden okuyun. Harfleri ve kuralları koruyarak sesi doğal biçimde güzelleştirin; Kur’an okunurken saygıyla dinleyin.\n\nHatimde Allah’a hamdedin ve meşru dualar edin. Belirli bir hatim duası zorunlu değildir; hatim, okumayı ve ameli bırakmak değil yeniden sürdürmek için başlangıçtır.',
        'fr':
            'Récitez avec sincérité, attention, humilité et réflexion. Choisissez un lieu propre, respectez le Mushaf ; l’état de pureté est recommandé pour le toucher.\n\nLisez avec tartil, clairement, calmement et sans précipitation. Embellissez naturellement la voix tout en préservant les lettres et les règles, et écoutez respectueusement la récitation.\n\nAprès avoir achevé le Coran, remerciez Allah et faites des invocations permises. Aucune formule particulière n’est obligatoire ; la clôture doit ouvrir une nouvelle continuité de lecture et de pratique.',
        'id':
            'Bacalah dengan ikhlas, khusyuk, perhatian, dan tadabur. Pilih tempat yang bersih, muliakan Mushaf, dan dianjurkan dalam keadaan suci ketika menyentuhnya.\n\nBacalah dengan tartil, jelas, tenang, dan tidak tergesa-gesa. Indahkan suara secara wajar sambil menjaga huruf dan hukum, serta dengarkan dengan hormat saat Al-Quran dibaca.\n\nSetelah khatam, pujilah Allah dan berdoalah dengan doa yang dibolehkan. Tidak ada bacaan khatam tertentu yang wajib; khatam hendaknya menjadi awal untuk terus membaca dan mengamalkan.',
        'de':
            'Rezitiere aufrichtig, aufmerksam, demütig und nachdenklich. Wähle einen sauberen Ort, behandle den Mushaf respektvoll; rituelle Reinheit beim Berühren wird empfohlen.\n\nLies mit Tartil: klar, ruhig und ohne Eile. Verschönere die Stimme natürlich, ohne Buchstaben und Regeln zu verändern, und höre einer Rezitation respektvoll zu.\n\nDanke Allah nach dem Abschluss und sprich erlaubte Bittgebete. Keine bestimmte Abschlussformel ist verpflichtend; der Abschluss soll zu weiterem Lesen und Handeln führen.',
        'es':
            'Recita con sinceridad, atención, humildad y reflexión. Elige un lugar limpio, trata el Mushaf con respeto y se recomienda la purificación al tocarlo.\n\nLee con tartil: claramente, con calma y sin prisas. Embellece la voz con naturalidad conservando letras y reglas, y escucha respetuosamente cuando se recite el Corán.\n\nAl completar el Corán, agradece a Allah y realiza súplicas permitidas. Ninguna fórmula concreta es obligatoria; la finalización debe llevar a continuar la lectura y la práctica.',
      },
    ),
    TajweedArticle(
      id: 'istiadha_basmala',
      category: TajweedArticleCategory.miscellaneous,
      titles: {
        'en': 'Isti‘adhah and Basmalah',
        'ar': 'الاستعاذة والبسملة',
        'ur': 'استعاذہ اور بسم اللہ',
        'tr': 'İstiâze ve Besmele',
        'fr': 'Isti‘adha et Basmala',
        'id': 'Isti‘adzah dan Basmalah',
        'de': 'Isti‘adha und Basmala',
        'es': 'Isti‘adha y Basmala',
      },
      summaries: {
        'en': 'What to say when beginning recitation and between surahs.',
        'ar': 'ما يُقال عند بدء التلاوة والانتقال بين السور.',
        'ur': 'تلاوت شروع کرتے اور سورتوں کے درمیان پڑھنے کے احکام۔',
        'tr': 'Tilavete başlarken ve sureler arasında söylenecekler.',
        'fr': 'Formules du début de récitation et entre les sourates.',
        'id': 'Bacaan saat memulai tilawah dan berpindah antarsurah.',
        'de':
            'Was zu Beginn der Rezitation und zwischen Suren gesprochen wird.',
        'es': 'Qué decir al comenzar la recitación y entre suras.',
      },
      bodies: {
        'en':
            'Begin recitation by seeking refuge in Allah, commonly: أعوذ بالله من الشيطان الرجيم. It may be read aloud or quietly according to the setting.\n\nRead the basmalah at the beginning of every surah except At-Tawbah. When beginning inside a surah, the basmalah is permissible but not required.\n\nBetween two surahs, one may join or separate the end, basmalah, and next beginning, but should not join the previous ending to the basmalah and then stop. Between Al-Anfal and At-Tawbah there is no basmalah; stop, pause briefly, or join directly.',
        'ar':
            'تُشرع الاستعاذة عند بدء التلاوة، وصيغتها المشهورة: «أعوذ بالله من الشيطان الرجيم»، ويُجهر أو يُسر بها بحسب المقام.\n\nتُقرأ البسملة في أول كل سورة سوى سورة التوبة. وعند الابتداء من أثناء السورة تجوز البسملة ولا تلزم.\n\nبين سورتين يجوز قطع الجميع أو وصل الجميع أو الوقف على آخر السورة ثم وصل البسملة بأول التالية، ولا يُوصل آخر السورة بالبسملة ثم يُوقف عليها. وبين الأنفال والتوبة لا بسملة؛ ويجوز الوقف أو السكت أو الوصل.',
        'ur':
            'تلاوت شروع کرتے وقت اللہ کی پناہ مانگیں، عام الفاظ ہیں: أعوذ بالله من الشيطان الرجيم۔ موقع کے مطابق بلند یا آہستہ پڑھا جا سکتا ہے۔\n\nسورۂ توبہ کے علاوہ ہر سورت کے آغاز میں بسم اللہ پڑھیں۔ سورت کے درمیان سے شروع کرتے وقت بسم اللہ جائز ہے لیکن لازم نہیں۔\n\nدو سورتوں کے درمیان اختتام، بسم اللہ اور اگلی ابتدا کو الگ یا ملا کر پڑھا جا سکتا ہے، لیکن پچھلی سورت کو بسم اللہ سے ملا کر بسم اللہ پر نہ رکیں۔ انفال اور توبہ کے درمیان بسم اللہ نہیں؛ وقف، مختصر سکتہ یا وصل جائز ہے۔',
        'tr':
            'Tilavete Allah’a sığınarak başlayın; yaygın ifade أعوذ بالله من الشيطان الرجيم şeklindedir. Ortama göre sesli veya sessiz okunabilir.\n\nTevbe suresi dışında her surenin başında besmele okunur. Surenin ortasından başlarken besmele caizdir fakat zorunlu değildir.\n\nİki sure arasında son, besmele ve yeni başlangıç ayrılabilir veya birleştirilebilir; ancak önceki son besmeleye bağlanıp besmelede durulmaz. Enfal ile Tevbe arasında besmele yoktur; durmak, kısa sekte yapmak veya doğrudan bağlamak mümkündür.',
        'fr':
            'Commencez la récitation en cherchant refuge auprès d’Allah, généralement par أعوذ بالله من الشيطان الرجيم. Elle peut être dite à voix haute ou basse selon le contexte.\n\nPrononcez la basmala au début de chaque sourate sauf At-Tawbah. En commençant au milieu d’une sourate, elle est permise mais non obligatoire.\n\nEntre deux sourates, on peut séparer ou relier la fin, la basmala et le début suivant, mais on ne relie pas la fin précédente à la basmala pour s’y arrêter. Entre Al-Anfal et At-Tawbah, pas de basmala : arrêt, courte pause ou liaison directe.',
        'id':
            'Mulailah tilawah dengan memohon perlindungan kepada Allah, umumnya: أعوذ بالله من الشيطان الرجيم. Boleh dibaca keras atau pelan sesuai keadaan.\n\nBacalah basmalah di awal setiap surah kecuali At-Tawbah. Ketika mulai dari tengah surah, basmalah boleh dibaca tetapi tidak wajib.\n\nDi antara dua surah, akhir surah, basmalah, dan awal berikutnya dapat dipisah atau disambung; namun jangan menyambung akhir surah ke basmalah lalu berhenti. Antara Al-Anfal dan At-Tawbah tidak ada basmalah; boleh berhenti, saktah singkat, atau langsung menyambung.',
        'de':
            'Beginne die Rezitation mit der Zufluchtsformel, üblich ist أعوذ بالله من الشيطان الرجيم. Je nach Situation kann sie laut oder leise gesprochen werden.\n\nSprich die Basmala am Anfang jeder Sure außer At-Tawbah. Beim Beginn innerhalb einer Sure ist sie erlaubt, aber nicht erforderlich.\n\nZwischen zwei Suren können Ende, Basmala und neuer Anfang getrennt oder verbunden werden; das vorige Ende soll jedoch nicht mit der Basmala verbunden und dort angehalten werden. Zwischen Al-Anfal und At-Tawbah gibt es keine Basmala: Halt, kurze Pause oder direkte Verbindung sind möglich.',
        'es':
            'Comienza la recitación buscando refugio en Allah, normalmente con أعوذ بالله من الشيطان الرجيم. Puede decirse en voz alta o baja según el contexto.\n\nLee la basmala al inicio de cada sura excepto At-Tawbah. Al comenzar dentro de una sura, está permitida pero no es obligatoria.\n\nEntre dos suras se pueden separar o unir el final, la basmala y el comienzo siguiente, pero no se debe unir el final anterior a la basmala y detenerse allí. Entre Al-Anfal y At-Tawbah no hay basmala: se puede parar, hacer una pausa breve o unir directamente.',
      },
    ),
    TajweedArticle(
      id: 'qiraat_qurra',
      category: TajweedArticleCategory.miscellaneous,
      titles: {
        'en': 'Qira’at and Reciters',
        'ar': 'معلومات عن القراءات والقراء',
        'ur': 'قراءات اور قراء کا تعارف',
        'tr': 'Kıraatler ve Kâriler',
        'fr': 'Lectures canoniques et récitateurs',
        'id': 'Qiraat dan Para Imam',
        'de': 'Lesarten und ihre Imame',
        'es': 'Lecturas canónicas y recitadores',
      },
      summaries: {
        'en':
            'An introduction to canonical readings, transmissions, and paths.',
        'ar': 'مدخل إلى القراءات المتواترة والروايات والطرق.',
        'ur': 'معتبر قراءات، روایات اور طرق کا مختصر تعارف۔',
        'tr': 'Mütevatir kıraat, rivayet ve tariklere giriş.',
        'fr': 'Introduction aux lectures canoniques, transmissions et voies.',
        'id': 'Pengantar qiraat kanonik, riwayat, dan jalur periwayatan.',
        'de': 'Einführung in kanonische Lesarten, Überlieferungen und Wege.',
        'es': 'Introducción a las lecturas canónicas, transmisiones y vías.',
      },
      bodies: {
        'en':
            'Qira’at are authenticated ways of reciting the Quran transmitted through recognized chains. The ten canonical readings agree on the Quran while differing in limited pronunciation, vowels, assimilation, elongation, or wording transmitted from the Prophet.\n\nA qira’ah is associated with an imam, a riwayah with a principal transmitter, and a tariq with a later transmission path. These are not personal inventions or different Qurans.\n\nThis app follows the riwayah of Hafs from ‘Asim, the reading used by most printed Mushafs today. Other authentic readings should be learned through qualified teachers and their dedicated Mushafs.',
        'ar':
            'القراءات أوجه أداء ثابتة للقرآن نُقلت بأسانيد معتبرة. وتتفق القراءات العشر المتواترة في القرآن، مع اختلافات محدودة في النطق أو الحركات أو الإدغام أو المد أو ألفاظ منقولة عن النبي ﷺ.\n\nتُنسب القراءة إلى الإمام، والرواية إلى أحد رواته، والطريق إلى سلسلة نقل بعد الراوي. وليست هذه الأوجه اجتهادات شخصية ولا مصاحف مختلفة.\n\nيعتمد هذا التطبيق رواية حفص عن عاصم، وهي الشائعة في أكثر المصاحف المطبوعة اليوم. وتُتعلم القراءات الأخرى بالتلقي عن أهلها وبمصاحفها المخصصة.',
        'ur':
            'قراءات قرآن پڑھنے کے مستند طریقے ہیں جو معتبر سندوں سے منتقل ہوئے۔ دس متواتر قراءات قرآن پر متفق ہیں، البتہ نطق، حرکات، ادغام، مد یا نبی ﷺ سے منقول بعض الفاظ میں محدود فرق ہے۔\n\nقراءت امام کی طرف، روایت اس کے بڑے راوی کی طرف، اور طریق بعد کے سلسلۂ نقل کی طرف منسوب ہوتا ہے۔ یہ ذاتی ایجاد یا مختلف قرآن نہیں ہیں۔\n\nیہ ایپ حفص عن عاصم کی روایت استعمال کرتی ہے جو آج زیادہ تر مطبوعہ مصاحف میں ہے۔ دوسری معتبر قراءات اہل استاد اور مخصوص مصاحف کے ذریعے سیکھی جائیں۔',
        'tr':
            'Kıraatler, güvenilir isnatlarla aktarılan Kur’an okuma biçimleridir. On mütevatir kıraat Kur’an’da birleşir; telaffuz, hareke, idğam, med veya Peygamber’den aktarılan bazı lafızlarda sınırlı farklılıklar bulunur.\n\nKıraat imama, rivayet onun başlıca ravisine, tarik ise sonraki aktarım yoluna nispet edilir. Bunlar kişisel icat veya farklı Kur’anlar değildir.\n\nBu uygulama günümüzde çoğu basılı Mushafta kullanılan Âsım’dan Hafs rivayetini izler. Diğer sahih kıraatler ehil hocalardan ve özel Mushaflarından öğrenilmelidir.',
        'fr':
            'Les qira’at sont des modes authentifiés de récitation transmis par des chaînes reconnues. Les dix lectures canoniques portent sur le même Coran avec des différences limitées de prononciation, voyelles, assimilation, allongement ou formulation transmise du Prophète.\n\nUne qira’ah est attribuée à un imam, une riwayah à un transmetteur principal et une tariq à une voie de transmission ultérieure. Ce ne sont ni des inventions personnelles ni des Corans différents.\n\nCette application suit la riwayah de Hafs d’après ‘Asim, utilisée dans la plupart des Mushafs imprimés actuels. Les autres lectures authentiques s’apprennent auprès d’enseignants qualifiés et dans leurs Mushafs dédiés.',
        'id':
            'Qiraat adalah cara membaca Al-Quran yang sah dan diriwayatkan melalui sanad yang diakui. Sepuluh qiraat kanonik sepakat pada Al-Quran, dengan perbedaan terbatas pada pelafalan, harakat, idgham, mad, atau lafaz yang diriwayatkan dari Nabi.\n\nQiraah dinisbatkan kepada imam, riwayah kepada perawi utama, dan thariq kepada jalur periwayatan berikutnya. Semua ini bukan ciptaan pribadi atau Al-Quran yang berbeda.\n\nAplikasi ini mengikuti riwayat Hafs dari ‘Asim yang digunakan oleh kebanyakan Mushaf cetak saat ini. Qiraat sahih lainnya hendaknya dipelajari dari guru ahli dan Mushaf khususnya.',
        'de':
            'Qira’at sind authentische Rezitationsweisen, die über anerkannte Überlieferungsketten weitergegeben wurden. Die zehn kanonischen Lesarten stimmen im Koran überein und unterscheiden sich begrenzt in Aussprache, Vokalen, Assimilation, Dehnung oder überliefertem Wortlaut.\n\nEine Qira’ah wird einem Imam, eine Riwayah einem Hauptüberlieferer und ein Tariq einem späteren Überlieferungsweg zugeordnet. Es handelt sich nicht um persönliche Erfindungen oder verschiedene Korane.\n\nDiese App folgt der Riwayah von Hafs nach ‘Asim, die heute in den meisten gedruckten Mushafs verwendet wird. Andere authentische Lesarten sollten bei qualifizierten Lehrkräften und mit ihren eigenen Mushafs gelernt werden.',
        'es':
            'Las qira’at son formas autentificadas de recitar el Corán transmitidas por cadenas reconocidas. Las diez lecturas canónicas coinciden en el Corán y difieren de forma limitada en pronunciación, vocales, asimilación, prolongación o palabras transmitidas del Profeta.\n\nUna qira’ah se asocia a un imam, una riwayah a un transmisor principal y una tariq a una vía posterior. No son invenciones personales ni coranes diferentes.\n\nEsta aplicación sigue la riwayah de Hafs de ‘Asim, usada en la mayoría de los Mushafs impresos actuales. Las demás lecturas auténticas deben aprenderse con maestros cualificados y sus Mushafs específicos.',
      },
    ),
    TajweedArticle(
      id: 'hafs_distinctions',
      category: TajweedArticleCategory.miscellaneous,
      titles: {
        'en': 'Distinctive Cases in Hafs',
        'ar': 'انفرادات حفص',
        'ur': 'روایت حفص کی مخصوص صورتیں',
        'tr': 'Hafs Rivayetine Özgü Durumlar',
        'fr': 'Particularités de Hafs',
        'id': 'Kekhususan Riwayat Hafs',
        'de': 'Besonderheiten der Hafs-Überlieferung',
        'es': 'Casos distintivos de Hafs',
      },
      summaries: {
        'en':
            'Notable recitation cases in Hafs through the path of Ash-Shatibiyyah.',
        'ar': 'مواضع أداء مشهورة لحفص من طريق الشاطبية.',
        'ur': 'طریق شاطبیہ سے حفص کی مشہور ادائیگی کی صورتیں۔',
        'tr': 'Şâtıbiyye tarikinde Hafs’a özgü tanınmış okuyuşlar.',
        'fr': 'Cas notables de Hafs selon la voie d’Ash-Shatibiyyah.',
        'id':
            'Kasus bacaan terkenal dalam riwayat Hafs melalui jalur Asy-Syathibiyyah.',
        'de':
            'Bekannte Rezitationsfälle bei Hafs nach dem Weg der Schatibiyyah.',
        'es': 'Casos notables de Hafs por la vía de Ash-Shatibiyyah.',
      },
      bodies: {
        'en':
            'In the path of Ash-Shatibiyyah, Hafs has four famous brief pauses without taking breath: عِوَجَاۜ قَيِّمًا (18:1–2), مَرْقَدِنَاۜ هَٰذَا (36:52), مَنْۜ رَاقٍ (75:27), and بَلْۜ رَانَ (83:14).\n\nIn مَجْر۪ىٰهَا (11:41), the ra is read with imalah kubra, inclining the fathah toward kasrah and the alif toward ya. This pronunciation should be received directly from a qualified teacher.\n\nHafs also preserves particular choices in hamzah, madd, assimilation, and pauses. “Hafs” alone does not specify every advanced detail; the transmission path matters, so do not combine options from different paths without study.',
        'ar':
            'لحفص من طريق الشاطبية أربع سكتات مشهورة بلا تنفس: «عِوَجَاۜ قَيِّمًا» (الكهف ١–٢)، و«مَرْقَدِنَاۜ هَٰذَا» (يس ٥٢)، و«مَنْۜ رَاقٍ» (القيامة ٢٧)، و«بَلْۜ رَانَ» (المطففين ١٤).\n\nوفي «مَجْر۪ىٰهَا» (هود ٤١) تُقرأ الراء بالإمالة الكبرى؛ أي يُمال الفتح نحو الكسر والألف نحو الياء، ويُتلقى أداؤها مشافهة من معلّم متقن.\n\nولحفص اختيارات مخصوصة أخرى في الهمز والمد والإدغام والوقف. ولا يكفي اسم «حفص» وحده لتعيين كل تفصيل متقدم، بل يُراعى الطريق، فلا تُخلط أوجه الطرق المختلفة من غير علم.',
        'ur':
            'طریق شاطبیہ میں حفص کے چار مشہور سکتات بغیر سانس لیے ہیں: عِوَجَاۜ قَيِّمًا (18:1–2)، مَرْقَدِنَاۜ هَٰذَا (36:52)، مَنْۜ رَاقٍ (75:27)، اور بَلْۜ رَانَ (83:14)۔\n\nمَجْر۪ىٰهَا (11:41) میں راء کو امالۂ کبریٰ سے پڑھا جاتا ہے، یعنی فتحہ کو کسرہ اور الف کو یاء کی طرف مائل کیا جاتا ہے۔ یہ ادائیگی ماہر استاد سے بالمشافہ سیکھی جائے۔\n\nحفص کے ہمزہ، مد، ادغام اور وقف میں بھی مخصوص اختیارات ہیں۔ ہر باریک حکم کے لیے صرف نام حفص کافی نہیں؛ طریق بھی اہم ہے، اس لیے مختلف طرق کے اوجُہ بغیر علم نہ ملائیں۔',
        'tr':
            'Şâtıbiyye tarikinde Hafs’ın nefes almadan yaptığı dört meşhur sekte vardır: عِوَجَاۜ قَيِّمًا (18:1–2), مَرْقَدِنَاۜ هَٰذَا (36:52), مَنْۜ رَاقٍ (75:27) ve بَلْۜ رَانَ (83:14).\n\nمَجْر۪ىٰهَا (11:41) kelimesindeki ra, fethayı kesreye ve elifi yaya yaklaştıran imâle-i kübrâ ile okunur. Bu telaffuz ehil bir hocadan doğrudan alınmalıdır.\n\nHafs’ın hemze, med, idğam ve vakıfta başka özel tercihleri de vardır. İleri ayrıntılarda yalnız “Hafs” adı yeterli değildir; tarik önemlidir. Farklı tariklerin vecihleri ilimsizce karıştırılmamalıdır.',
        'fr':
            'Dans la voie d’Ash-Shatibiyyah, Hafs observe quatre pauses brèves célèbres sans reprendre souffle : عِوَجَاۜ قَيِّمًا (18:1–2), مَرْقَدِنَاۜ هَٰذَا (36:52), مَنْۜ رَاقٍ (75:27) et بَلْۜ رَانَ (83:14).\n\nDans مَجْر۪ىٰهَا (11:41), le ra se lit avec imalah kubra, inclinant la fatha vers la kasra et l’alif vers le ya. Cette prononciation doit être apprise directement d’un enseignant qualifié.\n\nHafs conserve aussi des choix propres pour la hamza, le madd, l’assimilation et les pauses. Le nom « Hafs » ne précise pas seul chaque détail avancé : la voie de transmission compte et les options de voies différentes ne doivent pas être mélangées sans étude.',
        'id':
            'Dalam jalur Asy-Syathibiyyah, Hafs memiliki empat saktah singkat tanpa mengambil napas: عِوَجَاۜ قَيِّمًا (18:1–2), مَرْقَدِنَاۜ هَٰذَا (36:52), مَنْۜ رَاقٍ (75:27), dan بَلْۜ رَانَ (83:14).\n\nPada مَجْر۪ىٰهَا (11:41), ra dibaca dengan imalah kubra, memiringkan fathah ke arah kasrah dan alif ke arah ya. Pelafalan ini harus diterima langsung dari guru yang ahli.\n\nHafs juga memiliki pilihan khusus dalam hamzah, mad, idgham, dan waqaf. Nama “Hafs” saja tidak menentukan semua rincian lanjutan; jalur periwayatan juga penting, maka jangan mencampur pilihan dari jalur berbeda tanpa ilmu.',
        'de':
            'Auf dem Weg der Schatibiyyah hat Hafs vier bekannte kurze Pausen ohne Atemholen: عِوَجَاۜ قَيِّمًا (18:1–2), مَرْقَدِنَاۜ هَٰذَا (36:52), مَنْۜ رَاقٍ (75:27) und بَلْۜ رَانَ (83:14).\n\nIn مَجْر۪ىٰهَا (11:41) wird das Ra mit Imalah Kubra gelesen: Fatha wird zu Kasra und Alif zu Ya geneigt. Diese Aussprache sollte direkt bei einer qualifizierten Lehrkraft gelernt werden.\n\nHafs hat weitere besondere Entscheidungen bei Hamza, Madd, Assimilation und Pausen. Der Name „Hafs“ allein bestimmt nicht jedes fortgeschrittene Detail; der Überlieferungsweg zählt. Varianten verschiedener Wege dürfen nicht ohne Studium vermischt werden.',
        'es':
            'En la vía de Ash-Shatibiyyah, Hafs tiene cuatro pausas breves famosas sin tomar aire: عِوَجَاۜ قَيِّمًا (18:1–2), مَرْقَدِنَاۜ هَٰذَا (36:52), مَنْۜ رَاقٍ (75:27) y بَلْۜ رَانَ (83:14).\n\nEn مَجْر۪ىٰهَا (11:41), la ra se lee con imalah kubra, inclinando la fatha hacia kasra y el alif hacia ya. Esta pronunciación debe aprenderse directamente de un maestro cualificado.\n\nHafs también conserva opciones particulares de hamza, madd, asimilación y pausas. El nombre “Hafs” no especifica por sí solo cada detalle avanzado; la vía de transmisión importa y no deben mezclarse opciones de vías distintas sin estudio.',
      },
    ),
  ];

  static List<TajweedArticle> search(String query, String languageCode) =>
      all.where((article) => article.matches(query, languageCode)).toList();
}
