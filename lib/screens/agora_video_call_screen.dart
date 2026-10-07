import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../models/models.dart';
import '../services/chat_service.dart';
import '../widgets/widgets.dart';

// Utilisé seulement si le serveur ne renvoie pas d'App ID.
const String _agoraAppId = 'ba0140cb525942b1b0f81cd26d97f3d2';

class AgoraVideoCallScreen extends StatefulWidget {
  final UserModel remoteUser;
  final String channelName;
  final bool isCaller;
  final String? callId; // si fourni : ferme l'écran si l'autre raccroche/refuse avant connexion

  const AgoraVideoCallScreen({
    super.key,
    required this.remoteUser,
    required this.channelName,
    this.isCaller = true,
    this.callId,
  });

  @override
  State<AgoraVideoCallScreen> createState() => _AgoraVideoCallScreenState();
}

class _AgoraVideoCallScreenState extends State<AgoraVideoCallScreen> {
  // Nullable : si l'initialisation échoue, on ne plante pas.
  RtcEngine? _engine;

  bool _joined        = false;
  bool _remoteJoined  = false;
  bool _muted         = false;
  bool _cameraOff     = false;
  bool _speakerOn     = true;
  bool _frontCamera   = true;

  int  _remoteUid     = 0;
  int  _callSeconds   = 0;
  String _status      = 'Appel en cours...';
  bool _ending        = false;

  Timer? _secondTimer;
  Timer? _joinTimeout;
  StreamSubscription? _callStatusSub;

  // ── Init ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initAgora();

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
  void _setStatus(String s) {
    debugPrint('AGORA $s');
    if (mounted && !_remoteJoined) setState(() => _status = s);
  }

  Future<void> _initAgora() async {
    try {
      final perms = await [Permission.camera, Permission.microphone].request();
      if (perms[Permission.microphone]?.isGranted != true) {
        _setStatus('Micro refusé : autorise-le dans les réglages');
        return;
      }
      if (perms[Permission.camera]?.isGranted != true) {
        _setStatus('Caméra refusée : autorise-la dans les réglages');
        return;
      }

      _setStatus('Récupération du token...');
      final creds = await ChatService.instance.agoraCredentials(widget.channelName, _agoraAppId);
      _setStatus('Connexion Agora (${creds.token.isEmpty ? "token VIDE" : "token OK"})...');

      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(RtcEngineContext(appId: creds.appId));
      await engine.setChannelProfile(ChannelProfileType.channelProfileCommunication);
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.enableVideo();
      await engine.enableAudio();
      await engine.setEnableSpeakerphone(_speakerOn);
      await engine.startPreview();

      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _joinTimeout?.cancel();
          if (!mounted) return;
          setState(() { _joined = true; _status = 'En attente...'; });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!mounted) return;
          setState(() {
            _remoteUid    = remoteUid;
            _remoteJoined = true;
            _status       = 'Connecté';
          });
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

      _joinTimeout = Timer(const Duration(seconds: 15), () {
        if (!_joined && mounted) {
          _setStatus('Connexion impossible (vérifie le token et le réseau)');
        }
      });

      await engine.joinChannel(
        token: creds.token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      _setStatus('Échec : $e');
    }
  }

  void _startTimer() {
    _secondTimer?.cancel();
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _callSeconds++);
    });
  }

  String get _formattedDuration {
    final m = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _releaseEngine() async {
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    try { await engine.stopPreview(); } catch (_) {}
    try { await engine.leaveChannel(); } catch (_) {}
    try { await engine.release(); } catch (_) {}
  }

  // ── Fin d'appel ───────────────────────────────────────────────────
  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    _secondTimer?.cancel();
    _joinTimeout?.cancel();
    _callStatusSub?.cancel();
    if (widget.callId != null) ChatService.instance.endCallSignal(widget.callId!);
    await _releaseEngine();
    if (mounted) Navigator.pop(context);
  }

  // ── Contrôles ─────────────────────────────────────────────────────
  void _toggleMute() async {
    setState(() => _muted = !_muted);
    try { await _engine?.muteLocalAudioStream(_muted); } catch (_) {}
  }

  void _toggleCamera() async {
    setState(() => _cameraOff = !_cameraOff);
    try { await _engine?.muteLocalVideoStream(_cameraOff); } catch (_) {}
  }

  void _switchCamera() async {
    setState(() => _frontCamera = !_frontCamera);
    try { await _engine?.switchCamera(); } catch (_) {}
  }

  @override
  void dispose() {
    _secondTimer?.cancel();
    _joinTimeout?.cancel();
    _callStatusSub?.cancel();
    _releaseEngine();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final engine = _engine;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

        // ── Vidéo distante (plein écran) ─────────────────────────────
        if (_remoteJoined && engine != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          )
        else
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(user: widget.remoteUser, radius: 50),
                const SizedBox(height: 16),
                Text(widget.remoteUser.fullName,
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),
                Text(_status,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white60)),
                if (!_joined) ...[
                  const SizedBox(height: 20),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                  ),
                ],
              ],
            ),
          )),

        // ── Prévisualisation caméra locale (coin) ─────────────────────
        if (_joined && !_cameraOff && engine != null)
          Positioned(
            top: 60, right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 100, height: 140,
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),

        // ── Barre du haut (nom) ───────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Text(widget.remoteUser.fullName,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                const Spacer(),
              ]),
            ),
          ),
        ),

        // ── Durée ─────────────────────────────────────────────────────
        if (_remoteJoined)
          Positioned(
            top: 60, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Text(_formattedDuration,
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
              ]),
            ),
          ),

        // ── Contrôles bas ─────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.85), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _VideoBtn(
                  icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: _muted ? 'Muet' : 'Micro',
                  active: !_muted,
                  onTap: _toggleMute,
                ),
                _VideoBtn(
                  icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                  label: _cameraOff ? 'Caméra off' : 'Caméra',
                  active: !_cameraOff,
                  onTap: _toggleCamera,
                ),
                // Raccrocher
                GestureDetector(
                  onTap: _endCall,
                  child: Column(children: [
                    Container(
                      width: 64, height: 64,
                      decoration: const BoxDecoration(
                          color: Color(0xFFEF4444), shape: BoxShape.circle),
                      child: const Icon(Icons.call_end_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 6),
                    Text('Raccrocher',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.white60)),
                  ]),
                ),
                _VideoBtn(
                  icon: Icons.flip_camera_ios_rounded,
                  label: 'Retourner',
                  active: true,
                  onTap: _switchCamera,
                ),
                _VideoBtn(
                  icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  label: 'HP',
                  active: _speakerOn,
                  onTap: () async {
                    setState(() => _speakerOn = !_speakerOn);
                    try { await _engine?.setEnableSpeakerphone(_speakerOn); } catch (_) {}
                  },
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _VideoBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _VideoBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(
                color: active ? Colors.white30 : Colors.white12),
          ),
          child: Icon(icon,
              color: active ? Colors.white : Colors.white38, size: 22),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.white60)),
      ]),
    );
  }
}