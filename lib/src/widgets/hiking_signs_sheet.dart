import 'package:flutter/material.dart';

/// Bottom sheet explaining the Romanian hiking trail markings (marcaje
/// turistice) — the painted signs hikers see on trees, rocks and poles.
/// All signs are drawn with painters so they stay crisp at any size.
class HikingSignsSheet extends StatelessWidget {
  const HikingSignsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const HikingSignsSheet(),
    );
  }

  // The three official marking colours used in Romania.
  static const _markColors = <Color>[
    Color(0xFFD32F2F), // red
    Color(0xFF1565C0), // blue
    Color(0xFFF9A825), // yellow
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtl) => Padding(
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
            Text('🥾 Hiking Trail Signs',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Marcaje turistice — Romania',
                style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Text(
              'Romanian trails are marked with painted symbols on trees, rocks '
              'and poles. Each route uses one symbol in one colour, repeated '
              'along the whole way — if you keep seeing it, you are on the '
              'right trail. 🌲',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),

            _shapeCard(
              ctx,
              shape: TrailMarkShape.stripe,
              title: 'Vertical stripe',
              romanian: 'Bandă verticală',
              description:
                  'Main route — a long "backbone" trail, usually following the '
                  'main mountain ridge.',
            ),
            _shapeCard(
              ctx,
              shape: TrailMarkShape.cross,
              title: 'Cross',
              romanian: 'Cruce',
              description:
                  'Connecting route — a link trail that joins two main routes '
                  'together.',
            ),
            _shapeCard(
              ctx,
              shape: TrailMarkShape.triangle,
              title: 'Triangle',
              romanian: 'Triunghi',
              description:
                  'Secondary route — branches off a main trail, often leading '
                  'to a peak, a mountain hut or a sight.',
            ),
            _shapeCard(
              ctx,
              shape: TrailMarkShape.dot,
              title: 'Dot',
              romanian: 'Punct',
              description:
                  'Circuit route — a loop trail that brings you back to where '
                  'you started.',
            ),

            const SizedBox(height: 4),
            _infoBox(
              ctx,
              icon: Icons.palette_outlined,
              child:
                  'Every symbol comes in red, blue or yellow, always painted on '
                  'a white square. The colour identifies a specific route, so '
                  'several trails can share the same path without confusion. '
                  'The white background is part of the official mark.',
            ),
            const SizedBox(height: 20),

            Text('At junctions',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Yellow arrow boards (săgeți indicatoare) at trailheads and '
              'junctions show the destination, the trail mark to follow and '
              'the estimated walking time:',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 10),
            const _SignpostExample(
              shape: TrailMarkShape.stripe,
              color: Color(0xFFD32F2F),
              label: 'Vf. Omu — 2½–3 h',
            ),
            const SizedBox(height: 6),
            const _SignpostExample(
              shape: TrailMarkShape.triangle,
              color: Color(0xFF1565C0),
              label: 'Cabana Mălăiești — 1½ h',
            ),
            const SizedBox(height: 20),

            Text('Above the treeline',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CustomPaint(
                  size: Size(44, 96),
                  painter: _MarkingPolePainter(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'In the alpine zone the marks are painted on metal poles '
                    '(stâlpi de marcaj) so the route stays visible in fog and '
                    'snow. In bad weather never leave the line of poles — they '
                    'are placed within sight of each other.',
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('Good to know',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _tip(ctx, Icons.straighten,
                'Marks repeat roughly every 100–200 m. At forks, spot the next mark before walking on.'),
            _tip(ctx, Icons.u_turn_left,
                'No mark for several minutes? Walk back to the last one you saw and look again.'),
            _tip(ctx, Icons.schedule,
                'Times on signposts assume a steady pace without long breaks.'),
            _tip(ctx, Icons.emergency_outlined,
                'Emergency: call 112, or Salvamont (mountain rescue) directly at 0725 826 668.'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _shapeCard(
    BuildContext context, {
    required TrailMarkShape shape,
    required String title,
    required String romanian,
    required String description,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          for (final c in _markColors) ...[
            TrailMarkBadge(shape: shape, color: c, size: 44),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$title • $romanian',
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(description,
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(BuildContext context,
      {required IconData icon, required String child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(child, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _tip(BuildContext context, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

enum TrailMarkShape { stripe, cross, triangle, dot }

/// A single trail mark: coloured symbol on the official white square.
class TrailMarkBadge extends StatelessWidget {
  final TrailMarkShape shape;
  final Color color;
  final double size;

  const TrailMarkBadge({
    super.key,
    required this.shape,
    required this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(blurRadius: 3, color: Colors.black12, offset: Offset(0, 1)),
        ],
      ),
      child: CustomPaint(painter: _TrailMarkPainter(shape, color)),
    );
  }
}

class _TrailMarkPainter extends CustomPainter {
  final TrailMarkShape shape;
  final Color color;
  const _TrailMarkPainter(this.shape, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final pad = size.width * 0.22;
    final inner = Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (shape) {
      case TrailMarkShape.stripe:
        final w = inner.width / 2.6;
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(cx, cy), width: w, height: inner.height),
            paint);
      case TrailMarkShape.cross:
        final arm = inner.width / 2.6;
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(cx, cy), width: arm, height: inner.height),
            paint);
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(cx, cy), width: inner.width, height: arm),
            paint);
      case TrailMarkShape.triangle:
        final path = Path()
          ..moveTo(cx, inner.top)
          ..lineTo(inner.right, inner.bottom)
          ..lineTo(inner.left, inner.bottom)
          ..close();
        canvas.drawPath(path, paint);
      case TrailMarkShape.dot:
        canvas.drawCircle(Offset(cx, cy), inner.width / 2.4, paint);
    }
  }

  @override
  bool shouldRepaint(_TrailMarkPainter old) =>
      old.shape != shape || old.color != color;
}

/// A yellow direction board with a pointed tip, like the real signposts.
class _SignpostExample extends StatelessWidget {
  final TrailMarkShape shape;
  final Color color;
  final String label;

  const _SignpostExample({
    required this.shape,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipPath(
        clipper: _ArrowBoardClipper(),
        child: Container(
          color: const Color(0xFFFBC02D),
          padding: const EdgeInsets.fromLTRB(10, 7, 26, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrailMarkBadge(shape: shape, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowBoardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const tip = 14.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - tip, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - tip, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Alpine marking pole: striped post with a marked plate on top.
class _MarkingPolePainter extends CustomPainter {
  const _MarkingPolePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const poleW = 7.0;
    const plate = 24.0;
    const poleTop = plate + 2;

    // Striped pole (red/white bands)
    final bandH = (size.height - poleTop) / 5;
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(
        Rect.fromLTWH(cx - poleW / 2, poleTop + i * bandH, poleW, bandH),
        Paint()
          ..color =
              i.isEven ? const Color(0xFFD32F2F) : const Color(0xFFFAFAFA),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(cx - poleW / 2, poleTop, poleW, size.height - poleTop),
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke,
    );

    // Plate with a red stripe mark
    final plateRect = Rect.fromCenter(
        center: Offset(cx, plate / 2 + 1), width: plate, height: plate);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plateRect, const Radius.circular(4)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plateRect, const Radius.circular(4)),
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke,
    );
    canvas.drawRect(
      Rect.fromCenter(
          center: plateRect.center, width: plate / 3.2, height: plate * 0.58),
      Paint()..color = const Color(0xFFD32F2F),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
