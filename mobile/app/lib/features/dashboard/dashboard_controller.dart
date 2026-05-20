import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/request.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';

class DashboardController extends ChangeNotifier {
  DashboardController(this._repository) {
    // Seed with fixtures immediately so the UI is never empty
    _remoteListings.addAll(DashboardFixtures.listings);
    _blockStats.addAll(DashboardFixtures.blockStats);
    _matchLeads.addAll(DashboardFixtures.matchLeads);
    _leaderboard.addAll(DashboardFixtures.leaderboard);

    _bindStreams();
    _loadLeaderboard();
  }

  final DashboardRepository _repository;
  final List<ListingRecord> _remoteListings = [];
  final List<ListingRecord> _myListings = [];
  final List<BlockMarketStat> _blockStats = [];
  final List<MatchLead> _matchLeads = [];
  final List<LeaderboardEntry> _leaderboard = [];
  final List<Request> _requests = [];
  final Set<String> _selectedWorkAreas = <String>{};
  final Set<String> _archivedListingIds = <String>{};
  final Map<String, ListingVisibility> _visibilityOverrides = <String, ListingVisibility>{};

  StreamSubscription<List<ListingRecord>>? _listingsSub;
  StreamSubscription<List<BlockMarketStat>>? _statsSub;
  StreamSubscription<List<MatchLead>>? _matchesSub;
  Timer? _toastTimer;
  String? _toastMessage;
  String? _lastNotifiedMatchId;
  int _tabIndex = 0;
  ListingVisibility _vaultFilter = ListingVisibility.private;
  bool _showRequests = false;

  int get tabIndex => _tabIndex;
  ListingVisibility get vaultFilter => _vaultFilter;
  bool get showRequests => _showRequests;
  String? get toastMessage => _toastMessage;
  List<String> get availableWorkAreas => _repository.getWorkAreas();
  Set<String> get selectedWorkAreas => Set.unmodifiable(_selectedWorkAreas);
  List<LeaderboardEntry> get leaderboard => List.unmodifiable(_leaderboard);
  List<MarketPremium> get premiums => _repository.getPremiums();

  /// All active listings filtered by work area
  List<ListingRecord> get listings {
    final visible = _remoteListings.map((listing) {
      final mergedVisibility = _visibilityOverrides[listing.id] ?? listing.visibility;
      final mergedStatus = _archivedListingIds.contains(listing.id)
          ? ListingStatus.archived
          : listing.status;

      return listing.copyWith(
        visibility: mergedVisibility,
        status: mergedStatus,
      );
    }).where((listing) {
      final matchesArea = _selectedWorkAreas.isEmpty || _selectedWorkAreas.contains(listing.workArea);
      return matchesArea && listing.status == ListingStatus.active;
    }).toList(growable: false);

    visible.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return visible;
  }

  /// All active listings unfiltered by work area for map visualization
  List<ListingRecord> get unfilteredListings {
    final visible = _remoteListings.map((listing) {
      final mergedVisibility = _visibilityOverrides[listing.id] ?? listing.visibility;
      final mergedStatus = _archivedListingIds.contains(listing.id)
          ? ListingStatus.archived
          : listing.status;

      return listing.copyWith(
        visibility: mergedVisibility,
        status: mergedStatus,
      );
    }).where((listing) {
      return listing.status == ListingStatus.active;
    }).toList(growable: false);

    visible.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return visible;
  }

  List<BlockMarketStat> get unfilteredBlockStats => _blockStats
      .toList(growable: false)
    ..sort((a, b) => b.demandRatio.compareTo(a.demandRatio));

  /// My own listings — fetched from /api/listings/my
  List<ListingRecord> get myListings => List.unmodifiable(_myListings);

  /// Vault listings — all active listings (private or public) for the agent
  List<ListingRecord> get vaultListings {
    // Show ALL listings regardless of work area filter for the vault
    final all = _myListings.map((listing) {
      final mergedVisibility = _visibilityOverrides[listing.id] ?? listing.visibility;
      final mergedStatus = _archivedListingIds.contains(listing.id)
          ? ListingStatus.archived
          : listing.status;
      return listing.copyWith(visibility: mergedVisibility, status: mergedStatus);
    }).where((listing) {
      return listing.status == ListingStatus.active && listing.visibility == _vaultFilter;
    }).toList(growable: false);

    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all;
  }

  List<BlockMarketStat> get blockStats => _blockStats
      .where((stat) => _selectedWorkAreas.isEmpty || _selectedWorkAreas.contains(stat.blockName) || _selectedWorkAreas.contains(_inferArea(stat.blockName)))
      .toList(growable: false)
    ..sort((a, b) => b.demandRatio.compareTo(a.demandRatio));

