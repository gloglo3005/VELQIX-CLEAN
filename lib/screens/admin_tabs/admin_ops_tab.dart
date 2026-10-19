// lib/screens/admin_tabs/admin_ops_tab.dart
// Opérations & finances : missions terrain, tarifs et rémunérations, revenus,
// reversements aux agents, journal d'activité.
// Les actions sensibles (tarifs, versements) sont journalisées côté serveur.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/mission_model.dart';
import '../../services/mission_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/net_image.dart';
import '../../widgets/widgets.dart' show formatFcfa;
import 'admin_common.dart';

class AdminOpsTab extends StatefulWidget {
  const AdminOpsTab({super.key});
  @override
  State<AdminOpsTab> createState() => _AdminOpsTabState();
}

class _AdminOpsTabState extends State<AdminOpsTab> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          controller: _tab,
          isScrollable: true,
          labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Missions'),
            Tab(text: 'Tarifs'),
            Tab(text: 'Revenus'),
            Tab(text: 'Reversements'),
            Tab(text: 'Journal'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tab, children: const [
          _MissionsPanel(),
          _PricingPanel(),
          _FinancePanel(),
          _PayoutsPanel(),
          _AuditPanel(),
        ]),
      ),
    ]);
  }
}

// ─── Chargement générique avec erreur lisible ────────────────────────────────
class _Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  const _Loader({super.key, required this.load, required this.builder});
  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  T? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.warning),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 4),
            Text('Voir BACKEND_CHANGES.md pour les routes attendues.',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _reload, child: const Text('Réessayer')),
          ]),
        ),
      );
    }
    return widget.builder(context, _data as T, _reload);
  }
}

Widget _centered(Widget child, {double maxWidth = 900}) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );

