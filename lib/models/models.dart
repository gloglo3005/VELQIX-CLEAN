// ============================================================
// MODELS
// ============================================================

enum PropertyType { immobilier, mobilier }
enum ListingType { vente, location, les_deux }
enum PropertyCategory {
  maison, appartement, terrain, bureau, entrepot,
  voiture, moto, camion, equipement, autre
}

class UserModel {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final String? avatarUrl;
  final bool isVerified;
  final double rating;
  final int totalAvis;
  final DateTime createdAt;
  final String role; // 'proprietaire', 'client', 'admin'
  final bool isPremium;
  final String? countryCode; // Code ISO 2 lettres ex: 'TG', 'FR', 'US'
  final String? countryName; // Nom du pays ex: 'Togo', 'France'
  final String accountType; // 'personal' | 'business'
  final String? nomEntreprise;
  final String? typeActivite;
  final int followersCount;
  final int followingCount;
  final bool isFollowedByMe;

  UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    this.avatarUrl,
    this.isVerified = false,
    this.rating = 0.0,
    this.totalAvis = 0,
    required this.createdAt,
    this.role = 'client',
    this.isPremium = false,
    this.countryCode,
    this.countryName,
    this.accountType = 'personal',
    this.nomEntreprise,
    this.typeActivite,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowedByMe = false,
  });

  String get fullName {
  return "$prenom $nom".trim();
}

String get initials {
  String p = prenom.isNotEmpty ? prenom[0] : "";
  String n = nom.isNotEmpty ? nom[0] : "";
  return (p + n).toUpperCase();
}

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    nom: json['nom'],
    prenom: json['prenom'],
    // ⚠️ Certains endpoints (ex: GET /api/users recherche) n'exposent
    // volontairement pas email/téléphone pour la confidentialité — on
    // retombe sur '' plutôt que de planter (null → String non-nullable).
    email: json['email'] ?? '',
    telephone: json['telephone'] ?? '',
    avatarUrl: json['avatarUrl'],
    isVerified: json['isVerified'] ?? false,
    rating: (json['rating'] ?? 0.0).toDouble(),
    totalAvis: json['totalAvis'] ?? 0,
    createdAt: DateTime.parse(json['createdAt']),
    role: json['role'] ?? 'client',
    isPremium: json['isPremium'] ?? false,
    countryCode: json['countryCode'],
    countryName: json['countryName'],
    accountType: json['accountType'] ?? 'personal',
    nomEntreprise: json['nomEntreprise'],
    typeActivite: json['typeActivite'],
    // Présents uniquement sur GET /api/users/:id — absents ailleurs (ex.
    // proprietaire embarqué dans une annonce), d'où les valeurs par défaut.
    followersCount: json['followersCount'] ?? 0,
    followingCount: json['followingCount'] ?? 0,
    isFollowedByMe: json['isFollowedByMe'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'nom': nom, 'prenom': prenom, 'email': email,
    'telephone': telephone, 'avatarUrl': avatarUrl, 'isVerified': isVerified,
    'rating': rating, 'totalAvis': totalAvis, 'createdAt': createdAt.toIso8601String(),
    'role': role, 'isPremium': isPremium,
    'countryCode': countryCode, 'countryName': countryName,
    'accountType': accountType, 'nomEntreprise': nomEntreprise, 'typeActivite': typeActivite,
  };
}

class PropertyModel {
  final String id;
  final String titre;
  final String description;
  final PropertyType type;
  final ListingType listingType;
  final PropertyCategory categorie;
  final double prix;
  final String? prixParJour;
  final List<String> images;
  final AddressModel adresse;
  final UserModel proprietaire;
  final List<String> caracteristiques;
  final double rating;
  final int totalAvis;
  final bool isAvailable;
  final bool isFeatured;
  final DateTime createdAt;
  final int vues;
  final String? surface; // m²
  final int? nombrePieces;
  final int? annee;
  // 'en_attente' | 'approuve' | 'rejete'
  final String status;
  // Multilingual translations: {'en': '...', 'es': '...', 'pt': '...', 'de': '...', 'ar': '...'}
  final Map<String, String>? titreTranslations;
  final Map<String, String>? descriptionTranslations;
  final Map<String, List<String>>? caracteristiquesTranslations;
  final DateTime? updatedAt;

  PropertyModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.type,
    required this.listingType,
    required this.categorie,
    required this.prix,
    this.prixParJour,
    required this.images,
    required this.adresse,
    required this.proprietaire,
    this.caracteristiques = const [],
    this.rating = 0.0,
    this.totalAvis = 0,
    this.isAvailable = true,
    this.isFeatured = false,
    required this.createdAt,
    this.vues = 0,
    this.surface,
    this.nombrePieces,
    this.annee,
    this.status = 'approuve', // Les anciens biens sont approuvés par défaut
    this.titreTranslations,
    this.descriptionTranslations,
    this.caracteristiquesTranslations,
    this.updatedAt,
  });

  /// Lien de partage vers la page du bien (deep link web)
  // ⚠️ Corrigé : pointait vers "libimmo.tg", un reliquat de l'ancien nom du
  // projet avant son renommage en VelQix — lien mort et mauvaise marque
  // affichés à chaque partage d'annonce.
  String get shareUrl => 'https://velqix.tg/bien/$id';

  /// Texte de partage incluant le lien retour
  String get shareText {
    final montant = prix % 1 == 0
        ? prix.toInt().toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')
        : prix.toString();
    return '🏠 $titre\n'
        '📍 ${adresse.full}\n'
        '💰 $montant FCFA\n'
        '🔗 Disponible sur VelQix\n'
        '$shareUrl';
  }

  String get typeLabel => type == PropertyType.immobilier ? 'Immobilier' : 'Mobilier';
  String get listingLabel {
    switch (listingType) {
      case ListingType.vente: return 'Vente';
      case ListingType.location: return 'Location';
      case ListingType.les_deux: return 'Vente / Location';
    }
  }

  String get categorieLabel {
    const labels = {
      PropertyCategory.maison: 'Maison',
      PropertyCategory.appartement: 'Appartement',
      PropertyCategory.terrain: 'Terrain',
      PropertyCategory.bureau: 'Bureau',
      PropertyCategory.entrepot: 'Entrepôt',
      PropertyCategory.voiture: 'Voiture',
      PropertyCategory.moto: 'Moto',
      PropertyCategory.camion: 'Camion',
      PropertyCategory.equipement: 'Équipement',
      PropertyCategory.autre: 'Autre',
    };
    return labels[categorie] ?? 'Autre';
  }

  String get firstImage => images.isNotEmpty ? images.first : '';

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    PropertyType type;
    switch ((json['type'] ?? '').toString().toLowerCase()) {
      case 'mobilier': type = PropertyType.mobilier; break;
      default:         type = PropertyType.immobilier;
    }

    ListingType listingType;
    switch ((json['listingType'] ?? '').toString().toLowerCase()) {
      case 'vente':    listingType = ListingType.vente; break;
      case 'les_deux': listingType = ListingType.les_deux; break;
      default:         listingType = ListingType.location;
    }

    PropertyCategory categorie;
    switch ((json['categorie'] ?? '').toString().toLowerCase()) {
      case 'maison':      categorie = PropertyCategory.maison; break;
      case 'appartement': categorie = PropertyCategory.appartement; break;
      case 'terrain':     categorie = PropertyCategory.terrain; break;
      case 'bureau':      categorie = PropertyCategory.bureau; break;
      case 'entrepot':    categorie = PropertyCategory.entrepot; break;
      case 'voiture':     categorie = PropertyCategory.voiture; break;
      case 'moto':        categorie = PropertyCategory.moto; break;
      case 'camion':      categorie = PropertyCategory.camion; break;
      case 'equipement':  categorie = PropertyCategory.equipement; break;
      default:            categorie = PropertyCategory.autre;
    }

    final propJson = json['proprietaire'] as Map<String, dynamic>?;
    final proprietaire = propJson != null
        ? UserModel.fromJson({
            ...propJson,
            'telephone':  propJson['telephone']  ?? '',
            'createdAt':  propJson['createdAt']  ?? DateTime.now().toIso8601String(),
            'prenom':     propJson['prenom']      ?? '',
            'nom':        propJson['nom']         ?? '',
            'email':      propJson['email']       ?? '',
          })
        : UserModel(
            id: '', nom: '', prenom: '', email: '',
            telephone: '', createdAt: DateTime.now(),
          );

    // NOTE : dans le schéma Prisma réel, Property.adresse est une simple String?
    // (jamais un objet imbriqué). L'ancien code tentait un cast `as Map`, qui
    // levait une exception dès qu'une vraie annonce avait une adresse renseignée.
    final adresseRaw = json['adresse'];
    final adresse = adresseRaw is Map<String, dynamic>
        ? AddressModel(
            rue:       adresseRaw['rue']       ?? '',
            ville:     adresseRaw['ville']     ?? json['ville'] ?? '',
            pays:      adresseRaw['pays']      ?? 'Togo',
            latitude:  (adresseRaw['latitude']  as num?)?.toDouble(),
            longitude: (adresseRaw['longitude'] as num?)?.toDouble(),
          )
        : AddressModel(
            rue:   adresseRaw as String? ?? '',
            ville: json['ville'] as String? ?? '',
            pays:  json['pays']  as String? ?? 'Togo',
          );

    return PropertyModel(
      id:              json['id']?.toString() ?? '',
      titre:           json['titre']       ?? '',
      description:     json['description'] ?? '',
      type:            type,
      listingType:     listingType,
      categorie:       categorie,
      prix:            (json['prix'] ?? 0).toDouble(),
      prixParJour:     json['prixParJour'],
      images:          (json['images'] as List?)?.cast<String>() ?? [],
      adresse:         adresse,
      proprietaire:    proprietaire,
      caracteristiques:(json['caracteristiques'] as List?)?.cast<String>() ?? [],
      rating:          (json['rating'] ?? 0.0).toDouble(),
      totalAvis:       json['totalAvis'] ?? 0,
      isAvailable:     json['isAvailable'] ?? true,
      isFeatured:      json['isFeatured']  ?? false,
      createdAt:       json['createdAt'] != null
                           ? DateTime.parse(json['createdAt'])
                           : DateTime.now(),
      vues:            json['vues'] ?? 0,
      surface:         json['surface'],
      nombrePieces:    json['nombrePieces'],
      annee:           json['annee'],
      status:          json['status'] ?? 'approuve',
      // ⚠️ Corrigé : ces 3 champs existaient dans le modèle et étaient
      // utilisés par getLocalizedTitre/getLocalizedDescription/
      // getLocalizedCaracteristiques, mais n'étaient jamais lus depuis le
      // JSON — les traductions ne s'affichaient donc jamais, quelle que
      // soit la langue de l'utilisateur. Le backend ne renvoie pas encore
      // ces champs aujourd'hui (voir schema.prisma : colonnes ajoutées mais
      // pas encore peuplées), donc les valeurs resteront `null` tant que
      // cette partie backend n'est pas branchée — mais le parsing est
      // maintenant prêt à les recevoir dès qu'elle le sera.
      titreTranslations: (json['titreTranslations'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), v.toString())),
      descriptionTranslations: (json['descriptionTranslations'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), v.toString())),
      caracteristiquesTranslations: (json['caracteristiquesTranslations'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), (v as List).cast<String>())),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }

  /// Returns localized title (falls back to French)
  String getLocalizedTitre(String lang) =>
      titreTranslations?[lang] ?? titreTranslations?['en'] ?? titre;

  /// Returns localized description (falls back to French)
  String getLocalizedDescription(String lang) =>
      descriptionTranslations?[lang] ?? descriptionTranslations?['en'] ?? description;

  /// Returns localized caracteristiques (falls back to French list)
  List<String> getLocalizedCaracteristiques(String lang) =>
      caracteristiquesTranslations?[lang] ?? caracteristiquesTranslations?['en'] ?? caracteristiques;
}

