/// Service de sélection de fichiers — compatible Web ET Desktop/Mobile.
/// Utilise conditional imports pour charger la bonne implémentation.

import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart' show XFile;

import 'platform_impl/file_picker_stub.dart'
    if (dart.library.html) 'platform_impl/file_picker_web.dart';

class WebFilePicker {
  /// Ouvre le sélecteur d'image natif.
  /// Sur Web → input HTML, renvoie une data URI.
  /// Sur mobile → image_picker, renvoie un chemin de fichier local.
  static Future<String?> pickImage({bool capture = false}) async {
    return pickImageWeb(capture: capture);
  }

  /// Ouvre un sélecteur de vidéo.
  /// capture=true → ouvre UNIQUEMENT la caméra pour enregistrer.
  /// capture=false → ouvre la galerie vidéo.
  static Future<String?> pickVideo({bool capture = false}) async {
    return pickVideoWeb(capture: capture);
  }

  /// Ouvre un sélecteur multi-images (jusqu'à [maxCount] fichiers).
  static Future<List<String>> pickMultipleImages({int maxCount = 10}) async {
    return pickMultipleImagesWeb(maxCount: maxCount);
  }

  /// Octets d'un fichier renvoyé par les sélecteurs ci-dessus, qu'il s'agisse
  /// d'une data URI (web) ou d'un chemin local (mobile). null si illisible.
  static Future<Uint8List?> readBytes(String pathOrDataUri) async {
    try {
      if (pathOrDataUri.startsWith('data:')) {
        final parts = pathOrDataUri.split(',');
        if (parts.length != 2) return null;
        return base64Decode(parts[1]);
      }
      return await XFile(pathOrDataUri).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Sous-type MIME image ("jpeg", "png"…) déduit de la data URI ou de l'extension.
  static String imageSubtype(String pathOrDataUri) {
    final mime = RegExp(r'^data:image/([a-zA-Z0-9.+-]+);').firstMatch(pathOrDataUri);
    if (mime != null) return mime.group(1)!;
    final ext = pathOrDataUri.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':  return 'png';
      case 'webp': return 'webp';
      case 'gif':  return 'gif';
      default:     return 'jpeg';
    }
  }
}
