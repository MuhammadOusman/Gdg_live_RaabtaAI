import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initializeSupabase() async {
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception('Supabase credentials not found in .env file');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}

Supabase get supabase {
  return Supabase.instance;
}

SupabaseClient get supabaseClient {
  try {
    return supabase.client;
  } catch (e) {
    print('Warning: Supabase not initialized, returning null. Error: $e');
    // Return a dummy client that won't crash - actual queries will fail gracefully
    throw Exception('Supabase not initialized');
  }
}

/// Database table names
class SupabaseTables {
  static const String agents = 'agents';
  static const String listings = 'listings';
  static const String requests = 'requests';
  static const String notifications = 'notifications';
  static const String conversationState = 'conversation_state';
  static const String orchestrationLogs = 'orchestration_logs';
}
