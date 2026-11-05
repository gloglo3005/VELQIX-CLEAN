import 'dart:convert';

import 'package:flutter/material.dart';

import '../main.dart' show navigatorKey;
import '../screens/availability_requests_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/my_services_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/owner_profile_screen.dart';
import '../screens/premium_screen.dart';
import '../screens/shared_property_screen.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'property_service.dart';

/// ===============================================================
/// NOTIFICATION ROUTER
/// ===============================================================
/// Quand on touche une notification (système, locale, bannière ou ligne
/// de la liste), on est emmené directement vers ce qu'elle annonce :
///
///   message          → la conversation avec l'expéditeur
///   follow           → le profil de la personne qui vous suit
///   annonce / signalement → la fiche du bien
///   disponibilite    → la demande de disponibilité (sinon la fiche du bien)
///   mission          → l'espace missions selon le rôle
///   premium          → l'écran Premium
class NotificationRouter {
  NotificationRouter._();

  static final NotificationRouter instance = NotificationRouter._();

  /// Texte stocké dans la notification locale (payload).
  static String encodePayload(NotificationModel n) {
    try {
      return jsonEncode(<String, dynamic>{
        'id': n.id,
        'type': n.type,
        'data': n.data ?? <String, dynamic>{},
      });
    } catch (_) {
      return n.id;
    }
  }

  /// Touche sur une notification locale.
  Future<void> openFromPayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;

    // Les appels entrants ont leur propre écran.
    if (payload.startsWith('call:')) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final rawData = decoded['data'];
        await open(
          type: decoded['type']?.toString() ?? 'general',
          data: rawData is Map
              ? Map<String, dynamic>.from(rawData)
              : <String, dynamic>{},
          notificationId: decoded['id']?.toString(),
        );
        return;
      }
    } catch (_) {
      // Ancien format : le payload est simplement l'id de la notification.
    }

    final found =
        notificationsNotifier.value.where((n) => n.id == payload).toList();
    if (found.isNotEmpty) {
      await openFromNotification(found.first, markRead: true, wait: true);
    } else {
      await open(type: 'general', notificationId: payload);
    }
  }

  /// Touche sur une ligne de la liste ou sur la bannière dans l'app.
  Future<void> openFromNotification(
    NotificationModel n, {
    bool markRead = false,
    bool wait = false,
  }) {
    return open(
      type: n.type,
      data: n.data ?? <String, dynamic>{},
      notificationId: n.id,
      markRead: markRead,
      wait: wait,
      // Depuis la liste on y est déjà : pas de retour à la liste.
      fallbackToList: wait,
    );
  }

  Future<void> open({
    required String type,
    Map<String, dynamic> data = const <String, dynamic>{},
    String? notificationId,
    bool markRead = true,
    bool wait = true,
    bool fallbackToList = true,
  }) async {
    if (type == 'incoming_call') return;

    // Au démarrage à froid, laisse l'app finir de s'afficher.
    if (wait) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    final nav = await _waitNavigator();
    if (nav == null) return;
    if (!AuthService.instance.isLoggedIn) return;

    if (markRead &&
        notificationId != null &&
        notificationId.isNotEmpty &&
        !notificationId.startsWith('push_')) {
      NotificationService.instance.markOneRead(notificationId);
    }

    try {
      final handled = await _route(nav, type, data);
      if (!handled && fallbackToList && nav.mounted) {
        _push(nav, const NotificationsScreen());
      }
    } catch (e) {
      debugPrint('NotificationRouter error: $e');
    }
  }

  Future<NavigatorState?> _waitNavigator() async {
    for (var i = 0; i < 50; i++) {
      final nav = navigatorKey.currentState;
      if (nav != null && nav.mounted) return nav;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return null;
  }

  void _push(NavigatorState nav, Widget screen) {
    if (!nav.mounted) return;
    nav.push(MaterialPageRoute(builder: (_) => screen));
  }

  /// Retourne true si la notification a un écran de destination.
  Future<bool> _route(
    NavigatorState nav,
    String type,
    Map<String, dynamic> data,
  ) async {
    String val(String key) => (data[key] ?? '').toString().trim();

    final role = AuthService.instance.currentUserOrEmpty.role;

    switch (type) {
      case 'message':
        final senderId = val('senderId');
        if (senderId.isEmpty) {
          // Ancienne notification sans expéditeur : liste des conversations.
          _push(nav, const MessagesScreen());
          return true;
        }
        final sender = await PropertyService.instance
            .fetchUserProfile(senderId, auth: true);
        if (sender == null) {
          _push(nav, const MessagesScreen());
        } else {
          _push(nav, ChatScreen(user: sender, otherUserId: senderId));
        }
        return true;

      case 'follow':
        final followerId = val('followerId');
        if (followerId.isEmpty) return false;
        final follower = await PropertyService.instance
            .fetchUserProfile(followerId, auth: true);
        if (follower == null) return false;
        _push(nav, OwnerProfileScreen(owner: follower));
        return true;

      case 'annonce':
      case 'signalement':
        final propertyId = val('propertyId');
        if (propertyId.isEmpty) return false;
        _push(nav, SharedPropertyScreen(propertyId: propertyId));
        return true;

      case 'disponibilite':
        if (val('requestId').isNotEmpty) {
          _push(nav, const AvailabilityRequestsScreen());
          return true;
        }
        final propId = val('propertyId');
        if (propId.isEmpty) return false;
        _push(nav, SharedPropertyScreen(propertyId: propId));
        return true;

      case 'mission':
        if (role == 'admin' ||
            role == 'demarcheur' ||
            role == 'agent_entretien') {
          // Leur espace de travail est l'écran racine de l'app.
          nav.popUntil((route) => route.isFirst);
        } else {
          _push(nav, const MyServicesScreen());
        }
        return true;

      case 'premium':
        _push(nav, const PremiumScreen());
        return true;

      default:
        return false;
    }
  }
}