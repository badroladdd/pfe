import 'dart:math';
import 'package:flutter/material.dart';

const _kBlue = Color(0xFF3B82F6);

// ─── Overlay wrapper ─────────────────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message = 'Recherche de vols…',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(child: _AirplaneLoadingScreen(message: message)),
      ],
    );
  }
}

// ─── Full-screen loading ──────────────────────────────────────────────────────

class _AirplaneLoadingScreen extends StatefulWidget {
  final String message;
  const _AirplaneLoadingScreen({required this.message});

  @override
  State<_AirplaneLoadingScreen> createState() => _AirplaneLoadingScreenState();
}

class _AirplaneLoadingScreenState extends State<_AirplaneLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    const radius = 72.0;

    return Container(
      color: Colors.black.withValues(alpha: 0.48),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Animation ─────────────────────────────────────────────
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  final t = _ctrl.value;
                  // Airplane position: start top (-π/2), clockwise
                  final trailAngle = 2 * pi * t - pi / 2;
                  // Plane is slightly ahead of the trail start
                  const lead = 0.18;
                  final planeAngle = trailAngle + lead;
                  final planeX = size / 2 + radius * cos(planeAngle);
                  final planeY = size / 2 + radius * sin(planeAngle);
                  // Icons.flight points NORTH by default.
                  // Tangent for CW motion = planeAngle + π/2.
                  // To align: rotation = tangent - (-π/2) = planeAngle + π
                  final iconAngle = planeAngle + pi;

                  return SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      children: [
                        // Dot trail (CustomPaint)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DotTrailPainter(
                              progress: t,
                              radius: radius,
                              center: const Offset(size / 2, size / 2),
                            ),
                          ),
                        ),
                        // Airplane icon
                        Positioned(
                          left: planeX - 20,
                          top:  planeY - 20,
                          child: Transform.rotate(
                            angle: iconAngle,
                            child: const Icon(
                              Icons.flight,
                              color: _kBlue,
                              size: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              Text(
                widget.message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Recherche des meilleurs tarifs…',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dot trail painter ────────────────────────────────────────────────────────

class _DotTrailPainter extends CustomPainter {
  final double progress;
  final double radius;
  final Offset center;

  const _DotTrailPainter({
    required this.progress,
    required this.radius,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const numDots = 28;
    // Trail covers ~320° behind the airplane
    const trailSweep = 320 * pi / 180;

    final planeAngle = 2 * pi * progress - pi / 2;

    for (int i = 1; i <= numDots; i++) {
      // t=0 → nearest dot to plane, t=1 → farthest
      final t = i / numDots;

      final dotAngle = planeAngle - t * trailSweep;
      final dx = center.dx + radius * cos(dotAngle);
      final dy = center.dy + radius * sin(dotAngle);

      // Dot size: large near plane (6px), tiny far (1px)
      final dotRadius = 6.0 * (1 - t) + 1.0;
      // Opacity: full near plane, fades to 0
      final opacity = (1 - t).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = _kBlue.withValues(alpha: opacity * 0.85)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dx, dy), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotTrailPainter old) => old.progress != progress;
}
