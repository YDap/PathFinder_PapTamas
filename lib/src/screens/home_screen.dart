import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../services/places_api.dart';
import '../services/sos_service.dart';
import '../services/routing_service.dart';
import '../widgets/places_layer.dart';
import '../widgets/ai_chat_sheet.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../app.dart';
import 'login_screen.dart';
import 'admin_screen.dart';
import 'friends_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final GlobalKey<PlacesLayerState> _placesLayerKey = GlobalKey<PlacesLayerState>();

  // USB + adb reverse esetere:
  final PlacesApi _placesApi =
      const PlacesApi(baseUrl: 'https://pathfinderbackend-production.up.railway.app');

  final LatLng _initialCenter = const LatLng(45.9432, 24.9668);
  final double _initialZoom = 6.5;
  LatLng? _currentLatLng;

  // Filter state
  final Set<String> _selectedCategories = {};
  int? _minElevation;
  int? _maxElevation;
  double? _maxDistanceKm;
  bool _showAllLocations = false; // Hidden by default


  // Text controllers for elevation & distance inputs
  late TextEditingController _minElevationController;
  late TextEditingController _maxElevationController;
  late TextEditingController _distanceController;

  // Navigation state
  Place? _navigationDestination;
  List<LatLng> _routePolyline = [];
  bool _isNavigating = false;
  bool _followUser = true;
  double _distanceToDestination = 0;
  double _totalRouteDistance = 0;

  // Waypoints along the active route (natural places within 600 m of the route)
  List<Place> _routeWaypoints = [];
  // Pre-computed bar fractions: placeId → 0..1 position on the progress bar.
  // Recomputed only when waypoints change, not on every position update.
  Map<String, double> _waypointFractions = {};

  void _updateWaypointFractions() {
    if (_routePolyline.isEmpty || _totalRouteDistance <= 0) {
      _waypointFractions = {};
      return;
    }
    final walked = _totalRouteDistance - _distanceToDestination;
    final fracs = <String, double>{};
    for (final wp in _routeWaypoints) {
      final fromNow = RoutingService.distanceAlongPolyline(
        _routePolyline,
        LatLng(wp.latitude, wp.longitude),
      ) / 1000; // meters → km
      fracs[wp.id] = ((walked + fromNow) / _totalRouteDistance).clamp(0.0, 1.0);
    }
    setState(() => _waypointFractions = fracs);
  }

  // Navigate Together state
  String? _navSessionId;
  String? _navPartnerName;
  PartnerLocation? _partnerLocation;
  LatLng? _navDestination;       // shared destination (to draw partner's line)
  List<LatLng> _partnerRoutePolyline = [];
  LatLng? _lastPartnerLocationForRoute;
  Timer? _navPollTimer;
  Timer? _invitePollTimer;

  // Profile state
  final ProfileService _profileService =
      ProfileService(baseUrl: 'https://pathfinderbackend-production.up.railway.app');
  String? _profileImageUrl;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _minElevationController = TextEditingController();
    _maxElevationController = TextEditingController();
    _distanceController = TextEditingController();
    _placesApi.warmUp();
    _ensureLocationAndCenter(silent: true);
    _loadProfileImage();
    _startInvitePolling();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreNavigationState());
  }

  Future<void> _loadProfileImage() async {
    final user = await _placesApi.fetchCurrentUser();
    if (mounted) {
      setState(() {
        if (user.imageUrl != null) _profileImageUrl = user.imageUrl;
        _isAdmin = user.isAdmin;
      });
    }
    // Also check local cache for immediate display
    final cached = await _profileService.getProfileImageUrl();
    if (mounted && cached != null && _profileImageUrl == null) {
      setState(() {
        _profileImageUrl = cached;
      });
    }
  }

  @override
  void dispose() {
    _navPollTimer?.cancel();
    _invitePollTimer?.cancel();
    _minElevationController.dispose();
    _maxElevationController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _isNavigating
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_help',
                  tooltip: 'Help & Legend',
                  onPressed: () => _showHelpDialog(context),
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  child: const Text('?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
      body: Stack(
        children: [
          // The animated location indicator is defined below

          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              onMapEvent: (MapEvent event) {
                if (_isNavigating &&
                    _followUser &&
                    event is MapEventMoveStart &&
                    event.source != MapEventSource.mapController) {
                  setState(() => _followUser = false);
                }
              },
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
                key: _placesLayerKey,
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
                isAdmin: _isAdmin,
                routePolyline: _routePolyline,
                onRouteWaypointsChanged: (wps) {
                  if (!mounted) return;
                  setState(() => _routeWaypoints = wps);
                  _updateWaypointFractions();
                },
              ),
              // Navigation route polyline (own — blue)
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
              // Partner route line (orange dashed) — fetched via routing API
              if (_partnerRoutePolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _partnerRoutePolyline,
                      color: Colors.orange,
                      strokeWidth: 3,
                      borderStrokeWidth: 1.5,
                      borderColor: Colors.white,
                      pattern: StrokePattern.dashed(segments: const [12, 6]),
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
              if (_partnerLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_partnerLocation!.lat, _partnerLocation!.lng),
                      width: 52,
                      height: 52,
                      child: GestureDetector(
                        onTap: () {
                          final km = _partnerLocation?.remainingKm;
                          final name = _navPartnerName ?? 'Friend';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                km != null
                                    ? '$name: ${km.toStringAsFixed(2)} km to destination'
                                    : '$name\'s location',
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                        child: _PartnerMarker(name: _navPartnerName ?? 'Friend'),
                      ),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: IconButton.filledTonal(
                      tooltip: 'AI Assistant',
                      onPressed: () => _openAiChatSheet(context),
                      icon: const Icon(Icons.auto_awesome_rounded),
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
          // + Add place FAB (bottom left)
          if (!_isNavigating)
            Positioned(
              bottom: 16,
              left: 16,
              child: SafeArea(
                child: FloatingActionButton.small(
                  heroTag: 'fab_add',
                  tooltip: 'Add a new place',
                  onPressed: () => _showAddLocationSheet(context),
                  child: const Icon(Icons.add),
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
                        // Distance progress bar with waypoint dots
                        _buildProgressBar(cs),
                        const SizedBox(height: 12),
                        // Navigate Together row
                        if (_navSessionId != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people_rounded, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'With ${_navPartnerName ?? 'Friend'}',
                                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_partnerLocation?.remainingKm != null)
                                        Text(
                                          '${_partnerLocation!.remainingKm!.toStringAsFixed(1)} km left',
                                          style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _endNavSession,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('End'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _inviteFriendToNavigate,
                              icon: const Icon(Icons.people_rounded),
                              label: const Text('Navigate Together'),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Re-center button (shown when user panned away)
                        if (!_followUser) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _followUser = true);
                                if (_currentLatLng != null) {
                                  _mapController.move(
                                    _currentLatLng!,
                                    _mapController.camera.zoom,
                                  );
                                }
                              },
                              icon: const Icon(Icons.my_location_rounded),
                              label: const Text('Re-center'),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
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

  void _openAiChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AiChatSheet(
        api: _placesApi,
        currentLocation: _currentLatLng,
        onShowOnMap: (place) {
          _mapController.move(
            LatLng(place.latitude, place.longitude),
            14,
          );
          Future.delayed(const Duration(milliseconds: 350), () {
            _placesLayerKey.currentState?.selectPlace(place);
          });
        },
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
      _followUser = true;
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
        _saveNavigationState();

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
        setState(() => _currentLatLng = userLocation);
        if (_followUser) {
          _mapController.move(userLocation, _mapController.camera.zoom);
        }
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
    // End any active shared session so the partner's polyline clears immediately.
    if (_navSessionId != null) {
      _endNavSession();
    }
    setState(() {
      _isNavigating = false;
      _routePolyline = [];
      _navigationDestination = null;
      _distanceToDestination = 0;
      _totalRouteDistance = 0;
    });
    _saveNavigationState();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation stopped')),
    );
  }

  // ── Navigate Together ────────────────────────────────────────

  Future<void> _saveNavigationState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_navSessionId != null) {
      await prefs.setString('nav_session_id', _navSessionId!);
      if (_navPartnerName != null) {
        await prefs.setString('nav_partner_name', _navPartnerName!);
      }
    } else {
      await prefs.remove('nav_session_id');
      await prefs.remove('nav_partner_name');
    }
    await prefs.setBool('is_navigating', _isNavigating);
    if (_isNavigating && _navigationDestination != null) {
      await prefs.setString('nav_dest_id', _navigationDestination!.id);
      await prefs.setString('nav_dest_name', _navigationDestination!.name);
      await prefs.setString('nav_dest_category', _navigationDestination!.category);
      await prefs.setDouble('nav_dest_lat', _navigationDestination!.latitude);
      await prefs.setDouble('nav_dest_lng', _navigationDestination!.longitude);
    } else {
      for (final k in ['nav_dest_id', 'nav_dest_name', 'nav_dest_category', 'nav_dest_lat', 'nav_dest_lng']) {
        await prefs.remove(k);
      }
    }
    if (_navDestination != null) {
      await prefs.setDouble('nav_shared_dest_lat', _navDestination!.latitude);
      await prefs.setDouble('nav_shared_dest_lng', _navDestination!.longitude);
    } else {
      await prefs.remove('nav_shared_dest_lat');
      await prefs.remove('nav_shared_dest_lng');
    }
  }

  Future<void> _restoreNavigationState() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('nav_session_id');
    if (sessionId != null && mounted) {
      setState(() {
        _navSessionId = sessionId;
        _navPartnerName = prefs.getString('nav_partner_name');
      });
      _invitePollTimer?.cancel();
      _startNavSessionPolling();
    }
    final sharedLat = prefs.getDouble('nav_shared_dest_lat');
    final sharedLng = prefs.getDouble('nav_shared_dest_lng');
    if (sharedLat != null && sharedLng != null && mounted) {
      setState(() => _navDestination = LatLng(sharedLat, sharedLng));
    }
    final wasNavigating = prefs.getBool('is_navigating') ?? false;
    if (wasNavigating) {
      final lat = prefs.getDouble('nav_dest_lat');
      final lng = prefs.getDouble('nav_dest_lng');
      if (lat != null && lng != null && mounted) {
        await _startNavigation(Place(
          id: prefs.getString('nav_dest_id') ?? '',
          name: prefs.getString('nav_dest_name') ?? 'Destination',
          category: prefs.getString('nav_dest_category') ?? 'unknown',
          latitude: lat,
          longitude: lng,
        ));
      }
    }
  }

  void _startInvitePolling() {
    _invitePollTimer?.cancel();
    _invitePollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (_navSessionId != null || !mounted) return;
      try {
        final invite = await _placesApi.getPendingNavInvite();
        if (invite != null && mounted && _navSessionId == null) {
          _invitePollTimer?.cancel();
          _showInviteDialog(invite);
        }
      } catch (_) {}
    });
  }

  void _showInviteDialog(NavInvite invite) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Navigate Together'),
        content: Text('${invite.creatorName} wants to navigate with you!'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _placesApi.declineNavSession(invite.sessionId);
              } catch (_) {}
              _startInvitePolling();
            },
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _placesApi.acceptNavSession(invite.sessionId);
                if (!mounted) return;
                setState(() {
                  _navSessionId = invite.sessionId;
                  _navPartnerName = invite.creatorName;
                  if (invite.hasDestination) {
                    _navDestination = LatLng(invite.destinationLat!, invite.destinationLng!);
                  }
                });
                _startNavSessionPolling();
                _saveNavigationState();
                if (invite.hasDestination && !_isNavigating) {
                  await _startNavigation(Place(
                    id: 'nav_${invite.sessionId}',
                    name: invite.destinationName ?? 'Shared Destination',
                    category: 'destination',
                    latitude: invite.destinationLat!,
                    longitude: invite.destinationLng!,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not join: $e')),
                  );
                  _startInvitePolling();
                }
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _startNavSessionPolling() {
    _invitePollTimer?.cancel();
    _navPollTimer?.cancel();
    _navPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_navSessionId == null || !mounted) return;
      // Snapshot the session ID now. If _endNavSession() runs while we are
      // awaiting network calls below, _navSessionId will be set to null (or a
      // new value). We check the snapshot before writing any state so that a
      // stale response from the OLD session can never overwrite a clean state.
      final sessionId = _navSessionId!;
      try {
        if (_currentLatLng != null) {
          await _placesApi.updateNavLocation(
            sessionId,
            _currentLatLng!.latitude,
            _currentLatLng!.longitude,
            remainingKm: _isNavigating ? _distanceToDestination : null,
          );
        }
        // Bail if the session changed while we were awaiting updateNavLocation.
        if (!mounted || _navSessionId != sessionId) return;

        final result = await _placesApi.getPartnerNavLocation(sessionId);

        // Bail if the session changed while we were awaiting getPartnerNavLocation.
        if (!mounted || _navSessionId != sessionId) return;

        if (result.status == 'ended') {
          _endNavSession(notify: true);
          return;
        }
        if (result.status == 'active') {
          final dest = _navDestination ??
              (result.destination != null
                  ? LatLng(result.destination!.lat, result.destination!.lng)
                  : null);
          setState(() {
            _partnerLocation = result.partnerLocation;
            if (_navDestination == null && dest != null) _navDestination = dest;
          });
          final pl = result.partnerLocation;
          if (pl != null && dest != null) {
            final newLoc = LatLng(pl.lat, pl.lng);
            if (_lastPartnerLocationForRoute == null ||
                const Distance().as(LengthUnit.Meter,
                    _lastPartnerLocationForRoute!, newLoc) > 100) {
              _lastPartnerLocationForRoute = newLoc;
              _fetchPartnerRoute(newLoc, dest);
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _inviteFriendToNavigate() async {
    try {
      final friends = await _placesApi.getFriends();
      if (!mounted) return;
      if (friends.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No friends yet. Add friends first!')),
        );
        return;
      }
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Invite a friend to navigate together',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            ...friends.map((f) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                  child: Text(f.label[0].toUpperCase(),
                      style: TextStyle(color: Theme.of(ctx).colorScheme.onPrimaryContainer)),
                ),
                title: Text(f.label),
                subtitle: f.email != null ? Text(f.email!) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final sessionId = await _placesApi.inviteToNavigate(
                      f.userId,
                      destinationLat: _navigationDestination?.latitude,
                      destinationLng: _navigationDestination?.longitude,
                      destinationName: _navigationDestination?.name.isEmpty == true
                          ? null
                          : _navigationDestination?.name,
                    );
                    if (!mounted) return;
                    setState(() {
                      _navSessionId = sessionId;
                      _navPartnerName = f.label;
                    });
                    _startNavSessionPolling();
                    _saveNavigationState();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Waiting for ${f.label} to accept...')),
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                      );
                    }
                  }
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      );
    } catch (_) {}
  }

  Future<void> _fetchPartnerRoute(LatLng from, LatLng to) async {
    try {
      final routeData = await RoutingService().getRoute(from, to);
      if (mounted) setState(() => _partnerRoutePolyline = routeData.polyline);
    } catch (_) {}
  }

  void _endNavSession({bool notify = false}) {
    final sessionId = _navSessionId;
    if (sessionId != null) {
      _placesApi.endNavSession(sessionId);
    }
    _navPollTimer?.cancel();
    _navPollTimer = null;
    setState(() {
      _navSessionId = null;
      _navPartnerName = null;
      _partnerLocation = null;
      _navDestination = null;
      _partnerRoutePolyline = [];
      _lastPartnerLocationForRoute = null;
    });
    _saveNavigationState();
    _startInvitePolling();
    if (notify && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navigate together session ended')),
      );
    }
  }

  Future<void> _changeProfilePicture() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final imageFile = await _profileService.pickImage(source);
      if (imageFile != null) {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading profile picture...')),
          );
        }

        try {
          final downloadUrl =
              await _profileService.uploadProfileImage(imageFile);
          if (mounted) {
            setState(() => _profileImageUrl = downloadUrl);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture updated!')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: $e'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    }
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
                      GestureDetector(
                        onTap: _changeProfilePicture,
                        child: CircleAvatar(
                          radius: 32,
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child: _profileImageUrl == null
                              ? const Icon(Icons.person, size: 36)
                              : null,
                        ),
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
                            const SizedBox(height: 2),
                            Text(
                              'Tap avatar to change profile picture',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant.withOpacity(0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isAdmin) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.errorContainer,
                          foregroundColor: cs.onErrorContainer,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminScreen(api: _placesApi),
                            ),
                          );
                        },
                        icon: const Icon(Icons.admin_panel_settings_rounded),
                        label: const Text('Admin Panel'),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FriendsScreen(api: _placesApi),
                              ),
                            );
                          },
                          icon: const Icon(Icons.people_rounded),
                          label: const Text('Friends'),
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
                      // Clear profile image cache on logout
                      await _profileService.clearProfileImageUrl();
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

  void _showAddLocationSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedCategory;
    File? pickedImage;
    double? pickedLat = _currentLatLng?.latitude;
    double? pickedLng = _currentLatLng?.longitude;
    bool submitting = false;

    const categories = [
      ('peak',         'Peak / Mountain',  Icons.landscape_rounded),
      ('lake',         'Lake',             Icons.water_rounded),
      ('cave_entrance','Cave',             Icons.terrain_rounded),
      ('ruin',         'Ruin / Castle',    Icons.account_balance_rounded),
      ('spring',       'Spring',           Icons.water_drop_rounded),
      ('viewpoint',    'Viewpoint',        Icons.remove_red_eye_rounded),
      ('hotel',        'Hotel',            Icons.hotel_rounded),
      ('restaurant',   'Restaurant / Food',Icons.restaurant_rounded),
      ('fuel',         'Gas Station',      Icons.local_gas_station_rounded),
      ('pharmacy',     'Pharmacy',         Icons.local_pharmacy_rounded),
      ('marketplace',  'Market',           Icons.store_rounded),
      ('cafe',         'Café',             Icons.local_cafe_rounded),
      ('bar',          'Bar',              Icons.local_bar_rounded),
      ('museum',       'Museum',           Icons.museum_rounded),
    ];

    showModalBottomSheet<void>(
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
          builder: (ctx, setSheetState) {
            Future<void> submit() async {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a name.')));
                return;
              }
              if (selectedCategory == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please select a category.')));
                return;
              }
              if (pickedLat == null || pickedLng == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please set the location.')));
                return;
              }
              setSheetState(() => submitting = true);
              try {
                final newPlaceId = await _placesApi.submitPlace(
                  name: nameCtrl.text.trim(),
                  category: selectedCategory!,
                  lat: pickedLat!,
                  lng: pickedLng!,
                );
                final desc = descCtrl.text.trim();
                if (desc.isNotEmpty || pickedImage != null) {
                  await _placesApi.createPost(
                    placeId: newPlaceId,
                    content: desc.isNotEmpty ? desc : nameCtrl.text.trim(),
                    image: pickedImage,
                  );
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Place submitted! It will appear on the map shortly.')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  setSheetState(() => submitting = false);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              }
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollCtl) => Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                child: ListView(
                  controller: scrollCtl,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                            color: cs.outlineVariant,
                            borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                    Text('Add a New Place',
                        style: Theme.of(ctx).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    // Name
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Place name *',
                        hintText: 'e.g. Eagle Rock',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Category
                    Text('Category *',
                        style: Theme.of(ctx).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((c) {
                        final selected = selectedCategory == c.$1;
                        return FilterChip(
                          avatar: Icon(c.$3, size: 16,
                              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                          label: Text(c.$2),
                          selected: selected,
                          onSelected: (_) => setSheetState(() => selectedCategory = c.$1),
                          selectedColor: cs.primaryContainer,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Location
                    Text('Location *',
                        style: Theme.of(ctx).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _ensureLocationAndCenter(silent: true);
                            if (_currentLatLng != null) {
                              setSheetState(() {
                                pickedLat = _currentLatLng!.latitude;
                                pickedLng = _currentLatLng!.longitude;
                              });
                            }
                          },
                          icon: const Icon(Icons.my_location_rounded, size: 18),
                          label: const Text('Use my location'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (pickedLat != null)
                        Expanded(
                          child: Text(
                            '${pickedLat!.toStringAsFixed(5)}, ${pickedLng!.toStringAsFixed(5)}',
                            style: Theme.of(ctx).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        Expanded(
                          child: Text('No location set',
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(color: cs.error)),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    // Photo
                    Text('Photo (optional)',
                        style: Theme.of(ctx).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (pickedImage != null)
                      Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(pickedImage!,
                              height: 160, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 6, right: 6,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.white),
                              onPressed: () => setSheetState(() => pickedImage = null),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ])
                    else
                      OutlinedButton.icon(
                        onPressed: () async {
                          final source = await showDialog<ImageSource>(
                            context: ctx,
                            builder: (d) => AlertDialog(
                              title: const Text('Choose source'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(d, ImageSource.camera),
                                    child: const Text('Camera')),
                                TextButton(onPressed: () => Navigator.pop(d, ImageSource.gallery),
                                    child: const Text('Gallery')),
                              ],
                            ),
                          );
                          if (source == null) return;
                          final picked = await ImagePicker().pickImage(
                              source: source, imageQuality: 80, maxWidth: 1200);
                          if (picked != null) {
                            setSheetState(() => pickedImage = File(picked.path));
                          }
                        },
                        icon: const Icon(Icons.add_a_photo_rounded),
                        label: const Text('Add photo'),
                      ),
                    const SizedBox(height: 24),
                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: submitting ? null : submit,
                        icon: submitting
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded),
                        label: Text(submitting ? 'Submitting…' : 'Submit Place'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Route progress bar with waypoint dots ────────────────────────────────

  Widget _buildProgressBar(ColorScheme cs) {
    final progress = _totalRouteDistance > 0
        ? ((_totalRouteDistance - _distanceToDestination) / _totalRouteDistance)
            .clamp(0.0, 1.0)
        : 0.0;

    const trackH = 8.0;
    const dotSize = 22.0;
    const totalH = 30.0;

    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: totalH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track background
              Positioned(
                top: (totalH - trackH) / 2,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(height: trackH, color: cs.outlineVariant),
                ),
              ),
              // Progress fill
              Positioned(
                top: (totalH - trackH) / 2,
                left: 0,
                width: w * progress,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(height: trackH, color: cs.primary),
                ),
              ),
              // Waypoint dots
              ..._waypointFractions.entries.map((e) {
                final place = _routeWaypoints.firstWhere(
                  (wp) => wp.id == e.key,
                  orElse: () => _routeWaypoints.first,
                );
                final left = (w * e.value - dotSize / 2).clamp(0.0, w - dotSize);
                return Positioned(
                  left: left,
                  top: (totalH - dotSize) / 2,
                  child: GestureDetector(
                    onTap: () {
                      _mapController.move(
                        LatLng(place.latitude, place.longitude),
                        _mapController.camera.zoom,
                      );
                      Future.delayed(const Duration(milliseconds: 300), () {
                        _placesLayerKey.currentState?.selectPlace(place);
                      });
                    },
                    child: Tooltip(
                      message: place.name.isEmpty ? place.category : place.name,
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          color: _waypointDotColor(place.category),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(blurRadius: 4, color: Colors.black38),
                          ],
                        ),
                        child: Icon(
                          _waypointDotIcon(place.category),
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Color _waypointDotColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'peak':                          return Colors.deepPurple;
      case 'lake':                          return Colors.blueAccent;
      case 'cave': case 'cave_entrance':    return Colors.brown;
      case 'ruin': case 'ruins':
      case 'archaeological_site':           return Colors.redAccent;
      case 'spring':                        return Colors.teal;
      case 'viewpoint':                     return Colors.indigo;
      default:                              return Colors.orange;
    }
  }

  IconData _waypointDotIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'peak':                          return Icons.landscape;
      case 'lake':                          return Icons.water_rounded;
      case 'cave': case 'cave_entrance':    return Icons.terrain;
      case 'ruin': case 'ruins':
      case 'archaeological_site':           return Icons.account_balance;
      case 'spring':                        return Icons.water_drop;
      case 'viewpoint':                     return Icons.visibility;
      default:                              return Icons.place;
    }
  }

  void _showHelpDialog(BuildContext context) {
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

        Widget section(String title) => Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
              child: Text(title,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
            );

        Widget item(IconData icon, String label, String desc, {Color? color}) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color ?? cs.onSurface, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(desc,
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );

        Widget colorDot(Color c, String label, String desc) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(desc,
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtl) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: ListView(
              controller: scrollCtl,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                Text('Help & Legend',
                    style: Theme.of(ctx)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                section('Top Bar Buttons'),
                item(Icons.location_on_outlined, 'Current Location',
                    'Centers the map on your GPS position.'),
                item(Icons.tune_rounded, 'Filters',
                    'Filter places by type, elevation range, or distance from you. Applying a filter zooms the map out to show results.'),
                item(Icons.auto_awesome_rounded, 'AI Assistant',
                    'Ask the AI to find places for you in natural language — e.g. "show me lakes above 1500m".'),
                item(Icons.person_rounded, 'Profile',
                    'View your profile, change your photo, open Friends, send an S.O.S, or switch theme.'),
                section('Map Icons — Natural Places'),
                colorDot(Colors.blue, 'Lake', 'A natural lake or reservoir.'),
                colorDot(Colors.brown, 'Cave', 'A cave or grotto entrance.'),
                colorDot(Colors.grey, 'Ruin / Castle', 'Historical ruins or castle remains.'),
                colorDot(Colors.orange, 'Peak', 'A mountain summit or peak.'),
                colorDot(Colors.cyan, 'Spring', 'A natural water spring.'),
                colorDot(Colors.green, 'Viewpoint', 'A scenic viewpoint or panorama.'),
                section('Map Icons — Amenities'),
                colorDot(Colors.purple, 'Hotel', 'Accommodation — hotel, hostel or guesthouse.'),
                colorDot(Colors.red, 'Restaurant / Food', 'Restaurants, fast food and eateries.'),
                colorDot(Colors.amber, 'Gas Station', 'Fuel stations for vehicles.'),
                colorDot(Colors.teal, 'Pharmacy', 'Drug stores and pharmacies.'),
                colorDot(Colors.indigo, 'Market', 'Supermarkets and grocery stores.'),
                colorDot(const Color(0xFF795548), 'Café', 'Coffee shops and cafés.'),
                colorDot(Colors.pink, 'Bar', 'Bars and pubs.'),
                colorDot(Colors.deepPurple, 'Museum', 'Museums and cultural sites.'),
                section('Navigation'),
                item(Icons.navigation_rounded, 'Navigate',
                    'Tap any place marker and press Navigate to get a hiking route to it. Your position is kept centered while navigating.'),
                item(Icons.my_location_rounded, 'Re-center',
                    'If you pan the map during navigation this button reappears — tap it to re-lock the map to your position.'),
                item(Icons.people_rounded, 'Navigate Together',
                    'While navigating, invite a friend to join. They\'ll get a notification, and once they accept you can both see each other\'s live position and remaining distance on the route.'),
                section('Other'),
                item(Icons.add, 'Add a Place',
                    'Tap the + button (bottom-left) to suggest a new location. Add a photo, choose the category and drop a pin on the map.'),
                item(Icons.emergency_share_rounded, 'S.O.S',
                    'Found in your Profile. Shares your current GPS coordinates so you can call for help.'),
                item(Icons.people_rounded, 'Friends',
                    'Found in your Profile. Search for users, send friend requests and manage your friends list.'),
                item(Icons.wb_sunny_rounded, 'Weather Forecast',
                    'Tap any place marker, then tap "24h Weather Forecast" to see an hourly temperature and weather conditions timeline for that exact location for the next 24 hours, powered by Open-Meteo.'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFiltersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
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
              minChildSize: 0.75,
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
                      const SizedBox(height: 14),
                      // Natural places sub-section
                      Row(children: [
                        Icon(Icons.landscape_rounded, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Text('Natural Places',
                            style: Theme.of(ctx).textTheme.labelMedium
                                ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['peak','lake','cave','ruin','spring','viewpoint'].map((category) {
                          final isSelected = _selectedCategories.contains(category);
                          return FilterChip(
                            label: Text(_formatCategoryName(category)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) { _selectedCategories.add(category); }
                                else { _selectedCategories.remove(category); }
                              });
                              this.setState(() {});
                            },
                            backgroundColor: Theme.of(ctx).colorScheme.surface,
                            selectedColor: Theme.of(ctx).colorScheme.primaryContainer,
                            side: BorderSide(color: isSelected ? Theme.of(ctx).colorScheme.primary : cs.outline),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Amenities sub-section
                      Row(children: [
                        Icon(Icons.storefront_rounded, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Text('Amenities',
                            style: Theme.of(ctx).textTheme.labelMedium
                                ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['hotel','restaurant','fuel','pharmacy','marketplace','cafe','bar','museum'].map((category) {
                          final isSelected = _selectedCategories.contains(category);
                          return FilterChip(
                            label: Text(_formatCategoryName(category)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) { _selectedCategories.add(category); }
                                else { _selectedCategories.remove(category); }
                              });
                              this.setState(() {});
                            },
                            backgroundColor: Theme.of(ctx).colorScheme.surface,
                            selectedColor: Theme.of(ctx).colorScheme.primaryContainer,
                            side: BorderSide(color: isSelected ? Theme.of(ctx).colorScheme.primary : cs.outline),
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
                                  'Note: Places with no data about their height will not appear on the map.',
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
                        onPressed: () {
                          Navigator.pop(ctx);
                          final hasFilters = _selectedCategories.isNotEmpty ||
                              _minElevation != null ||
                              _maxElevation != null ||
                              _maxDistanceKm != null ||
                              _showAllLocations;
                          if (hasFilters) {
                            final center = _currentLatLng ?? _mapController.camera.center;
                            _mapController.move(center, 10.0);
                          }
                        },
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
    const names = {
      'peak': 'Peak',
      'lake': 'Lake',
      'cave': 'Cave',
      'ruin': 'Ruin / Castle',
      'spring': 'Spring',
      'viewpoint': 'Viewpoint',
      'hotel': 'Hotel',
      'restaurant': 'Restaurant',
      'fuel': 'Gas Station',
      'pharmacy': 'Pharmacy',
      'marketplace': 'Market',
      'cafe': 'Café',
      'bar': 'Bar',
      'museum': 'Museum',
    };
    return names[category] ??
        category.replaceAll('_', ' ').split(' ')
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
  }
}

// ----------------------------------------------------------
// Partner location marker (green pin with initial)
// ----------------------------------------------------------

class _PartnerMarker extends StatelessWidget {
  final String name;
  const _PartnerMarker({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        Container(width: 3, height: 8, color: Colors.green.shade600),
        Container(width: 8, height: 3, color: Colors.green.shade600),
      ],
    );
  }
}

// ----------------------------------------------------------
// Current location indicator widget with subtle pulse
// ----------------------------------------------------------

class _CurrentLocationIndicator extends StatefulWidget {
  const _CurrentLocationIndicator();

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
