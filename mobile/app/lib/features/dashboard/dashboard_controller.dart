import 'dart:async';

import 'package:flutter/foundation.dart';

import 'dashboard_models.dart';
import 'dashboard_repository.dart';

class DashboardController extends ChangeNotifier {
  DashboardController(this._repository) {
    _selectedWorkAreas.addAll(_repository.getWorkAreas());
    _bindStreams();
    _loadLeaderboard();
  }

  final DashboardRepository _repository;
  final List<ListingRecord> _remoteListings = [];
  final List<BlockMarketStat> _blockStats = [];
  final List<MatchLead> _matchLeads = [];
  final List<LeaderboardEntry> _leaderboard = [];
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

  int get tabIndex => _tabIndex;
  ListingVisibility get vaultFilter => _vaultFilter;
  String? get toastMessage => _toastMessage;
  List<String> get availableWorkAreas => _repository.getWorkAreas();
  Set<String> get selectedWorkAreas => Set.unmodifiable(_selectedWorkAreas);
  List<LeaderboardEntry> get leaderboard => List.unmodifiable(_leaderboard);
  List<MarketPremium> get premiums => _repository.getPremiums();

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

  List<ListingRecord> get vaultListings {
    final filtered = listings
        .where((listing) => listing.visibility == _vaultFilter)
        .toList(growable: false);
    return filtered;
  }

  List<BlockMarketStat> get blockStats => _blockStats
      .where((stat) => _selectedWorkAreas.isEmpty || _selectedWorkAreas.contains(stat.blockName) || _selectedWorkAreas.contains(_inferArea(stat.blockName)))
      .toList(growable: false)
    ..sort((a, b) => b.demandRatio.compareTo(a.demandRatio));

  List<MatchLead> get matchLeads => _matchLeads;

  Future<void> _loadLeaderboard() async {
    try {
      final entries = await _repository.fetchLeaderboard();
      _leaderboard
        ..clear()
        ..addAll(entries);
      notifyListeners();
    } catch (e) {
      // Keep using empty list or fixtures
    }
  }

  void _bindStreams() {
    _listingsSub = _repository.watchListings().listen((data) {
      _remoteListings
        ..clear()
        ..addAll(data);
      notifyListeners();
    });

    _statsSub = _repository.watchBlockStats().listen((data) {
      _blockStats
        ..clear()
        ..addAll(data);
      notifyListeners();
    });

    _matchesSub = _repository.watchMatchLeads().listen((data) {
      _matchLeads
        ..clear()
        ..addAll(data);

      if (data.isNotEmpty && data.first.id != _lastNotifiedMatchId) {
        _lastNotifiedMatchId = data.first.id;
        showToast('🎯 Match Found in ${data.first.blockName}. Tap to view.');
      }

      notifyListeners();
    });
  }

  void setTabIndex(int value) {
    _tabIndex = value;
    notifyListeners();
  }

  void setVaultFilter(ListingVisibility value) {
    _vaultFilter = value;
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
    showToast('Archived as sold.');
    notifyListeners();
  }

  void togglePublicPrivate(String listingId) {
    final listingIndex = _remoteListings.indexWhere((item) => item.id == listingId);
    if (listingIndex == -1) {
      return;
    }

    final listing = _remoteListings[listingIndex];
    final next = (_visibilityOverrides[listing.id] ?? listing.visibility) == ListingVisibility.private
        ? ListingVisibility.public
        : ListingVisibility.private;
    _visibilityOverrides[listing.id] = next;
    showToast('Switched to ${next.name.toUpperCase()}.');
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
