import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import '../services/ringtone_service.dart';
import '../widgets/widgets.dart';

// ── Config Agora ─────────────────────────────────────────────────────────────
// Utilisé seulement si le serveur ne renvoie pas d'App ID.
const String _agoraAppId = 'ba0140cb525942b1b0f81cd26d97f3d2';

class AgoraCallScreen extends StatefulWidget {
  final UserModel remoteUser;
  final String channelName;
  final bool isCaller;
  final String? callId; // si fourni : ferme l'écran si l'autre raccroche/refuse avant connexion

  const AgoraCallScreen({
    super.key,
    required this.remoteUser,
    required this.channelName,
    this.isCaller = true,
    this.callId,
  });

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  // Nullable : si l'initialisation échoue, on ne plante pas.
  RtcEngine? _engine;
  bool _joined        = false;
  bool _muted         = false;
  bool _speakerOn     = true;
  bool _remoteJoined  = false;
  bool _ending        = false;
  int  _callDuration  = 0;
  Timer? _timer;
  Timer? _joinTimeout;
  String _status = 'Appel en cours...';
  StreamSubscription? _callStatusSub;

  @override
  void initState() {
    super.initState();
    _initAgora();

    // Tonalité « ça sonne » pour l'appelant, jusqu'à la réponse.
    if (widget.isCaller) {
      RingtoneService.instance.start(volume: 0.6);
    }

    // Si un callId a été fourni : si l'appel est rejeté/terminé côté serveur
    // avant que le distant ne rejoigne le canal, on ferme cet écran.
    if (widget.callId != null) {
      _callStatusSub = ChatService.instance.onCallStatus.listen((data) {
        if (data['callId'] == widget.callId &&
            (data['event'] == 'rejected' || data['event'] == 'ended') &&
            !_remoteJoined) {
          _endCall();
        }
      });
    }
  }

  /// Affiche l'étape en cours à l'écran ET dans la console.
  /// Sert à voir exactement où ça bloque.
  void _setStatus(String s) {
    // Le détail technique (token, état Agora...) reste dans la console :
    // l'utilisateur ne voit qu'un message simple.
    debugPrint('AGORA $s');
    final shown = _friendlyStatus(s);
    if (!mounted || _remoteJoined) return;
    // Une fois dans le canal, on garde « Ça sonne... » tant que personne
    // ne répond, sauf vraie erreur.
    if (_joined && shown == _genericStatus) return;
    if (shown != _genericStatus) {
      // Erreur : plus de raison de faire sonner.
      RingtoneService.instance.stop();
    }
    setState(() => _status = shown);
  }

  String get _genericStatus =>
      widget.isCaller ? 'Appel en cours...' : 'Connexion...';

  String _friendlyStatus(String s) {
    if (s.startsWith('Micro refusé') || s.startsWith('Caméra refusée')) {
      return s;
    }
    if (s.startsWith('Connexion impossible')) {
      return 'Connexion impossible. Vérifiez votre réseau.';
    }
    if (s.startsWith('Échec') || s.startsWith('Erreur Agora')) {
      return 'Connexion impossible. Réessayez.';
    }
    return _genericStatus;
  }

