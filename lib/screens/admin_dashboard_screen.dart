// lib/screens/admin_dashboard_screen.dart
// ✅ Diff vs original : intégration AdminSocketService + bandeau live notif
// Sections métier : annonces, litiges.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/admin_socket_service.dart'; // NEW
import '../services/api_service.dart'; // NEW : vraies routes /api/admin/*
import '../services/staff_service.dart';
import '../services/admin_service.dart';
import '../services/report_service.dart';
import 'admin_tabs/admin_users_tab.dart';
import 'admin_tabs/admin_properties_tab.dart';
import 'admin_tabs/admin_roles_tab.dart';
import 'admin_tabs/admin_kpi_section.dart';
import 'admin_tabs/admin_ops_tab.dart';
import 'admin_tabs/admin_common.dart' show adminRoleColor;
import '../theme/app_theme.dart';
import '../widgets/widgets.dart' show publishedPropertiesNotifier, pendingPropertiesNotifier, StatCard, UserAvatar, AppTextField, PrimaryButton;
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

  // Litiges : l'onglet est branché sur les signalements (voir ReportService).

  // ── NEW : vraies données chargées depuis l'API (remplacent MockDataService) ─
  List<UserModel> _users = [];
  int _totalUsers = 0;
  int _totalProperties = 0;
  int _approvedProperties = 0; // annonces valides (approuvées) : chiffre de la carte « Annonces »
  Timer? _statsDebounce;
  bool _loadingDashboard = true;
  String? _dashboardError;

  /// Recharge uniquement la liste des utilisateurs (sans écran de chargement).
  Future<void> _refreshUsers() async {
    try {
      final list = await AdminService.instance.getUsers();
      if (mounted) setState(() => _users = list);
    } catch (_) {}
  }

  /// Recharge uniquement les compteurs (sans écran de chargement).
  Future<void> _refreshStats() async {
    try {
      final res = await ApiService.instance.get('/admin/stats', auth: true);
      if (res['success'] == true && res['data'] is Map && mounted) {
        final d = res['data'] as Map;
        setState(() {
          _totalUsers = (d['totalUsers'] as num?)?.toInt() ?? _totalUsers;
          _totalProperties = (d['totalProperties'] as num?)?.toInt() ?? _totalProperties;
          _approvedProperties = (d['approvedProperties'] as num?)?.toInt() ?? _approvedProperties;
        });
      }
    } catch (_) {}
  }

  /// Les compteurs étaient chargés une seule fois à l'ouverture : on les
  /// rafraîchit dès qu'une annonce arrive, est approuvée ou rejetée.
  void _scheduleStatsRefresh() {
    _statsDebounce?.cancel();
    _statsDebounce = Timer(const Duration(milliseconds: 600), _refreshStats);
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _loadingDashboard = true;
      _dashboardError = null;
    });

    try {
      final results = await Future.wait([
        ApiService.instance.get('/admin/users?limit=500', auth: true),
        ApiService.instance.get('/admin/stats', auth: true),
        ApiService.instance.get('/admin/properties/pending', auth: true),
      ]);

      final usersRes = results[0];
      final statsRes = results[1];
      final pendingPropsRes = results[2];

      if (usersRes['success'] == true) {
        final list = (usersRes['data'] as List)
            .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
            .toList();
        _users = list;
      }

      if (statsRes['success'] == true) {
        _totalUsers = statsRes['data']['totalUsers'] ?? _users.length;
        _totalProperties = (statsRes['data']['totalProperties'] as num?)?.toInt() ?? 0;
        _approvedProperties = (statsRes['data']['approvedProperties'] as num?)?.toInt() ?? 0;
      }

      if (pendingPropsRes['success'] == true) {
        pendingPropertiesNotifier.value = (pendingPropsRes['data'] as List)
            .map((j) => PropertyModel.fromJson(j as Map<String, dynamic>))
            .toList();
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
    _tabController = TabController(length: 8, vsync: this);
    // Met à jour la barre latérale (grand écran) quand l'onglet change
    _tabController.addListener(() {
      if (mounted && !_tabController.indexIsChanging) setState(() {});
    });

    // ── NEW : Charger les vraies données (users/stats/annonces) ─────────
    _loadDashboardData();

    // ── NEW : Connexion Socket.io ────────────────────────────────────────────
    // Le token JWT est stocké côté ApiService (SharedPreferences), pas sur
    // AuthService lui-même (qui n'expose aucun getter `token`).
    _connectAdminSocket();

    // Compteur de litiges à traiter (carte du tableau de bord)
    ReportService.instance.refreshOpenCount();

    // ── NEW : Écouter les notifs live pour afficher le bandeau ──────────────
    adminLiveNotifNotifier.addListener(_onLiveNotif);

    // Compteurs à jour : nouvelle annonce, approbation, rejet.
    pendingPropertiesNotifier.addListener(_scheduleStatsRefresh);
    publishedPropertiesNotifier.addListener(_scheduleStatsRefresh);
  }

  Future<void> _connectAdminSocket() async {
    final token = await ApiService.instance.getValidToken();
    if (token != null && token.isNotEmpty) {
      AdminSocketService.instance.connect(token: token);
    }
  }

  @override
  void dispose() {
    adminLiveNotifNotifier.removeListener(_onLiveNotif);
    pendingPropertiesNotifier.removeListener(_scheduleStatsRefresh);
    publishedPropertiesNotifier.removeListener(_scheduleStatsRefresh);
    _statsDebounce?.cancel();
    AdminSocketService.instance.disconnect(); // NEW
    _tabController.dispose();
    super.dispose();
  }

  // ── NEW : Affiche un SnackBar stylé à chaque notif reçue ─────────────────
  void _onLiveNotif() {
    final notif = adminLiveNotifNotifier.value;
    if (notif == null || !mounted) return;

    final isAlert = notif.type == 'NEW_PROPERTY';

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
                _tabController.animateTo(1);
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
    final properties = _approvedProperties; // annonces valides
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
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
        bottom: isWide ? null : TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          // ── NEW : Badge sur l'onglet Annonces ─────────────────────
          tabs: [
            const Tab(text: 'Tableau de bord'),
            Tab(child: _TabWithBadge(label: 'Modération', notifier: pendingPropertiesNotifier)),
            const Tab(text: 'Utilisateurs'),
            const Tab(text: 'Annonces'),
            const Tab(text: 'Équipe'),
            const Tab(text: 'Opérations & finances'),
            const Tab(text: 'Rôles & permissions'),
            const Tab(text: 'Litiges'),
          ],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: pendingPropertiesNotifier,
        builder: (context, _, __) => ValueListenableBuilder(
          valueListenable: publishedPropertiesNotifier,
          builder: (context, published, __) {
            final view = TabBarView(
              controller: _tabController,
              physics: isWide ? const NeverScrollableScrollPhysics() : null,
              children: [
                _buildDashboard(users.length, properties),
                _buildAnnoncesValidation(),
                AdminUsersTab(users: users, onRefresh: _refreshUsers),
                const AdminPropertiesTab(),
                _buildEquipe(),
                const AdminOpsTab(),
                const AdminRolesTab(),
                _buildLitiges(),
              ],
            );
            if (!isWide) return view;
            return Row(children: [
              _buildSideRail(),
              VerticalDivider(width: 1, color: AppTheme.border),
              Expanded(child: view),
            ]);
          },
        ),
      ),
    );
  }

  // ─── Équipe : démarcheurs & agents d'entretien (comptes créés par l'admin) ─
  Widget _buildEquipe() {
    final staff = _users.where((u) => u.isStaff).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
            child: Text("Démarcheurs & agents d'entretien",
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            onPressed: _openCreateStaff,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Créer un compte'),
          ),
        ]),
        const SizedBox(height: 6),
        Text("Ces comptes ne peuvent pas s'inscrire eux-mêmes : seul l'administrateur les crée.",
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 14),
        if (staff.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text('Aucun compte pour le moment.',
                  style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
            ),
          ),
        ...staff.map((u) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border)),
              child: Row(children: [
                UserAvatar(user: u, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.fullName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(u.roleLabel,
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primary)),
                    if (u.telephone.isNotEmpty)
                      Text(u.telephone,
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ),
              ]),
            )),
      ],
    );
  }

  Future<void> _openCreateStaff() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _CreateStaffSheet(),
    );
    if (created == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Compte créé avec succès.')));
      _loadDashboardData();
    }
  }

  // ─── Le reste est IDENTIQUE à l'original ─────────────────────────────────

  // ─── Barre latérale façon « Django admin » (grand écran) ──────────────────
  Widget _buildSideRail() {
    Widget icon(IconData i) => Icon(i);
    return NavigationRail(
      backgroundColor: AppTheme.surface,
      extended: MediaQuery.of(context).size.width >= 1200,
      selectedIndex: _tabController.index,
      onDestinationSelected: (i) => setState(() => _tabController.animateTo(i)),
      labelType: MediaQuery.of(context).size.width >= 1200 ? null : NavigationRailLabelType.all,
      selectedIconTheme: IconThemeData(color: AppTheme.primary),
      selectedLabelTextStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
      unselectedLabelTextStyle: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
      destinations: [
        NavigationRailDestination(icon: icon(Icons.dashboard_rounded), label: const Text('Tableau de bord')),
        NavigationRailDestination(
          icon: ValueListenableBuilder<List<dynamic>>(
            valueListenable: pendingPropertiesNotifier,
            builder: (_, l, __) => Badge(
              isLabelVisible: l.isNotEmpty,
              label: Text('${l.length}'),
              child: const Icon(Icons.fact_check_rounded),
            ),
          ),
          label: const Text('Modération'),
        ),
        NavigationRailDestination(icon: icon(Icons.people_alt_rounded), label: const Text('Utilisateurs')),
        NavigationRailDestination(icon: icon(Icons.home_work_rounded), label: const Text('Annonces')),
        NavigationRailDestination(icon: icon(Icons.support_agent_rounded), label: const Text('Équipe')),
        NavigationRailDestination(icon: icon(Icons.account_balance_wallet_rounded), label: const Text('Opérations')),
        NavigationRailDestination(icon: icon(Icons.admin_panel_settings_rounded), label: const Text('Rôles')),
        NavigationRailDestination(icon: icon(Icons.gavel_rounded), label: const Text('Litiges')),
      ],
    );
  }

  // ─── Répartition des utilisateurs par rôle ────────────────────────────────
  Widget _buildRoleBreakdown() {
    final total = _users.isEmpty ? 1 : _users.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Utilisateurs par rôle',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final r in AdminService.roles)
          Builder(builder: (_) {
            final n = _users.where((u) => u.role == r).length;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(
                    width: 120,
                    child: Text(AdminService.roleLabel(r), style: GoogleFonts.poppins(fontSize: 12))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: n / total,
                      minHeight: 8,
                      backgroundColor: AppTheme.border,
                      color: adminRoleColor(r),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$n', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            );
          }),
        const SizedBox(height: 4),
        Text(
          '${_users.where((u) => !u.isVerified).length} non vérifiés · '
          '${_users.where((u) => !u.isActive).length} suspendus',
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ]),
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
              Expanded(child: StatCard(label: 'En attente', value: '${pendingPropertiesNotifier.value.length}', icon: Icons.pending_actions_rounded, color: AppTheme.warning)),
              const SizedBox(width: 12),
              Expanded(child: ValueListenableBuilder<int>(valueListenable: openReportsCountNotifier, builder: (_, n, __) => StatCard(label: 'Litiges', value: '$n', icon: Icons.gavel_rounded, color: AppTheme.error))),
            ],
          ),
          const SizedBox(height: 16),
          const AdminKpiSection(),
          const SizedBox(height: 16),
          _buildRoleBreakdown(),
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
                  Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textHint),
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

  Widget _buildLitiges() => const _AdminReportsPanel();
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
  const _AdminRealAnnonceCard({required this.property, super.key});
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
        SnackBar(
          content: Text(res['message'] ?? 'Erreur lors de l\'approbation'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
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
      videoUrl: p.videoUrl, // ← la vidéo était perdue à l'approbation
      fieldVerified: p.fieldVerified,
      fieldVerifiedAt: p.fieldVerifiedAt,
      fieldVerifiedByName: p.fieldVerifiedByName,
      verificationRequested: p.verificationRequested,
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
        SnackBar(
          content: Text(res['message'] ?? 'Erreur lors du rejet'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    pendingPropertiesNotifier.value =
        pendingPropertiesNotifier.value.where((e) => (e as PropertyModel).id != p.id).toList();
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
                            child: Icon(Icons.image_rounded, color: AppTheme.textHint)))
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
              onTap: _submitting ? null : _reject,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.error.withOpacity(0.2))),
                child: _submitting
                    ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.error)))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.close_rounded, color: AppTheme.error, size: 16),
                  const SizedBox(width: 5),
                  Text('Rejeter', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.error, fontWeight: FontWeight.w600)),
                ]),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: _submitting ? null : _approve,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(10)),
                child: _submitting
                    ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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


