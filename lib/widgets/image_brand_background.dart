// lib/widgets/image_brand_background.dart
// Image plein cadre (recadrée en « cover ») avec un voile bleu VelQix pour que
// le texte blanc reste lisible par-dessus.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ImageBrandBackground extends StatelessWidget {
  final Widget child;
  final String asset;
  const ImageBrandBackground({
    super.key,
    required this.child,
    this.asset = 'assets/images/login_bg.jpg',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Couleur de repli si l'image ne peut pas se charger
        const ColoredBox(color: AppTheme.primaryDark),
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        // Voile bleu : plus foncé à gauche/en haut pour le texte
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryDark.withOpacity(0.85),
                AppTheme.primary.withOpacity(0.62),
                AppTheme.primaryLight.withOpacity(0.45),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
