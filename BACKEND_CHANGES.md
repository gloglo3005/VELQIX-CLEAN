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

# Annonces « vérifiées sur le terrain » vs « non vérifiées »

> ⚠️ **Règle modifiée (cahier des charges v1.0, §10.3 et §14.3).** Le statut Premium ne rend plus une annonce
> « approuvée ». Seule une vérification terrain validée donne `fieldVerified = true`. VelQix ne promet plus de
> « prendre en charge » les fraudes. Les mentions ci-dessous à « Premium OU démarcheur » sont obsolètes.

Règle métier :
- **Approuvée par VelQix** = le propriétaire est **Premium** OU un **démarcheur VelQix** a vérifié le bien
  sur le terrain. En cas de fraude, VelQix s'en charge.
- **Non approuvée** = tout le reste. En cas de fraude, VelQix ne s'en mêle pas.
(À ne pas confondre avec `status` : `en_attente / approuve / rejete` = modération admin avant publication.)

L'app calcule désormais `isVelqixApproved = fieldVerified` (le Premium n'entre plus dans le calcul).

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

---

# Cahier des charges « Velqix — modèle économique et interfaces » : phase 1

Principe : la publication d'annonces reste gratuite ; vérifications, visites accompagnées et entretien
sont des **missions payantes à la prestation**, séparées de l'abonnement. Toute règle (prix, droits,
paiement, rémunération) est appliquée **côté serveur** ; l'app ne fait qu'afficher.

> Cette section REMPLACE les routes de vérification décrites plus haut
> (`/properties/:id/verification-request`, `/demarcheur/verifications`, `/demarcheur/properties/:id/verify`) :
> une vérification terrain est maintenant une mission de type `verification`. Quand elle est **validée**,
> le serveur met `fieldVerified = true`, `fieldVerifiedAt`, `fieldVerifiedByName` sur l'annonce.

## Tables (base de données)
| Table | Contenu |
|---|---|
| `plans` | offres Freemium / Premium par profil : prix, durée, limites (annonces, photos, crédits de mise en avant) |
| `subscriptions` | formule active d'un utilisateur : dates, statut |
| `payments` | tous les paiements : référence UNIQUE, montant, frais, statut, échec, remboursement, `purpose` (`premium` / `mission`) |
| `missions` | type, statut, client, bien, adresse, zone, `price`, `agentPay`, `transport`, `paymentStatus`, `payoutStatus`, agent, `details`, `notes`, `evidence[]`, `reportNote`, dates |
| `agent_payouts` | sommes dues aux agents : mission, agent, montant, statut (`en_attente` → `du` → `paye`), corrections |
| `audit_logs` | qui / quoi / quand / détails : changement de tarif, validation manuelle de paiement, remboursement, changement de rémunération, versement |
| `settings` (ou `pricing`) | tarifs et commissions modifiables depuis l'admin (voir `/admin/pricing`) |

## Statuts d'une mission
`devis` → `devis_propose` → `attente_paiement` → `disponible` → `acceptee` → `rapport_soumis` → `validee`
(+ `contestee`, `rejetee` = rapport refusé, à corriger, `annulee`). Vérification : prix fixe → démarre à
`attente_paiement`. Visite / entretien : démarre à `devis` ; l'admin fixe le devis ; le client l'accepte en payant.

## Routes client (utilisateur connecté)
| Route | Rôle |
|---|---|
| `GET /pricing` (public) | `{ verification: {price, agentPay, transport}, visite: {}, entretien: {} }` — `price` absent = « sur devis » |
| `POST /missions` | `{ type, propertyId?, address?, notes?, details? }` → mission (avec `price` pour une vérification) |
| `GET /missions/mine` | demandes du client |
| `POST /missions/:id/checkout` | accepte le devis si besoin et renvoie `{ checkoutUrl }` (FedaPay, comme `/premium/checkout`) |
| `POST /missions/:id/cancel` | annulation tant que non payée |
| `POST /missions/:id/confirm` | le client valide la prestation d'entretien |
| `POST /missions/:id/dispute` | `{ reason }` → statut `contestee` |

Le **montant est toujours recalculé par le serveur** (jamais pris dans la requête). Remise Premium éventuelle
(`premiumDiscountPercent`) à appliquer ici, seulement si la marge reste suffisante.

