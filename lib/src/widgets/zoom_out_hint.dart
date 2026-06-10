import 'package:flutter/material.dart';

/// Brief overlay shown after Apply Filters — two finger dots spreading apart
/// to hint the user to pinch/zoom out and see the filtered results.
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
  late final Animation<double> _spread;
  late final Animation<double> _ripple;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
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

    _spread = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 10),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 62,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 28),
    ]).animate(_ctrl);

    _ripple = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 10),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 62,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 28),
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Opacity(
        opacity: _fade.value,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xEE1a1a2e),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGesture(),
                  const SizedBox(height: 14),
                  const Text(
                    'Zoom out to see filtered results',
                    style: TextStyle(
                      color: Colors.white70,
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

  Widget _buildGesture() {
    const fingerR = 12.0;
    const maxSpread = 36.0;
    final spread = _spread.value * maxSpread;
    final rippleExtra = _ripple.value * 14.0;
    final rippleOpacity = (1.0 - _ripple.value).clamp(0.0, 1.0) * 0.45;

    return SizedBox(
      width: 130,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outward arrows between fingers
          Opacity(
            opacity: (_spread.value * 2).clamp(0.0, 1.0) * 0.6,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_rounded,
                    size: 11, color: Colors.white54),
                SizedBox(width: 18),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 11, color: Colors.white54),
              ],
            ),
          ),
          // Left ripple
          Transform.translate(
            offset: Offset(-spread, 0),
            child: Opacity(
              opacity: rippleOpacity,
              child: Container(
                width: (fingerR + rippleExtra) * 2,
                height: (fingerR + rippleExtra) * 2,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
              ),
            ),
          ),
          // Right ripple
          Transform.translate(
            offset: Offset(spread, 0),
            child: Opacity(
              opacity: rippleOpacity,
              child: Container(
                width: (fingerR + rippleExtra) * 2,
                height: (fingerR + rippleExtra) * 2,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
              ),
            ),
          ),
          // Left finger dot
          Transform.translate(
            offset: Offset(-spread, 0),
            child: Container(
              width: fingerR * 2,
              height: fingerR * 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
          // Right finger dot
          Transform.translate(
            offset: Offset(spread, 0),
            child: Container(
              width: fingerR * 2,
              height: fingerR * 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
