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
import '../widgets/widgets.dart';

// ═══════════════════════════════════════════════════════════════════
// STORE GLOBAL — persiste messages + état lu pendant toute la session
// ═══════════════════════════════════════════════════════════════════
class _ChatStore {
  static final Map<String, List<Map<String, dynamic>>> _messages = {};
  static final Map<String, int> _unread = {};
  static final Map<String, String> _lastMsg = {};
  static final Map<String, String> _lastTime = {};

  // Messages
  static List<Map<String, dynamic>> getMessages(
    String userId, {
    List<Map<String, dynamic>>? defaultMessages,
  }) {
    if (!_messages.containsKey(userId)) {
      _messages[userId] = List.from(defaultMessages ?? []);
    }
    return _messages[userId]!;
  }

  static void saveMessages(String userId, List<Map<String, dynamic>> msgs) {
    _messages[userId] = List.from(msgs);
    // Mettre à jour aperçu dernier message
    if (msgs.isNotEmpty) {
      final last = msgs.last;
      _lastMsg[userId] = (last['text'] as String).isNotEmpty
          ? last['text'] as String
          : '📷 Image';
      _lastTime[userId] = last['time'] as String;
    } else {
      _lastMsg[userId] = '';
      _lastTime[userId] = '';
    }
  }

  static void clearMessages(String userId) {
    _messages[userId] = [];
    _lastMsg[userId] = '';
    _lastTime[userId] = '';
  }

  // Unread
  static int getUnread(String userId) => _unread[userId] ?? -1;
  static void markRead(String userId) => _unread[userId] = 0;
  static void setUnread(String userId, int count) => _unread[userId] = count;

  // Aperçu
  static String getLastMsg(String userId, String fallback) =>
      _lastMsg.containsKey(userId) ? _lastMsg[userId]! : fallback;
  static String getLastTime(String userId, String fallback) =>
      _lastTime.containsKey(userId) ? _lastTime[userId]! : fallback;
}

// ── Utilitaire horodatage ────────────────────────────────────────
String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(dt.year, dt.month, dt.day);
  if (d == today) return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  if (d == yesterday) return 'Hier';
  final weekdays = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];
  if (now.difference(dt).inDays < 7) return weekdays[dt.weekday - 1];
  return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}';
}

String _nowTime() {
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
}

