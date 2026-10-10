import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Tarif Premium affiché dans l'application.
///
/// Source unique : le backend (variables PREMIUM_PRICE_FCFA et
/// PREMIUM_DURATION_DAYS, exposées par GET /api/premium/plan). Tant que le
/// serveur n'a pas répondu (ou s'il est injoignable), on affiche les valeurs de
/// repli, identiques aux valeurs par défaut du backend : l'affichage ne change
/// donc jamais pour l'utilisateur, il suit simplement le serveur quand le tarif
/// est modifié.
class PremiumPlan {
  final double priceFcfa;
  final int durationDays;

  const PremiumPlan({
    required this.priceFcfa,
    required this.durationDays,
  });
}

class PremiumPlanService {
  PremiumPlanService._();

  static final PremiumPlanService instance = PremiumPlanService._();

  /// Valeurs par défaut du backend (2000 FCFA pour 30 jours).
  static const PremiumPlan fallback = PremiumPlan(
    priceFcfa: 2000,
    durationDays: 30,
  );

  final ValueNotifier<PremiumPlan> plan = ValueNotifier<PremiumPlan>(fallback);

  bool _loaded = false;

  /// Charge le tarif depuis le serveur. Sans effet une fois chargé ; ne lève
  /// jamais d'exception (en cas d'échec, le tarif de repli reste affiché).
  Future<void> load() async {
    if (_loaded) {
      return;
    }

    try {
      final res = await ApiService.instance.get('/premium/plan');
      if (res['success'] != true) {
        return;
      }

      final data = res['data'];
      if (data is! Map) {
        return;
      }

      final price = data['priceFcfa'];
      final days = data['durationDays'];
      if (price is num && days is num && price > 0 && days > 0) {
        plan.value = PremiumPlan(
          priceFcfa: price.toDouble(),
          durationDays: days.toInt(),
        );
        _loaded = true;
      }
    } catch (e) {
      debugPrint('Premium plan load error: $e');
    }
  }
}
