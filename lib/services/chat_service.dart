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
import 'web_file_picker.dart';

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

// Appel entrant (audio/vidéo) — écouté globalement par main_shell.dart, peu
// importe l'écran affiché au moment où l'appel arrive. Contenu : payload
// "call:incoming" du backend (callId, callerId, type, channelName, caller).
final incomingCallNotifier = ValueNotifier<Map<String, dynamic>?>(null);

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
  // Émis pour call:accepted / call:rejected / call:ended — chaque event a
  // la forme {event: 'accepted'|'rejected'|'ended', callId, channelName?}
  final _callStatusController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<MessageModel>         get onMessage    => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping     => _typingController.stream;
  Stream<String>               get onReadAck    => _readAckController.stream;
  Stream<Map<String, dynamic>> get onCallStatus => _callStatusController.stream;

  bool get isConnected => _isConnected;

  // ─── Connexion Socket.io ──────────────────────────────────────────
  Future<void> connect({String? userId}) async {
    // Socket déjà créé (connecté ou en cours de connexion) pour ce même
    // utilisateur : ne pas en ouvrir un second.
    if (_socket != null && _currentUserId == userId) return;
    if (_socket != null) disconnect();
    _currentUserId = userId;

    final token = await ApiService.instance.getValidToken();
    if (token == null) return;

    _socket = IO.io(
      ApiService.wsUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableForceNew()
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
    _socket!.onConnectError((e) async {
      _isConnected = false;
      debugPrint('❌ ChatSocket erreur connexion : $e');
      // L'access token (15 min) a expiré entre-temps : on le rafraîchit et
      // on met à jour l'auth du handshake pour les reconnexions suivantes.
      if (e.toString().contains('TOKEN_EXPIRED')) {
        final socket = _socket;
        if (await ApiService.instance.refreshAccessToken() && socket != null && identical(socket, _socket)) {
          socket.auth = {'token': await ApiService.instance.getToken()};
          socket.connect();
        }
      }
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
        _markOutgoingAsRead(readBy);
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

    // ── call:incoming ────────────────────────────────────────────────
    // Payload backend : { callId, callerId, type, channelName, caller }
    _socket!.on('call:incoming', (data) {
      if (data is! Map) return;
      incomingCallNotifier.value = Map<String, dynamic>.from(data);
    });

    // ── call:accepted / call:rejected / call:ended ────────────────────
    _socket!.on('call:accepted', (data) {
      if (data is! Map) return;
      _callStatusController.add({'event': 'accepted', ...Map<String, dynamic>.from(data)});
    });
    _socket!.on('call:rejected', (data) {
      if (data is! Map) return;
      _callStatusController.add({'event': 'rejected', ...Map<String, dynamic>.from(data)});
    });
    _socket!.on('call:ended', (data) {
      if (data is! Map) return;
      _callStatusController.add({'event': 'ended', ...Map<String, dynamic>.from(data)});
    });
  }

  // ─── Signaling d'appel (audio/vidéo) ──────────────────────────────
  // Invite quelqu'un à un appel et attend la confirmation serveur avant de
  // rejoindre le canal Agora — le channelName vient toujours du backend
  // (jamais généré localement), pour être sûr que les deux côtés utilisent
  // exactement la même valeur.
  Future<Map<String, dynamic>?> inviteCall({
    required String calleeId,
    required String type, // 'audio' | 'video'
  }) async {
    if (_socket == null || !_isConnected) return null;
    final completer = Completer<Map<String, dynamic>?>();
    _socket!.emitWithAck(
      'call:invite',
      {'calleeId': calleeId, 'type': type},
      ack: (response) {
        if (completer.isCompleted) return;
        if (response is Map && response['success'] == true) {
          completer.complete(Map<String, dynamic>.from(response['data']));
        } else {
          completer.complete(null);
        }
      },
    );
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () => null);
  }

  Future<bool> acceptCall(String callId) async {
    if (_socket == null || !_isConnected) return false;
    final completer = Completer<bool>();
    _socket!.emitWithAck(
      'call:accept',
      {'callId': callId},
      ack: (response) {
        if (completer.isCompleted) return;
        completer.complete(response is Map && response['success'] == true);
      },
    );
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
  }

  void rejectCall(String callId, {String? reason}) {
    _socket?.emit('call:reject', {'callId': callId, if (reason != null) 'reason': reason});
  }

  void endCallSignal(String callId) {
    _socket?.emit('call:end', {'callId': callId});
  }

  /// App ID + token Agora délivrés par le backend pour ce canal
  /// (GET /api/calls/agora-token). En cas d'échec ou si le serveur n'a pas
  /// d'App ID configuré, on garde [fallbackAppId] et un token vide.
  Future<({String appId, String token})> agoraCredentials(
      String channelName, String fallbackAppId) async {
    final res = await ApiService.instance.get(
      '/calls/agora-token?channelName=${Uri.encodeQueryComponent(channelName)}',
      auth: true,
    );
    final data = res['success'] == true ? res['data'] : null;
    if (data is Map) {
      final appId = (data['appId'] as String?) ?? '';
      final token = (data['token'] as String?) ?? '';
      if (appId.isNotEmpty) return (appId: appId, token: token);
    }
    return (appId: fallbackAppId, token: '');
  }

  // ─── Charger les conversations ────────────────────────────────────
  // GET /api/conversations → { success, data: [...] }
  Future<void> loadConversations() async {
    try {
      final res = await ApiService.instance.get('/conversations', auth: true);
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
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
  // Toujours rechargé depuis le serveur : le cache local ne contient que les
  // messages reçus/envoyés pendant la session. En cas d'échec, on renvoie
  // le cache.
  Future<List<MessageModel>> loadMessages(String otherUserId) async {
    try {
      final res = await ApiService.instance.get('/conversations/$otherUserId', auth: true);
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .map((j) => _msgFromPayload(j as Map<String, dynamic>))
            .toList();
        // Conserver les messages locaux pas encore confirmés par le serveur
        final pending = (messagesNotifier.value[otherUserId] ?? [])
            .where((m) => m.id.startsWith('temp_'));
        final merged = [...list, ...pending];
        final current = Map<String, List<MessageModel>>.from(messagesNotifier.value);
        current[otherUserId] = merged;
        messagesNotifier.value = current;
        return merged;
      }
    } catch (e) {
      debugPrint('❌ loadMessages: $e');
    }
    return messagesNotifier.value[otherUserId] ?? [];
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
      final res = await ApiService.instance.post(
        '/messages',
        {'receiverId': receiverId, 'text': text},
        auth: true,
      );

      if (res['success'] == true && res['data'] is Map) {
        final confirmed = _msgFromPayload(Map<String, dynamic>.from(res['data']));
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
      final token = await ApiService.instance.getValidToken();
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

  // ─── Envoi d'une pièce jointe image ────────────────────────────────
  // [dataUri] vient de WebFilePicker : data URI sur le web, chemin de fichier
  // local sur mobile (WebFilePicker.readBytes gère les deux cas).
  Future<MessageModel?> sendImageMessage({
    required String receiverId,
    required String dataUri,
  }) async {
    final tempId  = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = MessageModel(
      id: tempId, senderId: _currentUserId ?? '',
      receiverId: receiverId, content: '📷 Photo',
      sentAt: DateTime.now(), status: MessageStatus.sending,
      type: MessageType.image,
      imageUrl: dataUri, // aperçu local immédiat, remplacé après upload
    );
    _addToCache(tempMsg);
    _bumpConversation(
      otherUserId: receiverId, lastMessage: '📷 Photo',
      lastMessageAt: tempMsg.sentAt, incrementUnread: false,
    );

    try {
      final bytes = await WebFilePicker.readBytes(dataUri);
      if (bytes == null) throw Exception('image illisible');
      final subtype = WebFilePicker.imageSubtype(dataUri);

      final token = await ApiService.instance.getValidToken();
      final request = http.MultipartRequest(
        'POST', Uri.parse('${ApiService.baseUrl}/messages/image'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['receiverId'] = receiverId
        ..files.add(http.MultipartFile.fromBytes(
          'image', bytes,
          filename: 'photo.$subtype',
          contentType: MediaType('image', subtype),
        ));

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 201) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final confirmed = _msgFromPayload(body['data'] as Map<String, dynamic>);
        _replaceInCache(receiverId, tempId, confirmed);
        return confirmed;
      }
    } catch (e) {
      debugPrint('❌ sendImageMessage: $e');
    }
    _markFailed(receiverId, tempId);
    return null;
  }
  void markAsRead(String senderId) {
    _socket?.emit('message:read', {'senderId': senderId});
    _clearUnread(senderId);
  }

  // ─── Typing ───────────────────────────────────────────────────────
  void sendTyping(String receiverId, {bool isTyping = true}) {
    _socket?.emit('message:typing', {'receiverId': receiverId, 'isTyping': isTyping});
  }

  // ─── Convertir le payload backend → MessageModel ─────────────────
  // Socket : { id, senderId, receiverId, type, text, audioUrl, audioDuration,
  // imageUrl, isRead, timestamp }. Routes HTTP : message Prisma brut, avec
  // createdAt au lieu de timestamp.
  MessageModel _msgFromPayload(Map<String, dynamic> p) {
    final rawDate = p['timestamp'] ?? p['createdAt'] ?? p['sentAt'];
    return MessageModel(
      id:         p['id']         as String? ?? '',
      senderId:   p['senderId']   as String? ?? '',
      receiverId: p['receiverId'] as String? ?? '',
      content:    p['text']       as String? ?? p['content'] as String? ?? '',
      sentAt:     rawDate != null
          ? DateTime.tryParse(rawDate.toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      status: (p['isRead'] == true) ? MessageStatus.read : MessageStatus.sent,
      type: p['type'] == 'audio'
          ? MessageType.audio
          : p['type'] == 'image'
              ? MessageType.image
              : MessageType.text,
      isRead: p['isRead'] as bool? ?? false,
      audioUrl: p['audioUrl'] as String?,
      audioDuration: (p['audioDuration'] as num?)?.toInt(),
      imageUrl: p['imageUrl'] as String?,
    );
  }

  // ─── Accusé de lecture : mes messages envoyés à [readBy] sont lus ──
  void _markOutgoingAsRead(String readBy) {
    final list = messagesNotifier.value[readBy];
    if (list == null || list.isEmpty) return;
    final current = Map<String, List<MessageModel>>.from(messagesNotifier.value);
    current[readBy] = list
        .map((m) => m.senderId == _currentUserId && m.status != MessageStatus.read
                && m.status != MessageStatus.sending && m.status != MessageStatus.failed
            ? m.copyWith(status: MessageStatus.read)
            : m)
        .toList();
    messagesNotifier.value = current;
  }

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
    if (idx == -1) {
      // Nouveau correspondant : la liste serveur contient déjà ce message
      loadConversations();
      return;
    }
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
    _currentUserId = null;
    // Ne pas laisser les conversations du compte précédent au suivant
    conversationsNotifier.value = [];
    messagesNotifier.value = {};
    incomingCallNotifier.value = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _readAckController.close();
    _callStatusController.close();
  }
}