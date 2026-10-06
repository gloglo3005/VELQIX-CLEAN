import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'chat_service.dart';
import 'notification_service.dart';
import 'property_service.dart';

/// ===============================================================
/// PUSH NOTIFICATION SERVICE
/// ===============================================================

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance =
      PushNotificationService._();

  final ApiService _api =
      ApiService.instance;

  bool _initialized = false;

  FirebaseMessaging? _messaging;

  /// =============================================================
  /// INITIALIZE
  /// =============================================================

  Future<void> initialize() async {
    /// FCM natif uniquement pour le moment.
    ///
    /// Sur Flutter Web, les notifications temps réel doivent
    /// principalement passer par Socket.IO.
    if (kIsWeb) {
      debugPrint(
        'FCM disabled on Web. Socket.IO is used for realtime events.',
      );
      return;
    }

    if (_initialized) {
      return;
    }

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint(
        'Firebase initialization: $e',
      );
    }

    try {
      _messaging =
          FirebaseMessaging.instance;

      /// Permission
      await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      /// Token
      final token =
          await _messaging!.getToken();

      if (token != null &&
          token.isNotEmpty) {
        await _saveToken(token);
      }

      /// Token refresh
      _messaging!.onTokenRefresh.listen(
        (token) async {
          if (token.isNotEmpty) {
            await _saveToken(token);
          }
        },
        onError: (error) {
          debugPrint(
            'FCM token refresh error: $error',
          );
        },
      );

      /// Foreground
      FirebaseMessaging.onMessage.listen(
        _onForegroundMessage,
      );

      /// Opened from background
      FirebaseMessaging.onMessageOpenedApp.listen(
        _onOpenedMessage,
      );

      /// Opened from terminated state
      final initialMessage =
          await _messaging!.getInitialMessage();

      if (initialMessage != null) {
        await _onOpenedMessage(
          initialMessage,
        );
      }

      _initialized = true;

      debugPrint(
        'Push notification service initialized.',
      );
    } catch (e) {
      debugPrint(
        'Push notification initialization failed: $e',
      );
    }
  }

  /// =============================================================
  /// SAVE TOKEN
  /// =============================================================

  Future<void> _saveToken(
    String token,
  ) async {
    try {
      // ✅ CORRIGÉ : données en 2e argument positionnel + auth: true
      await _api.put(
        '/push/token',
        {
          'token': token,
          'platform': defaultTargetPlatform.name,
        },
        auth: true,
      );

      debugPrint(
        'FCM token registered successfully.',
      );
    } catch (e) {
      debugPrint(
        'Unable to register FCM token: $e',
      );
    }
  }

  /// =============================================================
  /// FOREGROUND MESSAGE
  /// =============================================================

  Future<void> _onForegroundMessage(
    RemoteMessage message,
  ) async {
    debugPrint(
      'FCM foreground message: ${message.data}',
    );

    final data =
        Map<String, dynamic>.from(
      message.data,
    );

    final type =
        data['type']?.toString();

    /// -----------------------------------------------------------
    /// INCOMING CALL
    /// -----------------------------------------------------------

    if (type == 'incoming_call') {
      await _handleCallMessage(data);
      return;
    }

    /// -----------------------------------------------------------
    /// NORMAL NOTIFICATION
    /// -----------------------------------------------------------

    final notification =
        message.notification;

    final title =
        notification?.title ??
        data['title']?.toString() ??
        'VELQIX';

    final body =
        notification?.body ??
        data['message']?.toString() ??
        data['body']?.toString() ??
        '';

    final id =
        data['notificationId']?.toString() ??
        data['id']?.toString() ??
        'push_${DateTime.now().millisecondsSinceEpoch}';

    final model =
        NotificationModel(
      id: id,
      title: title,
      message: body,
      type: type ?? 'general',
      isRead: false,
      createdAt: DateTime.now(),
      data: data,
    );

    await NotificationService.instance
        .addFromPush(model);
  }

  /// =============================================================
  /// OPENED MESSAGE
  /// =============================================================

  Future<void> _onOpenedMessage(
    RemoteMessage message,
  ) async {
    final data =
        Map<String, dynamic>.from(
      message.data,
    );

    debugPrint(
      'FCM notification opened: $data',
    );

    final type =
        data['type']?.toString();

    if (type == 'incoming_call') {
      await _handleCallMessage(data);
    }
  }

  /// =============================================================
  /// HANDLE CALL
  /// =============================================================

  Future<void> _handleCallMessage(
    Map<String, dynamic> data,
  ) async {
    final type =
        data['type']?.toString();

    if (type != 'incoming_call') {
      return;
    }

    final callId =
        data['callId']?.toString();

    final callerId =
        data['callerId']?.toString();

    final channelName =
        data['channelName']?.toString();

    final callType =
        data['callType']?.toString() ??
        'audio';

    if (callId == null ||
        callerId == null ||
        channelName == null) {
      debugPrint(
        'Invalid incoming call payload: $data',
      );
      return;
    }

    /// -----------------------------------------------------------
    /// BASE CALL DATA
    /// -----------------------------------------------------------
    ///
    /// IMPORTANT :
    /// On affiche l'appel même si le profil de l'appelant
    /// n'arrive pas à être récupéré.
    final callData =
        <String, dynamic>{
      'type': 'incoming_call',
      'callId': callId,
      'callerId': callerId,
      'channelName': channelName,
      'callType': callType,
    };

    incomingCallNotifier.value =
        callData;

    /// -----------------------------------------------------------
    /// OPTIONAL CALLER PROFILE
    /// -----------------------------------------------------------

    try {
      final caller =
          await PropertyService.instance
              .fetchUserProfile(
        callerId,
      );

      if (caller != null) {
        incomingCallNotifier.value = {
          ...callData,
          'caller': caller,
        };
      }
    } catch (e) {
      debugPrint(
        'Unable to load caller profile: $e',
      );

      /// On garde l'appel actif.
    }
  }
}