class AddressModel {
  final String rue;
  final String ville;
  final String pays;
  final double? latitude;
  final double? longitude;

  AddressModel({
    required this.rue,
    required this.ville,
    required this.pays,
    this.latitude,
    this.longitude,
  });

  String get full => '$rue, $ville, $pays';
  String get short => '$ville, $pays';
}

class TransactionModel {
  final String id;
  final PropertyModel property;
  final UserModel client;
  final String type; // 'achat', 'location'
  final double montant;
  final String statut; // 'en_attente', 'confirme', 'annule', 'termine'
  final DateTime dateDebut;
  final DateTime? dateFin;
  final String methode; // 'mobile_money', 'carte', 'paypal'
  final String? paymentRef;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.property,
    required this.client,
    required this.type,
    required this.montant,
    required this.statut,
    required this.dateDebut,
    this.dateFin,
    required this.methode,
    this.paymentRef,
    required this.createdAt,
  });

  String get statutLabel {
    const labels = {
      'en_attente': 'En attente',
      'confirme': 'Confirmé',
      'annule': 'Annulé',
      'termine': 'Terminé',
    };
    return labels[statut] ?? statut;
  }
}

enum MessageStatus { sending, sent, delivered, read, failed }

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime sentAt;
  final bool isRead;
  final String? propertyId;
  final MessageStatus status;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.sentAt,
    this.isRead = false,
    this.propertyId,
    this.status = MessageStatus.sent,
  });

  /// Alias pour le code qui utilise .text
  String get text => content;
  /// Alias pour le code qui utilise .timestamp
  DateTime get timestamp => sentAt;

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    id:         json['id'] ?? '',
    senderId:   json['senderId'] ?? '',
    receiverId: json['receiverId'] ?? '',
    content:    json['text'] ?? json['content'] ?? '',
    sentAt:     json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
        : json['sentAt'] != null
            ? DateTime.tryParse(json['sentAt']) ?? DateTime.now()
            : DateTime.now(),
    isRead:     json['isRead'] ?? false,
    propertyId: json['propertyId'],
  );
}

class AvisModel {
  final String id;
  final UserModel auteur;
  final String cible; // propertyId or userId
  final double note;
  final String commentaire;
  final DateTime createdAt;

  AvisModel({
    required this.id,
    required this.auteur,
    required this.cible,
    required this.note,
    required this.commentaire,
    required this.createdAt,
  });
}