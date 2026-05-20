import 'package:flutter/foundation.dart';

@immutable
class ListingRecord {
  const ListingRecord({
    required this.id,
    required this.blockName,
    required this.priceLabel,
    required this.sizeLabel,
    required this.notesSnippet,
    required this.sublocation,
    required this.notes,
    this.latitude,
    this.longitude,
    required this.signalTone,
    required this.visibility,
    required this.status,
    required this.demandRatio,
    required this.workArea,
    required this.updatedAt,
    this.listedBy = 'Unknown',
    this.agencyName = 'Unknown Agency',
    this.contactNumber = '',
  });

  final String id;
  final String blockName;
  final String priceLabel;
  final String sizeLabel;
  final String notesSnippet;
  final String sublocation;
  final String notes;
  final double? latitude;
  final double? longitude;
  final ListingTone signalTone;
  final ListingVisibility visibility;
  final ListingStatus status;
  final double demandRatio;
  final String workArea;
  final DateTime updatedAt;
  final String listedBy;
  final String agencyName;
  final String contactNumber;

  bool get hasCoordinates => latitude != null && longitude != null;

  ListingRecord copyWith({
    String? id,
    String? blockName,
    String? priceLabel,
    String? sizeLabel,
    String? notesSnippet,
    String? sublocation,
    String? notes,
    double? latitude,
    double? longitude,
    ListingTone? signalTone,
    ListingVisibility? visibility,
    ListingStatus? status,
    double? demandRatio,
    String? workArea,
    DateTime? updatedAt,
    String? listedBy,
    String? agencyName,
    String? contactNumber,
  }) {
    return ListingRecord(
      id: id ?? this.id,
      blockName: blockName ?? this.blockName,
      priceLabel: priceLabel ?? this.priceLabel,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      notesSnippet: notesSnippet ?? this.notesSnippet,
      sublocation: sublocation ?? this.sublocation,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      signalTone: signalTone ?? this.signalTone,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      demandRatio: demandRatio ?? this.demandRatio,
      workArea: workArea ?? this.workArea,
      updatedAt: updatedAt ?? this.updatedAt,
      listedBy: listedBy ?? this.listedBy,
      agencyName: agencyName ?? this.agencyName,
      contactNumber: contactNumber ?? this.contactNumber,
    );
  }

  factory ListingRecord.fromJson(Map<String, dynamic> json) {
    return ListingRecord(
      id: '${json['id']}',
      blockName: (json['block_name'] ?? json['blockName'] ?? 'Block') as String,
      priceLabel: (json['price_label'] ?? json['priceLabel'] ?? '—') as String,
      sizeLabel: (json['size_label'] ?? json['sizeLabel'] ?? '—') as String,
      notesSnippet:
          (json['notes_snippet'] ?? json['notesSnippet'] ?? 'No notes')
              as String,
      sublocation:
          (json['sub_location'] ?? json['subLocation'] ?? '') as String,
      notes:
          (json['notes_full'] ?? json['notesFull'] ?? json['notes'] ?? '')
              as String,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      signalTone: ListingToneX.fromValue(
        (json['signal_tone'] ?? json['signalTone'] ?? 'standard') as String,
      ),
      visibility: ListingVisibilityX.fromValue(
        (json['visibility'] ?? 'private') as String,
      ),
      status: ListingStatusX.fromValue((json['status'] ?? 'active') as String),
      demandRatio: _toDouble(json['demand_ratio']) ?? 1.0,
      workArea: (json['work_area'] ?? json['workArea'] ?? 'Karachi') as String,
      updatedAt:
          DateTime.tryParse('${json['updated_at'] ?? json['updatedAt']}') ??
          DateTime.now(),
      listedBy: (json['listed_by'] ?? json['listedBy'] ?? 'Unknown') as String,
      agencyName:
          (json['agency_name'] ?? json['agencyName'] ?? 'Unknown Agency')
              as String,
      contactNumber:
          (json['contact_number'] ?? json['contactNumber'] ?? '') as String,
    );
  }
}

@immutable
class BlockMarketStat {
  const BlockMarketStat({
    required this.blockName,
    required this.latitude,
    required this.longitude,
    required this.demandRatio,
    required this.supplyRatio,
    required this.label,
  });

