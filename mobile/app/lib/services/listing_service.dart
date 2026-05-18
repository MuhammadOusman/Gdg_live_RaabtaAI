import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:raabta_ai/models/listing.dart';
import 'package:raabta_ai/services/supabaseClient.dart';
import 'package:raabta_ai/app/app_config.dart';

class ListingService {
  SupabaseClient? _client;

  SupabaseClient? get client {
    if (!AppConfig.hasSupabase) return null;
    try {
      _client ??= supabaseClient;
      return _client;
    } catch (e) {
      print('Warning: Could not access Supabase client: $e');
      return null;
    }
  }

  /// Fetch all public listings
  Future<List<Listing>> fetchPublicListings({int limit = 100, int offset = 0}) async {
    if (client == null) {
      return [];
    }
    try {
      final response = await client!
          .from(SupabaseTables.listings)
          .select()
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((json) => Listing.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching public listings: $e');
      rethrow;
    }
  }

  /// Fetch listings owned by a specific agent
  Future<List<Listing>> fetchAgentListings(String agentId, {int limit = 100, int offset = 0}) async {
    if (client == null) {
      return [];
    }
    try {
      final response = await client!
          .from(SupabaseTables.listings)
          .select()
          .eq('owner_agent_id', agentId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((json) => Listing.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching agent listings: $e');
      rethrow;
    }
  }

  /// Fetch hot properties
  Future<List<Listing>> fetchHotProperties({int limit = 50}) async {
    if (client == null) {
      return [];
    }
    try {
      final response = await client!
          .from(SupabaseTables.listings)
          .select()
          .eq('is_hot_property', true)
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((json) => Listing.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching hot properties: $e');
      rethrow;
    }
  }

  /// Fetch listings by block
  Future<List<Listing>> fetchListingsByBlock(String blockId, {int limit = 100}) async {
    if (client == null) {
      return [];
    }
    try {
      final response = await client!
          .from(SupabaseTables.listings)
          .select()
          .eq('block_id', blockId)
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((json) => Listing.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching listings by block: $e');
      rethrow;
    }
  }

  /// Fetch a single listing by ID
  Future<Listing?> fetchListing(String listingId) async {
    if (client == null) {
      return null;
    }
    try {
      final response = await client!
          .from(SupabaseTables.listings)
          .select()
          .eq('id', listingId)
          .single();

      return Listing.fromJson(response);
    } catch (e) {
      print('Error fetching listing: $e');
      return null;
    }
  }

  /// Toggle listing visibility (public/private)
  Future<void> toggleListingVisibility(String listingId, bool isPublic) async {
    if (client == null) {
      return;
    }
    try {
      await client!
          .from(SupabaseTables.listings)
          .update({'is_public': isPublic})
          .eq('id', listingId);
    } catch (e) {
      print('Error toggling listing visibility: $e');
      rethrow;
    }
  }

  /// Stream real-time updates for listings using a polling approach
  /// (PostgREST subscriptions require additional setup, so using periodic fetch for now)
  Stream<List<Listing>> streamPublicListings() async* {
    try {
      while (true) {
        final listings = await fetchPublicListings();
        yield listings;
        await Future.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      print('Error in listings stream: $e');
    }
  }
}
