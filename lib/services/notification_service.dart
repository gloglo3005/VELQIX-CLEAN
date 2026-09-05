// ═══════════════════════════════════════════════════════════════════
// NOTIFICATION SERVICE — VelQix
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'api_service.dart';

class NotificationModel {
  final String   id;
  final String   titre;
  final String   corps;
  final bool     isRead;
  final String   type;
  final dynamic  data;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.titre,
    required this.corps,
    required this.isRead,
    required this.type,
    this.data,
    required this.createdAt,
  });

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id: id, titre: titre, corps: corps,
    isRead: isRead ?? this.isRead,
    type: type, data: data, createdAt: createdAt,
  );

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id:        json['id'] ?? '',
        titre:     json['titre'] ?? '',
        corps:     json['corps'] ?? '',
        isRead:    json['isRead'] ?? false,
        type:      json['type'] ?? 'system',
        data:      json['data'],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
      );
}

// ── Notifiers globaux — écoutés par la cloche (main_shell) et l'écran ────────
// de notifications, mis à jour en temps réel via l'event socket
// "notification:new" (voir chat_service.dart).
final notificationsNotifier    = ValueNotifier<List<NotificationModel>>([]);
final unreadNotifCountNotifier = ValueNotifier<int>(0);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _api = ApiService.instance;

  // ─── Charger depuis GET /api/notifications et alimenter les notifiers ────
  Future<void> loadNotifications() async {
    final res = await _api.get('/notifications', auth: true);
    if (res['success'] != true) return;

    final list = (res['data'] as List<dynamic>)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();

    notificationsNotifier.value = list;
    unreadNotifCountNotifier.value = (res['unreadCount'] as int?) ?? 0;
  }

  Future<void> markOneRead(String id) async {
    final list = List<NotificationModel>.from(notificationsNotifier.value);
    final idx  = list.indexWhere((n) => n.id == id);
    if (idx != -1 && !list[idx].isRead) {
      list[idx] = list[idx].copyWith(isRead: true);
      notificationsNotifier.value = list;
      unreadNotifCountNotifier.value =
          (unreadNotifCountNotifier.value - 1).clamp(0, 1 << 30);
    }
    try {
      await _api.put('/notifications/$id/read', {}, auth: true);
    } catch (_) {
      // best-effort — l'utilisateur peut tirer pour rafraîchir si besoin
    }
  }

  Future<void> markAllRead() async {
    notificationsNotifier.value = notificationsNotifier.value
        .map((n) => n.copyWith(isRead: true))
        .toList();
    unreadNotifCountNotifier.value = 0;
    try {
      await _api.put('/notifications/read-all', {}, auth: true);
    } catch (_) {}
  }

  /// Retire une notif localement (pas d'endpoint delete côté backend —
  /// on masque juste, après l'avoir marquée lue).
  void dismiss(String id) {
    notificationsNotifier.value =
        notificationsNotifier.value.where((n) => n.id != id).toList();
  }

  /// Appelé par ChatService à la réception de l'event socket
  /// "notification:new" pour insérer la nouvelle notif en tête de liste.
  void addFromSocket(NotificationModel notif) {
    notificationsNotifier.value = [notif, ...notificationsNotifier.value];
    unreadNotifCountNotifier.value++;
  }
}