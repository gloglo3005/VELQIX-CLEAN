// lib/services/mission_service.dart
// Missions terrain, tarifs des services, gains des agents et opérations admin.
// Toutes les règles (prix, droits, paiements) sont appliquées par le SERVEUR :
// l'app ne fait qu'afficher et envoyer les demandes. Voir BACKEND_CHANGES.md.

import 'package:flutter/foundation.dart';
import '../models/mission_model.dart';
import 'api_service.dart';

String _msg(Map<String, dynamic> res, String fallback) => (res['message'] ?? fallback).toString();

List<Map<String, dynamic>> _list(dynamic data) =>
    data is List ? data.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];

// ─── Tarifs publics des services ─────────────────────────────────────────────
class ServicePrice {
  final double? price;     // null = sur devis
  final double? agentPay;
  final double? transport;
  const ServicePrice({this.price, this.agentPay, this.transport});
  bool get onQuote => price == null;
}

class ServicePricing {
  final ServicePrice verification;
  final ServicePrice visite;
  final ServicePrice entretien;
  const ServicePricing({required this.verification, required this.visite, required this.entretien});

  /// Valeurs de lancement du cahier des charges (modifiables depuis l'admin).
  static const fallback = ServicePricing(
    // Mêmes valeurs que PRICING_DEFAULTS du backend (missionRules.ts) : plus d'écart 3500 / 5000.
    verification: ServicePrice(price: 5000, agentPay: 2500, transport: 500),
    visite: ServicePrice(),
    entretien: ServicePrice(),
  );

  ServicePrice of(String type) {
    switch (type) {
      case MissionType.verification: return verification;
      case MissionType.visite:       return visite;
      default:                       return entretien;
    }
  }

  static ServicePrice _p(dynamic j) {
    if (j is! Map) return const ServicePrice();
    double? n(dynamic v) => v is num ? v.toDouble() : null;
    return ServicePrice(price: n(j['price']), agentPay: n(j['agentPay']), transport: n(j['transport']));
  }

  factory ServicePricing.fromJson(Map<String, dynamic> j) => ServicePricing(
        verification: _p(j[MissionType.verification]),
        visite: _p(j[MissionType.visite]),
        entretien: _p(j[MissionType.entretien]),
      );
}

class AgentEarnings {
  final double pending; // missions en cours de validation
  final double due;     // validées, à payer
  final double paid;
  final List<Map<String, dynamic>> items;
  const AgentEarnings({this.pending = 0, this.due = 0, this.paid = 0, this.items = const []});
}

class AgentAvailability {
  final bool available;
  final String zones;
  final String hours;
  const AgentAvailability({this.available = true, this.zones = '', this.hours = ''});
}

enum AgentScope { available, mine, done }

class MissionService {
  MissionService._();
  static final MissionService instance = MissionService._();
  final _api = ApiService.instance;

  // ── Client ────────────────────────────────────────────────────────────────
  /// Tarifs publics ; avec [zone], le prix de la vérification dans cette zone.
  Future<ServicePricing> getPricing({String? zone}) async {
    try {
      final query = (zone == null || zone.trim().isEmpty) ? '' : '?zone=${Uri.encodeQueryComponent(zone.trim())}';
      final res = await _api.get('/pricing$query');
      if (res['success'] == true && res['data'] is Map) {
        return ServicePricing.fromJson(Map<String, dynamic>.from(res['data'] as Map));
      }
    } catch (e) {
      debugPrint('Pricing load error: $e');
    }
    return ServicePricing.fallback;
  }

