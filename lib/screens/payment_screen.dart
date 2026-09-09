import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/app_translations.dart';
import '../services/transaction_service.dart';

// ═══════════════════════════════════════════════════════════════════
// PAYMENT SCREEN — Intégration FedaPay (sandbox)
// ═══════════════════════════════════════════════════════════════════

class PaymentScreen extends StatefulWidget {
  final PropertyModel? property; // null pour le type 'premium' (pas de bien associé)
  final String type; // 'location' | 'achat' | 'premium'
  final double? montantOverride; // affichage indicatif seulement pour le premium —
  // le montant réellement facturé est toujours décidé par le backend (voir _startFedaPay)
  final String? descriptionOverride;

  const PaymentScreen({
    super.key,
    this.property,
    required this.type,
    this.montantOverride,
    this.descriptionOverride,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with WidgetsBindingObserver {
  // ── Formulaire ─────────────────────────────────────────────────────────────
  DateTime _dateDebut = DateTime.now().add(const Duration(days: 1));
  DateTime? _dateFin;
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // ── État ───────────────────────────────────────────────────────────────────
  bool _processing = false;
  String? _errorMsg;

  // ── Confirmation Premium (post-redirection FedaPay) ─────────────────────────
  // Le statut Premium ne vient JAMAIS d'une valeur locale : on interroge
  // toujours le backend (via AuthService.refreshUser → GET /auth/me), qui ne
  // reflète isPremium que si le webhook FedaPay a confirmé le paiement.
  bool _awaitingConfirmation = false;
  bool _checkingStatus = false;

  // ── Calculs ────────────────────────────────────────────────────────────────
  int get _nbJours => _dateFin != null
      ? _dateFin!.difference(_dateDebut).inDays.clamp(1, 9999)
      : 1;

  double get _baseAmount {
    if (widget.montantOverride != null) return widget.montantOverride!;
    if (widget.type == 'location') {
      // Utiliser prixParJour si dispo, sinon prix fixe
      final rawJour = widget.property!.prixParJour ?? '';
      final numStr  = rawJour.replaceAll(RegExp(r'[^\d]'), '');
      final parJour = double.tryParse(numStr) ?? 50000.0;
      return parJour * _nbJours;
    }
    // Premium : pas de bien associé (widget.property est null) et pas de
    // montantOverride passé par premium_screen.dart — le vrai montant est de
    // toute façon décidé par le backend au moment du checkout (voir
    // _startPremiumCheckout). 0 ici évite juste le crash à l'affichage.
    if (widget.type == 'premium') return 0;
    return widget.property!.prix;
  }

  double get _fraisService => _baseAmount * 0.02;
  double get _total        => _baseAmount + _fraisService;

  // ── Pré-remplir l'email de l'utilisateur connecté ─────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final user = AuthService.instance.currentUserOrEmpty;
    if (user.email.isNotEmpty) _emailCtrl.text = user.email;
    if ((user.telephone ?? '').isNotEmpty) _phoneCtrl.text = user.telephone!;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // L'utilisateur revient dans l'appli après être passé par le navigateur
  // pour payer (checkout hébergé FedaPay) → on revérifie son vrai statut
  // côté serveur, sans jamais le supposer côté client.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingConfirmation) {
      _checkPremiumStatus();
    }
  }

  // ── Paiement ───────────────────────────────────────────────────────────────
  Future<void> _startFedaPay() async {
    if (widget.type == 'premium') {
      await _startPremiumCheckout();
      return;
    }

    // ⚠️ Flux location/achat : la route /api/transactions correspondante est
    // désactivée côté backend depuis le 25/08/2026 (voir index.ts — seul
    // /api/premium reste actif). Ce chemin ne créera donc rien de réel tant
    // qu'elle n'est pas réactivée côté serveur.
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (phone.isEmpty) {
      setState(() => _errorMsg = 'Veuillez saisir votre numéro de téléphone.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMsg = 'Veuillez saisir un email valide.');
      return;
    }
    if (widget.type == 'location' && _dateFin == null) {
      setState(() => _errorMsg = 'Veuillez choisir une date de fin de location.');
      return;
    }
    if (widget.type == 'location' && _dateFin != null && !_dateFin!.isAfter(_dateDebut)) {
      setState(() => _errorMsg = 'La date de fin doit être après la date de début.');
      return;
    }

    setState(() { _processing = true; _errorMsg = null; });

    await Future.delayed(const Duration(seconds: 2));
    final fakePaymentRef = 'fp_${DateTime.now().millisecondsSinceEpoch}';

    if (!mounted) return;

    final result = await TransactionService.instance.createTransaction(
      propertyId: widget.property!.id,
      montant: _total,
      type: widget.type == 'location' ? 'location' : 'achat',
      moyenPaiement: 'mobile_money',
      dateDebut: widget.type == 'location' ? _dateDebut : null,
      dateFin: widget.type == 'location' ? _dateFin : null,
      paymentRef: fakePaymentRef,
    );

    if (!mounted) return;
    setState(() => _processing = false);

    if (result.error != null) {
      setState(() => _errorMsg = result.error);
      return;
    }
    _showSuccess();
  }

  // ── Premium : vrai checkout FedaPay ──────────────────────────────────────
  // Étape 1 — On demande au backend de créer la transaction FedaPay (lui
  //   seul connaît le prix réel, voir PREMIUM_PRICE_FCFA côté serveur).
  // Étape 2 — On ouvre l'URL de paiement hébergé dans le navigateur.
  // Étape 3 — On ne débloque JAMAIS le badge Premium depuis le client : on
  //   attend que le webhook FedaPay confirme le paiement côté serveur, puis
  //   on rafraîchit le vrai profil utilisateur (GET /auth/me) pour lire isPremium.
  Future<void> _startPremiumCheckout() async {
    setState(() { _processing = true; _errorMsg = null; });

    final result = await ApiService.instance.post('/premium/checkout', {}, auth: true);

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _processing = false;
        _errorMsg = result['message'] ?? 'Erreur lors de la création du paiement.';
      });
      return;
    }

