// ═══════════════════════════════════════════════════════════════════
// WALLET SCREEN — Recharge du solde pour appels vidéo
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0.0;
  bool _loading   = false;
  int? _selected; // montant sélectionné

  final List<Map<String, dynamic>> _packages = [
    {'amount': 100,  'label': '100 FCFA',  'minutes': 10,  'bonus': null},
    {'amount': 250,  'label': '250 FCFA',  'minutes': 25,  'bonus': null},
    {'amount': 500,  'label': '500 FCFA',  'minutes': 50,  'bonus': '+5 min offerts'},
    {'amount': 1000, 'label': '1 000 FCFA','minutes': 100, 'bonus': '+15 min offerts'},
    {'amount': 2000, 'label': '2 000 FCFA','minutes': 200, 'bonus': '+40 min offerts'},
    {'amount': 5000, 'label': '5 000 FCFA','minutes': 500, 'bonus': '+100 min offerts'},
  ];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final b = await WalletService.instance.getBalance();
    if (mounted) setState(() => _balance = b);
  }

  Future<void> _topUp() async {
    if (_selected == null) return;
    setState(() => _loading = true);

    // Simulation paiement (intégrer FedaPay ici plus tard)
    await Future.delayed(const Duration(seconds: 2));

    final pkg = _packages.firstWhere((p) => p['amount'] == _selected);
    double credit = (_selected! + 0.0);

    // Ajouter les minutes bonus si applicable
    if (pkg['bonus'] != null) {
      final bonusMinutes = int.tryParse(
          RegExp(r'\d+').firstMatch(pkg['bonus'] as String)?.group(0) ?? '0') ?? 0;
      credit += bonusMinutes * WalletService.kCallRatePerMin;
    }

    final newBalance = await WalletService.instance.topUp(credit);

    if (!mounted) return;
    setState(() { _balance = newBalance; _loading = false; _selected = null; });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${credit.toStringAsFixed(0)} FCFA ajoutés à votre solde !',
          style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(title: 'Mon portefeuille'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Solde actuel ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 36),
              const SizedBox(height: 12),
              Text('Solde disponible',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 4),
              Text('${_balance.toStringAsFixed(0)} FCFA',
                  style: GoogleFonts.poppins(
                      fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '≈ ${(_balance / WalletService.kCallRatePerMin).floor()} min d\'appel vidéo',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Tarif info ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
            ),
            child: Row(children: [
              const Icon(Icons.videocam_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Appel vidéo : 10 FCFA / minute\nLe solde est débité automatiquement pendant l\'appel.',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
              )),
            ]),
          ),

          const SizedBox(height: 24),
          Text('Choisir un montant',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          // ── Forfaits ──────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: _packages.length,
            itemBuilder: (_, i) {
              final pkg = _packages[i];
              final isSelected = _selected == pkg['amount'];
              return GestureDetector(
                onTap: () => setState(() => _selected = pkg['amount'] as int),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 12, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(pkg['label'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppTheme.textPrimary)),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${pkg['minutes']} min',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: isSelected ? Colors.white70 : AppTheme.textSecondary)),
                          if (pkg['bonus'] != null)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : AppTheme.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(pkg['bonus'] as String,
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : AppTheme.accent)),
                            ),
                        ]),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Bouton recharger ──────────────────────────────────────
          PrimaryButton(
            label: _selected != null
                ? 'Recharger $_selected FCFA'
                : 'Choisir un forfait',
            icon: Icons.add_card_rounded,
            isLoading: _loading,
            onPressed: _selected != null ? _topUp : null,
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              '💡 Paiement simulé — branchez FedaPay pour la production',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}
