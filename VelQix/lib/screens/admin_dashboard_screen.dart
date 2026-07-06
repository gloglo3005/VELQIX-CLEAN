import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/mock_data.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart' show publishedPropertiesNotifier, pendingPropertiesNotifier, pushNotification, followedOwnersNotifier, notifyFollowersOfOwner, PropertyCard, PrimaryButton, StatCard, UserAvatar, kycPendingNotifier, KycEntry;
import '../models/models.dart';
import 'auth_screens.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Simulated pending announcements for validation
  final _pendingAnnonces = [
    {'id': 'pa1', 'titre': 'Appartement F2 – Adidogomé', 'proprietaire': 'Agbotse Kokou', 'date': 'Aujourd\'hui 09:12', 'categorie': 'Appartement', 'prix': '180 000 FCFA/mois'},
    {'id': 'pa2', 'titre': 'Moto Yamaha 2021', 'proprietaire': 'Dovi Mensah', 'date': 'Hier 14:30', 'categorie': 'Moto', 'prix': '15 000 FCFA/jour'},
    {'id': 'pa3', 'titre': 'Terrain 400 m² – Baguida', 'proprietaire': 'Amélé Atchou', 'date': 'Hier 11:05', 'categorie': 'Terrain', 'prix': '4 500 000 FCFA'},
  ];

  // KYC list is now dynamic via kycPendingNotifier

  final _disputes = [
    {'id': 'l1', 'titre': 'Litige villa – Lomé Tokoin', 'parties': 'Ama K. vs Kwame M.', 'statut': 'Ouvert', 'date': 'Il y a 1j'},
    {'id': 'l2', 'titre': 'Non-restitution Toyota', 'parties': 'Mawuli A. vs Sena A.', 'statut': 'En cours', 'date': 'Il y a 3j'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final users = MockDataService.users;
    final properties = MockDataService.properties;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Text('Administration', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Déconnexion',
            onPressed: () async {
              await AuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Tableau de bord'),
            Tab(text: 'Annonces'),
            Tab(text: 'KYC'),
            Tab(text: 'Litiges'),
          ],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: pendingPropertiesNotifier,
        builder: (context, _, __) => ValueListenableBuilder(
          valueListenable: publishedPropertiesNotifier,
          builder: (context, published, __) => TabBarView(
            controller: _tabController,
            children: [
              _buildDashboard(users.length, properties.length + (published as List).length),
              _buildAnnoncesValidation(),
              _buildKycValidation(),
              _buildLitiges(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(int userCount, int propCount) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vue d\'ensemble', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: StatCard(label: 'Utilisateurs', value: '$userCount', icon: Icons.people_rounded, color: AppTheme.primary)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Annonces', value: '$propCount', icon: Icons.home_work_rounded, color: AppTheme.success)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StatCard(label: 'En attente', value: '${pendingPropertiesNotifier.value.length + _pendingAnnonces.length}', icon: Icons.pending_actions_rounded, color: AppTheme.warning)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Litiges', value: '${_disputes.length}', icon: Icons.gavel_rounded, color: AppTheme.error)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Utilisateurs récents', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...MockDataService.users.map((u) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              UserAvatar(user: u, radius: 20, showBadge: true),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.fullName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(u.role, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: u.isVerified ? AppTheme.success.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(u.isVerified ? 'Vérifié' : 'Non vérifié',
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: u.isVerified ? AppTheme.success : AppTheme.warning)),
              ),
            ]),
          )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAnnoncesValidation() {
    // ✅ ValueListenableBuilder local pour réagir en temps réel aux nouvelles soumissions
    return ValueListenableBuilder(
      valueListenable: pendingPropertiesNotifier,
      builder: (context, pendingRaw, _) {
        final pendingList = (pendingRaw as List).cast<PropertyModel>();
        final totalPending = pendingList.length + _pendingAnnonces.length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bandeau compteur total
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.pending_actions_rounded, color: AppTheme.warning),
                const SizedBox(width: 10),
                Text(
                  '$totalPending annonce${totalPending > 1 ? "s" : ""} en attente de validation',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.warning),
                ),
              ]),
            ),
            const SizedBox(height: 14),

            // ✅ Annonces RÉELLES soumises par les utilisateurs
            if (pendingList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [
                  const Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textHint),
                  const SizedBox(height: 12),
                  Text('Aucune nouvelle annonce soumise',
                      style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
                ]),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Annonces soumises par les utilisateurs (${pendingList.length})',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                ),
              ),
              ...pendingList.map((prop) => _AdminRealAnnonceCard(property: prop)),
            ],

            // Annonces simulées (demo)
            if (_pendingAnnonces.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Annonces demo', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
              ),
              ..._pendingAnnonces.map((a) => _AdminAnnonceCard(annonce: a)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildKycValidation() {
    return ValueListenableBuilder(
      valueListenable: kycPendingNotifier,
      builder: (context, kycList, _) {
        if (kycList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.verified_user_rounded, size: 56, color: AppTheme.textHint),
                const SizedBox(height: 16),
                Text('Aucune demande KYC en attente',
                    style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center),
              ]),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: kycList.length,
          itemBuilder: (context, i) {
            final entry = kycList[i];
            return _KycCard(entry: entry);
          },
        );
      },
    );
  }

  Widget _buildLitiges() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _disputes.map((l) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.gavel_rounded, color: AppTheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(l['titre']!, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: l['statut'] == 'Ouvert' ? AppTheme.error.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(l['statut']!, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: l['statut'] == 'Ouvert' ? AppTheme.error : AppTheme.warning)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Parties : ${l['parties']}', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
          Text('Ouvert ${l['date']}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)), child: Text('Voir les détails', style: GoogleFonts.poppins(fontSize: 12)))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8), backgroundColor: AppTheme.success), child: Text('Résoudre', style: GoogleFonts.poppins(fontSize: 12)))),
          ]),
        ]),
      )).toList(),
    );
  }
}