    final paymentUrl = result['data']?['paymentUrl'] as String?;
    if (paymentUrl == null) {
      setState(() {
        _processing = false;
        _errorMsg = 'Réponse inattendue du serveur.';
      });
      return;
    }

    final opened = await launchUrl(
      Uri.parse(paymentUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) return;

    if (!opened) {
      setState(() {
        _processing = false;
        _errorMsg = "Impossible d'ouvrir la page de paiement FedaPay.";
      });
      return;
    }

    setState(() {
      _processing = false;
      _awaitingConfirmation = true;
    });
  }

  Future<void> _checkPremiumStatus() async {
    if (_checkingStatus) return;
    setState(() => _checkingStatus = true);

    await AuthService.instance.refreshUser();

    if (!mounted) return;
    setState(() => _checkingStatus = false);

    if (AuthService.instance.currentUserOrEmpty.isPremium) {
      setState(() => _awaitingConfirmation = false);
      _showSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Paiement pas encore confirmé. Réessaie dans quelques instants.',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.textSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p     = widget.property;
    final isPremium = widget.type == 'premium';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: isPremium
            ? 'Passer Premium'
            : widget.type == 'location'
                ? tr('pay_reservation')
                : tr('pay_achat'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Résumé bien / offre ───────────────────────────────────────
            // p n'est non-null que pour les types location/achat — garanti par
            // les points d'appel de cet écran.
            if (!isPremium) _PropertySummaryCard(property: p!),
            if (isPremium)  _PremiumSummaryCard(),

            // ── Dates (location seulement) ────────────────────────────────
            if (widget.type == 'location') ...[
              const SizedBox(height: 20),
              Text(tr('pay_dates'),
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _DatePicker(
                  label: 'Début', date: _dateDebut,
                  onPick: (d) => setState(() => _dateDebut = d),
                )),
                const SizedBox(width: 12),
                Expanded(child: _DatePicker(
                  label: 'Fin', date: _dateFin,
                  onPick: (d) => setState(() => _dateFin = d),
                )),
              ]),
            ],

            // ── Infos paiement (téléphone + email) ───────────────────────
            const SizedBox(height: 24),
            _SectionTitle(icon: Icons.phone_rounded, label: 'Infos de paiement'),
            const SizedBox(height: 12),

            // Badge FedaPay
            _FedaPayBadge(),
            const SizedBox(height: 16),

            AppTextField(
              label: tr('pay_phone'),
              hint: '+228 90 00 00 00',
              controller: _phoneCtrl,
              prefixIcon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Email',
              hint: 'vous@exemple.com',
              controller: _emailCtrl,
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),

            // ── Moyens de paiement acceptés ────────────────────────────
            const SizedBox(height: 20),
            _SectionTitle(icon: Icons.payments_rounded, label: 'Moyens acceptés via FedaPay'),
            const SizedBox(height: 12),
            _AcceptedMethodsRow(),

            // ── Récapitulatif montant ──────────────────────────────────
            const SizedBox(height: 24),
            _AmountSummary(
              type: widget.type,
              nbJours: _nbJours,
              baseAmount: _baseAmount,
              frais: _fraisService,
              total: _total,
            ),

            // ── Erreur ────────────────────────────────────────────────
            if (_errorMsg != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_errorMsg!,
                      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.error))),
                ]),
              ),
            ],

            // ── En attente de confirmation (retour du checkout FedaPay) ──
            if (_awaitingConfirmation) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.info.withOpacity(0.25)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'En attente de confirmation du paiement…',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.info),
                    )),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    "Reviens sur l'appli une fois le paiement terminé — on vérifie automatiquement. Tu peux aussi le faire toi-même :",
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _checkingStatus ? null : _checkPremiumStatus,
                    child: Text(
                      _checkingStatus ? 'Vérification…' : 'Vérifier mon paiement',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            // ── Bouton paiement ────────────────────────────────────────
            PrimaryButton(
              label: isPremium ? 'Continuer vers FedaPay' : 'Payer ${formatFcfa(_total)} via FedaPay',
              icon: Icons.lock_rounded,
              isLoading: _processing,
              onPressed: _startFedaPay,
            ),

            const SizedBox(height: 12),
            Center(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.shield_outlined, size: 14, color: AppTheme.textHint),
                const SizedBox(width: 5),
                Text('Paiement 100 % sécurisé par FedaPay',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, size: 50, color: AppTheme.success),
            ),
            const SizedBox(height: 20),
            Text(
              widget.type == 'location'
                  ? tr('pay_resa_confirmed')
                  : widget.type == 'premium'
                      ? '🎉 Bienvenue en Premium !'
                      : tr('pay_success'),
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Un reçu vous a été envoyé par email.\nMerci pour votre confiance !',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: tr('pay_back_home'),
              onPressed: () {
                Navigator.pop(context); // ferme dialog
                Navigator.pop(context); // ferme PaymentScreen
                if (widget.type != 'premium') Navigator.pop(context); // ferme detail
              },
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS LOCAUX
// ═══════════════════════════════════════════════════════════════════

class _PropertySummaryCard extends StatelessWidget {
  final PropertyModel property;
  const _PropertySummaryCard({required this.property});

  @override
  Widget build(BuildContext context) {
    final p = property;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(p.firstImage, width: 70, height: 70, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: AppTheme.divider,
                  child: const Icon(Icons.home_rounded, color: AppTheme.textHint))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.titre,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(p.adresse.short,
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 3),
          Text(formatFcfa(p.prix),
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
        ])),
      ]),
    );
  }
}

