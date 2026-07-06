import 'dart:async';
import '../services/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agora_call_screen.dart';
import 'agora_video_call_screen.dart';
import 'wallet_screen.dart';
import '../services/wallet_service.dart';
import '../models/models.dart';
import '../services/mock_data.dart';
import '../theme/app_theme.dart';
import '../services/web_file_picker.dart';
import '../services/chat_service.dart';
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

  void _startAgoraCall(BuildContext ctx, dynamic user) {
    final channelName = 'velqix_${user.id}';
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AgoraCallScreen(
        remoteUser: user,
        channelName: channelName,
        isCaller: true,
      ),
    ));
  }

  Future<void> _startVideoCall(BuildContext ctx, dynamic user) async {
    final canCall = await WalletService.instance.canStartVideoCall();
    if (!mounted) return;

    if (!canCall) {
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Solde insuffisant',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.account_balance_wallet_rounded,
                size: 50, color: AppTheme.accent),
            const SizedBox(height: 12),
            Text(
              "Vous avez besoin d'au moins 10 FCFA pour lancer un appel vidéo (10 FCFA/min).",
              style: GoogleFonts.poppins(fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler',
                  style: GoogleFonts.poppins(
                      color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => const WalletScreen()));
              },
              child: Text('Recharger',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AgoraVideoCallScreen(
        remoteUser: user,
        channelName: 'velqix_video_${user.id}',
        isCaller: true,
      ),
    ));
  }

  void _showNewConversationDialog(BuildContext context) {
    final users = MockDataService.users
        .where((u) => u.id != MockDataService.currentUser.id)
        .toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Nouvelle conversation',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
        const SizedBox(height: 12),
        ...users.map((u) => ListTile(
          leading: UserAvatar(user: u, radius: 22),
          title: Text(u.fullName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(u.telephone ?? '',
              style: GoogleFonts.poppins(fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatScreen(user: u),
            ));
          },
        )),
        const SizedBox(height: 16),
      ]),
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
        if (_isTyping) {
          // Éteindre l'indicateur après 3 secondes si pas de mise à jour
          Future.delayed(const Duration(seconds: 3), () {
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
  }

  void _startAgoraCall(BuildContext ctx, dynamic user) {
    final channelName = 'velqix_${user.id}';
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AgoraCallScreen(
        remoteUser: user,
        channelName: channelName,
        isCaller: true,
      ),
    ));
  }

  Future<void> _startVideoCall(BuildContext ctx, dynamic user) async {
    final canCall = await WalletService.instance.canStartVideoCall();
    if (!mounted) return;

    if (!canCall) {
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Solde insuffisant',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.account_balance_wallet_rounded, size: 50, color: AppTheme.accent),
            const SizedBox(height: 12),
            Text(
              "Vous avez besoin d'au moins 10 FCFA pour lancer un appel vidéo (10 FCFA/min).",
              style: GoogleFonts.poppins(fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler',
                  style: GoogleFonts.poppins(
                      color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => const WalletScreen()));
              },
              child: Text('Recharger',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AgoraVideoCallScreen(
        remoteUser: user,
        channelName: 'velqix_video_${user.id}',
        isCaller: true,
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
    if (files.isNotEmpty && mounted) {
      // TODO: uploader l'image via l'API et envoyer l'URL
      setState(() {});
      _scrollToBottom();
    }
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
                                  Text(msg.text,
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
            child: Row(children: [
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
              GestureDetector(
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