// ─── Carte d'annonce réelle (depuis pendingPropertiesNotifier) ────────────────
class _AdminRealAnnonceCard extends StatefulWidget {
  final PropertyModel property;
  const _AdminRealAnnonceCard({required this.property});
  @override
  State<_AdminRealAnnonceCard> createState() => _AdminRealAnnonceCardState();
}

class _AdminRealAnnonceCardState extends State<_AdminRealAnnonceCard> {
  String _status = 'pending';

  void _approve() {
    final p = widget.property;

    // ✅ CORRECTIF : Lire isPremium EN TEMPS RÉEL depuis AuthService
    // (l'objet p.proprietaire est un snapshot figé au moment de la soumission,
    //  avant que l'utilisateur soit passé premium → isPremium était false à ce moment-là)
    final bool isActuallyPremium;
    final currentUser = AuthService.instance.currentUserOrEmpty;
    if (currentUser.id == p.proprietaire.id) {
      // Cas le plus courant : le propriétaire est l'utilisateur connecté
      isActuallyPremium = currentUser.isPremium;
    } else {
      // Fallback : chercher dans MockDataService si c'est un autre utilisateur
      final found = MockDataService.users.where((u) => u.id == p.proprietaire.id);
      isActuallyPremium = found.isNotEmpty ? found.first.isPremium : p.proprietaire.isPremium;
    }

    // Reconstruire l'objet proprietaire avec le statut premium à jour
    final updatedOwner = UserModel(
      id: p.proprietaire.id,
      nom: p.proprietaire.nom,
      prenom: p.proprietaire.prenom,
      email: p.proprietaire.email,
      telephone: p.proprietaire.telephone,
      avatarUrl: p.proprietaire.avatarUrl,
      isVerified: p.proprietaire.isVerified,
      rating: p.proprietaire.rating,
      totalAvis: p.proprietaire.totalAvis,
      createdAt: p.proprietaire.createdAt,
      role: p.proprietaire.role,
      isPremium: isActuallyPremium, // ← statut ACTUEL, pas le snapshot figé
      countryCode: p.proprietaire.countryCode,
      countryName: p.proprietaire.countryName,
    );

    final approvedProperty = PropertyModel(
      id: p.id,
      titre: p.titre,
      description: p.description,
      type: p.type,
      listingType: p.listingType,
      categorie: p.categorie,
      prix: p.prix,
      prixParJour: p.prixParJour,
      images: p.images,
      adresse: p.adresse,
      proprietaire: updatedOwner, // ← propriétaire avec isPremium à jour
      caracteristiques: p.caracteristiques,
      rating: p.rating,
      totalAvis: p.totalAvis,
      isAvailable: p.isAvailable,
      isFeatured: isActuallyPremium, // ✅ vedette si premium au moment de l'approbation ⭐
      vues: p.vues,
      surface: p.surface,
      nombrePieces: p.nombrePieces,
      annee: p.annee,
      createdAt: p.createdAt,
      status: 'approuve',
    );

    // ✅ Retirer de la file d'attente admin
    pendingPropertiesNotifier.value =
        pendingPropertiesNotifier.value.where((e) => (e as PropertyModel).id != p.id).toList();
    // ✅ Publier sur la home (visible par tous les utilisateurs)
    publishedPropertiesNotifier.value = [...publishedPropertiesNotifier.value, approvedProperty];
    // ✅ Notifier l'utilisateur propriétaire en temps réel
    final featuredMsg = isActuallyPremium
        ? ' Votre annonce est mise en vedette grâce à votre abonnement Premium ⭐'
        : '';
    pushNotification(
      titre: '🎉 Annonce approuvée !',
      message: '"${p.titre}" a été validée par l\'administration et est maintenant visible sur la plateforme.$featuredMsg',
      type: 'success',
      propertyId: p.id,
    );
    // ✅ Notifier tous les abonnés du propriétaire
    final ownerName = p.proprietaire.nomEntreprise?.isNotEmpty == true
        ? p.proprietaire.nomEntreprise!
        : '${p.proprietaire.prenom} ${p.proprietaire.nom}'.trim();
    notifyFollowersOfOwner(
      ownerId: p.proprietaire.id,
      ownerName: ownerName,
      propertyTitre: p.titre,
      propertyId: p.id,
    );
    if (mounted) setState(() => _status = 'approved');
  }

