import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/places_api.dart';
import '../screens/posts_screen.dart';
import 'create_post_sheet.dart';
import 'weather_sheet.dart';

// Categories considered "interesting waypoints" during navigation
const _waypointCategories = {
  'peak', 'lake', 'cave', 'cave_entrance', 'ruin', 'spring', 'viewpoint',
};

class PlacesLayer extends StatefulWidget {
  final MapController mapController;
  final PlacesApi api;
  final int limit;
  final Set<String> selectedCategories;
  final int? minElevation;
  final int? maxElevation;
  final double? maxDistanceKm;
  final LatLng? currentLocation;
  final bool showLocations;
  final bool isAdmin;
  final Function(Place)? onNavigate;
  final List<LatLng> routePolyline;
  final Function(List<Place>)? onRouteWaypointsChanged;

  const PlacesLayer({
    super.key,
    required this.mapController,
    required this.api,
    this.limit = 1000,
    this.selectedCategories = const {},
    this.minElevation,
    this.maxElevation,
    this.maxDistanceKm,
    this.currentLocation,
    this.showLocations = true,
    this.isAdmin = false,
    this.onNavigate,
    this.routePolyline = const [],
    this.onRouteWaypointsChanged,
  });

  @override
  State<PlacesLayer> createState() => PlacesLayerState();
}

class PlacesLayerState extends State<PlacesLayer> {
  StreamSubscription<MapEvent>? _sub;
  Timer? _debounce;

  // Accumulating cache: places are added but never removed mid-session.
  // This prevents markers from flickering/disappearing during zoom or pan.
  final Map<String, Place> _cache = {};

  bool _loading = false;
  Object? _lastError;

  Place? _selected;

  static const int _maxCacheSize = 4000;

  // Area already covered by the last successful fetch (including padding) and
  // when it happened. While navigating, the camera follows the user and fires
  // MoveEnd every second — without this check the app refetched places every
  // second, which made it constantly lag.
  LatLngBounds? _coveredBounds;
  DateTime? _lastFetchAt;
  static const _refetchTtl = Duration(minutes: 3);

