import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_localizations.dart';
import 'core/providers/bookmark_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/streak_provider.dart';
import 'core/providers/recitation_provider.dart';
import 'core/providers/tafseer_provider.dart';
import 'core/theme/app_theme.dart';
import 'root_scaffold.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Show errors visually on screen (works in release mode)
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Container(
          color: Colors.red.shade50,
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error: ${details.exceptionAsString()}',
            style: const TextStyle(fontSize: 14, color: Colors.red),
          ),
        ),
      );
    };

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };

    try {
      await Hive.initFlutter();
      await Hive.openBox('settings');
      await Hive.openBox('streak');
      await Hive.openBox('verse_cache');
      await Hive.openBox('bookmarks');
    } catch (e) {
      runApp(_ErrorApp(message: 'Hive init failed: $e'));
      return;
    }

    LocaleProvider localeProvider;
    StreakProvider streakProvider;
    BookmarkProvider bookmarkProvider;
    try {
      localeProvider = LocaleProvider();
      streakProvider = StreakProvider();
      bookmarkProvider = BookmarkProvider();
    } catch (e) {
      runApp(_ErrorApp(message: 'Provider init failed: $e'));
      return;
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: localeProvider),
          ChangeNotifierProvider.value(value: streakProvider),
          ChangeNotifierProvider.value(value: bookmarkProvider),
          ChangeNotifierProvider(create: (_) => RecitationProvider()),
          ChangeNotifierProvider(
            create: (_) => TafseerProvider(
              langCode: localeProvider.locale.languageCode,
            ),
          ),
        ],
        child: const TajweedApp(),
      ),
    );
  }, (error, stack) {
    runApp(_ErrorApp(message: 'Uncaught error:\n$error'));
  });
}

/// Minimal error display app — no dependencies, always renders.
class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF3F3),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️ App Error',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 12),
                SelectableText(message,
                    style: const TextStyle(fontSize: 11, color: Colors.black87, fontFamily: 'Courier')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TajweedApp extends StatelessWidget {
  const TajweedApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
      title: 'Tajweed Practice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Multilingual support
      locale: localeProvider.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const RootScaffold(),
    );
  }
}
