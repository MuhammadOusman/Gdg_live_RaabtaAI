import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class AppConfig {
  static String supabaseUrl = '';
  static String supabaseAnonKey = '';
  static String backendUrl = '';
  static String agentsBackendUrl = '';
  static String agentPhone = '';
  static String agentName = '';

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasBackend => backendUrl.isNotEmpty;
}

class AppBootstrap {
  static Future<void> initialize() async {
    try {
      // Load environment variables from .env file
      await dotenv.load(fileName: '.env');

      AppConfig.supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      AppConfig.supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      String backend = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
      if (!kIsWeb) {
        try {
          if (Platform.isAndroid && (backend.contains('localhost') || backend.contains('127.0.0.1'))) {
            backend = backend.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
          }
        } catch (_) {}
      }
      AppConfig.backendUrl = backend;
      // Agents backend can be a separate service; fall back to main backend when not set.
      String agentsBackend = dotenv.env['AGENTS_BACKEND_URL'] ?? backend;
      if (!kIsWeb) {
        try {
          if (Platform.isAndroid && (agentsBackend.contains('localhost') || agentsBackend.contains('127.0.0.1'))) {
            agentsBackend = agentsBackend.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
          }
        } catch (_) {}
      }
      AppConfig.agentsBackendUrl = agentsBackend;
      AppConfig.agentPhone = dotenv.env['AGENT_PHONE'] ?? '+923001234567';
      AppConfig.agentName = dotenv.env['AGENT_NAME'] ?? 'Muhammad Ousman';

      if (AppConfig.hasSupabase) {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );
      } else {
        print('Warning: Supabase credentials not found, running in offline mode');
      }
    } catch (e) {
      print('Error initializing AppBootstrap: $e');
      // Continue without Supabase in test/offline mode
    }
  }
}
