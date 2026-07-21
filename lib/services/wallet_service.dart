// ═══════════════════════════════════════════════════════════════════
// WALLET SERVICE — Gestion du solde client
// Synchronisé avec le backend + Cache local SharedPreferences
// Tarif appel vidéo : 10 FCFA / minute
// ═══════════════════════════════════════════════════════════════════

import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  static const String _kBalance       = 'wallet_balance';
  static const double kCallRatePerMin = 10.0; // FCFA par minute

  // ── Solde actuel ──────────────────────────────────────────────────
  Future<double> getBalance() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // Tenter de récupérer le solde depuis le serveur
      final res = await ApiService.instance.get('/wallet/balance', auth: true);
      if (res['success'] == true && res['data'] != null) {
        final balance = (res['data']['balance'] ?? 0.0).toDouble();
        await prefs.setDouble(_kBalance, balance);
        return balance;
      }
    } catch (_) {
      // En cas d'erreur réseau, on retourne la valeur en cache
    }
    return prefs.getDouble(_kBalance) ?? 0.0;
  }

  // ── Recharger le solde ────────────────────────────────────────────
  Future<double> topUp(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await ApiService.instance.post(
        '/wallet/topup',
        {'montant': amount, 'paymentRef': 'ref_${DateTime.now().millisecondsSinceEpoch}'},
        auth: true,
      );
      if (res['success'] == true && res['data'] != null) {
        final balance = (res['data']['balance'] ?? 0.0).toDouble();
        await prefs.setDouble(_kBalance, balance);
        return balance;
      }
    } catch (_) {
      // Fallback local en cas d'erreur réseau
    }
    final current = prefs.getDouble(_kBalance) ?? 0.0;
    final newBalance = current + amount;
    await prefs.setDouble(_kBalance, newBalance);
    return newBalance;
  }

  // ── Déduire (retourne false si solde insuffisant) ─────────────────
  Future<bool> deduct(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await ApiService.instance.post(
        '/wallet/deduct',
        {'montant': amount, 'motif': 'Appel vidéo'},
        auth: true,
      );
      if (res['success'] == true && res['data'] != null) {
        final balance = (res['data']['balance'] ?? 0.0).toDouble();
        await prefs.setDouble(_kBalance, balance);
        return true;
      } else if (res['statusCode'] == 402 || (res['message'] != null && res['message'].toString().contains('insuffisant'))) {
        return false;
      }
    } catch (_) {
      // Fallback local en cas d'erreur réseau
    }
    final current = prefs.getDouble(_kBalance) ?? 0.0;
    if (current < amount) return false;
    await prefs.setDouble(_kBalance, current - amount);
    return true;
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
