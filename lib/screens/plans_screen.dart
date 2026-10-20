// lib/screens/plans_screen.dart
// Formules Freemium / Premium par profil, formules prépayées, matrice des
// fonctionnalités. Le Freemium est durable (pas un essai) ; le Premium fait gagner
// du temps et de la visibilité, mais ne rend PAS un bien « vérifié ».

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/plan_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_gate.dart';
import '../widgets/widgets.dart' show formatFcfa;

class PlansScreen extends StatefulWidget {
  final String initialAudience;
  const PlansScreen({super.key, this.initialAudience = PlanAudience.particulier});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late String _audience = widget.initialAudience;
  List<PlanModel> _plans = PlanService.fallback;
  String _period = 'month';
  bool _busy = false;

  // Matrice du cahier des charges : fonctionnalité → (Freemium, Premium)
  static const _matrix = <List<String>>[
    ['Recherche et consultation des annonces', 'Oui', 'Oui'],
    ['Création de compte et profil', 'Oui', 'Oui'],
    ["Publication d'annonces de base", 'Gratuite', 'Incluse'],
    ['Modification et gestion des annonces', 'Basique', 'Avancée'],
    ['Favoris et alertes', 'Basiques', 'Personnalisables'],
    ['Statistiques de consultation', 'Simples', 'Détaillées'],
    ['Mise en avant des annonces', "Paiement à l'unité", 'Avantages ou crédits selon le forfait'],
    ['Gestion de plusieurs biens', 'Limitée', 'Étendue'],
    ['Export et rapports professionnels', 'Non ou limité', 'Selon le forfait'],
    ["Gestion d'équipe", 'Non', 'Pour les entreprises'],
    ["Vérification physique d'un bien", 'Payante', 'Payante, éventuellement à tarif préférentiel'],
    ['Entretien et visites accompagnées', 'Payants', 'Payants'],
  ];

  @override
  void initState() {
    super.initState();
    PlanService.instance.getPlans().then((p) {
      if (mounted) setState(() => _plans = p);
    });
  }

  List<PlanModel> get _current => _plans.where((p) => p.audience == _audience).toList()
    ..sort((a, b) => (a.premium ? 1 : 0).compareTo(b.premium ? 1 : 0));

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _choose(PlanModel p) async {
    if (p.isFree) {
      Navigator.maybePop(context);
      return;
    }
    if (!await requireLogin(context, reason: 'souscrire à cette formule')) return;
    if (!mounted) return;
    if (p.onQuote) {
      await _askQuote(p);
      return;
    }
    setState(() => _busy = true);
    try {
      final url = await PlanService.instance.checkout(p.id, _period);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askQuote(PlanModel p) async {
    final ctrl = TextEditingController();
    final msg = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Devis : ${p.name}'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Votre besoin (équipe, nombre de biens…)',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Envoyer')),
        ],
      ),
    );
    ctrl.dispose();
    if (msg == null || !mounted) return;
    final err = await PlanService.instance.requestQuote(p.id, message: msg);
    if (mounted) _snack(err ?? "Demande envoyée : l'équipe VelQix vous contacte.", error: err != null);
  }

  @override
  Widget build(BuildContext context) {
    final plans = _current;
    final prepaid = plans.where((p) => p.premium && p.price6Months != null).isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text('Formules et tarifs',
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            SegmentedButton<String>(
              segments: [
                for (final a in PlanAudience.all)
                  ButtonSegment(value: a, label: Text(PlanAudience.label(a), style: const TextStyle(fontSize: 12))),
              ],
              selected: {_audience},
              onSelectionChanged: (s) => setState(() {
                _audience = s.first;
                _period = 'month';
              }),
            ),
            const SizedBox(height: 16),
            if (prepaid) ...[
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('1 mois'), selected: _period == 'month', onSelected: (_) => setState(() => _period = 'month')),
                ChoiceChip(label: const Text('6 mois'), selected: _period == '6months', onSelected: (_) => setState(() => _period = '6months')),
                ChoiceChip(label: const Text('1 an'), selected: _period == 'year', onSelected: (_) => setState(() => _period = 'year')),
              ]),
              const SizedBox(height: 12),
            ],
            for (final p in plans) _planCard(p),
            const SizedBox(height: 20),
            Text('Ce que comprend chaque formule',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _matrixTable(),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }

  String _priceLine(PlanModel p) {
    if (p.isFree) return '0 F';
    if (p.onQuote) return 'Sur devis';
    switch (_period) {
      case '6months':
        return p.price6Months != null ? '${formatFcfa(p.price6Months!)} / 6 mois' : '${formatFcfa(p.priceMonthly!)} / mois';
      case 'year':
        return p.price1Year != null ? '${formatFcfa(p.price1Year!)} / an' : '${formatFcfa(p.priceMonthly!)} / mois';
      default:
        return '${formatFcfa(p.priceMonthly!)} / mois';
    }
  }

  String? _saving(PlanModel p) {
    final m = p.priceMonthly;
    if (m == null || m <= 0) return null;
    if (_period == '6months' && p.price6Months != null) {
      final pct = ((1 - p.price6Months! / (m * 6)) * 100).round();
      return pct > 0 ? 'Économisez $pct %' : null;
    }
    if (_period == 'year' && p.price1Year != null) {
      final pct = ((1 - p.price1Year! / (m * 12)) * 100).round();
      return pct > 0 ? 'Économisez $pct %' : null;
    }
    return null;
  }

  Widget _planCard(PlanModel p) {
    final color = p.premium ? AppTheme.primary : AppTheme.success;
    final saving = _saving(p);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.premium ? color : AppTheme.border, width: p.premium ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(p.premium ? Icons.workspace_premium_rounded : Icons.card_giftcard_rounded, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(p.name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          if (saving != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(saving,
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.success)),
            ),
        ]),
        const SizedBox(height: 6),
        Text(_priceLine(p), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(p.tagline, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: p.premium
              ? ElevatedButton(
                  onPressed: _busy ? null : () => _choose(p),
                  child: Text(p.onQuote ? 'Demander un devis' : 'Choisir cette formule'),
                )
              : OutlinedButton(onPressed: () => _choose(p), child: const Text('Commencer gratuitement')),
        ),
      ]),
    );
  }

  Widget _matrixTable() {
    TextStyle head = GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700);
    TextStyle cell = GoogleFonts.poppins(fontSize: 11);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(flex: 5, child: Text('Fonctionnalité', style: head)),
            Expanded(flex: 3, child: Text('Freemium', style: head)),
            Expanded(flex: 4, child: Text('Premium', style: head)),
          ]),
        ),
        for (final r in _matrix) ...[
          Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 5, child: Text(r[0], style: cell.copyWith(fontWeight: FontWeight.w500))),
              Expanded(flex: 3, child: Text(r[1], style: cell)),
              Expanded(flex: 4, child: Text(r[2], style: cell)),
            ]),
          ),
        ],
      ]),
    );
  }
}
