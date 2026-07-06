/// Service de sélection de fichiers — compatible Web ET Desktop/Mobile.
/// Utilise conditional imports pour charger la bonne implémentation.

import 'platform_impl/file_picker_stub.dart'
    if (dart.library.html) 'platform_impl/file_picker_web.dart';

class WebFilePicker {
  /// Ouvre le sélecteur d'image natif.
  /// Sur Web → input HTML (ouvre le gestionnaire de fichiers du navigateur).
  /// Sur Desktop → simule une sélection (nom de fichier factice).
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
}
