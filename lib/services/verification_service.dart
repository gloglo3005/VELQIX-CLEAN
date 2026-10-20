// lib/services/verification_service.dart
// « Vérifiée sur le terrain » : vérification terrain par les démarcheurs.
//  • Le propriétaire demande la vérification d'un bien (requestVerification).
//  • Le démarcheur voit les demandes, se rend sur place et valide (verify).
// Seule une vérification terrain donne ce statut : le Premium ne le donne pas
// (cahier des charges §10.3).

import '../models/models.dart';
import 'api_service.dart';

enum VerificationScope { requested, all, mine }

class VerificationService {
  VerificationService._();
  static final VerificationService instance = VerificationService._();
  final _api = ApiService.instance;

  /// Propriétaire : demande qu'un démarcheur vérifie son bien sur place.
  Future<String?> requestVerification(String propertyId) async {
    final res = await _api.post('/properties/$propertyId/verification-request', {}, auth: true);
    return res['success'] == true ? null : (res['message'] ?? 'Demande impossible.').toString();
  }

  /// Démarcheur : liste des annonces à vérifier (ou déjà vérifiées par lui).
  Future<List<PropertyModel>> getQueue(VerificationScope scope) async {
    final res = await _api.get('/demarcheur/verifications?scope=${scope.name}', auth: true);
    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Impossible de charger la liste.');
    }
    final data = res['data'];
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map(PropertyModel.fromJson).toList();
  }

  /// Démarcheur : confirme que le bien existe réellement (visite sur place).
  Future<String?> verify(
    String propertyId, {
    required bool exists,
    required bool photosMatch,
    required bool ownerIdentified,
    String? note,
  }) async {
    final res = await _api.post(
      '/demarcheur/properties/$propertyId/verify',
      {
        'checklist': {
          'exists': exists,
          'photosMatch': photosMatch,
          'ownerIdentified': ownerIdentified,
        },
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      auth: true,
    );
    return res['success'] == true ? null : (res['message'] ?? 'Validation impossible.').toString();
  }
}
