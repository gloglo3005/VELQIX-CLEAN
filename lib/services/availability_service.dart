// lib/services/availability_service.dart
// Disponibilité des annonces, demandes de confirmation / de visite et
// signalements (cahier des charges §6.3, §7, VIS-01, VIS-02, SIG-01).
//
// Principes (§7.1) :
//  • une annonce publiée n'est jamais assimilée à un bien disponible ;
//  • le silence d'un annonceur n'est JAMAIS présenté comme une confirmation ;
//  • toutes les règles sont appliquées par le SERVEUR (voir BACKEND_CHANGES.md).

import 'api_service.dart';

String _msg(Map<String, dynamic> res, String fallback) =>
    (res['message'] ?? fallback).toString();

/// Type de demande (§6.3).
class AvailabilityRequestType {
  static const confirmation = 'confirmation'; // « Demander une confirmation »
  static const visit = 'visit';               // « Organiser une visite »
}

/// Statut d'une demande.
class AvailabilityRequestStatus {
  static const pending = 'pending';           // en attente (≠ confirmé)
  static const available = 'available';      // l'annonceur confirme
  static const unavailable = 'unavailable';   // loué / vendu / indisponible
  static const slotProposed = 'slot_proposed';// autre créneau proposé
  static const expired = 'expired';           // aucune réponse dans le délai
  static const cancelled = 'cancelled';
}

/// Réponses possibles de l'annonceur.
class AvailabilityResponse {
  static const available = 'available';
  static const unavailable = 'unavailable';
  static const proposeSlot = 'propose_slot';
}

/// Motifs de signalement d'une annonce (§7.5).
class ReportReason {
  final String code;
  final String label;
  const ReportReason(this.code, this.label);

  static const all = <ReportReason>[
    ReportReason('already_rented', 'Déjà louée ou vendue'),
    ReportReason('not_found', 'Inexistante ou introuvable'),
    ReportReason('misleading', 'Trompeuse'),
    ReportReason('wrong_price', 'Prix incorrect'),
    ReportReason('suspicious_advertiser', 'Annonceur suspect'),
    ReportReason('wrong_info_or_images', 'Informations ou images inexactes'),
  ];
}

/// Statuts qu'un annonceur peut déclarer lui-même (§5.3, §7.3).
class DeclaredAvailability {
  static const available = 'available';     // « Le bien est toujours disponible »
  static const rented = 'rented';           // « Le bien est loué »
  static const sold = 'sold';               // « Le bien est vendu »
  static const unavailable = 'unavailable'; // temporairement indisponible
}

