// ═══════════════════════════════════════════════════════════════════
// AGORA VIDEO CALL SCREEN
// 🚫 Facturation 10 FCFA/min DÉSACTIVÉE (25/08/2026) — appels gratuits/illimités
// pour l'instant (wallet plus utilisé). Voir _startBillingTimer ci-dessous.
// 🔑 Remplace VOTRE_APP_ID_AGORA par ton App ID Agora
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
// import '../services/wallet_service.dart'; // 🚫 DÉSACTIVÉ (25/08/2026) : appels vidéo gratuits/illimités

const String _agoraAppId = '5c00b5a87a274771bb20ef52f0f0fb43'; // 🔑 À remplacer

class AgoraVideoCallScreen extends StatefulWidget {
  final UserModel remoteUser;
  final String channelName;
  final bool isCaller; // true = client (payant), false = propriétaire

  const AgoraVideoCallScreen({
    super.key,
    required this.remoteUser,
    required this.channelName,
    this.isCaller = true,
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
  int  _billedMinutes = 0;  // minutes déjà facturées

  double _balance     = 0.0;
  bool _lowBalance    = false;
  String _status      = 'Appel en cours...';

  Timer? _secondTimer;  // tick chaque seconde (durée + facturation)

  // ── Init ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // _loadBalance(); // 🚫 DÉSACTIVÉ (25/08/2026) : appels gratuits, plus de solde à charger
    _initAgora();
  }

  // 🚫 DÉSACTIVÉ (25/08/2026) : appels vidéo gratuits/illimités, plus de solde à suivre
  // Future<void> _loadBalance() async {
  //   final b = await WalletService.instance.getBalance();
  //   if (mounted) setState(() => _balance = b);
  // }

  Future<void> _initAgora() async {
    await [Permission.camera, Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: _agoraAppId));
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
      token: '',
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  // ── Facturation par minute ── 🚫 DÉSACTIVÉE (25/08/2026) : appels
  // gratuits/illimités — le timer ne sert plus qu'à afficher la durée.
  void _startBillingTimer() {
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      setState(() => _callSeconds++);

      // // Facturer chaque nouvelle minute commencée
      // final minuteElapsed = _callSeconds ~/ 60;
      // if (minuteElapsed > _billedMinutes && widget.isCaller) {
      //   _billedMinutes = minuteElapsed;
      //   final ok = await WalletService.instance.deduct(
      //       WalletService.kCallRatePerMin);
      //
      //   if (!ok) {
      //     // Solde épuisé → couper l'appel
      //     _showInsufficientFunds();
      //     await _endCall();
      //     return;
      //   }
      //
      //   final newBalance = await WalletService.instance.getBalance();
      //   if (!mounted) return;
      //   setState(() {
      //     _balance    = newBalance;
      //     _lowBalance = newBalance < WalletService.kCallRatePerMin * 3;
      //   });
      // }
    });
  }

  String get _formattedDuration {
    final m = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Fin d'appel ───────────────────────────────────────────────────
  Future<void> _endCall() async {
    _secondTimer?.cancel();
    try {
      await _engine.stopPreview();
      await _engine.leaveChannel();
      await _engine.release();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  // 🚫 DÉSACTIVÉ (25/08/2026) : plus jamais appelée, appels gratuits/illimités
  // void _showInsufficientFunds() {
  //   if (!mounted) return;
  //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //     content: Text('Solde insuffisant — appel coupé',
  //         style: GoogleFonts.poppins(color: Colors.white)),
  //     backgroundColor: AppTheme.error,
  //     behavior: SnackBarBehavior.floating,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //   ));
  // }

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

        // ── Barre du haut (nom + solde) ───────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Text(widget.remoteUser.fullName,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                const Spacer(),
                // Solde (affiché seulement côté client) — 🚫 DÉSACTIVÉ (25/08/2026) : appels gratuits
                // if (widget.isCaller)
                //   Container(
                //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                //     decoration: BoxDecoration(
                //       color: _lowBalance
                //           ? AppTheme.error.withOpacity(0.85)
                //           : Colors.black54,
                //       borderRadius: BorderRadius.circular(20),
                //     ),
                //     child: Row(mainAxisSize: MainAxisSize.min, children: [
                //       Icon(Icons.account_balance_wallet_rounded,
                //           size: 14,
                //           color: _lowBalance ? Colors.white : Colors.white70),
                //       const SizedBox(width: 5),
                //       Text('${_balance.toStringAsFixed(0)} FCFA',
                //           style: GoogleFonts.poppins(
                //               fontSize: 12,
                //               fontWeight: FontWeight.w600,
                //               color: Colors.white)),
                //     ]),
                //   ),
              ]),
            ),
          ),
        ),

        // ── Durée + tarif ─────────────────────────────────────────────
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
                // 🚫 DÉSACTIVÉ (25/08/2026) : appels gratuits, plus de tarif à afficher
                // if (widget.isCaller) ...[
                //   const SizedBox(width: 6),
                //   Text('• 10 FCFA/min',
                //       style: GoogleFonts.poppins(fontSize: 11, color: Colors.white60)),
                // ],
              ]),
            ),
          ),

        // ── Alerte solde faible ── 🚫 DÉSACTIVÉE (25/08/2026) : appels gratuits
        // if (_lowBalance && widget.isCaller)
        //   Positioned(
        //     top: 100, left: 16, right: 16,
        //     child: Container(
        //       padding: const EdgeInsets.all(10),
        //       decoration: BoxDecoration(
        //           color: AppTheme.error.withOpacity(0.9),
        //           borderRadius: BorderRadius.circular(12)),
        //       child: Row(children: [
        //         const Icon(Icons.warning_rounded, color: Colors.white, size: 18),
        //         const SizedBox(width: 8),
        //         Text('Solde faible — rechargez bientôt',
        //             style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
        //       ]),
        //     ),
        //   ),

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