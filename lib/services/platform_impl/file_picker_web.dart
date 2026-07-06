import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

String _createObjectUrl(html.File file) => html.Url.createObjectUrl(file);

/// Lit un fichier via FileReader.readAsDataURL → retourne "data:image/jpeg;base64,..."
/// C'est le navigateur lui-même qui encode en base64 — pas de btoa manuel.
Future<String> _readFileAsDataUrl(html.File file) async {
  final completer = Completer<String>();
  final reader = html.FileReader();
  reader.onLoad.listen((_) {
    if (!completer.isCompleted) completer.complete(reader.result as String);
  });
  reader.onError.listen((_) {
    if (!completer.isCompleted) completer.completeError('FileReader error');
  });
  reader.readAsDataUrl(file);
  return completer.future;
}

/// Lit les bytes bruts d'un fichier HTML (pour Image.memory)
Future<Uint8List> _readFileBytes(html.File file) async {
  final completer = Completer<Uint8List>();
  final reader = html.FileReader();
  reader.onLoad.listen((_) {
    if (!completer.isCompleted) {
      final buf = reader.result as ByteBuffer;
      completer.complete(Uint8List.view(buf));
    }
  });
  reader.onError.listen((_) {
    if (!completer.isCompleted) completer.completeError('FileReader error');
  });
  reader.readAsArrayBuffer(file);
  return completer.future;
}

/// GALERIE / CAMERA — retourne un data URI natif
Future<String?> pickImageWeb({bool capture = false}) async {
  if (capture) {
    final ua = html.window.navigator.userAgent.toLowerCase();
    final isMobile = ua.contains('android') || ua.contains('iphone') || ua.contains('ipad');
    if (!isMobile) return await _captureFromWebcamPC();
    return await _pickWithInput(capture: true);
  }
  return await _pickWithInput(capture: false);
}

/// Galerie multi-sélection — retourne des data URIs natifs
Future<List<String>> pickMultipleImagesWeb({int maxCount = 10}) async {
  final completer = Completer<List<html.File>>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = true
    ..style.cssText = 'position:fixed;top:-9999px;left:-9999px;opacity:0;width:1px;height:1px';

  input.onChange.listen((_) {
    if (!completer.isCompleted) {
      final files = input.files;
      completer.complete(files != null && files.isNotEmpty
          ? files.take(maxCount).toList() : []);
    }
  });
  Future.delayed(const Duration(minutes: 10), () {
    if (!completer.isCompleted) completer.complete([]);
  });
  html.document.body!.append(input);
  await Future.delayed(const Duration(milliseconds: 100));
  input.click();
  final htmlFiles = await completer.future;
  try { input.remove(); } catch (_) {}

  final results = <String>[];
  for (final f in htmlFiles) {
    try {
      results.add(await _readFileAsDataUrl(f));
    } catch (_) {
      results.add(_createObjectUrl(f));
    }
  }
  return results;
}

/// Input HTML simple — retourne un data URI natif
Future<String?> _pickWithInput({required bool capture}) async {
  final completer = Completer<html.File?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false
    ..style.cssText = 'position:fixed;top:-9999px;left:-9999px;opacity:0;width:1px;height:1px';
  if (capture) input.setAttribute('capture', 'environment');

  input.onChange.listen((_) {
    if (!completer.isCompleted) {
      final files = input.files;
      completer.complete(files != null && files.isNotEmpty ? files.first : null);
    }
  });
  Future.delayed(const Duration(minutes: 10), () {
    if (!completer.isCompleted) completer.complete(null);
  });
  html.document.body!.append(input);
  await Future.delayed(const Duration(milliseconds: 100));
  input.click();
  final htmlFile = await completer.future;
  try { input.remove(); } catch (_) {}

  if (htmlFile == null) return null;
  try {
    return await _readFileAsDataUrl(htmlFile);
  } catch (_) {
    return _createObjectUrl(htmlFile);
  }
}

