// ═══════════════════════════════════════════════════════════════════
// AGORA CALL SCREEN — Appel VoIP in-app
// ═══════════════════════════════════════════════════════════════════
// 🔑 Remplace APP_ID par ton App ID Agora :
//    https://console.agora.io → Projet → App ID
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

// ── Config Agora ─────────────────────────────────────────────────────────────
const String _agoraAppId = '5c00b5a87a274771bb20ef52f0f0fb43'; // 🔑 À remplacer

class AgoraCallScreen extends StatefulWidget {
  final UserModel remoteUser;
  final String channelName; // ex: 'chat_${userId1}_${userId2}'
  final bool isCaller;

  const AgoraCallScreen({
    super.key,
    required this.remoteUser,
    required this.channelName,
    this.isCaller = true,
  });

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  late RtcEngine _engine;
  bool _joined        = false;
  bool _muted         = false;
  bool _speakerOn     = true;
  bool _remoteJoined  = false;
  bool _ending        = false;
  int  _callDuration  = 0;
  Timer? _timer;
  String _status = 'Appel en cours...';

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // 1. Demander permissions micro
    await [Permission.microphone].request();

    // 2. Créer le moteur Agora
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: _agoraAppId));

    // 3. Audio seulement (pas de vidéo)
    await _engine.setChannelProfile(
        ChannelProfileType.channelProfileCommunication);
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableAudio();
    await _engine.setEnableSpeakerphone(_speakerOn);

    // 4. Callbacks
    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        if (!mounted) return;
        setState(() { _joined = true; _status = 'En attente...'; });
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        if (!mounted) return;
        setState(() { _remoteJoined = true; _status = 'Connecté'; });
        _startTimer();
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (!mounted) return;
        setState(() { _remoteJoined = false; _status = 'Appel terminé'; });
        Future.delayed(const Duration(seconds: 1), _endCall);
      },
      onError: (err, msg) {
        if (!mounted) return;
        setState(() => _status = 'Erreur: $msg');
      },
    ));

    // 5. Rejoindre le canal (token null = mode test sans token)
    await _engine.joinChannel(
      token: '',
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  String get _formattedDuration {
    final m = (_callDuration ~/ 60).toString().padLeft(2, '0');
    final s = (_callDuration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    _timer?.cancel();
    try { await _engine.leaveChannel(); } catch (_) {}
    try { await _engine.release(); } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() async {
    setState(() => _muted = !_muted);
    await _engine.muteLocalAudioStream(_muted);
  }

  void _toggleSpeaker() async {
    setState(() => _speakerOn = !_speakerOn);
    await _engine.setEnableSpeakerphone(_speakerOn);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _engine.leaveChannel();
    _engine.release();
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
            Text(
              _remoteJoined ? _formattedDuration : _status,
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.white60),
            ),

            // ── Indicateur connexion ──────────────────────────────────────
            if (!_joined) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
            ],

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
