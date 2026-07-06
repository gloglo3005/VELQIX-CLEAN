import '../models/models.dart';

class MockDataService {
  static final UserModel currentUser = UserModel(
    id: 'u1',
    nom: 'Kofi',
    prenom: 'Ama',
    email: 'ama.kofi@example.com',
    telephone: '+228 90 12 34 56',
    isVerified: false,
    rating: 4.8,
    totalAvis: 23,
    createdAt: DateTime(2023, 6, 15),
    role: 'proprietaire',
    isPremium: false,
  );

  // ✅ Compte admin par défaut
  static final UserModel adminUser = UserModel(
    id: 'admin_1',
    nom: 'Admin',
    prenom: 'VelQix',
    email: 'admin@innorent.tg',
    telephone: '+228 90 00 00 00',
    isVerified: true,
    rating: 5.0,
    totalAvis: 0,
    createdAt: DateTime(2023, 1, 1),
    role: 'admin',
    isPremium: true,
  );

  // Liste des utilisateurs (vide — remplie via inscription)
  static final List<UserModel> users = [
    currentUser,
  ];

  // Liste des propriétés (vide — remplie via les annonces soumises)
  static List<PropertyModel> get properties => [];

  // Liste des transactions (vide)
  static List<TransactionModel> get myTransactions => [];

  // Liste des avis (vide)
  static List<AvisModel> get avis => [];

  // Notifications (vide)
  static final List<Map<String, dynamic>> notifications = [];
}