// lib/services/plan_service.dart
// Formules et abonnements. AUCUNE valeur par dÃ©faut : tout vient du serveur
// (prix Premium : GET /premium/plan ; formules d'agence : GET /agency-plans).
// Si le serveur ne rÃ©pond pas, une erreur claire est levÃ©e et l'Ã©cran propose de rÃ©essayer.

import 'api_service.dart';

class PlanAudience {
  static const particulier = 'particulier';
  static const professionnel = 'professionnel';
  static const entreprise = 'entreprise';
  static const all = [particulier, professionnel, entreprise];

  static String label(String a) {
    switch (a) {
      case particulier:   return 'Particuliers';
      case professionnel: return 'Professionnels';
      default:            return 'Entreprises';
    }
  }
}

/// LibellÃ© d'une durÃ©e d'abonnement (30 j â†’ Â« 1 mois Â», etc.).
String planDurationLabel(int days) {
  switch (days) {
    case 30:  return '1 mois';
    case 180: return '6 mois';
    case 365: return '1 an';
    default:  return '$days jours';
  }
}

/// Une durÃ©e de Premium proposÃ©e par le serveur, avec son prix.
class PremiumPeriod {
  final String key; // month | 6months | year
  final String label;
  final int durationDays;
  final double priceFcfa;
  const PremiumPeriod({
    required this.key,
    required this.label,
    required this.durationDays,
    required this.priceFcfa,
  });

  static PremiumPeriod? tryParse(dynamic j) {
    if (j is! Map) return null;
    final key = (j['key'] ?? '').toString();
    final days = j['durationDays'];
    final price = j['priceFcfa'];
    if (key.isEmpty || days is! num || price is! num || days <= 0 || price <= 0) return null;
    final label = (j['label'] ?? '').toString();
    return PremiumPeriod(
      key: key,
      label: label.isEmpty ? planDurationLabel(days.toInt()) : label,
      durationDays: days.toInt(),
      priceFcfa: price.toDouble(),
    );
  }
}

/// Formule d'abonnement d'agence (configurÃ©e depuis l'admin).
class AgencyPlanModel {
  final String id;
  final String name;
  final String? description;
  final double priceFcfa;
  final int durationDays;
  final int? maxMembers;   // null = illimitÃ©
  final int? maxListings;  // null = illimitÃ©
  final bool advancedStats;
  const AgencyPlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceFcfa,
    required this.durationDays,
    required this.maxMembers,
    required this.maxListings,
    required this.advancedStats,
  });

  static AgencyPlanModel? tryParse(dynamic j) {
    if (j is! Map) return null;
    final id = (j['id'] ?? '').toString();
    final price = j['priceFcfa'];
    final days = j['durationDays'];
    if (id.isEmpty || price is! num || days is! num) return null;
    final desc = (j['description'] ?? '').toString().trim();
    return AgencyPlanModel(
      id: id,
      name: (j['name'] ?? '').toString(),
      description: desc.isEmpty ? null : desc,
      priceFcfa: price.toDouble(),
      durationDays: days.toInt(),
      maxMembers: j['maxMembers'] is num ? (j['maxMembers'] as num).toInt() : null,
      maxListings: j['maxListings'] is num ? (j['maxListings'] as num).toInt() : null,
      advancedStats: j['advancedStats'] == true,
    );
  }
}

class AgencyPlansInfo {
  final bool paidEnabled;
  final List<AgencyPlanModel> plans;
  const AgencyPlansInfo({required this.paidEnabled, required this.plans});
}

class OrganizationRef {
  final String id;
  final String name;
  const OrganizationRef({required this.id, required this.name});
}

class SubscriptionInfo {
  final String planName;
  final String status; // actif | expire | aucun
  final DateTime? expiresAt;
  const SubscriptionInfo({this.planName = 'Gratuit', this.status = 'aucun', this.expiresAt});
}

class PlanService {
  PlanService._();
  static final PlanService instance = PlanService._();
  final _api = ApiService.instance;

