import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/places_api.dart';
import '../services/sos_service.dart';
import '../services/routing_service.dart';
import '../widgets/places_layer.dart';
import '../services/auth_service.dart';
import '../app.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  // USB + adb reverse esetere:
  final PlacesApi _placesApi =
      const PlacesApi(baseUrl: 'http://127.0.0.1:3000');

  // Ha Wi-Fi/LAN modra allnal at, akkor hasznalj ilyesmit:
  // final PlacesApi _placesApi =
  //     const PlacesApi(baseUrl: 'http://<YOUR_PC_IP>:3000');

  final LatLng _initialCenter = const LatLng(45.9432, 24.9668);
  final double _initialZoom = 6.5;
  LatLng? _currentLatLng;

  // Filter state
  final Set<String> _selectedCategories = {};
  int? _minElevation;
  int? _maxElevation;
  double? _maxDistanceKm;
  bool _showAllLocations = false; // Hidden by default

  // All available categories
  final List<String> _allCategories = [
    'lake',
    'cave',
    'ruin',
    'peak',
    'spring',
    'viewpoint',
  ];

  // Text controllers for elevation & distance inputs
  late TextEditingController _minElevationController;
  late TextEditingController _maxElevationController;
  late TextEditingController _distanceController;

  // Navigation state
  Place? _navigationDestination;
  List<LatLng> _routePolyline = [];
  bool _isNavigating = false;
  double _distanceToDestination = 0;
  double _totalRouteDistance = 0;

  @override
  void initState() {
    super.initState();
    _minElevationController = TextEditingController();
    _maxElevationController = TextEditingController();
    _distanceController = TextEditingController();
    _ensureLocationAndCenter(silent: true);
  }

  @override
  void dispose() {
    _minElevationController.dispose();
    _maxElevationController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // The animated location indicator is defined below

          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: Theme.of(context).brightness == Brightness.dark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.pathfinder_app',
              ),
              PlacesLayer(
                mapController: _mapController,
                api: _placesApi,
                limit: 1000,
                selectedCategories: _selectedCategories,
                minElevation: _minElevation,
                maxElevation: _maxElevation,
                maxDistanceKm: _maxDistanceKm,
                currentLocation: _currentLatLng,
                showLocations: _showAllLocations ||
                    _selectedCategories.isNotEmpty ||
                    _minElevation != null ||
                    _maxElevation != null ||
                    _maxDistanceKm != null,
                onNavigate: _startNavigation,
              ),
              // Navigation route polyline
              if (_routePolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePolyline,
                      color: const Color(0xFF2196F3),
                      strokeWidth: 4,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              if (_currentLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLatLng!,
                      width: 40,
                      height: 40,
                      child: const _CurrentLocationIndicator(),
                    ),
                  ],
                ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _ensureLocationAndCenter,
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Current location'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: IconButton.filledTonal(
                      tooltip: 'Filters',
                      onPressed: () => _openFiltersSheet(context),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Profile',
                    onPressed: () => _openProfileSheet(context),
                    icon: const Icon(Icons.person_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Hint when no locations are shown
          if (!_showAllLocations &&
              _selectedCategories.isEmpty &&
              _minElevation == null &&
              _maxElevation == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 100,
              left: 12,
              right: 12,
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: cs.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tap the filter icon to show locations or apply filters',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Navigation bottom bar with distance slider
          if (_isNavigating && _navigationDestination != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Navigating to',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _navigationDestination!.name.isEmpty
                                        ? 'Destination'
                                        : _navigationDestination!.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Distance',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_distanceToDestination.toStringAsFixed(2)} km',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: cs.primary,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Distance progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (_navigationDestination != null &&
                                    _totalRouteDistance > 0)
                                ? ((_totalRouteDistance -
                                            _distanceToDestination) /
                                        _totalRouteDistance)
                                    .clamp(0, 1)
                                : 0,
                            minHeight: 8,
                            backgroundColor: cs.outlineVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Stop navigation button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _stopNavigation,
                            icon: const Icon(Icons.close),
                            label: const Text('Stop Navigation'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _ensureLocationAndCenter({bool silent = false}) async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is permanently denied'),
            ),
          );
        }
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable Location Services'),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _currentLatLng = latLng;
      });

      _mapController.move(latLng, 15);

      // If navigation is active, update polyline
      if (_isNavigating) {
        _updateNavigationPolyline(latLng);
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    }
  }

  Future<void> _startNavigation(Place destination) async {
    if (_currentLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting location...')),
      );
      await _ensureLocationAndCenter(silent: false);
    }

    if (_currentLatLng == null) return;

    setState(() {
      _navigationDestination = destination;
      _isNavigating = true;
    });

    try {
      final routingService = RoutingService();
      final routeData = await routingService.getRoute(
        _currentLatLng!,
        LatLng(destination.latitude, destination.longitude),
      );

      if (mounted) {
        setState(() {
          _routePolyline = routeData.polyline;
          _totalRouteDistance = routeData.distance / 1000; // Convert to km
          _distanceToDestination = _totalRouteDistance;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Navigating to ${destination.name.isEmpty ? 'destination' : destination.name}'),
            duration: const Duration(seconds: 2),
          ),
        );

        // Start listening to position updates
        _listenToPositionChanges();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          _navigationDestination = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get route: $e')),
        );
      }
    }
  }

  void _listenToPositionChanges() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update when moved 5 meters
      ),
    ).listen((Position position) {
      if (_isNavigating && mounted) {
        final userLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLatLng = userLocation;
        });
        _updateNavigationPolyline(userLocation);
      }
    });
  }

  void _updateNavigationPolyline(LatLng userLocation) {
    if (_routePolyline.isEmpty || _navigationDestination == null) return;

    const distance = Distance();
    final distToDestination = distance.as(
      LengthUnit.Kilometer,
      userLocation,
      LatLng(
        _navigationDestination!.latitude,
        _navigationDestination!.longitude,
      ),
    );

    // If very close to destination, stop navigation
    if (distToDestination < 0.05) {
      setState(() {
        _isNavigating = false;
        _routePolyline = [];
        _navigationDestination = null;
        _distanceToDestination = 0;
        _totalRouteDistance = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destination reached!')),
      );
      return;
    }

    // Find closest point on polyline and remove already walked portion
    final result = RoutingService.findClosestPointAndRemovePath(
      _routePolyline,
      userLocation,
    );

    // Calculate remaining distance along the route
    final remainingDistance =
        RoutingService.calculatePolylineDistance(result.value) /
            1000; // Convert to km

    if (mounted) {
      setState(() {
        _routePolyline = result.value;
        _distanceToDestination = remainingDistance;
      });
    }
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _routePolyline = [];
      _navigationDestination = null;
      _distanceToDestination = 0;
      _totalRouteDistance = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation stopped')),
    );
  }

  void _openProfileSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final display = user?.displayName?.trim();
    final email = user?.email?.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final auth = AuthService();

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.42,
          minChildSize: 0.32,
          maxChildSize: 0.9,
          builder: (ctx, scrollCtl) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ListView(
                controller: scrollCtl,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 32,
                        child: Icon(Icons.person, size: 36),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (display != null && display.isNotEmpty)
                                  ? display
                                  : 'Your profile',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email ?? 'no-email@example.com',
                              style:
                                  Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Stats coming soon'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.bar_chart_rounded),
                          label: const Text('Stats'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Future.delayed(Duration.zero, () {
                              if (mounted) {
                                SosService.showSosSheet(context);
                              }
                            });
                          },
                          icon: const Icon(Icons.emergency_share_rounded),
                          label: const Text('S.O.S'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Theme.of(ctx).brightness == Brightness.dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: cs.primary,
                    ),
                    title: Text(
                      Theme.of(ctx).brightness == Brightness.dark
                          ? 'Switch to Light Mode'
                          : 'Switch to Dark Mode',
                    ),
                    onTap: () {
                      PathfinderApp.of(context)?.toggleTheme();
                      Navigator.of(ctx).pop();
                    },
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout_rounded, color: cs.error),
                    title: const Text('Log out'),
                    onTap: () async {
                      await auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          LoginScreen.routeName,
                          (_) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openFiltersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;

        return StatefulBuilder(
          builder: (ctx, setState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (ctx, scrollCtl) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: ListView(
                    controller: scrollCtl,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: cs.outlineVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),

                      // Title
                      Text(
                        'Filter Places',
                        style: Theme.of(ctx)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),

                      // Show All Locations Toggle
                      Card(
                        color: _showAllLocations
                            ? cs.primaryContainer
                            : cs.surfaceContainerHigh,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                _showAllLocations
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: _showAllLocations ? cs.primary : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Show All Locations',
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: _showAllLocations
                                                ? cs.onPrimaryContainer
                                                : null,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Display all available places on the map',
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: _showAllLocations
                                                ? cs.onPrimaryContainer
                                                : cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _showAllLocations,
                                onChanged: (value) {
                                  setState(() {
                                    _showAllLocations = value;
                                  });
                                  this.setState(() {});
                                },
                                activeThumbColor: cs.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Categories Section
                      Text(
                        'Place Types',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select categories to display (leave empty to show all)',
                        style: Theme.of(ctx)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allCategories.map((category) {
                          final isSelected =
                              _selectedCategories.contains(category);
                          return FilterChip(
                            label: Text(_formatCategoryName(category)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                              });
                              this.setState(() {});
                            },
                            backgroundColor: Theme.of(ctx).colorScheme.surface,
                            selectedColor:
                                Theme.of(ctx).colorScheme.primaryContainer,
                            side: BorderSide(
                              color: isSelected
                                  ? Theme.of(ctx).colorScheme.primary
                                  : cs.outline,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Elevation Filter
                      Text(
                        'Elevation Range (meters)',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Filter places by altitude. Leave empty for no limit.',
                        style: Theme.of(ctx)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),

                      // Distance filter
                      Text(
                        'Max distance (km)',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Radius from current location',
                          hintText: 'e.g., 10',
                          suffixText: 'km',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          setState(() {
                            _maxDistanceKm =
                                double.tryParse(v.replaceAll(',', '.'));
                          });
                        },
                        controller: _distanceController,
                      ),
                      const SizedBox(height: 12),

                      // Elevation Range Inputs
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Min (m)',
                                prefixIcon: const Icon(Icons.trending_up),
                                hintText: '0',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  _minElevation = int.tryParse(value);
                                });
                                this.setState(() {});
                              },
                              controller: _minElevationController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Max (m)',
                                prefixIcon: const Icon(Icons.trending_up),
                                hintText: '∞',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  _maxElevation = int.tryParse(value);
                                });
                                this.setState(() {});
                              },
                              controller: _maxElevationController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Reset Button
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedCategories.clear();
                            _minElevation = null;
                            _maxElevation = null;
                            _maxDistanceKm = null;
                            _showAllLocations = false;
                            _minElevationController.clear();
                            _maxElevationController.clear();
                            _distanceController.clear();
                          });
                          this.setState(() {});
                        },
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Clear All Filters'),
                      ),
                      const SizedBox(height: 16),

                      // Active Filters Summary
                      if (_selectedCategories.isNotEmpty ||
                          _minElevation != null ||
                          _maxElevation != null ||
                          _maxDistanceKm != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.primary),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Active Filters:',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              if (_selectedCategories.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.category, size: 14),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _selectedCategories
                                              .map(_formatCategoryName)
                                              .join(', '),
                                          style:
                                              Theme.of(ctx).textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_minElevation != null ||
                                  _maxElevation != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.trending_up, size: 14),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Altitude: ${_minElevation ?? '0'} - ${_maxElevation ?? '∞'} m',
                                          style:
                                              Theme.of(ctx).textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_maxDistanceKm != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.map, size: 14),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '≤ ${_maxDistanceKm!.toStringAsFixed(1)} km',
                                          style:
                                              Theme.of(ctx).textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_minElevation != null ||
                                  _maxElevation != null)
                                const SizedBox(height: 8),
                              if (_minElevation != null ||
                                  _maxElevation != null)
                                Text(
                                  '💡 Note: Places without elevation data will always be shown.',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Close Button
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Apply Filters'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatCategoryName(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

// ----------------------------------------------------------
// Current location indicator widget with subtle pulse
// ----------------------------------------------------------

class _CurrentLocationIndicator extends StatefulWidget {
  const _CurrentLocationIndicator({super.key});

  @override
  State<_CurrentLocationIndicator> createState() =>
      _CurrentLocationIndicatorState();
}

class _CurrentLocationIndicatorState extends State<_CurrentLocationIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _scale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // pulsating circle
          AnimatedBuilder(
            animation: _scale,
            builder: (ctx, child) {
              return Container(
                width: 24 * _scale.value,
                height: 24 * _scale.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue
                      .withOpacity(0.3 * (1 - (_scale.value - 1) / 0.6)),
                ),
              );
            },
          ),
          // core icon
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 12,
            ),
          ),
        ],
      ),
    );
  }
}
