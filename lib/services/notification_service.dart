import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

/// ===============================================================
/// NOTIFICATION MODEL
/// ===============================================================

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory NotificationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawDate = json['createdAt']?.toString();

    final rawData = json['data'];

    Map<String, dynamic>? parsedData;

    if (rawData is Map) {
      parsedData = Map<String, dynamic>.from(rawData);
    }

    return NotificationModel(
      id: json['id']?.toString() ??
          json['_id']?.toString() ??
          '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ??
          json['body']?.toString() ??
          '',
      type: json['type']?.toString() ?? 'general',
      isRead:
          json['isRead'] == true ||
          json['isRead'] == 1 ||
          json['isRead']?.toString().toLowerCase() ==
              'true',
      createdAt: rawDate != null
          ? DateTime.tryParse(rawDate) ??
              DateTime.now()
          : DateTime.now(),
      data: parsedData,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }
}

/// ===============================================================
/// GLOBAL NOTIFIERS
/// ===============================================================

final notificationsNotifier =
    ValueNotifier<List<NotificationModel>>([]);

final unreadNotifCountNotifier =
    ValueNotifier<int>(0);

final latestNotificationNotifier =
    ValueNotifier<NotificationModel?>(null);

/// ===============================================================
/// SERVICE
/// ===============================================================

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final ApiService _api = ApiService.instance;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _localReady = false;

  /// =============================================================
  /// LOCAL NOTIFICATIONS INITIALIZATION
  /// =============================================================

  Future<void> initializeLocalNotifications() async {
    if (kIsWeb || _localReady) {
      return;
    }

    const androidSettings =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings =
        InitializationSettings(
      android: androidSettings,
    );

    await _local.initialize(
      initializationSettings,
    );

    final androidPlugin =
        _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'velqix_notifications',
        'VELQIX Notifications',
        description:
            'Notifications VELQIX',
        importance: Importance.high,
      ),
    );

    await androidPlugin?.requestNotificationsPermission();

    _localReady = true;
  }

  /// =============================================================
  /// SHOW LOCAL NOTIFICATION
  /// =============================================================

  Future<void> showLocalNotification(
    NotificationModel notification,
  ) async {
    if (kIsWeb) {
      return;
    }

    if (!_localReady) {
      await initializeLocalNotifications();
    }

    const androidDetails =
        AndroidNotificationDetails(
      'velqix_notifications',
      'VELQIX Notifications',
      channelDescription:
          'Notifications VELQIX',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const details =
        NotificationDetails(
      android: androidDetails,
    );

    await _local.show(
      notification.id.hashCode,
      notification.title,
      notification.message,
      details,
    );
  }

  /// =============================================================
  /// LOAD NOTIFICATIONS
  /// =============================================================

  Future<void> loadNotifications() async {
    try {
      final response =
          await _api.get('/notifications');

      final dynamic rawData =
          response['data'];

      List<dynamic> rawNotifications = [];

      int? serverUnreadCount;

      if (rawData is List) {
        rawNotifications = rawData;
      } else if (rawData is Map) {
        final nested =
            rawData['notifications'];

        if (nested is List) {
          rawNotifications = nested;
        }

        final unread =
            rawData['unreadCount'];

        if (unread is num) {
          serverUnreadCount = unread.toInt();
        }
      }

      final topLevelUnread =
          response['unreadCount'];

      if (topLevelUnread is num) {
        serverUnreadCount =
            topLevelUnread.toInt();
      }

      final notifications =
          rawNotifications
              .whereType<Map>()
              .map(
                (item) =>
                    NotificationModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();

      notificationsNotifier.value =
          notifications;

      unreadNotifCountNotifier.value =
          serverUnreadCount ??
              notifications
                  .where(
                    (notification) =>
                        !notification.isRead,
                  )
                  .length;
    } catch (e) {
      debugPrint(
        'Failed to load notifications: $e',
      );
    }
  }

  /// =============================================================
  /// ADD FROM SOCKET
  /// =============================================================

  Future<void> addFromSocket(
    NotificationModel notification,
  ) async {
    _insertNotification(notification);

    latestNotificationNotifier.value =
        notification;

    await showLocalNotification(
      notification,
    );
  }

  /// =============================================================
  /// ADD FROM PUSH
  /// =============================================================

  Future<void> addFromPush(
    NotificationModel notification,
  ) async {
    _insertNotification(notification);

    latestNotificationNotifier.value =
        notification;

    await showLocalNotification(
      notification,
    );
  }

  /// =============================================================
  /// INSERT / UPDATE
  /// =============================================================

  void _insertNotification(
    NotificationModel notification,
  ) {
    final current =
        List<NotificationModel>.from(
      notificationsNotifier.value,
    );

    final existingIndex =
        current.indexWhere(
      (item) => item.id == notification.id,
    );

    if (existingIndex >= 0) {
      current[existingIndex] =
          notification;
    } else {
      current.insert(
        0,
        notification,
      );
    }

    notificationsNotifier.value =
        current;

    unreadNotifCountNotifier.value =
        current
            .where(
              (item) => !item.isRead,
            )
            .length;
  }

  /// =============================================================
  /// MARK ONE AS READ
  /// =============================================================

  Future<void> markOneRead(
    String notificationId,
  ) async {
    try {
      await _api.patch(
        '/notifications/$notificationId/read',
      );
    } catch (e) {
      debugPrint(
        'Failed to mark notification as read: $e',
      );
    }

    final updated =
        notificationsNotifier.value.map(
      (notification) {
        if (notification.id ==
            notificationId) {
          return notification.copyWith(
            isRead: true,
          );
        }

        return notification;
      },
    ).toList();

    notificationsNotifier.value =
        updated;

    unreadNotifCountNotifier.value =
        updated
            .where(
              (notification) =>
                  !notification.isRead,
            )
            .length;
  }

  /// =============================================================
  /// MARK ALL AS READ
  /// =============================================================

  Future<void> markAllRead() async {
    try {
      await _api.patch(
        '/notifications/read-all',
      );
    } catch (e) {
      debugPrint(
        'Failed to mark all notifications as read: $e',
      );
    }

    final updated =
        notificationsNotifier.value
            .map(
              (notification) =>
                  notification.copyWith(
                isRead: true,
              ),
            )
            .toList();

    notificationsNotifier.value =
        updated;

    unreadNotifCountNotifier.value = 0;
  }

  /// =============================================================
  /// DISMISS NOTIFICATION
  /// =============================================================

  Future<void> dismiss(
    String notificationId,
  ) async {
    try {
      await _api.delete(
        '/notifications/$notificationId',
      );
    } catch (e) {
      debugPrint(
        'Failed to dismiss notification: $e',
      );
    }

    final updated =
        notificationsNotifier.value
            .where(
              (notification) =>
                  notification.id !=
                  notificationId,
            )
            .toList();

    notificationsNotifier.value =
        updated;

    unreadNotifCountNotifier.value =
        updated
            .where(
              (notification) =>
                  !notification.isRead,
            )
            .length;
  }
}