class AvailabilityRequest {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String type;
  final String status;
  final String requesterName;
  final String? ownerName;
  final String? note;
  final DateTime? desiredSlot;
  final DateTime? proposedSlot;
  final String? responseNote;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const AvailabilityRequest({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.type,
    required this.status,
    required this.requesterName,
    this.ownerName,
    this.note,
    this.desiredSlot,
    this.proposedSlot,
    this.responseNote,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isVisit => type == AvailabilityRequestType.visit;
  bool get isPending => status == AvailabilityRequestStatus.pending;

  factory AvailabilityRequest.fromJson(Map<String, dynamic> j) {
    DateTime? d(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
    final prop = j['property'] is Map ? Map<String, dynamic>.from(j['property'] as Map) : const <String, dynamic>{};
    final req = j['requester'] is Map ? Map<String, dynamic>.from(j['requester'] as Map) : const <String, dynamic>{};
    final own = j['owner'] is Map ? Map<String, dynamic>.from(j['owner'] as Map) : const <String, dynamic>{};
    String name(Map<String, dynamic> m, String fallback) {
      final n = '${m['prenom'] ?? ''} ${m['nom'] ?? ''}'.trim();
      return n.isEmpty ? fallback : n;
    }
    return AvailabilityRequest(
      id: (j['id'] ?? '').toString(),
      propertyId: (j['propertyId'] ?? prop['id'] ?? '').toString(),
      propertyTitle: (j['propertyTitle'] ?? prop['titre'] ?? 'Annonce').toString(),
      type: (j['type'] ?? AvailabilityRequestType.confirmation).toString(),
      status: (j['status'] ?? AvailabilityRequestStatus.pending).toString(),
      requesterName: (j['requesterName'] ?? name(req, 'Un utilisateur')).toString(),
      ownerName: (j['ownerName'] ?? (own.isEmpty ? null : name(own, ''))) as String?,
      note: j['note']?.toString(),
      desiredSlot: d(j['desiredSlot']),
      proposedSlot: d(j['proposedSlot']),
      responseNote: j['responseNote']?.toString(),
      createdAt: d(j['createdAt']) ?? DateTime.now(),
      respondedAt: d(j['respondedAt']),
    );
  }
}

/// Une ligne de l'historique de disponibilité d'une annonce (ANN-06).
/// Le serveur ne la modifie ni ne l'efface jamais.
class AvailabilityEventItem {
  final String id;
  final String action;
  final String resultStatus;
  final String channel; // app | system | admin
  final String? actorName;
  final String? note;
  final DateTime? createdAt;

  const AvailabilityEventItem({
    required this.id,
    required this.action,
    required this.resultStatus,
    required this.channel,
    required this.actorName,
    required this.note,
    required this.createdAt,
  });

  factory AvailabilityEventItem.fromJson(Map<String, dynamic> j) {
    String? sn(dynamic v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    return AvailabilityEventItem(
      id: (j['id'] ?? '').toString(),
      action: (j['action'] ?? '').toString(),
      resultStatus: (j['resultStatus'] ?? '').toString(),
      channel: (j['channel'] ?? '').toString(),
      actorName: sn(j['actorName']),
      note: sn(j['note']),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
    );
  }

  static String actionLabel(String a) {
    switch (a) {
      case 'declared_available':   return 'Bien confirmé disponible';
      case 'declared_rented':      return 'Bien déclaré loué';
      case 'declared_sold':        return 'Bien déclaré vendu';
      case 'declared_unavailable': return 'Bien déclaré indisponible';
      case 'confirmed_via_request':   return 'Disponibilité confirmée suite à une demande';
      case 'unavailable_via_request': return 'Indisponibilité déclarée suite à une demande';
      case 'suspended_by_admin':   return 'Annonce suspendue par l\'équipe';
      case 'restored_by_admin':    return 'Annonce rétablie par l\'équipe';
      case 'suspended_by_reports': return 'Annonce suspendue après signalements';
      default:                     return a;
    }
  }

  static String statusLabel(String s) {
    switch (s) {
      case 'available':   return 'Disponible';
      case 'pending':     return 'À reconfirmer';
      case 'unavailable': return 'Indisponible';
      case 'rented':      return 'Loué';
      case 'sold':        return 'Vendu';
      case 'suspended':   return 'Suspendue';
      case 'archived':    return 'Archivée';
      default:            return s;
    }
  }

  static String channelLabel(String c) {
    switch (c) {
      case 'app':    return 'Application';
      case 'admin':  return 'Équipe VelQix';
      case 'system': return 'Automatique';
      default:       return c;
    }
  }
}

class AvailabilityService {
  AvailabilityService._();
  static final AvailabilityService instance = AvailabilityService._();
  final _api = ApiService.instance;

  /// Propriétaire (ou admin) : historique daté des confirmations et changements
  /// de statut d'une annonce, du plus récent au plus ancien (ANN-06).
  /// Lance une Exception avec un message lisible en cas d'échec.
  Future<List<AvailabilityEventItem>> getHistory(String propertyId) async {
    final res = await _api.get('/properties/$propertyId/availability-history', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, "Impossible de charger l'historique."));
    final data = res['data'];
    if (data is! List) return <AvailabilityEventItem>[];
    return data
        .whereType<Map>()
        .map((m) => AvailabilityEventItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  List<AvailabilityRequest> _parse(dynamic data) => data is List
      ? data.whereType<Map<String, dynamic>>().map(AvailabilityRequest.fromJson).toList()
      : <AvailabilityRequest>[];

  /// Demandeur : « Demander une confirmation » / « Organiser une visite ».
  /// Retourne null si OK, sinon un message d'erreur.
  Future<String?> createRequest(
    String propertyId, {
    required String type,
    DateTime? desiredSlot,
    String? note,
  }) async {
    final res = await _api.post('/properties/$propertyId/availability-requests', {
      'type': type,
      if (desiredSlot != null) 'desiredSlot': desiredSlot.toUtc().toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }, auth: true);
    return res['success'] == true ? null : _msg(res, "Impossible d'envoyer la demande.");
  }

  /// Demandes envoyées par l'utilisateur connecté.
  Future<List<AvailabilityRequest>> getMine() async {
    final res = await _api.get('/availability-requests/mine', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Impossible de charger vos demandes.'));
    return _parse(res['data']);
  }

  /// Demandes reçues par l'annonceur (sur ses annonces).
  Future<List<AvailabilityRequest>> getReceived() async {
    final res = await _api.get('/availability-requests/received', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Impossible de charger les demandes reçues.'));
    return _parse(res['data']);
  }

  /// Annonceur : confirmer, déclarer indisponible ou proposer un autre créneau.
  Future<String?> respond(
    String requestId, {
    required String response,
    DateTime? proposedSlot,
    String? note,
  }) async {
    final res = await _api.put('/availability-requests/$requestId/respond', {
      'response': response,
      if (proposedSlot != null) 'proposedSlot': proposedSlot.toUtc().toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }, auth: true);
    return res['success'] == true ? null : _msg(res, 'Réponse impossible.');
  }

  /// Annonceur : « Le bien est toujours disponible » / « loué » / « vendu ».
  /// Le serveur enregistre la date de confirmation et l'événement d'historique.
  Future<String?> declare(String propertyId, String status) async {
    final res = await _api.post('/properties/$propertyId/availability',
        {'status': status}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Mise à jour impossible.');
  }

  /// Signaler une annonce (§7.5). Un signalement isolé n'entraîne pas de
  /// sanction automatique : l'administration l'examine (SIG-02).
  Future<String?> report(String propertyId, String reasonCode, {String? details}) async {
    final res = await _api.post('/properties/$propertyId/reports', {
      'reason': reasonCode,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    }, auth: true);
    return res['success'] == true ? null : _msg(res, "Impossible d'envoyer le signalement.");
  }
}
