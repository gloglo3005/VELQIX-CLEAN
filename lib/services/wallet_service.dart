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
  // ⚠️ Corrigé : l'ancien fallback créditait le solde localement
  // (SharedPreferences) dès que l'appel réseau échouait, SANS AUCUNE
  // vérification qu'un paiement avait réellement eu lieu. Comme
  // /api/wallet/topup n'est aujourd'hui plus monté côté backend (routes
  // désactivées, voir index.ts), cet appel échoue systématiquement — ce
  // fallback aurait donc permis à n'importe qui de se créditer un solde
  // illimité gratuitement dès qu'il coupait sa connexion. On ne fait
  // désormais plus jamais confiance au solde local en cas d'échec réseau :
  // on retourne le solde serveur connu (mis en cache en lecture seule) et
  // on signale l'échec à l'appelant.
  Future<double> topUp(double amount) async {
    final prefs = await SharedPreferences.getInstance();
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
    // Échec (réseau ou serveur) : on ne crédite jamais localement, on
    // retourne le dernier solde confirmé par le serveur.
    return prefs.getDouble(_kBalance) ?? 0.0;
  }

  // ── Déduire (retourne false si solde insuffisant OU si la déduction
  // n'a pas pu être confirmée par le serveur — voir note ci-dessus : on ne
  // débite plus jamais un solde local non vérifié) ─────────────────
  Future<bool> deduct(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final res = await ApiService.instance.post(
      '/wallet/deduct',
      {'montant': amount, 'motif': 'Appel vidéo'},
      auth: true,
    );
    if (res['success'] == true && res['data'] != null) {
      final balance = (res['data']['balance'] ?? 0.0).toDouble();
      await prefs.setDouble(_kBalance, balance);
      return true;
    }
    return false;
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
