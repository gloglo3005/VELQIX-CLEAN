// ═══════════════════════════════════════════════════════════════════
// NOTIFICATION SERVICE — VelQix
// ═══════════════════════════════════════════════════════════════════

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

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _api = ApiService.instance;

  Future<({List<NotificationModel> items, int unreadCount})>
      getNotifications() async {
    final res = await _api.get('/notifications', auth: true);
    if (res['success'] != true) {
      return (items: <NotificationModel>[], unreadCount: 0);
    }

    final list = (res['data'] as List<dynamic>)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return (items: list, unreadCount: (res['unreadCount'] as int?) ?? 0);
  }

  Future<void> markOneRead(String id) async {
    await _api.put('/notifications/$id/read', {}, auth: true);
  }

  Future<void> markAllRead() async {
    await _api.put('/notifications/read-all', {}, auth: true);
  }
}


