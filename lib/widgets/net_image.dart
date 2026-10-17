// lib/widgets/net_image.dart
// Image réseau robuste, avec cache disque sur mobile (photos visibles sans
// connexion) et plusieurs tentatives pour qu'une photo s'affiche TOUJOURS si
// elle est accessible :
//   1. version allégée Cloudinary (plus rapide),
//   2. sinon l'URL d'origine (si la transformation est refusée par Cloudinary),
//   3. sur le web, repli automatique sur une balise <img> (contourne le CORS).
// Chaque échec est écrit dans la console (« NetImage: échec … ») pour diagnostic.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/image_url.dart';

class NetImage extends StatefulWidget {
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

  @override
  State<NetImage> createState() => _NetImageState();
}

class _NetImageState extends State<NetImage> {
  int _attempt = 0;

  /// Adresses à essayer, dans l'ordre.
  List<String> get _urls {
    final optimized = optimizeImageUrl(widget.url, displayWidth: widget.displayWidth ?? widget.width);
    return [if (optimized != widget.url) optimized, widget.url];
  }

  @override
  void didUpdateWidget(covariant NetImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _attempt = 0;
  }

  void _failed(String url, Object error) {
    debugPrint('NetImage: échec ($url) → $error');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _attempt++);
    });
  }

  Widget _placeholder() => Container(width: widget.width, height: widget.height, color: AppTheme.divider);

  Widget _error() =>
      widget.fallback?.call() ??
      Container(
        width: widget.width,
        height: widget.height,
        color: AppTheme.divider,
        child: Icon(Icons.image_not_supported_outlined, size: 32, color: AppTheme.textHint),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) return _error();
    final urls = _urls;
    if (_attempt >= urls.length) return _error();
    final url = urls[_attempt];

    // Web : le navigateur gère déjà son cache ; repli <img> si le CORS bloque.
    if (kIsWeb) {
      return Image.network(
        url,
        key: ValueKey('$_attempt-$url'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        loadingBuilder: (_, child, progress) => progress == null ? child : _placeholder(),
        errorBuilder: (_, error, __) {
          _failed(url, error);
          return _placeholder();
        },
      );
    }

    // Mobile : cache disque (photo déjà vue = visible sans connexion)
    return CachedNetworkImage(
      key: ValueKey('$_attempt-$url'),
      imageUrl: url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, failedUrl, error) {
        _failed(failedUrl, error);
        return _placeholder();
      },
    );
  }
}
