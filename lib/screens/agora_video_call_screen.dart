

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../models/models.dart';
import '../services/chat_service.dart';
import '../widgets/widgets.dart';

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
  late RtcEngine _engine;

  bool _joined        = false;
  bool _remoteJoined  = false;
  bool _muted         = false;
  bool _cameraOff     = false;
  bool _speakerOn     = true;
  bool _frontCamera   = true;

  int  _remoteUid     = 0;
  int  _callSeconds   = 0;  // durée totale en secondes
  String _status      = 'Appel en cours...';
  bool _ending        = false;

  Timer? _secondTimer;  // tick chaque seconde (durée)
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

  Future<void> _initAgora() async {
    await [Permission.camera, Permission.microphone].request();

    final creds = await ChatService.instance.agoraCredentials(widget.channelName, _agoraAppId);
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: creds.appId));
    await _engine.setChannelProfile(
        ChannelProfileType.channelProfileCommunication);
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.enableAudio();
    await _engine.startPreview();

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
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
        _startBillingTimer();
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (!mounted) return;
        setState(() { _remoteJoined = false; _status = 'Appel terminé'; });
        Future.delayed(const Duration(seconds: 1), _endCall);
      },
      onError: (err, msg) {
        if (mounted) setState(() => _status = 'Erreur : $msg');
      },
    ));

    await _engine.joinChannel(
      token: creds.token,
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  void _startBillingTimer() {
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

  // ── Fin d'appel ───────────────────────────────────────────────────
  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    _secondTimer?.cancel();
    _callStatusSub?.cancel();
    if (widget.callId != null) ChatService.instance.endCallSignal(widget.callId!);
    try {
      await _engine.stopPreview();
      await _engine.leaveChannel();
      await _engine.release();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }


  // ── Contrôles ─────────────────────────────────────────────────────
  void _toggleMute() async {
    setState(() => _muted = !_muted);
    await _engine.muteLocalAudioStream(_muted);
  }

  void _toggleCamera() async {
    setState(() => _cameraOff = !_cameraOff);
    await _engine.muteLocalVideoStream(_cameraOff);
  }

  void _switchCamera() async {
    setState(() => _frontCamera = !_frontCamera);
    await _engine.switchCamera();
  }

  @override
  void dispose() {
    _secondTimer?.cancel();
    _callStatusSub?.cancel();
    try {
      _engine.stopPreview();
      _engine.leaveChannel();
      _engine.release();
    } catch (_) {}
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

        // ── Vidéo distante (plein écran) ─────────────────────────────
        if (_remoteJoined)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          )
        else
          Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(user: widget.remoteUser, radius: 50),
              const SizedBox(height: 16),
              Text(widget.remoteUser.fullName,
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Text(_status,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white60)),
              if (!_joined) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
              ],
            ],
          )),

        // ── Prévisualisation caméra locale (coin) ─────────────────────
        if (_joined && !_cameraOff)
          Positioned(
            top: 60, right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 100, height: 140,
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
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
                    await _engine.setEnableSpeakerphone(_speakerOn);
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
