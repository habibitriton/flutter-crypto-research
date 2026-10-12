import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/navigation/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: CryptoResearchApp()));
}

class CryptoResearchApp extends StatelessWidget {
  const CryptoResearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF8B72FF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptoScope',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF151722),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0C12),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0C12),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF151722),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF151722),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}
