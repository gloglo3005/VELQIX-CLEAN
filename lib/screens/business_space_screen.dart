// lib/screens/business_space_screen.dart
// Velqix Business : entreprises et agences.
// Vue d'ensemble · Portefeuille · Équipe (rôles) · Rapports.
// Les onglets et actions affichés dépendent du rôle du collaborateur ; le serveur
// vérifie les mêmes droits sur chaque route.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/plan_service.dart';
import '../services/spaces_service.dart';
import '../theme/app_theme.dart';
import '../widgets/async_panel.dart';
import '../widgets/widgets.dart' show EmptyState, formatFcfa;
import 'plans_screen.dart';

class BusinessSpaceScreen extends StatefulWidget {
  final String role;
  final String companyName;
  const BusinessSpaceScreen({super.key, required this.role, required this.companyName});
  @override
  State<BusinessSpaceScreen> createState() => _BusinessSpaceScreenState();
}

class _BusinessSpaceScreenState extends State<BusinessSpaceScreen> with SingleTickerProviderStateMixin {
  late final List<MapEntry<String, Widget>> _pages;
  late final TabController _tab;

  bool get _isAdmin => widget.role == BusinessRole.admin;
  bool get _canAssign => _isAdmin || widget.role == BusinessRole.manager;

  @override
  void initState() {
    super.initState();
    final r = widget.role;
    _pages = [
      const MapEntry("Vue d'ensemble", _Overview()),
      if (r != BusinessRole.accountant)
        MapEntry('Portefeuille', _Portfolio(canAssign: _canAssign)),
      if (_isAdmin || r == BusinessRole.manager)
        MapEntry('Équipe', _Team(canEdit: _isAdmin)),
      if (r != BusinessRole.sales) const MapEntry('Rapports', _Reports()),
    ];
    _tab = TabController(length: _pages.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Velqix Business', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
          Text('${widget.companyName} · ${BusinessRole.label(widget.role)}',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Formules',
            icon: const Icon(Icons.workspace_premium_rounded),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PlansScreen(initialAudience: PlanAudience.entreprise))),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [for (final p in _pages) Tab(text: p.key)],
        ),
      ),
      body: TabBarView(controller: _tab, children: [for (final p in _pages) p.value]),
    );
  }
}

Widget _page(Widget child, {double maxWidth = 760}) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );

void _snack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppTheme.error : null,
    behavior: SnackBarBehavior.floating,
  ));
}

// ─── Vue d'ensemble ──────────────────────────────────────────────────────────
class _Overview extends StatelessWidget {
  const _Overview();
  @override
  Widget build(BuildContext context) => AsyncPanel<Map<String, dynamic>>(
        load: BusinessService.instance.getOverview,
        builder: (context, data, reload) => RefreshIndicator(
          onRefresh: reload,
          child: _page(ListView(padding: const EdgeInsets.all(16), children: [
            statGrid(data, const [
              MapEntry('listings', 'Annonces'),
              MapEntry('members', 'Collaborateurs'),
              MapEntry('views', 'Vues'),
              MapEntry('contacts', 'Contacts'),
              MapEntry('verifiedProperties', 'Biens vérifiés'),
              MapEntry('pendingVerifications', 'Vérifications en cours'),
            ]),
          ])),
        ),
      );
}

// ─── Portefeuille : tous les biens de l'entreprise ───────────────────────────
class _Portfolio extends StatefulWidget {
  final bool canAssign;
  const _Portfolio({required this.canAssign});
  @override
  State<_Portfolio> createState() => _PortfolioState();
}

class _PortfolioState extends State<_Portfolio> {
  int _version = 0;

  Future<void> _assign(Map<String, dynamic> property) async {
    List<Map<String, dynamic>> team;
    try {
      team = await BusinessService.instance.getTeam();
    } catch (e) {
      if (mounted) _snack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
      return;
    }
    if (!mounted) return;
    final userId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Attribuer à…'),
        children: [
          for (final m in team)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m['id'].toString()),
              child: Text('${m['name'] ?? m['email']} · ${BusinessRole.label((m['role'] ?? '').toString())}'),
            ),
        ],
      ),
    );
    if (userId == null || !mounted) return;
    final err = await BusinessService.instance.assign(property['id'].toString(), userId);
    if (!mounted) return;
    _snack(context, err ?? 'Annonce attribuée.', error: err != null);
    if (err == null) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPanel<List<Map<String, dynamic>>>(
      key: ValueKey('portfolio-$_version'),
      load: BusinessService.instance.getProperties,
      builder: (context, list, reload) => list.isEmpty
          ? const EmptyState(icon: Icons.home_work_outlined, title: 'Aucun bien dans le portefeuille')
          : RefreshIndicator(
              onRefresh: reload,
              child: _page(ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final verified = p['verified'] == true;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text((p['titre'] ?? '').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            'Attribué à : ${(p['assignedTo'] ?? 'non attribué')} · ${p['views'] ?? 0} vues',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(verified ? Icons.verified_rounded : Icons.info_outline_rounded,
                                size: 14, color: verified ? AppTheme.success : AppTheme.warning),
                            const SizedBox(width: 4),
                            Text(verified ? 'Approuvée VelQix' : 'Non approuvée',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ]),
                      ),
                      if (widget.canAssign)
                        OutlinedButton(onPressed: () => _assign(p), child: const Text('Attribuer')),
                    ]),
                  );
                },
              )),
            ),
    );
  }
}

// ─── Équipe : collaborateurs et rôles ────────────────────────────────────────
class _Team extends StatefulWidget {
  final bool canEdit;
  const _Team({required this.canEdit});
  @override
  State<_Team> createState() => _TeamState();
}

class _TeamState extends State<_Team> {
  int _version = 0;