// ═══════════════════════════════════════════════════════════════════
// MESSAGES SCREEN — Liste des conversations
// ═══════════════════════════════════════════════════════════════════
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late List<Map<String, dynamic>> _conversations;

  @override
  void initState() {
    super.initState();
    _conversations = [
      {'user': MockDataService.users[1], 'lastMsg': 'Bonjour, le bien est-il toujours disponible ?', 'time': '10:24', 'unread': 2, 'propertyId': 'p1'},
      {'user': MockDataService.users[3], 'lastMsg': 'Merci pour la réservation, vous pouvez venir récupérer les clés à partir de 14h.', 'time': 'Hier', 'unread': 0, 'propertyId': 'p2'},
      {'user': MockDataService.users[2], 'lastMsg': 'D\'accord, je confirme pour le 20 avril.', 'time': 'Lun', 'unread': 0, 'propertyId': 'p3'},
    ];
    // Init unread dans le store si pas encore fait
    for (final c in _conversations) {
      final user = c['user'] as dynamic;
      if (_ChatStore.getUnread(user.id.toString()) == -1) {
        _ChatStore.setUnread(user.id.toString(), c['unread'] as int);
      }
    }
  }

  void _openChat(dynamic user, {String? propertyTitre}) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(
        user: user,
        propertyTitre: propertyTitre,
        onMessagesUpdated: () => setState(() {}),
      ),
    ));
    // Rafraîchir après retour
    setState(() {});
  }

  void _showNewConversationDialog(BuildContext context) {
    final users = MockDataService.users
        .where((u) => u.id != MockDataService.currentUser.id)
        .toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Nouvelle conversation', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
        const SizedBox(height: 12),
        ...users.map((u) => ListTile(
          leading: UserAvatar(user: u, radius: 22),
          title: Text(u.fullName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(u.telephone ?? '', style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
          onTap: () {
            Navigator.pop(context);
            _openChat(u);
          },
        )),
        const SizedBox(height: 16),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(tr('msg_title'), style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
            onPressed: () => _showNewConversationDialog(context),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
        itemBuilder: (_, i) {
          final c = _conversations[i];
          final user = c['user'] as dynamic;
          final uid = user.id.toString();
          final unread = _ChatStore.getUnread(uid) == -1
              ? (c['unread'] as int)
              : _ChatStore.getUnread(uid);
          final lastMsg = _ChatStore.getLastMsg(uid, c['lastMsg'] as String);
          final lastTime = _ChatStore.getLastTime(uid, c['time'] as String);

          return ListTile(
            onTap: () => _openChat(user),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: UserAvatar(user: user, radius: 26),
            title: Text(user.fullName,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
            subtitle: Text(lastMsg,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: unread > 0 ? AppTheme.primary : (Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
                    fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(lastTime, style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: unread > 0 ? AppTheme.primary : AppTheme.textHint,
                    fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400)),
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                    child: Text('$unread', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CHAT SCREEN — Conversation individuelle style WhatsApp
// ═══════════════════════════════════════════════════════════════════
class ChatScreen extends StatefulWidget {
  final dynamic user;
  final String? propertyTitre;
  final VoidCallback? onMessagesUpdated;
  const ChatScreen({super.key, required this.user, this.propertyTitre, this.onMessagesUpdated});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late List<Map<String, dynamic>> _messages;

  @override
  void initState() {
    super.initState();
    final defaultMessages = widget.propertyTitre != null
        ? [
            {
              'text': 'Bonjour ! Je suis intéressé(e) par votre bien : "${widget.propertyTitre}". Est-il toujours disponible ?',
              'isMe': true,
              'time': _nowTime(),
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'read': false,
            },
          ]
        : [
            {'text': 'Bonjour, le bien est-il toujours disponible ?', 'isMe': false, 'time': '10:24', 'timestamp': 0, 'read': true},
            {'text': 'Oui, tout à fait ! Souhaitez-vous une visite ?', 'isMe': true, 'time': '10:26', 'timestamp': 0, 'read': true},
            {'text': 'Oui avec plaisir. Je suis disponible mercredi après-midi ou jeudi matin.', 'isMe': false, 'time': '10:28', 'timestamp': 0, 'read': true},
            {'text': 'Mercredi 15h vous conviendrait ?', 'isMe': true, 'time': '10:30', 'timestamp': 0, 'read': true},
            {'text': 'Parfait, à mercredi alors !', 'isMe': false, 'time': '10:31', 'timestamp': 0, 'read': true},
          ];

    _messages = _ChatStore.getMessages(widget.user.id.toString(), defaultMessages: defaultMessages);

    // Marquer comme lu à l'ouverture
    _ChatStore.markRead(widget.user.id.toString());

    // Marquer tous les messages reçus comme lus
    for (final m in _messages) {
      if (m['isMe'] == false) m['read'] = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _nowTime() => _formatTime(DateTime.now());

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _send() {
    if (_msgCtrl.text.trim().isEmpty) return;
    final text = _msgCtrl.text.trim();
    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
        'time': _nowTime(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
      });
      _ChatStore.saveMessages(widget.user.id.toString(), _messages);
      widget.onMessagesUpdated?.call();
      _msgCtrl.clear();
    });
    // Simuler "lu" après 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        for (final m in _messages) {
          if (m['isMe'] == true) m['read'] = true;
        }
        _ChatStore.saveMessages(widget.user.id.toString(), _messages);
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _deleteMessage(int index) {
    setState(() {
      _messages.removeAt(index);
      _ChatStore.saveMessages(widget.user.id.toString(), _messages);
      widget.onMessagesUpdated?.call();
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Message copié', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showMessageOptions(BuildContext context, int index, Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        if ((m['text'] as String).isNotEmpty)
          ListTile(
            leading: Icon(Icons.copy_rounded, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
            title: Text('Copier', style: GoogleFonts.poppins(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              _copyMessage(m['text'] as String);
            },
          ),
        ListTile(
          leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
          title: Text('Supprimer', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.error)),
          onTap: () {
            Navigator.pop(context);
            _deleteMessage(index);
          },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startAgoraCall(BuildContext ctx, dynamic user) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AgoraCallScreen(remoteUser: user, channelName: 'velqix_${user.id}', isCaller: true),
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
          title: Text('Solde insuffisant', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.account_balance_wallet_rounded, size: 50, color: AppTheme.accent),
            const SizedBox(height: 12),
            Text("Vous avez besoin d'au moins 10 FCFA pour lancer un appel vidéo (10 FCFA/min).",
                style: GoogleFonts.poppins(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
                textAlign: TextAlign.center),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.poppins(color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => const WalletScreen()));
              },
              child: Text('Recharger', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => AgoraVideoCallScreen(remoteUser: user, channelName: 'velqix_video_${user.id}', isCaller: true),
    ));
  }

  void _showChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
          title: Text(tr('msg_clear'), style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.error)),
          onTap: () {
            Navigator.pop(context);
            setState(() {
              _messages.clear();
              _ChatStore.clearMessages(widget.user.id.toString());
              widget.onMessagesUpdated?.call();
            });
          },
        ),
        ListTile(
          leading: Icon(Icons.block_rounded, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
          title: Text(tr('msg_block'), style: GoogleFonts.poppins(fontSize: 14)),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr('msg_blocked'), style: GoogleFonts.poppins(color: Colors.white)),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ));
          },
        ),
        ListTile(
          leading: Icon(Icons.flag_outlined, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
          title: Text(tr('msg_report'), style: GoogleFonts.poppins(fontSize: 14)),
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr('msg_reported'), style: GoogleFonts.poppins(color: Colors.white)),
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
      setState(() {
        _messages.add({
          'text': '',
          'imageUrl': files.first,
          'isMe': true,
          'time': _nowTime(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'read': false,
        });
        _ChatStore.saveMessages(widget.user.id.toString(), _messages);
        widget.onMessagesUpdated?.call();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Widget _buildMessageBubble(int index, Map<String, dynamic> m) {
    final isMe = m['isMe'] as bool;
    final text = m['text'] as String;
    final time = m['time'] as String;
    final read = m['read'] as bool? ?? false;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context, index, m),
      child: Dismissible(
        key: Key('msg_$index${m['timestamp']}'),
        direction: isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
        background: Container(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Supprimer ce message ?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Annuler', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Supprimer', style: GoogleFonts.poppins(color: AppTheme.error, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ) ?? false;
        },
        onDismissed: (_) => _deleteMessage(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  UserAvatar(user: widget.user, radius: 14),
                  const SizedBox(width: 6),
                ],
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (m['imageUrl'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: m['imageUrl'].toString().startsWith('blob:')
                              ? SizedBox(
                                  width: 200, height: 150,
                                  child: Stack(children: [
                                    Positioned.fill(child: HtmlElementView(viewType: 'msg-img-${m['imageUrl']}')),
                                    Positioned.fill(child: Container(color: Colors.transparent)),
                                  ]))
                              : Image.network(m['imageUrl'].toString(), width: 200, height: 150, fit: BoxFit.cover),
                        ),
                      if (text.isNotEmpty)
                        Text(text,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: isMe ? Colors.white : AppTheme.textPrimary,
                                height: 1.4)),
                      const SizedBox(height: 3),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(time,
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: isMe ? Colors.white.withOpacity(0.7) : AppTheme.textHint)),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.done_all_rounded,
                            size: 13,
                            // Bleu si lu, blanc sinon
                            color: read ? Colors.lightBlueAccent : Colors.white.withOpacity(0.7),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
            decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
          ),
        ),
        title: Row(children: [
          UserAvatar(user: widget.user, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.user.fullName,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis),
              Row(children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(tr('msg_online'), style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.success)),
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
            icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
            onPressed: () => _showChatOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
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
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.home_outlined, size: 16, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Concernant le bien', style: GoogleFonts.poppins(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
                    Text(widget.propertyTitre!, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ),

          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessageBubble(i, _messages[i]),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => _attachImage(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.attach_file_rounded, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6) ?? AppTheme.textHint, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: tr('msg_hint'),
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6) ?? AppTheme.textHint),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: AppTheme.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}