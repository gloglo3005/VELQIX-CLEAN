// ═══════════════════════════════════════════════════════════════════
// WALLET SERVICE — Gestion du solde client
// Stockage local via SharedPreferences
// Tarif appel vidéo : 10 FCFA / minute
// ═══════════════════════════════════════════════════════════════════

import 'package:shared_preferences/shared_preferences.dart';

class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  static const String _kBalance       = 'wallet_balance';
  static const double kCallRatePerMin = 10.0; // FCFA par minute

  // ── Solde actuel ──────────────────────────────────────────────────
  Future<double> getBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kBalance) ?? 0.0;
  }

  // ── Recharger le solde ────────────────────────────────────────────
  Future<double> topUp(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble(_kBalance) ?? 0.0;
    final newBalance = current + amount;
    await prefs.setDouble(_kBalance, newBalance);
    return newBalance;
  }

  // ── Déduire (retourne false si solde insuffisant) ─────────────────
  Future<bool> deduct(double amount) async {
    final prefs = await SharedPreferences.getInstance();
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
