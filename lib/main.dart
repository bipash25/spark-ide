import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark_ide/app.dart';
import 'package:spark_ide/core/config/firebase_config.dart';
import 'package:spark_ide/providers/settings_provider.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences eagerly so providers can use it synchronously
  final prefs = await SharedPreferences.getInstance();

  // Initialize Firebase if configured
  if (FirebaseConfig.isConfigured) {
    await Firebase.initializeApp(
      options: FirebaseConfig.currentPlatform,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SparkApp(),
    ),
  );
}
