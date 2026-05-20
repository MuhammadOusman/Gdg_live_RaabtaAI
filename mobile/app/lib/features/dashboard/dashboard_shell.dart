import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../match/match_chat_screen.dart';

import '../../app/app_theme.dart';
import '../../models/request.dart';
import 'dashboard_controller.dart';
import 'dashboard_models.dart';
import 'listing_card.dart';

class RaabtaDashboardShell extends StatelessWidget {
  const RaabtaDashboardShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: const [_TabHost(), _FloatingToast(), _BottomNavShell()],
      ),
    );
  }
}

class _TabHost extends StatelessWidget {
  const _TabHost();

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardController>(
      builder: (context, controller, _) {
        return IndexedStack(
          index: controller.tabIndex,
          children: const [
            PulseMapScreen(),
            VaultScreen(),
            // Match tab now uses the chat interface
            // ignore: prefer_const_constructors
            MatchChatScreen(),
            InsightsScreen(),
          ],
        );
      },
    );
  }
}

class _FloatingToast extends StatelessWidget {
  const _FloatingToast();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Consumer<DashboardController>(
          builder: (context, controller, _) {
            final message = controller.toastMessage;
            return AnimatedOpacity(
              opacity: message == null ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              child: AnimatedSlide(
                offset: message == null ? const Offset(0, -0.18) : Offset.zero,
                duration: const Duration(milliseconds: 240),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14171D).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: RaabtaTheme.emeraldGreen.withValues(
                            alpha: 0.16,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Text(
                      message ?? '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BottomNavShell extends StatelessWidget {
  const _BottomNavShell();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Consumer<DashboardController>(
                builder: (context, controller, _) {
                  final items = <({IconData icon, String label})>[
                    (icon: Icons.waves_rounded, label: 'Pulse'),
                    (icon: Icons.vpn_key_rounded, label: 'Vault'),
                    (icon: Icons.auto_graph_rounded, label: 'Match'),
                    (icon: Icons.insights_rounded, label: 'Intel'),
                  ];

                  return SizedBox(
                    height: 52,
                    child: Row(
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        final selected = controller.tabIndex == index;
                        return Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => controller.setTabIndex(index),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 20,
                                    color: selected
                                        ? RaabtaTheme.electricBlue
                                        : Colors.white70,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: selected
                                              ? Colors.white
                                              : Colors.white70,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PulseMapScreen extends StatefulWidget {
  const PulseMapScreen({super.key});

  @override
  State<PulseMapScreen> createState() => _PulseMapScreenState();
}

class _PulseMapScreenState extends State<PulseMapScreen> {
  GoogleMapController? _googleMapController;
  ListingRecord? _selectedListing;
  bool _hasInitialZoom = false;

  static const CameraPosition _kKarachi = CameraPosition(
    target: LatLng(24.91, 67.08),
    zoom: 12.2,
  );

  void _zoomToWorkAreas(DashboardController controller) {
    if (_googleMapController == null || controller.selectedWorkAreas.isEmpty) {
      return;
    }

    late final LatLngBounds bounds;

    // Check if we have listings in selected work areas to zoom to
    final filteredListings = controller.listings
        .where((l) => l.hasCoordinates)
        .toList();

    if (filteredListings.isNotEmpty) {
      double minLat = filteredListings.first.latitude!;
      double maxLat = filteredListings.first.latitude!;
      double minLng = filteredListings.first.longitude!;
      double maxLng = filteredListings.first.longitude!;

      for (final l in filteredListings) {
        if (l.latitude! < minLat) minLat = l.latitude!;
        if (l.latitude! > maxLat) maxLat = l.latitude!;
        if (l.longitude! < minLng) minLng = l.longitude!;
        if (l.longitude! > maxLng) maxLng = l.longitude!;
      }

      bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
    } else {
      // Fallback to block centroids if no listings found
      final areas = controller.selectedWorkAreas;
      final coords = areas.map((a) {
        if (a.contains('Nazimabad')) return const LatLng(24.93, 67.04);
        if (a.contains('PECHS')) return const LatLng(24.87, 67.05);
        if (a.contains('Gulshan')) return const LatLng(24.91, 67.10);
        if (a.contains('Scheme 33')) return const LatLng(24.95, 67.12);
        return const LatLng(24.91, 67.08); // Default Karachi
      }).toList();

      double minLat = coords.first.latitude;
      double maxLat = coords.first.latitude;
      double minLng = coords.first.longitude;
      double maxLng = coords.first.longitude;

      for (final c in coords) {
        if (c.latitude < minLat) minLat = c.latitude;
        if (c.latitude > maxLat) maxLat = c.latitude;
        if (c.longitude < minLng) minLng = c.longitude;
        if (c.longitude > maxLng) maxLng = c.longitude;
      }

      bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
    }

    _googleMapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
    setState(() {
      _hasInitialZoom = true;
    });
  }

  static const String _darkMapStyleJson = r'''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#14171d"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8ec3b9"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1a1c22"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#4b5366"
      }
    ]
  },
  {
    "featureType": "landscape",
    "stylers": [
      {
        "color": "#14171d"
      }
    ]
  },
  {
    "featureType": "poi",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1a1e27"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#212733"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#2c3344"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#3b4458"
      }
    ]
  },
  {
    "featureType": "transit",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0d1b2a"
      }
    ]
  }
]
''';

  @override
  void dispose() {
    _googleMapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardController>(
      builder: (context, controller, _) {
        // Build interactive markers from listings
        final Set<Marker> myMarkers = controller.unfilteredListings
            .where((listing) => listing.hasCoordinates)
            .map((listing) {
              final matchesFilter =
                  controller.selectedWorkAreas.isEmpty ||
                  controller.selectedWorkAreas.contains(listing.workArea);

              // Style markers of selected work areas with colorful hues, and others with a grey/slate hue
              double markerHue = 200.0; // Slate-grey for greyed out areas
              if (matchesFilter) {
                if (listing.demandRatio >= 2.0) {
                  markerHue = BitmapDescriptor.hueRed;
                } else if (listing.blockName.contains('H') ||
                    listing.blockName.contains('15')) {
                  markerHue = BitmapDescriptor.hueGreen;
                } else if (listing.blockName.contains('N')) {
                  markerHue = BitmapDescriptor.hueYellow;
                } else {
                  markerHue = BitmapDescriptor.hueAzure;
                }
              }

              return Marker(
                markerId: MarkerId(listing.id),
                position: LatLng(listing.latitude!, listing.longitude!),
                icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
                alpha: matchesFilter ? 1.0 : 0.45,
                infoWindow: InfoWindow(
                  title: '${listing.blockName} • ${listing.priceLabel}',
                  snippet: listing.notesSnippet,
                ),
                onTap: () {
                  setState(() {
                    _selectedListing = listing;
                  });
                  final wasFiltered = controller.selectedWorkAreas.isNotEmpty;
                  if (wasFiltered && !matchesFilter) {
                    controller.setWorkAreas([listing.workArea]);
                    controller.showToast('Focused on ${listing.workArea}');
                  } else {
                    controller.showToast(
                      '${listing.blockName} • ${listing.priceLabel} Selected',
                    );
                  }
                },
              );
            })
            .toSet();

        // Build premium demand heatmap circles based on block statistics
        final Set<Circle>
        demandHeatmapCircles = controller.unfilteredBlockStats.map((stat) {
          String inferredArea = 'North Nazimabad';
          final name = stat.blockName.toLowerCase();
          if (name.contains('13d') || name.contains('gulshan')) {
            inferredArea = 'Gulshan';
          } else if (name.contains('9') || name.contains('scheme')) {
            inferredArea = 'Scheme 33';
          } else if (name.contains('k') || name.contains('north karachi')) {
            inferredArea = 'North Karachi';
          } else if (name.contains('pechs')) {
            inferredArea = 'PECHS';
          } else if (name.contains('nazimabad block 3')) {
            inferredArea = 'Nazimabad';
          }

          final matchesFilter =
              controller.selectedWorkAreas.isEmpty ||
              controller.selectedWorkAreas.contains(inferredArea);

          // Beautiful geographic clustering centers for key blocks in Karachi
          double lat = 24.91;
          double lng = 67.10;
          if (stat.blockName.contains('Nazimabad')) {
            lat = 24.93;
            lng = 67.04;
          } else if (stat.blockName.contains('PECHS')) {
            lat = 24.87;
            lng = 67.05;
          } else if (stat.blockName.contains('Gulshan')) {
            lat = 24.91;
            lng = 67.10;
          } else if (stat.blockName.contains('Scheme 33')) {
            lat = 24.95;
            lng = 67.12;
          }

          final Color circleColor = matchesFilter
              ? RaabtaTheme.emeraldGreen.withValues(alpha: 0.16)
              : Colors.grey.withValues(alpha: 0.05);

          final Color strokeColor = matchesFilter
              ? RaabtaTheme.emeraldGreen.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.1);

          return Circle(
            circleId: CircleId(stat.blockName),
            center: LatLng(lat, lng),
            radius: 350.0 * (stat.demandRatio / 2.0).clamp(0.5, 4.0),
            fillColor: circleColor,
            strokeColor: strokeColor,
            strokeWidth: 2,
          );
        }).toSet();

        return Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: _kKarachi,
                onMapCreated: (googleController) {
                  _googleMapController = googleController;
                  if (!_hasInitialZoom) {
                    _zoomToWorkAreas(controller);
                  }
                },
                style: _darkMapStyleJson,
                markers: myMarkers,
                circles: demandHeatmapCircles,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),
            // Search bar + filter pill
            Positioned(
              top: 20,
              left: 16,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: _GlassPanel(
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search blocks, listings, sellers',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        fit: FlexFit.loose,
                        child: _FilterPill(
                          label: controller.selectedWorkAreas.isEmpty
                              ? 'All Work Areas'
                              : controller.selectedWorkAreas.join(' • '),
                          onTap: () => _openWorkAreaSheet(context, controller),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ), // Selected listing details
            if (_selectedListing != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 92,
                child: _MapDetailsPanel(
                  listing: _selectedListing!,
                  onCopy: () async {
                    final number = _selectedListing!.contactNumber.trim();
                    if (number.isEmpty) {
                      controller.showToast('No contact number available');
                      return;
                    }
                    await Clipboard.setData(ClipboardData(text: number));
                    controller.showToast('Number copied');
                  },
                  onClose: () {
                    setState(() {
                      _selectedListing = null;
                    });
                  },
                ),
              ),
            // Legend
            Positioned(
              left: 16,
              bottom: _selectedListing != null ? 300 : 140,
              child: Wrap(
                direction: Axis.vertical,
                spacing: 6,
                children: const [
                  _LegendPill(color: RaabtaTheme.electricBlue, label: 'Plot'),
                  _LegendPill(color: RaabtaTheme.emeraldGreen, label: 'New'),
                  _LegendPill(color: RaabtaTheme.softGold, label: 'Hot'),
                  _LegendPill(
                    color: RaabtaTheme.signalRed,
                    label: 'Demand > 2.0',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openWorkAreaSheet(
    BuildContext context,
    DashboardController controller,
  ) async {
    final selected = controller.selectedWorkAreas.toSet();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: RaabtaTheme.charcoal.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Work Areas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Multi-select Karachi blocks to personalize the map and CRM views.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: controller.availableWorkAreas
                        .map((area) {
                          final isSelected = selected.contains(area);
                          return FilterChip(
                            label: Text(area),
                            selected: isSelected,
                            onSelected: (value) {
                              setModalState(() {
                                if (value) {
                                  selected.add(area);
                                } else {
                                  selected.remove(area);
                                }
                              });
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            selected.clear();
                            setModalState(() {});
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            controller.setWorkAreas(selected);
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MapDetailsPanel extends StatelessWidget {
  const _MapDetailsPanel({
    required this.listing,
    required this.onCopy,
    required this.onClose,
  });

  final ListingRecord listing;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${listing.blockName} | ${listing.priceLabel}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Color(0xFF374151)),
              ),
            ],
          ),
          Text(
            '${listing.sizeLabel}${listing.sublocation.isEmpty ? '' : ' | ${listing.sublocation}'}',
            style: const TextStyle(color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Text(
            'Listed by: ${listing.listedBy}',
            style: const TextStyle(color: Color(0xFF111827)),
          ),
          Text(
            'Agency: ${listing.agencyName}',
            style: const TextStyle(color: Color(0xFF111827)),
          ),
          Text(
            'Number: ${listing.contactNumber.isEmpty ? 'N/A' : listing.contactNumber}',
            style: const TextStyle(color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Text(
            listing.notes.isEmpty ? 'No notes' : listing.notes,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy Number'),
            ),
          ),
        ],
      ),
    );
  }
}

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 72, 16, 96),
        child: Consumer<DashboardController>(
          builder: (context, controller, _) {
            final showReqs = controller.showRequests;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The Vault',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  showReqs
                      ? 'Swipe right to delete a request.'
                      : 'Swipe right to archive as sold. Swipe left to flip public/private.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                _VaultTabs(
                  selected: showReqs
                      ? 2
                      : (controller.vaultFilter == ListingVisibility.private
                            ? 0
                            : 1),
                  onTab: (index) {
                    if (index == 0) {
                      controller.setVaultFilter(ListingVisibility.private);
                    } else if (index == 1) {
                      controller.setVaultFilter(ListingVisibility.public);
                    } else {
                      controller.setShowRequests(true);
                      controller.fetchRequests();
                    }
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: showReqs
                      ? _buildRequestsList(controller)
                      : _buildListingsList(controller),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildListingsList(DashboardController controller) {
    final items = controller.vaultFilter == ListingVisibility.private
        ? controller.vaultListings
              .where((l) => l.visibility == ListingVisibility.private)
              .toList(growable: false)
        : controller.vaultListings
              .where((l) => l.visibility == ListingVisibility.public)
              .toList(growable: false);

    if (items.isEmpty) {
      return const _EmptyState(
        title: 'Nothing here yet',
        subtitle:
            'Try widening your work-area filter or import a private lead.',
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final listing = items[index];
        return Dismissible(
          key: ValueKey(listing.id),
          background: const _DismissBackground(
            color: RaabtaTheme.emeraldGreen,
            icon: Icons.archive_rounded,
            label: 'SOLD',
            alignment: Alignment.centerLeft,
          ),
          secondaryBackground: _DismissBackground(
            color: RaabtaTheme.electricBlue,
            icon: Icons.visibility_rounded,
            label: listing.visibility == ListingVisibility.private
                ? 'PUBLIC'
                : 'PRIVATE',
            alignment: Alignment.centerRight,
          ),
          onDismissed: (direction) {
            if (direction == DismissDirection.startToEnd) {
              controller.markSold(listing.id);
            } else {
              controller.togglePublicPrivate(listing.id);
            }
          },
          child: ListingCard(
            listing: listing,
            trailing: _VisibilityBadge(value: listing.visibility),
          ),
        );
      },
    );
  }

  Widget _buildRequestsList(DashboardController controller) {
    final items = controller.requests;

    if (items.isEmpty) {
      return const _EmptyState(
        title: 'No active requests',
        subtitle: 'Your searching requests will appear here.',
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final req = items[index];
        return Dismissible(
          key: ValueKey(req.id),
          direction: DismissDirection.startToEnd,
          background: const _DismissBackground(
            color: RaabtaTheme.signalRed,
            icon: Icons.delete_rounded,
            label: 'DELETE',
            alignment: Alignment.centerLeft,
          ),
          onDismissed: (_) => controller.deleteRequest(req.id),
          child: _RequestCard(request: req),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final Request request;

  @override
  Widget build(BuildContext context) {
    final blocks = request.targetBlocks.join(', ');
    final features = request.targetFeatures.isNotEmpty
        ? request.targetFeatures.join(', ')
        : null;
    final budget = request.maxBudget != null
        ? _formatBigInt(request.maxBudget!)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RaabtaTheme.electricBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: RaabtaTheme.electricBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  blocks.isNotEmpty ? blocks : 'Any block',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (request.targetSize != null)
                _InfoChip(label: '${request.targetSize} ${request.unit}'),
              if (budget != null) _InfoChip(label: budget),
              _InfoChip(label: request.status),
            ],
          ),
          if (features != null) ...[
            const SizedBox(height: 8),
            Text(
              '✨ $features',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatBigInt(int amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    }
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)} Lakh';
    return '$amount';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _VaultTabs extends StatelessWidget {
  const _VaultTabs({required this.selected, required this.onTab});

  final int selected;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'PVT',
              icon: Icons.vpn_key_rounded,
              selected: selected == 0,
              onTap: () => onTab(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              label: 'PUB',
              icon: Icons.storefront_rounded,
              selected: selected == 1,
              onTap: () => onTab(1),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              label: 'REQ',
              icon: Icons.search_rounded,
              selected: selected == 2,
              onTap: () => onTab(2),
            ),
          ),
        ],
      ),
    );
  }
}

class MatchFeedScreen extends StatelessWidget {
  const MatchFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 72, 16, 96),
        child: Consumer<DashboardController>(
          builder: (context, controller, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match Center',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'AI-powered connections between sellers and buyers.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: controller.matchLeads.isEmpty
                        ? 1
                        : controller.matchLeads.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (controller.matchLeads.isEmpty) {
                        return const _EmptyState(
                          title: 'No matches yet',
                          subtitle:
                              'Realtime notifications will appear here as the engine finds fit.',
                        );
                      }

                      return _MatchCard(lead: controller.matchLeads[index]);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MatchCard extends StatefulWidget {
  const _MatchCard({required this.lead});

  final MatchLead lead;

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Connection: ${widget.lead.sellerName} (Seller) ↔ You (Buyer)',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lead.reasoningTrace,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.lead.summary,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.lead.agency,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _revealed = true;
                  });
                },
                icon: const Icon(Icons.call_rounded),
                label: Text(_revealed ? widget.lead.phoneNumber : 'Connect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 72, 16, 96),
        child: Consumer<DashboardController>(
          builder: (context, controller, _) {
            return ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Market Insights',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        controller.fetchIntelAnalytics();
                        controller.fetchRecommendations();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Radar-grade signals for demand, pricing, and agent performance.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 18),
                if (controller.intelLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (controller.intelError != null &&
                    controller.intelError!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Intel error: ${controller.intelError}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                    ),
                  ),
                if (controller.intelLoading || (controller.intelError != null))
                  const SizedBox(height: 18),
                _SectionCard(
                  title: 'AI Recommendations',
                  subtitle: 'Generated by Recommender agent for your listings.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            controller.fetchRecommendations(runAgent: true);
                          },
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Run Recommender'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (controller.recommendations.isEmpty)
                        Text(
                          'No recommendations yet. Run recommender to generate insights.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        )
                      else
                        Column(
                          children: controller.recommendations
                              .take(6)
                              .map(
                                (rec) => Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    rec.message,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _PanelCard(
                        title: 'Hot Props',
                        subtitle: 'Active flagged',
                        child: _RadialGauge(
                          value: (controller.intelHotPropertiesCount * 8)
                              .clamp(10, 100)
                              .toDouble(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PanelCard(
                        title: 'Velocity',
                        subtitle: 'Avg days',
                        child: _RadialGauge(
                          value: ((controller.intelAvgVelocityDays ?? 0) * 3)
                              .clamp(20, 100)
                              .toDouble(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Demand vs Supply',
                  subtitle: 'Top block pressure ratios.',
                  child: Column(
                    children: controller.demandVsSupply
                        .take(5)
                        .map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${row['block_id'] ?? 'Block'}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  'D:${row['demand'] ?? 0} / S:${row['supply'] ?? 0}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Price Stats',
                  subtitle: 'Median and average by block.',
                  child: Column(
                    children: controller.priceStats
                        .take(5)
                        .map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${row['block_id'] ?? 'Block'} (${row['unit'] ?? ''})',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  'Avg ${row['avg_price'] ?? '-'}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Networking Leaderboard',
                  subtitle: 'Top 10 agents by deal volume.',
                  child: Column(
                    children: controller.leaderboard
                        .map((entry) => _LeaderboardRow(entry: entry))
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Corner Premium',
                  subtitle: 'Block-wise premium indicators.',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: controller.cornerPremium
                        .map(
                          (premium) => _PremiumPill(
                            feature: '${premium['block_id'] ?? 'Block'}',
                            premium: '${premium['corner_premium_pct'] ?? 0}%',
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Geofencing / Profile Filters',
                  subtitle:
                      'Multi-select Karachi blocks to personalize the live map.',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: controller.availableWorkAreas
                        .map(
                          (area) => FilterChip(
                            selected: controller.selectedWorkAreas.contains(
                              area,
                            ),
                            label: Text(area),
                            onSelected: (_) => controller.toggleWorkArea(area),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      subtitle: subtitle,
      child: SizedBox(height: 176, child: child),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _RadialGauge extends StatelessWidget {
  const _RadialGauge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadialGaugePainter(value: value),
      child: Center(
        child: Text(
          '${value.toStringAsFixed(0)}%',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: RaabtaTheme.electricBlue.withValues(alpha: 0.2),
            child: Text(
              '${entry.rank}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.agency,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
          Text(
            entry.volumeLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: RaabtaTheme.softGold),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.person_add_alt_1_rounded,
            color: Colors.white70,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _PremiumPill extends StatelessWidget {
  const _PremiumPill({required this.feature, required this.premium});

  final String feature;
  final String premium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        '$feature $premium',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.value});

  final ListingVisibility value;

  @override
  Widget build(BuildContext context) {
    final color = value == ListingVisibility.public
        ? RaabtaTheme.emeraldGreen
        : RaabtaTheme.electricBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value.name.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        children: alignment == Alignment.centerLeft
            ? [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ]
            : [
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: color),
              ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? RaabtaTheme.electricBlue.withValues(alpha: 0.18)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: RaabtaTheme.electricBlue.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: RaabtaTheme.electricBlue.withValues(alpha: 0.28),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  _RadialGaugePainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.32;

    final background = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    final progress = Paint()
      ..shader = SweepGradient(
        colors: [
          RaabtaTheme.electricBlue,
          RaabtaTheme.emeraldGreen,
          RaabtaTheme.softGold,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, background);
    final sweep = (value.clamp(0, 100) / 100) * (math.pi * 2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progress,
    );

    final inner = Paint()
      ..color = Colors.black.withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 16, inner);
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) =>
      oldDelegate.value != value;
}
