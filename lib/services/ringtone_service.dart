import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ringtone_data.dart';

/// ===============================================================
/// RINGTONE SERVICE
/// ===============================================================
/// Sonnerie des appels :
///  - appel entrant  : sonnerie en boucle + vibrations (IncomingCallScreen)
///  - appel sortant  : tonalité de retour « ça sonne » (écrans Agora)
///
/// Le son est embarqué dans le code (ringtone_data.dart) : rien à
/// déclarer dans pubspec.yaml.
class RingtoneService {
  RingtoneService._();

  static final RingtoneService instance = RingtoneService._();

  AudioPlayer? _player;
  Uint8List? _bytes;
  Timer? _hapticTimer;
  Timer? _beepTimer;
  bool _active = false;
  int _generation = 0;

  bool get isPlaying => _active;

  Future<void> start({bool vibrate = false, double volume = 1.0}) async {
    if (_active) return;
    _active = true;
    final gen = ++_generation;

    if (vibrate && !kIsWeb) {
      HapticFeedback.vibrate();
      _hapticTimer = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => HapticFeedback.vibrate(),
      );
    }

    try {
      _bytes ??= base64Decode(kRingtoneBase64);
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(volume);
      // stop() a pu être appelé pendant l'initialisation.
      if (gen != _generation) return;
      await player.play(BytesSource(_bytes!));
      if (gen != _generation && !_active) {
        await player.stop();
      }
    } catch (e) {
      debugPrint('Ringtone error: $e');
      if (gen == _generation) {
        _startFallbackBeep();
      }
    }
  }

  /// Repli si la lecture audio échoue (ex. autoplay bloqué sur le web).
  void _startFallbackBeep() {
    if (kIsWeb) return;
    SystemSound.play(SystemSoundType.alert);
    _beepTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => SystemSound.play(SystemSoundType.alert),
    );
  }

  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    _generation++;
    _hapticTimer?.cancel();
    _hapticTimer = null;
    _beepTimer?.cancel();
    _beepTimer = null;
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('Ringtone stop error: $e');
    }
  }
}