// ─── Formulaire de création d'un compte démarcheur / agent d'entretien ───────
class _CreateStaffSheet extends StatefulWidget {
  const _CreateStaffSheet();
  @override
  State<_CreateStaffSheet> createState() => _CreateStaffSheetState();
}

class _CreateStaffSheetState extends State<_CreateStaffSheet> {
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _tel = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _pass = TextEditingController();
  String _role = StaffService.roleDemarcheur;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_prenom, _nom, _tel, _email, _username, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if ([_prenom, _nom, _tel, _email].any((c) => c.text.trim().isEmpty) ||
        !_email.text.contains('@')) {
      setState(() => _error = 'Prénom, nom, téléphone et e-mail valides sont obligatoires.');
      return;
    }
    if (_pass.text.length < 8) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final err = await StaffService.instance.createStaff(
      role: _role,
      prenom: _prenom.text.trim(),
      nom: _nom.text.trim(),
      telephone: _tel.text.trim(),
      email: _email.text.trim(),
      username: _username.text,
      password: _pass.text,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() { _saving = false; _error = err; });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nouveau compte',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Wrap(spacing: 8, children: [
                  ChoiceChip(
                    label: const Text('Démarcheur'),
                    selected: _role == StaffService.roleDemarcheur,
                    onSelected: (_) => setState(() => _role = StaffService.roleDemarcheur),
                  ),
                  ChoiceChip(
                    label: const Text("Agent d'entretien"),
                    selected: _role == StaffService.roleAgentEntretien,
                    onSelected: (_) => setState(() => _role = StaffService.roleAgentEntretien),
                  ),
                ]),
                const SizedBox(height: 14),
                AppTextField(label: 'Prénom', controller: _prenom, prefixIcon: Icons.person_outline_rounded),
                const SizedBox(height: 12),
                AppTextField(label: 'Nom', controller: _nom, prefixIcon: Icons.person_outline_rounded),
                const SizedBox(height: 12),
                AppTextField(label: 'Téléphone', controller: _tel, prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                AppTextField(label: 'E-mail', controller: _email, prefixIcon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                AppTextField(label: "Nom d'utilisateur (facultatif)", controller: _username, prefixIcon: Icons.alternate_email_rounded),
                const SizedBox(height: 12),
                AppTextField(label: 'Mot de passe provisoire', controller: _pass, prefixIcon: Icons.lock_outline_rounded, obscureText: true),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error)),
                ],
                const SizedBox(height: 16),
                PrimaryButton(label: 'Créer le compte', isLoading: _saving, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Litiges : signalements d'annonces (GET/PUT /api/admin/reports) ───────────
class _ReportFilter {
  final String? status; // null = à traiter (open, reviewing, needs_info)
  final String label;
  const _ReportFilter(this.status, this.label);
}

class _AdminReportsPanel extends StatefulWidget {
  const _AdminReportsPanel();
  @override
  State<_AdminReportsPanel> createState() => _AdminReportsPanelState();
}

class _AdminReportsPanelState extends State<_AdminReportsPanel> {
  static const List<_ReportFilter> _filters = [
    _ReportFilter(null, 'À traiter'),
    _ReportFilter('resolved', 'Résolus'),
    _ReportFilter('dismissed', 'Classés'),
    _ReportFilter('all', 'Tous'),
  ];

  String? _filter;
  List<PropertyReportItem> _items = [];
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    final requested = _filter;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final res = await ReportService.instance.list(status: requested);
    if (!mounted || requested != _filter) return; // filtre changé entre-temps
    setState(() {
      _loading = false;
      _error = res.error;
      if (res.error == null) {
        _items = res.items;
        _total = res.total;
      }
    });
    if (res.error == null && requested == null) {
      openReportsCountNotifier.value = res.total;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'open':       return AppTheme.error;
      case 'reviewing':  return AppTheme.info;
      case 'needs_info': return AppTheme.warning;
      case 'resolved':   return AppTheme.success;
      default:           return AppTheme.textHint;
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Future<void> _openActionSheet(PropertyReportItem r) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReportActionSheet(report: r),
    );
    if (changed == true) {
      ReportService.instance.refreshOpenCount();
      if (mounted) _load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          children: [
            for (final f in _filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.label, style: GoogleFonts.poppins(fontSize: 12)),
                  selected: _filter == f.status,
                  onSelected: (_) {
                    if (_filter == f.status) return;
                    setState(() => _filter = f.status);
                    _load();
                  },
                ),
              ),
          ],
        ),
      ),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.textHint),
            const SizedBox(height: 12),
            Text(_error!,
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: Text('Réessayer', style: GoogleFonts.poppins(fontSize: 12))),
          ]),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.gavel_rounded, size: 56, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(_filter == null ? 'Aucun signalement à traiter' : 'Aucun signalement dans cette liste',
                style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_total > _items.length ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Affichage des ${_items.length} plus récents sur $_total.',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
                  textAlign: TextAlign.center),
            );
          }
          return _reportCard(_items[i]);
        },
      ),
    );
  }

  Widget _reportCard(PropertyReportItem r) {
    final color = _statusColor(r.status);
    final place = r.propertyCity.isEmpty ? r.propertyTitle : '${r.propertyTitle} · ${r.propertyCity}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.gavel_rounded, color: AppTheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(place,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          _pill(ReportService.statusLabel(r.status), color),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _pill(ReportService.reasonLabel(r.reason), AppTheme.warning),
          if (r.isSuspended) _pill('Annonce suspendue', AppTheme.error),
          if (r.isActive && r.activeOnProperty > 1)
            _pill('${r.activeOnProperty} signalements actifs sur ce bien', AppTheme.info),
          if (r.isActive && r.activeSameReason > 1)
            _pill('${r.activeSameReason} pour ce même motif', AppTheme.info),
        ]),
        if (r.details != null) ...[
          const SizedBox(height: 8),
          Text(r.details!, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
        ],
        const SizedBox(height: 8),
        Text(
          'Signalé par ${r.reporterName.isEmpty ? 'un utilisateur' : r.reporterName}'
          '${r.createdAt == null ? '' : ' le ${_fmtDate(r.createdAt)}'}',
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
        ),
        if (r.ownerName.isNotEmpty)
          Text(
            'Annonceur : ${r.ownerName}${r.ownerPhone.isEmpty ? '' : ' · ${r.ownerPhone}'}',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
          ),
        if (r.resolution != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Décision : ${r.resolution}',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: r.isActive
              ? ElevatedButton(
                  onPressed: () => _openActionSheet(r),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                  child: Text('Traiter', style: GoogleFonts.poppins(fontSize: 12)),
                )
              : OutlinedButton(
                  onPressed: () => _openActionSheet(r),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                  child: Text('Revoir la décision', style: GoogleFonts.poppins(fontSize: 12)),
                ),
        ),
      ]),
    );
  }
}

