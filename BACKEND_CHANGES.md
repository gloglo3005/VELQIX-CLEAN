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

---

# Mots de passe : réinitialisation par l'admin + hachage Argon2id

## `POST /admin/users/:id/reset-password` (admin uniquement)
Body : `{ newPassword: string (≥ 10 car.), mustChangePassword: true }`
- Hacher `newPassword` avec **Argon2id** (jamais de stockage ni de log en clair).
- Mettre `mustChangePassword = true` sur l'utilisateur et le renvoyer dans les réponses
  `/auth/login` et `/auth/me` (`"mustChangePassword": true`) : l'app force alors un
  changement de mot de passe avant d'entrer (via `PUT /auth/password`, qui doit remettre le flag à `false`).
- **Invalider les sessions / refresh tokens** existants de cet utilisateur.
- Interdire à un admin de réinitialiser son propre compte par cette route.
- Journaliser l'action (qui, quand, quel compte) sans enregistrer le mot de passe.

## Argon2id
Le hachage se fait UNIQUEMENT côté API (le client Flutter envoie le mot de passe en HTTPS,
jamais de hachage côté app). Paramètres recommandés par l'OWASP : Argon2id,
mémoire 19 MiB, 2 itérations, parallélisme 1 (ou 46 MiB / 1 itération / 1) ; sel aléatoire
unique par mot de passe (géré par la bibliothèque).

Exemple Node.js (si l'API est en Node) — `npm i argon2` :

```js
const argon2 = require('argon2');
const OPTS = { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 };

const hashPassword = (plain) => argon2.hash(plain, OPTS);

// Connexion — avec migration progressive depuis bcrypt
async function verifyAndUpgrade(user, plain) {
  if (user.passwordHash.startsWith('$argon2')) {
    const ok = await argon2.verify(user.passwordHash, plain);
    if (ok && argon2.needsRehash(user.passwordHash, OPTS)) {
      await saveHash(user.id, await hashPassword(plain));
    }
    return ok;
  }
  // Ancien hash (ex. bcrypt) : vérifier, puis re-hacher en Argon2id
  const ok = await require('bcrypt').compare(plain, user.passwordHash);
  if (ok) await saveHash(user.id, await hashPassword(plain));
  return ok;
}
```

À appliquer partout où un mot de passe est créé : inscription, `PUT /auth/password`,
`/auth/reset-password` (mot de passe oublié), `POST /admin/staff` et `POST /admin/users/:id/reset-password`.

---

# Vidéo d'annonce — points à vérifier côté API

Le formulaire envoie la vidéo à `POST /upload/video` (multipart, champ `file`, réponse
`{ success, data: { url } }`), puis ajoute `videoUrl` dans `POST /properties` / `PUT /properties/:id`.
Pour que la vidéo apparaisse sur la plateforme, l'API doit :
- accepter et **enregistrer** `videoUrl` (colonne / champ sur l'annonce) à la création ET à la modification ;
- **renvoyer** `videoUrl` dans `POST /properties`, `GET /properties`, `GET /properties/:id`,
  `GET /admin/properties/pending` et `GET /admin/properties` ;
- accepter les formats mp4, mov, webm, 3gp, m4v (taille max 30 Mo côté app).
Si le serveur ne renvoie pas `videoUrl` après la création, l'app affiche maintenant un avertissement.

---

# Annonces « approuvées par VelQix » vs « non approuvées »

Règle métier :
- **Approuvée par VelQix** = le propriétaire est **Premium** OU un **démarcheur VelQix** a vérifié le bien
  sur le terrain. En cas de fraude, VelQix s'en charge.
- **Non approuvée** = tout le reste. En cas de fraude, VelQix ne s'en mêle pas.
(À ne pas confondre avec `status` : `en_attente / approuve / rejete` = modération admin avant publication.)

L'app calcule `isVelqixApproved = fieldVerified || proprietaire.isPremium`.

## Champs à renvoyer dans toutes les réponses d'annonces
`fieldVerified` (bool), `fieldVerifiedAt` (ISO), `fieldVerifiedByName` (string, nom du démarcheur),
`verificationRequested` (bool). `proprietaire.isPremium` doit être présent et à jour (Premium expiré = plus approuvé).

## Routes
| Route | Qui | Rôle |
|---|---|---|
| `POST /properties/:id/verification-request` | propriétaire du bien | Demande la vérification terrain (`verificationRequested = true`). |
| `GET /demarcheur/verifications?scope=requested\|all\|mine` | demarcheur, admin | `requested` : demandes des propriétaires ; `all` : annonces non vérifiées ; `mine` : vérifiées par l'appelant. Renvoie des annonces avec `proprietaire.telephone`. |
| `POST /demarcheur/properties/:id/verify` | demarcheur, admin | Body `{ checklist: { exists, photosMatch, ownerIdentified }, note? }`. Les 3 cases doivent être `true`. Met `fieldVerified = true`, `fieldVerifiedAt`, enregistre le démarcheur et la note. |

Permission : `properties.verify_field` (accordée au rôle `demarcheur` par défaut).

## Recommandations
- Journaliser chaque vérification (démarcheur, date, note, checklist) : preuve en cas de litige.
- Si le propriétaire modifie l'adresse ou les photos d'un bien vérifié, remettre `fieldVerified = false`.
- Prévoir une route admin pour **révoquer** une vérification (ex. `PUT /admin/properties/:id` avec `fieldVerified: false`).
- Définir dans les CGU les conditions exactes de la prise en charge en cas de fraude : l'app l'annonce
  telle quelle (« En cas de fraude, VelQix s'en charge »).