  // Tracks the last set of waypoint IDs sent via the callback so we only fire
  // when the list actually changes.
  List<String> _lastWaypointIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNow());
    _sub = widget.mapController.mapEventStream.listen((ev) {
      if (ev is MapEventMoveEnd ||
          ev is MapEventRotateEnd ||
          ev is MapEventFlingAnimationEnd ||
          ev is MapEventDoubleTapZoomEnd) {
        _scheduleReload();
      }
    });
  }

  @override
  void didUpdateWidget(PlacesLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-evaluate waypoints when the route polyline is set or cleared.
    if (oldWidget.routePolyline != widget.routePolyline) {
      _notifyWaypoints();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _notifyWaypoints() {
    final cb = widget.onRouteWaypointsChanged;
    if (cb == null) return;
    if (widget.routePolyline.isEmpty) {
      if (_lastWaypointIds.isNotEmpty) {
        _lastWaypointIds = [];
        cb([]);
      }
      return;
    }
    final waypoints = _cache.values
        .where((p) =>
            _waypointCategories.contains(_normalizeCategory(p.category)) &&
            _isNearRoute(p))
        .toList();
    final ids = (waypoints.map((p) => p.id).toList()..sort()).join(',');
    if (ids == _lastWaypointIds.join(',')) return;
    _lastWaypointIds = ids.isEmpty ? [] : ids.split(',');
    cb(waypoints);
  }

  void selectPlace(Place p) => _openPlaceSheet(p);

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadNow);
  }

  Future<void> _loadNow() async {
    // Don't fetch individual markers when zoomed out too far — too little detail
    if (widget.mapController.camera.zoom < 9) {
      if (mounted) setState(() { _loading = false; _lastError = null; });
      return;
    }
    try {
      final bounds = widget.mapController.camera.visibleBounds;
      final sw = bounds.southWest;
      final ne = bounds.northEast;

      // Skip the network entirely when the visible area is still inside the
      // padded area of a recent fetch — the cache already has these places.
      if (_coveredBounds != null &&
          _lastFetchAt != null &&
          DateTime.now().difference(_lastFetchAt!) < _refetchTtl &&
          _covers(_coveredBounds!, bounds)) {
        return;
      }

      setState(() { _loading = true; _lastError = null; });

      final List<Place> data;
      final LatLngBounds fetchedArea;
      if (widget.mapController.camera.zoom < 11) {
        // Large viewport: split into 4 quadrants fetched in parallel so that
        // places near the edges of the screen are covered, not just the centre.
        data = await _fetchTiled(sw, ne);
        final latPad = (ne.latitude  - sw.latitude)  * 0.15;
        final lngPad = (ne.longitude - sw.longitude) * 0.15;
        fetchedArea = LatLngBounds(
          LatLng(sw.latitude - latPad, sw.longitude - lngPad),
          LatLng(ne.latitude + latPad, ne.longitude + lngPad),
        );
      } else {
        // Smaller viewport: single fetch with 25% padding is sufficient.
        final latPad = (ne.latitude  - sw.latitude)  * 0.25;
        final lngPad = (ne.longitude - sw.longitude) * 0.25;
        fetchedArea = LatLngBounds(
          LatLng(sw.latitude - latPad, sw.longitude - lngPad),
          LatLng(ne.latitude + latPad, ne.longitude + lngPad),
        );
        data = await widget.api.fetchInBounds(
          southWest: fetchedArea.southWest,
          northEast: fetchedArea.northEast,
          limit: widget.limit,
        );
      }

      if (!mounted) return;
      _coveredBounds = fetchedArea;
      _lastFetchAt = DateTime.now();
      setState(() {
        for (final p in data) {
          _cache[p.id] = p;
        }
        // Prevent unbounded growth: drop oldest entries when cache is large.
        if (_cache.length > _maxCacheSize) {
          final toRemove = _cache.keys.take(_cache.length - _maxCacheSize).toList();
          for (final k in toRemove) { _cache.remove(k); }
        }
        _loading = false;
      });
      _notifyWaypoints();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _lastError = e; });
    }
  }

  /// Whether [outer] fully contains [inner].
  bool _covers(LatLngBounds outer, LatLngBounds inner) =>
      outer.southWest.latitude  <= inner.southWest.latitude  &&
      outer.southWest.longitude <= inner.southWest.longitude &&
      outer.northEast.latitude  >= inner.northEast.latitude  &&
      outer.northEast.longitude >= inner.northEast.longitude;

  /// Divides [sw]→[ne] into 4 quadrants and fetches them concurrently.
  /// Deduplicates by place ID before returning. Each quadrant uses 25%
  /// padding so tiles overlap slightly and leave no gaps between them.
  Future<List<Place>> _fetchTiled(LatLng sw, LatLng ne) async {
    final midLat = (sw.latitude  + ne.latitude)  / 2;
    final midLng = (sw.longitude + ne.longitude) / 2;
    final latPad = (ne.latitude  - sw.latitude)  * 0.15;
    final lngPad = (ne.longitude - sw.longitude) * 0.15;

    final results = await Future.wait([
      widget.api.fetchInBounds(                                     // SW
        southWest: LatLng(sw.latitude  - latPad, sw.longitude - lngPad),
        northEast: LatLng(midLat       + latPad, midLng       + lngPad),
        limit: widget.limit,
      ),
      widget.api.fetchInBounds(                                     // SE
        southWest: LatLng(sw.latitude  - latPad, midLng       - lngPad),
        northEast: LatLng(midLat       + latPad, ne.longitude + lngPad),
        limit: widget.limit,
      ),
      widget.api.fetchInBounds(                                     // NW
        southWest: LatLng(midLat       - latPad, sw.longitude - lngPad),
        northEast: LatLng(ne.latitude  + latPad, midLng       + lngPad),
        limit: widget.limit,
      ),
      widget.api.fetchInBounds(                                     // NE
        southWest: LatLng(midLat       - latPad, midLng       - lngPad),
        northEast: LatLng(ne.latitude  + latPad, ne.longitude + lngPad),
        limit: widget.limit,
      ),
    ]);

    final merged = <String, Place>{};
    for (final list in results) {
      for (final p in list) { merged[p.id] = p; }
    }
    return merged.values.toList();
  }

  Color _colorFor(String category) {
    switch (_normalizeCategory(category)) {
      case 'lake':        return Colors.blueAccent;
      case 'cave':        return Colors.brown;
      case 'ruin':        return Colors.redAccent;
      case 'peak':        return Colors.deepPurple;
      case 'spring':      return Colors.teal;
      case 'viewpoint':   return Colors.indigo;
      case 'hotel':       return Colors.purple;
      case 'restaurant':  return Colors.red.shade700;
      case 'fuel':        return Colors.amber.shade700;
      case 'pharmacy':    return const Color(0xFF00897B);
      case 'marketplace': return Colors.indigo.shade700;
      case 'cafe':        return const Color(0xFF795548);
      case 'bar':         return Colors.pink.shade700;
      case 'museum':      return Colors.deepPurple.shade700;
      default:            return Colors.orange;
    }
  }

  IconData _iconFor(String category) {
    switch (_normalizeCategory(category)) {
      case 'lake':        return Icons.water_rounded;
      case 'cave':        return Icons.terrain;
      case 'ruin':        return Icons.account_balance;
      case 'peak':        return Icons.landscape;
      case 'spring':      return Icons.water_drop;
      case 'viewpoint':   return Icons.visibility;
      case 'hotel':       return Icons.hotel_rounded;
      case 'restaurant':  return Icons.restaurant_rounded;
      case 'fuel':        return Icons.local_gas_station_rounded;
      case 'pharmacy':    return Icons.local_pharmacy_rounded;
      case 'marketplace': return Icons.store_rounded;
      case 'cafe':        return Icons.local_cafe_rounded;
      case 'bar':         return Icons.local_bar_rounded;
      case 'museum':      return Icons.museum_rounded;
      default:            return Icons.place;
    }
  }

  /// Normalize category names for filtering (handle plural/singular/OSM variants)
  String _normalizeCategory(String category) {
    switch (category.toLowerCase()) {
      case 'caves':
      case 'cave_entrance': return 'cave';
      case 'ruins':
      case 'archaeological_site': return 'ruin';
      case 'fast_food': return 'restaurant';
      case 'supermarket':
      case 'convenience': return 'marketplace';
      case 'guest_house':
      case 'hostel': return 'hotel';
      default: return category.toLowerCase();
    }
  }

  Future<void> _openPlaceSheet(Place p) async {
    setState(() => _selected = p);
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        Place displayPlace = p;
        bool fetched = false;
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          if (!fetched) {
            fetched = true;
            widget.api.fetchPlaceById(p.id).then((full) {
              if (ctx.mounted) setSheetState(() => displayPlace = full);
            }).catchError((_) {});
          }
          return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _colorFor(p.category),
                  child: const Icon(Icons.place, color: Colors.white),
                ),
                title: Text(
                  (p.name.isEmpty ? 'Unknown' : p.name),
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  () {
                    final parts = <String>[];
                    if (p.category.isNotEmpty) parts.add(p.category);
                    if (p.elevationM != null) parts.add('${p.elevationM} m');
                    if (displayPlace.averageRating != null) {
                      parts.add('⭐ ${displayPlace.averageRating!.toStringAsFixed(1)}/5');
                    }
                    parts.add(
                        '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}');
                    if (widget.currentLocation != null) {
                      final dist = const Distance().as(
                          LengthUnit.Kilometer,
                          widget.currentLocation!,
                          LatLng(p.latitude, p.longitude));
                      parts.add('${dist.toStringAsFixed(1)} km away');
                    }
                    return parts.join(' • ');
                  }(),
                ),
              ),
              const SizedBox(height: 12),
              // Rating widget
              Text('Rate this place:',
                  style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final rating = i + 1;
                  return IconButton(
                    onPressed: () async {
                      try {
                        await widget.api.ratePlace(p.id, rating);
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '⭐ Rated $rating star${rating > 1 ? 's' : ''}!'),
                              duration: const Duration(milliseconds: 1500),
                            ),
                          );
                          // Close the bottom sheet after rating
                          Future.delayed(const Duration(milliseconds: 800), () {
                            if (mounted) {
                              Navigator.pop(ctx);
                              // Reload to show updated average
                              _loadNow();
                            }
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Failed to rate: $e')),
                          );
                        } 
                      }
                    },
                    icon: Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    tooltip: 'Rate $rating star${rating > 1 ? 's' : ''}',
                  );
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _navigateTo(p),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Navigate'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.mapController.move(
                          LatLng(p.latitude, p.longitude),
                          widget.mapController.camera.zoom,
                        );
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('Center here'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostsScreen(
                              place: p,
                              api: widget.api,
                              isAdmin: widget.isAdmin,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.article_outlined),
                      label: const Text('See Posts'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(18)),
                          ),
                          builder: (_) => CreatePostSheet(
                            place: p,
                            api: widget.api,
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Create Post'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      useSafeArea: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => WeatherSheet(
                        placeName: p.name,
                        latitude: p.latitude,
                        longitude: p.longitude,
                      ),
                    );
                  },
                  icon: const Icon(Icons.wb_sunny_rounded),
                  label: const Text('48h Weather Forecast'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final text =
                          '${p.latitude},${p.longitude}  ${(p.name.isEmpty ? 'Unknown' : p.name)}';
                      await Clipboard.setData(ClipboardData(text: text));
                      if (mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Coordinates copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_all_rounded),
                    label: const Text('Copy coords'),
                  ),
                  if (!widget.isAdmin)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(ctx).colorScheme.error,
                      ),
                      onPressed: () async {
                        final reason = await showDialog<String>(
                          context: ctx,
                          builder: (d) => _ReportReasonDialog(),
                        );
                        if (reason == null) return;
                        try {
                          await widget.api.reportPlace(p.id, reason: reason);
                          if (mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Place reported. Thank you.')),
                            );
                          }
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Failed to report place.')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Report'),
                    ),
                  if (widget.isAdmin)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: cs.error),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: ctx,
                          builder: (d) => AlertDialog(
                            title: const Text('Delete Place'),
                            content: Text(
                                'Permanently delete "${p.name.isEmpty ? 'this place' : p.name}" and all its posts?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: cs.error,
                                      foregroundColor: cs.onError),
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        ) == true;
                        if (!confirmed) return;
                        try {
                          await widget.api.adminDeletePlace(p.id);
                          if (mounted && ctx.mounted) {
                            setState(() => _cache.remove(p.id));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Place deleted.')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Delete Place'),
                    ),
                ],
              ),
            ],
          ),
        );
        });
      },
    );
    if (mounted) setState(() => _selected = null);
  }

  Future<void> _navigateTo(Place p) async {
    if (widget.onNavigate != null) {
      widget.onNavigate!(p);
      Navigator.of(context).pop();
    } else {
      final label = (p.name.isEmpty ? 'Destination' : p.name);
      final geo = Uri.parse(
          'geo:${p.latitude},${p.longitude}?q=${Uri.encodeComponent('${p.latitude},${p.longitude}($label)')}');
      final gmaps = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}&travelmode=driving');
      try {
        if (await canLaunchUrl(geo)) {
          await launchUrl(geo, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(gmaps, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open maps: $e')),
        );
      }
    }
  }

  /// Returns true if [p] is within 600 m of any sampled point on the route.
  bool _isNearRoute(Place p) {
    if (widget.routePolyline.isEmpty) return false;
    const maxDistM = 600.0;
    const dist = Distance();
    final placeLatLng = LatLng(p.latitude, p.longitude);
    // Sample every 4th point for performance
    for (var i = 0; i < widget.routePolyline.length; i += 4) {
      if (dist.as(LengthUnit.Meter, widget.routePolyline[i], placeLatLng) < maxDistM) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = widget.routePolyline.isNotEmpty;

    // Filter cache to places currently visible on screen (with a small buffer
    // so markers don't pop in at the very edge while panning).
    final bounds   = widget.mapController.camera.visibleBounds;
    final latPad   = (bounds.northEast.latitude  - bounds.southWest.latitude)  * 0.1;
    final lngPad   = (bounds.northEast.longitude - bounds.southWest.longitude) * 0.1;
    final visible  = _cache.values.where((p) =>
        p.latitude  >= bounds.southWest.latitude  - latPad &&
        p.latitude  <= bounds.northEast.latitude  + latPad &&
        p.longitude >= bounds.southWest.longitude - lngPad &&
        p.longitude <= bounds.northEast.longitude + lngPad,
    );

    // Waypoints: natural places near the active route, shown even when filter is off
    final waypointPlaces = hasRoute
        ? visible
            .where((p) =>
                _waypointCategories.contains(_normalizeCategory(p.category)) &&
                _isNearRoute(p))
            .toList()
        : <Place>[];

    // If locations should be hidden (and no route), only show waypoints
    if (!widget.showLocations) {
      if (waypointPlaces.isEmpty) {
        return Stack(
          children: [
            if (_loading)
              const Positioned(right: 12, top: 12, child: _LoadingChip()),
            if (_lastError != null)
              Positioned(
                  right: 12, top: 12, child: _ErrorChip(msg: _lastError.toString())),
          ],
        );
      }
    }

    // Apply user filters to visible places (empty list when showLocations is off)
    final filteredPlaces = widget.showLocations
        ? visible.where((p) {
            final normalizedPlaceCategory = _normalizeCategory(p.category);
            if (widget.selectedCategories.isNotEmpty &&
                !widget.selectedCategories.contains(normalizedPlaceCategory)) {
              return false;
            }
            if (widget.maxDistanceKm != null && widget.currentLocation != null) {
              final dist = const Distance().as(LengthUnit.Kilometer,
                  widget.currentLocation!, LatLng(p.latitude, p.longitude));
              if (dist > widget.maxDistanceKm!) return false;
            }
            if (widget.minElevation != null) {
              if (p.elevationM == null || p.elevationM! < widget.minElevation!) return false;
            }
            if (widget.maxElevation != null) {
              if (p.elevationM == null || p.elevationM! > widget.maxElevation!) return false;
            }
            return true;
          }).toList()
        : <Place>[];

    final markers = filteredPlaces.map((p) {
      final isSelected = _selected?.id == p.id;
      final color = _colorFor(p.category);
      final icon = _iconFor(p.category);
      return Marker(
        point: LatLng(p.latitude, p.longitude),
        width: isSelected ? 40 : 32,
        height: isSelected ? 40 : 32,
        child: GestureDetector(
          onTap: () => _openPlaceSheet(p),
          child: Tooltip(
            message: (p.name.isEmpty ? "Unknown" : p.name),
            waitDuration: const Duration(milliseconds: 250),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 1.0 : 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(blurRadius: 4, color: Colors.black26)
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isSelected ? 20 : 16,
              ),
            ),
          ),
        ),
      );
    }).toList();

    // Build waypoint markers — shown on top of filtered markers, with a
    // pulsing yellow border so they stand out from regular filtered pins.
    final waypointMarkers = waypointPlaces
        .where((p) => !filteredPlaces.any((fp) => fp.id == p.id))
        .map((p) {
      final color = _colorFor(p.category);
      final icon  = _iconFor(p.category);
      return Marker(
        point: LatLng(p.latitude, p.longitude),
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _openPlaceSheet(p),
          child: Tooltip(
            message: p.name.isEmpty ? 'Nearby' : p.name,
            waitDuration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber, width: 2.5),
                boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      );
    }).toList();

    return Stack(
      children: [
        MarkerLayer(markers: [...markers, ...waypointMarkers]),
        if (_loading)
          const Positioned(right: 12, top: 12, child: _LoadingChip()),
        if (_lastError != null)
          Positioned(
              right: 12, top: 12, child: _ErrorChip(msg: _lastError.toString())),
      ],
    );
  }
}

class _ReportReasonDialog extends StatefulWidget {
  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  static const _reasons = [
    'Doesn\'t exist / wrong location',
    'Wrong category (not a lake, peak, etc.)',
    'Spam or fake place',
    'Inappropriate or offensive',
    'Duplicate of another place',
    'Other',
  ];

  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Place'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Why are you reporting this place?'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons
                .map((r) => ChoiceChip(
                      label: Text(r, style: const TextStyle(fontSize: 13)),
                      selected: _selected == r,
                      onSelected: (_) => setState(() => _selected = r),
                    ))
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.pop(context, _selected),
            child: const Text('Report')),
      ],
    );
  }
}

class _LoadingChip extends StatelessWidget {
  const _LoadingChip();

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Loading places…'),
      ]),
      backgroundColor: Colors.white,
      elevation: 4,
      side: BorderSide(color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _ErrorChip extends StatelessWidget {
  final String msg;
  const _ErrorChip({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        msg,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Theme.of(context).colorScheme.onError),
      ),
      backgroundColor: Theme.of(context).colorScheme.error,
      elevation: 4,
    );
  }
}
