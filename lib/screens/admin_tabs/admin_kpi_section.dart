// lib/screens/admin_tabs/admin_kpi_section.dart
// Indicateurs de performance et d'activité du tableau de bord (ANA-01, §15.1 et §17).
// Données : AnalyticsService (GET /admin/analytics). Aucune valeur n'est calculée
// ni estimée ici : l'app affiche ce que le serveur renvoie, « — » quand il n'y a
// pas de base de calcul, et liste à part les indicateurs non mesurés.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/analytics_service.dart';
import '../../services/mission_service.dart' show AdminOpsService;
import '../../theme/app_theme.dart';
import 'admin_common.dart' show AdminChipRow;

// ─── Mise en forme ───────────────────────────────────────────────────────────
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
num? _num(dynamic v) => v is num ? v : null;

String _grouped(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

String _count(dynamic v) => _num(v) == null ? '—' : _grouped(_num(v)!.round());
String _fcfa(dynamic v) => _num(v) == null ? '—' : '${_grouped(_num(v)!.round())} FCFA';

String _pct(dynamic v) {
  final n = _num(v);
  if (n == null) return '—';
  final s = n.toStringAsFixed(1);
  return '${(s.endsWith('.0') ? s.substring(0, s.length - 2) : s).replaceAll('.', ',')} %';
}

String _hours(dynamic v) {
  final n = _num(v);
  if (n == null) return '—';
  String trim(double x) {
    final s = x.toStringAsFixed(1);
    return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s).replaceAll('.', ',');
  }
  if (n < 1) return '${(n * 60).round()} min';
  if (n < 48) return '${trim(n.toDouble())} h';
  return '${trim(n / 24)} j';
}

String _serviceLabel(String s) {
  switch (s) {
    case 'verification': return 'Vérification terrain';
    case 'visite':       return 'Visite accompagnée';
    case 'entretien':    return 'Entretien';
    case 'premium':      return 'Abonnements Premium';
    default:             return s;
  }
}

class AdminKpiSection extends StatefulWidget {
  const AdminKpiSection({super.key});

  @override
  State<AdminKpiSection> createState() => _AdminKpiSectionState();
}

class _AdminKpiSectionState extends State<AdminKpiSection> {
  int _days = 30;
  Map<String, dynamic>? _data;
  num? _commissions; // cumul depuis le lancement (route finance, facultatif)
  bool _loading = true;
  String? _error;
  int _seq = 0; // ignore les réponses d'une période devenue obsolète

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await AnalyticsService.instance.overview(days: _days);
      if (!mounted || seq != _seq) return;
      setState(() => _data = d);
      _loadCommissions(seq);
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  // Commissions perçues : déjà calculées par la route finance (cumul). Facultatif.
  Future<void> _loadCommissions(int seq) async {
    try {
      final f = await AdminOpsService.instance.getFinanceSummary();
      if (mounted && seq == _seq) setState(() => _commissions = _num(f['commissions']));
    } catch (_) {
      if (mounted && seq == _seq) setState(() => _commissions = null);
    }
  }

