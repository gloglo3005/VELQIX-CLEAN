// ═══════════════════════════════════════════════════════════════════
// PROPERTY SERVICE — VelQix
// Remplace mock_data.dart — connecté au backend Node.js/Express
// ═══════════════════════════════════════════════════════════════════

import 'dart:io';
import '../models/models.dart';
import 'api_service.dart';

class PropertyService {
  PropertyService._();
  static final PropertyService instance = PropertyService._();

  final _api = ApiService.instance;

  // Un seul parseur pour toute l'app : PropertyModel.fromJson
  PropertyModel _fromJson(Map<String, dynamic> json) => PropertyModel.fromJson(json);

  // ─── GET — Liste des biens ────────────────────────────────────────
  Future<List<PropertyModel>> getProperties({
    String? type,
    String? listingType,
    String? categorie,
    String? ville,
    String? pays,
    double? prixMin,
    double? prixMax,
  }) async {
    // Construire les query params de filtrage
    final params = <String, String>{};
    if (type != null) params['type'] = type;
    if (listingType != null) params['listingType'] = listingType;
    if (categorie != null) params['categorie'] = categorie;
    if (ville != null) params['ville'] = ville;
    if (pays != null) params['pays'] = pays;
    if (prixMin != null) params['prixMin'] = prixMin.toString();
    if (prixMax != null) params['prixMax'] = prixMax.toString();

    final query = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';

    final res = await _api.get('/properties$query');
    if (res['success'] != true) return [];

    final list = res['data'] as List<dynamic>;
    return list.map((item) => _fromJson(item as Map<String, dynamic>)).toList();
  }

  // ─── GET — Biens vedettes (Premium) ──────────────────────────────
  Future<List<PropertyModel>> getFeaturedProperties() async {
    final res = await _api.get('/properties/featured');
    if (res['success'] != true) return [];
    final list = res['data'] as List<dynamic>;
    return list.map((item) => _fromJson(item as Map<String, dynamic>)).toList();
  }

  // ─── GET — Mes annonces ───────────────────────────────────────────
  Future<List<PropertyModel>> getMyProperties() async {
    final res = await _api.get('/properties/my', auth: true);
    if (res['success'] != true) return [];
    final list = res['data'] as List<dynamic>;
    return list.map((item) => _fromJson(item as Map<String, dynamic>)).toList();
  }

  // ─── GET — Détail d'un bien ───────────────────────────────────────
  Future<PropertyModel?> getProperty(String id) async {
    final res = await _api.get('/properties/$id');
    if (res['success'] != true || res['data'] == null) return null;
    return _fromJson(res['data'] as Map<String, dynamic>);
  }

  // ─── POST — Créer un bien ─────────────────────────────────────────
  /// [imageUrl] : URL Cloudinary obtenue après un appel à uploadImage()
  Future<({PropertyModel? property, String? error})> createProperty({
    required String titre,
    required String description,
    required double prix,
    required String imageUrl,
    String type = 'immobilier',
    String listingType = 'vente',
    String categorie = 'appartement',
    String? adresse,
    String? ville,
    String pays = 'Togo',
    String? prixParJour,
    double? surface,
    int? nombrePieces,
    List<String> caracteristiques = const [],
  }) async {
    final res = await _api.post('/properties', {
      'titre': titre,
      'description': description,
      'prix': prix,
      'imageUrl': imageUrl,
      'type': type,
      'listingType': listingType,
      'categorie': categorie,
      if (adresse != null) 'adresse': adresse,
      if (ville != null) 'ville': ville,
      'pays': pays,
      if (prixParJour != null) 'prixParJour': prixParJour,
      if (surface != null) 'surface': surface,
      if (nombrePieces != null) 'nombrePieces': nombrePieces,
      if (caracteristiques.isNotEmpty) 'caracteristiques': caracteristiques,
    }, auth: true);

    if (res['success'] != true) {
      return (property: null, error: (res['message'] as String?) ?? 'Erreur création');
    }
    return (property: _fromJson(res['data'] as Map<String, dynamic>), error: null);
  }

  // ─── PUT — Modifier un bien ───────────────────────────────────────
  Future<String?> updateProperty(String id, Map<String, dynamic> data) async {
    final res = await _api.put('/properties/$id', data, auth: true);
    if (res['success'] != true) return res['message'] ?? 'Erreur mise à jour';
    return null;
  }

  // ─── DELETE — Supprimer un bien ───────────────────────────────────
  Future<String?> deleteProperty(String id) async {
    final res = await _api.delete('/properties/$id', auth: true);
    if (res['success'] != true) return res['message'] ?? 'Erreur suppression';
    return null;
  }

  // ─── POST — Incrémenter les vues ──────────────────────────────────
  Future<void> incrementViews(String id) async {
    await _api.post('/properties/$id/views', {});
  }

