import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

// ═══════════════════════════════════════════════════════════════════
// PAYMENT SCREEN — Abonnement Premium via FedaPay
// ═══════════════════════════════════════════════════════════════════

/// Prix affiché à titre indicatif : le montant réellement facturé est
/// décidé par le backend (PREMIUM_PRICE_FCFA, 2000 par défaut).
const double kPremiumPriceFcfa = 2000;
const int kPremiumDurationDays = 30;

class PaymentScreen extends StatefulWidget {
  final String type; // 'premium' uniquement
  const PaymentScreen({super.key, this.type = 'premium'});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with WidgetsBindingObserver {
  bool _processing = false;
  String? _errorMsg;

  // Le statut Premium ne vient JAMAIS d'une valeur locale : on interroge
  // toujours le backend (via AuthService.refreshUser → GET /auth/me), qui ne
  // reflète isPremium que si le webhook FedaPay a confirmé le paiement.
  bool _awaitingConfirmation = false;
  bool _checkingStatus = false;

  // Sur le web (et parfois sur mobile) l'événement « resumed » n'arrive pas
  // au retour du paiement : on interroge donc aussi le serveur toutes les
  // 5 s (3 min max) tant qu'on attend la confirmation du webhook.
  Timer? _poll;
  int _pollCount = 0;

  void _startPolling() {
    _poll?.cancel();
    _pollCount = 0;
    _poll = Timer.periodic(const Duration(seconds: 5), (t) {
      if (!mounted || !_awaitingConfirmation || ++_pollCount > 36) {
        t.cancel();
        return;
      }
      _checkPremiumStatus(silent: true);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // L'utilisateur revient dans l'appli après être passé par le navigateur
  // pour payer (checkout hébergé FedaPay) → on revérifie son vrai statut.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingConfirmation) {
      _checkPremiumStatus();
    }
  }

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
    _startPolling();
  }

  Future<void> _checkPremiumStatus({bool silent = false}) async {
    if (_checkingStatus) return;
    setState(() => _checkingStatus = true);

    await AuthService.instance.refreshUser();

    if (!mounted) return;
    setState(() => _checkingStatus = false);

    if (AuthService.instance.currentUserOrEmpty.isPremium) {
      _poll?.cancel();
      setState(() => _awaitingConfirmation = false);
      _showSuccess();
    } else if (!silent) {
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomAppBar(title: 'Passer Premium'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PremiumSummaryCard(),

            const SizedBox(height: 24),
            const _SectionTitle(icon: Icons.payments_rounded, label: 'Paiement'),
            const SizedBox(height: 12),
            const _FedaPayBadge(),

            const SizedBox(height: 20),
            const _SectionTitle(icon: Icons.phone_android_rounded, label: 'Moyens acceptés via FedaPay'),
            const SizedBox(height: 12),
            const _AcceptedMethodsRow(),

            const SizedBox(height: 24),
            Container(
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
                const _Row(label: 'Durée', value: '$kPremiumDurationDays jours'),
                const Divider(height: 20),
                _Row(label: 'Total à payer', value: formatFcfa(kPremiumPriceFcfa), bold: true),
              ]),
            ),

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
                  const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_errorMsg!,
                      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.error))),
                ]),
              ),
            ],

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

            PrimaryButton(
              label: 'Continuer vers FedaPay',
              icon: Icons.lock_rounded,
              isLoading: _processing,
              onPressed: _startPremiumCheckout,
            ),

            const SizedBox(height: 12),
            Center(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shield_outlined, size: 14, color: AppTheme.textHint),
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
              '🎉 Bienvenue en Premium !',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Votre abonnement est actif.\nMerci pour votre confiance !',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Continuer',
              onPressed: () {
                Navigator.pop(context); // ferme dialog
                Navigator.pop(context); // ferme PaymentScreen
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