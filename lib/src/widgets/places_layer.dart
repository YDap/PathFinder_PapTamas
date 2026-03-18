import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/places_api.dart';

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
  final Function(Place)? onNavigate;

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
    this.onNavigate,
  });

  @override
  State<PlacesLayer> createState() => _PlacesLayerState();
}

class _PlacesLayerState extends State<PlacesLayer> {
  StreamSubscription<MapEvent>? _sub;
  Timer? _debounce;
  List<Place> _places = const [];
  bool _loading = false;
  Object? _lastError;

  Place? _selected;

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
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadNow);
  }

  Future<void> _loadNow() async {
    try {
      final bounds = widget.mapController.camera.visibleBounds;

      final sw = bounds.southWest;
      final ne = bounds.northEast;

      setState(() {
        _loading = true;
        _lastError = null;
      });

      final data = await widget.api.fetchInBounds(
        southWest: LatLng(sw.latitude, sw.longitude),
        northEast: LatLng(ne.latitude, ne.longitude),
        limit: widget.limit,
      );

      if (!mounted) return;
      setState(() {
        _places = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lastError = e;
      });
    }
  }

  Color _colorFor(String category) {
    switch (category.toLowerCase()) {
      case 'lake':
        return Colors.blueAccent;
      case 'cave':
      case 'caves':
        return Colors.brown;
      case 'ruin':
      case 'ruins':
        return Colors.redAccent;
      case 'peak':
        return Colors.deepPurple;
      case 'spring':
        return Colors.teal;
      case 'viewpoint':
        return Colors.indigo;
      default:
        return Colors.orange;
    }
  }

  IconData _iconFor(String category) {
    switch (category.toLowerCase()) {
      case 'lake':
        return Icons.pool; // Water body icon
      case 'cave':
      case 'caves':
        return Icons.terrain; // Cave/terrain icon
      case 'ruin':
      case 'ruins':
        return Icons.account_balance; // Historical/ruins icon
      case 'peak':
        return Icons.landscape; // Mountain peak icon
      case 'spring':
        return Icons.water_drop; // Water spring icon
      case 'viewpoint':
        return Icons.visibility; // Viewpoint icon
      default:
        return Icons.place; // Generic location icon
    }
  }

  /// Normalize category names for filtering (handle plural/singular variants)
  String _normalizeCategory(String category) {
    final cat = category.toLowerCase();
    // Map plural/alternate forms to canonical forms
    if (cat == 'caves' || cat == 'cave_entrance') return 'cave';
    if (cat == 'ruins' || cat == 'archaeological_site') return 'ruin';
    return cat;
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
        final cs = Theme.of(ctx).colorScheme;
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
                trailing: p.averageRating != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          return Icon(
                            star <= p.averageRating!
                                ? Icons.star
                                : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          );
                        }),
                      )
                    : null,
              ),
              if (p.averageRating != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Rating: ${p.averageRating!.toStringAsFixed(1)} / 5',
                    style: Theme.of(ctx).textTheme.bodySmall,
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
                        // Optionally reload to update average
                        _loadNow();
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Rated $rating stars!')),
                          );
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
                      Icons.star_border,
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
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
              ),
            ],
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    // If locations should be hidden, don't show any markers
    if (!widget.showLocations) {
      return Stack(
        children: [
          if (_loading)
            const Positioned(
              right: 12,
              top: 12,
              child: _LoadingChip(),
            ),
          if (_lastError != null)
            Positioned(
              right: 12,
              top: 12,
              child: _ErrorChip(msg: _lastError.toString()),
            ),
        ],
      );
    }

    // Apply filters to places
    final filteredPlaces = _places.where((p) {
      // Normalize the place category for comparison
      final normalizedPlaceCategory = _normalizeCategory(p.category);

      // If categories are selected, only show places in those categories
      if (widget.selectedCategories.isNotEmpty &&
          !widget.selectedCategories.contains(normalizedPlaceCategory)) {
        return false;
      }

      // Distance filter
      if (widget.maxDistanceKm != null && widget.currentLocation != null) {
        final dist = const Distance().as(LengthUnit.Kilometer,
            widget.currentLocation!, LatLng(p.latitude, p.longitude));
        if (dist > widget.maxDistanceKm!) {
          return false;
        }
      }

      // Apply elevation filters if specified
      if (widget.minElevation != null && p.elevationM != null) {
        if (p.elevationM! < widget.minElevation!) {
          return false;
        }
      }
      if (widget.maxElevation != null && p.elevationM != null) {
        if (p.elevationM! > widget.maxElevation!) {
          return false;
        }
      }

      return true;
    }).toList();

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
                color: color.withOpacity(isSelected ? 1.0 : 0.9),
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

    return Stack(
      children: [
        MarkerLayer(markers: markers),
        if (_loading)
          const Positioned(
            right: 12,
            top: 12,
            child: _LoadingChip(),
          ),
        if (_lastError != null)
          Positioned(
            right: 12,
            top: 12,
            child: _ErrorChip(msg: _lastError.toString()),
          ),
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