class _ReportActionSheet extends StatefulWidget {
  final PropertyReportItem report;
  const _ReportActionSheet({required this.report});
  @override
  State<_ReportActionSheet> createState() => _ReportActionSheetState();
}

class _ReportActionSheetState extends State<_ReportActionSheet> {
  late String _status;
  String _action = 'none'; // none | suspend | restore
  late final TextEditingController _resolutionCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.report.status;
    _resolutionCtrl = TextEditingController(text: widget.report.resolution ?? '');
  }

  @override
  void dispose() {
    _resolutionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final r = widget.report;
    final status = _status != r.status ? _status : null;
    final resolution = _resolutionCtrl.text.trim();
    final resolutionChanged = resolution != (r.resolution ?? '');
    final action = _action == 'none' ? null : _action;
    final messenger = ScaffoldMessenger.of(context);

    if (status == null && !resolutionChanged && action == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Aucune modification à enregistrer')));
      return;
    }

    setState(() => _saving = true);
    final res = await ReportService.instance.update(
      r.id,
      status: status,
      resolution: resolutionChanged ? resolution : null,
      propertyAction: action,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    messenger.showSnackBar(SnackBar(
      content: Text(res.message),
      backgroundColor: res.ok ? AppTheme.success : AppTheme.error,
    ));
    if (res.ok) Navigator.of(context).pop(true);
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      selected: selected,
      onSelected: _saving ? null : (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Traiter le signalement',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${ReportService.reasonLabel(r.reason)} · ${r.propertyTitle}',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            Text('Statut', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in ReportService.statuses)
                _choice(ReportService.statusLabel(s), _status == s, () => setState(() => _status = s)),
            ]),
            const SizedBox(height: 16),
            Text('Décision / commentaire', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _resolutionCtrl,
              enabled: !_saving,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: 'Ex. : annonce vérifiée, informations corrigées par le propriétaire',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Action sur l\'annonce', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _choice('Aucune', _action == 'none', () => setState(() => _action = 'none')),
              if (!r.isSuspended)
                _choice('Suspendre l\'annonce', _action == 'suspend', () => setState(() => _action = 'suspend')),
              if (r.isSuspended)
                _choice('Rétablir l\'annonce', _action == 'restore', () => setState(() => _action = 'restore')),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Enregistrer', style: GoogleFonts.poppins(fontSize: 13)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}