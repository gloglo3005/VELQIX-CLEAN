/// Implémentation native Android/iOS avec image_picker.
import 'package:image_picker/image_picker.dart';

final _picker = ImagePicker();

Future<String?> pickImageWeb({bool capture = false}) async {
  try {
    final source = capture ? ImageSource.camera : ImageSource.gallery;
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    return file?.path;
  } catch (_) {
    return null;
  }
}

Future<List<String>> pickMultipleImagesWeb({int maxCount = 10}) async {
  try {
    final List<XFile> files = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    return files.take(maxCount).map((f) => f.path).toList();
  } catch (_) {
    return [];
  }
}

Future<String?> pickVideoWeb({bool capture = false}) async {
  try {
    final source = capture ? ImageSource.camera : ImageSource.gallery;
    final XFile? file = await _picker.pickVideo(source: source);
    return file?.path;
  } catch (_) {
    return null;
  }
}
