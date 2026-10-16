// lib/widgets/animated_brand_background.dart
// Fond animé (dégradé qui respire + halos lumineux + icônes flottantes).
// 100 % Flutter : aucune vidéo à télécharger, donc léger pour les connexions
// mobiles et identique sur Android, iOS et web.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedBrandBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBrandBackground({super.key, required this.child});

  @override
  State<AnimatedBrandBackground> createState() => _AnimatedBrandBackgroundState();
}

class _AnimatedBrandBackgroundState extends State<AnimatedBrandBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _icons = <_FloatIcon>[
    _FloatIcon(Icons.home_rounded, 0.12, 0.18, 34, 1),
    _FloatIcon(Icons.directions_car_rounded, 0.78, 0.12, 30, 2),
    _FloatIcon(Icons.apartment_rounded, 0.86, 0.46, 38, 1),
    _FloatIcon(Icons.key_rounded, 0.08, 0.62, 28, 2),
    _FloatIcon(Icons.two_wheeler_rounded, 0.70, 0.80, 30, 1),
    _FloatIcon(Icons.hotel_rounded, 0.30, 0.88, 28, 2),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 24));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respecte le réglage « réduire les animations » du système.
    if (MediaQuery.of(context).disableAnimations) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(painter: _BackgroundPainter(_ctrl.value)),
          ),
        ),
        RepaintBoundary(
          child: LayoutBuilder(
            builder: (_, box) => AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final a = _ctrl.value * 2 * math.pi;
                return Stack(
                  children: [
                    for (final ic in _icons)
                      Positioned(
                        left: box.maxWidth * ic.x - ic.size / 2 +
                            math.cos(a * ic.speed) * 10,
                        top: box.maxHeight * ic.y - ic.size / 2 +
                            math.sin(a * ic.speed + ic.x * 6) * 18,
                        child: Icon(ic.icon, size: ic.size, color: Colors.white.withOpacity(0.16)),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _FloatIcon {
  final IconData icon;
  final double x, y, size;
  final int speed; // entier → boucle parfaitement fluide
  const _FloatIcon(this.icon, this.x, this.y, this.size, this.speed);
}

class _BackgroundPainter extends CustomPainter {
  final double t; // 0..1, boucle continue
  _BackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    final rect = Offset.zero & size;

    // Dégradé qui se déplace lentement
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + 0.5 * math.sin(a), -1 + 0.3 * math.cos(a)),
          end: Alignment(1 - 0.5 * math.cos(a), 1 - 0.3 * math.sin(a)),
          colors: const [AppTheme.primaryDark, AppTheme.primary, AppTheme.primaryLight],
        ).createShader(rect),
    );

    // Halos lumineux qui dérivent
    void orb(double fx, double fy, double radiusFactor, int k, double phase, Color color) {
      final ang = a * k + phase;
      final c = Offset(
        size.width * fx + math.cos(ang) * size.width * 0.07,
        size.height * fy + math.sin(ang) * size.height * 0.06,
      );
      final r = size.shortestSide * radiusFactor;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withOpacity(0.35), color.withOpacity(0.0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    orb(0.15, 0.20, 0.65, 1, 0.0, const Color(0xFF7C4DFF)); // violet du logo
    orb(0.90, 0.35, 0.55, 2, 1.7, AppTheme.accent);
    orb(0.35, 0.95, 0.70, 1, 3.1, const Color(0xFF29B6F6));
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) => old.t != t;
}