  void _reject() {
    final p = widget.property;
    // ✅ Retirer de la file d'attente
    pendingPropertiesNotifier.value =
        pendingPropertiesNotifier.value.where((e) => (e as PropertyModel).id != p.id).toList();
    // ✅ Notifier l'utilisateur du rejet
    pushNotification(
      titre: '⚠️ Annonce non approuvée',
      message: '"${p.titre}" n\'a pas été validée. Veuillez corriger votre annonce et la soumettre à nouveau.',
      type: 'error',
      propertyId: p.id,
    );
    if (mounted) setState(() => _status = 'rejected');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final prix = p.prix % 1 == 0
        ? '${p.prix.toInt()} FCFA'
        : '${p.prix} FCFA';

    if (_status != 'pending') {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _status == 'approved' ? AppTheme.success.withOpacity(0.05) : AppTheme.error.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _status == 'approved' ? AppTheme.success.withOpacity(0.3) : AppTheme.error.withOpacity(0.3),
          ),
        ),
        child: Row(children: [
          Icon(
            _status == 'approved' ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: _status == 'approved' ? AppTheme.success : AppTheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(
            '${p.titre} – ${_status == 'approved' ? 'Approuvée et publiée' : 'Rejetée'}',
            style: GoogleFonts.poppins(fontSize: 13, color: _status == 'approved' ? AppTheme.success : AppTheme.error),
          )),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(children: [
        // Badge "Nouveau"
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.1),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Row(children: [
            const Icon(Icons.fiber_new_rounded, color: AppTheme.warning, size: 16),
            const SizedBox(width: 6),
            Text('Nouvelle annonce · ${p.adresse.ville}',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w600)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60, height: 60,
                child: p.images.isNotEmpty && p.images.first.startsWith('http')
                    ? Image.network(p.images.first, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: AppTheme.divider,
                            child: const Icon(Icons.image_rounded, color: AppTheme.textHint)))
                    : Container(color: AppTheme.primary.withOpacity(0.1),
                        child: const Icon(Icons.home_rounded, color: AppTheme.primary, size: 28)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.titre, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
              // ✅ Ligne propriétaire + badge Premium en temps réel
              Builder(builder: (ctx) {
                final currentUser = AuthService.instance.currentUserOrEmpty;
                final isPrem = currentUser.id == p.proprietaire.id
                    ? currentUser.isPremium
                    : MockDataService.users.where((u) => u.id == p.proprietaire.id).isNotEmpty
                        ? MockDataService.users.firstWhere((u) => u.id == p.proprietaire.id).isPremium
                        : p.proprietaire.isPremium;
                return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  Text('Par \${p.proprietaire.fullName}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                  if (isPrem) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 10),
                      const SizedBox(width: 2),
                      Text('Premium', style: GoogleFonts.poppins(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]);
              }),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.info.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                  child: Text(p.categorieLabel, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.info, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Text(prix, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
              ]),
            ])),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: _reject,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.error.withOpacity(0.2)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.close_rounded, color: AppTheme.error, size: 16),
                  const SizedBox(width: 5),
                  Text('Rejeter', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.error, fontWeight: FontWeight.w600)),
                ]),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: _approve,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 5),
                  Text('Approuver', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                ]),
              ),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ─── KYC Card dynamique ──────────────────────────────────────────────────────
