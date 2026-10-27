// lib/services/analytics_service.dart
// Indicateurs du tableau de bord (ANA-01, cahier §15.1 et §17).
//
// Route admin : GET /admin/analytics?days=30  (lecture seule, permission « stats.view »).
// Le serveur calcule tout ; l'app n'affiche que ce qu'il renvoie. Un indicateur
// sans base de calcul arrive à null (affiché « — »), jamais à 0, et ceux que la
// base ne permet pas de mesurer sont listés dans `notMeasured`.

import 'api_service.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();
  final _api = ApiService.instance;

  /// Périodes proposées dans l'app (jours).
  static const List<int> periods = [7, 30, 90];

  /// Lève une Exception avec le message du serveur en cas d'échec.
  Future<Map<String, dynamic>> overview({int days = 30}) async {
    final res = await _api.get('/admin/analytics?days=$days', auth: true);
    if (res['success'] != true || res['data'] is! Map) {
      throw Exception((res['message'] ?? 'Impossible de charger les indicateurs.').toString());
    }
    return Map<String, dynamic>.from(res['data'] as Map);
  }
}