  final String blockName;
  final double latitude;
  final double longitude;
  final double demandRatio;
  final double supplyRatio;
  final String label;

  factory BlockMarketStat.fromJson(Map<String, dynamic> json) {
    return BlockMarketStat(
      blockName: (json['block_name'] ?? json['blockName'] ?? 'Block') as String,
      latitude: _toDouble(json['latitude']) ?? 24.8607,
      longitude: _toDouble(json['longitude']) ?? 67.0011,
      demandRatio: _toDouble(json['demand_ratio']) ?? 1.0,
      supplyRatio: _toDouble(json['supply_ratio']) ?? 1.0,
      label: (json['label'] ?? json['label_text'] ?? 'Demand') as String,
    );
  }
}

@immutable
class MatchLead {
  const MatchLead({
    required this.id,
    required this.sellerName,
    required this.buyerName,
    required this.blockName,
    required this.reasoningTrace,
    required this.summary,
    required this.phoneNumber,
    required this.agency,
    required this.createdAt,
  });

  final String id;
  final String sellerName;
  final String buyerName;
  final String blockName;
  final String reasoningTrace;
  final String summary;
  final String phoneNumber;
  final String agency;
  final DateTime createdAt;

  factory MatchLead.fromJson(Map<String, dynamic> json) {
    return MatchLead(
      id: '${json['id']}',
      sellerName:
          (json['seller_name'] ?? json['sellerName'] ?? 'Seller') as String,
      buyerName: (json['buyer_name'] ?? json['buyerName'] ?? 'Buyer') as String,
      blockName: (json['block_name'] ?? json['blockName'] ?? 'Block') as String,
      reasoningTrace:
          (json['reasoning_trace'] ??
                  json['reasoningTrace'] ??
                  'Reasoning: Match found using 15% budget flex. Property is West-Open as requested.')
              as String,
      summary:
          (json['summary'] ??
                  json['summary_text'] ??
                  'High-fit lead, best used as a premium call.')
              as String,
      phoneNumber:
          (json['phone_number'] ?? json['phoneNumber'] ?? '+92 300 1234567')
              as String,
      agency: (json['agency'] ?? 'Raabta Private Desk') as String,
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? json['createdAt']}') ??
          DateTime.now(),
    );
  }
}

@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.agency,
    required this.volumeLabel,
  });

  final int rank;
  final String name;
  final String agency;
  final String volumeLabel;
}

@immutable
class MarketPremium {
  const MarketPremium({required this.feature, required this.premiumLabel});

  final String feature;
  final String premiumLabel;
}

enum ListingTone { standard, newListing, hot }

enum ListingVisibility { private, public }

enum ListingStatus { active, archived }

extension ListingToneX on ListingTone {
  static ListingTone fromValue(String value) {
    switch (value.toLowerCase()) {
      case 'new':
      case 'newlisting':
        return ListingTone.newListing;
      case 'hot':
        return ListingTone.hot;
      default:
        return ListingTone.standard;
    }
  }
}

extension ListingVisibilityX on ListingVisibility {
  static ListingVisibility fromValue(String value) {
    switch (value.toLowerCase()) {
      case 'public':
        return ListingVisibility.public;
      default:
        return ListingVisibility.private;
    }
  }
}

extension ListingStatusX on ListingStatus {
  static ListingStatus fromValue(String value) {
    switch (value.toLowerCase()) {
      case 'archived':
      case 'sold':
        return ListingStatus.archived;
      default:
        return ListingStatus.active;
    }
  }
}

double? _toDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

