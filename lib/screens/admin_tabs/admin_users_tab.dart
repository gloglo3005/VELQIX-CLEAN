// lib/screens/admin_tabs/admin_users_tab.dart
// Gestion des utilisateurs : recherche, filtres, vérification, suspension,
// changement de rôle, suppression.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart' show UserAvatar;
import 'admin_common.dart';

class AdminUsersTab extends StatefulWidget {
  final List<UserModel> users;
  final Future<void> Function() onRefresh;
  const AdminUsersTab({super.key, required this.users, required this.onRefresh});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  String _q = '';
  String _role = 'all';
  String _status = 'all';

  bool _isMe(UserModel u) => u.id == AuthService.instance.currentUser?.id;

  List<UserModel> get _filtered {
    final q = _q.trim().toLowerCase();
    return widget.users.where((u) {
      if (_role != 'all' && u.role != _role) return false;
      if (_status == 'verified' && !u.isVerified) return false;
      if (_status == 'unverified' && u.isVerified) return false;
      if (_status == 'suspended' && u.isActive) return false;
      if (q.isEmpty) return true;
      return [u.fullName, u.email, u.telephone, u.countryName ?? '']
          .join(' ')
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  Future<void> _run(Future<String?> Function() action, String okMsg) async {
    final err = await action();
    if (!mounted) return;
    if (err != null) {
      adminSnack(context, err, error: true);
      return;
    }
    adminSnack(context, okMsg);
    await widget.onRefresh();
  }

  Future<void> _changeRole(UserModel u) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Rôle de ${u.fullName}',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        children: [
          for (final r in AdminService.roles)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r),
              child: Row(children: [
                Icon(r == u.role ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18, color: adminRoleColor(r)),
                const SizedBox(width: 10),
                Text(AdminService.roleLabel(r), style: GoogleFonts.poppins(fontSize: 14)),
              ]),
            ),
        ],
      ),
    );
    if (picked == null || picked == u.role || !mounted) return;
    if (picked == 'admin') {
      final ok = await adminConfirm(context,
          title: 'Donner les droits administrateur ?',
          message: '${u.fullName} aura accès à toute la gestion de la plateforme.',
          confirmLabel: 'Promouvoir',
          danger: true);
      if (!ok) return;
    }
    await _run(() => AdminService.instance.updateUser(u.id, {'role': picked}),
        'Rôle mis à jour : ${AdminService.roleLabel(picked)}.');
  }

  Future<void> _delete(UserModel u) async {
    final ok = await adminConfirm(context,
        title: 'Supprimer ce compte ?',
        message: 'Le compte de ${u.fullName} sera définitivement supprimé. Cette action est irréversible.',
        confirmLabel: 'Supprimer',
        danger: true);
    if (!ok) return;
    await _run(() => AdminService.instance.deleteUser(u.id), 'Compte supprimé.');
  }

  void _details(UserModel u) {
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 110,
                child: Text(k, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary))),
            Expanded(child: Text(v.isEmpty ? '—' : v, style: GoogleFonts.poppins(fontSize: 13))),
          ]),
        );
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              UserAvatar(user: u, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(u.fullName,
                    style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 14),
            row('Identifiant', u.id),
            row('E-mail', u.email),
            row('Téléphone', u.telephone),
            row('Pays', u.countryName ?? ''),
            row('Rôle', AdminService.roleLabel(u.role)),
            row('Type de compte', u.accountType == 'business' ? 'Professionnel' : 'Personnel'),
            if (u.nomEntreprise != null) row('Entreprise', u.nomEntreprise!),
            row('Premium', u.isPremium ? 'Oui' : 'Non'),
            row('Vérifié', u.isVerified ? 'Oui' : 'Non'),
            row('Statut', u.isActive ? 'Actif' : 'Suspendu'),
            row('Inscrit le', '${u.createdAt.day.toString().padLeft(2, '0')}/'
                '${u.createdAt.month.toString().padLeft(2, '0')}/${u.createdAt.year}'),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                onChanged: (v) => setState(() => _q = v),
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom, e-mail, téléphone, pays…',
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textHint),
                ),
              ),
              const SizedBox(height: 10),
              AdminChipRow(
                selected: _role,
                onSelected: (v) => setState(() => _role = v),
                items: [
                  const MapEntry('all', 'Tous les rôles'),
                  for (final r in AdminService.roles) MapEntry(r, AdminService.roleLabel(r)),
                ],
              ),
              const SizedBox(height: 6),
              AdminChipRow(
                selected: _status,
                onSelected: (v) => setState(() => _status = v),
                items: const [
                  MapEntry('all', 'Tous statuts'),
                  MapEntry('verified', 'Vérifiés'),
                  MapEntry('unverified', 'Non vérifiés'),
                  MapEntry('suspended', 'Suspendus'),
                ],
              ),
              const SizedBox(height: 6),
              Text('${list.length} utilisateur${list.length > 1 ? 's' : ''}',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: list.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Center(
                          child: Text('Aucun utilisateur ne correspond.',
                              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _userCard(list[i]),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _userCard(UserModel u) {
    final me = _isMe(u);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        onTap: () => _details(u),
        leading: UserAvatar(user: u, radius: 20),
        title: Text(u.fullName + (me ? ' (vous)' : ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            AdminBadge(AdminService.roleLabel(u.role), adminRoleColor(u.role)),
            AdminBadge(u.isVerified ? 'Vérifié' : 'Non vérifié',
                u.isVerified ? AppTheme.success : AppTheme.warning),
            if (!u.isActive) AdminBadge('Suspendu', AppTheme.error),
            if (u.email.isNotEmpty)
              Text(u.email, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Actions',
          onSelected: (a) async {
            switch (a) {
              case 'details': _details(u); break;
              case 'verify':
                await _run(() => AdminService.instance.updateUser(u.id, {'isVerified': !u.isVerified}),
                    u.isVerified ? 'Vérification retirée.' : 'Compte vérifié.');
                break;
              case 'suspend':
                final ok = u.isActive
                    ? await adminConfirm(context,
                        title: 'Suspendre ce compte ?',
                        message: '${u.fullName} ne pourra plus se connecter tant que le compte est suspendu.',
                        confirmLabel: 'Suspendre',
                        danger: true)
                    : true;
                if (ok) {
                  await _run(() => AdminService.instance.updateUser(u.id, {'isActive': !u.isActive}),
                      u.isActive ? 'Compte suspendu.' : 'Compte réactivé.');
                }
                break;
              case 'role': await _changeRole(u); break;
              case 'delete': await _delete(u); break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'details', child: Text('Voir les détails')),
            PopupMenuItem(value: 'verify', child: Text(u.isVerified ? 'Retirer la vérification' : 'Vérifier le compte')),
            PopupMenuItem(value: 'role', enabled: !me, child: const Text('Changer le rôle')),
            PopupMenuItem(value: 'suspend', enabled: !me, child: Text(u.isActive ? 'Suspendre' : 'Réactiver')),
            PopupMenuItem(
                value: 'delete',
                enabled: !me,
                child: Text('Supprimer', style: TextStyle(color: me ? null : AppTheme.error))),
          ],
        ),
      ),
    );
  }
}
