// lib/utils/image_url.dart
// Réduit le poids des photos Cloudinary : au lieu de télécharger l'original
// (souvent 3-8 Mo), on demande une version redimensionnée, compressée et au
// format JPEG universel (les formats AVIF/WebP automatiques peuvent poser des problèmes de décodage sur le web). Les autres URL sont inchangées.

String optimizeImageUrl(String url, {double? displayWidth}) {
  if (!url.contains('res.cloudinary.com') || !url.contains('/upload/')) return url;
  // Déjà transformée (par nous ou à l'upload) : on ne touche à rien
  final afterUpload = url.split('/upload/').last;
  if (afterUpload.startsWith('f_') ||
      afterUpload.startsWith('q_') ||
      afterUpload.startsWith('w_') ||
      afterUpload.startsWith('c_')) {
    return url;
  }
  final w = (displayWidth != null && displayWidth.isFinite)
      ? (displayWidth * 2).clamp(200, 1600).round() // ×2 pour les écrans haute densité
      : 800;
  return url.replaceFirst('/upload/', '/upload/f_jpg,q_auto,w_$w,c_limit/');
}
