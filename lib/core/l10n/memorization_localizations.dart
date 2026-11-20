const hifzTranslations = <String, Map<String, String>>{
  'en': {
    'quran_asr_repeat_unverified': 'Not verified. Recite this ayah again.',
    'quran_asr_share_diagnostics': 'Share recordings & diagnostics',
    'quran_asr_share_empty': 'No diagnostic recordings saved yet.',
    'quran_asr_retained_preview':
        'Retained words — unverified, no match credit',
    'quran_asr_assisted': 'Assisted',
    'quran_asr_next_word': 'Continue from word',
    'quran_asr_word_preview': 'Live word preview (unverified)',
    'quran_asr_audio_debug_warning':
        'AI Lab only · Audio debugging is enabled in this build. Up to six audio snapshots from this recording (up to 30 seconds each) and their recognized text are saved locally and may be uploaded with diagnostic reports. Recite and tap Pause when finished; there is no session time limit. Live words are unverified, incorrect words block progress, and the model may miss or invent words. This is not a memorization or Tajweed assessment.',
    'quran_asr_transcript_debug_warning':
        'AI Lab only · Transcript debugging is enabled in this build. Text recognized in each preview is saved with timing and progress diagnostics and uploaded with the report; reports are retained for up to 30 days. No audio is saved. Recite and tap Pause when finished; live words are unverified, incorrect words block progress, and the model may miss or invent words. This is not a memorization or Tajweed assessment.',
    'quran_asr_live_warning':
        'AI Lab only · Live word preview starts on. Keep reciting and tap Pause when finished; there is no session time limit. Audio is checked in rolling windows of up to 30 seconds. Earlier matching words are retained as unverified, without match credit; unmatched words still block progress. Turn preview off to hide new words until Pause. The transcript stays hidden. The model can miss or invent words; a text match is not proof of correct memorization or Tajweed. Audio stays on this device and temporary snapshots are deleted.',
    'quran_asr_title': 'DEBUG: On-device Quran AI',
    'quran_asr_warning':
        'Experimental · Record up to 30 seconds, then stop to check. Audio stays on this device; the temporary recording is deleted. No Hifz progress or Tajweed grading. The transcript is unverified: words may be misheard, completed, or generated from noise.',
    'quran_asr_check': 'Stop and check',
    'quran_asr_cancel': 'Cancel',
    'quran_asr_result': 'Unverified transcript',
    'quran_asr_time': 'Inference time (seconds)',
    'quran_asr_unavailable':
        'This debug build does not include the experimental model.',
    'quran_asr_failed': 'Recognition failed. Please try again.',
    'hifz_live_preview': 'Live ayah preview (unconfirmed)',
    'hifz_provisional': 'Preview only — awaiting final recognition',
    'tab_hifz': 'Hifz',
    'hifz_select': 'Choose or search a surah',
    'hifz_review': 'Review',
    'hifz_recite': 'Recite from memory',
    'hifz_review_intro': 'Read and listen on the complete Mushaf page.',
    'hifz_step': 'Ayah-by-ayah practice',
    'hifz_intro':
        'Keep reciting. Confirmed ayahs appear in place. This experimental aid checks recognized words, not pronunciation or Tajweed.',
    'hifz_start': 'Recite',
    'hifz_ready': 'Start reciting from memory and continue in Quran order.',
    'hifz_resume': 'Resume',
    'hifz_pause': 'Pause',
    'hifz_finalizing': 'Finishing recognition…',
    'hifz_hint': 'Hint',
    'hifz_reveal': 'Reveal',
    'hifz_hint_used': 'Hint words shown. This ayah is hint-assisted.',
    'hifz_resume_message': 'Recognition paused. Resume to continue from here.',
    'hifz_unaided': 'Unaided matches',
    'hifz_assisted': 'Hint-assisted',
    'hifz_mistakes': 'Mistakes',
    'hifz_mistakes_empty': 'No mistakes recorded in this session yet.',
  },
  'ar': {
    'quran_asr_repeat_unverified': 'لم يتم التحقق. أعد تلاوة هذه الآية.',
    'quran_asr_share_diagnostics': 'مشاركة التسجيلات والتشخيص',
    'quran_asr_share_empty': 'لا توجد تسجيلات تشخيصية محفوظة بعد.',
    'quran_asr_retained_preview':
        'الكلمات المحفوظة — غير مؤكدة ولا تُحسب كتطابق',
    'quran_asr_assisted': 'بمساعدة',
    'quran_asr_next_word': 'تابع من الكلمة',
    'quran_asr_word_preview': 'معاينة الكلمات أثناء التلاوة (غير مؤكدة)',
    'quran_asr_audio_debug_warning':
        'مختبر الذكاء الاصطناعي فقط · تسجيل الصوت للتشخيص مفعّل في هذه النسخة. تُحفظ محليًا حتى ست لقطات صوتية من هذا التسجيل (حتى ٣٠ ثانية لكل لقطة) مع النص المتعرّف عليه، وقد تُرفع مع تقارير التشخيص. واصل التلاوة واضغط الإيقاف المؤقت عند الانتهاء؛ لا يوجد حد زمني للجلسة. الكلمات المعروضة غير مؤكدة، والكلمات الخاطئة تمنع التقدم، وقد يفوّت النموذج كلمات أو يولّدها. هذا ليس تقييمًا للحفظ أو التجويد.',
    'quran_asr_transcript_debug_warning':
        'مختبر الذكاء الاصطناعي فقط · يُحفظ النص الذي يتعرّف عليه كل فحص مع بيانات الوقت والتقدم، ويُرفع مع التقرير الذي يُحتفظ به حتى ٣٠ يومًا. لا يُحفظ الصوت. واصل التلاوة واضغط الإيقاف المؤقت عند الانتهاء. الكلمات المعروضة غير مؤكدة وقد يفوّت النموذج كلمات أو يولّدها. هذا ليس تقييمًا للحفظ أو التجويد.',
    'quran_asr_live_warning':
        'مختبر الذكاء الاصطناعي فقط · معاينة الكلمات مفعّلة عند البدء. واصل التلاوة واضغط الإيقاف المؤقت عند الانتهاء؛ لا يوجد حد زمني للجلسة. يُفحص الصوت في نوافذ متحركة لا تتجاوز ٣٠ ثانية. تُحفظ الكلمات المطابقة السابقة كمعاينة غير مؤكدة ولا تُحسب كتطابق؛ وتبقى الكلمة غير المطابقة عائقًا للتقدم. عطّل المعاينة لإخفاء الكلمات الجديدة حتى الإيقاف المؤقت. يبقى النص المتعرّف عليه مخفيًا. قد يفوّت النموذج كلمات أو يولّدها؛ تطابق النص ليس إثباتًا لصحة الحفظ أو التجويد. يبقى الصوت على الجهاز وتُحذف اللقطات المؤقتة.',
    'quran_asr_title': 'DEBUG: التعرف القرآني على الجهاز',
    'quran_asr_warning':
        'تجريبي · سجل حتى ٣٠ ثانية، ثم أوقف التسجيل للتحقق. يبقى الصوت على جهازك ويُحذف التسجيل المؤقت. لا يؤثر على تقدم الحفظ ولا يقيّم التجويد. النص غير مؤكد: قد تُفهم الكلمات خطأ أو تُستكمل أو تُولد من الضوضاء.',
    'quran_asr_check': 'إيقاف والتحقق',
    'quran_asr_cancel': 'إلغاء',
    'quran_asr_result': 'نص غير مؤكد',
    'quran_asr_time': 'وقت التعرف (ثوانٍ)',
    'quran_asr_unavailable': 'نسخة الاختبار هذه لا تتضمن النموذج التجريبي.',
    'quran_asr_failed': 'فشل التعرف. حاول مرة أخرى.',
    'hifz_live_preview': 'معاينة الآيات أثناء التلاوة (غير مؤكدة)',
    'hifz_provisional': 'معاينة فقط — بانتظار نتيجة التعرف النهائية',
    'tab_hifz': 'الحفظ',
    'hifz_select': 'اختر سورة أو ابحث عنها',
    'hifz_review': 'مراجعة',
    'hifz_recite': 'تلاوة من الحفظ',
    'hifz_review_intro': 'اقرأ واستمع في صفحة المصحف كاملة.',
    'hifz_step': 'تدريب آية بآية',
    'hifz_intro':
        'واصل التلاوة. تظهر الآيات المؤكدة في مواضعها. هذه أداة تجريبية لمقارنة الكلمات المتعرّف عليها، وليست لتقييم النطق أو التجويد.',
    'hifz_start': 'رتّل',
    'hifz_ready': 'ابدأ التلاوة من حفظك وتابع بترتيب الآيات.',
    'hifz_resume': 'متابعة',
    'hifz_pause': 'إيقاف',
    'hifz_finalizing': 'جارٍ إنهاء التعرّف…',
    'hifz_hint': 'تلميح',
    'hifz_reveal': 'إظهار',
    'hifz_hint_used': 'ظهرت كلمات التلميح. هذه الآية بمساعدة تلميح.',
    'hifz_resume_message': 'توقف التعرف مؤقتًا. تابع من هنا.',
    'hifz_unaided': 'تطابق دون مساعدة',
    'hifz_assisted': 'بمساعدة تلميح',
    'hifz_mistakes': 'الأخطاء',
    'hifz_mistakes_empty': 'لا توجد أخطاء مسجلة في هذه الجلسة بعد.',
  },
  'ur': {
    'quran_asr_repeat_unverified': 'تصدیق نہیں ہوئی۔ یہ آیت دوبارہ پڑھیں۔',
    'quran_asr_share_diagnostics': 'ریکارڈنگز اور تشخیص شیئر کریں',
    'quran_asr_share_empty': 'ابھی تک کوئی تشخیصی ریکارڈنگ محفوظ نہیں۔',
    'quran_asr_retained_preview':
        'محفوظ الفاظ — غیر تصدیق شدہ، مطابقت میں شمار نہیں',
    'quran_asr_assisted': 'مدد کے ساتھ',
    'quran_asr_next_word': 'اس لفظ سے جاری رکھیں',
    'quran_asr_word_preview': 'الفاظ کا براہ راست پیش منظر (غیر تصدیق شدہ)',
    'quran_asr_audio_debug_warning':
        'صرف AI لیب · اس نسخے میں صوتی تشخیص فعال ہے۔ اس ریکارڈنگ کے زیادہ سے زیادہ چھ صوتی نمونے (ہر ایک ۳۰ سیکنڈ تک) اور شناخت شدہ متن اسی آلے پر محفوظ ہوتے ہیں اور تشخیصی رپورٹوں کے ساتھ اپ لوڈ ہو سکتے ہیں۔ تلاوت کریں اور آخر میں وقفہ دبائیں؛ نشست کی کوئی زمانی حد نہیں۔ دکھائے گئے الفاظ غیر تصدیق شدہ ہیں، غلط لفظ پیش رفت روکتا ہے اور ماڈل الفاظ چھوڑ یا بنا سکتا ہے۔ یہ حفظ یا تجوید کی جانچ نہیں۔',
    'quran_asr_transcript_debug_warning':
        'صرف AI لیب · ہر پیش منظر میں شناخت شدہ متن وقت اور پیش رفت کی معلومات کے ساتھ محفوظ اور تشخیصی رپورٹ میں اپ لوڈ ہوگا؛ رپورٹ ۳۰ دن تک رکھی جائے گی۔ آڈیو محفوظ نہیں ہوگی۔ تلاوت مکمل ہونے پر وقفہ دبائیں۔ الفاظ غیر تصدیق شدہ ہیں، اور ماڈل الفاظ چھوڑ یا بنا سکتا ہے۔ یہ حفظ یا تجوید کی جانچ نہیں۔',
    'quran_asr_live_warning':
        'صرف AI لیب · الفاظ کا براہ راست پیش منظر شروع سے فعال ہے۔ تلاوت جاری رکھیں اور ختم ہونے پر وقفہ دبائیں؛ نشست کی کوئی زمانی حد نہیں۔ آواز زیادہ سے زیادہ ۳۰ سیکنڈ کی متحرک کھڑکیوں میں جانچی جاتی ہے۔ پہلے ملنے والے الفاظ غیر تصدیق شدہ رہتے ہیں اور مطابقت میں شمار نہیں ہوتے؛ غیر مطابق لفظ آگے بڑھنے سے روکتا ہے۔ وقفے تک نئے الفاظ چھپانے کے لیے پیش منظر بند کریں۔ شناخت شدہ متن چھپا رہتا ہے۔ ماڈل الفاظ چھوڑ یا بنا سکتا ہے؛ متن کی مطابقت درست حفظ یا تجوید کا ثبوت نہیں۔ آواز آلے پر رہتی ہے اور عارضی نمونے حذف ہوتے ہیں۔',
    'quran_asr_title': 'DEBUG: آلے پر قرآنی AI',
    'quran_asr_warning':
        'تجرباتی · ۳۰ سیکنڈ تک ریکارڈ کریں، پھر جانچ کے لیے روکیں۔ آواز اسی آلے پر رہتی ہے اور عارضی ریکارڈنگ حذف ہوتی ہے۔ حفظ کی پیش رفت یا تجوید کی جانچ نہیں ہوتی۔ متن غیر تصدیق شدہ ہے: الفاظ غلط پہچانے، مکمل کیے یا شور سے بنائے جا سکتے ہیں۔',
    'quran_asr_check': 'روکیں اور جانچیں',
    'quran_asr_cancel': 'منسوخ',
    'quran_asr_result': 'غیر تصدیق شدہ متن',
    'quran_asr_time': 'شناخت کا وقت (سیکنڈ)',
    'quran_asr_unavailable': 'اس آزمائشی نسخے میں تجرباتی ماڈل شامل نہیں ہے۔',
    'quran_asr_failed': 'شناخت ناکام ہوئی۔ دوبارہ کوشش کریں۔',
    'hifz_live_preview': 'آیات کا براہ راست پیش منظر (غیر تصدیق شدہ)',
    'hifz_provisional': 'صرف پیش منظر — حتمی شناخت کا انتظار',
    'tab_hifz': 'حفظ',
    'hifz_select': 'سورت منتخب یا تلاش کریں',
    'hifz_review': 'دہرائیں',
    'hifz_recite': 'یاد سے سنائیں',
    'hifz_review_intro': 'مصحف کے پورے صفحے پر پڑھیں اور سنیں۔',
    'hifz_step': 'آیت بہ آیت مشق',
    'hifz_intro':
        'تلاوت جاری رکھیں۔ تصدیق شدہ آیات اپنی جگہ ظاہر ہوں گی۔ یہ تجرباتی مدد پہچانے گئے الفاظ جانچتی ہے، تلفظ یا تجوید نہیں۔',
    'hifz_start': 'تلاوت',
    'hifz_ready': 'یاد سے تلاوت شروع کریں اور آیات کی ترتیب میں جاری رکھیں۔',
    'hifz_resume': 'جاری رکھیں',
    'hifz_pause': 'وقفہ',
    'hifz_finalizing': 'شناخت مکمل ہو رہی ہے…',
    'hifz_hint': 'اشارہ',
    'hifz_reveal': 'دکھائیں',
    'hifz_hint_used': 'اشارے کے الفاظ دکھائے گئے۔ یہ آیت اشارے کی مدد سے ہے۔',
    'hifz_resume_message': 'آواز کی پہچان رک گئی۔ یہاں سے جاری رکھیں۔',
    'hifz_unaided': 'بغیر مدد مطابقت',
    'hifz_assisted': 'اشارے کی مدد سے',
    'hifz_mistakes': 'غلطیاں',
    'hifz_mistakes_empty': 'اس نشست میں ابھی کوئی غلطی ریکارڈ نہیں ہوئی۔',
  },
  'tr': {
    'quran_asr_repeat_unverified': 'Doğrulanmadı. Bu ayeti tekrar okuyun.',
    'quran_asr_share_diagnostics': 'Kayıtları ve tanılamayı paylaş',
    'quran_asr_share_empty': 'Henüz kaydedilmiş tanılama kaydı yok.',
    'quran_asr_retained_preview':
        'Korunan kelimeler — doğrulanmamış, eşleşme sayılmaz',
    'quran_asr_assisted': 'Yardımlı',
    'quran_asr_next_word': 'Şu kelimeden devam edin',
    'quran_asr_word_preview': 'Canlı kelime önizlemesi (doğrulanmamış)',
    'quran_asr_audio_debug_warning':
        'Yalnızca AI Lab · Bu sürümde sesli hata ayıklama açıktır. Bu kayıttan en fazla altı ses kesiti (her biri en fazla 30 saniye) ve tanınan metin cihazda saklanır ve tanılama raporlarıyla yüklenebilir. Okuyun ve bitirince duraklatın; oturum süresi sınırsızdır. Canlı kelimeler doğrulanmamıştır, yanlış kelimeler ilerlemeyi durdurur ve model kelime atlayabilir veya uydurabilir. Bu bir ezber veya tecvid değerlendirmesi değildir.',
    'quran_asr_transcript_debug_warning':
        'Yalnızca AI Lab · Her önizlemede tanınan metin, zamanlama ve ilerleme bilgileriyle kaydedilir ve tanılama raporuyla yüklenir; raporlar en fazla 30 gün saklanır. Ses kaydedilmez. Okuyun ve bitirince duraklatın. Kelimeler doğrulanmamıştır; model kelime atlayabilir veya uydurabilir. Bu bir ezber veya tecvid değerlendirmesi değildir.',
    'quran_asr_live_warning':
        'Yalnızca AI Lab · Canlı kelime önizlemesi başlangıçta açıktır. Okumaya devam edin ve bitirince duraklatın; oturum süresi sınırsızdır. Ses, en fazla 30 saniyelik kayan pencerelerde kontrol edilir. Önceki eşleşen kelimeler doğrulanmamış olarak korunur ve eşleşme sayılmaz; eşleşmeyen kelimeler ilerlemeyi durdurur. Yeni kelimeleri duraklatana kadar gizlemek için önizlemeyi kapatın. Döküm gizlidir. Model kelime atlayabilir veya uydurabilir; metin eşleşmesi doğru ezber ya da tecvid kanıtı değildir. Ses cihazda kalır ve geçici örnekler silinir.',
    'quran_asr_title': 'DEBUG: Cihazda Kur’an AI',
    'quran_asr_warning':
        'Deneysel · En fazla 30 saniye kaydedip kontrol için durdurun. Ses cihazda kalır; geçici kayıt silinir. Hıfz ilerlemesi veya tecvid değerlendirmesi yapılmaz. Metin doğrulanmamıştır: kelimeler yanlış tanınabilir, tamamlanabilir veya gürültüden üretilebilir.',
    'quran_asr_check': 'Durdur ve kontrol et',
    'quran_asr_cancel': 'İptal',
    'quran_asr_result': 'Doğrulanmamış metin',
    'quran_asr_time': 'Tanıma süresi (saniye)',
    'quran_asr_unavailable':
        'Bu hata ayıklama derlemesi deneysel modeli içermiyor.',
    'quran_asr_failed': 'Tanıma başarısız. Lütfen tekrar deneyin.',
    'hifz_live_preview': 'Canlı ayet önizlemesi (doğrulanmamış)',
    'hifz_provisional': 'Yalnızca önizleme — son tanıma sonucu bekleniyor',
    'tab_hifz': 'Hıfz',
    'hifz_select': 'Sure seç veya ara',
    'hifz_review': 'Tekrar et',
    'hifz_recite': 'Ezberden oku',
    'hifz_review_intro': 'Tam Mushaf sayfasında oku ve dinle.',
    'hifz_step': 'Ayet ayet çalışma',
    'hifz_intro':
        'Okumaya devam et. Doğrulanan ayetler yerlerinde görünür. Bu deneysel yardımcı tanınan kelimeleri kontrol eder; telaffuz veya tecvidi değerlendirmez.',
    'hifz_start': 'Oku',
    'hifz_ready': 'Ezberden okumaya başla ve ayet sırasıyla devam et.',
    'hifz_resume': 'Devam',
    'hifz_pause': 'Duraklat',
    'hifz_finalizing': 'Tanıma tamamlanıyor…',
    'hifz_hint': 'İpucu',
    'hifz_reveal': 'Göster',
    'hifz_hint_used':
        'İpucu kelimeleri gösterildi. Bu ayette ipucu kullanıldı.',
    'hifz_resume_message': 'Tanıma durakladı. Buradan devam et.',
    'hifz_unaided': 'İpucusuz eşleşmeler',
    'hifz_assisted': 'İpucuyla',
    'hifz_mistakes': 'Hatalar',
    'hifz_mistakes_empty': 'Bu oturumda henüz kaydedilmiş hata yok.',
  },
  'fr': {
    'quran_asr_repeat_unverified': 'Non vérifié. Récitez à nouveau ce verset.',
    'quran_asr_share_diagnostics':
        'Partager les enregistrements et diagnostics',
    'quran_asr_share_empty': 'Aucun enregistrement de diagnostic sauvegardé.',
    'quran_asr_retained_preview':
        'Mots conservés — non vérifiés, sans crédit de correspondance',
    'quran_asr_assisted': 'Avec aide',
    'quran_asr_next_word': 'Reprendre au mot',
    'quran_asr_word_preview': 'Aperçu des mots en direct (non vérifié)',
    'quran_asr_audio_debug_warning':
        'AI Lab uniquement · Le diagnostic audio est activé dans cette version. Jusqu’à six extraits de cet enregistrement (30 secondes maximum chacun) et leur transcription sont conservés localement et peuvent être envoyés avec les rapports de diagnostic. Récitez puis faites une pause ; la session n’a pas de limite de durée. Les mots affichés ne sont pas vérifiés, les mots incorrects bloquent la progression et le modèle peut omettre ou inventer des mots. Ce n’est pas une évaluation de la mémorisation ou du tajwid.',
    'quran_asr_transcript_debug_warning':
        'AI Lab uniquement · Le texte reconnu à chaque aperçu est enregistré avec les données de temps et de progression, puis envoyé avec le rapport, conservé jusqu’à 30 jours. Aucun audio n’est enregistré. Récitez puis faites une pause. Les mots ne sont pas vérifiés ; le modèle peut en omettre ou en inventer. Ce n’est pas une évaluation de la mémorisation ou du tajwid.',
    'quran_asr_live_warning':
        'AI Lab uniquement · L’aperçu des mots en direct est activé au départ. Continuez à réciter et faites une pause à la fin ; la session n’a pas de limite de durée. Le son est vérifié par fenêtres glissantes de 30 secondes maximum. Les mots précédents sont conservés sans vérification ni crédit de correspondance ; les mots incorrects bloquent toujours la progression. Désactivez l’aperçu pour masquer les nouveaux mots jusqu’à la pause. La transcription reste masquée. Le modèle peut omettre ou inventer des mots ; une correspondance ne prouve ni la mémorisation ni le tajwid. Le son reste sur cet appareil et les extraits temporaires sont supprimés.',
    'quran_asr_title': 'DEBUG : IA coranique sur l’appareil',
    'quran_asr_warning':
        'Expérimental · Enregistrez jusqu’à 30 secondes, puis arrêtez pour vérifier. L’audio reste sur l’appareil ; l’enregistrement temporaire est supprimé. Aucun progrès Hifz ni évaluation du tajwid. Le texte n’est pas vérifié : des mots peuvent être mal reconnus, complétés ou générés à partir du bruit.',
    'quran_asr_check': 'Arrêter et vérifier',
    'quran_asr_cancel': 'Annuler',
    'quran_asr_result': 'Texte non vérifié',
    'quran_asr_time': 'Temps de reconnaissance (secondes)',
    'quran_asr_unavailable':
        'Cette version de débogage ne contient pas le modèle expérimental.',
    'quran_asr_failed': 'La reconnaissance a échoué. Réessayez.',
    'hifz_live_preview': 'Aperçu des versets en direct (non confirmé)',
    'hifz_provisional': 'Aperçu uniquement — résultat final attendu',
    'tab_hifz': 'Hifz',
    'hifz_select': 'Choisir ou rechercher une sourate',
    'hifz_review': 'Réviser',
    'hifz_recite': 'Réciter de mémoire',
    'hifz_review_intro': 'Lisez et écoutez sur la page complète du Mushaf.',
    'hifz_step': 'Entraînement verset par verset',
    'hifz_intro':
        'Continuez à réciter. Les versets confirmés apparaissent à leur place. Cette aide expérimentale vérifie les mots reconnus, pas la prononciation ni le tajwid.',
    'hifz_start': 'Réciter',
    'hifz_ready': 'Commencez de mémoire et suivez l’ordre des versets.',
    'hifz_resume': 'Reprendre',
    'hifz_pause': 'Pause',
    'hifz_finalizing': 'Finalisation de la reconnaissance…',
    'hifz_hint': 'Indice',
    'hifz_reveal': 'Révéler',
    'hifz_hint_used':
        'Mots indices affichés. Un indice a été utilisé pour ce verset.',
    'hifz_resume_message': 'Reconnaissance en pause. Reprenez ici.',
    'hifz_unaided': 'Correspondances sans aide',
    'hifz_assisted': 'Avec indice',
    'hifz_mistakes': 'Erreurs',
    'hifz_mistakes_empty': 'Aucune erreur enregistrée dans cette session.',
  },
  'id': {
    'quran_asr_repeat_unverified':
        'Belum terverifikasi. Bacakan ayat ini lagi.',
    'quran_asr_share_diagnostics': 'Bagikan rekaman & diagnostik',
    'quran_asr_share_empty': 'Belum ada rekaman diagnostik yang disimpan.',
    'quran_asr_retained_preview':
        'Kata dipertahankan — belum terverifikasi, tidak dihitung cocok',
    'quran_asr_assisted': 'Dengan bantuan',
    'quran_asr_next_word': 'Lanjutkan dari kata',
    'quran_asr_word_preview': 'Pratinjau kata langsung (belum terverifikasi)',
    'quran_asr_audio_debug_warning':
        'Khusus AI Lab · Diagnostik audio aktif dalam versi ini. Hingga enam cuplikan dari rekaman ini (masing-masing hingga 30 detik) beserta transkripnya disimpan secara lokal dan dapat diunggah bersama laporan diagnostik. Bacalah dan tekan Jeda saat selesai; sesi tidak dibatasi waktu. Kata yang ditampilkan belum terverifikasi, kata salah menghalangi kemajuan, dan model dapat melewatkan atau mengarang kata. Ini bukan penilaian hafalan atau tajwid.',
    'quran_asr_transcript_debug_warning':
        'Khusus AI Lab · Teks yang dikenali pada setiap pratinjau disimpan bersama data waktu dan progres, lalu diunggah bersama laporan yang disimpan hingga 30 hari. Audio tidak disimpan. Bacalah dan tekan Jeda saat selesai. Kata belum terverifikasi; model dapat melewatkan atau mengarang kata. Ini bukan penilaian hafalan atau tajwid.',
    'quran_asr_live_warning':
        'Khusus AI Lab · Pratinjau kata langsung aktif sejak awal. Teruskan membaca dan tekan Jeda saat selesai; tidak ada batas waktu sesi. Audio diperiksa dalam jendela bergulir hingga 30 detik. Kata sebelumnya dipertahankan sebagai belum terverifikasi dan tidak dihitung cocok; kata yang salah tetap menghalangi kemajuan. Matikan pratinjau untuk menyembunyikan kata baru hingga Jeda. Transkrip tetap tersembunyi. Model dapat melewatkan atau mengarang kata; kecocokan teks bukan bukti hafalan atau tajwid yang benar. Audio tetap di perangkat ini dan cuplikan sementara dihapus.',
    'quran_asr_title': 'DEBUG: AI Al-Qur’an di perangkat',
    'quran_asr_warning':
        'Eksperimental · Rekam hingga 30 detik, lalu hentikan untuk memeriksa. Audio tetap di perangkat; rekaman sementara dihapus. Tidak mengubah progres Hifz atau menilai tajwid. Teks belum terverifikasi: kata dapat salah dikenali, dilengkapi, atau dihasilkan dari derau.',
    'quran_asr_check': 'Hentikan dan periksa',
    'quran_asr_cancel': 'Batal',
    'quran_asr_result': 'Teks belum terverifikasi',
    'quran_asr_time': 'Waktu pengenalan (detik)',
    'quran_asr_unavailable':
        'Build debug ini tidak menyertakan model eksperimental.',
    'quran_asr_failed': 'Pengenalan gagal. Silakan coba lagi.',
    'hifz_live_preview': 'Pratinjau ayat langsung (belum dikonfirmasi)',
    'hifz_provisional': 'Hanya pratinjau — menunggu hasil pengenalan akhir',
    'tab_hifz': 'Hafalan',
    'hifz_select': 'Pilih atau cari surah',
    'hifz_review': 'Murajaah',
    'hifz_recite': 'Baca dari hafalan',
    'hifz_review_intro': 'Baca dan dengarkan pada halaman Mushaf lengkap.',
    'hifz_step': 'Latihan ayat demi ayat',
    'hifz_intro':
        'Teruskan membaca. Ayat yang terkonfirmasi muncul di tempatnya. Bantuan eksperimental ini memeriksa kata yang dikenali, bukan pelafalan atau tajwid.',
    'hifz_start': 'Baca',
    'hifz_ready': 'Mulai dari hafalan dan teruskan sesuai urutan ayat.',
    'hifz_resume': 'Lanjut',
    'hifz_pause': 'Jeda',
    'hifz_finalizing': 'Menyelesaikan pengenalan…',
    'hifz_hint': 'Petunjuk',
    'hifz_reveal': 'Tampilkan',
    'hifz_hint_used': 'Kata petunjuk ditampilkan. Ayat ini dibantu petunjuk.',
    'hifz_resume_message': 'Pengenalan dijeda. Lanjutkan dari sini.',
    'hifz_unaided': 'Kecocokan tanpa bantuan',
    'hifz_assisted': 'Dengan petunjuk',
    'hifz_mistakes': 'Kesalahan',
    'hifz_mistakes_empty': 'Belum ada kesalahan tercatat di sesi ini.',
  },
  'de': {
    'quran_asr_repeat_unverified':
        'Nicht bestätigt. Rezitiere diesen Vers erneut.',
    'quran_asr_share_diagnostics': 'Aufnahmen & Diagnose teilen',
    'quran_asr_share_empty': 'Noch keine Diagnoseaufnahmen gespeichert.',
    'quran_asr_retained_preview':
        'Beibehaltene Wörter — ungeprüft, nicht als Treffer gezählt',
    'quran_asr_assisted': 'Mit Hilfe',
    'quran_asr_next_word': 'Weiter ab Wort',
    'quran_asr_word_preview': 'Live-Wortvorschau (ungeprüft)',
    'quran_asr_audio_debug_warning':
        'Nur AI Lab · Audio-Diagnose ist in dieser Version aktiv. Bis zu sechs Ausschnitte dieser Aufnahme (je höchstens 30 Sekunden) und die erkannten Texte werden lokal gespeichert und können mit Diagnoseberichten hochgeladen werden. Rezitieren und am Ende pausieren; die Sitzung hat kein Zeitlimit. Angezeigte Wörter sind ungeprüft, falsche Wörter blockieren den Fortschritt und das Modell kann Wörter auslassen oder erfinden. Dies ist keine Bewertung des Auswendiglernens oder Tadschwids.',
    'quran_asr_transcript_debug_warning':
        'Nur AI Lab · Der erkannte Text jedes Vorschaufensters wird mit Zeit- und Fortschrittsdaten gespeichert und mit dem Diagnosebericht hochgeladen; Berichte bleiben bis zu 30 Tage erhalten. Audio wird nicht gespeichert. Rezitieren und am Ende pausieren. Wörter sind ungeprüft; das Modell kann Wörter auslassen oder erfinden. Dies ist keine Bewertung des Auswendiglernens oder Tadschwids.',
    'quran_asr_live_warning':
        'Nur AI Lab · Die Live-Wortvorschau ist anfangs eingeschaltet. Weiter rezitieren und am Ende pausieren; es gibt kein Zeitlimit für die Sitzung. Audio wird in gleitenden Fenstern von höchstens 30 Sekunden geprüft. Frühere Wörter bleiben ungeprüft erhalten und zählen nicht als Treffer; falsche Wörter blockieren weiterhin den Fortschritt. Vorschau ausschalten, um neue Wörter bis zur Pause zu verbergen. Das Transkript bleibt verborgen. Das Modell kann Wörter auslassen oder erfinden; Textübereinstimmung beweist weder korrektes Auswendiglernen noch Tadschwid. Audio bleibt auf diesem Gerät und temporäre Ausschnitte werden gelöscht.',
    'quran_asr_title': 'DEBUG: Koran-KI auf dem Gerät',
    'quran_asr_warning':
        'Experimentell · Bis zu 30 Sekunden aufnehmen, dann zur Prüfung stoppen. Audio bleibt auf dem Gerät; die temporäre Aufnahme wird gelöscht. Kein Hifz-Fortschritt und keine Tadschwid-Bewertung. Der Text ist unbestätigt: Wörter können falsch erkannt, ergänzt oder aus Geräuschen erzeugt werden.',
    'quran_asr_check': 'Stoppen und prüfen',
    'quran_asr_cancel': 'Abbrechen',
    'quran_asr_result': 'Unbestätigter Text',
    'quran_asr_time': 'Erkennungszeit (Sekunden)',
    'quran_asr_unavailable':
        'Dieser Debug-Build enthält das experimentelle Modell nicht.',
    'quran_asr_failed': 'Erkennung fehlgeschlagen. Bitte erneut versuchen.',
    'hifz_live_preview': 'Live-Versvorschau (unbestätigt)',
    'hifz_provisional': 'Nur Vorschau — endgültige Erkennung ausstehend',
    'tab_hifz': 'Hifz',
    'hifz_select': 'Sure auswählen oder suchen',
    'hifz_review': 'Wiederholen',
    'hifz_recite': 'Auswendig rezitieren',
    'hifz_review_intro': 'Lies und höre auf der vollständigen Mushaf-Seite.',
    'hifz_step': 'Versweise üben',
    'hifz_intro':
        'Rezitiere weiter. Bestätigte Verse erscheinen an ihrem Platz. Diese experimentelle Hilfe prüft erkannte Wörter, nicht Aussprache oder Tadschwid.',
    'hifz_start': 'Rezitieren',
    'hifz_ready': 'Beginne auswendig und folge der Reihenfolge der Verse.',
    'hifz_resume': 'Weiter',
    'hifz_pause': 'Pause',
    'hifz_finalizing': 'Erkennung wird abgeschlossen…',
    'hifz_hint': 'Hinweis',
    'hifz_reveal': 'Zeigen',
    'hifz_hint_used':
        'Hinweiswörter gezeigt. Dieser Vers wurde mit Hinweis geübt.',
    'hifz_resume_message': 'Erkennung pausiert. Setze hier fort.',
    'hifz_unaided': 'Treffer ohne Hilfe',
    'hifz_assisted': 'Mit Hinweis',
    'hifz_mistakes': 'Fehler',
    'hifz_mistakes_empty': 'Noch keine Fehler in dieser Sitzung aufgezeichnet.',
  },
  'es': {
    'quran_asr_repeat_unverified': 'Sin verificar. Recita esta aleya de nuevo.',
    'quran_asr_share_diagnostics': 'Compartir grabaciones y diagnóstico',
    'quran_asr_share_empty': 'Aún no hay grabaciones de diagnóstico guardadas.',
    'quran_asr_retained_preview':
        'Palabras conservadas — sin verificar, no cuentan como coincidencia',
    'quran_asr_assisted': 'Con ayuda',
    'quran_asr_next_word': 'Continuar desde la palabra',
    'quran_asr_word_preview':
        'Vista previa de palabras en vivo (sin verificar)',
    'quran_asr_audio_debug_warning':
        'Solo AI Lab · Esta versión tiene activado el diagnóstico de audio. Se guardan localmente hasta seis fragmentos de esta grabación (hasta 30 segundos cada uno) y sus transcripciones, y pueden subirse con los informes de diagnóstico. Recita y pausa al terminar; la sesión no tiene límite de tiempo. Las palabras mostradas no están verificadas, las incorrectas bloquean el avance y el modelo puede omitir o inventar palabras. No es una evaluación de memorización ni de taywid.',
    'quran_asr_transcript_debug_warning':
        'Solo AI Lab · El texto reconocido en cada vista previa se guarda con datos de tiempo y progreso, y se sube con el informe, que se conserva hasta 30 días. No se guarda audio. Recita y pausa al terminar. Las palabras no están verificadas; el modelo puede omitirlas o inventarlas. No es una evaluación de memorización ni de taywid.',
    'quran_asr_live_warning':
        'Solo AI Lab · La vista previa de palabras en vivo empieza activada. Sigue recitando y pausa al terminar; la sesión no tiene límite de tiempo. El audio se comprueba en ventanas móviles de hasta 30 segundos. Las palabras anteriores se conservan sin verificar y no cuentan como coincidencias; las palabras incorrectas siguen bloqueando el avance. Desactiva la vista previa para ocultar palabras nuevas hasta la pausa. La transcripción sigue oculta. El modelo puede omitir o inventar palabras; una coincidencia no demuestra memorización ni tajwid correctos. El audio permanece en este dispositivo y los fragmentos temporales se eliminan.',
    'quran_asr_title': 'DEBUG: IA coránica en el dispositivo',
    'quran_asr_warning':
        'Experimental · Graba hasta 30 segundos y detén para comprobar. El audio permanece en el dispositivo; la grabación temporal se elimina. No cambia el progreso Hifz ni evalúa el taywid. El texto no está verificado: se pueden reconocer mal, completar o generar palabras a partir del ruido.',
    'quran_asr_check': 'Detener y comprobar',
    'quran_asr_cancel': 'Cancelar',
    'quran_asr_result': 'Texto no verificado',
    'quran_asr_time': 'Tiempo de reconocimiento (segundos)',
    'quran_asr_unavailable':
        'Esta compilación de depuración no incluye el modelo experimental.',
    'quran_asr_failed': 'Falló el reconocimiento. Inténtalo de nuevo.',
    'hifz_live_preview': 'Vista previa de aleyas en vivo (sin confirmar)',
    'hifz_provisional': 'Solo vista previa — esperando reconocimiento final',
    'tab_hifz': 'Hifz',
    'hifz_select': 'Elige o busca una sura',
    'hifz_review': 'Repasar',
    'hifz_recite': 'Recitar de memoria',
    'hifz_review_intro': 'Lee y escucha en la página completa del Mushaf.',
    'hifz_step': 'Práctica aleya por aleya',
    'hifz_intro':
        'Sigue recitando. Las aleyas confirmadas aparecen en su lugar. Esta ayuda experimental comprueba palabras reconocidas, no pronunciación ni tajwid.',
    'hifz_start': 'Recitar',
    'hifz_ready': 'Empieza de memoria y sigue el orden de las aleyas.',
    'hifz_resume': 'Continuar',
    'hifz_pause': 'Pausa',
    'hifz_finalizing': 'Finalizando reconocimiento…',
    'hifz_hint': 'Pista',
    'hifz_reveal': 'Mostrar',
    'hifz_hint_used':
        'Se muestran las palabras de ayuda. Esta aleya recibió una pista.',
    'hifz_resume_message': 'Reconocimiento en pausa. Continúa desde aquí.',
    'hifz_unaided': 'Coincidencias sin ayuda',
    'hifz_assisted': 'Con pista',
    'hifz_mistakes': 'Errores',
    'hifz_mistakes_empty': 'Aún no hay errores registrados en esta sesión.',
  },
};

