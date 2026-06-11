import 'package:flutter/material.dart';

/// Brief overlay shown after Apply Filters — two finger dots pinching
/// together to hint the user to zoom out and see the filtered results.
class ZoomOutHintOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const ZoomOutHintOverlay({super.key, required this.onDone});

  @override
  State<ZoomOutHintOverlay> createState() => _ZoomOutHintOverlayState();
}

class _ZoomOutHintOverlayState extends State<ZoomOutHintOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _pinch;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _fade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 72),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
    ]).animate(_ctrl);

    // 1.0 = fingers far apart, 0.0 = fingers together. Runs twice so the
    // pinch-in motion is clearly readable as "zoom out".
    _pinch = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 12),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 8),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 12),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Opacity(
        opacity: _fade.value,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xF22A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Filters applied! 🏕️',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGesture(cs),
                  const SizedBox(height: 12),
                  Text(
                    'Pinch to zoom out and explore the results',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGesture(ColorScheme cs) {
    const fingerR = 11.0;
    const maxSpread = 36.0;
    final spread = 8.0 + _pinch.value * maxSpread;
    final moving = _pinch.value > 0.02 && _pinch.value < 0.98;

    return SizedBox(
      width: 130,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inward arrows between the fingers (pinch-in = zoom out)
          Opacity(
            opacity: moving ? 0.7 : 0.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 11, color: cs.primary),
                const SizedBox(width: 22),
                Icon(Icons.arrow_back_ios_rounded,
                    size: 11, color: cs.primary),
              ],
            ),
          ),
          // Left finger dot
          Transform.translate(
            offset: Offset(-spread, 0),
            child: Container(
              width: fingerR * 2,
              height: fingerR * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary,
                border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3), width: 3),
              ),
            ),
          ),
          // Right finger dot
          Transform.translate(
            offset: Offset(spread, 0),
            child: Container(
              width: fingerR * 2,
              height: fingerR * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary,
                border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3), width: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
