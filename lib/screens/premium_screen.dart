import '../services/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlan = 1; // 0=mensuel, 1=semestriel, 2=annuel
  bool _loading = false;

  List<Map<String, dynamic>> get _plans => [
    {'labelKey': 'prem_free',       'price': '0',      'periodKey': 'prem_forever',     'discountKey': null,           'color': AppTheme.success, 'isFree': true},
    {'labelKey': 'prem_mensuel',    'price': r'$5',    'periodKey': 'prem_per_month',   'discountKey': null,           'color': AppTheme.info,    'isFree': false},
    {'labelKey': 'prem_semestriel', 'price': r'$26',   'periodKey': 'prem_per_6months', 'discountKey': 'prem_saved_15','color': AppTheme.primary, 'isFree': false},
    {'labelKey': 'prem_annuel',     'price': r'$48.5', 'periodKey': 'prem_per_year',    'discountKey': 'prem_saved_35','color': AppTheme.accent,  'isFree': false},
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
                              if (plan['discountKey'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(6)),
                                  child: Text(tr((plan['discountKey'] ?? '') as String), style: GoogleFonts.poppins(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                                ),
                              if (plan['discountKey'] == null) const SizedBox(height: 14),
                              const SizedBox(height: 6),
                              Text(plan['price'] as String, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: selected ? plan['color'] as Color : AppTheme.textPrimary)),
                              
                              Text(tr(plan['periodKey'] as String), style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              Text(tr(plan['labelKey'] as String), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? plan['color'] as Color : AppTheme.textSecondary)),
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
                        : "${tr('prem_start_with')} ${tr(_plans[_selectedPlan]['labelKey'] as String)}",
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
      _onPaymentSuccess(isFree: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(
        planLabel: tr(plan['labelKey'] as String),
        planPrice: plan['price'] as String,
        planPeriod: tr(plan['periodKey'] as String),
        onPaid: () => _onPaymentSuccess(isFree: false),
      ),
    );
  }

  void _onPaymentSuccess({bool isFree = false}) async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _loading = false);

    // Plan payant → badge Premium activé / Plan gratuit → pas de badge
    await AuthService.instance.setPremium(!isFree);
    notifyUserChanged();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PremiumSuccessDialog(
        isFree: isFree,
        onContinue: () {
          Navigator.of(dialogContext).pop(); // ferme dialog
          Navigator.of(context).pop();       // retour profil
        },
        onKyc: () {
          Navigator.of(dialogContext).pop(); // ferme dialog
          Navigator.of(context).pop();       // retour profil
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Redirection vers la vérification d\'identité...', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        },
      ),
    );
  }
}



// ─── Bottom Sheet Paiement ────────────────────────────────────────────────────
class _PaymentSheet extends StatefulWidget {
  final String planLabel, planPrice, planPeriod;
  final VoidCallback onPaid;
  const _PaymentSheet({required this.planLabel, required this.planPrice, required this.planPeriod, required this.onPaid});
  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  int _methodIndex = 0; // 0=MobileMoney, 1=Carte, 2=PayPal
  int _mobileOperator = 0; // 0=Flooz, 1=T-Money, 2=MTN MoMo
  bool _processing = false;

  final _phoneController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardNameController = TextEditingController();

  List<Map<String, dynamic>> get _methods => [
    {"label": tr('pay_mobile_money'), 'subtitle': 'Flooz, T-Money, MTN MoMo...', 'icon': Icons.phone_android_rounded, 'color': Color(0xFF10B981)},
    {"label": tr('pay_card'), "subtitle": tr('pay_card_sub'), 'icon': Icons.credit_card_rounded, 'color': Color(0xFF6366F1)},
    {'label': 'PayPal', "subtitle": tr('pay_intl'), 'icon': Icons.account_balance_wallet_rounded, 'color': Color(0xFF0070BA)},
  ];

  final _operators = ['Flooz', 'T-Money', 'MTN MoMo'];