/// Caméra vidéo via getUserMedia + MediaRecorder
/// capture=true  → ouvre la caméra pour enregistrer
/// capture=false → ouvre le sélecteur de fichier galerie
Future<String?> pickVideoWeb({bool capture = false}) async {
  if (!capture) {
    // Galerie : sélecteur fichier classique
    final completer = Completer<html.File?>();
    final input = html.FileUploadInputElement()
      ..accept = 'video/*'
      ..multiple = false
      ..style.cssText = 'position:fixed;top:-9999px;left:-9999px;opacity:0;width:1px;height:1px';
    input.onChange.listen((_) {
      if (!completer.isCompleted) {
        final files = input.files;
        completer.complete(files != null && files.isNotEmpty ? files.first : null);
      }
    });
    Future.delayed(const Duration(minutes: 10), () {
      if (!completer.isCompleted) completer.complete(null);
    });
    html.document.body!.append(input);
    await Future.delayed(const Duration(milliseconds: 100));
    input.click();
    final htmlFile = await completer.future;
    try { input.remove(); } catch (_) {}
    if (htmlFile == null) return null;
    return _createObjectUrl(htmlFile);
  }

  // Sur mobile : l'input avec capture ouvre directement l'app caméra vidéo
  final ua = html.window.navigator.userAgent.toLowerCase();
  final isMobile = ua.contains('android') || ua.contains('iphone') || ua.contains('ipad');
  if (isMobile) {
    final completer = Completer<html.File?>();
    final input = html.FileUploadInputElement()
      ..accept = 'video/*'
      ..multiple = false
      ..style.cssText = 'position:fixed;top:-9999px;left:-9999px;opacity:0;width:1px;height:1px';
    input.setAttribute('capture', 'camcorder');
    input.onChange.listen((_) {
      if (!completer.isCompleted) {
        final files = input.files;
        completer.complete(files != null && files.isNotEmpty ? files.first : null);
      }
    });
    Future.delayed(const Duration(minutes: 10), () {
      if (!completer.isCompleted) completer.complete(null);
    });
    html.document.body!.append(input);
    await Future.delayed(const Duration(milliseconds: 100));
    input.click();
    final htmlFile = await completer.future;
    try { input.remove(); } catch (_) {}
    if (htmlFile == null) return null;
    return _createObjectUrl(htmlFile);
  }

  // PC : caméra live via getUserMedia + MediaRecorder
  return await _recordFromCameraPC();
}

/// Enregistrement vidéo PC via getUserMedia + MediaRecorder
Future<String?> _recordFromCameraPC() async {
  final completer = Completer<String?>();

  // ── Overlay ──────────────────────────────────────────────────────────────
  final overlay = html.DivElement()
    ..style.cssText = '''
      position:fixed;top:0;left:0;width:100%;height:100%;
      background:rgba(0,0,0,0.9);z-index:999999;
      display:flex;flex-direction:column;align-items:center;justify-content:center;
      font-family:sans-serif;
    ''';

  final title = html.DivElement()
    ..style.cssText = 'color:white;font-size:18px;font-weight:600;margin-bottom:16px;'
    ..text = '🎥 Enregistrer une vidéo';

  final preview = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..style.cssText = 'border-radius:12px;max-width:90vw;max-height:55vh;background:#000;';

  final timerDiv = html.DivElement()
    ..style.cssText = 'color:#ef4444;font-size:16px;font-weight:700;margin-top:10px;min-height:24px;'
    ..text = '';

  final btnRow = html.DivElement()
    ..style.cssText = 'display:flex;gap:16px;margin-top:16px;';

  final recordBtn = html.ButtonElement()
    ..text = '⏺ Démarrer'
    ..style.cssText = '''
      padding:12px 28px;background:#ef4444;color:white;border:none;
      border-radius:12px;font-size:15px;font-weight:600;cursor:pointer;
    ''';

  final stopBtn = html.ButtonElement()
    ..text = '⏹ Arrêter'
    ..disabled = true
    ..style.cssText = '''
      padding:12px 28px;background:#374151;color:white;border:none;
      border-radius:12px;font-size:15px;font-weight:600;cursor:pointer;
    ''';

  final cancelBtn = html.ButtonElement()
    ..text = 'Annuler'
    ..style.cssText = '''
      padding:12px 28px;background:#6b7280;color:white;border:none;
      border-radius:12px;font-size:15px;cursor:pointer;
    ''';

  btnRow.children.addAll([recordBtn, stopBtn, cancelBtn]);
  overlay.children.addAll([title, preview, timerDiv, btnRow]);
  html.document.body!.append(overlay);

  // ── Stream caméra ─────────────────────────────────────────────────────────
  html.MediaStream? stream;
  try {
    stream = await html.window.navigator.mediaDevices!
        .getUserMedia({'video': true, 'audio': true});
    preview.srcObject = stream;
  } catch (_) {
    overlay.remove();
    if (!completer.isCompleted) completer.complete(null);
    return completer.future;
  }

  // ── MediaRecorder ─────────────────────────────────────────────────────────
  final chunks = <html.Blob>[];
  html.MediaRecorder? recorder;
  int _seconds = 0;
  Timer? _timer;

  void _stopAll() {
    _timer?.cancel();
    recorder?.stop();
    stream?.getTracks().forEach((t) => t.stop());
  }

  recordBtn.onClick.listen((_) {
    chunks.clear();
    recorder = html.MediaRecorder(stream!);
    recorder!.addEventListener('dataavailable', (e) {
      final blob = (e as html.BlobEvent).data;
      if (blob != null && blob.size > 0) chunks.add(blob);
    });
    recorder!.addEventListener('stop', (_) {
      if (chunks.isNotEmpty) {
        final blob = html.Blob(chunks, 'video/webm');
        final url = html.Url.createObjectUrlFromBlob(blob);
        overlay.remove();
        if (!completer.isCompleted) completer.complete(url);
      } else {
        overlay.remove();
        if (!completer.isCompleted) completer.complete(null);
      }
    });
    recorder!.start();
    _seconds = 0;
    timerDiv.text = '⏺ 0s';
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _seconds++;
      timerDiv.text = '⏺ ${_seconds}s';
    });
    recordBtn.disabled = true;
    stopBtn.disabled = false;
    recordBtn.style.background = '#6b7280';
    stopBtn.style.background = '#1a56db';
  });

  stopBtn.onClick.listen((_) {
    _stopAll();
  });

  cancelBtn.onClick.listen((_) {
    _stopAll();
    overlay.remove();
    if (!completer.isCompleted) completer.complete(null);
  });

  return completer.future;
}

