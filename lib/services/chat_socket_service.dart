import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

// ── Notifiers globaux (écoutés par l'UI) ─────────────────────────────────────
final conversationsNotifier =
    ValueNotifier<List<ConversationModel>>([]);

final ValueNotifier<Map<String, List<MessageModel>>> messagesNotifier =
    ValueNotifier({});

// ── Événement "message reçu" (pour la conversation ouverte) ──────────────────
final ValueNotifier<MessageModel?> incomingMessageNotifier =
    ValueNotifier(null);

class ChatSocketService {
  ChatSocketService._();
  static final instance = ChatSocketService._();

  dynamic _socket;
  String? _currentUserId;

  void connect({required String token, required String userId}) {
    _currentUserId = userId;

    // ── Même pattern WebSocket natif que AdminSocketService ─────────────────
    // URL backend en production (Render)
    const wsUrl = String.fromEnvironment('WS_URL',
        defaultValue: 'wss://velqix.onrender.com');

    _initSocket(wsUrl, token);
  }

  void _initSocket(String url, String token) {
    // Utilise le même _WebSocketHelper que AdminSocketService
    // ou socket_io_client sur mobile
    _sendRaw(jsonEncode({'type': 'auth', 'token': token}));

    _onMessage((raw) {
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      switch (data['type']) {

        // 1️⃣ Nouveau message reçu
        case 'new_message':
          _handleNewMessage(data['payload']);
          break;

        // 2️⃣ Message lu par l'interlocuteur
        case 'message_read':
          _handleMessageRead(data['payload']);
          break;

        // 3️⃣ Nouvelle conversation créée
        case 'new_conversation':
          _handleNewConversation(data['payload']);
          break;

        // 4️⃣ L'autre utilisateur est en train d'écrire
        case 'typing':
          typingNotifier.value = data['payload']['conversationId'];
          Future.delayed(const Duration(seconds: 3),
              () => typingNotifier.value = null);
          break;
      }
    });
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  void _handleNewMessage(Map<String, dynamic> payload) {
    final message = MessageModel.fromJson(payload);
    final convId  = message.conversationId;

    // 1. Ajouter aux messages de la conversation
    final current = Map<String, List<MessageModel>>.from(messagesNotifier.value);
    current[convId] = [...(current[convId] ?? []), message];
    messagesNotifier.value = current;

    // 2. Notifier la conversation ouverte
    incomingMessageNotifier.value = message;

    // 3. Remonter la conversation en tête + incrémenter unread
    _bumpConversation(
      convId: convId,
      lastMessage: message.content,
      lastMessageAt: message.sentAt,
      // Incrémenter seulement si ce n'est pas MON message
      incrementUnread: message.senderId != _currentUserId,
    );
  }

  void _handleMessageRead(Map<String, dynamic> payload) {
    final convId = payload['conversationId'] as String;

    // Remettre unreadCount à 0 pour cette conversation
    final list = List<ConversationModel>.from(conversationsNotifier.value);
    final idx  = list.indexWhere((c) => c.id == convId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(unreadCount: 0);
      conversationsNotifier.value = list;
    }
  }

  void _handleNewConversation(Map<String, dynamic> payload) {
    final conv = ConversationModel.fromJson(payload);
    final already = conversationsNotifier.value.any((c) => c.id == conv.id);
    if (!already) {
      conversationsNotifier.value = [conv, ...conversationsNotifier.value];
    }
  }

  // ── Remonter une conversation en tête (comme WhatsApp) ───────────────────

  void _bumpConversation({
    required String convId,
    required String lastMessage,
    required DateTime lastMessageAt,
    required bool incrementUnread,
  }) {
    final list = List<ConversationModel>.from(conversationsNotifier.value);
    final idx  = list.indexWhere((c) => c.id == convId);

    ConversationModel updated;
    if (idx != -1) {
      final existing = list[idx];
      updated = existing.copyWith(
        lastMessage:   lastMessage,
        lastMessageAt: lastMessageAt,
        unreadCount: incrementUnread
            ? existing.unreadCount + 1
            : existing.unreadCount,
      );
      list.removeAt(idx);
    } else {
      return; // conversation inconnue, elle arrivera via new_conversation
    }

    conversationsNotifier.value = [updated, ...list];
  }

  // ── Émettre "en train d'écrire" ──────────────────────────────────────────

  void emitTyping(String conversationId) {
    _sendRaw(jsonEncode({
      'type': 'typing',
      'payload': {'conversationId': conversationId},
    }));
  }

  // ── Émettre "messages lus" ───────────────────────────────────────────────

  void emitRead(String conversationId) {
    _sendRaw(jsonEncode({
      'type': 'read',
      'payload': {'conversationId': conversationId},
    }));
  }

  void disconnect() {
    try { (_socket as dynamic).close(); } catch (_) {}
    _socket = null;
  }

  void _sendRaw(String data) {
    try { (_socket as dynamic).send(data); } catch (_) {}
  }

  void _onMessage(void Function(dynamic) handler) {
    // Brancher sur ton WebSocket helper existant
    (_socket as dynamic).onmessage = (e) => handler((e as dynamic).data);
  }
}

// Notifier pour "est en train d'écrire"
final ValueNotifier<String?> typingNotifier = ValueNotifier(null);