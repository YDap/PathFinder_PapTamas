import 'package:flutter/material.dart';
import '../services/weather_service.dart';

class WeatherSheet extends StatefulWidget {
  final String placeName;
  final double latitude;
  final double longitude;

  const WeatherSheet({
    super.key,
    required this.placeName,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<WeatherSheet> createState() => _WeatherSheetState();
}

class _WeatherSheetState extends State<WeatherSheet> {
  final _scrollController = ScrollController();
  List<HourlyWeather>? _hours;
  String? _error;

  static const double _cardWidth = 68;
  static const double _cardSpacing = 6;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final data = await WeatherService().fetchHourly(widget.latitude, widget.longitude);
      if (!mounted) return;
      setState(() => _hours = data);
      // Scroll to current hour after layout
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _scrollToNow() {
    if (!_scrollController.hasClients || _hours == null) return;
    final now = DateTime.now();
    final idx = _hours!.indexWhere((h) => h.time.hour == now.hour && h.time.day == now.day);
    if (idx > 0) {
      _scrollController.animateTo(
        idx * (_cardWidth + _cardSpacing),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final name = widget.placeName.isEmpty ? 'This place' : widget.placeName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // Header row
          Row(
            children: [
              Icon(Icons.wb_sunny_rounded, color: Colors.amber.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Next 24 hours',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Current conditions summary (when loaded)
          if (_hours != null) _buildCurrentSummary(cs, now),

          const SizedBox(height: 16),

          // Timeline
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: cs.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Could not load weather: $_error',
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                ],
              ),
            )
          else if (_hours == null)
            const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              height: 118,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: _hours!.length,
                separatorBuilder: (_, __) => const SizedBox(width: _cardSpacing),
                itemBuilder: (ctx, i) {
                  final h = _hours![i];
                  final isNow = h.time.hour == now.hour && h.time.day == now.day;
                  return _HourCard(hour: h, isNow: isNow, cs: cs);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentSummary(ColorScheme cs, DateTime now) {
    final current = _hours!.firstWhere(
      (h) => h.time.hour == now.hour && h.time.day == now.day,
      orElse: () => _hours!.first,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            WeatherService.emojiFor(current.weatherCode),
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${current.temperature.round()}°C',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                WeatherService.labelFor(current.weatherCode),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_hours!.map((h) => h.temperature).reduce((a, b) => a > b ? a : b).round()}° high',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                '${_hours!.map((h) => h.temperature).reduce((a, b) => a < b ? a : b).round()}° low',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourCard extends StatelessWidget {
  final HourlyWeather hour;
  final bool isNow;
  final ColorScheme cs;

  const _HourCard({required this.hour, required this.isNow, required this.cs});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 68,
      decoration: BoxDecoration(
        color: isNow ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: isNow ? Border.all(color: cs.primary, width: 1.5) : null,
        boxShadow: isNow
            ? [BoxShadow(color: cs.primary.withValues(alpha: 0.2), blurRadius: 6)]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isNow ? 'Now' : '${hour.time.hour.toString().padLeft(2, '0')}:00',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
              color: isNow ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            WeatherService.emojiFor(hour.weatherCode),
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(height: 7),
          Text(
            '${hour.temperature.round()}°',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isNow ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