class DashboardFixtures {
  static final List<ListingRecord> listings = [
    ListingRecord(
      id: 'lst_01',
      blockName: 'Block N',
      priceLabel: '4.2 Cr',
      sizeLabel: '120 Sq Yd',
      notesSnippet: 'Owner ready at 4.1, needs a fast close.',
      sublocation: 'Block N East',
      notes:
          'Owner ready at 4.1, needs a fast close. Contact via mobile; prefers cash deals.',
      latitude: 24.9366,
      longitude: 67.0493,
      signalTone: ListingTone.hot,
      visibility: ListingVisibility.private,
      status: ListingStatus.active,
      demandRatio: 2.4,
      workArea: 'North Nazimabad',
      updatedAt: DateTime(2026, 5, 18, 9, 10),
    ),
    ListingRecord(
      id: 'lst_02',
      blockName: 'Block 13D',
      priceLabel: '2.85 Cr',
      sizeLabel: '80 Sq Yd',
      notesSnippet: 'Fresh capture, green-lighted for public.',
      sublocation: '13D North',
      notes:
          'Fresh capture, green-lighted for public. Owner open to quick visits on weekends.',
      latitude: 24.9225,
      longitude: 67.1247,
      signalTone: ListingTone.newListing,
      visibility: ListingVisibility.public,
      status: ListingStatus.active,
      demandRatio: 1.7,
      workArea: 'Gulshan',
      updatedAt: DateTime(2026, 5, 18, 11, 15),
    ),
    ListingRecord(
      id: 'lst_03',
      blockName: 'Block K',
      priceLabel: '7.9 Cr',
      sizeLabel: '240 Sq Yd',
      notesSnippet: 'Premium corner plot with west-open edge.',
      sublocation: 'K Sector Corner',
      notes:
          'Premium corner plot with west-open edge. Documents clear; preferred serious buyers only.',
      latitude: 24.945,
      longitude: 67.072,
      signalTone: ListingTone.standard,
      visibility: ListingVisibility.private,
      status: ListingStatus.active,
      demandRatio: 2.15,
      workArea: 'North Karachi',
      updatedAt: DateTime(2026, 5, 17, 17, 40),
    ),
    ListingRecord(
      id: 'lst_04',
      blockName: 'Block 9',
      priceLabel: '1.95 Cr',
      sizeLabel: '75 Sq Yd',
      notesSnippet: 'Buyer asked for possession within 30 days.',
      sublocation: 'Block 9 South',
      notes:
          'Buyer asked for possession within 30 days. Tenant occupied, needs 2-week notice.',
      latitude: 24.895,
      longitude: 67.13,
      signalTone: ListingTone.hot,
      visibility: ListingVisibility.public,
      status: ListingStatus.active,
      demandRatio: 2.8,
      workArea: 'Scheme 33',
      updatedAt: DateTime(2026, 5, 18, 8, 5),
    ),
    ListingRecord(
      id: 'lst_05',
      blockName: 'Block M',
      priceLabel: '5.4 Cr',
      sizeLabel: '160 Sq Yd',
      notesSnippet: 'Negotiable if the buyer skips financing.',
      sublocation: 'Block M West',
      notes:
          'Negotiable if the buyer skips financing. Seller prefers deal closure within 45 days.',
      latitude: 24.929,
      longitude: 67.058,
      signalTone: ListingTone.newListing,
      visibility: ListingVisibility.private,
      status: ListingStatus.active,
      demandRatio: 1.3,
      workArea: 'North Nazimabad',
      updatedAt: DateTime(2026, 5, 18, 13, 0),
    ),
    ListingRecord(
      id: 'lst_06',
      blockName: 'Block L',
      priceLabel: '3.1 Cr',
      sizeLabel: '100 Sq Yd',
      notesSnippet: 'Archived lead, keep in CRM only.',
      sublocation: 'Block L Near Park',
      notes:
          'Archived lead, keep in CRM only. Seller decided to postpone listing.',
      latitude: 24.913,
      longitude: 67.086,
      signalTone: ListingTone.standard,
      visibility: ListingVisibility.private,
      status: ListingStatus.archived,
      demandRatio: 0.9,
      workArea: 'Gulistan-e-Johar',
      updatedAt: DateTime(2026, 5, 16, 15, 20),
    ),
  ];

  static final List<BlockMarketStat> blockStats = [
    BlockMarketStat(
      blockName: 'Block N',
      latitude: 24.9366,
      longitude: 67.0493,
      demandRatio: 2.4,
      supplyRatio: 0.9,
      label: 'Demand Spike',
    ),
    BlockMarketStat(
      blockName: 'Block 13D',
      latitude: 24.9225,
      longitude: 67.1247,
      demandRatio: 1.7,
      supplyRatio: 1.2,
      label: 'Balanced',
    ),
    BlockMarketStat(
      blockName: 'Block K',
      latitude: 24.945,
      longitude: 67.072,
      demandRatio: 2.15,
      supplyRatio: 0.8,
      label: 'Hot Zone',
    ),
    BlockMarketStat(
      blockName: 'Block 9',
      latitude: 24.895,
      longitude: 67.13,
      demandRatio: 2.8,
      supplyRatio: 0.7,
      label: 'Overheated',
    ),
  ];

