import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/places_api.dart';

/// Modal bottom sheet that lets the user ask the AI for place recommendations.
/// [onShowOnMap] is called with a Place when the user taps "Show on map",
/// so the home screen can pan the map to it.
class AiChatSheet extends StatefulWidget {
  final PlacesApi api;
  final LatLng? currentLocation;
  final void Function(Place place) onShowOnMap;

  const AiChatSheet({
    super.key,
    required this.api,
    required this.currentLocation,
    required this.onShowOnMap,
  });

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends State<AiChatSheet> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = false;
  String? _errorMessage;
  AiQueryResult? _result;

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final msg = _inputController.text.trim();
    if (msg.isEmpty) return;

    if (widget.currentLocation == null) {
      setState(() {
        _errorMessage = 'Location not available. Tap "Current location" on the map first.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _result = null;
    });

    _focusNode.unfocus();

    try {
      final result = await widget.api.queryAI(
        message: msg,
        lat: widget.currentLocation!.latitude,
        lng: widget.currentLocation!.longitude,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  // ── Category helpers (mirrors places_layer.dart) ──────────
  Color _colorFor(String category) {
    switch (category.toLowerCase()) {
      case 'lake':
        return Colors.blueAccent;
      case 'cave':
        return Colors.brown;
      case 'ruin':
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
        return Icons.pool;
      case 'cave':
        return Icons.terrain;
      case 'ruin':
        return Icons.account_balance;
      case 'peak':
        return Icons.landscape;
      case 'spring':
        return Icons.water_drop;
      case 'viewpoint':
        return Icons.visibility;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Handle bar ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Header ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: cs.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'AI Assistant',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Input row ────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Show me ruins within 60km, best rated',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      minimumSize: const Size(48, 48),
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
            // ── Results area ─────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _buildBody(cs),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: cs.error),
              ),
            ),
          ],
        ),
      );
    }

    if (_result == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.search, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Ask me to find places for you.\nTry: "lakes above 800m" or "best rated viewpoints near me"',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final result = _result!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI message bubble
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome,
                  size: 18, color: cs.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.message,
                  style: TextStyle(color: cs.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
        if (result.places.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No places found matching those criteria. Try broader filters.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          )
        else
          ...result.places.map((place) => _PlaceCard(
                place: place,
                color: _colorFor(place.category),
                icon: _iconFor(place.category),
                onShowOnMap: () {
                  Navigator.of(context).pop();
                  widget.onShowOnMap(place);
                },
              )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Place card for AI results
// ─────────────────────────────────────────────────────────────
class _PlaceCard extends StatelessWidget {
  final Place place;
  final Color color;
  final IconData icon;
  final VoidCallback onShowOnMap;

  const _PlaceCard({
    required this.place,
    required this.color,
    required this.icon,
    required this.onShowOnMap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRating = (place.averageRating ?? 0) > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category icon circle
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            // Name + details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      _Chip(
                        label: place.category,
                        color: color,
                      ),
                      if (place.elevationM != null)
                        _Chip(
                          label: '${place.elevationM} m',
                          icon: Icons.terrain,
                          color: cs.outline,
                        ),
                      if (hasRating)
                        _Chip(
                          label:
                              '${place.averageRating!.toStringAsFixed(1)} ★  (${place.ratingCount})',
                          color: Colors.amber.shade700,
                        ),
                      if (place.distanceKm != null)
                        _Chip(
                          label: '${place.distanceKm!.toStringAsFixed(1)} km',
                          icon: Icons.near_me,
                          color: cs.outline,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Show on map button
            IconButton(
              tooltip: 'Show on map',
              onPressed: onShowOnMap,
              icon: Icon(Icons.map_outlined, color: cs.primary),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const _Chip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
        ],
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
}
