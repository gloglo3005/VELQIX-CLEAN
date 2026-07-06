/// Widget universel d'affichage d'image locale sélectionnée.
/// Gère automatiquement :
///   • blob:http://...        → Web (galerie / caméra mobile web)
///   • data:image/...;base64  → Web PC (webcam via canvas)
///   • /data/user/0/...       → Android / iOS (chemin fichier local)
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class SmartImage extends StatelessWidget {
  final String src;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SmartImage({
    super.key,
    required this.src,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  static bool isBlob(String s) => s.startsWith('blob:');
  static bool isDataUrl(String s) => s.startsWith('data:image');
  static bool isLocalFile(String s) =>
      !kIsWeb && !isBlob(s) && !isDataUrl(s) && s.contains('/');

  static bool canDisplay(String s) =>
      isBlob(s) || isDataUrl(s) || isLocalFile(s);

  @override
  Widget build(BuildContext context) {
    final fallback = errorBuilder ??
        (_, __, ___) => const Icon(Icons.broken_image_outlined);

    if (isBlob(src)) {
      return Image.network(src,
          width: width, height: height, fit: fit, errorBuilder: fallback);
    }

    if (isDataUrl(src)) {
      try {
        final base64Str = src.substring(src.indexOf(',') + 1);
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes,
            width: width, height: height, fit: fit, errorBuilder: fallback);
      } catch (_) {
        return fallback(context, 'base64 decode error', null);
      }
    }

    if (isLocalFile(src)) {
      return Image.file(File(src),
          width: width, height: height, fit: fit, errorBuilder: fallback);
    }

    // Fallback
    return fallback(context, 'unknown src format', null);
  }
}
