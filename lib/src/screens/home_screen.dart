import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Térkép vezérlő a kameramozgatáshoz
  final MapController _mapController = MapController();

  // Kezdő nézet: Románia közepe körül
  static const LatLng _initialCenter = LatLng(45.9432, 24.9668);
  static const double _initialZoom = 6.5;

  LatLng? _current; // ide mentjük az aktuális pozíciót (ha megvan)
  bool _locating = false;

  Future<void> _goToCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      // 1) Szolgáltatás bekapcsolva?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showSnack('Kapcsold be a helymeghatározást (GPS).');
        }
        setState(() => _locating = false);
        return;
      }

      // 2) Engedélyek
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) _showSnack('Helyhozzáférés megtagadva.');
        setState(() => _locating = false);
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showSnack(
              'Helyhozzáférés végleg megtagadva. Engedélyezd a Beállításokban.');
        }
        setState(() => _locating = false);
        return;
      }

      // 3) Pozíció lekérése
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      final target = LatLng(pos.latitude, pos.longitude);

      // 4) Térkép mozgatása
      _mapController.move(target, 14.0);

      // 5) Marker állapotba
      setState(() {
        _current = target;
        _locating = false;
      });
    } catch (e) {
      setState(() => _locating = false);
      if (mounted) _showSnack('Hiba a helylekéréskor: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── OSM térkép ─────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
            ),
            children: [
              TileLayer(
                // Fejlesztéshez: OSM public tiles. Prod: szolgáltató / saját szerver.
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.pathfinder',
              ),
              // Csak akkor rajzolunk markert, ha van aktuális pozíció
              if (_current != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _current!,
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFE23A3A),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 7,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── FELSŐ UI: Current Location + Filter + Profile ──────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _LocationChip(
                    label: _locating ? 'Locating…' : 'Current Location',
                    onTap: _goToCurrentLocation,
                    loading: _locating,
                  ),
                  const Spacer(),
                  _IconPill(
                    icon: Icons.filter_list_rounded,
                    onTap: () {},
                  ),
                  const SizedBox(width: 10),
                  _IconPill(
                    icon: Icons.person_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // ── Attribution (OSM licenc) ───────────────────────────────────────
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: SafeArea(
              top: false,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Helpers ───────────────────────────

class _LocationChip extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _LocationChip({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_rounded,
                  size: 18, color: Color(0xFFE23A3A)),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (loading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconPill({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: const Color(0xFF0F172A)),
        ),
      ),
    );
  }
}
