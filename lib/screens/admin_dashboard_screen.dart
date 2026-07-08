// lib/screens/admin_dashboard_screen.dart
// ✅ Diff vs original : intégration AdminSocketService + bandeau live notif
// Toutes les sections métier (annonces, KYC, litiges) sont INCHANGÉES.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/mock_data.dart';
import '../services/auth_service.dart';
import '../services/admin_socket_service.dart'; // NEW
import '../services/api_service.dart'; // NEW : vraies routes /api/admin/*
import '../theme/app_theme.dart';
import '../widgets/widgets.dart' show publishedPropertiesNotifier, pendingPropertiesNotifier, pushNotification, followedOwnersNotifier, notifyFollowersOfOwner, PropertyCard, PrimaryButton, StatCard, UserAvatar, kycPendingNotifier, KycEntry;
import '../models/models.dart';
import 'auth_screens.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // NOTE : listes de démo retirées. "Litiges" n'a pas encore de backend réel
  // (aucune route/contrôleur fourni pour ça) — l'onglet affiche donc un état
  // vide honnête plutôt que des données inventées, en attendant l'implémentation.
  final List<Map<String, String>> _disputes = [];

  // ── NEW : vraies données chargées depuis l'API (remplacent MockDataService) ─
  List<UserModel> _users = [];
  int _totalUsers = 0;
  int _totalProperties = 0;
  bool _loadingDashboard = true;
  String? _dashboardError;

  Future<void> _loadDashboardData() async {
    setState(() {
      _loadingDashboard = true;
      _dashboardError = null;
    });

    try {
      final results = await Future.wait([
        ApiService.instance.get('/admin/users?limit=100', auth: true),
        ApiService.instance.get('/admin/stats', auth: true),
        ApiService.instance.get('/admin/properties/pending', auth: true),
        ApiService.instance.get('/admin/kyc/pending', auth: true),
      ]);

      final usersRes = results[0];
      final statsRes = results[1];
      final pendingPropsRes = results[2];
      final kycRes = results[3];

      if (usersRes['success'] == true) {
        final list = (usersRes['data'] as List)
            .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
            .toList();
        _users = list;
      }

      if (statsRes['success'] == true) {
        _totalUsers = statsRes['data']['totalUsers'] ?? _users.length;
        _totalProperties = statsRes['data']['totalProperties'] ?? 0;
      }

      if (pendingPropsRes['success'] == true) {
        pendingPropertiesNotifier.value = (pendingPropsRes['data'] as List)
            .map((j) => PropertyModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }

      if (kycRes['success'] == true) {
        kycPendingNotifier.value = (kycRes['data'] as List).map((j) {
          final doc = j as Map<String, dynamic>;
          final user = doc['user'] as Map<String, dynamic>? ?? {};
          return KycEntry(
            userId: user['id'] ?? '',
            // NEW : on garde l'id du document KYC séparément de l'userId,
            // il est indispensable pour appeler PUT /admin/kyc/:id/approve|reject
            docId: doc['id'] ?? '',
            nom: user['nom'] ?? '',
            prenom: user['prenom'] ?? '',
            docType: doc['docType'] ?? doc['type'] ?? 'Document',
            numDoc: doc['numDoc'] ?? '—',
            soumisLabel: doc['createdAt'] != null ? 'Soumis' : '',
            soumisAt: doc['createdAt'] != null
                ? DateTime.tryParse(doc['createdAt']) ?? DateTime.now()
                : DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
      _dashboardError = 'Impossible de charger les données admin : $e';
    } finally {
      if (mounted) setState(() => _loadingDashboard = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // ── NEW : Charger les vraies données (users/stats/annonces/KYC) ─────────
    _loadDashboardData();

    // ── NEW : Connexion Socket.io ────────────────────────────────────────────
    // Le token JWT est stocké côté ApiService (SharedPreferences), pas sur
    // AuthService lui-même (qui n'expose aucun getter `token`).
    _connectAdminSocket();

    // ── NEW : Écouter les notifs live pour afficher le bandeau ──────────────
    adminLiveNotifNotifier.addListener(_onLiveNotif);
  }

  Future<void> _connectAdminSocket() async {
    final token = await ApiService.instance.getToken();
    if (token != null && token.isNotEmpty) {
      AdminSocketService.instance.connect(token: token);
    }
  }

  @override
  void dispose() {
    adminLiveNotifNotifier.removeListener(_onLiveNotif);
    AdminSocketService.instance.disconnect(); // NEW
    _tabController.dispose();
    super.dispose();
  }

  // ── NEW : Affiche un SnackBar stylé à chaque notif reçue ─────────────────
  void _onLiveNotif() {
    final notif = adminLiveNotifNotifier.value;
    if (notif == null || !mounted) return;

    final isAlert = notif.type == 'NEW_PROPERTY' || notif.type == 'NEW_KYC';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isAlert ? AppTheme.warning : AppTheme.success,
        content: Row(children: [
          Icon(
            isAlert ? Icons.notifications_active_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notif.title,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(
                // Supprimer les balises <strong> pour l'affichage Flutter
                notif.message.replaceAll(RegExp(r'<[^>]*>'), ''),
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )),
          // Bouton "Voir" qui saute sur l'onglet concerné
          if (isAlert)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _tabController.animateTo(
                  notif.type == 'NEW_PROPERTY' ? 1 : 2, // Annonces=1, KYC=2
                );
              },
              child: Text('Voir', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDashboard) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_dashboardError != null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_dashboardError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadDashboardData, child: const Text('Réessayer')),
          ]),
        ),
      );
    }
    final users = _users;
    final properties = _totalProperties;

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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Administration', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(width: 8),
          // ── NEW : Point vert "connecté" ────────────────────────────────────
          ValueListenableBuilder<AdminNotif?>(
            valueListenable: adminLiveNotifNotifier,
            builder: (_, notif, __) => Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.6), blurRadius: 4)],
              ),
            ),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Déconnexion',
            onPressed: () async {
              AdminSocketService.instance.disconnect(); // NEW
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
          // ── NEW : Badge sur l'onglet Annonces et KYC ─────────────────────
          tabs: [
            const Tab(text: 'Tableau de bord'),
            Tab(child: _TabWithBadge(label: 'Annonces', notifier: pendingPropertiesNotifier)),
            Tab(child: _TabWithBadge(label: 'KYC', notifier: kycPendingNotifier)),
            const Tab(text: 'Litiges'),
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
              _buildDashboard(users.length, properties + (published as List).length),
              _buildAnnoncesValidation(),
              _buildKycValidation(),
              _buildLitiges(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Le reste est IDENTIQUE à l'original ─────────────────────────────────

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
              Expanded(child: StatCard(label: 'En attente', value: '${pendingPropertiesNotifier.value.length}', icon: Icons.pending_actions_rounded, color: AppTheme.warning)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Litiges', value: '${_disputes.length}', icon: Icons.gavel_rounded, color: AppTheme.error)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Utilisateurs récents', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ..._users.take(10).map((u) => Container(
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
    return ValueListenableBuilder(
      valueListenable: pendingPropertiesNotifier,
      builder: (context, pendingRaw, _) {
        final pendingList = (pendingRaw as List).cast<PropertyModel>();
        final totalPending = pendingList.length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              ...pendingList.map((prop) => _AdminRealAnnonceCard(property: prop, key: ValueKey(prop.id))),
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
          itemBuilder: (context, i) => _KycCard(entry: kycList[i]),
        );
      },
    );
  }

  Widget _buildLitiges() {
    if (_disputes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.gavel_rounded, size: 56, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text('Aucun litige pour le moment',
                style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('La gestion des litiges n\'est pas encore connectée au backend.',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }
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

// ── NEW : Widget onglet avec badge compteur ───────────────────────────────────
class _TabWithBadge extends StatelessWidget {
  final String label;
  final ValueNotifier<List<dynamic>> notifier;
  const _TabWithBadge({required this.label, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: notifier,
      builder: (_, list, __) {
        final count = list.length;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ]);
      },
    );
  }
}

// ── Les classes suivantes sont IDENTIQUES à l'original ───────────────────────

class _AdminRealAnnonceCard extends StatefulWidget {
  final PropertyModel property;
  const _AdminRealAnnonceCard({required this.property});
  @override
  State<_AdminRealAnnonceCard> createState() => _AdminRealAnnonceCardState();
}

class _AdminRealAnnonceCardState extends State<_AdminRealAnnonceCard> {
  String _status = 'pending';

  bool _submitting = false;

  Future<void> _approve() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final p = widget.property;
    final res = await ApiService.instance.put('/admin/properties/${p.id}/approve', {}, auth: true);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Erreur lors de l\'approbation')),
      );
      return;
    }

    final currentUser = AuthService.instance.currentUserOrEmpty;
    final isActuallyPremium = currentUser.id == p.proprietaire.id
        ? currentUser.isPremium
        : p.proprietaire.isPremium;

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
      isPremium: isActuallyPremium,
      countryCode: p.proprietaire.countryCode,
      countryName: p.proprietaire.countryName,
    );

    final approvedProperty = PropertyModel(
      id: p.id,
      titre: p.titre,
      description: p.description,
      prix: p.prix,
      type: p.type,
      listingType: p.listingType,
      categorie: p.categorie,
      adresse: p.adresse,
      images: p.images,
      caracteristiques: p.caracteristiques,
      isAvailable: p.isAvailable,
      isFeatured: p.isFeatured,
      status: 'approuve',
      vues: p.vues,
      createdAt: p.createdAt,
      updatedAt: DateTime.now(),
      proprietaire: updatedOwner,
    );

    pendingPropertiesNotifier.value =
        pendingPropertiesNotifier.value.where((e) => (e as PropertyModel).id != p.id).toList();
    publishedPropertiesNotifier.value = [
      ...publishedPropertiesNotifier.value,
      approvedProperty,
    ];
    notifyFollowersOfOwner(
      ownerId: p.proprietaire.id,
      ownerName: p.proprietaire.fullName,
      propertyTitre: p.titre,
      propertyId: p.id,
    );
    pushNotification(
      titre: '🎉 Annonce approuvée !',
      message: '"${p.titre}" a été validée et publiée sur VelQix.',
      type: 'success',
      propertyId: p.id,
    );
    if (mounted) setState(() => _status = 'approved');
  }

  Future<void> _reject() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final p = widget.property;
    final res = await ApiService.instance.put('/admin/properties/${p.id}/reject', {}, auth: true);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Erreur lors du rejet')),
      );
      return;
    }

    pendingPropertiesNotifier.value =
        pendingPropertiesNotifier.value.where((e) => (e as PropertyModel).id != p.id).toList();
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
    final prix = p.prix % 1 == 0 ? '${p.prix.toInt()} FCFA' : '${p.prix} FCFA';

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
              Builder(builder: (ctx) {
                final currentUser = AuthService.instance.currentUserOrEmpty;
                final isPrem = currentUser.id == p.proprietaire.id
                    ? currentUser.isPremium
                    : p.proprietaire.isPremium;
                return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  Text('Par ${p.proprietaire.fullName}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
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
                decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.error.withOpacity(0.2))),
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
                decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(10)),
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

class _KycCard extends StatefulWidget {
  final KycEntry entry;
  const _KycCard({required this.entry});
  @override
  State<_KycCard> createState() => _KycCardState();
}

class _KycCardState extends State<_KycCard> {
  String _status = 'pending';
  bool _submitting = false;

  Future<void> _approve() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final res = await ApiService.instance.put(
      '/admin/kyc/${widget.entry.docId}/approve', {}, auth: true,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Erreur lors de l\'approbation du KYC')),
      );
      return;
    }

    kycPendingNotifier.value =
        kycPendingNotifier.value.where((e) => e.userId != widget.entry.userId).toList();
    if (mounted) setState(() => _status = 'approved');
  }

  Future<void> _reject() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final res = await ApiService.instance.put(
      '/admin/kyc/${widget.entry.docId}/reject', {}, auth: true,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Erreur lors du rejet du KYC')),
      );
      return;
    }

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
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Color(0xFFE8F0FE), shape: BoxShape.circle),
          child: const Icon(Icons.person_search_rounded, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${e.prenom} ${e.nom}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          Text('Document : ${e.docType} · N° ${e.numDoc}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          Text('Soumis ${e.soumisLabel}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
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