import 'dart:async';

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
  // How long the hint stays on screen. This is driven by a wall-clock Timer
  // rather than the AnimationController on purpose: on devices with a
  // reduced-motion accessibility setting, battery saver, or a non-default
  // "animator duration scale" (developer options), Flutter collapses an
  // AnimationController to near-instant. That made the hint flash and vanish
  // in under a second for some users while looking fine on a default 1x phone.
  // A Timer is unaffected by those settings, so the dwell time is consistent.
  static const Duration _dwell = Duration(milliseconds: 4800);
  static const Duration _fade = Duration(milliseconds: 280);

  late final AnimationController _ctrl; // drives the pinch gesture loop only
  late final Animation<double> _pinch;
  Timer? _fadeOutTimer;
  Timer? _doneTimer;
  double _opacity = 0;
  bool _gestureStarted = false;

  @override
  void initState() {
    super.initState();
    // One pinch-in/out cycle; repeated below while the gesture is visible.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pinch = Tween<double>(begin: 1.0, end: 0.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_ctrl);

    // Fade in next frame, hold, then fade out and finish — all on a real clock.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
    _fadeOutTimer = Timer(_dwell - _fade, () {
      if (mounted) setState(() => _opacity = 0);
    });
    _doneTimer = Timer(_dwell, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only loop the pinch gesture when the platform actually plays animations.
    // If animations are disabled, repeat() would otherwise spin every frame;
    // we leave the fingers in a readable static position instead.
    if (!_gestureStarted && !MediaQuery.of(context).disableAnimations) {
      _gestureStarted = true;
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _fadeOutTimer?.cancel();
    _doneTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: _fade,
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
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) => _buildGesture(cs),
                  ),
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
    // When the gesture loop isn't running (animations disabled) the controller
    // stays at 0; show the fingers part-way apart so the hint still reads.
    final pinchValue = _gestureStarted ? _pinch.value : 0.5;
    final spread = 8.0 + pinchValue * maxSpread;
    final moving = _gestureStarted && pinchValue > 0.02 && pinchValue < 0.98;

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
