import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:raabta_ai/models/listing.dart' as listing_model;
import 'package:raabta_ai/services/listing_service.dart';
import 'package:raabta_ai/services/agent_service.dart';
import 'package:raabta_ai/services/api_service.dart';

import '../../app/app_config.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  late ListingService _listingService;
  late AgentService _agentService;
  final ApiService _api = ApiService();

  DashboardRepository() {
    _listingService = ListingService();
    _agentService = AgentService();
  }

  /// Convert Supabase Listing model to dashboard ListingRecord
  ListingRecord _toListing(listing_model.Listing listing) {
    ListingTone tone = ListingTone.standard;
    if (listing.isHotProperty) {
      tone = ListingTone.hot;
    } else {
      final daysSinceCreation = DateTime.now().difference(listing.createdAt).inDays;
      if (daysSinceCreation <= 7) {
        tone = ListingTone.newListing;
      }
    }

    final visibility = listing.isPublic ? ListingVisibility.public : ListingVisibility.private;
    final status = listing.status == 'archived' || listing.status == 'sold'
        ? ListingStatus.archived
        : ListingStatus.active;

    final priceLabel = listing.demandPrice != null ? _formatPrice(listing.demandPrice!) : '—';
    final sizeLabel = listing.size != null ? '${listing.size} ${listing.unit}' : '—';
    final firstNote = listing.notes.isNotEmpty ? '${listing.notes.first}' : '';
    final notesSnippet = firstNote.length > 60
        ? '${firstNote.substring(0, 60)}...'
        : firstNote.isNotEmpty
            ? firstNote
            : 'No notes';

    return ListingRecord(
      id: listing.id,
      blockName: listing.blockId ?? 'Block —',
      priceLabel: priceLabel,
      sizeLabel: sizeLabel,
      notesSnippet: notesSnippet,
      latitude: listing.latitude != null && listing.latitude != 0.0 ? listing.latitude! : null,
      longitude: listing.longitude != null && listing.longitude != 0.0 ? listing.longitude! : null,
      signalTone: tone,
      visibility: visibility,
      status: status,
      demandRatio: 1.0,
      workArea: listing.subLocationRaw ?? 'Karachi',
      updatedAt: listing.updatedAt,
    );
  }

  /// Convert backend API listing JSON to dashboard ListingRecord
  ListingRecord _fromApiJson(Map<String, dynamic> json) {
    final listing = listing_model.Listing.fromJson(json);
    return _toListing(listing);
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

  /// Watch public listings — tries backend API first, falls back to Supabase realtime,
  /// then fixture data.
  Stream<List<ListingRecord>> watchListings() {
    if (AppConfig.hasBackend) {
      return Stream.fromFuture(_fetchListingsFromApi()).handleError((e) {
        debugPrint('Backend listings error: $e');
        return DashboardFixtures.listings;
      });
    }

    if (!AppConfig.hasSupabase) {
      return Stream.value(DashboardFixtures.listings);
    }

    try {
      return Supabase.instance.client
          .from('listings')
          .stream(primaryKey: ['id'])
          .map((rows) {
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
            debugPrint('Supabase listings error: $e');
            return DashboardFixtures.listings;
          });
    } catch (e) {
      debugPrint('Error setting up listings stream: $e');
      return Stream.value(DashboardFixtures.listings);
    }
  }

  Future<List<ListingRecord>> _fetchListingsFromApi() async {
    try {
      final raw = await _api.getListings();
      // Backend returns { data: [...], count: N }
      List<dynamic> items;
      if (raw is Map && raw.containsKey('data')) {
        items = raw['data'] as List<dynamic>;
      } else {
        items = raw as List<dynamic>;
      }
      final records = items
          .map((e) => _fromApiJson(e as Map<String, dynamic>))
          .toList(growable: false)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      debugPrint('✅ Loaded ${records.length} listings from backend API');
      return records;
    } catch (e) {
      debugPrint('❌ Backend fetch failed, falling back: $e');
      return DashboardFixtures.listings;
    }
  }

  /// Fetch agent's own listings for vault
  Future<List<ListingRecord>> fetchAgentListings(String agentId) async {
    if (AppConfig.hasBackend) {
      try {
        final raw = await _api.getMyListings();
        final records = raw
            .map((e) => _fromApiJson(e as Map<String, dynamic>))
            .toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        debugPrint('✅ Loaded ${records.length} my listings from backend API');
        return records;
      } catch (e) {
        debugPrint('❌ Backend my listings failed, falling back: $e');
      }
    }

    if (!AppConfig.hasSupabase) return DashboardFixtures.listings;

    try {
      final listings = await _listingService.fetchAgentListings(agentId);
      return listings.map(_toListing).toList(growable: false)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Error fetching agent listings: $e');
      return DashboardFixtures.listings;
    }
  }

  /// Watch block stats — derived from listings
  Stream<List<BlockMarketStat>> watchBlockStats() {
    return watchListings().map((listings) {
      final blockMap = <String, List<ListingRecord>>{};
      for (final listing in listings) {
        blockMap.putIfAbsent(listing.blockName, () => []).add(listing);
      }

      final stats = blockMap.entries.map((entry) {
        final lst = entry.value;
        final hotCount = lst.where((l) => l.signalTone == ListingTone.hot).length;
        final demandRatio = lst.isNotEmpty ? ((hotCount / lst.length) + 1.0) : 1.0;
        final coords = _resolveBlockCenter(entry.key, lst);

        return BlockMarketStat(
          blockName: entry.key,
          latitude: coords.latitude,
          longitude: coords.longitude,
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
      debugPrint('Error computing block stats: $e');
      return DashboardFixtures.blockStats;
    });
  }

  ({double latitude, double longitude}) _resolveBlockCenter(
    String blockName,
    List<ListingRecord> listings,
  ) {
    final listingWithCoordinates = listings.cast<ListingRecord?>().firstWhere(
          (listing) => listing?.hasCoordinates ?? false,
          orElse: () => null,
        );

    if (listingWithCoordinates != null) {
      return (
        latitude: listingWithCoordinates.latitude!,
        longitude: listingWithCoordinates.longitude!,
      );
    }

    final lower = blockName.toLowerCase();
    if (lower.contains('nazimabad')) return (latitude: 24.93, longitude: 67.04);
    if (lower.contains('pechs')) return (latitude: 24.87, longitude: 67.05);
    if (lower.contains('gulshan')) return (latitude: 24.91, longitude: 67.10);
    if (lower.contains('scheme 33')) return (latitude: 24.95, longitude: 67.12);

    return (latitude: 24.86, longitude: 67.03);
  }

  /// Watch match leads — tries backend, falls back to Supabase, then fixtures
  Stream<List<MatchLead>> watchMatchLeads() {
    if (AppConfig.hasBackend) {
      return Stream.fromFuture(_fetchNotificationsFromApi()).handleError((e) {
        debugPrint('Backend notifications error: $e');
        return DashboardFixtures.matchLeads;
      });
    }

    if (!AppConfig.hasSupabase) return Stream.value(DashboardFixtures.matchLeads);

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
            debugPrint('Supabase notifications error: $e');
            return DashboardFixtures.matchLeads;
          });
    } catch (e) {
      debugPrint('Error setting up match leads stream: $e');
      return Stream.value(DashboardFixtures.matchLeads);
    }
  }

  Future<List<MatchLead>> _fetchNotificationsFromApi() async {
    try {
      final raw = await _api.getNotifications();
      final leads = raw
          .map((e) => MatchLead.fromJson(e as Map<String, dynamic>))
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint('✅ Loaded ${leads.length} notifications from backend API');
      return leads;
    } catch (e) {
      debugPrint('❌ Backend notifications failed, falling back: $e');
      return DashboardFixtures.matchLeads;
    }
  }

  /// Fetch leaderboard — tries backend, falls back to Supabase, then fixtures
  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    if (AppConfig.hasBackend) {
      try {
        final raw = await _api.getLeaderboard();
        final entries = raw.asMap().entries.map((e) {
          final json = e.value as Map<String, dynamic>;
          return LeaderboardEntry(
            rank: (json['rank'] as int?) ?? (e.key + 1),
            name: (json['name'] ?? 'Agent') as String,
            agency: (json['agency_name'] ?? 'Raabta') as String,
            volumeLabel: '${json['public_listings_count'] ?? 0} Active',
          );
        }).toList();
        debugPrint('✅ Loaded ${entries.length} leaderboard entries from backend API');
        return entries;
      } catch (e) {
        debugPrint('❌ Backend leaderboard failed, falling back: $e');
      }
    }

    if (!AppConfig.hasSupabase) return DashboardFixtures.leaderboard;

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
      debugPrint('Error fetching leaderboard: $e');
      return DashboardFixtures.leaderboard;
    }
  }

  List<LeaderboardEntry> getLeaderboard() => DashboardFixtures.leaderboard;
  List<MarketPremium> getPremiums() => DashboardFixtures.premiums;
  List<String> getWorkAreas() => DashboardFixtures.workAreas;
}
