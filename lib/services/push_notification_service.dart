import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'chat_service.dart';
import 'notification_service.dart';

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
      // L'app est ouverte et le socket est connecté : c'est le socket
      // qui affiche déjà l'écran d'appel. On évite un deuxième écran.
      if (ChatService.instance.isConnected) {
        return;
      }
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
        callId.isEmpty ||
        callerId == null ||
        channelName == null ||
        channelName.isEmpty) {
      debugPrint(
        'Invalid incoming call payload: $data',
      );
      return;
    }

    final avatar = data['avatarUrl']?.toString() ?? '';

    // Même format que l'événement socket "call:incoming" :
    // IncomingCallScreen lit 'type' ('audio' ou 'video') et 'caller' (Map).
    // Le nom et l'avatar viennent directement du push : pas besoin
    // de charger le profil de l'appelant.
    incomingCallNotifier.value = <String, dynamic>{
      'callId': callId,
      'callerId': callerId,
      'channelName': channelName,
      'type': callType,
      'caller': <String, dynamic>{
        'id': callerId,
        'nom': data['nom']?.toString() ?? '',
        'prenom': data['prenom']?.toString() ?? '',
        'avatarUrl': avatar.isEmpty ? null : avatar,
      },
    };
  }
}