double _toNum(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

// ═════════════════════════════ MISSIONS ═══════════════════════════════════════
class _MissionsPanel extends StatefulWidget {
  const _MissionsPanel();
  @override
  State<_MissionsPanel> createState() => _MissionsPanelState();
}

class _MissionsPanelState extends State<_MissionsPanel> {
  String _status = 'all';
  int _version = 0; // force le rechargement

  Future<void> _run(Future<String?> Function() action, String ok) async {
    final err = await action();
    if (!mounted) return;
    if (err != null) {
      adminSnack(context, err, error: true);
      return;
    }
    adminSnack(context, ok);
    setState(() => _version++);
  }

  Future<void> _quote(MissionModel m) async {
    final price = TextEditingController(text: m.price > 0 ? m.price.round().toString() : '');
    final pay = TextEditingController(text: m.agentPay > 0 ? m.agentPay.round().toString() : '');
    final transport = TextEditingController(text: m.transport > 0 ? m.transport.round().toString() : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final p = _toNum(price.text), a = _toNum(pay.text), t = _toNum(transport.text);
        final margin = p - a - t;
        return AlertDialog(
          title: Text('Devis : ${MissionType.label(m.type)}',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (m.details.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(m.details.entries.map((e) => '${e.key} : ${e.value}').join(' · '),
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                ),
              TextField(
                controller: price, keyboardType: TextInputType.number, onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(labelText: 'Prix facturé au client (F)')),
              const SizedBox(height: 10),
              TextField(
                controller: pay, keyboardType: TextInputType.number, onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(labelText: "Rémunération de l'agent (F)")),
              const SizedBox(height: 10),
              TextField(
                controller: transport, keyboardType: TextInputType.number, onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(labelText: 'Transport (F)')),
              const SizedBox(height: 10),
              Text('Marge avant frais de paiement : ${formatFcfa(margin)}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: margin > 0 ? AppTheme.success : AppTheme.error)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(
              onPressed: p > 0 && a > 0 ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Envoyer le devis'),
            ),
          ],
        );
      }),
    );
    final p = _toNum(price.text), a = _toNum(pay.text), t = _toNum(transport.text);
    price.dispose(); pay.dispose(); transport.dispose();
    if (ok != true || !mounted) return;
    await _run(() => AdminOpsService.instance.setQuote(m.id, price: p, agentPay: a, transport: t),
        'Devis envoyé au client.');
  }

  Future<void> _reject(MissionModel m) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser le rapport'),
        content: TextField(
            controller: ctrl, maxLines: 3,
            decoration: const InputDecoration(labelText: "Motif (transmis à l'agent)")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Refuser')),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;
    await _run(() => AdminOpsService.instance.rejectMission(m.id, reason), 'Rapport refusé.');
  }

  Future<void> _validate(MissionModel m) async {
    final ok = await adminConfirm(context,
        title: 'Valider cette mission ?',
        message: m.type == MissionType.verification
            ? "Le bien deviendra « approuvé par VelQix » et ${formatFcfa(m.agentTotal)} seront dus à l'agent."
            : "${formatFcfa(m.agentTotal)} seront dus à l'agent.",
        confirmLabel: 'Valider');
    if (!ok || !mounted) return;
    await _run(() => AdminOpsService.instance.validateMission(m.id), 'Mission validée.');
  }

  void _photo(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(child: NetImage(url: url, fit: BoxFit.contain, displayWidth: 1000)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Loader<List<MissionModel>>(
      key: ValueKey('missions-$_status-$_version'),
      load: () => AdminOpsService.instance.getMissions(status: _status == 'all' ? null : _status),
      builder: (context, list, reload) => _centered(Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: AdminChipRow(
            selected: _status,
            onSelected: (v) => setState(() => _status = v),
            items: const [
              MapEntry('all', 'Toutes'),
              MapEntry('devis', 'Devis à faire'),
              MapEntry('devis_propose', 'Devis envoyés'),
              MapEntry('disponible', 'Disponibles'),
              MapEntry('acceptee', 'En cours'),
              MapEntry('rapport_soumis', 'À valider'),
              MapEntry('contestee', 'Contestées'),
              MapEntry('validee', 'Terminées'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: reload,
            child: list.isEmpty
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text('Aucune mission.',
                            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                      ),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _card(list[i]),
                  ),
          ),
        ),
      ])),
    );
  }

  Widget _card(MissionModel m) {
    final color = MissionStatus.color(m.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(MissionType.icon(m.type), size: 18, color: AppTheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${MissionType.label(m.type)} · ${m.title}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          AdminBadge(MissionStatus.label(m.status), color),
        ]),
        const SizedBox(height: 4),
        Text(
          'Client : ${m.clientName.isEmpty ? '—' : m.clientName}'
          '${m.address.isNotEmpty ? ' · ${m.address}' : ''}',
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          'Prix ${formatFcfa(m.price)} · Agent ${formatFcfa(m.agentPay)} · Transport ${formatFcfa(m.transport)}'
          ' · ${m.isPaid ? 'payé' : 'non payé'}',
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        if (m.reportNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Rapport : ${m.reportNote}',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          ),
        if (m.evidence.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final url in m.evidence)
                GestureDetector(
                  onTap: () => _photo(url),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: NetImage(url: url, width: 56, height: 56, fit: BoxFit.cover),
                    ),
                  ),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (m.status == MissionStatus.devis || m.status == MissionStatus.devisPropose)
            OutlinedButton.icon(
              onPressed: () => _quote(m),
              icon: const Icon(Icons.request_quote_rounded, size: 16),
              label: Text(m.status == MissionStatus.devis ? 'Établir le devis' : 'Modifier le devis'),
            ),
          if (m.status == MissionStatus.rapportSoumis || m.status == MissionStatus.contestee) ...[
            ElevatedButton.icon(
              onPressed: () => _validate(m),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Valider'),
            ),
            OutlinedButton(onPressed: () => _reject(m), child: const Text('Refuser')),
          ],
        ]),
      ]),
    );
  }
}

// ═════════════════════════════ TARIFS ═════════════════════════════════════════
class _PriceField {
  final String key, label, suffix, section;
  final String defaultValue;
  const _PriceField(this.key, this.label, this.suffix, this.section, [this.defaultValue = '']);
}

