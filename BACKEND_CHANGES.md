# Changements requis côté API (pour le développeur backend)

Le frontend Flutter attend les évolutions suivantes.

## 1. Nouvelle catégorie de bien : `hotel`
- Ajouter `hotel` à l'enum `categorie` (Prisma) et l'accepter dans `POST/PUT /properties`.
- Catégories désormais proposées : immobilier = maison, appartement, hotel, terrain, bureau, entrepot ;
  mobilier (véhicules) = voiture, moto, camion.
- Recommandé : refuser `equipement` et `autre` pour les NOUVELLES annonces (les anciennes restent lisibles).

## 2. Nouveaux rôles : `demarcheur` et `agent_entretien`
- Valeurs possibles de `User.role` (en plus de client / proprietaire / admin).
- `POST /auth/register` doit IGNORER tout champ `role` envoyé par le client.

## 3. `POST /admin/staff` (admin uniquement)
Body : `{ role: 'demarcheur' | 'agent_entretien', prenom, nom, telephone, email, password, username? }`
- Crée l'utilisateur (mot de passe haché, compte vérifié) ; réponse `{ success: true, data: <user> }`.
- Erreur 409 si e-mail / username déjà utilisé : `{ success: false, message }`.

## 4. `GET /users/staff?role=` (utilisateur connecté)
- Retourne `{ success: true, data: [ { id, nom, prenom, telephone, avatarUrl, role, countryName, isVerified, createdAt } ] }`
  filtré sur les rôles `demarcheur` / `agent_entretien` (filtre `role` optionnel).
- Le téléphone doit être renvoyé : ces profils sont faits pour être contactés.

## 5. `GET /admin/users`
- Doit renvoyer les nouveaux rôles (utilisés par l'onglet « Équipe » du tableau de bord).

---

# Console d'administration (utilisateurs, annonces, rôles, permissions)

Nouvelles routes attendues par l'onglet admin (toutes réservées au rôle `admin`) :

| Route | Rôle côté app |
|---|---|
| `GET /admin/users?limit=500` | Liste complète (le filtrage/recherche est fait côté app). Doit inclure `role`, `isVerified`, **`isActive`**. |
| `PUT /admin/users/:id` | Body partiel `{ role?, isVerified?, isActive? }`. Interdire à un admin de se rétrograder / suspendre lui-même. |
| `DELETE /admin/users/:id` | Suppression d'un compte. |
| `GET /admin/properties?limit=500` | Toutes les annonces, tous statuts (`en_attente`, `approuve`, `rejete`). Sans cette route, l'onglet « Annonces » affiche une liste partielle avec un avertissement. |
| `DELETE /admin/properties/:id` | Suppression d'une annonce. |
| `PUT /admin/properties/:id/approve` / `/reject` | Déjà utilisées. |
| `GET /admin/roles` | `{ success, data: { client: ['chat.use', …], proprietaire: [...], demarcheur: [...], agent_entretien: [...], admin: [...] } }` |
| `PUT /admin/roles/:role` | Body `{ permissions: ['key', …] }`. |

Clés de permissions utilisées : `stats.view`, `users.view`, `users.edit`, `users.delete`,
`users.create_staff`, `roles.manage`, `properties.create`, `properties.moderate`,
`properties.edit`, `properties.delete`, `disputes.manage`, `chat.use`.

⚠️ Le tableau « Rôles & permissions » ne fait que CONFIGURER. L'API doit vérifier ces
permissions sur chaque route (middleware), et refuser la connexion si `isActive == false`.
