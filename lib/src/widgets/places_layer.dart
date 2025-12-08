import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/places_api.dart';

class PlacesLayer extends StatefulWidget {
  final MapController mapController;
  final PlacesApi api;
  final int limit;

  const PlacesLayer({
    super.key,
    required this.mapController,
    required this.api,
    this.limit = 1000,
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
      if (bounds == null) return;

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
        return Colors.brown;
      case 'ruin':
        return Colors.grey;
      case 'waterfall':
        return Colors.lightBlueAccent;
      case 'peak':
        return Colors.deepPurple;
      case 'shelter':
        return Colors.green;
      case 'spring':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = _places
        .map(
          (p) => Marker(
            point: LatLng(p.latitude, p.longitude),
            width: 30,
            height: 30,
            child: Tooltip(
              message: '${p.name.isEmpty ? "Unknown" : p.name} (${p.category})',
              waitDuration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  color: _colorFor(p.category).withOpacity(0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(blurRadius: 4, color: Colors.black26)
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();

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
      label: Row(mainAxisSize: MainAxisSize.min, children: const [
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
