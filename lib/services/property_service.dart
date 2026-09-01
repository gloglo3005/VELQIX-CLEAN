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

  // ─── Convertir JSON backend → PropertyModel Flutter ──────────────
  PropertyModel _fromJson(Map<String, dynamic> json) {
    final prop = json['proprietaire'] as Map<String, dynamic>?;

    return PropertyModel(
      id: json['id'] ?? '',
      titre: json['titre'] ?? '',
      description: json['description'] ?? '',
      prix: (json['prix'] ?? 0).toDouble(),
      prixParJour: json['prixParJour'],
      // Enums : convertir string → enum
      type: _parsePropertyType(json['type']),
      listingType: _parseListingType(json['listingType']),
      categorie: _parseCategorie(json['categorie']),
      // Images : le backend stocke une seule imageUrl, Flutter attend une liste
      images: json['images'] != null
          ? List<String>.from(json['images'])
          : (json['imageUrl'] != null ? [json['imageUrl'] as String] : []),
      adresse: AddressModel(
        rue: json['adresse'] ?? '',
        ville: json['ville'] ?? '',
        pays: json['pays'] ?? 'TG',
      ),
      proprietaire: prop != null
          ? UserModel(
              id: prop['id'] ?? '',
              nom: prop['nom'] ?? '',
              prenom: prop['prenom'] ?? '',
              email: prop['email'] ?? '',
              telephone: prop['telephone'] ?? '',
              avatarUrl: prop['avatarUrl'],
              isVerified: prop['isVerified'] ?? false,
              isPremium: prop['isPremium'] ?? false,
              rating: (prop['rating'] ?? 0.0).toDouble(),
              totalAvis: prop['totalAvis'] ?? 0,
              createdAt: prop['createdAt'] != null
                  ? DateTime.tryParse(prop['createdAt']) ?? DateTime.now()
                  : DateTime.now(),
              role: prop['role'] ?? 'client',
            )
          : UserModel(
              id: json['proprietaireId'] ?? '',
              nom: '', prenom: '', email: '',
              telephone: '', rating: 0, totalAvis: 0,
              createdAt: DateTime.now(),
            ),
      caracteristiques: json['caracteristiques'] != null
          ? List<String>.from(json['caracteristiques'])
          : [],
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalAvis: json['totalAvis'] ?? 0,
      isAvailable: json['isAvailable'] ?? true,
      isFeatured: json['isFeatured'] ?? false,
      status: json['status'] ?? 'en_attente',
      vues: json['vues'] ?? 0,
      surface: json['surface']?.toString(),
      nombrePieces: json['nombrePieces'],
      annee: json['annee'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

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
    String pays = 'TG',
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
  Future<void> addFavorite(String propertyId) async {
    await _api.post('/properties/$propertyId/favorite', {}, auth: true);
  }

  Future<void> removeFavorite(String propertyId) async {
    await _api.delete('/properties/$propertyId/favorite', auth: true);
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

  Future<void> followUser(String userId) async {
    await _api.post('/users/$userId/follow', {}, auth: true);
  }

  Future<void> unfollowUser(String userId) async {
    await _api.delete('/users/$userId/follow', auth: true);
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

  // ─── Parseurs d'enum ─────────────────────────────────────────────
  PropertyType _parsePropertyType(dynamic value) {
    switch (value?.toString()) {
      case 'mobilier': return PropertyType.mobilier;
      default: return PropertyType.immobilier;
    }
  }

  ListingType _parseListingType(dynamic value) {
    switch (value?.toString()) {
      case 'location': return ListingType.location;
      case 'les_deux': return ListingType.les_deux;
      default: return ListingType.vente;
    }
  }

  PropertyCategory _parseCategorie(dynamic value) {
    switch (value?.toString()) {
      case 'maison': return PropertyCategory.maison;
      case 'terrain': return PropertyCategory.terrain;
      case 'bureau': return PropertyCategory.bureau;
      case 'entrepot': return PropertyCategory.entrepot;
      case 'voiture': return PropertyCategory.voiture;
      case 'moto': return PropertyCategory.moto;
      case 'camion': return PropertyCategory.camion;
      case 'equipement': return PropertyCategory.equipement;
      case 'appartement': return PropertyCategory.appartement;
      default: return PropertyCategory.autre;
    }
  }
}