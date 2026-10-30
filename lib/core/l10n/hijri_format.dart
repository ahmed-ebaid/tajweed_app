import '../services/hijri_calendar_service.dart';
import 'app_localizations.dart';

/// Localized Hijri month names, indexed by month - 1.
const Map<String, List<String>> hijriMonthNames = {
  'en': [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Ula',
    'Jumada al-Akhirah',
    'Rajab',
    'Shaban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qadah',
    'Dhu al-Hijjah',
  ],
  'ar': [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ],
  'ur': [
    'محرم',
    'صفر',
    'ربیع الاول',
    'ربیع الثانی',
    'جمادی الاول',
    'جمادی الثانی',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذوالقعدہ',
    'ذوالحجہ',
  ],
  'tr': [
    'Muharrem',
    'Safer',
    'Rebiülevvel',
    'Rebiülahir',
    'Cemaziyelevvel',
    'Cemaziyelahir',
    'Recep',
    'Şaban',
    'Ramazan',
    'Şevval',
    'Zilkade',
    'Zilhicce',
  ],
  'fr': [
    'Mouharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Joumada al-Oula',
    'Joumada al-Akhira',
    'Rajab',
    'Chaabane',
    'Ramadan',
    'Chawwal',
    'Dhou al-Qi’da',
    'Dhou al-Hijja',
  ],
  'id': [
    'Muharam',
    'Safar',
    'Rabiulawal',
    'Rabiulakhir',
    'Jumadilawal',
    'Jumadilakhir',
    'Rajab',
    'Syakban',
    'Ramadan',
    'Syawal',
    'Zulkaidah',
    'Zulhijah',
  ],
  'de': [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Dschumada al-Ula',
    'Dschumada al-Achira',
    'Radschab',
    'Schaban',
    'Ramadan',
    'Schawwal',
    'Dhu l-Qa’da',
    'Dhu l-Hiddscha',
  ],
  'es': [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Yumada al-Ula',
    'Yumada al-Ajira',
    'Rayab',
    'Shaabán',
    'Ramadán',
    'Shawwal',
    'Dhu al-Qada',
    'Dhu al-Hiyya',
  ],
};

const Map<String, String> _hijriEraSuffix = {
  'en': 'AH',
  'ar': 'هـ',
  'ur': 'ھ',
  'tr': 'H',
  'fr': 'AH',
  'id': 'H',
  'de': 'n. H.',
  'es': 'H',
};

String formatHijriDate(HijriDate date, AppLocalizations l10n) {
  final code = l10n.locale.languageCode;
  final months = hijriMonthNames[code] ?? hijriMonthNames['en']!;
  final suffix = _hijriEraSuffix[code] ?? _hijriEraSuffix['en']!;
  final day = l10n.digits(date.day);
  final year = l10n.digits(date.year);
  final month = months[date.month - 1];
  return code == 'de'
      ? '$day. $month $year $suffix'
      : '$day $month $year $suffix';
}
