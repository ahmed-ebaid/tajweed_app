import 'package:flutter/material.dart';

class AppTheme {
  static const _teal = Color(0xFF1D9E75);
  static const _gold = Color(0xFFB8860B);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _teal,
          brightness: Brightness.light,
          primary: _teal,
          secondary: _gold,
          surface: const Color(0xFFFAFAFA),
          onPrimary: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0x26000000), width: 0.5),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0x1A000000),
          thickness: 0.5,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF0F0F0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: _teal,
          unselectedItemColor: Color(0xFF888780),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
          titleLarge:    TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
          titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
          bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Color(0xFF1A1A1A)),
          bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFF3D3D3A)),
          bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFF888780)),
          labelMedium:   TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3D3D3A)),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _teal,
          brightness: Brightness.dark,
          primary: const Color(0xFF5DCAA5),
          secondary: const Color(0xFFF5E6C8),
          surface: const Color(0xFF1C1C1E),
          onPrimary: Colors.black,
        ),
        scaffoldBackgroundColor: const Color(0xFF111111),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1C1C1E),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1C1C1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0x26FFFFFF), width: 0.5),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0x1AFFFFFF),
          thickness: 0.5,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1C1C1E),
          selectedItemColor: Color(0xFF5DCAA5),
          unselectedItemColor: Color(0xFF888780),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white),
          titleLarge:    TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
          titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.white),
          bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFB4B2A9)),
          bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFF888780)),
          labelMedium:   TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFB4B2A9)),
        ),
      );

  // Tajweed rule colors (same in light and dark)
  static const Map<String, Color> tajweedColors = {
    'ghunnah':               Color(0xFF1D9E75),
    'qalqalah':              Color(0xFFA32D2D),
    'madd_tabeei':           Color(0xFF185FA5),
    'madd_muttasil':         Color(0xFF185FA5),
    'madd_munfasil':         Color(0xFF185FA5),
    'idgham_ghunnah':        Color(0xFFB8860B),
    'idgham_no_ghunnah':     Color(0xFFB8860B),
    'ikhfa':                 Color(0xFF8B008B),
    'iqlab':                 Color(0xFFD85A30),
    'izhar':                 Color(0xFF0F6E56),
    'shaddah':               Color(0xFF639922),
    'waqf':                  Color(0xFF888780),
    'sajdah':                Color(0xFF455A64),
  };
}
