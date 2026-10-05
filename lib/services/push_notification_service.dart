
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'chat_service.dart';
import 'property_service.dart';
import 'notification_service.dart';

/// Push FCM : notifications lorsque VelQix est en arrière-plan ou fermé.
///
/// Socket.io reste la source temps réel lorsque l'application est ouverte.
/// FCM constitue le filet de sécurité lorsque le socket n'est plus actif.
///
/// IMPORTANT :
/// - Sur Web, l'initialisation FCM est volontairement ignorée ici tant que
///   la configuration Firebase Web n'est pas fournie.
/// - Sur Android/iOS, Firebase doit être correctement configuré.
class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    // La configuration Firebase Web n'est pas encore installée.
    if (kIsWeb) {
      debugPrint(
        'ℹ️ FCM Web ignoré : configuration Firebase Web non fournie.',
      );
      return;
    }

    try {
      await Firebase.initializeApp();

      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();

      if (token != null && token.isNotEmpty) {
        await _saveToken(token);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen(
        _saveToken,
      );

      FirebaseMessaging.onMessage.listen(
        _onForegroundMessage,
      );

      FirebaseMessaging.onMessageOpenedApp.listen(
        _onOpenedMessage,
      );

      final initial =
          await FirebaseMessaging.instance.getInitialMessage();

      if (initial != null) {
        await _handleCallMessage(
          initial.data,
        );
      }

      _initialized = true;

      debugPrint(
        '🔔 FCM VelQix initialisé',
      );
    } catch (e, st) {
      // FCM reste optionnel.
      // Socket.io continue à fonctionner même si Firebase échoue.
      debugPrint(
        '⚠️ FCM non initialisé : $e\n$st',
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  // ENREGISTREMENT DU TOKEN
  // ────────────────────────────────────────────────────────────────

  Future<void> _saveToken(String token) async {
    if (token.isEmpty) {
      return;
    }

    try {
      await ApiService.instance.put(
        '/push/token',
        {
          'token': token,
        },
        auth: true,
      );

      debugPrint(
        '✅ Token FCM enregistré côté backend',
      );
    } catch (e) {
      debugPrint(
        '⚠️ Impossible d’enregistrer le token FCM: $e',
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  // MESSAGE FCM EN PREMIER PLAN
  // ────────────────────────────────────────────────────────────────

  Future<void> _onForegroundMessage(
    RemoteMessage message,
  ) async {
    final data = message.data;

    // Cas particulier : appel entrant.
    if (data['type'] == 'incoming_call') {
      await _handleCallMessage(data);
      return;
    }

    final title =
        message.notification?.title ??
        data['title']?.toString() ??
        'VelQix';

    final body =
        message.notification?.body ??
        data['body']?.toString() ??
        '';

    final notification = NotificationModel(
      id: 'push_${DateTime.now().microsecondsSinceEpoch}',
      titre: title,
      corps: body,
      isRead: false,
      type: data['type']?.toString() ?? 'system',
      data: data,
      createdAt: DateTime.now(),
    );

    // Permet à MainShell d'afficher immédiatement la notification.
    latestNotificationNotifier.value = notification;
  }

  // ────────────────────────────────────────────────────────────────
  // UTILISATEUR OUVRE UNE NOTIFICATION
  // ────────────────────────────────────────────────────────────────

  Future<void> _onOpenedMessage(
    RemoteMessage message,
  ) async {
    await _handleCallMessage(
      message.data,
    );
  }

  // ────────────────────────────────────────────────────────────────
  // APPEL ENTRANT
  // ────────────────────────────────────────────────────────────────

  Future<void> _handleCallMessage(
    Map<String, dynamic> data,
  ) async {
    if (data['type'] != 'incoming_call') {
      return;
    }

    final callId = data['callId']?.toString();
    final callerId = data['callerId']?.toString();
    final channelName = data['channelName']?.toString();

    if (callId == null ||
        callerId == null ||
        channelName == null) {
      debugPrint(
        '⚠️ Payload appel entrant incomplet.',
      );
      return;
    }

    try {
      final caller =
          await PropertyService.instance.fetchUserProfile(
        callerId,
        auth: true,
      );

      incomingCallNotifier.value = {
        'callId': callId,
        'callerId': callerId,
        'type': data['callType']?.toString() ?? 'audio',
        'channelName': channelName,
        if (caller != null)
          'caller': caller.toJson(),
      };
    } catch (e) {
      debugPrint(
        '⚠️ Impossible de préparer l’appel FCM: $e',
      );
    }
  }
}

/// Handler exécuté lorsqu'un message FCM arrive alors que
/// l'application est en arrière-plan.
///
/// Pour un payload FCM de type notification, Android/iOS affiche
/// automatiquement la notification système.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // Pour le moment, aucune UI n'est ouverte ici.
  //
  // Si nous devons plus tard traiter des données FCM silencieuses,
  // Firebase.initializeApp() devra être appelé ici avec la
  // configuration Firebase appropriée.
}
```
