# Cahier des charges VelQix — avancement

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

## Fait (phase 2)
| Section du cahier | Réalisation |
|---|---|
| Règle importante | Le Premium ne signifie plus « bien vérifié » : une annonce n'est « approuvée par VelQix » que si la vérification terrain a été effectuée et validée (badges, avertissement avant le chat, textes, documentation) |
| 2 / 3 — Freemium / Premium, grille tarifaire | Écran « Formules et tarifs » (lien depuis Premium et « Mes espaces ») : particuliers, professionnels, entreprises ; 6 mois 11 000 F et 1 an 20 000 F avec économie affichée ; Entreprise Premium sur devis ; matrice des fonctionnalités ; pas de formule 5 ans |
| 1 / 5 — Profil ≠ rôles | « Mes espaces » (menu Profil) : un compte, plusieurs espaces (personnel, Velqix Pro, Velqix Business) |
| 5C — Velqix Pro | Tableau de bord, prospects (statuts : nouveau → contacté → visite → conclu / perdu), raccourcis publier / modifier / archiver / vérifications, abonnement et factures |
| 5B — Velqix Business | Vue d'ensemble, portefeuille avec attribution aux collaborateurs, équipe et rôles (administrateur, gestionnaire, commercial, comptable), rapports avec export, historique des vérifications, factures ; onglets selon le rôle |

## À faire (phases suivantes)
1. Appliquer la remise Premium sur le prix des prestations affiché au client (la valeur est configurable côté admin).
2. Mise en avant payante à l'unité / crédits de visibilité, alertes personnalisées Premium.
3. Indicateurs mensuels dans le tableau de bord admin (conversion Premium, coût réel d'une vérification,
   marge par mission, délais de prise en charge et de paiement, missions annulées ou contestées).
4. Coordonnées GPS dans le rapport terrain.
5. Choix du type de profil (Particulier / Professionnel / Entreprise) dès l'inscription.
