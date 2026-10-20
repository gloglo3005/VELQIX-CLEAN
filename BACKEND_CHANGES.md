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
- **Approuvée par VelQix** = un **démarcheur VelQix** a vérifié le bien
  sur le terrain. En cas de fraude, VelQix s'en charge.
- **Non approuvée** = tout le reste. En cas de fraude, VelQix ne s'en mêle pas.
(À ne pas confondre avec `status` : `en_attente / approuve / rejete` = modération admin avant publication.)

**Règle du cahier des charges : le Premium ne signifie PAS « bien vérifié ».** L'app calcule
`isVelqixApproved = fieldVerified` (vérification terrain réellement effectuée et validée).

## Champs à renvoyer dans toutes les réponses d'annonces
`fieldVerified` (bool), `fieldVerifiedAt` (ISO), `fieldVerifiedByName` (string, nom du démarcheur),
`verificationRequested` (bool).

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

# Phase 2 du cahier des charges : formules, espaces Pro / Business

> **Règle mise à jour** : le **Premium ne rend PAS un bien « vérifié »**. Seule une vérification terrain
> réellement effectuée et validée donne `fieldVerified = true` (voir plus haut). Ne jamais déduire
> « approuvée » du statut Premium du propriétaire.

## Formules (Freemium / Premium par profil)
| Route | Rôle |
|---|---|
| `GET /plans` (public) | `[ { id, audience: particulier\|professionnel\|entreprise, name, tagline, premium, priceMonthly?, price6Months?, price1Year? } ]`. `premium: true` sans `priceMonthly` = « sur devis ». Valeurs de lancement : Particulier Plus 2 000 F/mois ; Professionnel Premium 2 000 F/mois, 6 mois 11 000 F, 1 an 20 000 F ; Entreprise Premium sur devis. **Pas de formule 5 ans.** Les plafonds (annonces, collaborateurs, crédits de mise en avant) viennent de `/admin/pricing`. |
| `POST /subscriptions/checkout` | `{ planId, period: month\|6months\|year }` → `{ checkoutUrl }` (le prix est lu côté serveur, jamais dans la requête) |
| `POST /subscriptions/quote-request` | `{ planId, message }` (Entreprise Premium) |
| `GET /subscriptions/me` | `{ planName, status: actif\|expire\|aucun, expiresAt }` |
| `GET /me/invoices` | `[ { id, label, date, amount, url? } ]` |

## Profil ≠ rôles : plusieurs espaces pour un même compte
| Route | Rôle |
|---|---|
| `GET /me/spaces` | `{ pro: bool, business: bool, businessName?, businessRole? }` |
| `POST /me/spaces/pro` | `{ activity: agent_immobilier\|demarcheur_independant\|commercial\|vendeur\|autre }` (gratuit, immédiat) |
| `POST /me/spaces/business` | `{ name }` : crée l'entreprise, le demandeur en devient `administrateur` |

## Velqix Pro (accès : `spaces.pro`)
| Route | Rôle |
|---|---|
| `GET /pro/dashboard` | `{ activeListings, views, contacts, pendingRequests, visitsPlanned, verified }` |
| `GET /pro/leads` | `[ { id, name, phone, propertyTitle, message, status, createdAt } ]` |
| `PUT /pro/leads/:id` | `{ status: nouveau\|contacte\|visite\|conclu\|perdu }` |

## Velqix Business (rôles : administrateur, gestionnaire, commercial, comptable)
| Route | Qui |
|---|---|
| `GET /business/overview` | tous : `{ listings, members, views, contacts, verifiedProperties, pendingVerifications }` |
| `GET /business/properties` | administrateur, gestionnaire (tous) ; commercial (ses annonces attribuées) : `[ { id, titre, assignedTo, views, verified } ]` |
| `PUT /business/properties/:id/assign` | administrateur, gestionnaire : `{ userId }` |
| `GET /business/team` | administrateur, gestionnaire |
| `POST /business/team` | administrateur : `{ email, role }` (compte VelQix existant) |
| `PUT /business/team/:id` / `DELETE /business/team/:id` | administrateur |
| `GET /business/reports?period=7d\|30d\|90d` | administrateur, gestionnaire, comptable : `{ listings, views, contacts, visits, verificationsDone, verifications:[{title,date,status}] }` |
| `GET /business/reports/export?period=&format=csv` | idem : `{ url }` |

Rappel : l'app masque onglets et boutons selon le rôle, mais **le serveur doit refuser** toute route
interdite au rôle de l'appelant. L'accès aux fonctions financières reste réservé aux personnes autorisées.
