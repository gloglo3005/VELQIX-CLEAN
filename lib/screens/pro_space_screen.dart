// lib/screens/pro_space_screen.dart
// Velqix Pro : agents immobiliers, démarcheurs indépendants, commerciaux, vendeurs.
// Accessible aux indépendants qui travaillent seuls : pas d'outils d'entreprise imposés.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/plan_service.dart';
import '../services/spaces_service.dart';
import '../theme/app_theme.dart';
import '../widgets/async_panel.dart';
import '../widgets/widgets.dart' show EmptyState, formatFcfa;
import 'add_listing_screen.dart';
import 'my_listings_screen.dart';
import 'my_services_screen.dart';
import 'plans_screen.dart';

const _leadStatuses = <MapEntry<String, String>>[
  MapEntry('nouveau', 'Nouveau'),
  MapEntry('contacte', 'Contacté'),
  MapEntry('visite', 'Visite prévue'),
  MapEntry('conclu', 'Conclu'),
  MapEntry('perdu', 'Perdu'),
];

class ProSpaceScreen extends StatefulWidget {
  const ProSpaceScreen({super.key});
  @override
  State<ProSpaceScreen> createState() => _ProSpaceScreenState();
}

class _ProSpaceScreenState extends State<ProSpaceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Velqix Pro', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Tableau de bord'), Tab(text: 'Prospects'), Tab(text: 'Abonnement')],
        ),
      ),
      body: TabBarView(controller: _tab, children: const [_ProDashboard(), _ProLeads(), _ProSubscription()]),
    );
  }
}

// ─── Tableau de bord ─────────────────────────────────────────────────────────
class _ProDashboard extends StatelessWidget {
  const _ProDashboard();

  @override
  Widget build(BuildContext context) {
    return AsyncPanel<Map<String, dynamic>>(
      load: ProService.instance.getDashboard,
      builder: (context, data, reload) => RefreshIndicator(
        onRefresh: reload,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              statGrid(data, const [
                MapEntry('activeListings', 'Annonces actives'),
                MapEntry('views', 'Vues'),
                MapEntry('contacts', 'Contacts reçus'),
                MapEntry('pendingRequests', 'Demandes en attente'),
                MapEntry('visitsPlanned', 'Visites prévues'),
                MapEntry('verified', 'Biens vérifiés'),
              ]),
              const SizedBox(height: 20),
              Text('Raccourcis', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const AddListingScreen())),
                  icon: const Icon(Icons.add_home_work_rounded, size: 18),
                  label: const Text('Publier une annonce'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const MyListingsScreen())),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Modifier / archiver mes annonces'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const MyServicesScreen())),
                  icon: const Icon(Icons.fact_check_rounded, size: 18),
                  label: const Text('Vérifications et rapports'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Prospects : contacts, visites, demandes reçues ──────────────────────────
class _ProLeads extends StatefulWidget {
  const _ProLeads();
  @override
  State<_ProLeads> createState() => _ProLeadsState();
}

class _ProLeadsState extends State<_ProLeads> {
  int _version = 0;
  String _filter = 'all';

  String _label(String s) => _leadStatuses.where((e) => e.key == s).map((e) => e.value).firstOrNull ?? s;

  Future<void> _setStatus(Map<String, dynamic> lead, String status) async {
    final err = await ProService.instance.updateLead(lead['id'].toString(), status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Statut mis à jour.'),
      backgroundColor: err == null ? null : AppTheme.error,
      behavior: SnackBarBehavior.floating,
    ));
    if (err == null) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPanel<List<Map<String, dynamic>>>(
      key: ValueKey('leads-$_version'),
      load: ProService.instance.getLeads,
      builder: (context, all, reload) {
        final list = _filter == 'all' ? all : all.where((l) => l['status'] == _filter).toList();
        return Column(children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final e in [const MapEntry('all', 'Tous'), ..._leadStatuses])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value, style: GoogleFonts.poppins(fontSize: 12)),
                      selected: _filter == e.key,
                      onSelected: (_) => setState(() => _filter = e.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(icon: Icons.people_outline_rounded, title: 'Aucun prospect pour le moment')
                : RefreshIndicator(
                    onRefresh: reload,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final l = list[i];
                            final phone = (l['phone'] ?? '').toString();
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(
                                    child: Text((l['name'] ?? 'Contact').toString(),
                                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Changer le statut',
                                    onSelected: (s) => _setStatus(l, s),
                                    itemBuilder: (_) => [
                                      for (final s in _leadStatuses)
                                        PopupMenuItem(value: s.key, child: Text(s.value)),
                                    ],
                                    child: Chip(
                                      label: Text(_label((l['status'] ?? 'nouveau').toString()),
                                          style: GoogleFonts.poppins(fontSize: 11)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ]),
                                if ((l['propertyTitle'] ?? '').toString().isNotEmpty)
                                  Text('Bien : ${l['propertyTitle']}',
                                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                                if ((l['message'] ?? '').toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('« ${l['message']} »',
                                        style: GoogleFonts.poppins(fontSize: 12)),
                                  ),
                                if (phone.isNotEmpty)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                                      icon: const Icon(Icons.call_rounded, size: 16),
                                      label: Text(phone),
                                    ),
                                  ),
                              ]),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ]);
      },
    );
  }
}

// ─── Abonnement, paiements et factures ───────────────────────────────────────
class _ProSubscription extends StatelessWidget {
  const _ProSubscription();

  String _date(DateTime? d) =>
      d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return AsyncPanel<SubscriptionInfo>(
      load: PlanService.instance.getMySubscription,
      builder: (context, sub, reload) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Formule actuelle', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                Text(sub.planName, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800)),
                if (sub.expiresAt != null)
                  Text('${sub.status == 'actif' ? 'Valable jusqu\'au' : 'Expirée le'} ${_date(sub.expiresAt)}',
                      style: GoogleFonts.poppins(fontSize: 12)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PlansScreen(initialAudience: PlanAudience.professionnel))),
                  child: const Text('Voir / changer de formule'),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Text('Paiements et factures', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            AsyncPanel<List<Map<String, dynamic>>>(
              load: PlanService.instance.getInvoices,
              builder: (context, items, _) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text('Aucune facture pour le moment.',
                            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                      ),
                    )
                  : Column(children: [
                      for (final f in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long_rounded),
                          title: Text((f['label'] ?? 'Facture').toString(),
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text((f['date'] ?? '').toString(),
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                          trailing: Text(
                              formatFcfa(((f['amount'] ?? 0) as num).toDouble()),
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                          onTap: (f['url'] ?? '').toString().isEmpty
                              ? null
                              : () => launchUrl(Uri.parse(f['url'].toString()),
                                  mode: LaunchMode.externalApplication),
                        ),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}
