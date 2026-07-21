// ═══════════════════════════════════════════════════════════════════
// AVIS SERVICE — VelQix
// ═══════════════════════════════════════════════════════════════════

import '../models/models.dart';
import 'api_service.dart';

class AvisService {
  AvisService._();
  static final AvisService instance = AvisService._();

  final _api = ApiService.instance;

  AvisModel _fromJson(Map<String, dynamic> json) {
    final auteurJson = json['auteur'] as Map<String, dynamic>? ?? {};
    return AvisModel(
      id: json['id'] ?? '',
      auteur: UserModel(
        id:        auteurJson['id']      ?? '',
        nom:       auteurJson['nom']     ?? '',
        prenom:    auteurJson['prenom']  ?? '',
        email:     '',
        telephone: auteurJson['telephone'] ?? '',
        avatarUrl: auteurJson['avatarUrl'],
        rating: 0, totalAvis: 0, createdAt: DateTime.now(),
      ),
      cible:       json['propertyId'] ?? '',
      note:        (json['note'] ?? 0).toDouble(),
      commentaire: json['commentaire'] ?? '',
      createdAt:   json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // ─── Lister les avis d'un bien ────────────────────────────────────
  Future<List<AvisModel>> getAvis(String propertyId) async {
    final res = await _api.get('/properties/$propertyId/avis');
    if (res['success'] != true) return [];
    final list = res['data'] as List<dynamic>;
    return list.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Laisser un avis ─────────────────────────────────────────────
  Future<({AvisModel? avis, String? error})> createAvis({
    required String propertyId,
    required double note,
    required String commentaire,
  }) async {
    final res = await _api.post(
      '/properties/$propertyId/avis',
      {'note': note, 'commentaire': commentaire},
      auth: true,
    );
    if (res['success'] != true) {
      return (avis: null, error: (res['message'] as String?) ?? 'Erreur');
    }
    return (avis: _fromJson(res['data'] as Map<String, dynamic>), error: null);
  }

  // ─── Supprimer un avis ───────────────────────────────────────────
  Future<String?> deleteAvis(String avisId) async {
    final res = await _api.delete('/avis/$avisId', auth: true);
    if (res['success'] != true) return res['message'] ?? 'Erreur';
    return null;
  }
}