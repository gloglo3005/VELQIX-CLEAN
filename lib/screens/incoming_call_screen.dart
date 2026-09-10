// ═══════════════════════════════════════════════════════════════════
// INCOMING CALL SCREEN — écran "appel entrant", poussé globalement par
// main_shell.dart dès que incomingCallNotifier (chat_service.dart) change.
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import '../widgets/widgets.dart';
import 'agora_call_screen.dart';
import 'agora_video_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final Map<String, dynamic> callData;
  const IncomingCallScreen({super.key, required this.callData});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _responding = false;
  StreamSubscription? _statusSub;

  String get _callId => widget.callData['callId'] as String;
  String get _type => widget.callData['type'] as String? ?? 'audio';
  String get _channelName => widget.callData['channelName'] as String? ?? '';

  UserModel get _caller {
    final raw = widget.callData['caller'] as Map?;
    // Payload backend minimal (id, nom, prenom, avatarUrl) — createdAt n'a
    // aucun sens ici, juste requis par UserModel.fromJson pour l'affichage.
    return UserModel.fromJson({
      'id': raw?['id'] ?? widget.callData['callerId'],
      'nom': raw?['nom'] ?? '',
      'prenom': raw?['prenom'] ?? '',
      'avatarUrl': raw?['avatarUrl'],
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  void initState() {
    super.initState();
    // Si l'appelant raccroche ou que l'appel expire (30s sans réponse) avant
    // qu'on ait répondu, on referme cet écran tout seul.
    _statusSub = ChatService.instance.onCallStatus.listen((data) {
      if (data['callId'] == _callId && (data['event'] == 'ended' || data['event'] == 'rejected')) {
        if (mounted && !_responding) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_responding) return;
    setState(() => _responding = true);
    final ok = await ChatService.instance.acceptCall(_callId);
    if (!mounted) return;
    if (!ok || _channelName.isEmpty) {
      setState(() => _responding = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Impossible d'accepter l'appel — réessaie.",
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => _type == 'video'
          ? AgoraVideoCallScreen(remoteUser: _caller, channelName: _channelName, isCaller: false, callId: _callId)
          : AgoraCallScreen(remoteUser: _caller, channelName: _channelName, isCaller: false, callId: _callId),
    ));
  }

  void _reject() {
    ChatService.instance.rejectCall(_callId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // on ne quitte cet écran que via Accepter/Refuser
      child: Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 80),
              UserAvatar(user: _caller, radius: 55),
              const SizedBox(height: 24),
              Text(_caller.fullName,
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                _type == 'video' ? 'Appel vidéo entrant...' : 'Appel entrant...',
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.white60),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(children: [
                      ElevatedButton(
                        onPressed: _responding ? null : _reject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(22),
                          elevation: 4,
                        ),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text('Refuser', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60)),
                    ]),
                    Column(children: [
                      ElevatedButton(
                        onPressed: _responding ? null : _accept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(22),
                          elevation: 4,
                        ),
                        child: _responding
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(_type == 'video' ? Icons.videocam_rounded : Icons.call_rounded,
                                color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text('Accepter', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}