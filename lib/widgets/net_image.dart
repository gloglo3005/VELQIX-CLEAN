// lib/widgets/net_image.dart
// Image réseau avec cache DISQUE : une photo déjà vue reste affichée sans
// connexion internet (et ne se retélécharge pas). Les photos Cloudinary sont
// en plus demandées en version allégée.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/image_url.dart';

class NetImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final double? displayWidth; // largeur d'affichage (pour choisir la taille à télécharger)
  final BoxFit fit;
  final Widget Function()? fallback;

  const NetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.displayWidth,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  Widget _placeholder() => Container(width: width, height: height, color: AppTheme.divider);

  Widget _error() =>
      fallback?.call() ??
      Container(
        width: width,
        height: height,
        color: AppTheme.divider,
        child: Icon(Icons.image_not_supported_outlined, size: 32, color: AppTheme.textHint),
      );

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _error();
    return CachedNetworkImage(
      imageUrl: optimizeImageUrl(url, displayWidth: displayWidth ?? width),
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _error(),
    );
  }
}
