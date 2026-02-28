import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_ide/core/theme/theme_provider.dart';
import 'package:spark_ide/ui/layout/main_layout.dart';

/// Root application widget
class SparkApp extends ConsumerWidget {
  const SparkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final sparkThemeAsync = ref.watch(sparkThemeProvider);

    return sparkThemeAsync.when(
      data: (sparkTheme) => MaterialApp(
        title: 'Spark IDE',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: sparkTheme.toFlutterTheme(),
        darkTheme: sparkTheme.toFlutterTheme(),
        home: const MainLayout(),
      ),
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 48, color: Color(0xFF89B4FA)),
                SizedBox(height: 16),
                Text(
                  'Spark IDE',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFCDD6F4),
                  ),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF89B4FA),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      error: (error, stack) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFF38BA8)),
                const SizedBox(height: 16),
                Text(
                  'Failed to load theme: $error',
                  style: const TextStyle(color: Color(0xFFF38BA8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