  @override
  void dispose() {
    _phoneController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          // Titre
          Text(tr('prem_payment_title'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Plan ${widget.planLabel} · ${widget.planPrice}${widget.planPeriod}',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          // Méthodes de paiement
          ...List.generate(_methods.length, (i) {
            final m = _methods[i];
            final selected = i == _methodIndex;
            return GestureDetector(
              onTap: () => setState(() => _methodIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? (m['color'] as Color).withOpacity(0.06) : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? m['color'] as Color : AppTheme.border, width: selected ? 2 : 1),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: (m['color'] as Color).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m['label'] as String, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    Text(m['subtitle'] as String, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                  ])),
                  if (selected)
                    Container(width: 22, height: 22,
                      decoration: BoxDecoration(color: m['color'] as Color, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 14))
                  else
                    Container(width: 22, height: 22,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.border, width: 1.5))),
                ]),
              ),
            );
          }),

          // ── Champs dynamiques selon méthode ───────────────────────────────
          if (_methodIndex == 0) ..._buildMobileMoneyFields(),
          if (_methodIndex == 1) ..._buildCardFields(),
          if (_methodIndex == 2) ..._buildPayPalFields(),

          const SizedBox(height: 16),
          // Résumé
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Plan ${widget.planLabel}', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary)),
                Text(widget.planPrice, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('TVA (0%)', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                Text('0', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                Text(widget.planPrice, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          // Bouton payer
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _processing ? null : _pay,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: AppTheme.primary,
              ),
              child: _processing
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.lock_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('Payer ${widget.planPrice}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
            ),
          ),
          const SizedBox(height: 10),
          Center(child: Text('Paiement sécurisé · SSL · Sans engagement', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint))),
        ]),
      ),
    );
  }

  List<Widget> _buildMobileMoneyFields() => [
    const SizedBox(height: 16),
    Text('Opérateur', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
    const SizedBox(height: 10),
    Row(children: List.generate(_operators.length, (i) {
      final selected = i == _mobileOperator;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _mobileOperator = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: EdgeInsets.only(left: i > 0 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary.withOpacity(0.08) : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? AppTheme.primary : AppTheme.border, width: selected ? 2 : 1),
            ),
            child: Text(_operators[i], textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppTheme.primary : AppTheme.textSecondary)),
          ),
        ),
      );
    })),
    const SizedBox(height: 14),
    Text('Numéro de téléphone', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
    const SizedBox(height: 8),
    TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        hintText: '+228 90 00 00 00',
        hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textHint),
        prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: AppTheme.textSecondary),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  ];

  List<Widget> _buildCardFields() => [
    const SizedBox(height: 16),
    Text('Numéro de carte', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
    const SizedBox(height: 8),
    _inputField(_cardNumberController, 'XXXX XXXX XXXX XXXX', Icons.credit_card_rounded, TextInputType.number),
    const SizedBox(height: 12),
    Text('Nom sur la carte', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
    const SizedBox(height: 8),
    _inputField(_cardNameController, 'JOHN DOE', Icons.person_outline_rounded, TextInputType.text),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Expiration', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        _inputField(_cardExpiryController, 'MM/AA', Icons.calendar_today_outlined, TextInputType.number),
      ])),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CVV', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        _inputField(_cardCvvController, '•••', Icons.lock_outline_rounded, TextInputType.number, obscure: true),
      ])),
    ]),
  ];

  List<Widget> _buildPayPalFields() => [
    const SizedBox(height: 16),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0070BA).withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF0070BA).withOpacity(0.2))),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFF0070BA), size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text('Vous serez redirigé vers PayPal pour finaliser le paiement de manière sécurisée.',
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.4))),
      ]),
    ),
  ];

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, TextInputType type, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textSecondary),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _pay() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context);
    widget.onPaid();
  }
}

// ─── Dialog Succès Premium ────────────────────────────────────────────────────
class _PremiumSuccessDialog extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onKyc;
  final bool isFree;
  const _PremiumSuccessDialog({required this.onContinue, required this.onKyc, this.isFree = false});

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
          // KYC suggestion (payant seulement) — 🚫 DÉSACTIVÉ (25/08/2026) : KYC en pause
          // if (!isFree)
          // Container(
          //   padding: const EdgeInsets.all(14),
          //   decoration: BoxDecoration(color: AppTheme.info.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.info.withOpacity(0.2))),
          //   child: Column(children: [
          //     Row(children: [
          //       const Icon(Icons.verified_user_rounded, color: AppTheme.info, size: 18),
          //       const SizedBox(width: 8),
          //       Expanded(child: Text(tr('prem_verify_id'), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.info))),
          //     ]),
          //     const SizedBox(height: 6),
          //     Text('Augmentez la confiance des acheteurs et débloquez toutes les fonctionnalités Premium.',
          //         style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary, height: 1.4)),
          //     const SizedBox(height: 10),
          //     SizedBox(
          //       width: double.infinity,
          //       child: ElevatedButton(
          //         onPressed: onKyc,
          //         style: ElevatedButton.styleFrom(
          //           backgroundColor: AppTheme.info,
          //           padding: const EdgeInsets.symmetric(vertical: 10),
          //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          //           elevation: 0,
          //         ),
          //         child: Text('Vérifier mon identité maintenant', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          //       ),
          //     ),
          //   ]),
          // ),
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