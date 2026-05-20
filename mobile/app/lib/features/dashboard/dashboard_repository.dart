import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:raabta_ai/models/listing.dart' as listing_model;
import 'package:raabta_ai/services/listing_service.dart';
import 'package:raabta_ai/services/agent_service.dart';
import 'package:raabta_ai/services/api_service.dart';

import '../../app/app_config.dart';
import '../../models/request.dart';
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
      final daysSinceCreation = DateTime.now()
          .difference(listing.createdAt)
          .inDays;
      if (daysSinceCreation <= 7) {
        tone = ListingTone.newListing;
      }
    }

    final visibility = listing.isPublic
        ? ListingVisibility.public
        : ListingVisibility.private;
    final status = listing.status == 'archived' || listing.status == 'sold'
        ? ListingStatus.archived
        : ListingStatus.active;

    final priceLabel = listing.demandPrice != null
        ? _formatPrice(listing.demandPrice!)
        : '—';
    final sizeLabel = listing.size != null
        ? '${listing.size} ${listing.unit}'
        : '—';
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
      sublocation: listing.subLocationRaw ?? '',
      notes: listing.notes.isNotEmpty ? listing.notes.join(' \u2014 ') : '',
      latitude: listing.latitude != null && listing.latitude != 0.0
          ? listing.latitude!
          : null,
      longitude: listing.longitude != null && listing.longitude != 0.0
          ? listing.longitude!
          : null,
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
    final agent = json['agents'];
    final listedBy = agent is Map<String, dynamic>
        ? (agent['name']?.toString() ?? 'Unknown')
        : 'Unknown';
    final agencyName = agent is Map<String, dynamic>
        ? (agent['agency_name']?.toString() ?? 'Unknown Agency')
        : 'Unknown Agency';
    final contactNumber = (json['owner_agent_id'] ?? '').toString();
    return _toListing(listing).copyWith(
      listedBy: listedBy,
      agencyName: agencyName,
      contactNumber: contactNumber,
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

  /// Watch public listings — tries backend API first, falls back to Supabase realtime,
  /// then an empty result.
  Stream<List<ListingRecord>> watchListings() {
    if (AppConfig.hasBackend) {
      return Stream.fromFuture(_fetchMapListingsFromApi()).handleError((e) {
        debugPrint('Backend listings error: $e');
        return <ListingRecord>[];
      });
    }

    if (!AppConfig.hasSupabase) {
      return Stream<List<ListingRecord>>.value(<ListingRecord>[]);
    }

    try {
      return Supabase.instance.client
          .from('listings')
          .stream(primaryKey: ['id'])
          .map((rows) {
            final publicRows = rows
                .where(
                  (Map<String, dynamic> row) =>
                      row['is_public'] as bool? ?? false,
                )
                .toList();
            return publicRows
                .map(
                  (Map<String, dynamic> json) =>
                      listing_model.Listing.fromJson(json),
                )
                .map(_toListing)
                .toList(growable: false)
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          })
          .handleError((e) {
            debugPrint('Supabase listings error: $e');
            return <ListingRecord>[];
          });
    } catch (e) {
      debugPrint('Error setting up listings stream: $e');
      return Stream<List<ListingRecord>>.value(<ListingRecord>[]);
    }
  }

  Future<List<ListingRecord>> _fetchMapListingsFromApi() async {
    try {
      final items = await _api.getMapListings();
      final records =
          items
              .map((e) => _fromApiJson(e as Map<String, dynamic>))
              .where((record) => record.status == ListingStatus.active)
              .where(
                (record) => record.latitude != null && record.longitude != null,
              )
              .toList(growable: false)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      debugPrint(
        'Loaded ${records.length} active map listings from /api/listings',
      );
      return records;
    } catch (e) {
      debugPrint('Backend map listings fetch failed: $e');
      return <ListingRecord>[];
    }
  }

  /// Fetch the current agent's requests
  Future<List<Request>> fetchMyRequests() async {
    if (AppConfig.hasBackend) {
      try {
        final raw = await _api.getMyRequests();
        final records =
            raw
                .map((e) => Request.fromJson(e as Map<String, dynamic>))
                .toList(growable: false)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        debugPrint('✅ Loaded ${records.length} requests from backend API');
        return records;
      } catch (e) {
        debugPrint('❌ Backend my requests failed, falling back: $e');
      }
    }
    return [];
  }

  /// Toggle a listing's public/private visibility via the API
  Future<void> toggleListingVisibility(String listingId, bool isPublic) async {
    if (AppConfig.hasBackend) {
      await _api.updateListing(listingId, {'is_public': isPublic});
    }
  }

  /// Mark a listing as sold/archived via the API
  Future<void> markListingSold(String listingId) async {
    if (AppConfig.hasBackend) {
      await _api.updateListing(listingId, {'status': 'sold'});
    }
  }

  /// Delete a request by ID
  Future<void> deleteRequest(String id) async {
    if (AppConfig.hasBackend) {
      await _api.deleteRequest(id);
    }
  }

  /// Fetch agent's own listings for vault
  Future<List<ListingRecord>> fetchAgentListings(String agentId) async {
    if (AppConfig.hasBackend) {
      try {
        final raw = await _api.getMyListings();
        final records =
            raw
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
    return watchListings()
        .map((listings) {
          final blockMap = <String, List<ListingRecord>>{};
          for (final listing in listings) {
            blockMap.putIfAbsent(listing.blockName, () => []).add(listing);
          }

          final stats = blockMap.entries.map((entry) {
            final lst = entry.value;
            final hotCount = lst
                .where((l) => l.signalTone == ListingTone.hot)
                .length;
            final demandRatio = lst.isNotEmpty
                ? ((hotCount / lst.length) + 1.0)
                : 1.0;
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
        })
        .handleError((e) {
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

  /// Watch match leads — uses backend API polling as requested
  Stream<List<MatchLead>> watchMatchLeads() async* {
    while (true) {
      if (AppConfig.hasBackend) {
        try {
          final notifications = await _fetchNotificationsFromApi();
          yield notifications;
        } catch (e) {
          debugPrint('Backend notifications error: $e');
        }
      } else {
        yield DashboardFixtures.matchLeads;
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  Future<List<MatchLead>> _fetchNotificationsFromApi() async {
    try {
      final raw = await _api.getNotifications();
      final leads =
          raw
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
        debugPrint(
          '✅ Loaded ${entries.length} leaderboard entries from backend API',
        );
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

  Future<List<RecommendationEntry>> fetchRecommendations({
    int limit = 20,
  }) async {
    if (!AppConfig.hasBackend) return [];
    try {
      final raw = await _api.getRecommendations(limit: limit);
      return raw
          .map((e) => RecommendationEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
      return [];
    }
  }

  Future<List<RecommendationEntry>> runAndFetchRecommendations() async {
    if (!AppConfig.hasBackend) return [];
    try {
      await _api.runRecommendations();
    } catch (e) {
      debugPrint('Error running recommendations: $e');
    }
    return fetchRecommendations(limit: 20);
  }

  Future<Map<String, dynamic>> fetchIntelBundle() async {
    if (!AppConfig.hasBackend) {
      return {
        'dashboard': <String, dynamic>{},
        'demandVsSupply': <dynamic>[],
        'priceStats': <dynamic>[],
        'velocity': <dynamic>[],
        'cornerPremium': <dynamic>[],
      };
    }

    try {
      final results = await Future.wait<dynamic>([
        _api.getDashboardStats(),
        _api.getDemandVsSupply(),
        _api.getPriceStats(),
        _api.getVelocity(days: 30),
        _api.getCornerPremium(),
      ]);
      return {
        'dashboard': results[0] as Map<String, dynamic>,
        'demandVsSupply': results[1] as List<dynamic>,
        'priceStats': results[2] as List<dynamic>,
        'velocity': results[3] as List<dynamic>,
        'cornerPremium': results[4] as List<dynamic>,
      };
    } catch (e) {
      debugPrint('Error loading intel bundle: $e');
      return _buildIntelFallbackFromListings();
    }
  }

  Future<Map<String, dynamic>> _buildIntelFallbackFromListings() async {
    try {
      final raw = await _api.getMapListings();
      final items = raw
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      final active = items
          .where((l) => (l['status'] ?? 'active') == 'active')
          .toList(growable: false);

      final hotCount = active
          .where((l) => (l['is_hot_property'] ?? false) == true)
          .length;

      final supplyMap = <String, int>{};
      for (final l in active) {
        final block = (l['block_id'] ?? 'Unknown').toString();
        supplyMap[block] = (supplyMap[block] ?? 0) + 1;
      }

      final demandVsSupply = supplyMap.entries
          .map(
            (e) => <String, dynamic>{
              'block_id': e.key,
              'supply': e.value,
              'demand': 0,
              'demand_supply_ratio': 0.0,
            },
          )
          .toList(growable: false)
        ..sort((a, b) => (b['supply'] as int).compareTo(a['supply'] as int));

      final groupedPrices = <String, List<int>>{};
      for (final l in active) {
        final block = (l['block_id'] ?? 'Unknown').toString();
        final unit = (l['unit'] ?? '').toString();
        final price = l['demand_price'];
        if (price is! num) continue;
        final key = '${block}__$unit';
        groupedPrices.putIfAbsent(key, () => []).add(price.toInt());
      }

      final priceStats = groupedPrices.entries.map((entry) {
        final prices = entry.value..sort();
        final n = prices.length;
        final avg = prices.reduce((a, b) => a + b) ~/ n;
        final median = n.isOdd
            ? prices[n ~/ 2]
            : ((prices[n ~/ 2 - 1] + prices[n ~/ 2]) ~/ 2);
        final split = entry.key.split('__');
        return <String, dynamic>{
          'block_id': split.first,
          'unit': split.length > 1 ? split[1] : '',
          'count': n,
          'min_price': prices.first,
          'max_price': prices.last,
          'avg_price': avg,
          'median_price': median,
        };
      }).toList(growable: false);

      final cornerByBlock = <String, ({List<int> corner, List<int> nonCorner})>{};
      for (final l in active) {
        final block = (l['block_id'] ?? 'Unknown').toString();
        final price = l['demand_price'];
        if (price is! num) continue;
        final features = (l['features'] as List<dynamic>? ?? const [])
            .map((f) => f.toString().toLowerCase())
            .toSet();
        final rec = cornerByBlock[block] ?? (corner: <int>[], nonCorner: <int>[]);
        if (features.contains('corner')) {
          rec.corner.add(price.toInt());
        } else {
          rec.nonCorner.add(price.toInt());
        }
        cornerByBlock[block] = rec;
      }

      final cornerPremium = cornerByBlock.entries.map((e) {
        int? avg(List<int> arr) => arr.isEmpty ? null : (arr.reduce((a, b) => a + b) ~/ arr.length);
        final cAvg = avg(e.value.corner);
        final nAvg = avg(e.value.nonCorner);
        final pct = (cAvg != null && nAvg != null && nAvg > 0)
            ? (((cAvg - nAvg) / nAvg) * 100)
            : null;
        return <String, dynamic>{
          'block_id': e.key,
          'corner_avg_price': cAvg,
          'non_corner_avg_price': nAvg,
          'corner_premium_pct': pct != null ? double.parse(pct.toStringAsFixed(1)) : null,
          'corner_count': e.value.corner.length,
          'non_corner_count': e.value.nonCorner.length,
        };
      }).toList(growable: false);

      return {
        'dashboard': <String, dynamic>{
          'hot_properties_count': hotCount,
          'avg_velocity_days': null,
        },
        'demandVsSupply': demandVsSupply,
        'priceStats': priceStats,
        'velocity': <dynamic>[],
        'cornerPremium': cornerPremium,
      };
    } catch (e) {
      debugPrint('Intel fallback build failed: $e');
      return {
        'dashboard': <String, dynamic>{},
        'demandVsSupply': <dynamic>[],
        'priceStats': <dynamic>[],
        'velocity': <dynamic>[],
        'cornerPremium': <dynamic>[],
      };
    }
  }
}
