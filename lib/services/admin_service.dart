// lib/services/admin_service.dart
// Gestion complète de la plateforme (façon « Django admin ») :
// utilisateurs, annonces, rôles et permissions.
// Les routes utilisées sont listées dans BACKEND_CHANGES.md.

import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;

import '../models/models.dart';
import 'api_service.dart';

class AdminPermission {
  final String key;
  final String label;
  final String group;
  const AdminPermission(this.key, this.label, this.group);
}

class RoleMatrix {
  final Map<String, Set<String>> permissions;
  final bool fromServer; // false = valeurs par défaut locales (API absente)
  const RoleMatrix(this.permissions, this.fromServer);
}

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();
  final _api = ApiService.instance;

  // ─── Rôles de la plateforme ──────────────────────────────────────────────
  static const List<String> roles = [
    'client', 'proprietaire', 'demarcheur', 'agent_entretien', 'admin',
  ];

  static String roleLabel(String r) {
    switch (r) {
      case 'client':          return 'Client';
      case 'proprietaire':    return 'Propriétaire';
      case 'demarcheur':      return 'Démarcheur';
      case 'agent_entretien': return "Agent d'entretien";
      case 'admin':           return 'Administrateur';
      default:                return r;
    }
  }

  // ─── Catalogue des permissions ───────────────────────────────────────────
  static const List<AdminPermission> permissions = [
    AdminPermission('stats.view',          'Voir les statistiques',            'Plateforme'),
    AdminPermission('users.view',          'Voir les utilisateurs',            'Utilisateurs'),
    AdminPermission('users.edit',          'Modifier / vérifier / suspendre',  'Utilisateurs'),
    AdminPermission('users.delete',        'Supprimer des comptes',            'Utilisateurs'),
    AdminPermission('users.create_staff',  "Créer démarcheurs / agents",       'Utilisateurs'),
    AdminPermission('roles.manage',        'Gérer les rôles et permissions',   'Utilisateurs'),
    AdminPermission('properties.create',   'Publier des annonces',             'Annonces'),
    AdminPermission('properties.moderate', 'Approuver / rejeter des annonces', 'Annonces'),
    AdminPermission('properties.verify_field', 'Vérifier les biens sur le terrain', 'Annonces'),
    AdminPermission('properties.edit',     "Modifier les annonces d'autrui",   'Annonces'),
    AdminPermission('properties.delete',   "Supprimer les annonces d'autrui",  'Annonces'),
    AdminPermission('disputes.manage',     'Gérer les litiges',                'Support'),
    AdminPermission('missions.manage',     'Suivre, valider les missions terrain', 'Opérations'),
    AdminPermission('pricing.manage',      'Modifier les tarifs et rémunérations', 'Opérations'),
    AdminPermission('finance.view',        'Voir les finances',                'Finances'),
    AdminPermission('finance.payouts',     'Verser les agents',                'Finances'),
    AdminPermission('audit.view',          "Consulter le journal d'activité",  'Finances'),
    AdminPermission('chat.use',            'Utiliser la messagerie',           'Communication'),
  ];

  /// Matrice par défaut, utilisée tant que le backend ne fournit pas la sienne.
  static Map<String, Set<String>> defaultMatrix() => {
        'client': {'chat.use'},
        'proprietaire': {'chat.use', 'properties.create'},
        'demarcheur': {'chat.use', 'properties.create', 'properties.verify_field'},
        'agent_entretien': {'chat.use'},
        'admin': permissions.map((p) => p.key).toSet(),
      };

  // ─── Utilisateurs ────────────────────────────────────────────────────────
  Future<List<UserModel>> getUsers() async {
    final res = await _api.get('/admin/users?limit=500', auth: true);
    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Impossible de charger les utilisateurs.');
    }
    return (res['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map((j) => UserModel.fromJson({
              ...j,
              'nom': j['nom'] ?? '',
              'prenom': j['prenom'] ?? '',
              'createdAt': j['createdAt'] ?? DateTime.now().toIso8601String(),
            }))
        .toList();
  }

  /// changes : { role?, isVerified?, isActive? }
  Future<String?> updateUser(String id, Map<String, dynamic> changes) async {
    final res = await _api.put('/admin/users/$id', changes, auth: true);
    return res['success'] == true ? null : (res['message'] ?? 'Modification impossible.').toString();
  }

  /// Réinitialise le mot de passe d'un utilisateur. Le mot de passe est envoyé
  /// en HTTPS puis haché (Argon2id) côté API : il n'est jamais stocké en clair.
  /// L'utilisateur devra le changer à sa prochaine connexion.
  Future<String?> resetUserPassword(String id, String newPassword) async {
    final res = await _api.post(
      '/admin/users/$id/reset-password',
      {'newPassword': newPassword, 'mustChangePassword': true},
      auth: true,
    );
    return res['success'] == true ? null : (res['message'] ?? 'Réinitialisation impossible.').toString();
  }

  /// Génère un mot de passe temporaire robuste (aléatoire cryptographique).
  static String generateTempPassword({int length = 12}) {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const digits = '23456789';
    const symbols = '!@#\$%*?-_';
    final rnd = Random.secure();
    String pick(String s) => s[rnd.nextInt(s.length)];
    final all = upper + lower + digits + symbols;
    final chars = [pick(upper), pick(lower), pick(digits), pick(symbols)];
    while (chars.length < length) {
      chars.add(pick(all));
    }
    chars.shuffle(rnd);
    return chars.join();
  }

  Future<String?> deleteUser(String id) async {
    final res = await _api.delete('/admin/users/$id', auth: true);
    return res['success'] == true ? null : (res['message'] ?? 'Suppression impossible.').toString();
  }

  // ─── Annonces ────────────────────────────────────────────────────────────
  /// Toutes les annonces, tous statuts confondus. Retourne null si la route
  /// n'existe pas encore côté API.
  Future<List<PropertyModel>?> getAllProperties() async {
    final res = await _api.get('/admin/properties?limit=500', auth: true);
    if (res['success'] != true || res['data'] is! List) return null;
    return (res['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map(PropertyModel.fromJson)
        .toList();
  }

  Future<String?> approveProperty(String id) async {
    final res = await _api.put('/admin/properties/$id/approve', {}, auth: true);
    debugPrint('approve $id → $res');
    return res['success'] == true ? null : (res['message'] ?? 'Erreur.').toString();
  }

  Future<String?> rejectProperty(String id) async {
    final res = await _api.put('/admin/properties/$id/reject', {}, auth: true);
    debugPrint('reject $id → $res');
    return res['success'] == true ? null : (res['message'] ?? 'Erreur.').toString();
  }

  Future<String?> deleteProperty(String id) async {
    final res = await _api.delete('/admin/properties/$id', auth: true);
    return res['success'] == true ? null : (res['message'] ?? 'Suppression impossible.').toString();
  }

  // ─── Rôles & permissions ─────────────────────────────────────────────────
  Future<RoleMatrix> getRoleMatrix() async {
    try {
      final res = await _api.get('/admin/roles', auth: true);
      if (res['success'] == true && res['data'] is Map) {
        final defaults = defaultMatrix();
        final data = res['data'] as Map;
        final out = <String, Set<String>>{};
        for (final r in roles) {
          final list = data[r];
          out[r] = list is List ? list.map((e) => e.toString()).toSet() : defaults[r]!;
        }
        return RoleMatrix(out, true);
      }
    } catch (_) {}
    return RoleMatrix(defaultMatrix(), false);
  }

  Future<String?> saveRolePermissions(String role, Set<String> perms) async {
    final res = await _api.put('/admin/roles/$role', {'permissions': perms.toList()}, auth: true);
    return res['success'] == true ? null : (res['message'] ?? 'Enregistrement impossible.').toString();
  }
}