  // ─── Favoris ─────────────────────────────────────────────────────
  Future<bool> addFavorite(String propertyId) async {
    final res = await _api.post('/properties/$propertyId/favorite', {}, auth: true);
    return res['success'] == true;
  }

  Future<bool> removeFavorite(String propertyId) async {
    final res = await _api.delete('/properties/$propertyId/favorite', auth: true);
    return res['success'] == true;
  }

  Future<List<PropertyModel>> getFavorites() async {
    final res = await _api.get('/properties/favorites', auth: true);
    if (res['success'] != true) return [];
    final list = res['data'] as List<dynamic>;
    return list.map((item) => _fromJson(item as Map<String, dynamic>)).toList();
  }

  // ─── Abonnement (follow) ─────────────────────────────────────────
  // ⚠️ Avant : followOwner/unfollowOwner (widgets.dart) ne touchaient que des
  // ValueNotifier en mémoire — aucun appel réseau, rien de persisté. Ces
  // méthodes branchent sur les vrais endpoints POST/DELETE /users/:id/follow.

  /// Profil public d'un utilisateur, avec compteurs à jour et statut
  /// d'abonnement (GET /api/users/:id, route publique mais optionalAuth :
  /// passer auth: true si connecté pour obtenir isFollowedByMe).
  Future<UserModel?> fetchUserProfile(String userId, {bool auth = false}) async {
    final res = await _api.get('/users/$userId', auth: auth);
    if (res['success'] != true) return null;
    return UserModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Annonces approuvées d'un utilisateur (GET /api/users/:id/properties)
  Future<List<PropertyModel>> getUserProperties(String userId) async {
    final res = await _api.get('/users/$userId/properties');
    if (res['success'] != true) return [];
    final list = res['data'] as List<dynamic>;
    return list.map((item) => _fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<bool> followUser(String userId) async {
    final res = await _api.post('/users/$userId/follow', {}, auth: true);
    return res['success'] == true;
  }

  Future<bool> unfollowUser(String userId) async {
    final res = await _api.delete('/users/$userId/follow', auth: true);
    return res['success'] == true;
  }

  // ─── Avis ────────────────────────────────────────────────────────
  // ⚠️ Avant : property_detail_screen.dart affichait MockDataService.avis
  // (100% factice). Ces deux méthodes branchent sur les vrais endpoints
  // GET/POST /api/properties/:id/avis qui existaient déjà côté backend.
  Future<List<AvisModel>> getAvis(String propertyId) async {
    final res = await _api.get('/properties/$propertyId/avis', auth: false);
    if (res['success'] != true) return [];
    final list = res['data'] as List<dynamic>;
    return list.map((item) {
      final j = item as Map<String, dynamic>;
      final auteurJson = j['auteur'] as Map<String, dynamic>?;
      return AvisModel(
        id: j['id'] ?? '',
        cible: j['propertyId'] ?? propertyId,
        note: (j['note'] ?? 0).toDouble(),
        commentaire: j['commentaire'] ?? '',
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        auteur: UserModel(
          id: auteurJson?['id'] ?? j['auteurId'] ?? '',
          nom: auteurJson?['nom'] ?? '',
          prenom: auteurJson?['prenom'] ?? '',
          email: '', telephone: '',
          avatarUrl: auteurJson?['avatarUrl'],
          rating: 0, totalAvis: 0,
          createdAt: DateTime.now(),
        ),
      );
    }).toList();
  }

  /// Retourne null en cas de succès, ou un message d'erreur.
  Future<String?> createAvis(String propertyId, {required double note, required String commentaire}) async {
    final res = await _api.post('/properties/$propertyId/avis', {
      'note': note,
      'commentaire': commentaire,
    }, auth: true);
    if (res['success'] != true) return res['message'] ?? 'Erreur';
    return null;
  }

  // ─── Upload d'image ───────────────────────────────────────────────
  /// Upload une image et retourne l'URL Cloudinary à utiliser dans createProperty()
  Future<({String? url, String? error})> uploadImage(File imageFile) async {
    final res = await _api.uploadFile('/upload/image', imageFile);
    if (res['success'] != true) {
      return (url: null, error: (res['message'] as String?) ?? 'Erreur upload');
    }
    return (url: res['data']['url'] as String?, error: null);
  }

  /// Upload depuis bytes (web / caméra)
  Future<({String? url, String? error})> uploadImageBytes(
    List<int> bytes,
    String filename,
  ) async {
    final res = await _api.uploadBytes('/upload/image', bytes, filename);
    if (res['success'] != true) {
      return (url: null, error: (res['message'] as String?) ?? 'Erreur upload');
    }
    return (url: res['data']['url'] as String?, error: null);
  }
}
