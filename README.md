# 🏠 InnoRent – Plateforme de Location & Vente

Application Flutter complète pour la location et vente de biens mobiliers et immobiliers.

## 📱 Fonctionnalités implémentées

### ✅ Authentification
- Onboarding animé (3 slides)
- Connexion (email/téléphone + mot de passe)
- Inscription avec choix de rôle (client / propriétaire)
- Connexion sociale (Google, Facebook – UI)

### ✅ Accueil
- Annonces vedettes (carrousel horizontal)
- Filtres par catégorie (Maisons, Voitures, etc.)
- Barre de recherche rapide
- Statistiques rapides (Annonces, Mobilier, Immobilier)

### ✅ Explorer
- Recherche full-text (titre, ville, catégorie)
- Tri : Récent, Prix ↑↓, Note
- Filtres avancés (fourchette de prix, disponibilité)
- Onglets : Tous / Immobilier / Mobilier

### ✅ Détail d'un bien
- Galerie photos (swipeable)
- Caractéristiques
- Description complète
- Fiche propriétaire
- Avis et notes
- CTA : Réserver / Acheter

### ✅ Paiement
- Mobile Money (Flooz, T-Money, MTN MoMo)
- Carte bancaire (Visa, Mastercard)
- PayPal
- Sélection de dates pour locations
- Confirmation animée

### ✅ Messagerie
- Liste des conversations
- Chat en temps réel (simulé)
- Indicateur non-lus

### ✅ Profil
- Stats utilisateur (annonces, note, avis)
- Badge Premium + Vérifié
- Historique des transactions
- Menu paramètres complet
- Déconnexion

### ✅ Publier une annonce
- Formulaire en 3 étapes
- Sélection type de bien (immobilier/mobilier)
- Sélection catégorie
- Upload photos (UI)
- Validation et soumission

## 🚀 Installation & Démarrage

### Prérequis
- Flutter SDK ≥ 3.0.0
- Dart ≥ 3.0.0
- Android Studio / VS Code
- Android Emulator ou appareil physique

### Étapes

```bash
# 1. Cloner ou extraire le projet
cd innorent

# 2. Installer les dépendances
flutter pub get

# 3. Lancer l'application
flutter run

# Pour un build release Android
flutter build apk --release
```

## 📁 Structure du projet

```
lib/
├── main.dart                   # Point d'entrée
├── theme/
│   └── app_theme.dart          # Thème, couleurs, typographie
├── models/
│   └── models.dart             # UserModel, PropertyModel, etc.
├── services/
│   └── mock_data.dart          # Données de démonstration
├── widgets/
│   └── widgets.dart            # Composants réutilisables
└── screens/
    ├── auth_screens.dart       # Onboarding, Login, Register
    ├── main_shell.dart         # Navigation principale
    ├── home_screen.dart        # Accueil
    ├── explore_screen.dart     # Recherche & filtres
    ├── property_detail_screen.dart  # Détail d'un bien
    ├── payment_screen.dart     # Paiement
    ├── add_listing_screen.dart # Publier une annonce
    ├── messages_screen.dart    # Messagerie
    └── profile_screen.dart     # Profil utilisateur
```

## 🎨 Design System
- **Couleurs** : Bleu primaire #0D47A1, Orange accent #FF6F00
- **Typographie** : Google Fonts Poppins
- **Composants** : Cards, Boutons, Champs de formulaire personnalisés

## 🔌 Intégration Backend (À faire)
- Connecter à une API REST (Node.js / Django / Laravel)
- Firebase Authentication pour la vraie auth
- Stripe / Campay / FedaPay pour les paiements Mobile Money
- Firebase Cloud Messaging pour les notifications push
- Google Maps pour la géolocalisation

## 🌍 Adapté pour l'Afrique de l'Ouest
- Monnaie FCFA
- Mobile Money (Flooz, T-Money, MTN MoMo)
- Interface en français
- Données de démo situées à Lomé, Togo