  /// Exécute une étape et, si elle échoue, ajoute son nom à l'erreur.
  Future<void> _step(String name, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      throw Exception('étape "$name" : $e');
    }
  }

  Future<void> _initAgora() async {
    try {
      // 1. Permission micro
      final perm = await Permission.microphone.request();
      if (!perm.isGranted) {
        _setStatus('Micro refusé : autorise-le dans les réglages');
        return;
      }

      // 2. Token + App ID donnés par le serveur
      _setStatus('Récupération du token...');
      final creds = await ChatService.instance.agoraCredentials(widget.channelName, _agoraAppId);
      _setStatus('Connexion Agora (${creds.token.isEmpty ? "token VIDE" : "token OK"})...');

      // 3. Moteur Agora, audio seulement
      // Chaque étape est nommée : si Agora refuse (ex. erreur -4), l'écran
      // indique laquelle. Pas de setClientRole : il n'est pas supporté
      // en profil "communication" (c'est la cause probable de l'erreur -4).
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await _step('initialize', () => engine.initialize(RtcEngineContext(
            appId: creds.appId,
            channelProfile: ChannelProfileType.channelProfileCommunication,
          )));
      await _step('enableAudio', () => engine.enableAudio());

      // 4. Callbacks
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _joinTimeout?.cancel();
          // Le haut-parleur se règle une fois dans le canal.
          _engine?.setEnableSpeakerphone(_speakerOn).catchError((_) {});
          if (!mounted) return;
          setState(() { _joined = true; _status = widget.isCaller ? 'Ça sonne...' : 'Connexion...'; });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!mounted) return;
          setState(() { _remoteJoined = true; _status = 'Connecté'; });
          RingtoneService.instance.stop();
          _startTimer();
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (!mounted) return;
          setState(() { _remoteJoined = false; _status = 'Appel terminé'; });
          Future.delayed(const Duration(seconds: 1), _endCall);
        },
        onConnectionStateChanged: (connection, state, reason) {
          _setStatus('Agora : ${state.name} / ${reason.name}');
        },
        onError: (err, msg) {
          _setStatus('Erreur Agora : ${err.name} $msg');
        },
      ));

      // Si on n'a pas rejoint au bout de 15 s, on le dit clairement.
      _joinTimeout = Timer(const Duration(seconds: 15), () {
        if (!_joined && mounted) {
          _setStatus('Connexion impossible (vérifie le token et le réseau)');
        }
      });

      // 5. Rejoindre le canal
      await _step('joinChannel', () => engine.joinChannel(
            token: creds.token,
            channelId: widget.channelName,
            uid: 0,
            options: const ChannelMediaOptions(
              channelProfile: ChannelProfileType.channelProfileCommunication,
              publishMicrophoneTrack: true,
              autoSubscribeAudio: true,
            ),
          ));
    } catch (e) {
      _setStatus('Échec : $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  String get _formattedDuration {
    final m = (_callDuration ~/ 60).toString().padLeft(2, '0');
    final s = (_callDuration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _releaseEngine() async {
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    try { await engine.leaveChannel(); } catch (_) {}
    try { await engine.release(); } catch (_) {}
  }

  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    RingtoneService.instance.stop();
    _timer?.cancel();
    _joinTimeout?.cancel();
    _callStatusSub?.cancel();
    if (widget.callId != null) ChatService.instance.endCallSignal(widget.callId!);
    await _releaseEngine();
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() async {
    setState(() => _muted = !_muted);
    try { await _engine?.muteLocalAudioStream(_muted); } catch (_) {}
  }

  void _toggleSpeaker() async {
    setState(() => _speakerOn = !_speakerOn);
    try { await _engine?.setEnableSpeakerphone(_speakerOn); } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _joinTimeout?.cancel();
    _callStatusSub?.cancel();
    RingtoneService.instance.stop();
    _releaseEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            // ── Avatar ────────────────────────────────────────────────────
            UserAvatar(user: widget.remoteUser, radius: 50),
            const SizedBox(height: 20),

            // ── Nom ───────────────────────────────────────────────────────
            Text(
              widget.remoteUser.fullName,
              style: GoogleFonts.poppins(
                  fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 8),

            // ── Statut / durée ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _remoteJoined ? _formattedDuration : 'En attente...',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.white60),
              ),
            ),

            // ── Indicateur connexion ──────────────────────────────────────
            // (aucun indicateur : seul « En attente... » s'affiche)

            const Spacer(),

            // ── Contrôles ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Micro
                  _CallButton(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _muted ? 'Muet' : 'Micro',
                    color: _muted ? Colors.white24 : Colors.white.withOpacity(0.15),
                    onTap: _toggleMute,
                  ),

                  // Raccrocher
                  Column(children: [
                    ElevatedButton(
                      onPressed: _endCall,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(22),
                        elevation: 4,
                      ),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text('Raccrocher', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60)),
                  ]),

                  // Haut-parleur
                  _CallButton(
                    icon: _speakerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    label: _speakerOn ? 'HP On' : 'HP Off',
                    color: _speakerOn
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white24,
                    onTap: _toggleSpeaker,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bouton rond d'appel ────────────────────────────────────────────────────────
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: size * 0.45),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60)),
      ]),
    );
  }
}