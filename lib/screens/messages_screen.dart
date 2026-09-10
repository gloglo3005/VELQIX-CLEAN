import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../services/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agora_call_screen.dart';
import 'agora_video_call_screen.dart';
// import 'wallet_screen.dart';           // 🚫 DÉSACTIVÉ (25/08/2026)
// import '../services/wallet_service.dart'; // 🚫 DÉSACTIVÉ (25/08/2026)
import '../models/models.dart';
// import '../services/mock_data.dart'; // 🚫 DÉSACTIVÉ (25/08/2026) : plus de données factices
import '../theme/app_theme.dart';
import '../services/web_file_picker.dart';
import '../services/chat_service.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';

// ═══════════════════════════════════════════════════════════════════
// MESSAGES SCREEN — liste des conversations (style WhatsApp)
// ═══════════════════════════════════════════════════════════════════

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {

  @override
  void initState() {
    super.initState();
    // Charger les conversations depuis l'API au démarrage
    ChatService.instance.loadConversations();
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Prévient d'abord le destinataire via call:invite (voir callSocket.ts) —
  // le channelName vient toujours du serveur, jamais généré localement,
  // sinon l'appelant et l'appelé peuvent finir chacun dans un canal différent.
  Future<void> _startAgoraCall(BuildContext ctx, dynamic user) async {
    final result = await ChatService.instance.inviteCall(calleeId: user.id, type: 'audio');
    if (!ctx.mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text("Impossible de joindre ${user.fullName} pour le moment.",
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AgoraCallScreen(
        remoteUser: user,
        channelName: result['channelName'] as String,
        isCaller: true,
        callId: result['callId'] as String,
      ),
    ));
  }

  Future<void> _startVideoCall(BuildContext ctx, dynamic user) async {
    // 🚫 DÉSACTIVÉ (25/08/2026) : wallet plus utilisé, les appels vidéo sont
    // gratuits/illimités pour l'instant — plus de vérification de solde.
    // final canCall = await WalletService.instance.canStartVideoCall();
    // if (!mounted) return;
    //
    // if (!canCall) {
    //   showDialog(
    //     context: ctx,
    //     builder: (_) => AlertDialog(
    //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    //       title: Text('Solde insuffisant',
    //           style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
    //       content: Column(mainAxisSize: MainAxisSize.min, children: [
    //         const Icon(Icons.account_balance_wallet_rounded,
    //             size: 50, color: AppTheme.accent),
    //         const SizedBox(height: 12),
    //         Text(
    //           "Vous avez besoin d'au moins 10 FCFA pour lancer un appel vidéo (10 FCFA/min).",
    //           style: GoogleFonts.poppins(fontSize: 13,
    //               color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
    //           textAlign: TextAlign.center,
    //         ),
    //       ]),
    //       actions: [
    //         TextButton(
    //           onPressed: () => Navigator.pop(ctx),
    //           child: Text('Annuler',
    //               style: GoogleFonts.poppins(
    //                   color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
    //         ),
    //         ElevatedButton(
    //           style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
    //           onPressed: () {
    //             Navigator.pop(ctx);
    //             Navigator.push(ctx, MaterialPageRoute(builder: (_) => const WalletScreen()));
    //           },
    //           child: Text('Recharger',
    //               style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
    //         ),
    //       ],
    //     ),
    //   );
    //   return;
    // }

    final result = await ChatService.instance.inviteCall(calleeId: user.id, type: 'video');
    if (!ctx.mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text("Impossible de joindre ${user.fullName} pour le moment.",
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AgoraVideoCallScreen(
        remoteUser: user,
        channelName: result['channelName'] as String,
        isCaller: true,
        callId: result['callId'] as String,
      ),
    ));
  }

  void _showNewConversationDialog(BuildContext context) {
    // ⚠️ Avant : liste d'utilisateurs 100% factice (MockDataService.users).
    // Maintenant : recherche réelle via GET /api/users?search=... (nouvel
    // endpoint, sans email/téléphone exposés — le contact se fait par chat).
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NewConversationSheet(
        onUserSelected: (u) {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatScreen(user: u),
          ));
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return jours[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(tr('msg_title'),
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
            onPressed: () => _showNewConversationDialog(context),
          ),
        ],
      ),
      // ── ValueListenableBuilder : se reconstruit automatiquement à chaque
      //    nouveau message ou mise à jour de conversation ─────────────────
      body: ValueListenableBuilder<List<Conversation>>(
        valueListenable: conversationsNotifier,
        builder: (context, conversations, _) {
          if (conversations.isEmpty) {
            return Center(
              child: Text(
                "Aucune conversation pour l'instant",
                style: GoogleFonts.poppins(fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
              ),
            );
          }

          return RefreshIndicator(
            // Pull-to-refresh pour recharger depuis l'API
            onRefresh: () => ChatService.instance.loadConversations(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
              itemBuilder: (_, i) {
                final conv = conversations[i];
                return ListTile(
                  onTap: () {
                    // Ouvrir le chat et remettre unread à 0
                    ChatService.instance.markAsRead(conv.otherUserId);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        user: _userFromConversation(conv),
                        conversationId: conv.id,
                        otherUserId: conv.otherUserId,
                      ),
                    ));
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  leading: _ConversationAvatar(
                    name: conv.otherUserName,
                    avatarUrl: conv.otherUserAvatar,
                  ),
                  title: Text(conv.otherUserName,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: conv.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                  subtitle: Text(conv.lastMessage,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary,
                          fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatTime(conv.lastMessageAt),
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: conv.unreadCount > 0 ? AppTheme.primary : AppTheme.textHint)),
                      if (conv.unreadCount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                              color: AppTheme.primary, shape: BoxShape.circle),
                          child: Text('${conv.unreadCount}',
                              style: GoogleFonts.poppins(
                                  fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Construit un UserModel minimal depuis une Conversation pour l'ouvrir
  dynamic _userFromConversation(Conversation conv) {
    return UserModel(
      id: conv.otherUserId,
      nom: conv.otherUserName.split(' ').last,
      prenom: conv.otherUserName.split(' ').first,
      email: '',
      telephone: '',
      avatarUrl: conv.otherUserAvatar,
      createdAt: DateTime.now(),
    );
  }
}

/// Avatar simplifié pour les conversations (pas de UserModel complet requis)
class _ConversationAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  const _ConversationAvatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(radius: 26, backgroundImage: NetworkImage(avatarUrl!));
    }
    final initials = name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    return CircleAvatar(
      radius: 26,
      backgroundColor: AppTheme.primary.withOpacity(0.15),
      child: Text(initials,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primary)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CHAT SCREEN — écran de conversation individuel
// ═══════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════
// NEW CONVERSATION SHEET — recherche réelle via GET /api/users?search=...
// ═══════════════════════════════════════════════════════════════════
class _NewConversationSheet extends StatefulWidget {
  final void Function(UserModel) onUserSelected;
  const _NewConversationSheet({required this.onUserSelected});

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<UserModel> _results = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() { _loading = true; _error = null; });
    try {
      final qs = query.trim().isEmpty ? '' : '?search=${Uri.encodeComponent(query.trim())}';
      final res = await ApiService.instance.get('/users$qs', auth: true);
      if (res['success'] == true) {
        final list = (res['data'] as List)
            .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() { _results = list; _loading = false; });
      } else {
        if (mounted) setState(() { _error = res['message'] ?? 'Erreur'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Recherche impossible'; _loading = false; });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Nouvelle conversation',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: GoogleFonts.poppins(color: AppTheme.textSecondary)))
                    : _results.isEmpty
                        ? Center(
                            child: Text('Aucun utilisateur trouvé',
                                style: GoogleFonts.poppins(color: AppTheme.textSecondary)))
                        : ListView(
                            children: _results.map((u) => ListTile(
                              leading: UserAvatar(user: u, radius: 22),
                              title: Text(u.fullName,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                              onTap: () => widget.onUserSelected(u),
                            )).toList(),
                          ),
          ),
        ]),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final dynamic user;
  final String? propertyTitre;
  final String? conversationId;
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.user,
    this.propertyTitre,
    this.conversationId,
    this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  // ID de l'interlocuteur (priorité au paramètre, fallback sur user.id)
  String get _otherUserId => widget.otherUserId ?? (widget.user?.id as String? ?? '');

  bool _isTyping = false; // l'autre utilisateur est en train d'écrire
  Timer? _typingTimer;    // permet d'annuler le timer précédent à chaque événement

  // ── Enregistrement vocal ──────────────────────────────────────────
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTicker;

  late StreamSubscription<MessageModel> _msgSub;
  late StreamSubscription<Map<String, dynamic>> _typingSub;
  late StreamSubscription<String> _readSub;

  @override
  void initState() {
    super.initState();

    // 1. Charger l'historique depuis le cache ou l'API
    ChatService.instance.loadMessages(_otherUserId).then((_) {
      _scrollToBottom(animate: false);
    });

    // 2. Si on vient d'une fiche bien, pré-remplir un message contextuel
    if (widget.propertyTitre != null) {
      _msgCtrl.text =
          'Bonjour ! Je suis intéressé(e) par votre bien : "${widget.propertyTitre}". Est-il toujours disponible ?';
    }

    // 3. Marquer comme lu à l'ouverture
    ChatService.instance.markAsRead(_otherUserId);

    // 4. Écouter les nouveaux messages entrants via Socket
    _msgSub = ChatService.instance.onMessage.listen((msg) {
      if (msg.senderId == _otherUserId || msg.receiverId == _otherUserId) {
        // Le cache est déjà mis à jour dans ChatService → juste rebuilder
        if (mounted) setState(() {});
        ChatService.instance.markAsRead(_otherUserId);
        _scrollToBottom();
      }
    });

    // 5. Écouter l'indicateur "en train d'écrire"
    _typingSub = ChatService.instance.onTyping.listen((data) {
      if (data['senderId'] == _otherUserId && mounted) {
        setState(() => _isTyping = data['isTyping'] == true);
        // On annule le timer précédent à chaque nouvel événement : sinon,
        // si l'autre personne tape en continu, plusieurs timers s'accumulent
        // et l'un d'eux coupe l'indicateur alors qu'elle tape toujours.
        _typingTimer?.cancel();
        if (_isTyping) {
          _typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _isTyping = false);
          });
        }
      }
    });

    // 6. Mettre à jour les coches de lecture (✓✓ bleu)
    _readSub = ChatService.instance.onReadAck.listen((readBy) {
      if (readBy == _otherUserId && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _msgSub.cancel();
    _typingSub.cancel();
    _readSub.cancel();
    _typingTimer?.cancel();
    _recordTicker?.cancel();
    _recorder.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    // Arrêter l'indicateur de frappe si on quitte
    ChatService.instance.sendTyping(_otherUserId, isTyping: false);
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (animate) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      }
    });
  }

  String _nowTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ─── Envoi d'un message ───────────────────────────────────────────
  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    // Arrêter l'indicateur de frappe
    ChatService.instance.sendTyping(_otherUserId, isTyping: false);

    // Envoyer via ChatService (optimistic UI inclus)
    ChatService.instance.sendMessage(receiverId: _otherUserId, text: text).then((_) {
      if (mounted) setState(() {});
      _scrollToBottom();
    });

    // Scroll immédiat (optimistic)
    _scrollToBottom();
  }

  // ─── Indicateur de frappe envoyé au serveur ───────────────────────
  void _onTextChanged(String value) {
    ChatService.instance.sendTyping(_otherUserId, isTyping: value.isNotEmpty);
    // Rebuild pour basculer l'icône micro ↔ envoi selon le champ texte
    if (mounted) setState(() {});
  }

  String _formatRecordDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    try {
      final granted = await _recorder.hasPermission();
      if (!granted) {
        debugPrint('❌ _startRecording: permission micro refusée');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Autorisation micro refusée — vérifie les paramètres du site dans ton navigateur (icône 🔒 à côté de l'URL)."),
          ));
        }
        return;
      }

      String path = '';
      RecordConfig config;
      if (kIsWeb) {
        // Le web n'a pas de vrai système de fichiers : path_provider ne
        // fonctionne pas ici (record gère tout en mémoire et renverra une
        // blob URL au stop()). Seul l'encodeur Opus est fiable sur le web —
        // aac/m4a (utilisé sur mobile) n'y est pas supporté.
        config = const RecordConfig(encoder: AudioEncoder.opus);
      } else {
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        config = const RecordConfig(encoder: AudioEncoder.aacLc);
      }

      await _recorder.start(config, path: path);
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e, st) {
      debugPrint('❌ _startRecording: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible de démarrer l'enregistrement : $e")),
        );
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    _recordTicker?.cancel();
    final path = await _recorder.stop();
    final duration = _recordSeconds;
    if (mounted) setState(() => _isRecording = false);

    // Enregistrement trop court (appui accidentel) : on l'ignore
    if (path == null || duration < 1) return;

    ChatService.instance.sendAudioMessage(
      receiverId: _otherUserId,
      localFilePath: path,
      durationSeconds: duration,
    ).then((_) {
      if (mounted) setState(() {});
      _scrollToBottom();
    });
    _scrollToBottom();
  }

  Future<void> _cancelRecording() async {
    _recordTicker?.cancel();
    await _recorder.stop();
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _startAgoraCall(BuildContext ctx, dynamic user) async {
    final result = await ChatService.instance.inviteCall(calleeId: user.id, type: 'audio');
    if (!ctx.mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text("Impossible de joindre ${user.fullName} pour le moment.",
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AgoraCallScreen(
        remoteUser: user,
        channelName: result['channelName'] as String,
        isCaller: true,
        callId: result['callId'] as String,
      ),
    ));
  }

  Future<void> _startVideoCall(BuildContext ctx, dynamic user) async {
    // 🚫 DÉSACTIVÉ (25/08/2026) : wallet plus utilisé, appels gratuits/illimités
    // final canCall = await WalletService.instance.canStartVideoCall();
    // if (!mounted) return;
    //
    // if (!canCall) {
    //   showDialog(
    //     context: ctx,
    //     builder: (_) => AlertDialog(
    //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    //       title: Text('Solde insuffisant',
    //           style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
    //       content: Column(mainAxisSize: MainAxisSize.min, children: [
    //         const Icon(Icons.account_balance_wallet_rounded, size: 50, color: AppTheme.accent),
    //         const SizedBox(height: 12),
    //         Text(
    //           "Vous avez besoin d'au moins 10 FCFA pour lancer un appel vidéo (10 FCFA/min).",
    //           style: GoogleFonts.poppins(fontSize: 13,
    //               color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
    //           textAlign: TextAlign.center,
    //         ),
    //       ]),
    //       actions: [
    //         TextButton(
    //           onPressed: () => Navigator.pop(ctx),
    //           child: Text('Annuler',
    //               style: GoogleFonts.poppins(
    //                   color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
    //         ),
    //         ElevatedButton(
    //           style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
    //           onPressed: () {
    //             Navigator.pop(ctx);
    //             Navigator.push(ctx, MaterialPageRoute(builder: (_) => const WalletScreen()));
    //           },
    //           child: Text('Recharger',
    //               style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
    //         ),
    //       ],
    //     ),
    //   );
    //   return;
    // }

    final result = await ChatService.instance.inviteCall(calleeId: user.id, type: 'video');
    if (!ctx.mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text("Impossible de joindre ${user.fullName} pour le moment.",
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AgoraVideoCallScreen(
        remoteUser: user,
        channelName: result['channelName'] as String,
        isCaller: true,
        callId: result['callId'] as String,
      ),
    ));
  }

  void _showChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
          title: Text(tr('msg_clear'),
              style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.error)),
          onTap: () {
            Navigator.pop(context);
            // Vider le cache local pour cette conversation
            final current = Map<String, List<MessageModel>>.from(messagesNotifier.value);
            current[_otherUserId] = [];
            messagesNotifier.value = current;
            if (mounted) setState(() {});
          },
        ),
        ListTile(
          leading: Icon(Icons.block_rounded,
              color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
          title: Text(tr('msg_block'), style: GoogleFonts.poppins(fontSize: 14)),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr('msg_blocked'),
                  style: GoogleFonts.poppins(color: Colors.white)),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ));
          },
        ),
        ListTile(
          leading: Icon(Icons.flag_outlined,
              color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
          title: Text(tr('msg_report'), style: GoogleFonts.poppins(fontSize: 14)),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr('msg_reported'),
                  style: GoogleFonts.poppins(color: Colors.white)),
              backgroundColor: AppTheme.info,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ));
          },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  Future<void> _attachImage(BuildContext context) async {
    final files = await WebFilePicker.pickMultipleImages(maxCount: 1);
    if (files.isEmpty || !mounted) return;

    ChatService.instance.sendImageMessage(
      receiverId: _otherUserId,
      dataUri: files.first,
    ).then((_) {
      if (mounted) setState(() {});
      _scrollToBottom();
    });
    setState(() {});
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 18,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
          ),
        ),
        title: Row(children: [
          UserAvatar(user: widget.user, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.user?.fullName ?? '',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis),
              // Afficher "En train d'écrire..." ou "En ligne"
              if (_isTyping)
                Text('En train d\'écrire…',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primary,
                        fontStyle: FontStyle.italic))
              else
                Row(children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: AppTheme.success, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(tr('msg_online'),
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.success)),
                ]),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppTheme.primary),
            onPressed: () => _startAgoraCall(context, widget.user),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: AppTheme.primary),
            onPressed: () => _startVideoCall(context, widget.user),
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
            onPressed: () => _showChatOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Bannière contexte du bien ──────────────────────────────
          if (widget.propertyTitre != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.home_outlined, size: 16, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Concernant le bien',
                        style: GoogleFonts.poppins(fontSize: 10,
                            color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
                    Text(widget.propertyTitre!,
                        style: GoogleFonts.poppins(fontSize: 12,
                            fontWeight: FontWeight.w600, color: AppTheme.primary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ),

          // ── Liste des messages (depuis le cache ValueNotifier) ─────
          Expanded(
            child: ValueListenableBuilder<Map<String, List<MessageModel>>>(
              valueListenable: messagesNotifier,
              builder: (context, allMessages, _) {
                final messages = allMessages[_otherUserId] ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Text('Aucun message pour l\'instant',
                        style: GoogleFonts.poppins(fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color
                                ?? AppTheme.textSecondary)),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg   = messages[i];
                    final isMe  = msg.senderId != _otherUserId;
                    final time  = _formatTime(msg.timestamp);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment:
                              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              UserAvatar(user: widget.user, radius: 14),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.68),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? AppTheme.primary : AppTheme.surface,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 6)
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  msg.isImage
                                      ? _ImageMessageBubble(message: msg)
                                      : msg.isAudio
                                      ? _VoiceMessageBubble(message: msg, isMe: isMe)
                                      : Text(msg.text,
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: isMe
                                              ? Colors.white
                                              : AppTheme.textPrimary,
                                          height: 1.4)),
                                  const SizedBox(height: 3),
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text(time,
                                        style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: isMe
                                                ? Colors.white.withOpacity(0.7)
                                                : AppTheme.textHint)),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      // ✓ envoi / ✓✓ livré / ✓✓ bleu lu
                                      _buildReadIcon(msg),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── Indicateur "En train d'écrire" ────────────────────────
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 4),
              child: Row(children: [
                UserAvatar(user: widget.user, radius: 12),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                  ),
                  child: Row(children: [
                    _TypingDot(delay: 0),
                    const SizedBox(width: 3),
                    _TypingDot(delay: 150),
                    const SizedBox(width: 3),
                    _TypingDot(delay: 300),
                  ]),
                ),
              ]),
            ),

          // ── Zone de saisie ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -2))
              ],
            ),
            child: _isRecording
                ? Row(children: [
                    const Icon(Icons.mic_rounded, color: AppTheme.error, size: 22),
                    const SizedBox(width: 8),
                    Text(_formatRecordDuration(_recordSeconds),
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _cancelRecording,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.error, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _stopRecordingAndSend,
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: const BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ])
                : Row(children: [
              GestureDetector(
                onTap: () => _attachImage(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.attach_file_rounded,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6)
                          ?? AppTheme.textHint,
                      size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onChanged: _onTextChanged,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: tr('msg_hint'),
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6)
                            ?? AppTheme.textHint),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    filled: true,
                    fillColor: AppTheme.background,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _msgCtrl.text.trim().isEmpty
                  ? GestureDetector(
                      // Appui long = enregistrer, relâcher = envoyer (façon WhatsApp)
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressEnd: (_) => _stopRecordingAndSend(),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: const BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.mic_rounded, size: 18, color: Colors.white),
                      ),
                    )
                  : GestureDetector(
                      onTap: _send,
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: const BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      ),
                    ),
            ]),
          ),
        ],
      ),
    );
  }

  /// Icône de statut du message (envoi / livré / lu)
  Widget _buildReadIcon(MessageModel msg) {
    switch (msg.status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time_rounded, size: 13,
            color: Colors.white.withOpacity(0.7));
      case MessageStatus.failed:
        return const Icon(Icons.error_outline_rounded, size: 13, color: Colors.redAccent);
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded, size: 13, color: Colors.lightBlueAccent.shade100);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 13, color: Colors.white.withOpacity(0.7));
      case MessageStatus.sent:
      default:
        return Icon(Icons.done_rounded, size: 13, color: Colors.white.withOpacity(0.7));
    }
  }
}