const _priceFields = [
  _PriceField('verificationPrice', 'Prix de la vérification', 'F', 'Vérification terrain', '3500'),
  _PriceField('verificationAgentPay', 'Rémunération du démarcheur', 'F', 'Vérification terrain', '1500'),
  _PriceField('verificationTransport', 'Transport estimé', 'F', 'Vérification terrain', '300'),
  _PriceField('supportCost', 'Traitement et support (par mission)', 'F', 'Vérification terrain', '200'),
  _PriceField('paymentFeePercent', 'Frais de paiement (hypothèse)', '%', 'Commissions et frais', '3'),
  _PriceField('servicesFeePercent', 'Frais de service VelQix (devis)', '%', 'Commissions et frais'),
  _PriceField('premiumDiscountPercent', 'Remise Premium sur les prestations', '%', 'Commissions et frais', '0'),
  _PriceField('premiumMonthly', 'Premium : 1 mois', 'F', 'Abonnements', '2000'),
  _PriceField('premium6Months', 'Premium : 6 mois (prépayé)', 'F', 'Abonnements', '11000'),
  _PriceField('premium1Year', 'Premium : 1 an (prépayé)', 'F', 'Abonnements', '20000'),
  _PriceField('freeMaxListings', 'Annonces max. en Freemium', '', 'Limites des offres'),
  _PriceField('premiumMaxListings', 'Annonces max. en Premium', '', 'Limites des offres'),
  _PriceField('premiumFeaturedCredits', 'Crédits de mise en avant (Premium)', '', 'Limites des offres'),
];

class _PricingPanel extends StatelessWidget {
  const _PricingPanel();
  @override
  Widget build(BuildContext context) => _Loader<Map<String, dynamic>>(
        load: AdminOpsService.instance.getPricing,
        builder: (context, data, reload) => _PricingForm(initial: data, onSaved: reload),
      );
}

class _PricingForm extends StatefulWidget {
  final Map<String, dynamic> initial;
  final Future<void> Function() onSaved;
  const _PricingForm({required this.initial, required this.onSaved});
  @override
  State<_PricingForm> createState() => _PricingFormState();
}

class _PricingFormState extends State<_PricingForm> {
  late final Map<String, TextEditingController> _c = {
    for (final f in _priceFields)
      f.key: TextEditingController(text: widget.initial[f.key]?.toString() ?? f.defaultValue),
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(String k) => _toNum(_c[k]!.text);

  Future<void> _save() async {
    // Seuls les champs modifiés sont envoyés (et journalisés)
    final changed = <String, dynamic>{};
    for (final f in _priceFields) {
      final now = _c[f.key]!.text.trim();
      final before = widget.initial[f.key]?.toString() ?? f.defaultValue;
      if (now != before && now.isNotEmpty) changed[f.key] = num.tryParse(now) ?? now;
    }
    if (changed.isEmpty) {
      adminSnack(context, 'Aucune modification.');
      return;
    }
    final ok = await adminConfirm(context,
        title: 'Modifier les tarifs ?',
        message: '${changed.length} valeur(s) vont changer pour tous les utilisateurs. '
            "L'action est enregistrée dans le journal d'activité.",
        confirmLabel: 'Enregistrer',
        danger: true);
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final err = await AdminOpsService.instance.savePricing(changed);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      adminSnack(context, err, error: true);
      return;
    }
    adminSnack(context, 'Tarifs enregistrés.');
    await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final price = _v('verificationPrice');
    final fee = price * _v('paymentFeePercent') / 100;
    final contribution =
        price - _v('verificationAgentPay') - _v('verificationTransport') - fee - _v('supportCost');
    final pct = price > 0 ? contribution / price * 100 : 0;
    final sections = <String>{for (final f in _priceFields) f.section};
    return _centered(
      ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (contribution > 0 ? AppTheme.success : AppTheme.error).withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Simulation : une vérification',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Contribution VelQix : ${formatFcfa(contribution)} (${pct.toStringAsFixed(0)} % du prix)\n'
              'avant frais fixes, impôts et autres charges. Frais de paiement estimés : ${formatFcfa(fee)}.',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ]),
        ),
        for (final s in sections) ...[
          const SizedBox(height: 18),
          Text(s, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final f in _priceFields.where((f) => f.section == s))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _c[f.key],
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: f.label, suffixText: f.suffix),
              ),
            ),
        ],
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Enregistrer les tarifs'),
        ),
        const SizedBox(height: 8),
        Text(
          'Les prix de visite accompagnée et d\'entretien sont fixés au cas par cas, par devis (onglet Missions).',
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
        ),
      ]),
      maxWidth: 640,
    );
  }
}

// ═════════════════════════════ REVENUS ════════════════════════════════════════
class _FinancePanel extends StatelessWidget {
  const _FinancePanel();

