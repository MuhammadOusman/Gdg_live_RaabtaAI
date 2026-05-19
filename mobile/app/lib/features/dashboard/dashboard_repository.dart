import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:raabta_ai/models/listing.dart' as listing_model;
import 'package:raabta_ai/services/listing_service.dart';
import 'package:raabta_ai/services/agent_service.dart';

import '../../app/app_config.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  late ListingService _listingService;
  late AgentService _agentService;

  DashboardRepository() {
    _listingService = ListingService();
    _agentService = AgentService();
  }

  /// Convert Supabase Listing model to dashboard ListingRecord
  ListingRecord _toListing(listing_model.Listing listing) {
    // Determine signal tone based on is_hot_property and creation date
    ListingTone tone = ListingTone.standard;
    if (listing.isHotProperty) {
      tone = ListingTone.hot;
    } else {
      final daysSinceCreation = DateTime.now().difference(listing.createdAt).inDays;
      if (daysSinceCreation <= 7) {
        tone = ListingTone.newListing;
      }
    }

    // Determine visibility
    final visibility = listing.isPublic ? ListingVisibility.public : ListingVisibility.private;

    // Determine status
    final status = listing.status == 'archived' || listing.status == 'sold'
        ? ListingStatus.archived
        : ListingStatus.active;

    // Format price label
    final priceLabel = listing.demandPrice != null
        ? _formatPrice(listing.demandPrice!)
        : '—';

    // Format size label
    final sizeLabel = listing.size != null
        ? '${listing.size} ${listing.unit}'
        : '—';

    // Get first note or snippet
    final notesSnippet = listing.notes.isNotEmpty
        ? '${listing.notes.first}'.substring(0, 60)
        : 'No notes';

    // Calculate demand ratio (stub for now - would need more complex logic)
    final demandRatio = 1.0;

    return ListingRecord(
      id: listing.id,
      blockName: listing.blockId ?? 'Block —',
      priceLabel: priceLabel,
      sizeLabel: sizeLabel,
      notesSnippet: notesSnippet,
      latitude: listing.latitude ?? 24.8607,
      longitude: listing.longitude ?? 67.0011,
      signalTone: tone,
      visibility: visibility,
      status: status,
      demandRatio: demandRatio,
      workArea: listing.subLocationRaw ?? 'Karachi',
      updatedAt: listing.updatedAt,
    );
  }

  String _formatPrice(int price) {
    if (price >= 10000000) {
      return '${(price / 10000000).toStringAsFixed(1)} Cr';
    } else if (price >= 100000) {
      return '${(price / 100000).toStringAsFixed(1)} Lakh';
    } else {
      return '$price';
    }
  }

  /// Watch public listings with real-time updates
  Stream<List<ListingRecord>> watchListings() {
    if (!AppConfig.hasSupabase) {
      return Stream.value(DashboardFixtures.listings);
    }

    try {
      return Supabase.instance.client
          .from('listings')
          .stream(primaryKey: ['id'])
          .map((rows) {
            // Filter for public listings
            final publicRows = rows
                .where((row) => (row as Map<String, dynamic>)['is_public'] as bool? ?? false)
                .toList();

            return publicRows
                .map((json) => listing_model.Listing.fromJson(json as Map<String, dynamic>))
                .map(_toListing)
                .toList(growable: false)
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          })
          .handleError((e) {
            print('Error watching listings: $e');
            // Fallback to fixtures on error
            return DashboardFixtures.listings;
          });
    } catch (e) {
      print('Error setting up listings stream: $e');
      return Stream.value(DashboardFixtures.listings);
    }
  }

  /// Fetch agent listings for vault
  Future<List<ListingRecord>> fetchAgentListings(String agentId) async {
    if (!AppConfig.hasSupabase) {
      return DashboardFixtures.listings;
    }

    try {
      final listings = await _listingService.fetchAgentListings(agentId);
      return listings
          .map(_toListing)
          .toList(growable: false)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      print('Error fetching agent listings: $e');
      return DashboardFixtures.listings;
    }
  }

  /// Watch block stats for demand visualization
  Stream<List<BlockMarketStat>> watchBlockStats() {
    if (!AppConfig.hasSupabase) {
      return Stream.value(DashboardFixtures.blockStats);
    }

    try {
      // Stream all listings and compute block stats
      return watchListings().map((listings) {
        // Group by block and calculate stats
        final blockMap = <String, List<ListingRecord>>{};
        for (final listing in listings) {
          blockMap.putIfAbsent(listing.blockName, () => []).add(listing);
        }

        final stats = blockMap.entries.map((entry) {
          final listings = entry.value;
          final hotCount = listings.where((l) => l.signalTone == ListingTone.hot).length;
          final demandRatio = listings.isNotEmpty ? ((hotCount / listings.length) + 1.0) : 1.0;

          return BlockMarketStat(
            blockName: entry.key,
            latitude: listings.first.latitude,
            longitude: listings.first.longitude,
            demandRatio: demandRatio,
            supplyRatio: 1.0,
            label: demandRatio > 2.0
                ? 'Overheated'
                : demandRatio > 1.5
                    ? 'Hot Zone'
                    : demandRatio > 1.0
                        ? 'Demand Spike'
                        : 'Balanced',
          );
        }).toList();

        return stats..sort((a, b) => b.demandRatio.compareTo(a.demandRatio));
      }).handleError((e) {
        print('Error computing block stats: $e');
        return DashboardFixtures.blockStats;
      });
    } catch (e) {
      print('Error setting up block stats stream: $e');
      return Stream.value(DashboardFixtures.blockStats);
    }
  }

  /// Watch match leads (notifications)
  Stream<List<MatchLead>> watchMatchLeads() {
    if (!AppConfig.hasSupabase) {
      return Stream.value(DashboardFixtures.matchLeads);
    }

    try {
      return Supabase.instance.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .map((rows) {
            return rows
                .map((json) => MatchLead.fromJson(json))
                .toList(growable: false)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          })
          .handleError((e) {
            print('Error watching match leads: $e');
            return DashboardFixtures.matchLeads;
          });
    } catch (e) {
      print('Error setting up match leads stream: $e');
      return Stream.value(DashboardFixtures.matchLeads);
    }
  }

  /// Fetch leaderboard from top agents
  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    if (!AppConfig.hasSupabase) {
      return DashboardFixtures.leaderboard;
    }

    try {
      final agents = await _agentService.fetchTopAgents(limit: 10);
      return agents.asMap().entries.map((entry) {
        return LeaderboardEntry(
          rank: entry.key + 1,
          name: entry.value.name,
          agency: entry.value.agencyName ?? 'Raabta',
          volumeLabel: '${entry.value.publicListingsCount} Active',
        );
      }).toList();
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return DashboardFixtures.leaderboard;
    }
  }

  /// Get leaderboard synchronously (for initialization)
  List<LeaderboardEntry> getLeaderboard() => DashboardFixtures.leaderboard;

  /// Get market premiums (static data for now)
  List<MarketPremium> getPremiums() => DashboardFixtures.premiums;

  /// Get work areas (would fetch from agents in production)
  List<String> getWorkAreas() => DashboardFixtures.workAreas;
}