  /// Crée une demande. Retourne la mission (avec son prix / devis) ou lève une erreur.
  Future<MissionModel> requestService({
    required String type,
    String? propertyId,
    String? address,
    String notes = '',
    Map<String, dynamic> details = const {},
  }) async {
    final res = await _api.post('/missions', {
      'type': type,
      if (propertyId != null) 'propertyId': propertyId,
      if (address != null && address.isNotEmpty) 'address': address,
      if (notes.isNotEmpty) 'notes': notes,
      if (details.isNotEmpty) 'details': details,
    }, auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Demande impossible.'));
    return MissionModel.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<List<MissionModel>> getMyRequests() async {
    final res = await _api.get('/missions/mine', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Impossible de charger vos demandes.'));
    return _list(res['data']).map(MissionModel.fromJson).toList();
  }

  /// Accepte le devis (si besoin) et ouvre le paiement hébergé. Retourne l'URL.
  Future<String> checkout(String missionId) async {
    final res = await _api.post('/missions/$missionId/checkout', {}, auth: true);
    final url = res['success'] == true && res['data'] is Map ? (res['data'] as Map)['checkoutUrl'] : null;
    if (url == null) throw Exception(_msg(res, 'Paiement indisponible.'));
    return url.toString();
  }

  Future<String?> cancel(String missionId) async {
    final res = await _api.post('/missions/$missionId/cancel', {}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Annulation impossible.');
  }

  /// Le client valide la prestation (déclenche la rémunération de l'agent).
  Future<String?> confirm(String missionId) async {
    final res = await _api.post('/missions/$missionId/confirm', {}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Validation impossible.');
  }

  Future<String?> dispute(String missionId, String reason) async {
    final res = await _api.post('/missions/$missionId/dispute', {'reason': reason}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Contestation impossible.');
  }

  // ── Démarcheur / agent d'entretien ────────────────────────────────────────
  Future<List<MissionModel>> getAgentMissions(AgentScope scope) async {
    final res = await _api.get('/agent/missions?scope=${scope.name}', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Impossible de charger les missions.'));
    return _list(res['data']).map(MissionModel.fromJson).toList();
  }

  Future<String?> accept(String missionId) async {
    final res = await _api.post('/agent/missions/$missionId/accept', {}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Mission indisponible.');
  }

  Future<String?> submitReport(
    String missionId, {
    required Map<String, bool> checklist,
    required List<String> evidence,
    String note = '',
  }) async {
    final res = await _api.post('/agent/missions/$missionId/report', {
      'checklist': checklist,
      'evidence': evidence,
      if (note.trim().isNotEmpty) 'note': note.trim(),
    }, auth: true);
    return res['success'] == true ? null : _msg(res, 'Envoi du rapport impossible.');
  }

  Future<AgentEarnings> getEarnings() async {
    final res = await _api.get('/agent/earnings', auth: true);
    if (res['success'] != true || res['data'] is! Map) {
      throw Exception(_msg(res, 'Impossible de charger vos gains.'));
    }
    final d = res['data'] as Map;
    double n(dynamic v) => v is num ? v.toDouble() : 0;
    return AgentEarnings(
      pending: n(d['pending']),
      due: n(d['due']),
      paid: n(d['paid']),
      items: _list(d['items']),
    );
  }

  Future<AgentAvailability> getAvailability() async {
    final res = await _api.get('/agent/availability', auth: true);
    if (res['success'] != true || res['data'] is! Map) return const AgentAvailability();
    final d = res['data'] as Map;
    return AgentAvailability(
      available: d['available'] != false,
      zones: (d['zones'] ?? '').toString(),
      hours: (d['hours'] ?? '').toString(),
    );
  }

  Future<String?> saveAvailability(AgentAvailability a) async {
    final res = await _api.put('/agent/availability',
        {'available': a.available, 'zones': a.zones, 'hours': a.hours}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Enregistrement impossible.');
  }
}

// ─── Opérations d'administration (missions, tarifs, finances, journal) ───────
class AdminOpsService {
  AdminOpsService._();
  static final AdminOpsService instance = AdminOpsService._();
  final _api = ApiService.instance;

  Future<List<MissionModel>> getMissions({String? status}) async {
    final q = status == null ? '' : '?status=$status';
    final res = await _api.get('/admin/missions$q', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Route /admin/missions indisponible.'));
    return _list(res['data']).map(MissionModel.fromJson).toList();
  }

  Future<String?> setQuote(String id, {required double price, required double agentPay, required double transport}) async {
    final res = await _api.put('/admin/missions/$id/quote',
        {'price': price, 'agentPay': agentPay, 'transport': transport}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Devis impossible.');
  }

  Future<String?> validateMission(String id) async {
    final res = await _api.post('/admin/missions/$id/validate', {}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Validation impossible.');
  }

  Future<String?> rejectMission(String id, String reason) async {
    final res = await _api.post('/admin/missions/$id/reject', {'reason': reason}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Refus impossible.');
  }

  Future<Map<String, dynamic>> getPricing() async {
    final res = await _api.get('/admin/pricing', auth: true);
    if (res['success'] != true || res['data'] is! Map) {
      throw Exception(_msg(res, 'Route /admin/pricing indisponible.'));
    }
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<String?> savePricing(Map<String, dynamic> values) async {
    final res = await _api.put('/admin/pricing', values, auth: true);
    return res['success'] == true ? null : _msg(res, 'Enregistrement impossible.');
  }

  Future<Map<String, dynamic>> getFinanceSummary() async {
    final res = await _api.get('/admin/finance/summary', auth: true);
    if (res['success'] != true || res['data'] is! Map) {
      throw Exception(_msg(res, 'Route /admin/finance/summary indisponible.'));
    }
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> getPayouts({String status = 'du'}) async {
    final res = await _api.get('/admin/payouts?status=$status', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Route /admin/payouts indisponible.'));
    return _list(res['data']);
  }

  Future<String?> payPayout(String id) async {
    final res = await _api.post('/admin/payouts/$id/pay', {}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Versement impossible.');
  }

  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    final res = await _api.get('/admin/audit-logs?limit=100', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Route /admin/audit-logs indisponible.'));
    return _list(res['data']);
  }
}