class _PremiumSummaryCard extends StatelessWidget {
  const _PremiumSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6F00), Color(0xFFFFB300)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        const Icon(Icons.star_rounded, color: Colors.white, size: 40),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Abonnement Premium',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Annonces vedettes · Statistiques · +',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
        ]),
      ]),
    );
  }
}

class _FedaPayBadge extends StatelessWidget {
  const _FedaPayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF00A884).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00A884).withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00A884),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.payment_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Paiement via FedaPay',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600,
                  color: const Color(0xFF00A884))),
          Text('Vous serez redirigé vers la page de paiement sécurisée',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
        ])),
      ]),
    );
  }
}

class _AcceptedMethodsRow extends StatelessWidget {
  const _AcceptedMethodsRow();

  @override
  Widget build(BuildContext context) {
    final methods = [
      {'label': 'Flooz',    'color': const Color(0xFF0D47A1), 'icon': Icons.phone_android_rounded},
      {'label': 'T-Money',  'color': const Color(0xFFE53935), 'icon': Icons.phone_android_rounded},
      {'label': 'MTN MoMo', 'color': const Color(0xFFFFB300), 'icon': Icons.phone_android_rounded},
      {'label': 'Carte',    'color': const Color(0xFF1976D2), 'icon': Icons.credit_card_rounded},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: methods.map((m) {
        final color = m['color'] as Color;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(m['icon'] as IconData, size: 14, color: color),
            const SizedBox(width: 5),
            Text(m['label'] as String,
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          ]),
        );
      }).toList(),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  final String type;
  final int nbJours;
  final double baseAmount;
  final double frais;
  final double total;

  const _AmountSummary({
    required this.type, required this.nbJours, required this.baseAmount,
    required this.frais, required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.primary.withOpacity(0.05),
          AppTheme.primaryLight.withOpacity(0.08),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Column(children: [
        if (type == 'location') ...[
          _Row(label: 'Durée',      value: '$nbJours jour${nbJours > 1 ? 's' : ''}'),
          _Row(label: 'Prix/jour',  value: formatFcfa(baseAmount / nbJours)),
        ],
        _Row(label: 'Sous-total',               value: formatFcfa(baseAmount)),
        _Row(label: 'Frais de service (2 %)',   value: formatFcfa(frais)),
        const Divider(height: 20),
        _Row(label: 'Total à payer', value: formatFcfa(total), bold: true),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _Row({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: bold ? 14 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: bold ? AppTheme.textPrimary : AppTheme.textSecondary)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: bold ? AppTheme.primary : AppTheme.textPrimary)),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: AppTheme.primary),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── Date Picker ────────────────────────────────────────────────────
class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? date;
  final Function(DateTime) onPick;
  const _DatePicker({required this.label, this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (_, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              date != null ? '${date!.day}/${date!.month}/${date!.year}' : 'Choisir',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: date != null ? AppTheme.textPrimary : AppTheme.textHint),
            ),
          ]),
        ]),
      ),
    );
  }
}