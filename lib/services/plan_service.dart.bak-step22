// lib/services/plan_service.dart
// Formules Freemium / Premium par profil (particulier, professionnel, entreprise).
// Les prix affichés viennent de GET /plans (configurables depuis l'admin) ; sans
// réponse du serveur, on affiche les valeurs de lancement du cahier des charges.

import 'package:flutter/foundation.dart';
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

class PlanModel {
  final String id;
  final String audience;
  final String name;
  final String tagline;
  final bool premium;
  final double? priceMonthly;  // null + premium = sur devis
  final double? price6Months;  // formules prépayées
  final double? price1Year;

  const PlanModel({
    required this.id,
    required this.audience,
    required this.name,
    required this.tagline,
    this.premium = false,
    this.priceMonthly,
    this.price6Months,
    this.price1Year,
  });

  bool get isFree => !premium;
  bool get onQuote => premium && priceMonthly == null;

  factory PlanModel.fromJson(Map<String, dynamic> j) {
    double? n(dynamic v) => v is num ? v.toDouble() : null;
    return PlanModel(
      id: (j['id'] ?? '').toString(),
      audience: (j['audience'] ?? PlanAudience.particulier).toString(),
      name: (j['name'] ?? '').toString(),
      tagline: (j['tagline'] ?? '').toString(),
      premium: j['premium'] == true,
      priceMonthly: n(j['priceMonthly']),
      price6Months: n(j['price6Months']),
      price1Year: n(j['price1Year']),
    );
  }
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

  /// Valeurs de lancement (hypothèses à tester auprès des utilisateurs togolais).
  /// La formule de 5 ans n'est volontairement PAS proposée.
  static const List<PlanModel> fallback = [
    PlanModel(
      id: 'particulier-gratuit', audience: PlanAudience.particulier, name: 'Gratuit',
      tagline: 'Rechercher, publier une annonce de base et gérer ses contacts.',
      priceMonthly: 0,
    ),
    PlanModel(
      id: 'particulier-plus', audience: PlanAudience.particulier, name: 'Plus', premium: true,
      tagline: 'Alertes avancées, statistiques, outils de gestion et avantages de visibilité définis.',
      priceMonthly: 2000,
    ),
    PlanModel(
      id: 'pro-gratuit', audience: PlanAudience.professionnel, name: 'Professionnel gratuit',
      tagline: 'Profil professionnel, annonces de base et gestion simple des prospects.',
      priceMonthly: 0,
    ),
    PlanModel(
      id: 'pro-premium', audience: PlanAudience.professionnel, name: 'Professionnel Premium', premium: true,
      tagline: 'Plus d\'annonces, statistiques, suivi des contacts et outils de gestion avancés.',
      priceMonthly: 2000, price6Months: 11000, price1Year: 20000,
    ),
    PlanModel(
      id: 'entreprise-gratuite', audience: PlanAudience.entreprise, name: 'Entreprise gratuite',
      tagline: 'Profil entreprise et gestion simple.',
      priceMonthly: 0,
    ),
    PlanModel(
      id: 'entreprise-premium', audience: PlanAudience.entreprise, name: 'Entreprise Premium', premium: true,
      tagline: 'Multi-utilisateurs, rôles, suivi d\'équipe, rapports et volumes d\'annonces adaptés.',
    ),
  ];

  Future<List<PlanModel>> getPlans() async {
    try {
      final res = await _api.get('/plans');
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(PlanModel.fromJson)
            .where((p) => p.id.isNotEmpty)
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('Plans load error: $e');
    }
    return fallback;
  }

  /// period : 'month' | '6months' | 'year'. Retourne l'URL de paiement hébergé.
  Future<String> checkout(String planId, String period) async {
    final res = await _api.post('/subscriptions/checkout', {'planId': planId, 'period': period}, auth: true);
    final url = res['success'] == true && res['data'] is Map ? (res['data'] as Map)['checkoutUrl'] : null;
    if (url == null) throw Exception((res['message'] ?? 'Paiement indisponible.').toString());
    return url.toString();
  }

  Future<String?> requestQuote(String planId, {String message = ''}) async {
    final res = await _api.post('/subscriptions/quote-request', {'planId': planId, 'message': message}, auth: true);
    return res['success'] == true ? null : (res['message'] ?? 'Demande impossible.').toString();
  }

  Future<SubscriptionInfo> getMySubscription() async {
    try {
      final res = await _api.get('/subscriptions/me', auth: true);
      if (res['success'] == true && res['data'] is Map) {
        final d = res['data'] as Map;
        return SubscriptionInfo(
          planName: (d['planName'] ?? 'Gratuit').toString(),
          status: (d['status'] ?? 'aucun').toString(),
          expiresAt: d['expiresAt'] != null ? DateTime.tryParse(d['expiresAt'].toString()) : null,
        );
      }
    } catch (_) {}
    return const SubscriptionInfo();
  }

  Future<List<Map<String, dynamic>>> getInvoices() async {
    final res = await _api.get('/me/invoices', auth: true);
    if (res['success'] != true) throw Exception((res['message'] ?? 'Factures indisponibles.').toString());
    final d = res['data'];
    return d is List ? d.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
  }
}
