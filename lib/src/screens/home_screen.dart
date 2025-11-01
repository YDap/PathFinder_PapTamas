import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- Map state ---
  final MapController _mapController = MapController();
  // Start roughly in Romania center (you can change anytime)
  LatLng _initialCenter = const LatLng(45.9432, 24.9668);
  double _initialZoom = 6.5;

  // Current user position marker (optional)
  LatLng? _currentLatLng;

  @override
  void initState() {
    super.initState();
    // Optionally try to fetch location on startup (silent; user can tap button too)
    _ensureLocationAndCenter(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: FilledButton.tonalIcon(
            onPressed: _ensureLocationAndCenter,
            icon: const Icon(Icons.location_on_outlined),
            label: const Text('Current location'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        actions: [
          // Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: IconButton.filledTonal(
              tooltip: 'Filters',
              onPressed: () {
                // TODO: open filters
              },
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
          // Profile
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton.filled(
              tooltip: 'Profile',
              onPressed: () => _openProfileSheet(context),
              icon: const Icon(Icons.person_rounded),
              style: IconButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
            ),
          ),
        ],
      ),

      // --- Actual map back again ---
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              // onMapReady: () { ... } // optional
            ),
            children: [
              // OSM tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.pathfinder_app', // <-- change to your package if needed
              ),

              // Optional marker for user's current location
              if (_currentLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLatLng!,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.85),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // (Optional) small helper chip to show status
          // if you like to display that location is centered etc.
        ],
      ),
    );
  }

  // ---------------- Helpers ----------------

  /// Requests permission (if needed), gets the current position and moves the map there.
  Future<void> _ensureLocationAndCenter({bool silent = false}) async {
    try {
      // Check & request permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Location permission is permanently denied')),
          );
        }
        return;
      }

      // GPS enabled?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable Location Services')),
          );
        }
        return;
      }

      // Get current position
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _currentLatLng = latLng;
      });

      // Center map
      _mapController.move(latLng, 15);
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    }
  }

  /// Opens the profile panel as a modal bottom sheet.
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

                  // Avatar + name/email
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
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Quick actions row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: open stats screen
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text('Stats coming soon')),
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
                            // TODO: SOS feature (share location/call/etc.)
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('S.O.S pressed')),
                            );
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
                    leading: Icon(Icons.logout_rounded, color: cs.error),
                    title: const Text('Log out'),
                    onTap: () async {
                      await auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pop(); // close sheet
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
}
