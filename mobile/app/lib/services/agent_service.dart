import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:raabta_ai/models/agent.dart';
import 'package:raabta_ai/services/supabase_client.dart';
import 'package:raabta_ai/app/app_config.dart';

class AgentService {
  SupabaseClient? _client;

  SupabaseClient? get client {
    if (!AppConfig.hasSupabase) return null;
    try {
      _client ??= supabaseClient;
      return _client;
    } catch (e) {
      return null;
    }
  }

  /// Fetch all agents
  Future<List<Agent>> fetchAllAgents({int limit = 100, int offset = 0}) async {
    if (client == null) {
      return [];
    }
    try {
      final response = await client!
          .from(SupabaseTables.agents)
          .select()
          .order('public_listings_count', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((json) => Agent.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch a single agent by ID
  Future<Agent?> fetchAgent(String agentId) async {
    if (client == null) {
      return null;
    }
    try {
      final response = await client!
          .from(SupabaseTables.agents)
          .select()
          .eq('id', agentId)
          .single();

      return Agent.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Fetch top agents by listing count
  Future<List<Agent>> fetchTopAgents({int limit = 10}) async {
    if (client == null) {
      return [];
    }
    try {
      final response = await client!
          .from(SupabaseTables.agents)
          .select()
          .order('public_listings_count', ascending: false)
          .limit(limit);

      return (response as List).map((json) => Agent.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Search agents by name
  Future<List<Agent>> searchAgents(String query, {int limit = 50}) async {
    if (client == null) {
      return [];
    }
    try {
      final response = await client!
          .from(SupabaseTables.agents)
          .select()
          .ilike('name', '%$query%')
          .limit(limit);

      return (response as List).map((json) => Agent.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch verified agents
  Future<List<Agent>> fetchVerifiedAgents({int limit = 50}) async {
    if (client == null) {
      return [];
    }
    try {
      final response = await client!
          .from(SupabaseTables.agents)
          .select()
          .eq('is_verified', true)
          .order('public_listings_count', ascending: false)
          .limit(limit);

      return (response as List).map((json) => Agent.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }
}
