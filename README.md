# VelQix — application Flutter

Plateforme de location et de vente de biens (immobilier, véhicules, mobilier) pour
l'Afrique de l'Ouest. Application Flutter (Android, web, Windows) connectée à
l'API `velqix-backend`.

## Fonctionnalités

- **Compte** : inscription, connexion email / Google / Facebook, mot de passe
  oublié, rôles client, propriétaire et admin, comptes entreprise.
- **Annonces** : publication (photos, vidéo) avec validation par la modération,
  recherche, filtres, favoris, avis et notes, suivi des propriétaires.
- **Messagerie temps réel** (Socket.IO) : texte, vocal, notifications.
- **Appels audio et vidéo** (Agora) avec notification d'appel entrant (FCM).
- **Premium** : abonnement payé via FedaPay. Le statut Premium vient toujours du
  serveur (webhook FedaPay), jamais d'une valeur locale.
- **VelqIA** : assistant IA (Gemini côté serveur) pour trouver un bien et
  répondre aux questions sur la plateforme. Bouton flottant présent sur les
  onglets principaux, saisie vocale à la demande.
- **Tableau de bord admin** : modération des annonces, utilisateurs, statistiques.
- 6 langues (fr, en, es, pt, de, ar), 4 devises, mode sombre.

## Prérequis

- Flutter stable (SDK Dart `>=3.0.0 <4.0.0`)
- Un backend VelQix joignable (par défaut `https://velqix.onrender.com/api`)

## Lancer en développement

```powershell
flutter pub get

# API de production (valeur par défaut)
flutter run -d chrome

# API locale
flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api
```

`API_URL` doit se terminer par `/api` : l'adresse WebSocket en est déduite.

## Builds

```powershell
# Web (déployé sur Vercel via vercel-build.sh)
flutter build web --release

# Android
flutter build apk --release
flutter build appbundle --release
```

### Signature Android

La release est signée avec `android\key.properties` s'il existe, sinon avec la
clé debug (build local possible, publication Play Store impossible).

1. Générer la clé : voir les commandes dans `android\key.properties.example`.
2. Copier `android\key.properties.example` en `android\key.properties` et le
   renseigner. Ce fichier et les `.jks` sont ignorés par git.

### Firebase (notifications push)

`android\app\google-services.json` doit être celui d'une application Android
Firebase dont le nom de package est **identique** à `applicationId`
(`com.example.velqix`). Un package différent fait échouer le build Android.

## Cohérence avec le backend

| Sujet | Contrat |
| --- | --- |
| Format des réponses | `{ success, data, message, error }` |
| Session | `401 TOKEN_EXPIRED` → refresh automatique ; `401/403` au refresh ou `403 ACCOUNT_BANNED` → session fermée |
| Tarif Premium | `GET /api/premium/plan` (repli local : 2000 FCFA / 30 jours) |
| Statut Premium | `GET /api/auth/me` et `GET /api/premium/status` |
| Assistant IA | `POST /api/ai/chat` `{ message, history }` → `{ data: { text, properties } }`, `503 GEMINI_UNAVAILABLE` si le modèle est surchargé |
| Appels | `GET /api/calls/agora-token?channelName=…` (App ID Agora de repli dans l'app) |

## Tests

```powershell
flutter test
flutter analyze
```

## Structure

```
lib/
  main.dart            point d'entrée, thème, langue, devise, Firebase
  models/              modèles de données
  screens/             écrans (MainShell héberge les onglets et VelqIA)
  services/            API, auth, chat, notifications, traductions, tarif Premium
  theme/               thème clair / sombre
  widgets/             composants partagés et assistant IA
```