  /// Renvoie `data` si la rÃ©ponse est un succÃ¨s, sinon lÃ¨ve le message du serveur.
  dynamic _data(Map<String, dynamic> res, String fallbackMessage) {
    if (res['success'] != true) {
      throw Exception((res['message'] ?? fallbackMessage).toString());
    }
    return res['data'];
  }

  /// DurÃ©es de Premium et prix, tels que configurÃ©s sur le serveur.
  Future<List<PremiumPeriod>> getPremiumPeriods() async {
    final d = _data(await _api.get('/premium/plan'), 'Tarifs indisponibles pour le moment.');
    final raw = d is Map ? d['periods'] : null;
    final list = (raw is List ? raw : const [])
        .map(PremiumPeriod.tryParse)
        .whereType<PremiumPeriod>()
        .toList()
      ..sort((a, b) => a.durationDays.compareTo(b.durationDays));
    if (list.isEmpty) throw Exception('Aucune formule Premium disponible pour le moment.');
    return list;
  }

  /// Formules d'abonnement d'agence (vide tant que l'admin n'a pas ouvert les abonnements).
  Future<AgencyPlansInfo> getAgencyPlans() async {
    final d = _data(await _api.get('/agency-plans'), 'Formules indisponibles pour le moment.');
    if (d is! Map) throw Exception('RÃ©ponse invalide du serveur.');
    final raw = d['plans'];
    return AgencyPlansInfo(
      paidEnabled: d['paidEnabled'] == true,
      plans: (raw is List ? raw : const []).map(AgencyPlanModel.tryParse).whereType<AgencyPlanModel>().toList(),
    );
  }

  /// period : 'month' | '6months' | 'year'. Retourne l'URL de paiement hÃ©bergÃ©.
  Future<String> checkoutPremium(String period) async {
    final d = _data(await _api.post('/premium/checkout', {'period': period}, auth: true), 'Paiement indisponible.');
    final url = d is Map ? (d['paymentUrl'] ?? d['checkoutUrl']) : null;
    if (url == null || url.toString().isEmpty) throw Exception('Paiement indisponible.');
    return url.toString();
  }

  /// Agences dont l'utilisateur est membre.
  Future<List<OrganizationRef>> getMyOrganizations() async {
    final d = _data(await _api.get('/organizations/mine', auth: true), 'Entreprises indisponibles.');
    if (d is! List) return <OrganizationRef>[];
    return d
        .whereType<Map>()
        .map((o) => OrganizationRef(id: (o['id'] ?? '').toString(), name: (o['name'] ?? '').toString()))
        .where((o) => o.id.isNotEmpty)
        .toList();
  }

  /// Abonnement d'une agence Ã  une formule. Retourne l'URL de paiement hÃ©bergÃ©.
  Future<String> checkoutAgency(String organizationId, String planId) async {
    final d = _data(
      await _api.post('/organizations/$organizationId/subscription/checkout', {'planId': planId}, auth: true),
      'Paiement indisponible.',
    );
    final url = d is Map ? (d['checkoutUrl'] ?? d['paymentUrl']) : null;
    if (url == null || url.toString().isEmpty) throw Exception('Paiement indisponible.');
    return url.toString();
  }

  /// Abonnement Premium de l'utilisateur connectÃ©.
  Future<SubscriptionInfo> getMySubscription() async {
    final d = _data(await _api.get('/premium/status', auth: true), 'Abonnement indisponible.');
    if (d is! Map) throw Exception('RÃ©ponse invalide du serveur.');
    final rawExp = d['premiumExpiresAt'];
    final exp = rawExp != null ? DateTime.tryParse(rawExp.toString())?.toLocal() : null;
    if (d['isPremium'] == true) return SubscriptionInfo(planName: 'Premium', status: 'actif', expiresAt: exp);
    if (exp != null) return SubscriptionInfo(planName: 'Premium', status: 'expire', expiresAt: exp);
    return const SubscriptionInfo();
  }

  /// Paiements d'abonnement confirmÃ©s (Premium et agences).
  Future<List<Map<String, dynamic>>> getInvoices() async {
    final d = _data(await _api.get('/premium/invoices', auth: true), 'Factures indisponibles.');
    return d is List ? d.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
  }
}