  static final List<MatchLead> matchLeads = [
    MatchLead(
      id: 'msg_01',
      sellerName: 'Ahmed',
      buyerName: 'You',
      blockName: 'Block N',
      reasoningTrace:
          'Reasoning: Match found using 15% budget flex. Property is West-Open as requested.',
      summary: 'Seller needs a clean close this week. Move fast.',
      phoneNumber: '+92 300 1234567',
      agency: 'Raabta Private Desk',
      createdAt: DateTime(2026, 5, 18, 12, 44),
    ),
    MatchLead(
      id: 'msg_02',
      sellerName: 'Usman',
      buyerName: 'You',
      blockName: 'Block 13D',
      reasoningTrace:
          'Reasoning: Demand circle is active and the seller accepted your size band.',
      summary: 'Negotiation window is open. Connect before noon.',
      phoneNumber: '+92 321 8765432',
      agency: 'North Star Realty',
      createdAt: DateTime(2026, 5, 18, 10, 20),
    ),
    MatchLead(
      id: 'msg_03',
      sellerName: 'Bilal',
      buyerName: 'You',
      blockName: 'Block K',
      reasoningTrace:
          'Reasoning: Budget flex and corner preference intersect with current inventory.',
      summary: 'High-fit lead, best used as a premium call.',
      phoneNumber: '+92 333 4445566',
      agency: 'Metro Properties',
      createdAt: DateTime(2026, 5, 17, 18, 30),
    ),
  ];

  static final List<LeaderboardEntry> leaderboard = [
    LeaderboardEntry(
      rank: 1,
      name: 'Hassan Ali',
      agency: 'Prime Link',
      volumeLabel: '128 deals',
    ),
    LeaderboardEntry(
      rank: 2,
      name: 'Sana Khan',
      agency: 'Urban Grid',
      volumeLabel: '115 deals',
    ),
    LeaderboardEntry(
      rank: 3,
      name: 'Adeel Raza',
      agency: 'Karachi Keys',
      volumeLabel: '103 deals',
    ),
    LeaderboardEntry(
      rank: 4,
      name: 'Mariam Shah',
      agency: 'Harbor Estate',
      volumeLabel: '97 deals',
    ),
    LeaderboardEntry(
      rank: 5,
      name: 'Fahad Noor',
      agency: 'Block Pulse',
      volumeLabel: '92 deals',
    ),
    LeaderboardEntry(
      rank: 6,
      name: 'Zain Abbas',
      agency: 'Axis Realty',
      volumeLabel: '87 deals',
    ),
    LeaderboardEntry(
      rank: 7,
      name: 'Aisha Karim',
      agency: 'Neon Properties',
      volumeLabel: '81 deals',
    ),
    LeaderboardEntry(
      rank: 8,
      name: 'Saad Javed',
      agency: 'DealCraft',
      volumeLabel: '77 deals',
    ),
    LeaderboardEntry(
      rank: 9,
      name: 'Noor Fatima',
      agency: 'Harbor Lane',
      volumeLabel: '69 deals',
    ),
    LeaderboardEntry(
      rank: 10,
      name: 'Hamza Tariq',
      agency: 'Metro Pulse',
      volumeLabel: '64 deals',
    ),
  ];

  static final List<MarketPremium> premiums = [
    MarketPremium(feature: 'Corner', premiumLabel: '+12%'),
    MarketPremium(feature: 'Park Facing', premiumLabel: '+8%'),
    MarketPremium(feature: 'West Open', premiumLabel: '+5%'),
    MarketPremium(feature: 'Main Road', premiumLabel: '+15%'),
  ];

  static final List<String> workAreas = [
    'North Nazimabad',
    'Gulshan',
    'Scheme 33',
    'North Karachi',
    'Gulistan-e-Johar',
  ];
}
