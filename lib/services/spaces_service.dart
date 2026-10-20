// lib/services/spaces_service.dart
// Profil ≠ rôles : un même COMPTE peut donner accès à plusieurs espaces
// (personnel, Velqix Pro, Velqix Business) selon les autorisations du serveur.
// Une même personne peut ainsi être propriétaire et professionnelle sans créer
// plusieurs comptes.

import 'api_service.dart';

String _msg(Map<String, dynamic> res, String fallback) => (res['message'] ?? fallback).toString();

List<Map<String, dynamic>> _list(dynamic d) =>
    d is List ? d.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];

Map<String, dynamic> _map(dynamic d) => d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};

class BusinessRole {
  static const admin = 'administrateur';
  static const manager = 'gestionnaire';
  static const sales = 'commercial';
  static const accountant = 'comptable';
  static const all = [admin, manager, sales, accountant];

  static String label(String r) {
    switch (r) {
      case admin:      return 'Administrateur';
      case manager:    return 'Gestionnaire';
      case sales:      return 'Commercial';
      case accountant: return 'Comptable';
      default:         return r;
    }
  }

  static String description(String r) {
    switch (r) {
      case admin:      return "Tout : équipe, portefeuille, rapports, facturation.";
      case manager:    return 'Portefeuille et attribution des annonces, rapports.';
      case sales:      return 'Annonces attribuées, prospects et visites.';
      case accountant: return 'Factures, paiements et rapports financiers.';
      default:         return '';
    }
  }
}

class MySpaces {
  final bool pro;
  final bool business;
  final String? businessName;
  final String? businessRole;
  const MySpaces({this.pro = false, this.business = false, this.businessName, this.businessRole});
}

class SpacesService {
  SpacesService._();
  static final SpacesService instance = SpacesService._();
  final _api = ApiService.instance;

  Future<MySpaces> getMySpaces() async {
    final res = await _api.get('/me/spaces', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Impossible de charger vos espaces.'));
    final d = _map(res['data']);
    return MySpaces(
      pro: d['pro'] == true,
      business: d['business'] == true,
      businessName: d['businessName']?.toString(),
      businessRole: d['businessRole']?.toString(),
    );
  }

  /// activity : agent_immobilier | demarcheur_independant | commercial | vendeur | autre
  Future<String?> activatePro(String activity) async {
    final res = await _api.post('/me/spaces/pro', {'activity': activity}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Activation impossible.');
  }

  Future<String?> activateBusiness(String name) async {
    final res = await _api.post('/me/spaces/business', {'name': name}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Création impossible.');
  }
}

class ProService {
  ProService._();
  static final ProService instance = ProService._();
  final _api = ApiService.instance;

  Future<Map<String, dynamic>> getDashboard() async {
    final res = await _api.get('/pro/dashboard', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Tableau de bord indisponible.'));
    return _map(res['data']);
  }

  Future<List<Map<String, dynamic>>> getLeads() async {
    final res = await _api.get('/pro/leads', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Prospects indisponibles.'));
    return _list(res['data']);
  }

  /// status : nouveau | contacte | visite | conclu | perdu
  Future<String?> updateLead(String id, String status) async {
    final res = await _api.put('/pro/leads/$id', {'status': status}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Mise à jour impossible.');
  }
}

class BusinessService {
  BusinessService._();
  static final BusinessService instance = BusinessService._();
  final _api = ApiService.instance;

  Future<Map<String, dynamic>> getOverview() async {
    final res = await _api.get('/business/overview', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, "Vue d'ensemble indisponible."));
    return _map(res['data']);
  }

  Future<List<Map<String, dynamic>>> getProperties() async {
    final res = await _api.get('/business/properties', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Portefeuille indisponible.'));
    return _list(res['data']);
  }

  Future<String?> assign(String propertyId, String userId) async {
    final res = await _api.put('/business/properties/$propertyId/assign', {'userId': userId}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Attribution impossible.');
  }

  Future<List<Map<String, dynamic>>> getTeam() async {
    final res = await _api.get('/business/team', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Équipe indisponible.'));
    return _list(res['data']);
  }

  Future<String?> addMember(String email, String role) async {
    final res = await _api.post('/business/team', {'email': email, 'role': role}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Ajout impossible.');
  }

  Future<String?> changeRole(String memberId, String role) async {
    final res = await _api.put('/business/team/$memberId', {'role': role}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Modification impossible.');
  }

  Future<String?> removeMember(String memberId) async {
    final res = await _api.delete('/business/team/$memberId', auth: true);
    return res['success'] == true ? null : _msg(res, 'Suppression impossible.');
  }

  /// period : 7d | 30d | 90d
  Future<Map<String, dynamic>> getReport(String period) async {
    final res = await _api.get('/business/reports?period=$period', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Rapports indisponibles.'));
    return _map(res['data']);
  }

  /// URL de téléchargement du rapport (CSV).
  Future<String> exportReportUrl(String period) async {
    final res = await _api.get('/business/reports/export?period=$period&format=csv', auth: true);
    final url = res['success'] == true ? _map(res['data'])['url'] : null;
    if (url == null) throw Exception(_msg(res, 'Export indisponible.'));
    return url.toString();
  }
}
