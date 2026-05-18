import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static String supabaseUrl = '';
  static String supabaseAnonKey = '';

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

class AppBootstrap {
  static Future<void> initialize() async {
    try {
      // Load environment variables from .env file
      await dotenv.load(fileName: '.env');

      AppConfig.supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      AppConfig.supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (AppConfig.hasSupabase) {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );
      }
    } catch (e) {
      // Continue without Supabase in test/offline mode
    }
  }
}
