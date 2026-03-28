import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/providers/locale_provider.dart';

class LanguageSelectorScreen extends StatelessWidget {
  const LanguageSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final currentCode = localeProvider.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLanguage),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: LocaleProvider.supportedLocales.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, index) {
          final locale = LocaleProvider.supportedLocales[index];
          final code = locale.languageCode;
          final name = LocaleProvider.languageNames[code] ?? code;
          final isSelected = code == currentCode;
          final isRtl = LocaleProvider.rtlLanguages.contains(code);

          return ListTile(
            leading: _FlagCircle(code: code),
            title: Text(
              name,
              textDirection:
                  isRtl ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    isSelected ? FontWeight.w500 : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
            subtitle: isRtl
                ? null
                : Text(
                    _nativeName(code),
                    style: const TextStyle(fontSize: 13),
                  ),
            trailing: isSelected
                ? Icon(
                    Icons.check_circle_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              localeProvider.setLocale(locale);
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }

  /// Returns the language name in English alongside the native name.
  String _nativeName(String code) {
    switch (code) {
      case 'ar': return 'Arabic';
      case 'ur': return 'Urdu';
      case 'tr': return 'Turkish';
      case 'fr': return 'French';
      case 'id': return 'Indonesian';
      case 'de': return 'German';
      default:   return '';
    }
  }
}

/// A circular avatar showing a 2-letter language code abbreviation.
/// Replace with real flag SVGs from a package like `country_flags` in production.
class _FlagCircle extends StatelessWidget {
  final String code;
  const _FlagCircle({required this.code});

  static const Map<String, Color> _colors = {
    'en': Color(0xFF185FA5),
    'ar': Color(0xFF1D9E75),
    'ur': Color(0xFF085041),
    'tr': Color(0xFFA32D2D),
    'fr': Color(0xFF185FA5),
    'id': Color(0xFFB8860B),
    'de': Color(0xFF534AB7),
  };

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: _colors[code] ?? Colors.grey,
      child: Text(
        code.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
