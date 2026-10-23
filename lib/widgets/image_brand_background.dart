// lib/widgets/image_brand_background.dart
// Image plein cadre (recadrée en « cover ») avec un voile noir neutre pour
// que le texte blanc reste lisible. Même photo que le hero de l'accueil :
// `assets/images/hero.jpg` si elle existe, sinon la photo en ligne, sinon un fond sombre.

import 'package:flutter/material.dart';

class ImageBrandBackground extends StatelessWidget {
  final Widget child;
  final String asset;
  final String networkFallback;
  const ImageBrandBackground({
    super.key,
    required this.child,
    this.asset = 'assets/images/hero.jpg',
    this.networkFallback =
        'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?w=1600',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Repli si aucune image ne peut se charger
        const ColoredBox(color: Color(0xFF1A1A1A), child: SizedBox.expand()),
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => Image.network(
            networkFallback,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        // Voile noir neutre (sans teinte verte) : plus foncé à gauche pour le texte
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xB3000000), Color(0x8C000000), Color(0x66000000)],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