class _KycCard extends StatefulWidget {
  final KycEntry entry;
  const _KycCard({required this.entry});
  @override
  State<_KycCard> createState() => _KycCardState();
}

class _KycCardState extends State<_KycCard> {
  String _status = 'pending';

  void _approve() {
    kycPendingNotifier.value =
        kycPendingNotifier.value.where((e) => e.userId != widget.entry.userId).toList();
    if (mounted) setState(() => _status = 'approved');
  }

  void _reject() {
    kycPendingNotifier.value =
        kycPendingNotifier.value.where((e) => e.userId != widget.entry.userId).toList();
    if (mounted) setState(() => _status = 'rejected');
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    if (_status != 'pending') {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _status == 'approved' ? AppTheme.success.withOpacity(0.05) : AppTheme.error.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _status == 'approved' ? AppTheme.success.withOpacity(0.3) : AppTheme.error.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(_status == 'approved' ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: _status == 'approved' ? AppTheme.success : AppTheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text(
            '${e.prenom} ${e.nom} – ${_status == "approved" ? "KYC approuvé" : "KYC rejeté"}',
            style: GoogleFonts.poppins(fontSize: 13, color: _status == 'approved' ? AppTheme.success : AppTheme.error),
          )),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Color(0xFFE8F0FE), shape: BoxShape.circle),
          child: const Icon(Icons.person_search_rounded, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${e.prenom} ${e.nom}',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          Text('Document : ${e.docType} · N° ${e.numDoc}',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          Text('Soumis ${e.soumisLabel}',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
        ])),
        Row(children: [
          GestureDetector(
            onTap: _approve,
            child: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.check_rounded, color: AppTheme.success, size: 18)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _reject,
            child: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close_rounded, color: AppTheme.error, size: 18)),
          ),
        ]),
      ]),
    );
  }
}

class _AdminAnnonceCard extends StatefulWidget {
  final Map<String, dynamic> annonce;
  const _AdminAnnonceCard({required this.annonce});
  @override
  State<_AdminAnnonceCard> createState() => _AdminAnnonceCardState();
}

class _AdminAnnonceCardState extends State<_AdminAnnonceCard> {
  String _status = 'pending'; // pending, approved, rejected

  @override
  Widget build(BuildContext context) {
    final a = widget.annonce;
    if (_status != 'pending') {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _status == 'approved' ? AppTheme.success.withOpacity(0.05) : AppTheme.error.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14), border: Border.all(color: _status == 'approved' ? AppTheme.success.withOpacity(0.3) : AppTheme.error.withOpacity(0.3))),
        child: Row(children: [
          Icon(_status == 'approved' ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: _status == 'approved' ? AppTheme.success : AppTheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text('${a['titre']} – ${_status == 'approved' ? 'Approuvée' : 'Rejetée'}',
              style: GoogleFonts.poppins(fontSize: 13, color: _status == 'approved' ? AppTheme.success : AppTheme.error))),
          TextButton(onPressed: () => setState(() => _status = 'pending'), child: Text('Annuler', style: GoogleFonts.poppins(fontSize: 11))),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.home_outlined, color: AppTheme.primary, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['titre']!, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              Text('Par ${a['proprietaire']} · ${a['date']}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: AppTheme.info.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                    child: Text(a['categorie']!, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.info, fontWeight: FontWeight.w600))),
                const SizedBox(width: 6),
                Text(a['prix']!, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
              ]),
            ])),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _status = 'rejected'),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.error.withOpacity(0.2))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.close_rounded, color: AppTheme.error, size: 16),
                    const SizedBox(width: 5),
                    Text('Rejeter', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.error, fontWeight: FontWeight.w600)),
                  ])),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _status = 'approved'),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 5),
                    Text('Approuver', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                  ])),
            )),
          ]),
        ),
      ]),
    );
  }
}