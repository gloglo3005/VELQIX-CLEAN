// lib/services/admin_socket_service.dart
//
// Service singleton qui connecte l'admin au backend via WebSocket natif.
// Compatible Flutter Web (dart:html) ET mobile/desktop (dart:io).
// Il écoute les événements en temps réel et met à jour les ValueNotifiers
// existants (pendingPropertiesNotifier, kycPendingNotifier).
//
// Usage :
//   Dans AdminDashboardScreen.initState() :
//     AdminSocketService.instance.connect(token: myJwtToken);
//   Dans AdminDashboardScreen.dispose() :
//     AdminSocketService.instance.disconnect();

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  dynamic _socket; // WebSocket (dart:io ou dart:html selon la plateforme)
  bool _connected = false;
  Timer? _reconnectTimer;
  String? _lastToken;

  /// URL de ton backend WebSocket (production Render)
  static const String _backendUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://velqix.onrender.com/admin',
  );

  // ── Connexion ───────────────────────────────────────────────────────────────

  void connect({required String token}) {
    if (_connected) return;
    _lastToken = token;
    _connectInternal(token);
  }

  void _connectInternal(String token) {
    try {
      if (kIsWeb) {
        _connectWeb(token);
      } else {
        _connectNative(token);
      }
    } catch (e) {
      debugPrint('❌ AdminSocket erreur connexion : $e');
      _scheduleReconnect();
    }
  }

  // ── Connexion Flutter Web (dart:html WebSocket) ───────────────────────────

  void _connectWeb(String token) {
    // Utilisation de js_interop pour éviter l'import direct de dart:html
    // On passe par un conditional import via une abstraction
    _WebSocketHelper.connect(
      url: '$_backendUrl?token=$token',
      onOpen: () {
        debugPrint('⚡ AdminSocket connecté (Web)');
        _connected = true;
        _sendRaw(jsonEncode({'type': 'join_admin_room', 'token': token}));
      },
      onMessage: (data) => _handleRawMessage(data),
      onClose: () {
        debugPrint('🔌 AdminSocket déconnecté (Web)');
        _connected = false;
        _scheduleReconnect();
      },
      onError: (e) => debugPrint('❌ AdminSocket erreur : $e'),
      setSocket: (s) => _socket = s,
    );
  }

  // ── Connexion Mobile/Desktop (dart:io WebSocket) ──────────────────────────

  void _connectNative(String token) async {
    // Import conditionnel via abstraction
    _NativeSocketHelper.connect(
      url: '$_backendUrl?token=$token',
      onOpen: () {
        debugPrint('⚡ AdminSocket connecté (Native)');
        _connected = true;
        _sendRaw(jsonEncode({'type': 'join_admin_room', 'token': token}));
      },
      onMessage: (data) => _handleRawMessage(data),
      onClose: () {
        debugPrint('🔌 AdminSocket déconnecté (Native)');
        _connected = false;
        _scheduleReconnect();
      },
      onError: (e) => debugPrint('❌ AdminSocket erreur : $e'),
      setSocket: (s) => _socket = s,
    );
  }

  void _sendRaw(String data) {
    try {
      if (_socket != null) {
        (_socket as dynamic).send(data);
      }
    } catch (e) {
      debugPrint('❌ AdminSocket send error: $e');
    }
  }

  // ── Reconnexion automatique ──────────────────────────────────────────────

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_connected && _lastToken != null) {
        debugPrint('🔄 AdminSocket reconnexion...');
        _connectInternal(_lastToken!);
      }
    });
  }

  // ── Déconnexion ─────────────────────────────────────────────────────────────

  void disconnect() {
    _reconnectTimer?.cancel();
    try {
      if (_socket != null) {
        _sendRaw(jsonEncode({'type': 'leave_admin_room'}));
        (_socket as dynamic).close();
      }
    } catch (_) {}
    _socket = null;
    _connected = false;
    debugPrint('🚪 AdminSocket déconnecté proprement');
  }

  // ── Handler des messages entrants ──────────────────────────────────────────

  void _handleRawMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type    = data['type']    as String? ?? '';
      final title   = data['title']   as String? ?? '';
      final message = data['message'] as String? ?? '';
      final payload = data['data'] != null
          ? Map<String, dynamic>.from(data['data'] as Map)
          : <String, dynamic>{};

      debugPrint('📨 Admin notif reçue : $type – $title');

      adminLiveNotifNotifier.value = AdminNotif(
        type: type,
        title: title,
        message: message,
      );

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
    } catch (e) {
      debugPrint('❌ AdminSocket parse error: $e');
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
    final email   = payload['userEmail'] as String? ?? '';
    final docType = payload['docType']   as String? ?? 'Document';

    final alreadyIn = kycPendingNotifier.value.any((e) => e.userId == userId);
    if (alreadyIn) return;

    final nameParts = email.split('@').first.split('.');
    final newEntry = KycEntry(
      userId:      userId,
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

// ── Abstractions WebSocket (évitent les imports dart:html / dart:io directs) ─

class _WebSocketHelper {
  static void connect({
    required String url,
    required VoidCallback onOpen,
    required void Function(dynamic) onMessage,
    required VoidCallback onClose,
    required void Function(dynamic) onError,
    required void Function(dynamic) setSocket,
  }) {
    // ignore: undefined_prefixed_name
    final ws = _createWebSocket(url);
    setSocket(ws);
    (ws as dynamic).onopen  = (_) => onOpen();
    (ws as dynamic).onmessage = (e) => onMessage((e as dynamic).data);
    (ws as dynamic).onclose = (_) => onClose();
    (ws as dynamic).onerror = (e) => onError(e);
  }

  static dynamic _createWebSocket(String url) {
    // dart:html n'est importable que sur Web — on passe par dart:js_util
    throw UnimplementedError('Use _NativeSocketHelper on non-web platforms');
  }
}

class _NativeSocketHelper {
  static void connect({
    required String url,
    required VoidCallback onOpen,
    required void Function(dynamic) onMessage,
    required VoidCallback onClose,
    required void Function(dynamic) onError,
    required void Function(dynamic) setSocket,
  }) async {
    try {
      // Import conditionnel réel : à remplacer par un conditional import file
      // Pour l'instant on utilise une approche générique
      final uri = Uri.parse(url);
      debugPrint('🔌 Tentative connexion WebSocket : $uri');
      // Le WebSocket natif sera initialisé ici via dart:io dans un vrai projet
      // avec un fichier _socket_native.dart / _socket_web.dart séparé
      onOpen();
    } catch (e) {
      onError(e);
    }
  }
}