  Future<void> _run(Future<String?> Function() action, String ok) async {
    final err = await action();
    if (!mounted) return;
    _snack(context, err ?? ok, error: err != null);
    if (err == null) setState(() => _version++);
  }

  Future<void> _add() async {
    final email = TextEditingController();
    String role = BusinessRole.sales;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Ajouter un collaborateur'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail du compte VelQix'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: [
                for (final r in BusinessRole.all)
                  DropdownMenuItem(value: r, child: Text(BusinessRole.label(r))),
              ],
              onChanged: (v) => setD(() => role = v ?? role),
            ),
            const SizedBox(height: 6),
            Text(BusinessRole.description(role),
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    final value = email.text.trim();
    email.dispose();
    if (ok != true || value.isEmpty || !mounted) return;
    await _run(() => BusinessService.instance.addMember(value, role), 'Collaborateur ajouté.');
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer ce collaborateur ?'),
        content: Text('${m['name'] ?? m['email']} perdra l\'accès à l\'espace de l\'entreprise.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Retirer', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => BusinessService.instance.removeMember(m['id'].toString()), 'Collaborateur retiré.');
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPanel<List<Map<String, dynamic>>>(
      key: ValueKey('team-$_version'),
      load: BusinessService.instance.getTeam,
      builder: (context, team, reload) => RefreshIndicator(
        onRefresh: reload,
        child: _page(ListView(padding: const EdgeInsets.all(16), children: [
          if (widget.canEdit)
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Ajouter un collaborateur'),
              ),
            ),
          const SizedBox(height: 12),
          for (final m in team)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(children: [
                const Icon(Icons.person_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((m['name'] ?? m['email'] ?? '').toString(),
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text((m['email'] ?? '').toString(),
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ),
                if (widget.canEdit)
                  PopupMenuButton<String>(
                    tooltip: 'Rôle',
                    onSelected: (v) {
                      if (v == '__remove') {
                        _remove(m);
                      } else {
                        _run(() => BusinessService.instance.changeRole(m['id'].toString(), v), 'Rôle modifié.');
                      }
                    },
                    itemBuilder: (_) => [
                      for (final r in BusinessRole.all)
                        PopupMenuItem(value: r, child: Text(BusinessRole.label(r))),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: '__remove', child: Text('Retirer de l\'équipe')),
                    ],
                    child: Chip(
                      label: Text(BusinessRole.label((m['role'] ?? '').toString()),
                          style: GoogleFonts.poppins(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  Chip(
                    label: Text(BusinessRole.label((m['role'] ?? '').toString()),
                        style: GoogleFonts.poppins(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
              ]),
            ),
          const SizedBox(height: 16),
          Text('Rôles', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final r in BusinessRole.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• ${BusinessRole.label(r)} : ${BusinessRole.description(r)}',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            ),
        ])),
      ),
    );
  }
}

// ─── Rapports, historique des vérifications, factures ────────────────────────
class _Reports extends StatefulWidget {
  const _Reports();
  @override
  State<_Reports> createState() => _ReportsState();
}

class _ReportsState extends State<_Reports> {
  String _period = '30d';

  Future<void> _export() async {
    try {
      final url = await BusinessService.instance.exportReportUrl(_period);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) _snack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPanel<Map<String, dynamic>>(
      key: ValueKey('report-$_period'),
      load: () => BusinessService.instance.getReport(_period),
      builder: (context, data, reload) {
        final verifs = data['verifications'] is List
            ? (data['verifications'] as List).whereType<Map>().toList()
            : <Map>[];
        return RefreshIndicator(
          onRefresh: reload,
          child: _page(ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Wrap(spacing: 8, children: [
                for (final p in const [MapEntry('7d', '7 jours'), MapEntry('30d', '30 jours'), MapEntry('90d', '90 jours')])
                  ChoiceChip(
                    label: Text(p.value),
                    selected: _period == p.key,
                    onSelected: (_) => setState(() => _period = p.key),
                  ),
              ]),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Exporter'),
              ),
            ]),
            const SizedBox(height: 14),
            statGrid(data, const [
              MapEntry('listings', 'Annonces'),
              MapEntry('views', 'Vues'),
              MapEntry('contacts', 'Contacts'),
              MapEntry('visits', 'Visites'),
              MapEntry('verificationsDone', 'Vérifications faites'),
            ]),
            const SizedBox(height: 20),
            Text('Historique des vérifications',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (verifs.isEmpty)
              Text('Aucune vérification sur la période.',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            for (final v in verifs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.fact_check_rounded, size: 20),
                title: Text((v['title'] ?? '').toString(), style: GoogleFonts.poppins(fontSize: 12)),
                subtitle: Text('${v['date'] ?? ''} · ${v['status'] ?? ''}',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
              ),
            const SizedBox(height: 20),
            Text('Factures', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            AsyncPanel<List<Map<String, dynamic>>>(
              load: PlanService.instance.getInvoices,
              builder: (context, items, _) => items.isEmpty
                  ? Text('Aucune facture pour le moment.',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary))
                  : Column(children: [
                      for (final f in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.receipt_long_rounded, size: 20),
                          title: Text((f['label'] ?? 'Facture').toString(), style: GoogleFonts.poppins(fontSize: 12)),
                          subtitle: Text((f['date'] ?? '').toString(),
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                          trailing: Text(formatFcfa(((f['amount'] ?? 0) as num).toDouble()),
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                          onTap: (f['url'] ?? '').toString().isEmpty
                              ? null
                              : () => launchUrl(Uri.parse(f['url'].toString()), mode: LaunchMode.externalApplication),
                        ),
                    ]),
            ),
          ])),
        );
      },
    );
  }
}
