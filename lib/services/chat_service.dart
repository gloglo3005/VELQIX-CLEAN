// ═══════════════════════════════════════════════════════════════════
// CHAT SERVICE — VelQix
// Socket.io temps réel + REST API
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/models.dart';
import 'api_service.dart';
import 'notification_service.dart';

// ═══════════════════════════════════════════════════════════════════
// MODÈLE CONVERSATION
// ═══════════════════════════════════════════════════════════════════

class Conversation {
  final String id;          // = otherUserId (clé unique de la conv)
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isOnline;

  Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  Conversation copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isOnline,
  }) => Conversation(
    id: id,
    otherUserId: otherUserId,
    otherUserName: otherUserName,
    otherUserAvatar: otherUserAvatar,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    unreadCount: unreadCount ?? this.unreadCount,
    isOnline: isOnline ?? this.isOnline,
  );

  /// Le backend retourne :
  /// { userId, user: {id,nom,prenom,avatarUrl}, isOnline,
  ///   lastMessage: {id,text,senderId,isRead,timestamp}, unreadCount }
  factory Conversation.fromJson(Map<String, dynamic> j) {
    final user        = j['user'] as Map<String, dynamic>? ?? {};
    final lastMsgMap  = j['lastMessage'] as Map<String, dynamic>? ?? {};
    final nom         = user['nom']    as String? ?? '';
    final prenom      = user['prenom'] as String? ?? '';
    final otherUserId = j['userId']    as String? ?? user['id'] as String? ?? '';

    return Conversation(
      id:             otherUserId,
      otherUserId:    otherUserId,
      otherUserName:  '$prenom $nom'.trim(),
      otherUserAvatar: user['avatarUrl'] as String?,
      lastMessage:    lastMsgMap['text'] as String? ?? '',
      lastMessageAt:  lastMsgMap['timestamp'] != null
          ? DateTime.tryParse(lastMsgMap['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      unreadCount:    j['unreadCount'] as int? ?? 0,
      isOnline:       j['isOnline']    as bool? ?? false,
    );
  }
}

// ── Notifiers globaux écoutés par l'UI ───────────────────────────────────────
final conversationsNotifier = ValueNotifier<List<Conversation>>([]);
final messagesNotifier      = ValueNotifier<Map<String, List<MessageModel>>>({});

// Émis à chaque follow/unfollow d'un profil — les écrans qui affichent ce
// profil (property_detail_screen, owner_profile_screen) comparent userId
// au profil affiché avant de mettre à jour leur compteur local.
final followersUpdateNotifier =
    ValueNotifier<({String userId, int followersCount})?>(null);

// Émis à chaque vue comptabilisée sur un bien — poussé uniquement au
// propriétaire du bien (voir propertyController.ts), donc si ce notifier
// se déclenche c'est forcément pour l'utilisateur courant.
final propertyViewsUpdateNotifier =
    ValueNotifier<({String propertyId, int vues})?>(null);

// ═══════════════════════════════════════════════════════════════════
// CHAT SERVICE
// ═══════════════════════════════════════════════════════════════════

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;

  // Streams exposés aux screens
  final _messageController = StreamController<MessageModel>.broadcast();
  final _typingController  = StreamController<Map<String, dynamic>>.broadcast();
  final _readAckController = StreamController<String>.broadcast();

  Stream<MessageModel>         get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping  => _typingController.stream;
  Stream<String>               get onReadAck => _readAckController.stream;

  bool get isConnected => _isConnected;

  // ─── Connexion Socket.io ──────────────────────────────────────────
  Future<void> connect({String? userId}) async {
    if (_isConnected) return;
    _currentUserId = userId;

    final token = await ApiService.instance.getToken();
    if (token == null) return;

    _socket = IO.io(
      ApiService.wsUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('⚡ ChatSocket connecté');
    });
    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('🔌 ChatSocket déconnecté');
    });
    _socket!.onConnectError((e) {
      _isConnected = false;
      debugPrint('❌ ChatSocket erreur connexion : $e');
    });

    // ── Log debug — à retirer en production ──────────────────────
    _socket!.onAny((event, data) {
      debugPrint('🔌 Socket event : $event → $data');
    });

    // ── message:receive ──────────────────────────────────────────
    // Payload backend : { id, senderId, receiverId, text, isRead, timestamp, sender }
    _socket!.on('message:receive', (data) {
      if (data is! Map) return;
      final payload = Map<String, dynamic>.from(data);
      final msg = _msgFromPayload(payload);
      _messageController.add(msg);
      _addToCache(msg);
      _bumpConversation(
        otherUserId:     msg.senderId,
        lastMessage:     msg.content,
        lastMessageAt:   msg.sentAt,
        incrementUnread: msg.senderId != _currentUserId,
      );
    });

    // ── message:typing ────────────────────────────────────────────
    _socket!.on('message:typing', (data) {
      if (data is Map) _typingController.add(Map<String, dynamic>.from(data));
    });

    // ── message:read_ack ──────────────────────────────────────────
    _socket!.on('message:read_ack', (data) {
      if (data is Map && data['readBy'] != null) {
        final readBy = data['readBy'] as String;
        _readAckController.add(readBy);
        _clearUnread(readBy);
      }
    });

    // ── user:online ───────────────────────────────────────────────
    _socket!.on('user:online', (data) {
      if (data is! Map) return;
      final userId   = data['userId']   as String?;
      final isOnline = data['isOnline'] as bool? ?? false;
      if (userId == null) return;
      _updateOnlineStatus(userId, isOnline);
    });

    // ── notification:new ──────────────────────────────────────────
    // Backend envoie l'objet Notification Prisma tel quel (id, titre,
    // corps, type, isRead, createdAt, ...) — même format que GET /notifications.
    _socket!.on('notification:new', (data) {
      if (data is! Map) return;
      final notif = NotificationModel.fromJson(Map<String, dynamic>.from(data));
      NotificationService.instance.addFromSocket(notif);
    });

    // ── user:followers_updated ──────────────────────────────────────
    _socket!.on('user:followers_updated', (data) {
      if (data is! Map) return;
      final userId = data['userId'] as String?;
      final count  = data['followersCount'] as int?;
      if (userId == null || count == null) return;
      followersUpdateNotifier.value = (userId: userId, followersCount: count);
    });

    // ── property:views_updated ──────────────────────────────────────
    // Poussé uniquement au propriétaire du bien (voir propertyController.ts).
    _socket!.on('property:views_updated', (data) {
      if (data is! Map) return;
      final propertyId = data['propertyId'] as String?;
      final vues       = data['vues'] as int?;
      if (propertyId == null || vues == null) return;
      propertyViewsUpdateNotifier.value = (propertyId: propertyId, vues: vues);
    });
  }

  // ─── Charger les conversations ────────────────────────────────────
  // GET /api/conversations → { success, data: [...] }
  Future<void> loadConversations() async {
    try {
      final token = await ApiService.instance.getToken();
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/conversations'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = ((body['data'] ?? body) as List)
            .map((j) => Conversation.fromJson(j as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
        conversationsNotifier.value = list;
      }
    } catch (e) {
      debugPrint('❌ loadConversations: $e');
    }
  }

  // ─── Charger l'historique des messages ───────────────────────────
  // GET /api/conversations/:userId → { success, data: [...], pagination }
  Future<List<MessageModel>> loadMessages(String otherUserId) async {
    final cached = messagesNotifier.value[otherUserId];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final token = await ApiService.instance.getToken();
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/conversations/$otherUserId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = ((body['data'] ?? body) as List)
            .map((j) => _msgFromPayload(j as Map<String, dynamic>))
            .toList();
        final current = Map<String, List<MessageModel>>.from(messagesNotifier.value);
        current[otherUserId] = list;
        messagesNotifier.value = current;
        return list;
      }
    } catch (e) {
      debugPrint('❌ loadMessages: $e');
    }
    return [];
  }

  // ─── Envoi avec optimistic UI + fallback HTTP ─────────────────────
  // Si le socket est indisponible (ou ne répond pas), on retombe sur
  // POST /api/messages plutôt que d'abandonner silencieusement le message.
  Future<MessageModel?> sendMessage({
    required String receiverId,
    required String text,
  }) async {
    final tempId  = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = MessageModel(
      id: tempId, senderId: _currentUserId ?? '',
      receiverId: receiverId, content: text,
      sentAt: DateTime.now(), status: MessageStatus.sending,
    );
    _addToCache(tempMsg);
    _bumpConversation(
      otherUserId: receiverId, lastMessage: text,
      lastMessageAt: tempMsg.sentAt, incrementUnread: false,
    );

    if (_isConnected && _socket != null) {
      final completer = Completer<MessageModel?>();
      _socket!.emitWithAck(
        'message:send',
        {'receiverId': receiverId, 'text': text},
        ack: (response) {
          if (response is Map && response['success'] == true) {
            final confirmed = _msgFromPayload(
                Map<String, dynamic>.from(response['data']));
            _replaceInCache(receiverId, tempId, confirmed);
            completer.complete(confirmed);
          } else {
            completer.complete(null);
          }
        },
      );

      final viaSocket = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      if (viaSocket != null) return viaSocket;
      // Le socket a échoué ou n'a pas répondu à temps → on tente le fallback HTTP
      debugPrint('⚠️ message:send sans réponse, fallback HTTP…');
    }

    return _sendViaHttp(receiverId: receiverId, text: text, tempId: tempId);
  }

  // ─── Fallback HTTP : POST /api/messages ───────────────────────────
  Future<MessageModel?> _sendViaHttp({
    required String receiverId,
    required String text,
    required String tempId,
  }) async {
    try {
      final token = await ApiService.instance.getToken();
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'receiverId': receiverId, 'text': text}),
      );

      if (res.statusCode == 201) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final confirmed = _msgFromPayload(body['data'] as Map<String, dynamic>);
        _replaceInCache(receiverId, tempId, confirmed);
        return confirmed;
      }
    } catch (e) {
      debugPrint('❌ _sendViaHttp: $e');
    }
    _markFailed(receiverId, tempId);
    return null;
  }

  // ─── Envoi d'un message vocal ──────────────────────────────────────
  // Pas de socket ici : le fichier doit être uploadé (multipart) avant
  // que le message n'existe côté serveur. On affiche immédiatement une
  // bulle "sending" qui pointe vers le fichier local (lecture optimiste),
  // puis on la remplace par la version confirmée (URL Cloudinary) une
  // fois l'upload terminé.
  Future<MessageModel?> sendAudioMessage({
    required String receiverId,
    required String localFilePath,
    required int durationSeconds,
  }) async {
    final tempId  = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = MessageModel(
      id: tempId, senderId: _currentUserId ?? '',
      receiverId: receiverId, content: '🎤 Message vocal',
      sentAt: DateTime.now(), status: MessageStatus.sending,
      type: MessageType.audio,
      audioUrl: localFilePath, // fichier local, remplacé après upload
      audioDuration: durationSeconds,
    );
    _addToCache(tempMsg);
    _bumpConversation(
      otherUserId: receiverId, lastMessage: '🎤 Message vocal',
      lastMessageAt: tempMsg.sentAt, incrementUnread: false,
    );

    try {
      final token = await ApiService.instance.getToken();
      final request = http.MultipartRequest(
        'POST', Uri.parse('${ApiService.baseUrl}/messages/audio'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['receiverId'] = receiverId;

      if (kIsWeb) {
        // Sur le web, localFilePath est en réalité une blob URL (pas un
        // vrai chemin fichier) — on récupère ses octets via une requête
        // dessus, et son vrai type MIME via l'en-tête de la réponse (varie
        // selon le navigateur : webm sous Chrome, ogg sous Firefox, etc.).
        final blobRes = await http.get(Uri.parse(localFilePath));
        final mimeType = blobRes.headers['content-type'] ?? 'audio/webm';
        final subtype = mimeType.split('/').last.split(';').first;
        request.files.add(http.MultipartFile.fromBytes(
          'audio', blobRes.bodyBytes,
          filename: 'voice.$subtype',
          contentType: MediaType('audio', subtype),
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('audio', localFilePath));
      }

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 201) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final confirmed = _msgFromPayload(body['data'] as Map<String, dynamic>);
        _replaceInCache(receiverId, tempId, confirmed);
        return confirmed;
      }
    } catch (e) {
      debugPrint('❌ sendAudioMessage: $e');
    }
    _markFailed(receiverId, tempId);
    return null;
  }

  // ─── Marquer comme lu ─────────────────────────────────────────────
  void markAsRead(String senderId) {
    _socket?.emit('message:read', {'senderId': senderId});
    _clearUnread(senderId);
  }

  // ─── Typing ───────────────────────────────────────────────────────
  void sendTyping(String receiverId, {bool isTyping = true}) {
    _socket?.emit('message:typing', {'receiverId': receiverId, 'isTyping': isTyping});
  }

  // ─── Convertir le payload backend → MessageModel ─────────────────
  // Backend envoie : { id, senderId, receiverId, type, text, audioUrl,
  // audioDuration, isRead, timestamp }
  // MessageModel attend : content, sentAt
  MessageModel _msgFromPayload(Map<String, dynamic> p) => MessageModel(
    id:         p['id']         as String? ?? '',
    senderId:   p['senderId']   as String? ?? '',
    receiverId: p['receiverId'] as String? ?? '',
    content:    p['text']       as String? ?? p['content'] as String? ?? '',
    sentAt:     p['timestamp'] != null
        ? DateTime.tryParse(p['timestamp'].toString()) ?? DateTime.now()
        : p['sentAt'] != null
            ? DateTime.tryParse(p['sentAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
    status: MessageStatus.sent,
    type: p['type'] == 'audio' ? MessageType.audio : MessageType.text,
    audioUrl: p['audioUrl'] as String?,
    audioDuration: p['audioDuration'] as int?,
  );

  // ─── Mettre à jour le statut en ligne ────────────────────────────
  void _updateOnlineStatus(String userId, bool isOnline) {
    final list = List<Conversation>.from(conversationsNotifier.value);
    final idx  = list.indexWhere((c) => c.otherUserId == userId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isOnline: isOnline);
      conversationsNotifier.value = List.from(list);
    }
  }

  // ─── Bump conversation en tête ────────────────────────────────────
  void _bumpConversation({
    required String otherUserId,
    required String lastMessage,
    required DateTime lastMessageAt,
    required bool incrementUnread,
  }) {
    final list = List<Conversation>.from(conversationsNotifier.value);
    final idx  = list.indexWhere((c) => c.otherUserId == otherUserId);
    if (idx == -1) return;
    final updated = list[idx].copyWith(
      lastMessage:   lastMessage,
      lastMessageAt: lastMessageAt,
      unreadCount:   incrementUnread
          ? list[idx].unreadCount + 1
          : list[idx].unreadCount,
    );
    list..removeAt(idx)..insert(0, updated);
    conversationsNotifier.value = List.from(list);
  }

  void _clearUnread(String otherUserId) {
    final list = List<Conversation>.from(conversationsNotifier.value);
    final idx  = list.indexWhere((c) => c.otherUserId == otherUserId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(unreadCount: 0);
      conversationsNotifier.value = List.from(list);
    }
  }

  // ─── Helpers cache ────────────────────────────────────────────────
  void _addToCache(MessageModel msg) {
    final key = msg.senderId == _currentUserId ? msg.receiverId : msg.senderId;
    final current = Map<String, List<MessageModel>>.from(messagesNotifier.value);
    current[key] = [...(current[key] ?? []), msg];
    messagesNotifier.value = current;
  }

  void _replaceInCache(String otherUserId, String tempId, MessageModel confirmed) {
    final current = Map<String, List<MessageModel>>.from(messagesNotifier.value);
    final list    = List<MessageModel>.from(current[otherUserId] ?? []);
    final idx     = list.indexWhere((m) => m.id == tempId);
    if (idx != -1) list[idx] = confirmed;
    current[otherUserId] = list;
    messagesNotifier.value = current;
  }

  void _markFailed(String otherUserId, String tempId) {
    final current = Map<String, List<MessageModel>>.from(messagesNotifier.value);
    final list    = List<MessageModel>.from(current[otherUserId] ?? []);
    final idx     = list.indexWhere((m) => m.id == tempId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(status: MessageStatus.failed);
    }
    current[otherUserId] = list;
    messagesNotifier.value = current;
  }

  // ─── Déconnexion ──────────────────────────────────────────────────
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _readAckController.close();
  }
}