  List<MatchLead> get matchLeads => _matchLeads;
  List<Request> get requests => _requests.where((r) => r.status == 'searching').toList(growable: false);

  /// Fetch the current agent's own listings
  Future<void> fetchMyListings() async {
    try {
      final data = await _repository.fetchAgentListings('');
      if (data.isNotEmpty) {
        _myListings
          ..clear()
          ..addAll(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching my listings: $e');
    }
  }

  /// Fetch the current agent's requests
  Future<void> fetchRequests() async {
    try {
      final data = await _repository.fetchMyRequests();
      if (data.isNotEmpty) {
        _requests
          ..clear()
          ..addAll(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
    }
  }

  /// Delete a request from local state and the database
  Future<void> deleteRequest(String id) async {
    try {
      await _repository.deleteRequest(id);
      _requests.removeWhere((r) => r.id == id);
      showToast('🗑 Request deleted');
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting request: $e');
      showToast('Failed to delete request');
    }
  }

  Future<void> _loadLeaderboard() async {
    try {
      final entries = await _repository.fetchLeaderboard();
      if (entries.isNotEmpty) {
        _leaderboard
          ..clear()
          ..addAll(entries);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
    }
  }

  void _bindStreams() {
    _listingsSub = _repository.watchListings().listen((data) {
      if (data.isNotEmpty) {
        _remoteListings
          ..clear()
          ..addAll(data);
        notifyListeners();
      }
    });

    _statsSub = _repository.watchBlockStats().listen((data) {
      if (data.isNotEmpty) {
        _blockStats
          ..clear()
          ..addAll(data);
        notifyListeners();
      }
    });

    _matchesSub = _repository.watchMatchLeads().listen((data) {
      if (data.isNotEmpty) {
        _matchLeads
          ..clear()
          ..addAll(data);

        if (data.first.id != _lastNotifiedMatchId) {
          _lastNotifiedMatchId = data.first.id;
          showToast('🎯 Match Found in ${data.first.blockName}. Tap to view.');
        }
      }
      notifyListeners();
    });
  }

  void setTabIndex(int value) {
    _tabIndex = value;
    if (value == 1) {
      // Vault tab selected — fetch my listings
      fetchMyListings();
    }
    notifyListeners();
  }

  void setVaultFilter(ListingVisibility value) {
    _vaultFilter = value;
    _showRequests = false;
    fetchMyListings();
    notifyListeners();
  }

  void setShowRequests(bool value) {
    _showRequests = value;
    notifyListeners();
  }

  void toggleWorkArea(String value) {
    if (_selectedWorkAreas.contains(value)) {
      _selectedWorkAreas.remove(value);
    } else {
      _selectedWorkAreas.add(value);
    }
    notifyListeners();
  }

  void setWorkAreas(Iterable<String> values) {
    _selectedWorkAreas
      ..clear()
      ..addAll(values);
    notifyListeners();
  }

  void markSold(String listingId) {
    _archivedListingIds.add(listingId);
    _repository.markListingSold(listingId);
    showToast('✅ Archived as sold.');
    fetchMyListings();
    notifyListeners();
  }

  void togglePublicPrivate(String listingId) {
    int listingIndex = _myListings.indexWhere((item) => item.id == listingId);
    if (listingIndex == -1) {
      listingIndex = _remoteListings.indexWhere((item) => item.id == listingId);
      if (listingIndex == -1) return;
    }

    final listing = _myListings.isNotEmpty && _myListings.any((l) => l.id == listingId)
        ? _myListings[listingIndex]
        : _remoteListings[listingIndex];
    final next = (_visibilityOverrides[listing.id] ?? listing.visibility) == ListingVisibility.private
        ? ListingVisibility.public
        : ListingVisibility.private;
    _visibilityOverrides[listing.id] = next;
    _repository.toggleListingVisibility(listingId, next == ListingVisibility.public);
    showToast('🔄 Switched to ${next.name.toUpperCase()}.');
    fetchMyListings();
    notifyListeners();
  }

  void showToast(String message) {
    _toastTimer?.cancel();
    _toastMessage = message;
    notifyListeners();

    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (_toastMessage == message) {
        _toastMessage = null;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _listingsSub?.cancel();
    _statsSub?.cancel();
    _matchesSub?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  String _inferArea(String blockName) {
    final lower = blockName.toLowerCase();
    if (lower.contains('13')) {
      return 'Gulshan';
    }
    if (lower.contains('9')) {
      return 'Scheme 33';
    }
    if (lower.contains('k')) {
      return 'North Karachi';
    }
    return 'North Nazimabad';
  }
}
