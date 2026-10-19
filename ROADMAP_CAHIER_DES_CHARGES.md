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
