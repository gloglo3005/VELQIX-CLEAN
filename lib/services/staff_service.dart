// lib/services/staff_service.dart
// Démarcheurs et agents d'entretien.
// ⚠️ Ces comptes NE peuvent PAS être créés via l'inscription publique :
// ils sont créés uniquement par l'équipe VelQix ou l'administrateur
// (POST /admin/staff). Les utilisateurs, eux, ne font que les consulter
// et les contacter (GET /users/staff).

import '../models/models.dart';
import 'api_service.dart';

class StaffService {
  StaffService._();
  static final StaffService instance = StaffService._();

  static const String roleDemarcheur = 'demarcheur';
  static const String roleAgentEntretien = 'agent_entretien';

  /// Liste publique (authentifiée) des comptes démarcheurs / agents d'entretien.
  Future<List<UserModel>> getStaff({String? role}) async {
    final query = role != null ? '?role=$role' : '';
    final res = await ApiService.instance.get('/users/staff$query', auth: true);
    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Impossible de charger la liste.');
    }
    final data = res['data'];
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map((j) {
      return UserModel.fromJson({
        ...j,
        'nom': j['nom'] ?? '',
        'prenom': j['prenom'] ?? '',
        'createdAt': j['createdAt'] ?? DateTime.now().toIso8601String(),
      });
    }).toList();
  }

  /// Création d'un compte par l'administrateur. Retourne un message d'erreur
  /// ou null si tout s'est bien passé.
  Future<String?> createStaff({
    required String role, // roleDemarcheur | roleAgentEntretien
    required String prenom,
    required String nom,
    required String telephone,
    required String email,
    required String password,
    String? username,
  }) async {
    final res = await ApiService.instance.post('/admin/staff', {
      'role': role,
      'prenom': prenom,
      'nom': nom,
      'telephone': telephone,
      'email': email,
      'password': password,
      if (username != null && username.trim().isNotEmpty) 'username': username.trim(),
    }, auth: true);
    if (res['success'] != true) {
      return (res['message'] ?? 'Erreur lors de la création du compte.').toString();
    }
    return null;
  }
}
