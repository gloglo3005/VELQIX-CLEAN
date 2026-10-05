
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

class NotificationModel {
  final String id;
  final String titre;
  final String corps;
  final bool isRead;
  final String type;
  final dynamic data;
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

  NotificationModel copyWith({
    bool? isRead,
  }) {
    return NotificationModel(
      id: id,
      titre: titre,
      corps: corps,
      isRead: isRead ?? this.isRead,
      type: type,
      data: data,
      createdAt: createdAt,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      titre: json['titre']?.toString() ?? '',
      corps: json['corps']?.toString() ?? '',
      isRead: json['isRead'] == true,
      type: json['type']?.toString() ?? 'system',
      data: json['data'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ??
              DateTime.now()
          : DateTime.now(),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// NOTIFIERS GLOBAUX
// ───────────────────────────────────────────────────────────────────
//
// notificationsNotifier
// → contient la liste des notifications.
//
// unreadNotifCountNotifier
// → contient le nombre de notifications non lues.
//
// latestNotificationNotifier
// → permet de prévenir immédiatement l'interface lorsqu'une nouvelle
//   notification arrive, notamment pour afficher une SnackBar.
//
// Ce dernier notifier était utilisé par main_shell.dart et
// push_notification_service.dart mais n'était pas déclaré.
// ───────────────────────────────────────────────────────────────────

final notificationsNotifier =
    ValueNotifier<List<NotificationModel>>([]);

final unreadNotifCountNotifier =
    ValueNotifier<int>(0);

final latestNotificationNotifier =
    ValueNotifier<NotificationModel?>(null);

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final ApiService _api = ApiService.instance;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _localReady = false;

  // ────────────────────────────────────────────────────────────────
  // NOTIFICATIONS LOCALES
  // ────────────────────────────────────────────────────────────────

  Future<void> initializeLocalNotifications() async {
    // Les notifications locales natives ne sont pas nécessaires sur Web.
    if (_localReady || kIsWeb) {
      return;
    }

    const android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(
      android: android,
    );

    await _local.initialize(settings);

    final androidImpl =
        _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.requestNotificationsPermission();

    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'velqix_messages',
        'Messages et appels',
        description:
            'Notifications VelQix de messages et appels',
        importance: Importance.high,
      ),
    );

    _localReady = true;
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    // Pas de notification locale native sur Web.
    if (kIsWeb) {
      return;
    }

    await initializeLocalNotifications();

    await _local.show(
      DateTime.now()
          .millisecondsSinceEpoch
          .remainder(2147483647),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'velqix_messages',
          'Messages et appels',
          channelDescription:
              'Notifications VelQix de messages et appels',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ────────────────────────────────────────────────────────────────
  // CHARGEMENT DES NOTIFICATIONS
  // ────────────────────────────────────────────────────────────────

  Future<void> loadNotifications() async {
    try {
      final res = await _api.get(
        '/notifications',
        auth: true,
      );

      if (res['success'] != true) {
        return;
      }

      final rawList = res['data'];

      if (rawList is! List) {
        return;
      }

      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map(NotificationModel.fromJson)
          .toList();

      notificationsNotifier.value = list;

      final unreadCount = res['unreadCount'];

      unreadNotifCountNotifier.value =
          unreadCount is int ? unreadCount : 0;
    } catch (e) {
      debugPrint(
        '⚠️ Impossible de charger les notifications: $e',
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  // MARQUER UNE NOTIFICATION COMME LUE
  // ────────────────────────────────────────────────────────────────

  Future<void> markOneRead(String id) async {
    final list =
        List<NotificationModel>.from(
      notificationsNotifier.value,
    );

    final idx = list.indexWhere(
      (notification) => notification.id == id,
    );

    if (idx != -1 && !list[idx].isRead) {
      list[idx] = list[idx].copyWith(
        isRead: true,
      );

      notificationsNotifier.value = list;

      unreadNotifCountNotifier.value =
          (unreadNotifCountNotifier.value - 1)
              .clamp(0, 1 << 30);
    }

    try {
      await _api.put(
        '/notifications/$id/read',
        {},
        auth: true,
      );
    } catch (e) {
      debugPrint(
        '⚠️ Impossible de marquer la notification comme lue: $e',
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  // MARQUER TOUTES LES NOTIFICATIONS COMME LUES
  // ────────────────────────────────────────────────────────────────

  Future<void> markAllRead() async {
    notificationsNotifier.value =
        notificationsNotifier.value
            .map(
              (notification) =>
                  notification.copyWith(isRead: true),
            )
            .toList();

    unreadNotifCountNotifier.value = 0;

    try {
      await _api.put(
        '/notifications/read-all',
        {},
        auth: true,
      );
    } catch (e) {
      debugPrint(
        '⚠️ Impossible de marquer toutes les notifications comme lues: $e',
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  // SUPPRESSION VISUELLE
  // ────────────────────────────────────────────────────────────────

  void dismiss(String id) {
    notificationsNotifier.value =
        notificationsNotifier.value
            .where(
              (notification) => notification.id != id,
            )
            .toList();
  }

  // ────────────────────────────────────────────────────────────────
  // NOUVELLE NOTIFICATION REÇUE VIA SOCKET.IO
  // ────────────────────────────────────────────────────────────────

  void addFromSocket(NotificationModel notif) {
    notificationsNotifier.value = [
      notif,
      ...notificationsNotifier.value,
    ];

    unreadNotifCountNotifier.value++;

    // Notifie immédiatement l'interface.
    latestNotificationNotifier.value = notif;

    // Notification native uniquement sur Android/iOS.
    showLocalNotification(
      title: notif.titre.isEmpty
          ? 'VelQix'
          : notif.titre,
      body: notif.corps,
      payload: 'notification:${notif.id}',
    );
  }
}
```
