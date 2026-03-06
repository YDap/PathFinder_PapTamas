import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/places_api.dart';
import '../services/sos_service.dart';
import '../widgets/places_layer.dart';
import '../services/auth_service.dart';
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

  LatLng _initialCenter = const LatLng(45.9432, 24.9668);
  double _initialZoom = 6.5;
  LatLng? _currentLatLng;

  // Filter state
  Set<String> _selectedCategories = {};
  int? _minElevation;
  int? _maxElevation;

  // All available categories
  final List<String> _allCategories = [
    'lake',
    'cave',
    'ruin',
    'ruins',
    'archaeological_site',
    'waterfall',
    'peak',
    'shelter',
    'spring',
  ];

  // Text controllers for elevation inputs
  late TextEditingController _minElevationController;
  late TextEditingController _maxElevationController;

  @override
  void initState() {
    super.initState();
    _minElevationController = TextEditingController();
    _maxElevationController = TextEditingController();
    _ensureLocationAndCenter(silent: true);
  }

  @override
  void dispose() {
    _minElevationController.dispose();
    _maxElevationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
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
              ),
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
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
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
                              this.setState(() {
                                if (selected) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                              });
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
                                this.setState(() {
                                  _minElevation = int.tryParse(value);
                                });
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
                                this.setState(() {
                                  _maxElevation = int.tryParse(value);
                                });
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
                          this.setState(() {
                            _selectedCategories.clear();
                            _minElevation = null;
                            _maxElevation = null;
                            _minElevationController.clear();
                            _maxElevationController.clear();
                          });
                        },
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Clear All Filters'),
                      ),
                      const SizedBox(height: 16),

                      // Active Filters Summary
                      if (_selectedCategories.isNotEmpty ||
                          _minElevation != null ||
                          _maxElevation != null)
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
                              const SizedBox(height: 8),
                              Text(
                                '💡 Note: Places without elevation data will always be shown.',
                                style:
                                    Theme.of(ctx).textTheme.bodySmall?.copyWith(
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
