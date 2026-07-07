// lib/services/admin_socket_service.dart
//
// Service singleton qui connecte l'admin au backend via Socket.io.
// ⚠️ Réécriture : l'ancienne version utilisait un WebSocket natif brut
// (dart:io / dart:html), incompatible avec le protocole Socket.io utilisé
// par le backend (voir messageRoutes.ts / adminNotificationService.ts).
// On utilise ici le même package `socket_io_client` que chat_service.dart,
// et on écoute l'événement `admin_notification` diffusé à la room "admin_room"
// (que le backend fait désormais rejoindre automatiquement aux sockets admin).

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';
import '../widgets/widgets.dart' show pendingPropertiesNotifier, kycPendingNotifier, KycEntry;
import '../models/models.dart';

// ── Notification temps réel affichée dans l'UI (classe PUBLIQUE) ─────────────
class AdminNotif {
  final String type;
  final String title;
  final String message;
  final DateTime timestamp;
  AdminNotif({required this.type, required this.title, required this.message})
      : timestamp = DateTime.now();
}

// Notifier global exposé au dashboard
final adminLiveNotifNotifier = ValueNotifier<AdminNotif?>(null);

// ─────────────────────────────────────────────────────────────────────────────

class AdminSocketService {
  AdminSocketService._();
  static final instance = AdminSocketService._();

  IO.Socket? _socket;
  bool _connected = false;
  String? _lastToken;

  // ── Connexion ───────────────────────────────────────────────────────────────

  void connect({required String token}) {
    if (_connected && _socket != null) return;
    _lastToken = token;

    // Même serveur Socket.io que la messagerie (pas de namespace /admin séparé
    // côté backend : on se connecte à la racine et on rejoint "admin_room"
    // côté serveur en fonction du rôle décodé depuis le JWT).
    _socket = IO.io(
      ApiService.wsUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('⚡ AdminSocket connecté');
      _connected = true;
    });

    _socket!.on('admin_notification', (data) {
      if (data is Map) {
        _handleNotification(Map<String, dynamic>.from(data));
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 AdminSocket déconnecté');
      _connected = false;
    });

    _socket!.onConnectError((e) => debugPrint('❌ AdminSocket erreur connexion : $e'));
    _socket!.onError((e) => debugPrint('❌ AdminSocket erreur : $e'));

    _socket!.connect();
  }

  // ── Déconnexion ─────────────────────────────────────────────────────────────

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    debugPrint('🚪 AdminSocket déconnecté proprement');
  }

  bool get isConnected => _connected;

  // ── Handler des notifications entrantes ─────────────────────────────────────

  void _handleNotification(Map<String, dynamic> data) {
    final type    = data['type']    as String? ?? '';
    final title   = data['title']   as String? ?? '';
    final message = data['message'] as String? ?? '';
    final payload = data['data'] != null
        ? Map<String, dynamic>.from(data['data'] as Map)
        : <String, dynamic>{};

    debugPrint('📨 Admin notif reçue : $type – $title');

    adminLiveNotifNotifier.value = AdminNotif(type: type, title: title, message: message);

    switch (type) {
      case 'NEW_PROPERTY':
        _handleNewProperty(payload);
        break;
      case 'NEW_KYC':
        _handleNewKyc(payload);
        break;
      default:
        break;
    }
  }

  void _handleNewProperty(Map<String, dynamic> payload) {
    final propertyId   = payload['propertyId']   as String? ?? '';
    final titre        = payload['titre']         as String? ?? 'Nouvelle annonce';
    final proprietaire = payload['proprietaire']  as String? ?? '';

    final alreadyIn = pendingPropertiesNotifier.value
        .any((p) => (p as PropertyModel).id == propertyId);
    if (alreadyIn) return;

    final ownerParts = proprietaire.split(' ');
    final owner = UserModel(
      id:         'pending_$propertyId',
      nom:        ownerParts.length > 1 ? ownerParts.last  : proprietaire,
      prenom:     ownerParts.isNotEmpty ? ownerParts.first : '',
      email:      '',
      telephone:  '',
      avatarUrl:  null,
      isVerified: false,
      rating:     0,
      totalAvis:  0,
      createdAt:  DateTime.now(),
      role:       'client',
      isPremium:  false,
      countryCode: null,
      countryName: null,
    );

    final newProp = PropertyModel(
      id:              propertyId,
      titre:           titre,
      description:     '',
      prix:            0,
      type:            PropertyType.immobilier,
      listingType:     ListingType.vente,
      categorie:       PropertyCategory.appartement,
      adresse:         AddressModel(rue: '', ville: '', pays: 'TG'),
      images:          [],
      caracteristiques: [],
      isAvailable:     true,
      isFeatured:      false,
      status:          'en_attente',
      vues:            0,
      createdAt:       DateTime.now(),
      updatedAt:       DateTime.now(),
      proprietaire:    owner,
    );

    pendingPropertiesNotifier.value = [
      newProp,
      ...pendingPropertiesNotifier.value,
    ];
  }

  void _handleNewKyc(Map<String, dynamic> payload) {
    final userId  = payload['userId']    as String? ?? '';
    final docId   = payload['docId']     as String? ?? payload['kycId'] as String? ?? '';
    final email   = payload['userEmail'] as String? ?? '';
    final docType = payload['docType']   as String? ?? 'Document';

    final alreadyIn = kycPendingNotifier.value.any((e) => e.userId == userId);
    if (alreadyIn) return;

    final nameParts = email.split('@').first.split('.');
    final newEntry = KycEntry(
      userId:      userId,
      docId:       docId,
      nom:         nameParts.length > 1 ? nameParts.last  : email,
      prenom:      nameParts.isNotEmpty ? nameParts.first : email,
      docType:     docType,
      numDoc:      '—',
      soumisLabel: 'À l\'instant',
      soumisAt:    DateTime.now(),
    );

    kycPendingNotifier.value = [
      newEntry,
      ...kycPendingNotifier.value,
    ];
  }
}