const memorizationTranslations = <String, Map<String, String>>{
  'en': {
    'mem_cancel': 'Cancel',
    'mem_title': 'Memorize this surah',
    'mem_load_error':
        'The complete surah and Mushaf pages could not be loaded. Check your connection or download the complete Quran for offline reading, then try again.',
    'mem_intro':
        'Recite the entire selected ayah. A full word match reveals it. This experimental aid checks recognized words, not Tajweed or pronunciation.',
    'mem_consent_title': 'Optional voice word checking',
    'mem_consent':
        'Your voice and recitation can reveal sensitive religious information. The phone’s speech service may send audio to Apple, Google, or your configured recognition provider. Their processing and retention rules apply. This app does not save recordings or transcripts or send them to Ebaid LLC or Quran.Foundation. Arabic recognition and offline support vary by device. Continue only if you agree; hints and reference audio work without voice access.',
    'mem_agree': 'Agree and continue',
    'mem_listen': 'Recite ayah',
    'mem_stop': 'Stop and check',
    'mem_hint': 'Reveal as a hint',
    'mem_next': 'Next ayah',
    'mem_replay': 'Listen',
    'mem_ready': 'Recite from memory, then stop to check.',
    'mem_match': 'Recognized words match the full ayah.',
    'mem_mismatch':
        'The recognized words do not match. Recognition can mishear; retry or use a hint. Check word',
    'mem_error':
        'Arabic speech recognition failed or is unavailable. Check microphone/speech permissions and connectivity, then retry. Hints remain available.',
    'mem_missing':
        'Complete matching text is unavailable for this ayah. Use a hint or reference audio.',
    'mem_done':
        'Surah practice finished. Hints are not counted as a voice match.',
    'mem_hint_used': 'Revealed as a hint, not a voice match.',
    'mem_heard': 'Recognized words',
    'mem_wait': 'Listening or checking…',
    'mem_audio_error': 'Reference audio could not be played. Try again.',
  },
  'ar': {
    'mem_cancel': 'إلغاء',
    'mem_title': 'حفظ هذه السورة',
    'mem_load_error':
        'تعذر تحميل السورة وصفحات المصحف كاملة. تحقق من الاتصال أو نزّل القرآن كاملًا للقراءة دون اتصال، ثم أعد المحاولة.',
    'mem_intro':
        'اقرأ الآية المحددة كاملة من حفظك. تظهر عند تطابق جميع الكلمات. هذه أداة تجريبية لمقارنة الكلمات المتعرّف عليها، وليست لتقييم التجويد أو النطق.',
    'mem_consent_title': 'مقارنة صوتية اختيارية للكلمات',
    'mem_consent':
        'قد يكشف صوتك وتلاوتك معلومات دينية حساسة. قد ترسل خدمة التعرف على الكلام في الهاتف الصوت إلى Apple أو Google أو مزود التعرف الذي اخترته، وتسري قواعدهم للمعالجة والاحتفاظ. لا يحفظ التطبيق التسجيلات أو النصوص المتعرّف عليها ولا يرسلها إلى Ebaid LLC أو Quran.Foundation. يختلف دعم العربية والعمل دون اتصال حسب الجهاز. تابع فقط إذا وافقت؛ يمكن استخدام التلميحات والتلاوة المرجعية دون إذن صوتي.',
    'mem_agree': 'أوافق وأتابع',
    'mem_listen': 'تلاوة الآية',
    'mem_stop': 'إيقاف ومقارنة',
    'mem_hint': 'إظهار كتلميح',
    'mem_next': 'الآية التالية',
    'mem_replay': 'استماع',
    'mem_ready': 'اقرأ من حفظك، ثم أوقف التسجيل للمقارنة.',
    'mem_match': 'تطابقت الكلمات المتعرّف عليها مع الآية كاملة.',
    'mem_mismatch':
        'لم تتطابق الكلمات المتعرّف عليها. قد تخطئ خدمة التعرف؛ أعد المحاولة أو استخدم تلميحًا. راجع الكلمة',
    'mem_error':
        'تعذر التعرف على الكلام بالعربية. تحقق من أذونات الميكروفون والكلام والاتصال ثم أعد المحاولة. التلميحات متاحة.',
    'mem_missing':
        'نص المقارنة الكامل غير متاح لهذه الآية. استخدم تلميحًا أو التلاوة المرجعية.',
    'mem_done': 'انتهى تدريب السورة. التلميحات لا تُحتسب كتطابق صوتي.',
    'mem_hint_used': 'أُظهرت كتلميح، وليس كتطابق صوتي.',
    'mem_heard': 'الكلمات المتعرّف عليها',
    'mem_wait': 'جارٍ الاستماع أو المقارنة…',
    'mem_audio_error': 'تعذر تشغيل التلاوة المرجعية. أعد المحاولة.',
  },
  'ur': {
    'mem_cancel': 'منسوخ',
    'mem_title': 'یہ سورت یاد کریں',
    'mem_load_error':
        'پوری سورت اور مصحف کے صفحات لوڈ نہیں ہو سکے۔ انٹرنیٹ دیکھیں یا آف لائن پڑھنے کے لیے پورا قرآن ڈاؤن لوڈ کریں، پھر دوبارہ کوشش کریں۔',
    'mem_intro':
        'منتخب آیت پوری سنائیں۔ تمام الفاظ ملنے پر آیت ظاہر ہوگی۔ یہ تجرباتی مدد پہچانے گئے الفاظ کا موازنہ کرتی ہے، تجوید یا تلفظ کا نہیں۔',
    'mem_consent_title': 'اختیاری صوتی الفاظ کی جانچ',
    'mem_consent':
        'آپ کی آواز اور تلاوت حساس مذہبی معلومات ظاہر کر سکتی ہیں۔ فون کی آواز پہچاننے والی سروس آڈیو Apple، Google یا آپ کے منتخب فراہم کنندہ کو بھیج سکتی ہے۔ ان کی پراسیسنگ اور محفوظ رکھنے کی شرائط لاگو ہوتی ہیں۔ یہ ایپ ریکارڈنگ یا پہچانا گیا متن محفوظ نہیں کرتی اور Ebaid LLC یا Quran.Foundation کو نہیں بھیجتی۔ عربی اور آف لائن سہولت آلے کے مطابق مختلف ہے۔ صرف رضامندی پر آگے بڑھیں؛ اشارے اور نمونہ تلاوت بغیر صوتی اجازت دستیاب ہیں۔',
    'mem_agree': 'متفق ہوں، آگے بڑھیں',
    'mem_listen': 'آیت سنائیں',
    'mem_stop': 'روکیں اور جانچیں',
    'mem_hint': 'اشارے کے طور پر دکھائیں',
    'mem_next': 'اگلی آیت',
    'mem_replay': 'سنیں',
    'mem_ready': 'یاد سے پڑھیں، پھر جانچنے کے لیے روکیں۔',
    'mem_match': 'پہچانے گئے الفاظ پوری آیت سے ملتے ہیں۔',
    'mem_mismatch':
        'پہچانے گئے الفاظ نہیں ملے۔ سروس غلط سن سکتی ہے؛ دوبارہ کوشش کریں یا اشارہ لیں۔ یہ لفظ دیکھیں',
    'mem_error':
        'عربی آواز کی پہچان ناکام یا دستیاب نہیں۔ مائیک، آواز کی اجازت اور انٹرنیٹ دیکھ کر دوبارہ کوشش کریں۔ اشارے دستیاب ہیں۔',
    'mem_missing':
        'اس آیت کا مکمل تقابلی متن دستیاب نہیں۔ اشارہ یا نمونہ تلاوت استعمال کریں۔',
    'mem_done': 'سورت کی مشق ختم ہوئی۔ اشارہ صوتی مطابقت نہیں سمجھا جاتا۔',
    'mem_hint_used': 'اشارے کے طور پر دکھایا گیا، صوتی مطابقت نہیں۔',
    'mem_heard': 'پہچانے گئے الفاظ',
    'mem_wait': 'سن رہا ہے یا جانچ رہا ہے…',
    'mem_audio_error': 'نمونہ تلاوت نہیں چل سکی۔ دوبارہ کوشش کریں۔',
  },
  'tr': {
    'mem_cancel': 'İptal',
    'mem_title': 'Bu sureyi ezberle',
    'mem_load_error':
        'Surenin tamamı ve Mushaf sayfaları yüklenemedi. Bağlantıyı kontrol edin veya çevrimdışı okumak için tüm Kur’an’ı indirin, sonra tekrar deneyin.',
    'mem_intro':
        'Seçili ayetin tamamını okuyun. Tüm kelimeler eşleşince ayet görünür. Bu deneysel yardımcı tanınan kelimeleri kontrol eder; tecvidi veya telaffuzu değerlendirmez.',
    'mem_consent_title': 'İsteğe bağlı sesli kelime kontrolü',
    'mem_consent':
        'Sesiniz ve okuyuşunuz hassas dinî bilgiler içerebilir. Telefonun konuşma hizmeti sesi Apple, Google veya seçtiğiniz sağlayıcıya gönderebilir. Onların işleme ve saklama kuralları geçerlidir. Uygulama kayıtları veya metinleri saklamaz, Ebaid LLC ya da Quran.Foundation’a göndermez. Arapça ve çevrimdışı destek cihaza göre değişir. Yalnızca kabul ediyorsanız devam edin; ipuçları ve örnek okuyuş ses izni olmadan kullanılabilir.',
    'mem_agree': 'Kabul et ve devam et',
    'mem_listen': 'Ayeti oku',
    'mem_stop': 'Durdur ve kontrol et',
    'mem_hint': 'İpucu olarak göster',
    'mem_next': 'Sonraki ayet',
    'mem_replay': 'Dinle',
    'mem_ready': 'Ezberden okuyun, kontrol için durdurun.',
    'mem_match': 'Tanınan kelimeler ayetin tamamıyla eşleşiyor.',
    'mem_mismatch':
        'Tanınan kelimeler eşleşmiyor. Tanıma hatası olabilir; tekrar deneyin veya ipucu kullanın. Şu kelimeyi kontrol edin',
    'mem_error':
        'Arapça konuşma tanıma başarısız veya kullanılamıyor. Mikrofon/konuşma izinlerini ve bağlantıyı kontrol edip tekrar deneyin. İpuçları kullanılabilir.',
    'mem_missing':
        'Bu ayetin tam karşılaştırma metni yok. İpucu veya örnek okuyuş kullanın.',
    'mem_done': 'Sure çalışması bitti. İpuçları sesli eşleşme sayılmaz.',
    'mem_hint_used': 'İpucu olarak gösterildi; sesli eşleşme değil.',
    'mem_heard': 'Tanınan kelimeler',
    'mem_wait': 'Dinleniyor veya kontrol ediliyor…',
    'mem_audio_error': 'Örnek okuyuş çalınamadı. Tekrar deneyin.',
  },
  'fr': {
    'mem_cancel': 'Annuler',
    'mem_title': 'Mémoriser cette sourate',
    'mem_load_error':
        'Impossible de charger toute la sourate et les pages du Mushaf. Vérifiez la connexion ou téléchargez le Coran complet pour la lecture hors ligne, puis réessayez.',
    'mem_intro':
        'Récitez tout le verset sélectionné. Il apparaît si tous les mots correspondent. Cette aide expérimentale vérifie les mots reconnus, pas le tajwid ni la prononciation.',
    'mem_consent_title': 'Vérification vocale facultative',
    'mem_consent':
        'Votre voix et votre récitation peuvent révéler des informations religieuses sensibles. Le service vocal du téléphone peut envoyer le son à Apple, Google ou au fournisseur choisi. Leurs règles de traitement et de conservation s’appliquent. L’application ne conserve ni enregistrements ni transcriptions et ne les envoie pas à Ebaid LLC ou Quran.Foundation. L’arabe et le mode hors ligne dépendent de l’appareil. Continuez uniquement si vous acceptez ; les indices et la récitation de référence fonctionnent sans autorisation vocale.',
    'mem_agree': 'Accepter et continuer',
    'mem_listen': 'Réciter le verset',
    'mem_stop': 'Arrêter et vérifier',
    'mem_hint': 'Révéler comme indice',
    'mem_next': 'Verset suivant',
    'mem_replay': 'Écouter',
    'mem_ready': 'Récitez de mémoire, puis arrêtez pour vérifier.',
    'mem_match': 'Les mots reconnus correspondent au verset entier.',
    'mem_mismatch':
        'Les mots reconnus ne correspondent pas. La reconnaissance peut se tromper ; réessayez ou utilisez un indice. Vérifiez le mot',
    'mem_error':
        'Reconnaissance arabe indisponible ou en échec. Vérifiez les autorisations micro/vocales et la connexion, puis réessayez. Les indices restent disponibles.',
    'mem_missing':
        'Le texte complet de comparaison manque pour ce verset. Utilisez un indice ou la référence audio.',
    'mem_done':
        'Entraînement de la sourate terminé. Les indices ne comptent pas comme correspondances vocales.',
    'mem_hint_used': 'Révélé comme indice, pas comme correspondance vocale.',
    'mem_heard': 'Mots reconnus',
    'mem_wait': 'Écoute ou vérification…',
    'mem_audio_error': 'Impossible de lire la référence audio. Réessayez.',
  },
  'id': {
    'mem_cancel': 'Batal',
    'mem_title': 'Hafalkan surah ini',
    'mem_load_error':
        'Surah dan halaman Mushaf lengkap tidak dapat dimuat. Periksa koneksi atau unduh seluruh Al-Qur’an untuk membaca luring, lalu coba lagi.',
    'mem_intro':
        'Bacakan seluruh ayat yang dipilih. Ayat ditampilkan jika semua kata cocok. Bantuan eksperimental ini memeriksa kata yang dikenali, bukan tajwid atau pelafalan.',
    'mem_consent_title': 'Pemeriksaan kata dengan suara opsional',
    'mem_consent':
        'Suara dan bacaan Anda dapat mengungkap informasi agama yang sensitif. Layanan ucapan ponsel dapat mengirim audio ke Apple, Google, atau penyedia yang Anda pilih. Aturan pemrosesan dan penyimpanan mereka berlaku. Aplikasi tidak menyimpan rekaman atau transkrip maupun mengirimkannya ke Ebaid LLC atau Quran.Foundation. Dukungan bahasa Arab dan luring berbeda menurut perangkat. Lanjutkan hanya jika setuju; petunjuk dan audio contoh tersedia tanpa izin suara.',
    'mem_agree': 'Setuju dan lanjutkan',
    'mem_listen': 'Bacakan ayat',
    'mem_stop': 'Hentikan dan periksa',
    'mem_hint': 'Tampilkan sebagai petunjuk',
    'mem_next': 'Ayat berikutnya',
    'mem_replay': 'Dengarkan',
    'mem_ready': 'Bacakan dari hafalan, lalu hentikan untuk memeriksa.',
    'mem_match': 'Kata yang dikenali cocok dengan seluruh ayat.',
    'mem_mismatch':
        'Kata yang dikenali tidak cocok. Pengenalan dapat salah dengar; coba lagi atau gunakan petunjuk. Periksa kata',
    'mem_error':
        'Pengenalan ucapan Arab gagal atau tidak tersedia. Periksa izin mikrofon/ucapan dan koneksi, lalu coba lagi. Petunjuk tetap tersedia.',
    'mem_missing':
        'Teks lengkap pembanding ayat ini tidak tersedia. Gunakan petunjuk atau audio contoh.',
    'mem_done':
        'Latihan surah selesai. Petunjuk tidak dihitung sebagai kecocokan suara.',
    'mem_hint_used': 'Ditampilkan sebagai petunjuk, bukan kecocokan suara.',
    'mem_heard': 'Kata yang dikenali',
    'mem_wait': 'Mendengarkan atau memeriksa…',
    'mem_audio_error': 'Audio contoh tidak dapat diputar. Coba lagi.',
  },
  'de': {
    'mem_cancel': 'Abbrechen',
    'mem_title': 'Diese Sure auswendig lernen',
    'mem_load_error':
        'Die vollständige Sure und Mushaf-Seiten konnten nicht geladen werden. Prüfe die Verbindung oder lade den gesamten Koran zum Offline-Lesen herunter und versuche es erneut.',
    'mem_intro':
        'Rezitiere den gesamten ausgewählten Vers. Stimmen alle Wörter überein, wird er sichtbar. Diese experimentelle Hilfe prüft erkannte Wörter, nicht Tadschwid oder Aussprache.',
    'mem_consent_title': 'Optionale Sprachprüfung der Wörter',
    'mem_consent':
        'Deine Stimme und Rezitation können sensible religiöse Informationen offenbaren. Der Sprachdienst des Telefons kann Audio an Apple, Google oder deinen gewählten Anbieter senden. Deren Verarbeitungs- und Aufbewahrungsregeln gelten. Die App speichert keine Aufnahmen oder Transkripte und sendet sie nicht an Ebaid LLC oder Quran.Foundation. Arabisch- und Offline-Unterstützung hängen vom Gerät ab. Fahre nur mit Zustimmung fort; Hinweise und Referenzaudio funktionieren ohne Sprachfreigabe.',
    'mem_agree': 'Zustimmen und fortfahren',
    'mem_listen': 'Vers rezitieren',
    'mem_stop': 'Stoppen und prüfen',
    'mem_hint': 'Als Hinweis zeigen',
    'mem_next': 'Nächster Vers',
    'mem_replay': 'Anhören',
    'mem_ready': 'Rezitiere aus dem Gedächtnis und stoppe zum Prüfen.',
    'mem_match': 'Die erkannten Wörter stimmen mit dem ganzen Vers überein.',
    'mem_mismatch':
        'Die erkannten Wörter stimmen nicht überein. Die Erkennung kann sich irren; versuche es erneut oder nutze einen Hinweis. Prüfe Wort',
    'mem_error':
        'Arabische Spracherkennung fehlgeschlagen oder nicht verfügbar. Prüfe Mikrofon-/Sprachberechtigungen und Verbindung und versuche es erneut. Hinweise bleiben verfügbar.',
    'mem_missing':
        'Der vollständige Vergleichstext dieses Verses fehlt. Nutze einen Hinweis oder Referenzaudio.',
    'mem_done':
        'Surenübung beendet. Hinweise zählen nicht als Sprachübereinstimmung.',
    'mem_hint_used': 'Als Hinweis gezeigt, nicht als Sprachübereinstimmung.',
    'mem_heard': 'Erkannte Wörter',
    'mem_wait': 'Wird angehört oder geprüft…',
    'mem_audio_error':
        'Referenzaudio konnte nicht abgespielt werden. Versuche es erneut.',
  },
  'es': {
    'mem_cancel': 'Cancelar',
    'mem_title': 'Memorizar esta sura',
    'mem_load_error':
        'No se pudieron cargar toda la sura y las páginas del Mushaf. Revisa la conexión o descarga el Corán completo para leer sin conexión y reintenta.',
    'mem_intro':
        'Recita toda la aleya seleccionada. Se muestra si coinciden todas las palabras. Esta ayuda experimental comprueba las palabras reconocidas, no el tajwid ni la pronunciación.',
    'mem_consent_title': 'Comprobación vocal opcional',
    'mem_consent':
        'Tu voz y recitación pueden revelar información religiosa sensible. El servicio de voz del teléfono puede enviar audio a Apple, Google o tu proveedor elegido. Se aplican sus normas de procesamiento y conservación. La app no guarda grabaciones ni transcripciones ni las envía a Ebaid LLC o Quran.Foundation. El soporte de árabe y sin conexión depende del dispositivo. Continúa solo si aceptas; las pistas y el audio de referencia funcionan sin permiso de voz.',
    'mem_agree': 'Aceptar y continuar',
    'mem_listen': 'Recitar la aleya',
    'mem_stop': 'Detener y comprobar',
    'mem_hint': 'Mostrar como pista',
    'mem_next': 'Aleya siguiente',
    'mem_replay': 'Escuchar',
    'mem_ready': 'Recita de memoria y detén para comprobar.',
    'mem_match': 'Las palabras reconocidas coinciden con toda la aleya.',
    'mem_mismatch':
        'Las palabras reconocidas no coinciden. El reconocimiento puede equivocarse; reintenta o usa una pista. Revisa la palabra',
    'mem_error':
        'El reconocimiento en árabe falló o no está disponible. Revisa los permisos de micrófono/voz y la conexión, y reintenta. Las pistas siguen disponibles.',
    'mem_missing':
        'No está disponible el texto completo de comparación de esta aleya. Usa una pista o el audio de referencia.',
    'mem_done':
        'Práctica de sura terminada. Las pistas no cuentan como coincidencias de voz.',
    'mem_hint_used': 'Mostrada como pista, no como coincidencia de voz.',
    'mem_heard': 'Palabras reconocidas',
    'mem_wait': 'Escuchando o comprobando…',
    'mem_audio_error':
        'No se pudo reproducir el audio de referencia. Reintenta.',
  },
};
