// lib/screens/plans_screen.dart
// Formules et tarifs. Les prix et les formules viennent TOUS du serveur :
//   • Particuliers / Professionnels : Premium (GET /premium/plan, durées 1 mois / 6 mois / 1 an)
//   • Entreprises : formules d'agence configurées par l'admin (GET /agency-plans)
// Aucune valeur de secours : si le serveur est injoignable, l'écran le dit et propose de réessayer.
// Le Freemium est durable (pas un essai) ; le Premium fait gagner du temps et de la visibilité,
// mais ne rend PAS un bien « vérifié ».

import 'package:flutter/material.dart';
import '../services/app_translations.dart' show tr;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/safe_url.dart';
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
  String _period = 'month';
  bool _busy = false;
  Future<List<PremiumPeriod>>? _premiumF;
  Future<AgencyPlansInfo>? _agencyF;

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
    _ensureLoaded();
  }

  /// Charge (une seule fois) les données de l'onglet affiché.
  void _ensureLoaded() {
    if (_audience == PlanAudience.entreprise) {
      _agencyF ??= PlanService.instance.getAgencyPlans();
    } else {
      _premiumF ??= PlanService.instance.getPremiumPeriods();
    }
  }

  void _retry() => setState(() {
        _premiumF = null;
        _agencyF = null;
        _ensureLoaded();
      });

  String _msg(Object? e) => (e ?? 'Erreur inconnue').toString().replaceFirst('Exception: ', '');

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pay(Future<String> Function() start) async {
    if (!await requireLogin(context, reason: 'souscrire à cette formule')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final url = await start();
      await launchUrl(safeHttpsUri(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) _snack(_msg(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choosePremium(PremiumPeriod p) => _pay(() => PlanService.instance.checkoutPremium(p.key));

  Future<void> _chooseAgency(AgencyPlanModel plan) => _pay(() async {
        final orgs = await PlanService.instance.getMyOrganizations();
        if (orgs.isEmpty) {
          throw Exception("Créez d'abord votre espace entreprise pour souscrire à une formule.");
        }
        OrganizationRef? org = orgs.length == 1 ? orgs.first : null;
        if (org == null) {
          if (!mounted) throw Exception('Opération annulée.');
          org = await showDialog<OrganizationRef>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('Pour quelle entreprise ?'),
              children: [
                for (final o in orgs)
                  SimpleDialogOption(onPressed: () => Navigator.pop(ctx, o), child: Text(o.name)),
              ],
            ),
          );
          if (org == null) throw Exception('Opération annulée.');
        }
        return PlanService.instance.checkoutAgency(org.id, plan.id);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Formules et tarifs',
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: ListView(children: [
        // En-tête VelQix Premium : pleine largeur (dégradé bleu + médaille)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.workspace_premium_rounded, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(tr('prem_title'),
                style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(tr('prem_subtitle'),
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withOpacity(0.8))),
          ]),
        ),
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SegmentedButton<String>(
                segments: [
                  for (final a in PlanAudience.all)
                    ButtonSegment(value: a, label: Text(PlanAudience.label(a), style: const TextStyle(fontSize: 12))),
                ],
                selected: {_audience},
                onSelectionChanged: (s) => setState(() {
                  _audience = s.first;
                  _period = 'month';
                  _ensureLoaded();
                }),
              ),
              const SizedBox(height: 16),
              if (_audience == PlanAudience.entreprise) _agencySection() else _premiumSection(),
              const SizedBox(height: 20),
              Text('Ce que comprend chaque formule',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _matrixTable(),
              const SizedBox(height: 30),
            ]),
          ),
        ),
      ]),
    );
  }

  // â”€â”€â”€ Particuliers / Professionnels : Premium â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _premiumSection() {
    return FutureBuilder<List<PremiumPeriod>>(
      future: _premiumF,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _loading();
        if (snap.hasError) return _errorBox(_msg(snap.error));
        final periods = snap.data ?? const <PremiumPeriod>[];
        if (periods.isEmpty) return _errorBox('Aucune formule Premium disponible pour le moment.');
        final sel = periods.firstWhere((p) => p.key == _period, orElse: () => periods.first);
        final pro = _audience == PlanAudience.professionnel;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (periods.length > 1) ...[
            Wrap(spacing: 8, children: [
              for (final p in periods)
                ChoiceChip(
                  label: Text(p.label),
                  selected: sel.key == p.key,
                  onSelected: (_) => setState(() => _period = p.key),
                ),
            ]),
            const SizedBox(height: 12),
          ],
          _freeCard(),
          _planCard(
            name: pro ? 'Professionnel Premium' : 'Plus',
            price: '${formatFcfa(sel.priceFcfa)} / ${sel.label}',
            tagline: pro
                ? "Plus d'annonces, statistiques, suivi des contacts et outils de gestion avancés."
                : 'Alertes avancées, statistiques, outils de gestion et avantages de visibilité définis.',
            premium: true,
            saving: _saving(periods, sel),
            action: ElevatedButton(
              onPressed: _busy ? null : () => _choosePremium(sel),
              child: const Text('Choisir cette formule'),
            ),
          ),
        ]);
      },
    );
  }

  /// Économie par rapport au tarif mensuel (calculée sur les prix du serveur).
  String? _saving(List<PremiumPeriod> all, PremiumPeriod p) {
    final months = p.key == '6months' ? 6 : (p.key == 'year' ? 12 : 0);
    if (months == 0) return null;
    final monthly = all.where((x) => x.key == 'month');
    if (monthly.isEmpty) return null;
    final pct = ((1 - p.priceFcfa / (monthly.first.priceFcfa * months)) * 100).round();
    return pct > 0 ? 'Économisez $pct %' : null;
  }

  // â”€â”€â”€ Entreprises : formules d'agence â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _agencySection() {
    return FutureBuilder<AgencyPlansInfo>(
      future: _agencyF,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _loading();
        if (snap.hasError) return _errorBox(_msg(snap.error));
        final info = snap.data!;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _freeCard(),
          if (!info.paidEnabled || info.plans.isEmpty)
            _infoBox("Les abonnements Entreprise ne sont pas encore ouverts : l'espace entreprise reste gratuit pour le moment."),
          if (info.paidEnabled)
            for (final plan in info.plans)
              _planCard(
                name: plan.name,
                price: '${formatFcfa(plan.priceFcfa)} / ${planDurationLabel(plan.durationDays)}',
                tagline: plan.description ?? '',
                premium: true,
                details: [
                  plan.maxMembers == null ? 'Membres illimités' : "Jusqu'à ${plan.maxMembers} membres",
                  plan.maxListings == null ? 'Annonces illimitées' : "Jusqu'à ${plan.maxListings} annonces",
                  if (plan.advancedStats) 'Statistiques avancées',
                ],
                action: ElevatedButton(
                  onPressed: _busy ? null : () => _chooseAgency(plan),
                  child: const Text('Choisir cette formule'),
                ),
              ),
        ]);
      },
    );
  }

  // ─── Éléments communs ─────────────────────────────────────────────────────
  Widget _freeCard() {
    late final String name;
    late final String tagline;
    switch (_audience) {
      case PlanAudience.professionnel:
        name = 'Professionnel gratuit';
        tagline = 'Profil professionnel, annonces de base et gestion simple des prospects.';
        break;
      case PlanAudience.entreprise:
        name = 'Entreprise gratuite';
        tagline = 'Profil entreprise et gestion simple.';
        break;
      default:
        name = 'Gratuit';
        tagline = 'Rechercher, publier une annonce de base et gérer ses contacts.';
    }
    return _planCard(
      name: name,
      price: '0 F',
      tagline: tagline,
      premium: false,
      action: OutlinedButton(
        onPressed: () => Navigator.maybePop(context),
        child: const Text('Commencer gratuitement'),
      ),
    );
  }

  Widget _loading() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );

  Widget _errorBox(String message) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(children: [
          const Icon(Icons.cloud_off_rounded, size: 36, color: Colors.grey),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _retry, child: const Text('Réessayer')),
        ]),
      );

  Widget _infoBox(String message) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: GoogleFonts.poppins(fontSize: 12, height: 1.4)),
          ),
        ]),
      );

  Widget _planCard({
    required String name,
    required String price,
    required String tagline,
    required bool premium,
    required Widget action,
    String? saving,
    List<String> details = const [],
  }) {
    final color = premium ? AppTheme.primary : AppTheme.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: premium ? color : AppTheme.border, width: premium ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(premium ? Icons.workspace_premium_rounded : Icons.card_giftcard_rounded, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
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
        Text(price, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        if (tagline.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(tagline, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
        ],
        if (details.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final d in details)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(children: [
                Icon(Icons.check_rounded, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(d, style: GoogleFonts.poppins(fontSize: 12))),
              ]),
            ),
        ],
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: action),
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