  // ─── Briques ───────────────────────────────────────────────────────────────
  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
      );

  Widget _tile(String label, String value, {String? hint}) => Container(
        width: 164,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primary)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
          ],
        ]),
      );

  Widget _tiles(List<Widget> tiles) => Wrap(spacing: 10, runSpacing: 10, children: tiles);

  Widget _rows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return Text('Aucune donnée sur la période.',
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary));
    }
    final max = rows.map((r) => _num(r['count']) ?? 0).fold<num>(1, (a, b) => b > a ? b : a);
    return Column(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(
              width: 120,
              child: Text('${r['label']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ((_num(r['count']) ?? 0) / max).toDouble(),
                  minHeight: 8,
                  backgroundColor: AppTheme.border,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(_count(r['count']), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
    ]);
  }

  // ─── Rendu ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text('Indicateurs', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Actualiser',
          onPressed: _loading ? null : _load,
        ),
      ]),
      AdminChipRow(
        items: [for (final d in AnalyticsService.periods) MapEntry('$d', '$d jours')],
        selected: '$_days',
        onSelected: (v) {
          final d = int.tryParse(v);
          if (d == null || d == _days) return;
          setState(() => _days = d);
          _load();
        },
      ),
      if (_loading && _data != null) const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      if (_data == null) _placeholder() else _content(_data!),
    ]);
  }

  Widget _placeholder() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        Text(_error ?? 'Indicateurs indisponibles.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
      ]),
    );
  }

  Widget _content(Map<String, dynamic> d) {
    final users = _m(d['users']);
    final listings = _m(d['listings']);
    final requests = _m(d['requests']);
    final reports = _m(d['reports']);
    final missions = _m(d['missions']);
    final finance = _m(d['finance']);
    final notMeasured = _l(d['notMeasured']);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.error)),
        ),

      _title('Utilisateurs'),
      _tiles([
        _tile('Inscrits', _count(users['total'])),
        _tile('Nouveaux', _count(users['new']), hint: 'sur la période'),
        _tile('Actifs', _count(users['active']),
            hint: 'au moins une action : message, demande, signalement, mission, annonce, connexion'),
        _tile('Nouveaux annonceurs', _count(users['newAdvertisers']), hint: 'première annonce sur la période'),
        _tile('Comptes suspendus', _count(users['suspended'])),
      ]),

      _title('Annonces'),
      _tiles([
        _tile('Publiées', _count(listings['published'])),
        _tile('Actives', _count(listings['active']), hint: 'disponibles ou à reconfirmer'),
        _tile('Suspendues', _count(listings['suspended'])),
        _tile('Archivées', _count(listings['archived'])),
        _tile('Indisponibles', _count(listings['unavailable']), hint: 'louées, vendues…'),
        _tile('En attente de validation', _count(listings['awaitingModeration'])),
        _tile('Déclarées louées ou vendues', _count(listings['declaredRentedOrSold']), hint: 'sur la période'),
      ]),

      _title('Demandes et fiabilité'),
      _tiles([
        _tile('Demandes de visite', _count(requests['visits']), hint: 'sur la période'),
        _tile('Demandes de confirmation', _count(requests['confirmationRequests']), hint: 'sur la période'),
        _tile('Confirmations reçues', _count(requests['confirmationsReceived'])),
        _tile('Demandes de contact', _count(requests['contactRequests']), hint: 'nouvelles conversations'),
        _tile('Taux de réponse des annonceurs', _pct(requests['responseRate']), hint: 'demandes arrivées à terme'),
        _tile('Délai moyen de réponse', _hours(requests['avgResponseHours'])),
        _tile('Demandes confirmées', _pct(requests['confirmedShare'])),
        _tile('Demandes révélant une indisponibilité', _pct(requests['unavailableShare'])),
        _tile('Signalements en attente', _count(reports['pending'])),
        _tile('Signalements reçus', _count(reports['created']), hint: 'sur la période'),
        _tile('Annonces signalées obsolètes', _pct(reports['obsoleteListingRate']), hint: 'part des annonces publiées'),
        _tile('Délai de traitement des signalements', _hours(reports['avgProcessingHours'])),
      ]),

      _title('Services sur le terrain'),
      _tiles([
        _tile('Missions proposées', _count(missions['proposed']), hint: 'créées sur la période'),
        _tile('Missions acceptées', _count(missions['accepted'])),
        _tile('Missions réalisées', _count(missions['done']), hint: 'validées sur la période'),
        _tile('Missions ouvertes', _count(missions['open']), hint: 'en cours, toutes périodes'),
        _tile('Taux d\'annulation', _pct(missions['cancellationRate'])),
        _tile('Taux de contestation', _pct(missions['contestRate']), hint: 'missions rapportées'),
        _tile('Délai d\'acceptation', _hours(missions['avgAcceptHours']), hint: 'du paiement à l\'acceptation'),
        _tile('Délai de réalisation', _hours(missions['avgDoneHours']), hint: 'du paiement à la validation'),
        _tile('Coût moyen d\'intervention', _fcfa(missions['avgCost']), hint: 'agent + transport'),
        _tile('Marge par mission', _fcfa(missions['avgMargin'])),
      ]),

      _title('Finances'),
      _tiles([
        _tile('Chiffre d\'affaires', _fcfa(finance['totalRevenue']), hint: 'missions validées + Premium, sur la période'),
        _tile('Clients payants', _count(finance['payingUsers'])),
        _tile('Revenu moyen par client payant', _fcfa(finance['avgRevenuePerPayer'])),
        _tile('Conversion vers les services payants', _pct(finance['payingRate']), hint: 'part des comptes ayant payé'),
        _tile('Paiements en attente', _fcfa(_m(finance['pendingPayments'])['amount']),
            hint: '${_count(_m(finance['pendingPayments'])['count'])} paiement(s)'),
        _tile('Dû aux agents', _fcfa(_m(finance['dueToAgents'])['amount']),
            hint: '${_count(_m(finance['dueToAgents'])['count'])} versement(s)'),
        _tile('Frais de paiement', _fcfa(finance['paymentFees']), hint: 'missions, sur la période'),
        _tile('Remboursements', _fcfa(_m(finance['refunds'])['amount']),
            hint: '${_count(_m(finance['refunds'])['count'])} sur la période'),
        _tile('Remboursements à faire', _fcfa(_m(finance['toRefund'])['amount']),
            hint: '${_count(_m(finance['toRefund'])['count'])} paiement(s)'),
        _tile('À décaisser prochainement', _fcfa(finance['cashNeeded']), hint: 'dû aux agents + remboursements à faire'),
        if (_commissions != null)
          _tile('Commissions perçues', _fcfa(_commissions), hint: 'cumul depuis le lancement'),
      ]),
      _title('Chiffre d\'affaires et marge par service'),
      for (final s in _l(finance['byService']))
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_serviceLabel('${s['service']}'),
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(
                  '${_count(s['missions'])} ${s['service'] == 'premium' ? 'achat(s)' : 'mission(s)'}',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fcfa(s['revenue']), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
              Text('marge ${_fcfa(s['grossMargin'])}',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
          ]),
        ),

      _title('Répartition géographique'),
      Text('Annonces actives par ville', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      _rows(_l(listings['activeByCity'])),
      const SizedBox(height: 12),
      Text('Missions par zone (période)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      _rows(_l(missions['byZone'])),

      if (notMeasured.isNotEmpty) ...[
        _title('Non mesurés pour l\'instant'),
        Text(
          'Ces indicateurs du cahier des charges n\'ont pas de donnée source : ils ne sont pas affichés plutôt que d\'être estimés.',
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        for (final n in notMeasured)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.remove_circle_outline_rounded, size: 14, color: AppTheme.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${n['label']} — ${n['reason']}',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
              ),
            ]),
          ),
      ],
    ]);
  }
}