## Routes démarcheur / agent d'entretien (`role` = `demarcheur` ou `agent_entretien`)
| Route | Rôle |
|---|---|
| `GET /agent/missions?scope=available\|mine\|done` | `available` : missions payées, non assignées, dans les zones/disponibilité de l'agent, **du bon type pour son rôle** (démarcheur : verification + visite ; agent d'entretien : entretien). `mine` : missions de l'agent |
| `POST /agent/missions/:id/accept` | assignation atomique (refuser si déjà prise) |
| `POST /agent/missions/:id/report` | `{ checklist, evidence[] (URLs de photos), note? }` → `rapport_soumis` |
| `GET /agent/earnings` | `{ pending, due, paid, items:[{ title, amount, status: en_attente\|du\|paye, date }] }` |
| `GET/PUT /agent/availability` | `{ available, zones, hours }` |

- **Rémunération** (`agentPay`, `transport`) visible avant l'acceptation. Ne PAS renvoyer les coordonnées du
  client / propriétaire (`contactName`, `contactPhone`) tant que la mission n'est pas acceptée par cet agent.
- Aucun abonnement requis pour un agent.

## Routes admin (permissions `missions.manage`, `pricing.manage`, `finance.view`, `finance.payouts`, `audit.view`)
| Route | Rôle |
|---|---|
| `GET /admin/missions?status=` | toutes les missions (avec `evidence`, `reportNote`, `clientName`) |
| `PUT /admin/missions/:id/quote` | `{ price, agentPay, transport }` → `devis_propose` |
| `POST /admin/missions/:id/validate` | `validee` ; crée le `agent_payout` (statut `du`) ; vérification → met à jour l'annonce |
| `POST /admin/missions/:id/reject` | `{ reason }` → `rejetee` (motif visible par l'agent) |
| `GET/PUT /admin/pricing` | clés : `verificationPrice`, `verificationAgentPay`, `verificationTransport`, `supportCost`, `paymentFeePercent`, `servicesFeePercent`, `premiumDiscountPercent`, `premiumMonthly`, `premium6Months`, `premium1Year`, `freeMaxListings`, `premiumMaxListings`, `premiumFeaturedCredits` (PUT = valeurs modifiées seulement) |
| `GET /admin/finance/summary` | `collected, missionsRevenue, subscriptionsRevenue, adsRevenue, commissions, dueToAgents, paidToAgents, refunds, profit` |
| `GET /admin/payouts?status=du\|paye\|en_attente` | `[ { id, agentName, missionTitle, amount, status } ]` |
| `POST /admin/payouts/:id/pay` | marque payé (action journalisée, non annulable) |
| `GET /admin/audit-logs?limit=100` | `[ { action, actorName, createdAt, details } ]` |

Chaque action de ce tableau qui modifie des tarifs ou de l'argent doit écrire dans `audit_logs`.

## Règles de sécurité financière (extraites du cahier des charges)
- Le serveur **confirme** chaque paiement auprès du prestataire (webhook + vérification), jamais sur la seule
  foi de l'app.
- Référence de transaction **unique** ; les notifications de paiement répétées ne créent pas de doublon
  (idempotence).
- Paiement d'un agent déclenché uniquement après validation ; remboursements / contestations enregistrés
  **sans effacer** l'historique.
- Droits vérifiés **côté serveur** sur chaque route (masquer un bouton ne suffit pas).
- Distinguer chiffre d'affaires, sommes dues aux agents, fonds encaissés et bénéfice. Si VelQix encaisse pour
  le compte d'agents, valider les modalités de détention / reversement avec FedaPay et la réglementation du Togo.

## Rôles
Nouveaux droits dans le catalogue : `missions.manage`, `pricing.manage`, `finance.view`, `finance.payouts`,
`audit.view`. Un démarcheur a déjà `properties.verify_field` ; un agent d'entretien n'a besoin que de `chat.use`.

---

# Cahier des charges v1.0 (19/10/2026) — disponibilité, visites, signalements

Principe (§7.1) : une annonce publiée n'est jamais assimilée à un bien disponible. Toutes les règles sont
appliquées **côté serveur** (§8.5 : un client ne doit pas pouvoir forcer un statut protégé).

## 1. Champs à renvoyer dans toutes les réponses d'annonces
| Champ | Type | Rôle |
|---|---|---|
| `availabilityStatus` | string | `available` \| `pending` \| `unavailable` (loué / vendu) \| `suspended` \| `archived` |
| `lastConfirmedAt` | ISO date | Date de la dernière confirmation de disponibilité par l'annonceur |
| `updatedAt` | ISO date | Déjà lu par l'app ; sert de date de déclaration si `lastConfirmedAt` est absent |

Sans `lastConfirmedAt`, l'app affiche « Déclaré disponible » (jamais « confirmé »). Au-delà de `freshnessDays`
(7 par défaut, `PropertyModel.freshnessDays`) l'app affiche « Disponibilité à reconfirmer ». **À rendre
configurable côté admin** (§7.2, §15.2) et à exposer par `GET /config/availability` si besoin.

## 2. Catégories (§8.1)
Ajouter à l'enum `categorie` : `chambre`, `studio`, `local_commercial` (valeur envoyée par l'app pour « Local
commercial »). Les valeurs `hotel`, `entrepot`, `voiture`, `moto`, `camion`, `equipement`, `autre` restent
lisibles mais l'app ne les propose plus à la **création**. Recommandé : refuser les véhicules sur `POST /properties`.

