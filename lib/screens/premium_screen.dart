import '../services/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';
import 'payment_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlan = 1; // 0=gratuit, 1=premium
  bool _loading = false;

  // Un seul palier payant pour l'instant : le backend (initPremiumCheckout)
  // ne gère qu'un tarif/durée fixes (PREMIUM_PRICE_FCFA / PREMIUM_DURATION_DAYS,
  // par défaut 2000 FCFA / 30 jours). Si un jour le backend accepte plusieurs
  // formules (planId → prix/durée), ce sélecteur pourra être ré-étoffé.
  static const double _premiumPriceFcfa = 2000;
  static const int _premiumDurationDays = 30;

  List<Map<String, dynamic>> get _plans => [
    {'label': 'Gratuit',  'price': '0 FCFA', 'period': '', 'color': AppTheme.success, 'isFree': true},
    {'label': 'Premium',  'price': formatFcfa(_premiumPriceFcfa), 'period': ' / $_premiumDurationDays jours', 'color': AppTheme.primary, 'isFree': false},
  ];

  List<Map<String, dynamic>> get _features => [
    {'icon': Icons.star_rounded,              'titleKey': 'feat_badge',     'subtitleKey': 'feat_badge_sub'},
    {'icon': Icons.trending_up_rounded,       'titleKey': 'feat_vedette',   'subtitleKey': 'feat_vedette_sub'},
    {'icon': Icons.photo_library_rounded,     'titleKey': 'feat_photos',    'subtitleKey': 'feat_photos_sub'},
    {'icon': Icons.analytics_rounded,         'titleKey': 'feat_stats',     'subtitleKey': 'feat_stats_sub'},
    {'icon': Icons.support_agent_rounded,     'titleKey': 'feat_support',   'subtitleKey': 'feat_support_sub'},
    {'icon': Icons.verified_rounded,          'titleKey': 'feat_kyc',       'subtitleKey': 'feat_kyc_sub'},
    {'icon': Icons.shield_rounded, 'titleKey': 'feat_assurance', 'subtitleKey': 'feat_assurance_sub'},
    {'icon': Icons.notifications_active_rounded, 'titleKey': 'feat_alertes', 'subtitleKey': 'feat_alertes_sub'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary)),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.workspace_premium_rounded, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text(tr('prem_title'), style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text(tr('prem_subtitle'), style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan selector
                  Text(tr('prem_choose_plan'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(_plans.length, (i) {
                      final plan = _plans[i];
                      final selected = i == _selectedPlan;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPlan = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(left: i > 0 ? 8 : 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selected ? (plan['color'] as Color).withOpacity(0.08) : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: selected ? (plan['color'] as Color) : AppTheme.border, width: selected ? 2 : 1),
                            ),
                            child: Column(children: [
                              const SizedBox(height: 14),
                              const SizedBox(height: 6),
                              Text(plan['price'] as String, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: selected ? plan['color'] as Color : AppTheme.textPrimary)),
                              if ((plan['period'] as String).isNotEmpty)
                                Text(plan['period'] as String, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              Text(plan['label'] as String, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? plan['color'] as Color : AppTheme.textSecondary)),
                            ]),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  // Features
                  Text(tr('prem_whats_included'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  ..._features.map((f) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(f['icon'] as IconData, size: 18, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr(f['titleKey'] as String), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(tr(f['subtitleKey'] as String), style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                      ])),
                      const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                    ]),
                  )),
                  const SizedBox(height: 20),
                  // Free vs Premium comparison
                  Text(tr('prem_free_vs'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _ComparisonTable(),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: (_plans[_selectedPlan]['isFree'] as bool? ?? false)
                        ? 'Commencer gratuitement'
                        : 'Passer Premium — ${_plans[_selectedPlan]['price']}${_plans[_selectedPlan]['period']}',
                    icon: (_plans[_selectedPlan]['isFree'] as bool? ?? false)
                        ? Icons.rocket_launch_rounded
                        : Icons.workspace_premium_rounded,
                    isLoading: _loading,
                    onPressed: _subscribe,
                  ),
                  const SizedBox(height: 10),
                  Center(child: Text(tr('prem_no_commitment'), style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary))),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _subscribe() {
    final plan = _plans[_selectedPlan];
    final isFree = plan['isFree'] as bool? ?? false;

    if (isFree) {
      // Plan gratuit → activation directe sans paiement, pas de badge
      _activateFreePlan();
      return;
    }

    // Plan payant → vrai checkout FedaPay côté backend. Le montant réel est
    // décidé par le serveur (PREMIUM_PRICE_FCFA) ; le badge Premium n'est
    // débloqué que si le webhook FedaPay confirme le paiement — jamais depuis
    // ce client. Voir PaymentScreen._startPremiumCheckout / _checkPremiumStatus.
    //
    // ⚠️ Limite actuelle : le backend ne gère qu'un seul tarif/durée fixes
    // (PREMIUM_PRICE_FCFA / PREMIUM_DURATION_DAYS), alors que ce sélecteur
    // propose 3 formules (mensuel/semestriel/annuel) à des prix différents.
    // Tant que /api/premium/checkout n'accepte pas un planId, le prix
    // effectivement facturé sera celui fixé côté serveur, quel que soit le
    // plan choisi ici.
    _goToRealCheckout();
  }

  Future<void> _goToRealCheckout() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentScreen(type: 'premium')),
    );

    // Au retour de l'écran de paiement, on ne se fie qu'à ce que le serveur
    // a confirmé (PaymentScreen a déjà appelé AuthService.refreshUser() si
    // le webhook FedaPay a validé le paiement pendant l'absence).
    if (!mounted) return;
    if (AuthService.instance.currentUserOrEmpty.isPremium) {
      _showResultDialog(isFree: false);
    }
  }

  void _activateFreePlan() {
    // Le statut Premium est géré par le serveur : choisir "Gratuit" ne
    // doit pas retirer localement un abonnement payé encore actif.
    _showResultDialog(isFree: true);
  }

  void _showResultDialog({required bool isFree}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PremiumSuccessDialog(
        isFree: isFree,
        onContinue: () {
          Navigator.of(dialogContext).pop(); // ferme dialog
          Navigator.of(context).pop();       // retour profil
        },
      ),
    );
  }
}



