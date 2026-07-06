// ═══════════════════════════════════════════════════════════════════
// WALLET SERVICE — Connecté au backend VelQix
// Tarif appel vidéo : 10 FCFA / minute
// ═══════════════════════════════════════════════════════════════════

import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  static const double kCallRatePerMin = 10.0;
  static const String _kBalance = 'wallet_balance_cache';

  final _api = ApiService.instance;

  // ── Solde depuis le backend (avec cache local) ────────────────────
  Future<double> getBalance() async {
    final res = await _api.get('/wallet/balance', auth: true);
    if (res['success'] == true) {
      final balance = (res['data']['balance'] ?? 0).toDouble();
      // Mettre en cache local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kBalance, balance);
      return balance;
    }
    // Fallback cache local si le réseau est indisponible
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kBalance) ?? 0.0;
  }

  // ── Recharger le solde ────────────────────────────────────────────
  Future<double> topUp(double amount, {String? paymentRef}) async {
    final res = await _api.post('/wallet/topup', {
      'montant': amount,
      if (paymentRef != null) 'paymentRef': paymentRef,
    }, auth: true);

    if (res['success'] == true) {
      final balance = (res['data']['balance'] ?? 0).toDouble();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kBalance, balance);
      return balance;
    }
    // Retourner le solde actuel en cas d'erreur
    return await getBalance();
  }

  // ── Déduire (appels vidéo) ────────────────────────────────────────
  Future<bool> deduct(double amount, {String? motif}) async {
    final res = await _api.post('/wallet/deduct', {
      'montant': amount,
      if (motif != null) 'motif': motif,
    }, auth: true);

    if (res['success'] == true) {
      final balance = (res['data']['balance'] ?? 0).toDouble();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kBalance, balance);
      return true;
    }
    return false; // solde insuffisant ou erreur
  }

  // ── Vérifier si le solde couvre au moins 1 minute ─────────────────
  Future<bool> canStartVideoCall() async {
    final balance = await getBalance();
    return balance >= kCallRatePerMin;
  }

  // ── Durée maximale possible avec le solde actuel ──────────────────
  Future<int> maxCallMinutes() async {
    final balance = await getBalance();
    return (balance / kCallRatePerMin).floor();
  }
}