/// Caméra PC via getUserMedia
Future<String?> _captureFromWebcamPC() async {
  final completer = Completer<String?>();

  final overlay = html.DivElement()
    ..style.cssText = '''
      position:fixed;top:0;left:0;width:100%;height:100%;
      background:rgba(0,0,0,0.85);z-index:999999;
      display:flex;flex-direction:column;align-items:center;justify-content:center;
      font-family:sans-serif;
    ''';

  final title = html.DivElement()
    ..style.cssText = 'color:white;font-size:18px;font-weight:600;margin-bottom:16px;'
    ..text = '📷 Prendre une photo';

  final video = html.VideoElement()
    ..autoplay = true
    ..style.cssText = 'border-radius:12px;max-width:90vw;max-height:60vh;background:#000;';

  final btnRow = html.DivElement()
    ..style.cssText = 'display:flex;gap:16px;margin-top:20px;';

  final captureBtn = html.ButtonElement()
    ..text = '📸 Capturer'
    ..style.cssText = '''
      padding:12px 32px;background:#1a56db;color:white;border:none;
      border-radius:12px;font-size:16px;font-weight:600;cursor:pointer;
    ''';

  final cancelBtn = html.ButtonElement()
    ..text = 'Annuler'
    ..style.cssText = '''
      padding:12px 32px;background:#6b7280;color:white;border:none;
      border-radius:12px;font-size:16px;cursor:pointer;
    ''';

  btnRow.children.addAll([captureBtn, cancelBtn]);
  overlay.children.addAll([title, video, btnRow]);
  html.document.body!.append(overlay);

  html.MediaStream? stream;
  try {
    stream = await html.window.navigator.mediaDevices!
        .getUserMedia({'video': true, 'audio': false});
    video.srcObject = stream;
  } catch (_) {
    overlay.remove();
    if (!completer.isCompleted) {
      completer.complete(await _pickWithInput(capture: false));
    }
    return completer.future;
  }

  captureBtn.onClick.listen((_) {
    final canvas = html.CanvasElement(
        width: video.videoWidth, height: video.videoHeight);
    canvas.context2D.drawImage(video, 0, 0);
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.92);
    stream?.getTracks().forEach((t) => t.stop());
    overlay.remove();
    if (!completer.isCompleted) completer.complete(dataUrl);
  });

  cancelBtn.onClick.listen((_) {
    stream?.getTracks().forEach((t) => t.stop());
    overlay.remove();
    if (!completer.isCompleted) completer.complete(null);
  });

  return completer.future;
}