// ─── Dialog Succès Premium ────────────────────────────────────────────────────
class _PremiumSuccessDialog extends StatelessWidget {
  final VoidCallback onContinue;
  final bool isFree;
  const _PremiumSuccessDialog({required this.onContinue, this.isFree = false});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Icône animée
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 20),
          Text(isFree ? 'Bienvenue sur VelQix !' : 'Félicitations ! 🎉',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text(isFree
              ? 'Votre compte est actif. Passez à un plan payant pour débloquer le badge Premium.'
              : tr('prem_active'),
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          // Badge preview (payant seulement)
          if (!isFree) Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(tr('prem_vendor'), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
          if (!isFree) const SizedBox(height: 24),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onContinue,
            child: Text('Continuer plus tard', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          ),
        ]),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({super.key});

  List<List<String>> _rows(BuildContext context) => [
    [tr('prem_table_listings'),  '3',               tr('prem_table_unlimited')],
    [tr('prem_table_photos'),    '2',               '30'],
    [tr('prem_table_featured'),  '✗',               '✔'],
    [tr('prem_table_badge'),     '✗',               '✔'],
    [tr('prem_table_stats'),     tr('prem_table_basic'),    tr('prem_table_advanced')],
    [tr('prem_table_support'),   tr('prem_table_standard'), tr('prem_table_priority')],
    [tr('prem_table_kyc'),       '48h',             tr('prem_table_express')],
    [tr('prem_table_commission'),'5%',              '2%'],
  ];

  @override
  Widget build(BuildContext context) {
    final rows = _rows(context);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14))),
          child: Row(children: [
            Expanded(flex: 2, child: Text(tr('prem_table_feature'), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white))),
            Expanded(child: Text(tr('prem_table_free'), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.7)), textAlign: TextAlign.center)),
            Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.workspace_premium_rounded, size: 13, color: Colors.amber),
              const SizedBox(width: 4),
              Text('Premium', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber)),
            ])),
          ]),
        ),
        ...rows.asMap().entries.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: e.key % 2 == 0 ? Theme.of(context).colorScheme.surface : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: e.key == rows.length - 1 ? const BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)) : null,
          ),
          child: Row(children: [
            Expanded(flex: 2, child: Text(e.value[0], style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary))),
            Expanded(child: Text(e.value[1], style: GoogleFonts.poppins(fontSize: 11, color: e.value[1] == '✗' ? AppTheme.error : (Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)), textAlign: TextAlign.center)),
            Expanded(child: Text(e.value[2], style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: e.value[2] == '✗' ? AppTheme.error : AppTheme.success), textAlign: TextAlign.center)),
          ]),
        )),
      ]),
    );
  }
}
