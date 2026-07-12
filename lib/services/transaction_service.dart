// ═══════════════════════════════════════════════════════════════════
// TRANSACTION SERVICE — VelQix
// Gestion des transactions achat/location
// ═══════════════════════════════════════════════════════════════════

import '../models/models.dart';
import 'api_service.dart';
import 'auth_service.dart';

class TransactionService {
  TransactionService._();
  static final TransactionService instance = TransactionService._();

  final _api = ApiService.instance;

  // ─── Parser JSON → TransactionModel ──────────────────────────────
  TransactionModel _fromJson(Map<String, dynamic> json) {
    final propJson   = json['property'] as Map<String, dynamic>? ?? {};
    final clientJson = json['client']   as Map<String, dynamic>? ?? {};
    final propOwner  = propJson['proprietaire'] as Map<String, dynamic>? ?? {};

    final property = PropertyModel(
      id:          propJson['id'] ?? '',
      titre:       propJson['titre'] ?? '',
      description: propJson['description'] ?? '',
      prix:        (propJson['prix'] ?? 0).toDouble(),
      images:      propJson['images'] != null
          ? List<String>.from(propJson['images'])
          : (propJson['imageUrl'] != null ? [propJson['imageUrl'] as String] : []),
      type:        propJson['type'] == 'mobilier'
          ? PropertyType.mobilier : PropertyType.immobilier,
      listingType: propJson['listingType'] == 'location'
          ? ListingType.location
          : propJson['listingType'] == 'les_deux'
              ? ListingType.les_deux : ListingType.vente,
      categorie:   PropertyCategory.autre,
      adresse: AddressModel(
        rue:   propJson['adresse'] ?? '',
        ville: propJson['ville']   ?? '',
        pays:  propJson['pays']    ?? 'TG',
      ),
      proprietaire: UserModel(
        id:         propOwner['id']      ?? '',
        nom:        propOwner['nom']     ?? '',
        prenom:     propOwner['prenom']  ?? '',
        email:      propOwner['email']   ?? '',
        telephone:  propOwner['telephone'],
        avatarUrl:  propOwner['avatarUrl'],
        isVerified: propOwner['isVerified'] ?? false,
        isPremium:  propOwner['isPremium']  ?? false,
        rating:     (propOwner['rating']   ?? 0.0).toDouble(),
        totalAvis:  propOwner['totalAvis'] ?? 0,
        createdAt:  DateTime.now(),
      ),
      createdAt: DateTime.now(),
      status: propJson['status'] ?? 'approuve',
    );

    final client = UserModel(
      id:         clientJson['id']      ?? '',
      nom:        clientJson['nom']     ?? '',
      prenom:     clientJson['prenom']  ?? '',
      email:      clientJson['email']   ?? '',
      telephone:  clientJson['telephone'],
      avatarUrl:  clientJson['avatarUrl'],
      isVerified: clientJson['isVerified'] ?? false,
      isPremium:  clientJson['isPremium']  ?? false,
      rating: 0, totalAvis: 0, createdAt: DateTime.now(),
    );

    return TransactionModel(
      id:         json['id'] ?? '',
      property:   property,
      client:     client,
      type:       json['type'] ?? 'achat',
      montant:    (json['montant'] ?? 0).toDouble(),
      statut:     json['status'] ?? 'en_attente',
      dateDebut:  json['dateDebut'] != null
          ? DateTime.tryParse(json['dateDebut']) ?? DateTime.now()
          : DateTime.now(),
      dateFin:    json['dateFin'] != null
          ? DateTime.tryParse(json['dateFin'])
          : null,
      methode:    json['moyenPaiement'] ?? 'mobile_money',
      paymentRef: json['paymentRef'],
      createdAt:  json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // ─── GET — Mes transactions ───────────────────────────────────────
  Future<List<TransactionModel>> getTransactions() async {
    final res = await _api.get('/transactions', auth: true);
    if (res['success'] != true) return [];
    final list = res['data'] as List<dynamic>;
    return list.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── GET — Une transaction ────────────────────────────────────────
  Future<TransactionModel?> getTransaction(String id) async {
    final res = await _api.get('/transactions/$id', auth: true);
    if (res['success'] != true || res['data'] == null) return null;
    return _fromJson(res['data'] as Map<String, dynamic>);
  }

  // ─── POST — Créer une transaction (après paiement réussi) ────────
  Future<({TransactionModel? transaction, String? error})> createTransaction({
    required String propertyId,
    required double montant,
    required String type,             // 'achat' | 'location'
    required String moyenPaiement,    // 'mobile_money' | 'carte' | 'especes'
    DateTime? dateDebut,
    DateTime? dateFin,
    String? paymentRef,
  }) async {
    final res = await _api.post('/transactions', {
      'propertyId':    propertyId,
      'montant':       montant,
      'type':          type,
      'moyenPaiement': moyenPaiement,
      if (dateDebut != null) 'dateDebut': dateDebut.toIso8601String(),
      if (dateFin   != null) 'dateFin':   dateFin.toIso8601String(),
      if (paymentRef != null) 'paymentRef': paymentRef,
    }, auth: true);

    if (res['success'] != true) {
      return (
        transaction: null,
        error: (res['message'] ?? 'Erreur création') as String,
      );
    }
    return (
      transaction: _fromJson(res['data'] as Map<String, dynamic>),
      error: null,
    );
  }

  // ─── PUT — Changer le statut ──────────────────────────────────────
  Future<String?> updateStatus(String id, String status) async {
    final res = await _api.put(
      '/transactions/$id/status',
      {'status': status},
      auth: true,
    );
    if (res['success'] != true) return res['message'] ?? 'Erreur';
    return null;
  }

  // ─── Annuler une transaction ──────────────────────────────────────
  Future<String?> cancel(String id) => updateStatus(id, 'annule');
}