  static const _labels = <MapEntry<String, String>>[
    MapEntry('collected', 'Fonds encaissés'),
    MapEntry('missionsRevenue', 'Contribution des missions'),
    MapEntry('subscriptionsRevenue', 'Abonnements'),
    MapEntry('adsRevenue', 'Visibilité payante'),
    MapEntry('commissions', 'Commissions de services'),
    MapEntry('dueToAgents', 'Dû aux agents'),
    MapEntry('paidToAgents', 'Déjà versé aux agents'),
    MapEntry('refunds', 'Remboursements'),
    MapEntry('profit', 'Résultat estimé'),
  ];

  @override
  Widget build(BuildContext context) => _Loader<Map<String, dynamic>>(
        load: AdminOpsService.instance.getFinanceSummary,
        builder: (context, data, reload) => _centered(
          RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text('Chiffre d\'affaires, sommes dues aux agents, fonds encaissés et bénéfice sont distincts.',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final e in _labels)
                  if (data.containsKey(e.key))
                    Container(
                      width: 200,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(formatFcfa(_toNum(data[e.key])),
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(e.value,
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                      ]),
                    ),
              ]),
            ]),
          ),
          maxWidth: 760,
        ),
      );
}

// ═════════════════════════════ REVERSEMENTS ═══════════════════════════════════
class _PayoutsPanel extends StatefulWidget {
  const _PayoutsPanel();
  @override
  State<_PayoutsPanel> createState() => _PayoutsPanelState();
}

class _PayoutsPanelState extends State<_PayoutsPanel> {
  String _status = 'du';
  int _version = 0;

  Future<void> _pay(Map<String, dynamic> p) async {
    final amount = formatFcfa(_toNum(p['amount']));
    final ok = await adminConfirm(context,
        title: 'Marquer comme payé ?',
        message: 'Confirmez que $amount ont bien été versés à ${p['agentName'] ?? 'cet agent'}. '
            "L'action est enregistrée dans le journal et ne peut pas être annulée.",
        confirmLabel: 'Confirmer',
        danger: true);
    if (!ok || !mounted) return;
    final err = await AdminOpsService.instance.payPayout(p['id'].toString());
    if (!mounted) return;
    if (err != null) {
      adminSnack(context, err, error: true);
      return;
    }
    adminSnack(context, 'Versement enregistré.');
    setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    return _Loader<List<Map<String, dynamic>>>(
      key: ValueKey('payouts-$_status-$_version'),
      load: () => AdminOpsService.instance.getPayouts(status: _status),
      builder: (context, list, reload) => _centered(Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: AdminChipRow(
            selected: _status,
            onSelected: (v) => setState(() => _status = v),
            items: const [
              MapEntry('du', 'À payer'),
              MapEntry('en_attente', 'En validation'),
              MapEntry('paye', 'Payés'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: reload,
            child: list.isEmpty
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text('Aucun reversement.',
                            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                      ),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final p = list[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text((p['agentName'] ?? 'Agent').toString(),
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text((p['missionTitle'] ?? '').toString(),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                            ]),
                          ),
                          Text(formatFcfa(_toNum(p['amount'])),
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                          if (_status == 'du') ...[
                            const SizedBox(width: 10),
                            OutlinedButton(onPressed: () => _pay(p), child: const Text('Marquer payé')),
                          ],
                        ]),
                      );
                    },
                  ),
          ),
        ),
      ])),
    );
  }
}

// ═════════════════════════════ JOURNAL ════════════════════════════════════════
class _AuditPanel extends StatelessWidget {
  const _AuditPanel();

  String _date(dynamic v) {
    final d = DateTime.tryParse('${v ?? ''}')?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) => _Loader<List<Map<String, dynamic>>>(
        load: AdminOpsService.instance.getAuditLogs,
        builder: (context, list, reload) => _centered(
          RefreshIndicator(
            onRefresh: reload,
            child: list.isEmpty
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text('Aucune action enregistrée.',
                            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                      ),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.border),
                    itemBuilder: (_, i) {
                      final l = list[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history_rounded, size: 20),
                        title: Text((l['action'] ?? '').toString(),
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${l['actorName'] ?? 'Système'} · ${_date(l['createdAt'])}'
                          '${(l['details'] ?? '').toString().isNotEmpty ? '\n${l['details']}' : ''}',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      );
                    },
                  ),
          ),
          maxWidth: 760,
        ),
      );
}