// ─── Bulle de message image (pièce jointe chat) ──────────────────────────────
class _ImageMessageBubble extends StatelessWidget {
  final MessageModel message;
  const _ImageMessageBubble({required this.message});

  ImageProvider _provider(String url) {
    if (url.startsWith('data:')) {
      final parts = url.split(',');
      return MemoryImage(base64Decode(parts.length > 1 ? parts[1] : ''));
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final url = message.imageUrl;
    if (url == null) return const SizedBox.shrink();
    final provider = _provider(url);

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: InteractiveViewer(child: Image(image: provider, fit: BoxFit.contain)),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: provider,
          width: 180,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 180, height: 180,
            color: AppTheme.background,
            child: const Icon(Icons.broken_image_rounded, color: AppTheme.textHint),
          ),
        ),
      ),
    );
  }
}

// ─── Lecteur de message vocal (bulle chat) ───────────────────────────────────
class _VoiceMessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  const _VoiceMessageBubble({required this.message, required this.isMe});

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    _total = Duration(seconds: widget.message.audioDuration ?? 0);
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _position = Duration.zero; });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final url = widget.message.audioUrl;
    if (url == null) return;
    if (_isPlaying) {
      await _player.pause();
    } else if (url.startsWith('http') || url.startsWith('blob:')) {
      // 'blob:' = enregistrement pas encore uploadé, lu directement depuis
      // la mémoire du navigateur (web) — pas un fichier sur disque.
      await _player.play(UrlSource(url));
    } else {
      await _player.play(DeviceFileSource(url));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : AppTheme.primary;
    final shown = _position > Duration.zero ? _position : _total;
    return SizedBox(
      width: 170,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _toggle,
          child: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: color, size: 32),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _total.inMilliseconds == 0
                    ? 0
                    : _position.inMilliseconds / _total.inMilliseconds,
                minHeight: 3,
                backgroundColor: color.withOpacity(0.25),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(_fmt(shown),
                style: GoogleFonts.poppins(fontSize: 11,
                    color: widget.isMe ? Colors.white.withOpacity(0.85) : AppTheme.textHint)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Bulle animée "En train d'écrire" ────────────────────────────────────────
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(widget.delay / 600, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: AppTheme.textHint,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}