## 3. Demandes de confirmation et de visite (VIS-01, VIS-02, NOT-01)
| Route | Qui | Rôle |
|---|---|---|
| `POST /properties/:id/availability-requests` | utilisateur connecté | Body `{ type: 'confirmation' \| 'visit', desiredSlot?: ISO, note? }`. Crée la demande `pending`, notifie l'annonceur (push / e-mail / SMS). Limiter les doublons et le spam (ex. 1 demande ouverte par utilisateur et par annonce). |
| `GET /availability-requests/mine` | demandeur | Ses demandes. |
| `GET /availability-requests/received` | annonceur | Demandes sur ses annonces (liste vide si aucune). |
| `PUT /availability-requests/:id/respond` | **propriétaire de l'annonce uniquement** | Body `{ response: 'available' \| 'unavailable' \| 'propose_slot', proposedSlot?: ISO, note? }`. `available` → met `lastConfirmedAt = now` et écrit un événement d'historique ; `unavailable` → `availabilityStatus = 'unavailable'` ; `propose_slot` → statut `slot_proposed`. Notifie le demandeur. |

Objet renvoyé : `{ id, propertyId, propertyTitle (ou property.titre), type, status, requesterName (ou requester.{prenom,nom}), note, desiredSlot, proposedSlot, responseNote, createdAt, respondedAt }`
avec `status` ∈ `pending | available | unavailable | slot_proposed | expired | cancelled`.

**Expiration (§6.3, §7.4)** : une tâche planifiée passe les demandes sans réponse à `expired` après un délai
**configurable** (cible à tester : 30 à 60 min pour une visite). Le silence n'est jamais traité comme une
confirmation. Ensuite, selon la politique : avertissement de fraîcheur → nouvelle demande de confirmation →
réduction de visibilité → suspension / archivage (pas de suppression immédiate).

## 4. Déclaration simple par l'annonceur (§5.3, §7.3)
`POST /properties/:id/availability` — propriétaire uniquement. Body `{ status: 'available' | 'rented' | 'sold' | 'unavailable' }`.
- `available` : `lastConfirmedAt = now`, `availabilityStatus = 'available'` ;
- `rented` / `sold` / `unavailable` : `availabilityStatus = 'unavailable'` et retrait des résultats actifs ;
- chaque appel écrit une ligne d'historique (ANN-06 : auteur, date, résultat, canal) — ne jamais écraser l'historique.
Ne PAS imposer à l'annonceur une confirmation manuelle tous les 2-3 jours (§5.3) : rappels périodiques raisonnables seulement.

## 5. Signalements (SIG-01, SIG-02)
`POST /properties/:id/reports` — utilisateur connecté. Body `{ reason, details? }` avec `reason` ∈
`already_rented | not_found | misleading | wrong_price | suspicious_advertiser | wrong_info_or_images`.
- Un signalement **isolé** ne sanctionne pas automatiquement (§7.5). Plusieurs signalements **indépendants et
  concordants** (comptes distincts) peuvent suspendre temporairement l'annonce (`availabilityStatus = 'suspended'`).
- Limiter les abus de signalement (1 par utilisateur et par annonce, quota quotidien) — risque listé au §14.1.
- File de traitement admin : évaluer le risque, demander des précisions, décision proportionnée, trace de la
  résolution, canal de contestation (§14.2). Journaliser dans `audit_logs`.

## 6. Mise en avant payante (§10.3)
`isFeatured` ne doit **jamais** modifier `fieldVerified`, `availabilityStatus` ni `lastConfirmedAt`. L'app libelle
désormais ces annonces « Mise en avant » (et non « Vedette ») et le Premium ne donne plus le statut vérifié.
Le tri des résultats doit conserver une logique de pertinence et de confiance.

## 7. Cohérence des promesses commerciales
L'écran Premium ne promet plus « Assurance transactions / protection contre les litiges » ni « réponse garantie ».
Le backend ne doit pas non plus présenter d'assurance ou de garantie de transaction tant que ce n'est pas défini
juridiquement (§14.3, §22 : structure juridique et contrats à vérifier).

