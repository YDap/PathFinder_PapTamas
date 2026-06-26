import 'package:flutter/material.dart';

/// Overlay shown after Apply Filters — stays visible until the user taps anywhere.
class ZoomOutHintOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const ZoomOutHintOverlay({super.key, required this.onDone});

  @override
  State<ZoomOutHintOverlay> createState() => _ZoomOutHintOverlayState();
}

class _ZoomOutHintOverlayState extends State<ZoomOutHintOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _fade = Duration(milliseconds: 280);

  late final AnimationController _ctrl;
  late final Animation<double> _pinch;
  double _opacity = 0;
  bool _gestureStarted = false;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pinch = Tween<double>(begin: 1.0, end: 0.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_ctrl);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    setState(() => _opacity = 0);
    Future.delayed(_fade, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_gestureStarted && !MediaQuery.of(context).disableAnimations) {
      _gestureStarted = true;
      _ctrl.repeat(reverse: true);
    }
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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismiss,
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
                    'Tap anywhere to explore the results',
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
    final pinchValue = _gestureStarted ? _pinch.value : 0.5;
    final spread = 8.0 + pinchValue * maxSpread;
    final moving = _gestureStarted && pinchValue > 0.02 && pinchValue < 0.98;

    return SizedBox(
      width: 130,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
