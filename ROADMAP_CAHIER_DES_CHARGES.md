# Conformité au cahier des charges v1.0 (19/10/2026)

Légende : ✅ fait côté app · 🟡 app prête, **dépend du backend** (voir `BACKEND_CHANGES.md`) · ⬜ à faire

| Réf. | Exigence | État | Détail |
|---|---|---|---|
| §10.3 | Le paiement ne donne jamais le statut « vérifié » | ✅ | `isVelqixApproved = fieldVerified` ; Premium retiré du calcul ; « Vedette » → « Mise en avant » |
| §14.3 | Limites des garanties annoncées sans détour | ✅ | Fin des promesses « VelQix s'en charge en cas de fraude » et « Assurance transactions » ; encadré de limites sur chaque annonce |
| §6.4 | Une vérification précise ce qu'elle couvre | ✅ | Date, agent, périmètre et limites (pas une preuve de propriété) affichés ; texte démarcheur corrigé |
| §7.1-7.2 | Statuts de disponibilité + date de l'information | ✅ | `AvailabilityState` (7 états), badge sur les cartes, encadré sur la fiche |
| §7.2 | « Confirmée » uniquement si l'annonceur a confirmé | 🟡 | Sans `lastConfirmedAt` : « Déclaré disponible ». Fenêtre « récemment » = 7 j, à rendre configurable |
| VIS-01 / §6.3 | Demande de confirmation avant visite | 🟡 | Boutons « Demander une confirmation » / « Organiser une visite » ; silence jamais présenté comme confirmation |
| VIS-02 | Accepter, refuser, proposer un autre créneau | 🟡 | Écran Profil → « Visites et confirmations » (onglets Reçues / Envoyées) |
| §5.3 / §7.3 | Mises à jour simples côté annonceur | 🟡 | « Toujours disponible », « Loué », « Vendu » sur la fiche (pas de relance manuelle imposée) |
| SIG-01 / §7.5 | Signalement d'une annonce (6 motifs) | 🟡 | Feuille « Signaler l'annonce » ; pas de sanction automatique sur signalement isolé (règle serveur) |
| §8.1 | Chambres, studios, locaux commerciaux | 🟡 | Ajoutés (publication, filtres accueil, assistant) ; enum Prisma à étendre |
| §4.2 | Lancement centré sur l'immobilier | ✅ | Type « Mobilier » (véhicules) conservé à la publication, à la demande du fondateur |
| SIG-02, ADM-01/02 | Traitement admin des signalements | ⬜ | Onglet admin « Signalements » à créer quand la route `/admin/reports` existera |
| NOT-01 | Notifications de demandes / changements de statut | ⬜ | Envoi par le backend (FCM déjà branché côté app) |
| §7.4 | Expiration / réduction de visibilité | ⬜ | Tâche planifiée serveur ; délais configurables dans l'admin (§15.2) |
| §8.4 | Filtres : fraîcheur, statut de vérification | ⬜ | À ajouter à la recherche (`search_screen.dart`) une fois `availabilityStatus` fourni par l'API |
| §3.7 | Direction visuelle (vert #143D35, or #D5B477…) | ⬜ | Non modifiée : thème actuel bleu #0D47A1 ; le cahier la qualifie de « proposition » à valider avec l'identité définitive |
| §3.4 | Signature « Le réel, sans frontières. » | ⬜ | Proposition de travail, à valider |
| §10.4 / PRO-01,02 | Espace agence, abonnements | ⬜ | Phase ultérieure (P2) |
| GEO-01/02 | Zones de couverture, tarifs par zone | ⬜ | P1 : à faire côté admin |

---

# Cahier des charges VelQix (version précédente) — avancement

Principe retenu : **améliorer l'existant sans changer les menus ni les fonctions actuelles**.

## Fait (phase 1)
| Section du cahier | Réalisation |
|---|---|
| 2 / 4 — Services payants séparés de l'abonnement | Feuille « Demander un service » (vérification, visite accompagnée, entretien), prix affichés, devis, paiement hébergé ; écran « Mes demandes de services » (menu Profil) ; boutons sur la page d'une annonce |
| 5D — Interface démarcheur | « Velqix Agent » : missions avec rémunération visible avant d'accepter, acceptation, rapport (constat + photos), Mes gains (en validation / à recevoir / payé), Disponibilité (zones, horaires) |
| 5E — Interface agent d'entretien | « Velqix Services » : même espace, missions d'entretien, détails (surface, prestation), preuves, gains ; validation / contestation côté client |
| 6 — Administration | Onglet « Opérations & finances » : missions (devis, validation, refus avec preuves), tarifs et rémunérations configurables + simulation de marge, revenus, reversements aux agents, journal d'activité ; nouveaux droits dans la matrice des permissions |
| 4 — Exemple de marge d'une vérification | Reproduit dans l'admin (3 500 F → contribution VelQix ≈ 1 395 F, ≈ 40 %) |
| 7 — Contrat technique | `BACKEND_CHANGES.md` : tables, statuts, routes, règles de sécurité financière |

## À faire (phases suivantes)
1. **Offres Freemium / Premium par profil** (grille : Particulier Plus, Professionnel Premium, Entreprise sur
   devis ; prépayé 6 mois 11 000 F et 1 an 20 000 F) : nécessite `plans` / `subscriptions` côté API ; l'écran
   Premium actuel ne gère qu'une formule (2 000 F / 30 jours).
2. **Espace Entreprise** : portefeuille de biens, équipe et rôles (administrateur, gestionnaire, commercial,
   comptable), suivi des prospects, rapports et factures exportables.
3. **Espace Professionnel** : tableau de bord prospects / visites, statistiques de consultation détaillées,
   archivage des annonces.
4. **Séparer profil et rôles** (une même personne : propriétaire ET professionnel, plusieurs espaces sans
   plusieurs comptes).
5. Mise en avant payante à l'unité / crédits, alertes personnalisées, remise Premium appliquée aux prix
   affichés, coordonnées GPS dans le rapport terrain, indicateurs mensuels dans le tableau de bord admin.
