import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'chat_service.dart';
import 'property_service.dart';
import 'notification_service.dart';

/// Push FCM : notifications quand VelQix est en arrière-plan/fermé.
///
/// Socket.io reste la source temps réel quand l'app est ouverte. FCM est le
/// filet de sécurité pour les messages et appels quand le socket n'est plus
/// actif. La configuration native Firebase (google-services.json / plist)
/// reste obligatoire côté projet Flutter.
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return; // configuration web Firebase non fournie dans le zip lib

    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);

      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedMessage);

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        await _handleCallMessage(initial.data);
      }

      _initialized = true;
      debugPrint('🔔 FCM VelQix initialisé');
    } catch (e, st) {
      // Firebase est optionnel : Socket.io continue de fonctionner sans FCM.
      debugPrint('⚠️ FCM non initialisé : $e\n$st');
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      await ApiService.instance.put('/push/token', {'token': token}, auth: true);
    } catch (e) {
      debugPrint('⚠️ impossible d’enregistrer le token FCM: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      await _handleCallMessage(data);
      return;
    }

    // Le socket crée déjà la NotificationModel persistée. Ici on ne fait que
    // déclencher la bannière globale pour le cas où Socket.io est indisponible.
    final title = message.notification?.title ?? 'VelQix';
    final body = message.notification?.body ?? '';
    latestNotificationNotifier.value = NotificationModel(
      id: 'push_${DateTime.now().microsecondsSinceEpoch}',
      titre: title,
      corps: body,
      isRead: false,
      type: data['type'] ?? 'system',
      data: data,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _onOpenedMessage(RemoteMessage message) async {
    await _handleCallMessage(message.data);
  }

  Future<void> _handleCallMessage(Map<String, dynamic> data) async {
    if (data['type'] != 'incoming_call') return;
    final callId = data['callId']?.toString();
    final callerId = data['callerId']?.toString();
    final channelName = data['channelName']?.toString();
    if (callId == null || callerId == null || channelName == null) return;

    try {
      final caller = await PropertyService.instance.fetchUserProfile(callerId, auth: true);
      incomingCallNotifier.value = {
        'callId': callId,
        'callerId': callerId,
        'type': data['callType']?.toString() ?? 'audio',
        'channelName': channelName,
        if (caller != null) 'caller': caller.toJson(),
      };
    } catch (e) {
      debugPrint('⚠️ impossible de préparer l’appel FCM: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Avec un payload `notification`, Android/iOS affiche déjà la notification
  // système lorsque l'app est en arrière-plan. On évite ici d'ouvrir l'UI.
}
